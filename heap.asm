include 'linux/signal.inc'

; Активен ли сборщик мусора
HEAP_GC := 0

; Минимальный начальный размер кучи (м.б. увеличен из-за выравнивания секций).
HEAP_INIT_SIZE := 1000h	; 4096
; Размер, на который увеличивается куча.
HEAP_INCREMENT := 1000h	; 4096

; "Куча", где размещаются и хранятся объекты (OCaml value)
; представляет собой статически выделенный в ELF-образе массив памяти.
; Размещение (аллокация) объектов происходит непосредственно один за другим,
; путём увеличения адреса.
; Адрес хранятся в 2х регистрах:
; RDI используется в виртуальной машине, оперирующей инструкциями movs/stos;
; R14 используется в вызываемом машинном коде (в оригинале: C-примитывы)
; поскольку RDI по конвенции вызовов (System V AMD64 ABI) не сохраняется.
alloc_small_ptr		equ rdi	; С-функции портят регистр
alloc_small_ptr_backup	equ r14	; копия для сохранения при вызовах

; Инициализация кучи. RDI копируется в R14 и обратно в обработчиках C_CALL.
macro heap_small_init
;	В качестве кучи используем массив байт в сегменте неинициализированных данных
	lea	alloc_small_ptr, [heap_small]
end macro

; Иниациализация необходимых для работы кучи и сборщика мусора параметров.
macro heap_init
if HEAP_GC
	mov	[heap_descriptor.gc_start], alloc_small_ptr
	mov	[heap_descriptor.sp_top], rsp
display 'Сборщик мусора активен.', 10
end if
	lea	rax, [heap_small.unaligned_end + PAGE_SIZE]
	and	rax, not (PAGE_SIZE-1)
	mov	[heap_descriptor.uncommited], rax
end macro

; При выходе за выделенные под кучу страницы памяти генерируется SIGSEGV.
; Обработчик sigsegv_handler добавляет новые страницы по необходимости.
; Там же обеспечить сборку мусора.
;
; Макрос устанавливает обработчик.
macro	heap_sigsegv_handler_init
	virtual at rsp
	.ksa	kernel_sigaction
	end virtual
	mov	rdi, rsp
	mov	rax, heap_sigsegv_handler
	stos	qword[rdi]
	mov	eax, SA_SIGINFO or SA_RESTORER
	stos	qword[rdi]
	mov	rax, __restore_rt
	stos	qword[rdi]
	zero	eax
	mov	ecx, _NSIG / 8
	mov	r10, rcx
rep	stos	qword[rdi]
	mov	edi, SIGSEGV
	mov	rsi, rsp
	zero	edx
	sys.rt_sigaction
	j_ok	.sigseg_handler_installed
	push	rax
	puts	error_sigsegv_nohandler
	pop	rdi
	jmp	sys_exit
.sigseg_handler_installed:
end macro

; Параметры кучи. Д.б. в секции данных.
macro	heap_descriptor
heap_descriptor:
	.gc_start	dq ?	; Если адрес не 0, то с него начинается сборка мусора.
	.uncommited	dq ?
	.sp_top		dq ?
end macro

; Выделяет статически начальную память для кучи.
; Должно завершать секцию неинициализированных данных.
macro heap_small__ends_bss
heap_small:	rb HEAP_INIT_SIZE
.unaligned_end:
end macro

; RDI - № сигнала (д.б. SIGSEGV)
; RSI - адрес siginfo
; RDX - контекст ucontext
proc heap_sigsegv_handler
	virtual at rsi
	.sinf	siginfo_sigfault
	end virtual
	virtual at rdx
	.ctx	ucontext
	end virtual
	cmp	[.sinf.si_code], SEGV_MAPERR
	mov	eax, EFAULT
	jnz	.err
uncommited equ r9
	mov	uncommited, [.sinf.si_addr]
	and	uncommited, not (PAGE_SIZE-1)
;	SIGSEGV валиден при обращении через один из регистров: r14 или rdi.
	lea	r10, [.ctx.uc_mcontext.rsi]
	mov	rax, [r10]
	and	rax, not (PAGE_SIZE-1)
	cmp	rax, uncommited
	jz	.chkun
	lea	r10, [.ctx.uc_mcontext.r14]
;	mov	rax, [r10]
;	and	rax, not (PAGE_SIZE-1)
;	cmp	rax, uncommited
;	jnz	.err
;	Поскольку адрес аллокации растёт линейно, исключение возникает
;	вблизи границы старших адресов кучи.
.chkun:	cmp	uncommited, [heap_descriptor.uncommited]
	jnz	.err
;	Если сборщик мусора отключен, просто добавляем страницу.
	mov	alloc_small_ptr, [heap_descriptor.gc_start]
	test	alloc_small_ptr, alloc_small_ptr
	jz	.add_page
;	Ищем в стеке потока ссылки на блоки в куче.
;	Это значения с младшим битом равным 0 и
;	попадающие в диапазон адресов кучи.
iter	equ r8
last	equ [.ctx.uc_mcontext.rsp]
step	equ -sizeof value
	mov	iter, [heap_descriptor.sp_top]
;	SIGSEGV может быть сгенерирован, когда объект на куче создан частично.
;	Поэтому после сборки мусора слудет найти заголовок последнего объекта.
;	Если часть объекта выходит за пределы кучи, необходимо
;	скопировать уже размещённую часть.
;	Поиск осуществляется от адреса за источником последнего скопированного
;	объекта. Для случая, когда копирований не было (нет "живых" объектов)
;	установим адрес источника равным адресу начала динамической области кучи.
	mov	rsi, alloc_small_ptr
.search_stack:
	add	iter, step
	cmp	iter, last
	jz	.stack_searched
	mov	rax, [iter]
	test	rax, 1
	jnz	.search_stack
	cmp	rax, alloc_small_ptr
	jc	.search_stack
	cmp	rax, uncommited
	jae	.search_stack
;	Найдена ссылка на объект в куче.
;	Копируем его в начало динамической области.
;
;	Возможны случаи, когда копирование не требуется.
;	Следует учесть их в дальнейшем.
;
	mov	rsi, rax
	mov	rax, [rsi - sizeof value]
	stos	Val_header[alloc_small_ptr]
;	Корректируем ссылку на объект.
	mov	[iter], alloc_small_ptr
	mov	ecx, eax
	from_wosize ecx
rep	movs	qword[alloc_small_ptr], [rsi]
	jmp	.search_stack
.stack_searched:
;	Ищем последний объект, что бы определить, не аллоцируется ли он
;	в момент возникновения SIGSEGV.
.find_last_value:
	mov	rax, rsi
	mov	rsi, [rax]
	from_wosize esi
	lea	rsi, [rax + (rsi + 1) * sizeof value]
	cmp	rsi, uncommited
	jc	.find_last_value
;	Если равны, значит последний объект размещён целиком.
	jz	.copied
;	Копируем частично размешённый объект в хвост динамической части кучи.
	mov	rsi, rax
.cpo:	movs	qword[alloc_small_ptr], [rsi]
	cmp	rsi, uncommited
	jc	.cpo
.copied:
;	Здесь alloc_small_ptr содержит адрес за "живыми" объектами кучи.
;	Если он равен uncommited, значит освободить место в куче не удалось
;	и следует выделить новые страницы.
	cmp	alloc_small_ptr, uncommited
	jae	.add_page
;	Если удалось освободить место, значит alloc_small_ptr изменился.
;	Следует передать его в прерванный поток через структуру ucontext.
;	Учтём, что обращение к памяти может быть по смещению
;	относительно значения регистра.
	sub	alloc_small_ptr, uncommited
	add	[r10], alloc_small_ptr
	ret
restore	step
restore	last
restore	iter
;	Добавляем страницу(ы) памяти.
.add_page:
	mov	rdi, uncommited	; округлённый до границы страницы [.sinf.si_addr]
	mov	esi, HEAP_INCREMENT
	mov	edx, PROT_READ or PROT_WRITE
	mov	r10d, MAP_PRIVATE or MAP_ANONYMOUS
	mov	r8, -1
	zero	r9
;	Сохраняем адрес за выделенными страницами.
	lea	rax, [rdi + rsi]
	mov	[heap_descriptor.uncommited], rax
	sys.mmap
	j_err	.err
	ret
restore	uncommited

.err:	push	rax
	puts	error_sigsegv_handler
	pop	rdi
	jmp	sys_exit

; См.	glibc/sysdeps/unix/sysv/linux/x86_64/sigaction.c
; и (?)	uClibc/libc/sysdeps/linux/arc/sigaction.c
align_code 16
__restore_rt:
	sys.rt_sigreturn
end proc
