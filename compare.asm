; Процедуры (C примитивы) сравнения.


; Возвращает результат сравнения произвольных значений:
; Val_int 1	- 1е больше 2го;
; Val_int 0	- значения равны;
; Val_int -1	- 1е меньше 2го;
;
; RDI - 1-е;
; RSI - 2-е.
; R8  - передаётся в точку входа compare_val_r8.
; 	Если не 0, то возвращается в случае NaN.
;
; Подпрограмма предполагает, что ссылки попадают в диапазон адресов кучи.
; В этой связи таблица атомов должна располагаться в куче.
C_primitive caml_compare
C_primitive_stub
; В оригинальной реализации возвращает:
; > 0 (1е > 2го), 0 (равны), < 0 (-1е < 2го) или UNORDERED (в случае QNaN).
compare_val:
	zero	r8
compare_val_r8:
val1	equ rdi
val2	equ rsi
	virtual at rsp
	label 	.compare_stack:8*3
		.val1	dq ?
		.val2	dq ?
		.count	dq ?
	end virtual
	push	rbp
	mov	rbp, rsp
.compare:
	test	r8, r8
	jnz	.total
;	Такое сравнение не учитывает возможно различный результат при Custom_tag
	cmp	val1, val2
	jz	.next_item
.total:	test	val1, 1
	jz	.val1_is_ptr
	test	val2, 1
	jz	.val2_is_ptr
;	Оба - числа и не равны - возвращаем разность как результат сравнения.
	mov	rax, val1
	cmp	rax, val2
	jmp	.result
.val2_is_ptr:
;	Здесь следует проверить Forward_tag и Custom_tag
;	целое меньше блока
	mov	rax, Val_int -1
	jmp	.exit
.val1_is_ptr:
;	блок больше целого
	mov	eax, Val_int 1
	test	val2, 1
	jnz	.exit
;	Оба значения - указатели. Проверяем, являются ли они ссылками на блоки.
	cmp	val1, heap_small
	jc	.arbitrary_ptr
	cmp	val1, [heap_descriptor.uncommited]
	jnc	.arbitrary_ptr
	cmp	val2, heap_small
	jc	.arbitrary_ptr
	cmp	val2, [heap_descriptor.uncommited]
	jnc	.arbitrary_ptr
;	Сравниваем теги блоков.
	mov	rax, Val_header[val1 - sizeof value]
;	cmp	al, Forward_tag
;	jz	.forward_tag
	mov	rdx, Val_header[val2 - sizeof value]
;	cmp	dl, Forward_tag
;	jz	.forward_tag
	cmp	al, dl
	jnz	.result
	cmp	al, Closure_tag		; 247
	jb	.default_tag
;	cmp	dl, Infix_tag		; 249
;	cmp	dl, Abstract_tag	; 251
	cmp	al, String_tag		; 252
	jz	.string_tag
	cmp	al, Double_tag		; 253
	jz	.double_tag
	cmp	al, Double_array_tag	; 254
	jz	.double_array_tag
;	cmp	dl, Custom_tag		; 255
	ja	.custom_tag
ud2
.custom_tag:
;	Версия только для nativeint, int64 и int32; без чтения таблицы методов.
	mov	rax, [rdi]
	lea	rdx, [caml_nativeint_ops]
	sub	rax, rdx
	cmp	rax, caml_int32_ops - caml_nativeint_ops
	ja	.arbitrary_ptr
	mov	rdi, [rdi + nativeint_val]
	mov	rsi, [rsi + nativeint_val]
.arbitrary_ptr:
	cmp	rdi, rsi
	jmp	.result
;	Теги равны - сравниваем размеры
.default_tag:
	cmp	rax, rdx
	jnz	.result
	from_wosize rdx
	jz	.next_item
	dec	rdx
	jz	.cmp0
;	Откладываем сравнение остальных элементов на следующую итерацию.
	mov	[.val1  - sizeof .compare_stack], val1
	mov	[.val2  - sizeof .compare_stack], val2
	mov	[.count - sizeof .compare_stack], rdx
	lea	rsp, [rsp - sizeof .compare_stack]
.cmp0:	; Продолжаем сравнение с 0ми элементами.
	mov	val1, [val1]
	mov	val2, [val2]
	jmp	.compare
.next_item:
	cmp	rsp, rbp
	mov	eax, Val_int 0
	jz	.exit
	mov	val1, [.val1]
	mov	val2, [.val2]
	lea	val1, [val1 + sizeof value]
	lea	val2, [val2 + sizeof value]
	mov	[.val1], val1
	mov	[.val2], val2
	mov	val1, [val1]
	mov	val2, [val2]
	dec	[.count]
	jnz	.compare
	lea	rsp, [rsp + sizeof .compare_stack]
	jmp	.compare
.result:
;	Флаги установлены командой сравнения перед переходом сюда.
	mov	eax, Val_int 0
	mov	ecx, Val_int 1
	mov	rdx, Val_int -1
	cmovnz	eax, ecx
	cmovs	rax, rdx
.exit:	mov	rsp, rbp
	pop	rbp
	ret
.exit_nan:
	test	r8, r8
	cmovnz	rax, r8	; задаётся вызывающей стороной, что бы отличить NaN.
	mov	rsp, rbp
	pop	rbp
	ret
;	Сравниваем строки посимвольно.
.string_tag:
;	Если одна из строк является подстрокой другой, сравниваем длины.
	caml_string_length	val1, rdx, rax
	caml_string_length	val2, rcx, rax
	mov	rax, rdx
	sub	rax, rcx
	cmovc	rcx, rdx
	test	rcx, rcx
	jz	.str_e
.str_c:	mov	dl, [val1]
	cmp	dl, [val2]
	lea	val1, [val1 + 1]
	lea	val2, [val2 + 1]
	jnz	.result
	dec	rcx
	jnz	.str_c
;	Если длины строк совпадают, продолжаем сравнение оставшихся элементов.
.str_e:	test	rax, rax
	jz	.next_item
	jmp	.result
;	Сравниваем вещественные числа.
.double_tag:
	movsd	xmm0, [val1]
	ucomisd	xmm0, [val2]
;	UNORDERED:	ZF,PF,CF <- 111;
;	GREATER_THAN:	ZF,PF,CF <- 000;
;	LESS_THAN:	ZF,PF,CF <- 001;
;	EQUAL:		ZF,PF,CF <- 100;
	mov	eax, Val_int 0
	mov	ecx, Val_int 1
	mov	rdx, Val_int -1
	cmova	eax, ecx	; [val1] > [val2]
	cmovc	rax, rdx	; [val1] < [val2]
	jnz	.exit
	jp	.exit_nan	; NaN
	jmp	.next_item
;	Сравниваем массивы вещественных чисел.
.double_array_tag:
;	Сначала размеры,
	mov	rax, Val_header[val1 - sizeof value]
	mov	rcx, Val_header[val2 - sizeof value]
	sub	rax, rcx
	jnz	.exit
;	потом поэлементно.
	from_wosize rcx
	jz	.next_item
.da_c:	movsd	xmm0, [val1]
	ucomisd	xmm0, [val2]
;	см. double_tag
	mov	eax, Val_int 1	; [val1] > [val2]
	mov	rdx, Val_int -1
	cmovc	rax, rdx	; [val1] < [val2]
	jnz	.exit
	jp	.exit_nan	; NaN
	lea	val1, [val1 + sizeof value]
	lea	val2, [val2 + sizeof value]
	dec	rcx
	jnz	.da_c
	jmp	.next_item
restore	val2
restore	val1
end C_primitive


; Возвращает Val_true если аргументы равны.
; RDI - 1-е значение;
; RSI - 2-e значение.
C_primitive caml_equal
	mov	r8, Val_int -1
	call	compare_val_r8
	Int_val	rax
	mov	eax, Val_false
	mov	ecx, Val_true
	cmovz	eax, ecx
	ret
end C_primitive


; Возвращает Val_true если аргументы не равны.
; RDI - 1-е значение;
; RSI - 2-e значение.
C_primitive caml_notequal
	mov	r8, Val_int -1
	call	compare_val_r8
	Int_val	rax
	mov	eax, Val_false
	mov	ecx, Val_true
	cmovne	eax, ecx
	ret
end C_primitive


; Возвращает Val_true если первый аргумент меньше второго.
; RDI - 1-е значение;
; RSI - 2-e значение.
C_primitive caml_lessthan
	mov	r8d, Val_int 1
	call	compare_val_r8
	cmp	rax, r8
	mov	rax, r8		; Val_true
	mov	ecx, Val_false
	cmovns	eax, ecx
	ret
end C_primitive


; Возвращает Val_true если первый аргумент меньше либо равен второму.
; RDI - 1-е значение;
; RSI - 2-e значение.
C_primitive caml_lessequal
	mov	r8d, Val_int 1
	call	compare_val_r8
	cmp	rax, r8
	mov	rax, r8		; Val_true
	mov	ecx, Val_false
	cmove	eax, ecx
	ret
end C_primitive


; Возвращает Val_true если первый аргумент больше второго.
; RDI - 1-е значение;
; RSI - 2-e значение.
C_primitive caml_greaterthan
	mov	r8, Val_int -1
	call	compare_val_r8
	cmp	rax, r8
	mov	ecx, Val_false
	cmove	eax, ecx
	ret
end C_primitive


; Возвращает Val_true если первый аргумент больше либо равен второму.
; RDI - 1-е значение;
; RSI - 2-e значение.
C_primitive caml_greaterequal
	mov	r8, Val_int -1
	call	compare_val_r8
	Int_val	rax
	mov	eax, Val_false
	mov	ecx, Val_true
	cmovns	eax, ecx
	ret
end C_primitive
