;  pc = prog;		r15 (или rsi?)
;  extra_args = 0;	r12
;  env = Atom(0);	r13
;  accu = Val_int(0);	rdx или надо сохранять?

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
	lea	rax, [rax + vm_base + vm_base_lbl - execute_instruction]
	next_opcode
	jmp	rax
	ud2
display_num_ln 'Размер трамплина: ', $ - execute_instruction


macro Instruct_next
	jmp	vm_base
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

end Instruct


Instruct	ACC7

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

end Instruct


Instruct	ENVACC3

end Instruct


Instruct	ENVACC4

end Instruct


Instruct	ENVACC

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

end Instruct


Instruct	PUSHENVACC4

end Instruct


Instruct	PUSHENVACC

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

end Instruct


Instruct	APPTERM1
	pop	rcx
	mov	eax, [opcode.1]
	lea	vm_sp, [vm_sp + (rax - 1) * sizeof value]
	push	rcx
	mov	vm_pc, [accu]
	mov	env, accu
	Instruct_next
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

end Instruct


Instruct	RETURN
Instruct_stub
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
int3
Instruct_size
end Instruct


Instruct	RESTART

end Instruct


Instruct	GRAB
Instruct_stub
	mov	eax, [opcode.1]
	next_opcode
	sub	extra_args, rax
	jnc	.next
int3
	add	extra_args, rax

.next:	Instruct_next
Instruct_size
end Instruct


; Замыкание.
; Размер 3. Аргументы опкода:
; 1. Количество аргументов замыкания;
; 2. Относительный адрес замыкания (смещение для счётчика инструкций).
Instruct	CLOSURE
Instruct_stub
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
Instruct_stub
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
	Instruct_next

if HEAP_GC
..heap_set_gc_start:
	heap_set_gc_start_address
	Instruct_next
end if
Instruct_size
end Instruct


Instruct	ATOM

end Instruct


Instruct	PUSHATOM0

end Instruct


Instruct	PUSHATOM

;	хвост MAKEBLOCK
..MAKEBLOCK_CNT:
	neg	accu
	lea	accu, [alloc_small_ptr + accu * sizeof value]
	Instruct_next
;Instruct_size
end Instruct


; При размещении блока, во время копирования значений со стека на кучу,
; возможен вызов сборщика мусора. Поскольку значения могут представлять собой
; ссылки на объекты (живые), их необходимо сохранять в стеке до завершения
; формирования блока. Так же и адрес блока д.б. вычислен на завершающей стадии.
Instruct	MAKEBLOCK
	mov	ecx, [opcode.1]		; wosize
	mov	eax, ecx
	to_wosize	eax
	or	eax, [opcode.2]		; tag
	next_opcode	2
	push	accu
	stos	Val_header[alloc_small_ptr]
	mov	rsi, rsp
	mov	accud, ecx
rep	movs	qword[alloc_small_ptr], [rsi]
	mov	rsp, rsi
	jmp	..MAKEBLOCK_CNT
;	Instruct_next
Instruct_size
end Instruct


Instruct	MAKEBLOCK1
	mov	eax, [opcode.1]	; tag
	next_opcode
	or	eax, 1 wosize
	stos	Val_header[alloc_small_ptr]
	mov	rax, accu
;	Значение на стеке будет учтено сборщиком мусора
	push	accu
	stos	qword[alloc_small_ptr]
	pop	accu
	lea	accu, [alloc_small_ptr - 1 * sizeof value]	; Адрес блока (за заголовком).
	Instruct_next
Instruct_size
end Instruct


Instruct	MAKEBLOCK2
	mov	eax, [opcode.1]	; tag
	next_opcode
	or	eax, 2 wosize
	stos	Val_header[alloc_small_ptr]
	push	accu
	mov	rsi, rsp
	movs	qword[alloc_small_ptr], [rsi]
	movs	qword[alloc_small_ptr], [rsi]
	mov	rsp, rsi
	lea	accu, [alloc_small_ptr - 2 * sizeof value]	; Адрес блока (за заголовком).
	Instruct_next
Instruct_size
end Instruct


Instruct	MAKEBLOCK3
	mov	eax, [opcode.1]	; tag
	next_opcode
;	or	eax, 3 wosize
	mov	ah, 3
	stos	Val_header[alloc_small_ptr]
	push	accu
	mov	rsi, rsp
	movs	qword[alloc_small_ptr], [rsi]
	movs	qword[alloc_small_ptr], [rsi]
	movs	qword[alloc_small_ptr], [rsi]
	mov	rsp, rsi
	lea	accu, [alloc_small_ptr - 3 * sizeof value]	; Адрес блока (за заголовком).
	Instruct_next
Instruct_size
end Instruct


Instruct	MAKEFLOATBLOCK
	mov	ecx, [opcode.1]	; кол-во
	next_opcode
	mov	eax, ecx
	to_wosize rax
	or	rax, Double_array_tag
	push	accu
	stos	Val_header[alloc_small_ptr]
;	Читаем со стека ссылки на числа и переносим значения в кучу.
;	Стек оставляем до конца формирования блока на случай сборки мусора.
	mov	rsi, rsp
	mov	accud, ecx
	jmp	..MAKEFLOATBLOCK_CNT
Instruct_size
end Instruct


Instruct	GETFIELD0
	mov	accu, [accu + 0 * sizeof value]
	Instruct_next

..MAKEFLOATBLOCK_CNT:
.cp:	lods	qword[rsi]
	mov	rax, [rax]
	stos	qword[alloc_small_ptr]
	dec	ecx
	jnz	.cp
	mov	rsp, rsi
	neg	accu
	lea	accu, [alloc_small_ptr + accu * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	GETFIELD1
	mov	accu, [accu + 1 * sizeof value]
	Instruct_next
Instruct_size
end Instruct


Instruct	GETFIELD2

end Instruct


Instruct	GETFIELD3

end Instruct


Instruct	GETFIELD

end Instruct


Instruct	GETFLOATFIELD

end Instruct


Instruct	SETFIELD0

end Instruct


Instruct	SETFIELD1

end Instruct


Instruct	SETFIELD2

end Instruct


Instruct	SETFIELD3

end Instruct


Instruct	SETFIELD

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

end Instruct


Instruct	SETVECTITEM

end Instruct


Instruct	GETSTRINGCHAR

end Instruct


Instruct	SETSTRINGCHAR

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
	jnz	.br
	next_opcode
	Instruct_next
.br:	movsxd	rax, [opcode.1]
	lea	vm_pc, [opcode.1 + rax * sizeof opcode]
	Instruct_next
Instruct_size
end Instruct


Instruct	BRANCHIFNOT
	cmp	accu, Val_false
	jz	.br
	next_opcode
	Instruct_next
.br:	movsxd	rax, [opcode.1]
	lea	vm_pc, [opcode.1 + rax * sizeof opcode]
	Instruct_next
Instruct_size
end Instruct


Instruct	SWITCH

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
	add	rax, vm_pc
	next_opcode
	push	extra_args
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


Instruct	RAISE

end Instruct


Instruct	CHECK_SIGNALS
Instruct_stub
	;       if (caml_something_to_do) goto process_signal;
	Instruct_next
Instruct_size
end Instruct

; Вызов С функций

Instruct	C_CALL1
;  Setup_for_c_call;
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
;  Setup_for_c_call;
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
	mov	accud, [opcode]
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
	mov	accud, [opcode]
	lea	accu, [Val_int accu]
	next_opcode
	Instruct_next
Instruct_size
end Instruct


Instruct	NEGINT

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

end Instruct


Instruct	ANDINT

end Instruct


Instruct	ORINT

end Instruct


Instruct	XORINT

end Instruct


; accu = (value)((((intnat) accu - 1) << Long_val(*sp++)) + 1); Next;
Instruct	LSLINT
;	dec	accu
;	pop	rcx
;	командой сдвига учитываются младшие 6 бит регистра cl
;	cmp	rcx, 64
;	ja	.zero
;	shl	accu, cl
;	inc	accu
;	Instruct_next
;Instruct_size
end Instruct

; accu = (value)((((uintnat) accu - 1) >> Long_val(*sp++)) | 1);
Instruct	LSRINT
;	dec	accu
	pop	rcx
;	командой сдвига учитываются младшие 6 бит регистра cl
	cmp	rcx, 64
	ja	.zero
	shr	accu, cl	; CF = 1
	or	accu, Val_int_0	; CF = 0
	Instruct_next
.zero:	mov	accu, Val_int_0
	Instruct_next
Instruct_size
end Instruct


Instruct	ASRINT

end Instruct


Instruct	EQ
	pop	rax
	cmp	accu, rax
	mov	rax, Val_true
	mov	accu, Val_false
	cmove	accu, rax
	Instruct_next
Instruct_size
end Instruct


Instruct	NEQ
	pop	rax
	cmp	accu, rax
	setne	accub
	Val_int	accu
	and	accu,3
	Instruct_next
Instruct_size
end Instruct


Instruct	LTINT

end Instruct


Instruct	LEINT

end Instruct


Instruct	GTINT
	pop	rax
	cmp	accu, rax
	setg	accub
	Val_int	accu
	and	accu,3
	Instruct_next
Instruct_size
end Instruct


Instruct	GEINT

end Instruct


Instruct	OFFSETINT
	movsxd	rax, [opcode.1]
	next_opcode
	lea	accu, [accu + rax*2]
	Instruct_next
Instruct_size
end Instruct


Instruct	OFFSETREF

end Instruct


Instruct	ISINT

end Instruct


Instruct	GETMETHOD

end Instruct



Instruct	BEQ

end Instruct


Instruct	BNEQ
	movsxd	rax, [opcode.1]
	Long_val accu
	cmp	rax, accu
	jnz	.br
	next_opcode 2
	Instruct_next
.br:	movsxd	rax, [opcode.2]
	lea	vm_pc, [opcode.2 + rax * sizeof opcode]
	Instruct_next
Instruct_size
end Instruct


Instruct	BLTINT

end Instruct


Instruct	BLEINT

end Instruct


Instruct	BGTINT
	movsxd	rax, [opcode.1]
	Long_val accu
	cmp	rax, accu
	jg	.br
	next_opcode 2
	Instruct_next
.br:	movsxd	rax, [opcode.2]
	lea	vm_pc, [opcode.2 + rax * sizeof opcode]
	Instruct_next
Instruct_size
end Instruct


Instruct	BGEINT

end Instruct


Instruct	ULTINT

end Instruct

; >=
; (accu >= sp*++) + 1
Instruct	UGEINT
;	mov	eax, [opcode.1]
;	next_opcode
	
;	jmp	execute_instruction
;Instruct_size
end Instruct


Instruct	BULTINT

end Instruct


Instruct	BUGEINT

end Instruct


Instruct	GETPUBMET

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


;Instruct	FIRST_UNIMPLEMENTED_OP

;end Instruct


; При размещении блока, во время копирования аргументов замыкания со стека на кучу,
; возможен вызов сборщика мусора. Поскольку эти значения могут представлять собой
; ссылки на объекты (живые), их необходимо сохранять в стеке до завершения
; формирования блока. Так же и адрес блока д.б. вычислен на завершающей стадии.
CLOSURE_impl:
	mov	ecx, [opcode.1]	; Количество аргументов замыкания.
	jecxz	.no_arg
	push	accu	; 1й аргумент для дальнейшего копирования.
.no_arg:
	lea	eax, [ecx+1]
	mov	accud, eax
	to_wosize	eax 
	or	eax, Closure_tag
	stos	Val_header[alloc_small_ptr]
	movsxd	rax, [opcode.2]
	lea	rax, [opcode.2 + rax * sizeof opcode]
;	Cохраняем указатель на байт-код замыкания (pc + *pc).
	stos	qword[alloc_small_ptr]
;	Копируем аргументы замыкания со стека.
	mov	rsi, rsp
rep	movs	qword[alloc_small_ptr], [rsi]
	mov	rsp, rsi
	neg	accu
	lea	accu, [alloc_small_ptr + (accu - 0) * sizeof value]
	next_opcode 2
	Instruct_next
display_num_ln "CLOSURE_impl: ", $-CLOSURE_impl


; Примечание: нижеследующая и предыдущая (CLOSURE_impl) подпрограммы объёмны,
; вероятно, имеет смысл выполнять явную проверку необходимости выделения памяти,
; а не полагаться на обработчик SIGSEGV. Что позволит упростить реализацию.
;
; В данном случае формирование блока после заголовка происходит в два этапа:
; 1. Копирование аргументов со стека - в конец блока. Поскольку их значения
;    могут представлять собой ссылки на объекты (живые), их необходимо
;    сохранять в стеке до завершения формирования блока.
; 2. Создание инфиксных блоков с размещением указателей на них на стеке.
;    Если при этом произойдёт вызов сборщика мусора, инфиксные блоки будут
;    сдвинуты за пределы блока замыкания, создание которого не завершено.
;    В случае выполнения пункта 1, указанная ситуация исключена, поскольку
;    сборка мусора сработает при доступе к старшим адресам, куда копируются
;    аргументы.
;    Если же количество аргументов равно 0, следует обратиться к ячейке памяти
;    в конце блока замыкания, для гарантии доступности памяти.
;
;    Адрес блока для возврата в accu д.б. вычислен после 1й стадии.
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
;	Адрес за блоками инфиксов (1й из них без заголовка)
	lea	alloc_small_ptr, [alloc_small_ptr + rsi * sizeof value]
;	Количество ячеек в блоке - для вычисления его адреса.
	lea	eax, [rsi + rcx]
	neg	rax
;	Копируем аргументы (аккумулятор и со стека), если они есть.
	jecxz	.noarg
	push	accu
	mov	rsi, rsp
rep	movs	qword[alloc_small_ptr], [rsi]
	mov	rsp, rsi
	jmp	.infix
.noarg:	cmp	[alloc_small_ptr - sizeof value], rax
.infix:;Далее вызов сборщика мусора исключён.
	mov	rsi, alloc_small_ptr	; временно храним адрес за блоком
	lea	alloc_small_ptr, [alloc_small_ptr + rax * sizeof value]
	mov	accu, alloc_small_ptr
;	Копируем указатели на код, предваряя их инфиксными заголовками, кроме 1го.
	zero	ecx
	mov	r8d, [opcode.1]
	next_opcode 2
	jmp	.cpp
.cpi:	mov	eax, ecx
;	to_wosize eax * 2
	shl	eax, wosize_shift + 1
	or	eax, Infix_tag
	stos	qword[alloc_small_ptr]
.cpp:	push	alloc_small_ptr
	movsxd	rax, [opcode.1]
	lea	rax, [vm_pc + rax * sizeof opcode]
	next_opcode
	stos	qword[alloc_small_ptr]
	inc	ecx
	cmp	ecx, r8d
	jc	.cpi
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
