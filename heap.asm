include 'linux/signal.inc'

; Об оригинальной куче и сборщике мусора:
; se.math.spbu.ru/SE/YearlyProjects/2014/444/444-Shashkova-report.pdf

; "Куча", где размещаются и хранятся объекты (OCaml value)
; представляет собой статически выделенный в ELF-образе массив памяти.
; Размещение (аллокация) объектов происходит непосредственно один за другим,
; путём увеличения адреса.
; Адрес хранятся в 2х регистрах:
; RDI используется в виртуальной машине, оперирующей инструкциями movs/stos;
; R14 используется в вызываемом машинном коде (в оригинале: C-примитивы)
; поскольку RDI по конвенции вызовов (System V AMD64 ABI) не сохраняется.
alloc_small_ptr		equ rdi	; С-функции портят регистр
alloc_small_ptr_backup	equ r14	; копия для сохранения при вызовах

; Для инициализации кучи используется макрос heap_init.
; Опциональными параметрами передаются адрес и размер стека, используемого
; в обработчике исключений. Например (область выделена в стеке потока):
;	heap_init	[rsp + main.stack_size - MINSIGSTKSZ], MINSIGSTKSZ
;
; Возможно инициализировать кучу раздельно макросами
; heap_set_sigsegv_handler и heap_set_limits, имея ввиду, что
; результат сгенерированного между ними SIGSEGV не определён.
; Кроме того, для корректной работы compare_val, таблица атомов должна
; располагаться в куче. Инициализируется макросом create_atom_table.
;
; Для активации сборщика мусора (при условии HEAP_GC) - heap_enable_gc.
;
; Если надо объявить размещённые на куче объекты не подлежащими для сборки мусора,
; используется макрос heap_set_gc_start_address.

; Инициализация параметров кучи; текущий адрес аллокации и верхняя граница.
; RDI копируется в R14 и обратно в обработчиках C_CALL, потому задаём только 1й.
macro heap_set_limits
;	В качестве кучи используем массив байт в сегменте неинициализированных данных
	lea	alloc_small_ptr, [heap_small]
	lea	rax, [heap_small.unaligned_end + PAGE_SIZE]
	and	rax, not (PAGE_SIZE-1)
	mov	[heap_descriptor.uncommited], rax
end macro

; Макрос в том числе делает объекты в куче статическими, запрещая их удаление.
macro heap_set_gc_start_address
	mov	[heap_descriptor.gc_start], alloc_small_ptr
end macro

; Сборщик мусора активируется. Устанавливаются нижняя граница адресов кучи
; и верхняя граница адресов стека (для поиска ссылок на объекты в куче).
macro heap_enable_gc
if HEAP_GC
	heap_set_gc_start_address
	mov	[heap_descriptor.sp_top], rsp
display 'Сборщик мусора активен.', 10
end if
end macro

; При выходе за выделенные под кучу страницы памяти генерируется SIGSEGV.
; Обработчик sigsegv_handler вызывает сборщик мусора и
; добавляет новые страницы по необходимости.
;
; Макрос устанавливает обработчик, а так же стек для него.
macro	heap_set_sigsegv_handler	sigstack_base, sigstack_size
	virtual at rsp
	.sstk	sigaltstack
	end virtual
	virtual at rsp
	.ksa	kernel_sigaction
	end virtual
;	Задаём диапазон адресов стека для обработчика, при наличии параметров.
	match ssb, sigstack_base
		lea	rax, ssb
	end match
	sub	rsp, sizeof .ksa
	match sss, sigstack_size
		mov	[.sstk.ss_sp], rax
		zero	esi
		mov	[.sstk.ss_flags], esi
		mov	[.sstk.ss_size], sss
		mov	rdi, rsp
		sys.sigaltstack
	end match
	mov	rdi, rsp
	mov	rax, heap_sigsegv_handler
	stos	qword[rdi]
	match dummy, sigstack_size
		mov	eax, SA_SIGINFO or SA_RESTORER or SA_ONSTACK
		display 'Обработчик SIGSEGV использует выделенный стек.', 10
	else match invalid, sigstack_base
		err 'Для инициализации стека требуется 2 параметра.', 10
	else
		mov	eax, SA_SIGINFO or SA_RESTORER
	end match
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
	add	rsp, sizeof .ksa
	j_ok	.sigseg_handler_installed
	push	rax
	puts	error_sigsegv_nohandler
	pop	rdi
	jmp	sys_exit
.sigseg_handler_installed:
end macro

; Создаёт таблицу атомов.
macro create_atom_table
	zero	eax
.@:	stos	qword[alloc_small_ptr]
	inc	al
	jnz	.@
end macro

; Инициализация кучи. Устанавливается регистр-аллокатор и верхняя граница,
; а так же обработчик исключений, обеспечивающий рост кучи.
macro heap_init	sigstack_base, sigstack_size
	heap_set_sigsegv_handler sigstack_base, sigstack_size
	heap_set_limits
	create_atom_table
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
label caml_atom_table: qword
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
	lea	rsi14_ptr, [.ctx.uc_mcontext.rdi]
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
;	Если сборщик мусора отключён, просто добавляем страницу.
	cmp	[heap_descriptor.gc_start], 0
	jz	.add_page
;	Сдвигаем живые объекты к началу кучи.
	push	rsi14_ptr
	mov	rbp, rsp
	mov	rsp, [.ctx.uc_mcontext.rsp]
	mov	alloc_small_ptr, uncommited
	call	heap_mark_compact_gc
	mov	rsp, rbp
;	После сборки мусора в ESI адрес за последним проверенным объектом,
;	а в r10 сохраняется значение uncommited (см. heap_mark_compact_gc).
;	Если адреса равны (началу неотображённой страницы), значит упомянутый
;	объект на момент генерации SIGSEGV размещён целиком.
	cmp	uncommited, rsi	; r10
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
	pop	rsi14_ptr
	jae	.add_page
;	Если удалось освободить место, значит alloc_small_ptr изменился.
;	Следует передать его в прерванный поток через структуру ucontext.
;	Учтём, что обращение к памяти может быть по смещению
;	относительно значения регистра.
	sub	alloc_small_ptr, uncommited
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
; в односвязный список (располагаемый на местах дополнительных ссылок).
;
; Рабочий режим кучи:
;
;    Одиночная ссылка                      Блок
; [root:  адрес данных1] ----------> [заголовок | данные1]
;
;  Множественные ссылки                    Блок
; [root1: адрес данных2] ---------->
; [root2: адрес данных2] ----------> [заголовок | данные2]
; [root3: адрес данных2] ---------->
;
; Маркировка:
;
;    Одиночная ссылка                      Блок
; [root:  адрес данных1] <---------> [индекс root + заголовок  | данные1]
;
;  Множественные ссылки                    Блок
; [root1: адрес данных2] ----------> [индекс root3 + заголовок | данные2]
;    ↑                                      |
; [root2: индекс root1 + адрес данных2*]    |
;    ↑                                      |
; [root3: индекс root2 + адрес данных2*] <--+
;
; *сохраняются младшие разряды адреса (для поиска ячейки со ссылкой в случаях,
;  когда блок с ней сдвинут при уплотнении, см. .negative_idx: и .find_link: ).
;
; См. так же для примера: Mark-Compact GC, sliding algorithm.
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
; R10 - приравнивается RSI в начальной точке входа, более не изменяется;
; RAX - размер последнего проверенного блока (см. .compact:);
; RDX, RCX, R8, R9, R11 - не определены.
; R14 - разрушается (что не по конвенции, но при вызове из ВМ допустимо).
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
;	Случай, когда адрес равен границе неотображённой памяти, считаем валидной
;	ссылкой на частично размещённый блок (SIGSEGV сненерирован сразу после
;	размещения заголовка; например, mklist вызывает MAKEBLOCK2). Позволяет
;	скорректировать ссылку на перемещённый пустой блок. Неразмещённое
;	содержимое блока пропускается из-за ограничения индекса (см. .check_block:).
	cmp	rax, gc_end	; [heap_descriptor.uncommited]
	ja	.search_stack
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
;	Если текущая ссылка адресует уже промаркированный блок, значит
;	обработка блока выполнена ранее. Достаточно учесть текущую ссылку.
	test	rsi, Val_header[b_base - sizeof value]
	mov	b_index, Val_header[b_base - sizeof value] ; rsi
	jnz	.already_marked
;	Первичный маркер: заголовок сохраняется, добавляется индекс.
	or	Val_header[b_base - sizeof value], rdx
.check_block:
;	Проверяем тег, подлежит ли блок сканированию.
;	Блоки с тегами, начиная с No_scan_tag (251), пропускаются.
;	Infix_tag = 249, а Forward_tag (250) не используется,
;	достаточно одного сравнения.
	cmp	sil, Infix_tag
	ja	.block_searched
	jz	.infix_tag_from_stack
	from_wosize b_index
	jz	.empty_block			;; ?
;	Что бы не адресовать ячейки за пределами отображённых страниц памяти,
;	скорректируем максимальный индекс для блоков, размещённых частично.
	lea	b_index, [b_base + b_index * sizeof value]
	cmp	b_index, gc_end	; [heap_descriptor.uncommited]
	cmovnc	b_index, gc_end	; [heap_descriptor.uncommited]
	sub	b_index, b_base
	shr	b_index, 3	; / sizeof value
.search_block:
	dec	b_index
	js	.block_searched
;	Проверяем блок на наличие ссылок.
	mov	rdx, [b_base + b_index * sizeof value]
	test	rdx, 1
	jnz	.search_block
	cmp	rdx, alloc_small_ptr
	jc	.search_block
	cmp	rdx, gc_end	; [heap_descriptor.uncommited]
	jae	.search_block
;	Найдена ссылка на объект в куче. Промаркируем объект индексом ссылки.
;	Индекс ссылки, находящейся в теле блока в куче, по значению д.б. больше
;	размера стека, либо отрицательный - так они различаются на стадии уплотнения.
;	Вычисляется как расстояние (в sizeof value) от адресуемого объекта
;	до места хранения ссылки + размер стека (в sizeof value).
b_ref	equ rdx
ref_idx	equ r11
hdr	equ r14
	lea	ref_idx, [b_base + b_index * sizeof value]
	sub	ref_idx, b_ref
;	Отрицательные смещения будут обработаны особо и корректировки не требуют.
	jc	.out_of_stack
;	Сдвиги можно оптимизировать, поскольку адреса кратны 8.
;	shr	ref_idx, 3	; / 8
	lea	ref_idx, [ref_idx + s_size * sizeof value]
.out_of_stack:
	shl	ref_idx, bsr (Max_wosize+1) + wosize_shift - 3
	mov	hdr, .mark_mask
	test	hdr, Val_header[b_ref - sizeof value]
	mov	hdr, Val_header[b_ref - sizeof value]
;	Запланируем рекурсивный поиск ссылок в объекте, если он найден впервые,
;	сохранив в стеке ссылку на новый объект, и продолжим обработку текущего.
	jnz	.already_marked_block
;	Если ссылка на блок, предварённый заголовком с Infix_tag, значит имеем
;	дело с частью блока с Closure_tag, который следует обработать отдельно.
	cmp	byte[b_ref - sizeof value], Infix_tag
	jz	.infix_tag
;	(Если вложенные объекты сканировать сразу, на стеке приходится сохранять
;	b_base и b_index для каждого вложенного объекта, что приводит к затратам
;	памяти O(n) при обработке односвязных списков; в данном варианте для
;	таких списков получаем O(1), поскольку достаточно всего 1й ячейки стека.)
	push	b_ref
	or	[b_ref - sizeof value], ref_idx
	jmp	.search_block
.infix_tag:
;	Данный блок содержит 1 указатель на код, находящийся вне кучи и
;	не требующий отложенной обработки.
;	Помечаем заголовок, что бы позже скорректировать ссылку на данный блок.
	or	[b_ref - sizeof value], ref_idx
;	Необходимо пометить блок, включающий данный, запланировав сканирование
;	его содержимого на стадии уплотнения. Маркируем, заменив Closure_tag на
;	Infix_tag. Заголовок обрамляющего блока находится по отрицательному
;	смещению, по модулю равному wosize.
	from_wosize hdr
	not	hdr	; neg - 1
	mov	byte[b_ref + hdr * sizeof value], Infix_tag
	jmp	.search_block
.already_marked_block:
;	Блок уже содержит индекс ссылки - его содержимое обработано.
;	Организуем односвязный список ссылок.
;	В заголовке текущего блока сохраним новый маркер.
	xor	ref_idx, hdr
	shr	ref_idx, 64 - ..Mark_shift
	shl	ref_idx, 64 - ..Mark_shift
	xor	ref_idx, hdr
	mov	Val_header[b_ref - sizeof value], ref_idx
;	Индекс, содержищийся в заголовке, перенесём по адресу текущей ссылки.
;	Младшие разряды значения ссылки сохраним на случай .find_link:.
	mov	ref_idx, .mark_mask
	and	hdr, ref_idx
	not	ref_idx
	and	ref_idx, b_ref
	or	hdr, ref_idx
	mov	[b_base + b_index * sizeof value], hdr
	jmp	.search_block
restore	hdr
restore	ref_idx
restore	b_ref
.infix_tag_from_stack:
;	Данный блок содержит 1 указатель на код, находящийся вне кучи и
;	не требующий отложенной обработки. Его заголовок помечен до перехода.
;	Необходимо пометить блок, включающий данный, запланировав сканирование
;	его содержимого на стадии уплотнения. Маркируем, заменив Closure_tag на
;	Infix_tag. Заголовок обрамляющего блока находится по отрицательному
;	смещению, по модулю равному wosize.
	from_wosize b_index
	not	b_index	; neg - 1
	mov	byte[b_base + b_index * sizeof value], Infix_tag
.block_searched:
;	Если стек запланированных блоков пуст, рекурсивная обработка
;	блока из кучи, адресуемого ссылкой со стека ВМ, завершена.
	cmp	rsp, s_base
	jz	.search_stack
;	Иначе сканируем блоки, содержащиеся в данном и запланированные ранее.
	pop	b_base
;	Блок промаркирован, но не обработан.
	mov	b_index, not .mark_mask
	and	b_index, Val_header[b_base - sizeof value]
	jmp	.check_block
restore b_index
.already_marked:
;	rsi (b_index) содержит заголовок адресуемого блока (с прежним маркером).
;	В данном случае ссылка находится в стеке и не затрагивается уплотнением.
;	Нет необходимости сохранять младшие разряды адреса рядом с индексом.
;	Для упрощения реализации перенесём заголовок как есть.
	mov	[s_base + s_index * sizeof value], rsi
;	Маркер заменяем новым из rdx.
	shl	rsi, 64 - ..Mark_shift
	shr	rsi, 64 - ..Mark_shift
	or	rsi, rdx
	mov	[b_base - sizeof value], rsi
	jmp	.search_stack
restore b_base
restore b_size
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
	mov	rcx, rax
	jnz	.live_block
;	Блоки с Closure_tag, содержащие подлежащие обработке блоки с Infix_tag,
;	маркируются заменой тега на Infix_tag (см. .infix_tag:).
	cmp	al, Infix_tag
	jz	.closure_infix
	from_wosize rax
;	Если 0 - формируется блок, размер которого будет определён позже.
;	Такая ситуация возможна при вызове из heap_sigsegv_handler.
;	В таком случае здесь уплотнение завершаем, установив максимальный размер,
;	а частично размещённый блок обработаем в вызывающей процедуре.
	mov	ecx, Max_wosize
	cmovz	rax, rcx
;	and	eax, Max_wosize - лишнее т.к. старшие биты проверены на 0
	lea	rsi, [rsi + rax * sizeof value]
	jmp	.compact

.closure_infix:
;	Такие блоки изначально создаются CLOSUREREC.
;	Меняем тег на прежний и копируем заголовок блока.
	mov	al, Closure_tag
	stos	Val_header[alloc_small_ptr]
.closure_tail:
	from_wosize ecx
;	Далее идёт 1 указатель на код, копируем его.
	movs	qword[alloc_small_ptr], [rsi]
	dec	ecx
;	Копируем остальную часть, проверяя инфиксные блоки.
.copy_closure:
	lods	qword[rsi]
	cmp	al, Infix_tag
	jz	.copy_closure_infix
.copy_closure_element:
	stos	qword[alloc_small_ptr]
	dec	ecx
	jnz	.copy_closure
	jmp	.compact
.copy_closure_infix:
;	При наличии маркера в заголовке, следует скорректировать ссылку на блок.
	mov	rdx, .mark_mask
	test	rdx, rax
	jz	.copy_closure_element
	push	rcx
;	см. .live_block:
;	Упрощено, т.к. нет (?) отрицательных индексов и блок целиком в куче.
	mov	rcx, rax
;	Очищаем маркер и копируем заголовок блока.
	not	rdx
	and	rax, rdx
	stos	Val_header[alloc_small_ptr]
.correct_infix_link:
;	Определяем по маркеру адрес ссылки на блок.
	sar	rcx, ..Mark_shift
	zero	rdx
	cmp	rcx, s_size
	cmovnc	rdx, s_size
	lea	s_base, [rsp + 8]	; компенсируем push rcx
	cmovnc	s_base, rsi
	sub	rcx, rdx
;	Ссылка либо равна хранящейся в источнике, либо вместо неё находится
;	маркер с индексом следующей ссылки на данный блок.
	mov	rdx, [s_base + rcx * sizeof value]
	cmp	rdx, rsi
	mov	[s_base + rcx * sizeof value], alloc_small_ptr
;	Обрабатываем список ссылок, копирование блока произойдёт по его завершении.
	jnz	.next_infix_link
	pop	rcx
;	После инфиксного заголовка расположен 1 указатель на код, копируем.
	movs	qword[alloc_small_ptr], [rsi]
	sub	ecx, 2
	jnz	.copy_closure
	jmp	.compact
.next_infix_link:
	mov	rcx, rdx
	jmp	.correct_infix_link

.live_block:
;	Очищаем маркер и копируем заголовок блока.
	not	rdx
	and	rax, rdx
	stos	Val_header[alloc_small_ptr]
.correct_link:
;	Определяем по маркеру адрес ссылки на блок.
	sar	rcx, ..Mark_shift
;	Элементы с индексом s_size и выше находятся за пределами стека. Для них
;	ссылка расположена в куче и находится по смещению от копируемого блока.
;	Отрицательный индекс обрабатываем отдельно.
	js	.negative_idx
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
;	Обрабатываем список ссылок, копирование блока произойдёт по его завершении.
	jnz	.next_link
;.copy_block:
;	Если был обработан заголовок блока с Infix_tag, следует обработать
;	содержащиеся в нём инфиксы.
	cmp	byte[alloc_small_ptr - sizeof value], Infix_tag
	jz	.closure_infix_block
.copy_block:
;	Если размер 0 - формируется блок, размер которого будет определён позже.
;	Такая ситуация возможна при вызове из heap_sigsegv_handler. Обеспечим
;	копирование имеющейся части блока, установив максимальный размер.
	mov	ecx, Max_wosize
	from_wosize rax
	cmovnz	rcx, rax
;	Что бы не адресовать ячейки за пределами отображённых страниц памяти,
;	скорректируем размер для блоков, размещённых частично.
	lea	rcx, [rsi + rcx * sizeof value]
	cmp	rcx, [heap_descriptor.uncommited]
	cmovnc	rcx, [heap_descriptor.uncommited]
	sub	rcx, rsi
	shr	rcx, 3	; / sizeof value
rep	movs	qword[alloc_small_ptr], [rsi]
	jmp	.compact
.next_link:
	mov	rcx, rdx
	jmp	.correct_link
.closure_infix_block:
	mov	rcx, Val_header[alloc_small_ptr - sizeof value]
	mov	byte[alloc_small_ptr - sizeof value], Closure_tag
	jmp	.closure_tail
.negative_idx:
;	В случае отрицательного индекса объект, где следует скорректировать
;	ссылку, на данном этапе смещён в сторону младших адресов по неизвестному
;	адресу (в следствии уплотнения за счёт отброса "мёртвых" объектов).
;	Выполним поиск ячейки со ссылкой, предположив, что расстояние
;	между объектами не изменилось (на практике оно уменьшается).
;	Вместе со ссылки может храниться маркер с индексом следующей ссылки на
;	данный блок. В таком случае младшие разряды ссылки сохранены, их и будем
;	искать, сравнивая с адресом текущего блока-источника.
;	Определение типа выполним позже, после замены содержимого ячейки
;	скорректированной ссылкой.
	lea	rdx, [rdi + rcx * sizeof value]
.find_link:
	cmp	[rdx], esi	; младшая часть адреса.
	jz	.found_link
	add	rdx, sizeof value
	cmp	rdx, alloc_small_ptr	; далее находятся необработанные объекты.
	jc	.find_link
;	не найдено
.empty_block:
ud2
.found_link:
	mov	rcx, [rdx]
	mov	[rdx], alloc_small_ptr
;	В случае ссылки скопируем остаток блока.
	cmp	rcx, rsi
	jz	.copy_block
;	Маркер с индексом следующей ссылки на данный блок требует обработки
;	связного списка ссылок (см. .next_link:)
	jmp	.correct_link
.compact_end:
restore s_base
restore s_size
restore gc_end
	ret
end proc
