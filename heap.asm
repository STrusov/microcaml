include 'linux/signal.inc'

; Активен ли сборщик мусора
HEAP_GC := 1

; Минимальный начальный размер кучи (м.б. увеличен из-за выравнивания секций).
HEAP_INIT_SIZE := 1000h	; 4096
; Размер, на который увеличивается куча.
HEAP_INCREMENT := 1000h	; 4096

; Об оригинальной куче и сборщике мусора:
; se.math.spbu.ru/SE/YearlyProjects/2014/444/444-Shashkova-report.pdf

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

; Макрос в том числе делает объекты в куче статическими, запрещая их удаление.
macro heap_set_gc_start
	mov	[heap_descriptor.gc_start], alloc_small_ptr
end macro

; Иниациализация необходимых для работы кучи и сборщика мусора параметров.
macro heap_init
if HEAP_GC
	heap_set_gc_start
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
uncommited equ r10
rsi14_ptr equ rcx
	mov	uncommited, [.sinf.si_addr]
	and	uncommited, not (PAGE_SIZE-1)
;	SIGSEGV валиден при обращении через один из регистров: r14 или rdi.
	lea	rsi14_ptr, [.ctx.uc_mcontext.rsi]
	mov	rax, [rsi14_ptr]
	and	rax, not (PAGE_SIZE-1)
	cmp	rax, uncommited
	jz	.chkun
	lea	rsi14_ptr, [.ctx.uc_mcontext.r14]
;	mov	rax, [rsi14_ptr]
;	and	rax, not (PAGE_SIZE-1)
;	cmp	rax, uncommited
;	jnz	.err
;	Поскольку адрес аллокации растёт линейно, исключение возникает
;	вблизи границы старших адресов кучи.
.chkun:	cmp	uncommited, [heap_descriptor.uncommited]
	jnz	.err
;	Если сборщик мусора отключен, просто добавляем страницу.
	cmp	[heap_descriptor.gc_start], 0
	jz	.add_page
;	Сдвигаем живые объекты к началу кучи.
	push	rsi14_ptr
	mov	rbp, rsp
	mov	rsp, [.ctx.uc_mcontext.rsp]
	mov	alloc_small_ptr, uncommited
	call	heap_mark_compact_gc
	mov	rsp, rbp
;	После сборки мусора в ESI адрес за последним проверенным объектом.
;	Если этот адрес равен началу неотображённой страницы, значит упомянутый
;	объект на момент генерации SIGSEGV размещён целиком.
	cmp	r10, rsi
	jz	.whole
;	Иначе объект размещён частично, необходимо скопировать что есть.
;	В RAX возвращён размер объекта (без заголовка), находим его начальный адрес.
	not	rax	; neg - 1
	lea	rsi, [rsi + rax * sizeof value]
.cpo:	movs	qword[alloc_small_ptr], [rsi]
	cmp	rsi, uncommited
	jc	.cpo
.whole:
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
	pop	rsi14_ptr
	add	[rsi14_ptr], alloc_small_ptr
	ret
restore rsi14_ptr

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


; Сборщик мусора:
; 1) ищет ссылки (roots) на живые объекты;
; 2) маркирует блоки, хранящие живые объекты;
; 3) выполняет рекурсивный поиск ссылок в блоке;
; 4) сдвигает промаркированные блоки к младшим адресами кучи, корректируя ссылки.
; Маркер обеспечивает поиск ссылки за O(1) и представляет из себя "индекс"
; элемента в одном из "массивов": куче (относительно текущего блока) или стеке.
; В случае наличия нескольких ссылок на один блок, они организуются
; в односвязный список (располагаемый на местах дополнилельных ссылок).
; См. для примера: Mark-Compact GC, sliding algorithm.
; https://www.cs.tau.ac.il/~maon/teaching/2014-2015/seminar/seminar1415a-lec2-mark-sweep-mark-compact.pdf
;
; При вызове подпрограммы:
; RDI - свободный адрес в куче (т.е. за последним блоком);
; RSP - база стека для поиска корневых ссылок;
; в ячейке [RSP] находится адрес возврата (пропускается).
;
; При выходе из подпрограммы:
; RDI - изменяется в сторону младших адресов, если произошло уплотнение кучи;
; RSI - адрес, следующий за последним проверенным блоком;
; R10 - приравнивается ESI в начальной точке входа, более не изменяется;
; RAX - размер послдеднего проверенного блока (см. .compact:);
; RDX, RCX, R8, R9, R11 - не определены.
proc heap_mark_compact_gc
s_base	equ r8
s_size	equ r9
gc_end	equ r10
;	Индекс элемента в стеке - требуется для коррекции ссылок при уплотнении.
s_index	equ rcx
	mov	s_base, rsp
	mov	s_size, [heap_descriptor.sp_top]
	sub	s_size, s_base
	shr	s_size, 3	; / 8
;	Далее индекс увеличим, пропустив адрес возврата в стеке - необходим ненулевой маркер.
	zero	s_index
	mov     gc_end, alloc_small_ptr
	mov	alloc_small_ptr, [heap_descriptor.gc_start]
.search_stack:
	inc	s_index
	cmp	s_index, s_size
	jz	.stack_searched
;	Ссылки (roots) - это значения с младшим битом равным 0 и
;	попадающие в диапазон адресов кучи.
	mov	rax, [s_base + s_index * sizeof value]
	test	rax, 1
	jnz	.search_stack
	cmp	rax, alloc_small_ptr
	jc	.search_stack
	cmp	rax, [heap_descriptor.uncommited]
	jae	.search_stack
;	Найдена ссылка на объект в куче. Промаркируем объект индексом ссылки -
;	для быстрой её модификации при уплотнении кучи.
	mov	rdx, s_index
;	Маркер храним в старших битах, оставшихся свободными после wosize.
.mark_mask :=  (1 shl 64 - 1) and not Wosize_mask
..Mark_shift	:= bsr (Max_wosize+1) + wosize_shift
	shl	rdx, ..Mark_shift
	mov	rsi, .mark_mask	; b_index
b_base	equ rax
b_index	equ rsi
	test	rsi, [b_base - sizeof value]	;; ?
	mov	b_index, [b_base - sizeof value]
	jnz	.already_marked			;; ?
	or	[b_base - sizeof value], rdx
.check_block:
;	Проверяем тег, подлежит ли блок сканированию.
	cmp	sil, No_scan_tag
	jae	.block_searched
	from_wosize b_index
	jz	.empty_block			;; ?
.search_block:
	dec	b_index
	js	.block_searched
;	Проверяем блок на наличие ссылок.
	mov	rdx, [b_base + b_index * sizeof value]
	test	rdx, 1
	jnz	.search_block
	cmp	rdx, alloc_small_ptr
	jc	.search_block
	cmp	rdx, [heap_descriptor.uncommited]
	jae	.search_block
;	Найдена ссылка на объект в куче. Промаркируем объект индексом ссылки.
;	Выполним рекурсивный поиск ссылок в объекте, если он найден впервые.
;	Индекс ссылки, находящейся в теле блока в куче, по значению д.б. больше
;	чем размер стека - т.о. они различаются на стадии уплотнения.
;	Вычисляется как расстояние (в sizeof value) от адресуемого объекта
;	до места храненения ссылки + резмер стека (в sizeof value).
	push	rax rsi		; b_base b_index
	lea	rsi, [b_base + b_index * sizeof value]	; далее b_index невалиден
	mov	r11, rsi
	sub	rsi, rdx
;	Сдвиги можно оптимизировать, поскольку адреса кратны 8.
;	shr	rsi, 3	; / 8
	lea	rsi, [rsi + s_size * sizeof value]
	shl	rsi, bsr (Max_wosize+1) + wosize_shift - 3
	mov	b_base, rdx
	mov	rdx, .mark_mask
	test	rdx, [b_base - sizeof value]
	mov	rdx, [b_base - sizeof value]
	jnz	.already_marked_block
	or	[b_base - sizeof value], rsi
	mov	rsi, rdx	; b_index
	jmp	.check_block
.already_marked_block:
;	Блок уже содержит индекс ссылки - его содержимое обработано.
;	Организуем односвязный список ссылок. Имеющийся заголовок перенесём
;	по адресу текущей ссылки, а на его место сохраним новый маркер.
	mov	[r11], rdx
;	Маркер заменяем новым.
	shl	rdx, 64 - ..Mark_shift
	shr	rdx, 64 - ..Mark_shift
	or	rsi, rdx
	mov	[b_base - sizeof value], rsi
;	Выходим из рекурсивной обработки, уже выполненной для найденного блока.
	pop	rsi rax		; b_index b_base
	jmp	.search_block
restore b_base
restore b_size
restore b_index
.block_searched:
;	Если стек пуст, рекурсивная обработка текущего блока из кучи завершена.
	cmp	rsp, s_base
	jz	.search_stack
;	Иначе продолжаем сканировать предыдущий уровень.
	pop	rsi rax		; b_index b_base
	jmp	.search_block
restore s_index
.stack_searched:
;	Стадия уплотнения кучи.
;	alloc_small_ptr указывает на начало динамической области.
;	Проверяем последовательно каждый блок. Живой копируем к началу,
;	после чего корректируем ссылку на него.
	mov	rsi, alloc_small_ptr
.compact:
	cmp	rsi, gc_end
	jnc	.compact_end
	lods	Val_header[rsi]
	mov	rdx, .mark_mask
	test	rdx, rax
	jnz	.live_block
	from_wosize rax
;	and	eax, Max_wosize - лишнее т.к. старшие биты проверены на 0
	lea	rsi, [rsi + rax * sizeof value]
	jmp	.compact
.live_block:
	mov	rcx, rax
;	Очищаем маркер и копируем заголовок блока.
	not	rdx
	and	rax, rdx
	stos	Val_header[alloc_small_ptr]
.correct_link:
;	Определяем по маркеру адресс ссылки на блок.
	shr	rcx, ..Mark_shift
;	Элементы с индексом s_size и выше находятся за пределами стека. Для них
;	ссылка раположена в куче и находится по смещению от копируемого блока.
	zero	rdx
	cmp	rcx, s_size
	cmovnc	rdx, s_size
	mov	s_base, rsp
	cmovnc	s_base, rsi
	sub	rcx, rdx
;	Ссылка либо равна хранящейся в источнике, либо вместо неё находится
;	маркер с индексом следующей ссылки на данный блок.
	mov	rdx, [s_base + rcx * sizeof value]
	cmp	rdx, rsi
	mov	[s_base + rcx * sizeof value], alloc_small_ptr
;	Обрабатываем список ссылок, копирование блока произойдёт по его заверщении.
	jnz	.next_link
	mov	rcx, rax
	from_wosize rcx
rep	movs	qword[alloc_small_ptr], [rsi]
	jmp	.compact
.next_link:
	mov	rcx, rdx
	jmp	.correct_link
.compact_end:
restore s_base
restore s_size
restore gc_end
	ret

.already_marked:
int3
.empty_block:
int3
nop
end proc
