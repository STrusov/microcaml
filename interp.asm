; Соответствие регистров виртуальной машины регистрам процессора:
;  pc ("счётчик" инструкций)	r15
;  accu (аккумулятор)		rdx
;  extra_args			r12
;  env				r13
;
; Инициализируется адресом байткода для интерпретации.
vm_pc	equ r15

virtual at vm_pc
label	opcode:	dword
;	Аргументы опкода. Используются в обработчиках инструкций,
;	где vm_pc уже увеличен и указывает на 1й аргумент.
	.1	dd ?
	.2	dd ?
end virtual

macro next_opcode size:1
	assert size > 0 & size < 4
	lea	vm_pc, [vm_pc + size * sizeof opcode]
end macro

; Аккумулятор можно рассматривать как вершину стека вне ОЗУ.
accu	equ rdx
accud	equ edx
accub	equ dl

env		equ r13
extra_args	equ r12
extra_args_d	equ r12d

caml_trapsp	equ rbp

virtual at rsp
label	vm_sp:	qword
	.0:	dq ?
	.1:	dq ?
	.2:	dq ?
	.3:	dq ?
	.4:	dq ?
	.5:	dq ?
	.6:	dq ?
	.7:	dq ?
end virtual


; 	Адрес используется для двух целей:
;	1. Прямой переход на трамплин для вызова инструкции вирт. машины;
;	2. В трамплине для вычисления адреса инструкции вирт. машины.
vm_base	equ rbx

;	Регистры должны быть подготовлены вызывающей стороной
macro	interpreter_init
interprete:
	lea	vm_base, [execute_instruction]
	zero	extra_args
	lea	env, [Atom 0]
	mov	accud, Val_int_0
;	Оригинал сохраняет границу стека и в инструкции RAISE сравнивает c
;	caml_trapsp, что бы определить наличие установленных обработчиков
;	исключений (которые представляют собой адрес для загрузки в vm_pc).
;	Здесь для простоты используем заведомо невалидный адрес.
	pushq	0
	mov	caml_trapsp, rsp
end macro


; Размер обработчика инструкции.
instruction_size := 32
instruction_size_log2 := bsr instruction_size
assert instruction_size_log2 = bsf instruction_size	; должна быть степень 2


;	В режиме THREADED_CODE ocamlrun использует таблицу с адресами переходов
;	по 16 байт на инструкцию. Для 148-ми инструкций потенциально могут быть
;	заняты 2368 байт L1 кеша (из, к примеру, 24576 у ядра Silvermont).
;	Из-за частичной ассоциативности данные вытесняются при работе с памятью,
;	что может оказаться причиной неоправданных задержек.
;	Для решения упомянутой проблемы ocamlrun перед исполнением байт-кода
;	конвертирует номер каждой инструкции в её адрес, относительный от начала 
;	1й инструкции (т.н. шитый код, threaded code).
;
;	В данной реализации размещаем инструкции по адресам, кратным степени 2.
;	Это позволит вычислять адрес в процессе интерпретации схожим образом,
;	добавив одну команду shl.
;align_code 0x100
execute_instruction:
	mov	eax, [opcode]
	shl	rax, instruction_size_log2
;	Переход никогда не происходит. Предотвращает предсказания следующего
;	косвенного перехода, во многих случаях некорректные.
	jc	.stop
	lea	rax, [rax + vm_base + vm_base_lbl - execute_instruction]
	next_opcode
	jmp	rax
.stop:	ud2
display_num_ln 'Размер трамплина: ', $ - execute_instruction


macro Instruct_next
if ($-ELF.SECTION_BASE) mod instruction_size >= instruction_size - 16
	jmp	vm_base
else
	mov	eax, [opcode]
	shl	rax, instruction_size_log2
	lea	rax, [rax + vm_base + vm_base_lbl - execute_instruction]
	next_opcode
	jmp	rax
end if
end macro


..INSTRUCT_COUNT = 0
..INSTRUCT_IMPLEMENTED = 0
INSTRUCT_NAMES equ


macro Instruct name
;lbl_#name:
Instruct_#name:
	.instruct_name equ `name
	..INSTRUCT_COUNT = ..INSTRUCT_COUNT + 1
	INSTRUCT_NAMES equ INSTRUCT_NAMES, `name
;	display_num <.instruct_name, ' '>, $
	if ($-ELF.SECTION_BASE) mod instruction_size <> 0
		err 'Инструкции должны быть выровнены'
	end if
end macro

macro end?.Instruct!
	.end:
	; Для неопределённых инструкций требуется заглушка
	if $ = .
		mov	rdi, .instruct_name and (1 shl 64 - 1)
		if instruction_size > 16
			mov	rsi, .instruct_name shr 64 and (1 shl 64 - 1)
		end if
		jmp	undefined_instruction
	else
		..INSTRUCT_IMPLEMENTED = ..INSTRUCT_IMPLEMENTED + 1
	end if
	align_code instruction_size
;	display_num_ln ' ' , .end - .
	if $ - . <> instruction_size
		err 'Размер инструкции ', .instruct_name, ' должен соответствовать instruction_size'
	end if
	purge .instruct_name
end macro

macro Instruct_size
	display_num_ln <.instruct_name, ': '> , $ - .
end macro

macro Instruct_stub
	display 'stub '
end macro


align_code instruction_size
vm_base_lbl:

Instruct	ACC0
	mov	accu, [vm_sp.0]
	Instruct_next
Instruct_size
end Instruct


Instruct	ACC1
	mov	accu, [vm_sp.1]
	Instruct_next
end Instruct


Instruct	ACC2
	mov	accu, [vm_sp.2]
	Instruct_next
end Instruct


Instruct	ACC3
	mov	accu, [vm_sp.3]
	Instruct_next
end Instruct


Instruct	ACC4
	mov	accu, [vm_sp.4]
	Instruct_next
end Instruct


Instruct	ACC5
	mov	accu, [vm_sp.5]
	Instruct_next
end Instruct


Instruct	ACC6
	mov	accu, [vm_sp.6]
	Instruct_next
end Instruct


Instruct	ACC7
	mov	accu, [vm_sp.7]
	Instruct_next
end Instruct


Instruct	ACC
	mov	eax, [opcode.1]
	next_opcode
	mov	accu, [vm_sp + rax * sizeof vm_sp]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSH_ ; идентична PUSHACC0
	push	accu
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC0
	push	accu
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC1
	push	accu
	mov	accu, [vm_sp.1]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC2
	push	accu
	mov	accu, [vm_sp.2]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC3
	push	accu
	mov	accu, [vm_sp.3]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC4
	push	accu
	mov	accu, [vm_sp.4]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC5
	push	accu
	mov	accu, [vm_sp.5]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC6
	push	accu
	mov	accu, [vm_sp.6]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC7
	push	accu
	mov	accu, [vm_sp.7]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHACC
	push	accu
	mov	eax, [opcode.1]
	next_opcode
	mov	accu, [vm_sp + rax * sizeof vm_sp]
	Instruct_next
Instruct_size
end Instruct


Instruct	POP_
	mov	eax, [opcode.1]
	next_opcode
	lea	rsp, [rsp+rax*8]
	Instruct_next
Instruct_size
end Instruct


Instruct	ASSIGN
	mov	eax, [opcode.1]
	next_opcode
	mov	[rsp + rax * sizeof value], accu
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct


Instruct	ENVACC1
	mov	accu, [env + 1 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	ENVACC2
	mov	accu, [env + 2 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	ENVACC3
	mov	accu, [env + 3 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	ENVACC4
	mov	accu, [env + 4 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


macro envacc
	mov	eax, [opcode.1]
	mov	accu, [env + rax * sizeof value]
	next_opcode
end macro


Instruct	ENVACC
	envacc
	Instruct_next
end Instruct


Instruct	PUSHENVACC1
	push	accu
	mov	accu, [env + 1 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHENVACC2
	push	accu
	mov	accu, [env + 2 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHENVACC3
	push	accu
	mov	accu, [env + 3 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHENVACC4

end Instruct


Instruct	PUSHENVACC
	push	accu
	envacc
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSH_RETADDR
	lea	rax, [extra_args * 2 + 1]
	push	rax
	push	env
	movsxd	rax, [opcode.1]
	lea	rax, [opcode.1 + rax * sizeof opcode]
	push	rax
	next_opcode
	Instruct_next
Instruct_size
end Instruct


Instruct	APPLY
	mov	extra_args_d, [opcode.1]
	dec	extra_args_d
	mov	vm_pc, [accu]
	mov	env, accu
	Instruct_next
end Instruct


Instruct	APPLY1
	pop	rax
	Val_int	extra_args
	push	extra_args
	push	env
	push	vm_pc
	push	rax
	mov	vm_pc, [accu]
	mov	env, accu
	zero	extra_args
	Instruct_next
Instruct_size
end Instruct


Instruct	APPLY2
	pop	rax
	pop	rcx
	Val_int	extra_args
	push	extra_args
	push	env
	push	vm_pc
	push	rcx
	push	rax
	mov	extra_args, 1
.pc:	mov	vm_pc, [accu]
	mov	env, accu
	Instruct_next
Instruct_size
end Instruct


Instruct	APPLY3
	pop	rax
	pop	rcx
	pop	r8
	Val_int	extra_args
	push	extra_args
	push	env
	push	vm_pc
	push	r8
	push	rcx
	push	rax
	mov	extra_args, 2
	jmp	Instruct_APPLY2.pc
Instruct_size
end Instruct


Instruct	APPTERM
	mov	ecx, [opcode.1]	; количество аргументов
	mov	eax, [opcode.2]	; размер слота
	sub	eax, ecx
	dec	ecx
	lea	extra_args, [extra_args + rcx]
	lea	rax, [rsp + rax * sizeof value]
.copy:	mov	rsi, [rsp + rcx * sizeof value]
	mov	[rax + rcx * sizeof value], rsi
	jmp	..APPTERM_tail
Instruct_size
end Instruct


Instruct	APPTERM1
	pop	rcx
	mov	eax, [opcode.1]
	lea	vm_sp, [vm_sp + (rax - 1) * sizeof value]
	push	rcx
.br:	mov	vm_pc, [accu]
	mov	env, accu
	Instruct_next
..APPTERM_tail:
	dec	ecx
	jns	Instruct_APPTERM.copy
	mov	rsp, rax
	jmp	.br
Instruct_size
end Instruct


Instruct	APPTERM2
	pop	rcx rsi
	mov	eax, [opcode.1]
	lea	vm_sp, [vm_sp + (rax - 2) * sizeof value]
	push	rsi rcx
	mov	vm_pc, [accu]
	mov	env, accu
	inc	extra_args
	Instruct_next
Instruct_size
end Instruct


Instruct	APPTERM3
	pop	rcx rsi r8
	mov	eax, [opcode.1]
	lea	vm_sp, [vm_sp + (rax - 3) * sizeof value]
	push	r8 rsi rcx
	mov	vm_pc, [accu]
	mov	env, accu
	add	extra_args, 2
	Instruct_next
Instruct_size
end Instruct


Instruct	RETURN
	mov	eax, [opcode.1]
	next_opcode
	lea	vm_sp, [vm_sp + rax * sizeof value]
	test	extra_args, extra_args
	jnz	.extra_args
	pop	vm_pc
	pop	env
	pop	extra_args
	Long_val extra_args
	Instruct_next
.extra_args:
	dec	extra_args
	jmp	Instruct_APPTERM1.br
Instruct_size
end Instruct


Instruct	RESTART
	mov	rcx, Val_header[env - sizeof value]
	from_wosize ecx
	sub	ecx, 2
	add	extra_args, rcx
.@:	push	[env + (2 + rcx - 1) * sizeof value]
	loopnz	.@
	mov	env, [env + 1 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	GRAB
	mov	eax, [opcode.1]
	next_opcode
	sub	extra_args, rax
	jc	GRAB_extra
	Instruct_next
Instruct_size
end Instruct


; Замыкание.
; Размер 3. Аргументы опкода:
; 1. Количество аргументов замыкания;
; 2. Относительный адрес замыкания (смещение для счётчика инструкций).
Instruct	CLOSURE
	jmp	CLOSURE_impl
Instruct_size
end Instruct


; Рекурсивное замыкание.
; Переменный размер:
; 1. Количество функторов;
; 2. Количество аргументов замыкания;
; 3.. функторы;
;     адрес замыкания.
Instruct	CLOSUREREC
	jmp	CLOSUREREC_impl
Instruct_size
end Instruct


Instruct	OFFSETCLOSUREM2

end Instruct


Instruct	OFFSETCLOSURE0

end Instruct


Instruct	OFFSETCLOSURE2

end Instruct


Instruct	OFFSETCLOSURE

end Instruct


Instruct	PUSHOFFSETCLOSUREM2

end Instruct


Instruct	PUSHOFFSETCLOSURE0
	push	accu
	mov	accu, env
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHOFFSETCLOSURE2

end Instruct


Instruct	PUSHOFFSETCLOSURE
	push	accu
	movsxd	accu, [opcode.1]
	next_opcode
	lea	accu, [env + accu * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	GETGLOBAL
;	Может ли поле иметь отрицательное смещение?
	mov	eax, [opcode.1]
	next_opcode
	mov	accu, [caml_global_data]
	mov	accu, [accu + rax * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHGETGLOBAL
	push	accu
	jmp	Instruct_GETGLOBAL
Instruct_size
end Instruct


Instruct	GETGLOBALFIELD
;	Может ли поле иметь отрицательное смещение?
	mov	eax, [opcode.1]
	mov	accu, [caml_global_data]
	mov	accu, [accu + rax * sizeof value]
	mov	eax, [opcode.2]
	mov	accu, [accu + rax * sizeof value]
	next_opcode 2
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHGETGLOBALFIELD
	push	accu
	jmp	Instruct_GETGLOBALFIELD
Instruct_size
end Instruct


; Замечания при отладке.
; Для простейшей программы, выводящей в цикле конкатенацию 2-х строк:
; 1. При первом вызове инструкции не наблюдается лишних блоков в куче.
; 2. При втором уплотняет кучу на 3 ячейки (24 байт).
; 3. Вызов происходит после вывода части (до сброса буфера канала) строк.
; Блок содержит 2 ссылки на статичную часть кучи (на строки "Привет" и "Мир").
; Остальные объекты в куче (строки) очищаются.
; 4. Параметром передаётся Atom(0)
;
; Семантика глобальных объектов подразумевает, что они живут до завершения
; приложения. В таком случае, динамичную часть кучи следует располагать за ними.
Instruct	SETGLOBAL
Instruct_stub
;	caml_modify(&Field(caml_global_data, *pc), accu);
if HEAP_GC
	push	accu
	call	heap_mark_compact_gc
	pop	accu
end if
	mov	eax, [opcode.1]
	next_opcode
	mov	rcx, [caml_global_data]
	mov	[rcx + rax * sizeof value], accu
	mov	accud, Val_unit
if HEAP_GC
	jmp	..heap_set_gc_start
else
	Instruct_next
end if
Instruct_size
end Instruct


Instruct	ATOM0
;	адрес за заголовком
	lea	accu, [Atom 0]
if HEAP_GC
	jmp	.next
..heap_set_gc_start:
	heap_set_gc_start_address
end if
.next:	Instruct_next
Instruct_size
end Instruct


Instruct	ATOM

end Instruct


Instruct	PUSHATOM0

end Instruct


Instruct	PUSHATOM

end Instruct


; При размещении блока, во время копирования значений со стека на кучу,
; возможен вызов сборщика мусора. Поскольку значения могут представлять собой
; ссылки на объекты (живые), их необходимо сохранять в стеке до завершения
; формирования блока. Кроме того, необходимо сохранить ссылку на формируемый
; блок, что бы скорректировать те ссылки, что уже размещены в блоке.
; Копирование выполняем инструкцией movs: при вызове сборщика мусора исходное
; значение может быть изменено, модификация и окажется скопирована в приёмник
; при возврате из обработчика прерывания.
Instruct	MAKEBLOCK
	mov	ecx, [opcode.1]		; wosize
	mov	eax, ecx
	to_wosize	eax
	or	eax, [opcode.2]		; tag
	next_opcode	2
;	Сохраняем возможную ссылку для учёта сборщиком мусора.
	push	accu
	stos	Val_header[alloc_small_ptr]
	mov	rsi, rsp
;	Сохраняем адрес блока для корректировки скопированных ссылок сборщиком мусора.
	push	alloc_small_ptr
rep	movs	qword[alloc_small_ptr], [rsi]
	pop	accu	; адрес блока (за заголовком) скорректирован сборщиком мусора
	mov	rsp, rsi
	Instruct_next
Instruct_size
end Instruct


Instruct	MAKEBLOCK1
	mov	eax, [opcode.1]	; tag
	next_opcode
	or	eax, 1 wosize
;	Сохраняем возможную ссылку для учёта сборщиком мусора.
;	Адрес блока сохранять не требуется, так как тело блока, состоящее из
;	одного элемента, изменится "атомарно".
	push	accu
	stos	Val_header[alloc_small_ptr]
	mov	rsi, rsp
	movs	qword[alloc_small_ptr], [rsi]
	mov	rsp, rsi
	lea     accu, [alloc_small_ptr - 1 * sizeof value]      ; Адрес блока (за заголовком).
	Instruct_next
Instruct_size
end Instruct


; Сборка мусора может быть вызвана, когда в блоке размещён первый элемент,
; являющийся ссылкой (такие создаёт mkleftlist). Что бы обеспечить
; обработку таких ссылок, сохраняем адрес формируемого блока в стеке.
Instruct	MAKEBLOCK2
	mov	eax, [opcode.1]	; tag
	next_opcode
	or	eax, 2 wosize
;	Сохраняем возможную ссылку для учёта сборщиком мусора.
	push	accu
	stos	Val_header[alloc_small_ptr]
	mov	rsi, rsp
;	Сохраняем адрес блока (иначе при mkleftlist его содержимое оставалось
;	без корректировки)
	push	alloc_small_ptr
	movs	qword[alloc_small_ptr], [rsi]
	movs	qword[alloc_small_ptr], [rsi]
	pop	accu	; адрес блока (за заголовком) скорректирован сборщиком мусора
	mov	rsp, rsi
	Instruct_next
Instruct_size
end Instruct


Instruct	MAKEBLOCK3
	mov	eax, [opcode.1]	; tag
	next_opcode
	or	eax, 3 wosize
;	Сохраняем возможную ссылку для учёта сборщиком мусора.
	push	accu
	stos	Val_header[alloc_small_ptr]
	mov	rsi, rsp
;	Сохраняем адрес блока (иначе при mkleftlist его содержимое оставалось
;	без корректировки)
	push	alloc_small_ptr
	movs	qword[alloc_small_ptr], [rsi]
	movs	qword[alloc_small_ptr], [rsi]
	movs	qword[alloc_small_ptr], [rsi]
	pop	accu	; адрес блока (за заголовком) скорректирован сборщиком мусора
	mov	rsp, rsi
	Instruct_next
Instruct_size
end Instruct


; Процедура читает со стека ссылки на вещественные числа и переносит значения
; в создаваемый блок. Внутри блока сборщику мусора учитывать нечего.
Instruct	MAKEFLOATBLOCK
	jmp	MAKEFLOATBLOCK_impl
end Instruct


Instruct	GETFIELD0
	mov	accu, [accu + 0 * sizeof value]
	Instruct_next
end Instruct


Instruct	GETFIELD1
	mov	accu, [accu + 1 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	GETFIELD2
	mov	accu, [accu + 2 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	GETFIELD3
	mov	accu, [accu + 3 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	GETFIELD
	mov	eax, [opcode.1]
	next_opcode
	mov	accu, [accu + rax * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	GETFLOATFIELD
	mov	eax, 1 wosize + Double_tag
	stos	Val_header[alloc_small_ptr]
	mov	eax, [opcode.1]
	next_opcode
	mov	rax, [accu + rax * sizeof value]
	stos	qword[alloc_small_ptr]
	lea	accu, [alloc_small_ptr - sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	SETFIELD0
	pop	rax
	mov	[accu + 0 * sizeof value], rax
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct


Instruct	SETFIELD1
	pop	rax
	mov	[accu + 1 * sizeof value], rax
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct


Instruct	SETFIELD2
	pop	rax
	mov	[accu + 2 * sizeof value], rax
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct


Instruct	SETFIELD3
	pop	rax
	mov	[accu + 3 * sizeof value], rax
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct


Instruct	SETFIELD
	pop	rax
	mov	ecx, [opcode.1]
	next_opcode
	mov	[accu + rcx * sizeof value], rax
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct


Instruct	SETFLOATFIELD

end Instruct


Instruct	VECTLENGTH
	mov	accu, Val_header[accu - sizeof value]
	from_wosize accu
	Val_int	accu
	Instruct_next
Instruct_size
end Instruct


Instruct	GETVECTITEM
	pop	rcx	; индекс элемента
	Int_val	rcx
	mov	accu, [accu + rcx * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	SETVECTITEM
;	caml_modify
	pop	rcx	; индекс элемента
	Int_val	rcx
	pop	rax
	mov	[accu + rcx * sizeof value], rax
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct


Instruct	GETSTRINGCHAR
	pop	rcx	; индекс в строке
	Int_val	rcx
	movzx	accud, byte[accu + rcx]
	Val_int	accud
	Instruct_next
Instruct_size
end Instruct


Instruct	SETSTRINGCHAR
	pop	rcx	; индекс в строке
	pop	rax	; символ
	Int_val	rcx
	Int_val	eax
	mov	[accu + rcx], al
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct

; Переходы, в том числе условные

Instruct	BRANCH
	movsxd	rax, [opcode.1]
	lea	vm_pc, [opcode.1 + rax * sizeof opcode]
	Instruct_next
Instruct_size
end Instruct


Instruct	BRANCHIF
	cmp	accu, Val_false
	movsxd	rax, [opcode.1]
	lea	rax, [opcode.1 + rax * sizeof opcode]
	next_opcode
	cmovnz	vm_pc, rax
	Instruct_next
Instruct_size
end Instruct


Instruct	BRANCHIFNOT
	cmp	accu, Val_false
	movsxd	rax, [opcode.1]
	lea	rax, [opcode.1 + rax * sizeof opcode]
	next_opcode
	cmovz	vm_pc, rax
	Instruct_next
Instruct_size
end Instruct


Instruct	SWITCH
	jmp	SWITCH_impl
end Instruct


Instruct	BOOLNOT
;	В оригинале используется вычитание из 4.
;	Здесь считаем все отличные от Val_false значения как Val_true.
	cmp	accu, Val_false
	mov	accud, Val_false
	mov	eax, Val_true
	cmove	accud, eax
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHTRAP
	movsxd	rax, [opcode.1]
	lea	rax, [vm_pc + rax * sizeof opcode]
	next_opcode
	mov	rcx, extra_args
	Val_int rcx
	push	rcx
	push	env
	push	caml_trapsp
	push	rax
	mov	caml_trapsp, rsp
	Instruct_next
Instruct_size
end Instruct


Instruct	POPTRAP
Instruct_stub
;	Должна быть проверка caml_something_to_do
	mov	caml_trapsp, [vm_sp.1]
	lea	rsp, [vm_sp.4]
	Instruct_next
Instruct_size
end Instruct


; Вызывается так же из caml_raise (см. fail.asm)
Instruct	RAISE
	mov	rsp, caml_trapsp
	pop	vm_pc
	test	vm_pc, vm_pc
;	В оригинале происходит выход из функции интерпретатора, с установкой
;	признака исключения в accu. Здесь проще вызвать процедуру напрямую.
	jz	caml_fatal_uncaught_exception
	pop	caml_trapsp
	pop	env
	pop	extra_args
	Int_val	extra_args
	Instruct_next
Instruct_size
end Instruct


Instruct	CHECK_SIGNALS
Instruct_stub
	;       if (caml_something_to_do) goto process_signal;
	Instruct_next
Instruct_size
end Instruct

; Вызов С функций

Instruct	C_CALL1
	mov	eax, [opcode.1]
	next_opcode
	mov	alloc_small_ptr_backup, alloc_small_ptr	; rdi
	mov	rdi, accu	; 1й
	jmp	Instruct_C_CALL2.exec
Instruct_size
end Instruct


Instruct	C_CALL2
	pop	rsi		; 2й
	jmp	Instruct_C_CALL1

.exec:	movzx	eax, [caml_builtin_cprim + rax*sizeof caml_builtin_cprim]
	add	rax, C_primitive_first
	call	rax
	mov	accu, rax
	mov	alloc_small_ptr, alloc_small_ptr_backup	; rdi
	Instruct_next
Instruct_size
end Instruct


Instruct	C_CALL3
	mov	eax, [opcode.1]
	next_opcode
	mov	alloc_small_ptr_backup, alloc_small_ptr	; rdi
	mov	rdi, accu	; 1й
	pop	rsi		; 2й
	pop	rdx		; 3й (accu)
	jmp	Instruct_C_CALL2.exec
Instruct_size
end Instruct


Instruct	C_CALL4
	mov	eax, [opcode.1]
	next_opcode
	mov	alloc_small_ptr_backup, alloc_small_ptr	; rdi
	mov	rdi, accu	; 1й
	pop	rsi		; 2й
	pop	rdx		; 3й (accu)
	pop	rcx		; 4й
	jmp	Instruct_C_CALL2.exec
Instruct_size
end Instruct


Instruct	C_CALL5
	mov	eax, [opcode.1]
	next_opcode
	mov	alloc_small_ptr_backup, alloc_small_ptr	; rdi
	mov	rdi, accu	; 1й
	pop	rsi		; 2й
	pop	rdx		; 3й (accu)
	pop	rcx		; 4й
	pop	r8		; 5й
	jmp	Instruct_C_CALL2.exec
Instruct_size
end Instruct


Instruct	C_CALLN

end Instruct

; Целочисленные константы

Instruct	CONST0
	mov	accu, Val_int 0
	Instruct_next
Instruct_size
end Instruct


Instruct	CONST1
	mov	accu, Val_int 1
	Instruct_next
Instruct_size
end Instruct


Instruct	CONST2
	mov	accu, Val_int 2
	Instruct_next
Instruct_size
end Instruct


Instruct	CONST3
	mov	accu, Val_int 3
	Instruct_next
Instruct_size
end Instruct


Instruct	CONSTINT
	movsxd	accu, [opcode]
	lea	accu, [Val_int accu]
	next_opcode
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHCONST0
	push	accu
	mov	accud, Val_int 0
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHCONST1
	push	accu
	mov	accud, Val_int 1
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHCONST2
	push	accu
	mov	accud, Val_int 2
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHCONST3
	push	accu
	mov	accud, Val_int 3
	Instruct_next
Instruct_size
end Instruct


Instruct	PUSHCONSTINT
	push	accu
;Instruct	CONSTINT
	movsxd	accu, [opcode]
	lea	accu, [Val_int accu]
	next_opcode
	Instruct_next
Instruct_size
end Instruct


Instruct	NEGINT
	neg	accu
	add	accu, 2
	Instruct_next
Instruct_size
end Instruct


Instruct	ADDINT
	pop	rax
	lea	accu, [accu + rax - 1]
	Instruct_next
Instruct_size
end Instruct


Instruct	SUBINT
	pop	rax
	sub	accu, rax
	add	accu, 1
	Instruct_next
Instruct_size
end Instruct


Instruct	MULINT
	pop	rcx
	Int_val rcx
	Int_val accu
	imul	accu, rcx
	Val_int	accu
	Instruct_next
end Instruct


Instruct	DIVINT
;	Проверку делителя на 0 не выполняем, но надо бы обработать исключение.
	pop	rcx
	sar	rcx, 1
	mov	rax, accu
	sar	rax, 1
	cqo
	idiv	rcx
	lea	accu, [rax * 2 + 1]
	Instruct_next
Instruct_size
end Instruct


Instruct	MODINT
;	Проверку делителя на 0 не выполняем, но надо бы обработать исключение.
	pop	rcx
	sar	rcx, 1
	mov	rax, accu
	sar	rax, 1
	cqo
	idiv	rcx
	lea	accu, [rdx * 2 + 1]
	Instruct_next
end Instruct


Instruct	ANDINT
	pop	rcx
	and	accu, rcx
	Instruct_next
Instruct_size
end Instruct


Instruct	ORINT
	pop	rcx
	or	accu, rcx
	Instruct_next
Instruct_size
end Instruct


Instruct	XORINT
	pop	rcx
	xor	accu, rcx
	Instruct_next
Instruct_size
end Instruct


Instruct	LSLINT
	pop	rcx
	Int_val	rcx
	dec	accu
	shl	accu, cl
	or	accu, Val_int_0
	Instruct_next
Instruct_size
end Instruct


Instruct	LSRINT
	pop	rcx
	Int_val	rcx
	shr	accu, cl
	or	accu, Val_int_0
	Instruct_next
Instruct_size
end Instruct


Instruct	ASRINT
	pop	rcx
	Int_val	rcx
	sar	accu, cl
	or	accu, Val_int_0
	Instruct_next
Instruct_size
end Instruct


macro INTcc condition
	pop	rax
	cmp	accu, rax
	mov	eax, Val_true
	mov	accud, Val_false
	cmov#condition	accud, eax
end macro


Instruct	EQ
	INTcc	E
	Instruct_next
Instruct_size
end Instruct


Instruct	NEQ
	INTcc	NE
	Instruct_next
Instruct_size
end Instruct


Instruct	LTINT
	INTcc	L
	Instruct_next
Instruct_size
end Instruct


Instruct	LEINT
	INTcc	LE
	Instruct_next
Instruct_size
end Instruct


Instruct	GTINT
	INTcc	G
	Instruct_next
Instruct_size
end Instruct


Instruct	GEINT
	INTcc	GE
	Instruct_next
Instruct_size
end Instruct


Instruct	OFFSETINT
	movsxd	rax, [opcode.1]
	next_opcode
	lea	accu, [accu + rax*2]
	Instruct_next
Instruct_size
end Instruct


Instruct	OFFSETREF
	movsxd	rax, [opcode.1]
	next_opcode
	add	rax, rax
	add	[accu + 0 * sizeof value], rax
	mov	accu, Val_unit
	Instruct_next
Instruct_size
end Instruct


Instruct	ISINT
	and	accu, 1
	Val_int	accu
	Instruct_next
Instruct_size
end Instruct


Instruct	GETMETHOD

end Instruct


macro BccINT condition
	movsxd	rax, [opcode.1]
	Long_val accu
	cmp	rax, accu
	movsxd	rax, [opcode.2]
	lea	rax, [opcode.2 + rax * sizeof opcode]
	next_opcode 2
	cmov#condition	vm_pc, rax
end macro


Instruct	BEQ
	BccINT	E
	Instruct_next
Instruct_size
end Instruct


Instruct	BNEQ
	BccINT	NE
	Instruct_next
Instruct_size
end Instruct


Instruct	BLTINT
	BccINT	L
	Instruct_next
Instruct_size
end Instruct


Instruct	BLEINT
	BccINT	LE
	Instruct_next
Instruct_size
end Instruct


Instruct	BGTINT
	BccINT	G
	Instruct_next
Instruct_size
end Instruct


Instruct	BGEINT
	BccINT	GE
	Instruct_next
Instruct_size
end Instruct


Instruct	ULTINT

end Instruct


Instruct	UGEINT

end Instruct


purge INTcc


Instruct	BULTINT
	BccINT	NAE
	Instruct_next
Instruct_size
end Instruct


Instruct	BUGEINT
	BccINT	AE	; nc
	Instruct_next
Instruct_size
end Instruct


purge BccINT


Instruct	GETPUBMET
Instruct_stub
	mov	rax, [accu + 0 * sizeof value]
	push	accu
	mov	accud, [opcode.1]
	Val_int	accud
	mov	ecx, [opcode.2]
	next_opcode 2
	and	ecx, [rax + 1 * sizeof value]
;	cmp	accud, [rax + 3 * sizeof value + rcx]
;	jnz	.not_cached
	mov	accu, [rax + 2 * sizeof value + rcx]
	Instruct_next
Instruct_size
.not_cached:
end Instruct


Instruct	GETDYNMET

end Instruct


Instruct	STOP
	mov	rdi, accu
	jmp	caml_sys_exit
end Instruct


Instruct	EVENT

end Instruct


Instruct	BREAK

end Instruct


Instruct	RERAISE

end Instruct


Instruct	RAISE_NOTRACE

end Instruct


SWITCH_impl:
	movzx	ecx, word[opcode.1]
	next_opcode
	mov	rax, accu
	Int_val	rax
	test	accud, 1
	jnz	.int
	movzx	eax, byte[accu - sizeof value]	; тег
	add	eax, ecx
.int:	mov	eax, [vm_pc + rax * sizeof opcode]
	lea	vm_pc, [vm_pc + rax * sizeof opcode]
	Instruct_next
display_num_ln "SWITCH_impl: ", $-SWITCH_impl


; Процедура читает со стека ссылки на вещественные числа и переносит значения
; в создаваемый блок. Внутри блока сборщику мусора учитывать нечего.
MAKEFLOATBLOCK_impl:
	mov	ecx, [opcode.1]	; кол-во
	next_opcode
	mov	eax, ecx
	to_wosize rax
	or	rax, Double_array_tag
;	Сохраняем ссылку для учёта сборщиком мусора.
	push	accu
	stos	Val_header[alloc_small_ptr]
;	Читаем со стека ссылки на числа и переносим значения в кучу.
;	Стек оставляем до конца формирования блока на случай сборки мусора.
	mov	rsi, rsp
;	Можно было бы сохранить alloc_small_ptr на стеке, что бы не вычислять далее,
;	блок с Double_array_tag не сканируется. Однако, уложиться в 32 байта не удаётся.
	mov	accud, ecx
.cp:	lods	qword[rsi]
	mov	rax, [rax]
	stos	qword[alloc_small_ptr]
	dec	ecx
	jnz	.cp
	mov	rsp, rsi
	neg	accu
	lea	accu, [alloc_small_ptr + accu * sizeof value]
	Instruct_next
display_num_ln "MAKEFLOATBLOCK_impl: ", $-MAKEFLOATBLOCK_impl


GRAB_extra:
	lea	rcx, [extra_args + rax + 1]
	add	eax, 2
	to_wosize rax
	or	rax, Closure_tag
	stos	Val_header[alloc_small_ptr]
	mov	rsi, rsp
	push	alloc_small_ptr
	lea	rax, [vm_pc - 3 * sizeof opcode]
	stos	qword[alloc_small_ptr]	; 0-е поле
	mov	rax, env
	stos	qword[alloc_small_ptr]	; 1-е поле
rep	movs	qword[alloc_small_ptr], [rsi]
	pop	accu
	mov	rsp, rsi
	pop	vm_pc
	pop	env
	pop	extra_args
	Int_val	extra_args
	Instruct_next
display_num_ln "GRAB_extra: ", $-GRAB_extra

; При размещении блока, во время копирования аргументов замыкания со стека на кучу,
; возможен вызов сборщика мусора. Поскольку эти значения могут представлять собой
; ссылки на объекты (живые), их необходимо сохранять в стеке до завершения
; формирования блока. Так же и адрес блока д.б. вычислен на завершающей стадии.
; Так же сохраняем на стеке адрес блока, что позволит сборщику мусора
; скорректировать уже скопированные в тело блока ссылки. (см. MAKEBLOCK)
CLOSURE_impl:
	mov	ecx, [opcode.1]	; Количество аргументов замыкания.
	jecxz	.no_arg
	push	accu	; 1й аргумент для дальнейшего копирования.
.no_arg:
	lea	eax, [ecx+1]
	to_wosize	eax 
	or	eax, Closure_tag
	stos	Val_header[alloc_small_ptr]
	movsxd	rax, [opcode.2]
	lea	rax, [opcode.2 + rax * sizeof opcode]
;	Копируем аргументы замыкания со стека.
	mov	rsi, rsp
;	Сохраняем адрес блока для корректировки скопированных ссылок сборщиком мусора.
	push	alloc_small_ptr
;	Сохраняем указатель на байт-код замыкания (pc + *pc).
	stos	qword[alloc_small_ptr]
rep	movs	qword[alloc_small_ptr], [rsi]
	pop	accu	; адрес блока (за заголовком) скорректирован сборщиком мусора
	mov	rsp, rsi
	next_opcode 2
	Instruct_next
display_num_ln "CLOSURE_impl: ", $-CLOSURE_impl


; В данном случае формирование блока после заголовка происходит в два этапа:
; 1. Копирование аргументов со стека - в конец блока. Поскольку их значения
;    могут представлять собой ссылки на объекты (живые), их необходимо
;    сохранять в стеке до завершения формирования блока.
; 2. Создание инфиксных блоков с размещением указателей на них на стеке.
; Для обеспечения корректировки скопированных в тело блока ссылок, сохраняем
; адрес блока на стеке.
CLOSUREREC_impl:
	mov	eax, [opcode.1]	; Количество функторов.
	mov	ecx, [opcode.2]	; Количество аргументов замыкания.
;		следом идут смещения для vm_pc (nfuncs шт.); вычисленный адрес
;		переносится в хранилище, за ним аргументы (снимаются со стека)
	lea	esi, [2*rax-1]
	lea	eax, [2*rax+rcx-1]
	to_wosize eax
	or	eax, Closure_tag
	stos	Val_header[alloc_small_ptr]
	mov	rax, rsi
;	Если есть аргументы, первый из них в аккумуляторе. Копируем к остальным.
	jecxz	.noarg
	push	accu
.noarg:	mov	rsi, rsp
;	Сохраняем адрес блока для корректировки скопированных ссылок сборщиком мусора.
	push	alloc_small_ptr
;	Адрес за блоками инфиксов (1й из них без заголовка)
	lea	alloc_small_ptr, [alloc_small_ptr + rax * sizeof value]
rep	movs	qword[alloc_small_ptr], [rsi]
	pop	accu	; адрес блока (за заголовком) скорректирован сборщиком мусора
	mov	rsp, rsi
	mov	rsi, alloc_small_ptr	; временно храним адрес за блоком
	mov	alloc_small_ptr, accu
;	Копируем указатели на код, предваряя их инфиксными заголовками, кроме 1го.
;	Такие указатели не могут быть ссылками на кучу, соответственно
;	не учитываются сборщиком мусора. Однако: Infix_tag < No_scan_tag - ???
	zero	ecx
	mov	r8d, [opcode.1]
	next_opcode 2
	jmp	.cpp
.cpi:	mov	eax, ecx
;	to_wosize eax * 2
	shl	eax, wosize_shift + 1
	or	eax, Infix_tag
	stos	qword[alloc_small_ptr]
;	Вызов сборщика мусора возможен в случае, если количество аргументов
;	замыкания нулевое (иначе он произошёл бы выше). Данное сохранение адреса
;	(в первой итерации цикла) на стеке должно обеспечить его безопасность.
.cpp:	push	alloc_small_ptr
	movsxd	rax, [vm_pc + rcx * sizeof opcode]
	lea	rax, [vm_pc + rax * sizeof opcode]
	stos	qword[alloc_small_ptr]
	inc	ecx
	cmp	ecx, r8d
	jc	.cpi
;	next_opcode r8
	lea	vm_pc, [vm_pc + r8 * sizeof opcode]
	mov	alloc_small_ptr, rsi
	Instruct_next	
display_num_ln "CLOSUREREC_impl: ", $-CLOSUREREC_impl


vm_end_lbl:


display_num "Реализовано инструкций виртуальной машины: ", ..INSTRUCT_IMPLEMENTED
display_num_ln " из ", ..INSTRUCT_COUNT
display_num_ln "Занимают байт: ", vm_end_lbl - vm_base_lbl

; Выводим наименование (в регистре RDI) неимплементированной инструкции.
proc undefined_instruction
	pushq	0
	if instruction_size > 16
		push	rsi
	end if
	push	rdi
	puts	rsp 
	jmp	main.invalid_bytecode
end proc


; Завершение работы при возникновении исключения.
; RDX - адрес пары значений, содержащей информацию об исключении.
proc caml_fatal_uncaught_exception
;	Регистрация обработчиков непойманых исключений пока не реализована.
;	Вызываем обработчик по умолчанию.
;
;	Формируем строку с информацией об исключении.
;	Обнуляем длину на случай уплотнения кучи. Корректировка не потребуется.
	mov	eax, String_tag
	stos	Val_header[alloc_small_ptr]
	push	alloc_small_ptr
	lea	rsi, [msg_fatal_error]
	mov	ecx, msg_fatal_error.size
rep	movs	byte[alloc_small_ptr], [rsi]
;	caml_format_exception()
;	Форматируем информацию об исключении.
	cmp	byte[rdx - sizeof value], 0	; Тег
	jz	.fmt
ud2	;add_string(&buf, String_val(Field(exn, 0)));
.fmt:;	Получаем адрес строки вида 'Assert_failure'
	mov	rsi, [rdx]
	mov	rsi, [rsi]	; String_val(Field(Field(exn, 0), 0)
;	и добавляем её к текущему сообщению.
	caml_string_length	rsi, rcx, rax
rep	movs	byte[alloc_small_ptr], [rsi]
	mov	al, '('
	stos	byte[alloc_small_ptr]
;	Особые варианты Match_failure и Assert_failure
	mov	rax, Val_header[rdx - sizeof value]
	cmp	eax, 2 wosize
	jnz	.ord_exn
;	Используем регистры, неизменяемые вызываемой процедурой.
;	Для ВМ в данной точке они более не актуальны.
bucket	equ rbx
start	equ r12
	zero	start
	mov	bucket, [rdx + 1 * sizeof value]
	test	bucket , 1		; Блок?
	jnz	.ord_exn
	cmp	byte[bucket - sizeof value], 0	; Тег
	jnz	.ord_exn
	mov	rcx, [caml_global_data]
	mov	rax, [rdx]
	cmp	rax, [rcx + MATCH_FAILURE_EXN * sizeof value]
	jz	.fmt_exn
	cmp	rax, [rcx + ASSERT_FAILURE_EXN * sizeof value]
	jz	.fmt_exn
	cmp	rax, [rcx + UNDEFINED_RECURSIVE_MODULE_EXN * sizeof value]
	jz	.fmt_exn
.ord_exn:
	mov	bucket, rdx
	inc	start
.fmt_exn:
	mov	r13, Val_header[bucket - sizeof value]
	from_wosize r13
	cmp	start, r13
	ja	.close
.elem:	mov	rsi, [bucket + start * sizeof value]
	test	rsi, 1
	jz	.block
;	Форматируем знаковое целое.
	mov	alloc_small_ptr_backup, alloc_small_ptr
	call	format_int_dec
	lea	alloc_small_ptr, [alloc_small_ptr_backup + rax]
	jmp	.next
.block:	cmp	byte[rsi - sizeof value], String_tag
	jnz	.any
	mov	al, '"'
	stos	byte[alloc_small_ptr]
	caml_string_length rsi, rcx, rax
rep	movs	byte[alloc_small_ptr], [rsi]
	mov	al, '"'
	stos	byte[alloc_small_ptr]
	jmp	.next
.any:	mov	al, '_'
	stos	byte[alloc_small_ptr]
.next:	inc	start
	cmp	start, r13
	jz	.close
	mov	ax, ', '
	stos	word[alloc_small_ptr]
	jmp	.elem
.close:	mov	eax, ')' + 256 * 10
	stos	dword[alloc_small_ptr]
	pop	rax
	puts	rax
	mov	eax, 2
	jmp	sys_exit
restore	start
restore	bucket
msg_fatal_error	db 'Фатальная ошибка: исключение '
msg_fatal_error.size := $-msg_fatal_error
end proc
