; Процедуры (C примитивы) для работы с целыми числами.


; Возвращает целое число, сконвертированное из текстового представления.
; RDI - адрес строки;
; CL - количество значащих разрядов результата.
proc parse_intnat
;base	equ rsi
sign	equ r8
over	equ r9
	push	rdi
	zero	sign
	cmp	byte[rdi], '+'
	jz	.sign
	cmp	byte[rdi], '-'
	jnz	.positive
	inc	sign
.sign:	inc	rdi
.positive:
;	По умолчанию числа десятичные знаковые.
;	Проверим наличие префикса с основанием системы счисления.
	cmp	byte[rdi], '0'
	jnz	.s10
	mov	al, [rdi + 1]
	and	al, not ('a' xor 'A')
	add	rdi, 2
	mov	esi, 16
	cmp	al, 'X'
	jz	._1
	mov	esi, 8
	cmp	al, 'O'
	jz	._1
	mov	esi, 2
	cmp	al, 'B'
	jz	._1
	cmp	al, 'U'
	jz	.u10
	sub	rdi, 2
;	Один разряд занимает знак числа. Для знаковых чисел он д.б. 0,
;	поскольку проверка выполняется до смены знака.
.s10:	dec	cl
.u10:	mov	esi, 10
._1:;	Маска содержит 1 в разрядах, запрещённых для результата.
	or	over, -1
;	Обеспечим сдвиг на 64 разряда
	dec	cl
	shl	over, cl
	add	over, over
	mov	al, [rdi]
	inc	rdi
	sub	eax, '0'
	jc	.fail
	cmp	al, 9
	jbe	._1d
	and	al, not (('a' - '0') xor ('A' - '0'))
	sub	al, 'A' - '0' - 10
	jc	.fail
	cmp	al, 0Fh
	ja	.fail
._1d:	movzx	edx, al
	cmp	edx, esi
	ja	.fail
.next:	mov	al, [rdi]
	inc	rdi
	cmp	al, '_'
	jz	.next
	sub	al, '0'
	jc	.done
	cmp	al, 9
	jbe	.dgt
	and	al, not (('a' - '0') xor ('A' - '0'))
	sub	al, 'A' - '0' - 10
	jc	.done
	cmp	al, 0Fh
	ja	.done
.dgt:	movzx	ecx, al
	cmp	ecx, esi
	ja	.done
	mov	rax, rdx
	mul	rsi
;	Умножение на основание системы счисления может вызвать переполнение.
	jo	.fail
	add	rax, rcx
;	Возможно переполнение после сложения.
	jc	.fail
	mov	rdx, rax
	jmp	.next
.done:	mov	rax, rdx
	zero	rdx
;	Даже если число знаковое, бит знака на данном этапе доложен быть 0,
;	кроме случая, когда число равно минимальному отрицательному.
	test	rax, over
	jnz	.check_min
; 	Меняем знак, если установлен соответствующий признак.
	sub	rdx, rax
	test	sign, sign
.min:	cmovnz	rax, rdx
	pop	rsi
	caml_string_length rsi, rcx, rdx
	dec	rdi
	sub	rdi, rcx
	cmp	rsi, rdi
	jnz	.fail2
	ret
.check_min:
;	Минимально возможное отрицательное число равно маске переполнения.
	test	sign, sign
	jz	.fail
	sub	rdx, rax
	cmp	rdx, over
	jz	.min
; 	При вызове caml_failwith нет необходимости выравнивать стек
.fail:;	pop	rdi
.fail2:	lea	rdi, [.msg]
	jmp	caml_failwith
;!!! следует передавать из вызывающей процедуры строку с её именем.
.msg	db	'parse_intnat', 0
restore	over
restore	sign
end proc


; Меняет местами байты в 16-ти разрядном представлении числа.
; EDI - целое в OCaml представлении.
C_primitive caml_bswap16
	mov	eax, edi
	shr	eax, 8
	shl	edi, 8
	and	eax, Val_int 0xff
	and	edi, Val_int 0xff00
	or	eax, edi
	or	eax, 1
	ret
end C_primitive


; Возвращает результат сравнения целых знаковых чисел:
; Val_int 1	- 1е > 2го;
; Val_int 0	- значения равны;
; Val_int -1	- 1е < 2го;
; RDI - 1-е целое;
; RSI - 2-е целое.
C_primitive caml_int_compare
	cmp	rdi, rsi
	mov	eax, Val_int 0
	mov	ecx, Val_int 1
	mov	rdx, Val_int -1
	cmovg	eax, ecx	; rdi > rsi
	cmovl	rax, rdx	; rdi < rsi
	ret
end C_primitive


; Возвращает целое OCaml value, сконвертированное из текстового представления.
; RDI - адрес строки.
C_primitive caml_int_of_string
	mov	cl, sizeof value * 8 - 1
	call	parse_intnat
	Val_int	rax
	ret
end C_primitive


; Преобразует число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат; см. format_of_iconv в stdlib/camlinternalFormat.ml
; RSI - целое (в OCaml-представлении).
C_primitive caml_format_int
	Int_val rsi
	mov	rdx, 1 shl 63 - 1
	jmp	caml_alloc_sprintf1
end C_primitive


; 32-x разрядные целые числа. Располагаются в куче. Размер ячейки вдвое больше
; такого числа. Приводим их к "родному" представлению для совместимости.

; Формирует заголовок блока int32
macro	int32_header
	mov	Val_header[alloc_small_ptr_backup], (1 + 1) wosize or Custom_tag
	lea	rax, [caml_int32_ops]
	mov	[alloc_small_ptr_backup + 1 * sizeof value], rax
end macro

; Значение хранится в 1-м поле блока (после 0-го - с адресом методов).
int32_val equ (1 * sizeof value)

; Сохраняет результат в блоке, устанавливает адреса блока и аллокатора.
macro	int32_ret result
	mov	qword[alloc_small_ptr_backup + 2 * sizeof value], result
	lea	rax, [int32_val + alloc_small_ptr_backup]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 3 * sizeof value]
	ret
end macro


; Возвращает результат вычитания из 0 (смена знака) целого.
; RDI - адрес целого;
C_primitive caml_int32_neg
	int32_header
	mov	eax, [int32_val + rdi]
	neg	eax
	cdqe
	int32_ret rax
end C_primitive


; Возвращает сумму двух целых.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_int32_add
	int32_header
	mov	eax, [int32_val + rdi]
	add	eax, [int32_val + rsi]
	cdqe
	int32_ret rax
end C_primitive


; Возвращает разность двух целых.
; RDI - адрес уменьшаемого;
; RSI - адрес вычитаемого.
C_primitive caml_int32_sub
	int32_header
	mov	eax, [int32_val + rdi]
	sub	eax, [int32_val + rsi]
	cdqe
	int32_ret rax
end C_primitive


; Возвращает произведение двух целых.
; RDI - адрес 1-го множителя;
; RSI - адрес 2-го множителя.
C_primitive caml_int32_mul
	int32_header
	mov	eax, [int32_val + rdi]
	imul	dword[int32_val + rsi]
	cdqe
	int32_ret rax
end C_primitive


; Возвращает частное от деления двух целых.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_int32_div
	int32_header
	mov	ecx, [int32_val + rsi]
	test	ecx, ecx
	jz	caml_raise_zero_divide
; 	При 32-х разрядном делении 0x80000000 на -1 генерируется SIGFPE,
;	поскольку частное положительно и выходит за допустимый диапазон.
;	Вернём в таком случае делимое (как в эталонной реализации).
	mov	eax, [int32_val + rdi]
	cmp	eax, 1 shl (sizeof value * 4 - 1)
	jz	.max_neg
.div:	cdq
	idiv	ecx
	cdqe
	int32_ret rax
.max_neg:
	cmp	ecx, -1
	jnz	.div
	mov	rax, rdi
	ret
end C_primitive


; Возвращает остаток от деления (по модулю) двух целых.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_int32_mod
	int32_header
; 	При 32-х разрядном делении 0x80000000 на -1 генерируется SIGFPE (см. div).
;	Используем 64-х разрядное.
	movsxd	rcx, [int32_val + rsi]
	test	rcx, rcx
	jz	caml_raise_zero_divide
	movsxd	rax, [int32_val + rdi]
	cqo
	idiv	rcx
	int32_ret rdx
end C_primitive


; Возвращает результат поразрядной конъюнкции (И) двух целых.
; RDI - адрес 1-го множителя;
; RSI - адрес 2-го множителя.
C_primitive caml_int32_and
	int32_header
	mov	eax, [int32_val + rdi]
	and	eax, [int32_val + rsi]
	int32_ret rax	; обнуляем незначащие разряды
end C_primitive


; Возвращает результат поразрядной дизъюнкции (включающего ИЛИ) двух целых.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_int32_or
	int32_header
	mov	rax, [int32_val + rdi]
	or	rax, [int32_val + rsi]
	int32_ret rax
end C_primitive


; Возвращает сумму по модулю 2 (исключающее ИЛИ) двух целых.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_int32_xor
	int32_header
	mov	rax, [int32_val + rdi]
	xor	rax, [int32_val + rsi]
	int32_ret rax
end C_primitive


; Сдвиг влево.
; Возвращает адрес результата.
; RDI - адрес сдвигаемого аргумента;
; RSI - количество бит, на которое следует сдвинуть аргумент (OCaml value)
C_primitive caml_int32_shift_left
	int32_header
	Int_val	esi
	mov	ecx, esi
	mov	eax, [int32_val + rdi]
	shl	eax, cl
	cdqe
	int32_ret rax	; обнуляем незначащие разряды
end C_primitive


; Сдвиг вправо арифметический (с учётом знака).
; Возвращает адрес результата.
; RDI - адрес сдвигаемого аргумента;
; RSI - количество бит, на которое следует сдвинуть аргумент (OCaml value)
C_primitive caml_int32_shift_right
	int32_header
	Int_val	esi
	mov	ecx, esi
	mov	rax, [int32_val + rdi]
	sar	rax, cl
	int32_ret rax
end C_primitive


; Сдвиг вправо без учёта знака.
; Возвращает адрес результата.
; RDI - адрес сдвигаемого аргумента;
; RSI - количество бит, на которое следует сдвинуть аргумент (OCaml value)
C_primitive caml_int32_shift_right_unsigned
	int32_header
	Int_val	esi
	mov	ecx, esi
	mov	eax, [int32_val + rdi]
	shr	eax, cl
	int32_ret rax	; обнуляем незначащие разряды
end C_primitive


; Меняет местами байты в 32-ти разрядном представлении числа.
; RDI - адрес 32-битного целого.
C_primitive caml_int32_bswap
	int32_header
	mov	rax, [int32_val + rdi]
	bswap	eax
	int32_ret rax	; обнуляем незначащие разряды
end C_primitive


; Возвращает адрес целого, полученного из OCaml value.
; RDI - OCaml value
C_primitive caml_int32_of_int
	int32_header
	Int_val	rdi
	int32_ret rdi
end C_primitive


; Возвращает целое OCaml value, преобразованное из int32.
; RDI - адрес целого числа.
C_primitive caml_int32_to_int
	movsxd	rax, [int32_val + rdi]
	Val_int	rax
	ret
end C_primitive


; Возвращает адрес целого, полученного округлением вещественного числа.
; RDI - адрес вещественного числа.
C_primitive caml_int32_of_float
	int32_header
	cvttsd2si rax, [rdi]
	int32_ret rax
end C_primitive


; Возвращает вещественное число, полученное из int32.
; RDI - адрес целого.
C_primitive caml_int32_to_float
	mov	eax, 1 wosize or Double_tag
	mov	[alloc_small_ptr_backup], rax
	mov	eax, [int32_val + rdi]
	cvtsi2sd xmm0, eax
	movsd	[alloc_small_ptr_backup + sizeof value], xmm0
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


; Сравнивает 2 целых числа.
C_primitive caml_int32_compare
	mov	eax, [int32_val + rdi]
	cmp	eax, [int32_val + rsi]
	mov	eax, Val_int 0
	mov	ecx, Val_int 1
	mov	rdx, Val_int -1
	cmovnz	eax, ecx
	cmovs	rax, rdx
	ret
end C_primitive


; Преобразует 32-х разрядное число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат; см. format_of_iconv в stdlib/camlinternalFormat.ml
; RSI - адрес блока с целым.
C_primitive caml_int32_format
;	Для вывода шестнадцатеричных цифр следует удалить незначащие разряды.
	or	edx, -1
	mov	rsi, [int32_val + rsi]
	jmp	caml_alloc_sprintf1
end C_primitive


; Возвращает целое OCaml value, сконвертированное из текстового представления.
; RDI - адрес строки.
C_primitive caml_int32_of_string
	int32_header
	mov	cl, sizeof value * 4
	call	parse_intnat
	cdqe
	int32_ret rax
end C_primitive


C_primitive caml_int32_bits_of_float
end C_primitive


C_primitive caml_int32_float_of_bits
end C_primitive


; 64-х разрядные числа. Располагаются в куче.
; Соответствуют "родным". В эталонной реализации различаются таблицей методов.

; Значение хранится в 1-м поле блока (после 0-го - с адресом методов).
int64_val equ (1 * sizeof value)


caml_int64_neg	:= caml_nativeint_neg

caml_int64_add	:= caml_nativeint_add

caml_int64_sub	:= caml_nativeint_sub

caml_int64_mul	:= caml_nativeint_mul

caml_int64_div	:= caml_nativeint_div

caml_int64_mod	:= caml_nativeint_mod

caml_int64_and	:= caml_nativeint_and

caml_int64_or	:= caml_nativeint_or

caml_int64_xor	:= caml_nativeint_xor

caml_int64_shift_left	:= caml_nativeint_shift_left

caml_int64_shift_right	:= caml_nativeint_shift_right

caml_int64_shift_right_unsigned := caml_nativeint_shift_right_unsigned

caml_int64_bswap	:= caml_nativeint_bswap

caml_int64_of_int	:= caml_nativeint_of_int

caml_int64_to_int	:= caml_nativeint_to_int

caml_int64_of_float	:= caml_nativeint_of_float

caml_int64_to_float	:= caml_nativeint_to_float

caml_int64_of_int32	:= caml_nativeint_of_int32

caml_int64_to_int32	:= caml_nativeint_to_int32

caml_int64_to_nativeint	:= caml_int64_of_nativeint

caml_int64_compare	:= caml_nativeint_compare

caml_int64_format	:= caml_nativeint_format

caml_int64_of_string	:= caml_nativeint_of_string


; Создаём копию, поскольку формат идентичен. (безопасно ли просто вернуть RDI?)
C_primitive caml_int64_of_nativeint
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	nativeint_ret	rax
end C_primitive


C_primitive caml_int64_bits_of_float
end C_primitive


; RDI - адрес источника для копирования в кучу числа с плавающей точкой.
C_primitive caml_int64_float_of_bits
	mov	eax, 1 wosize or Double_tag
	mov	[alloc_small_ptr_backup], rax
	mov	rax, [int64_val + rdi]
	mov	[alloc_small_ptr_backup + sizeof value], rax
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


; "Родные" для архитектуры целые числа. Располагаются в куче.

; Формирует заголовок блока nativeint
macro	nativeint_header
	mov	Val_header[alloc_small_ptr_backup], (1 + 1) wosize or Custom_tag
	lea	rax, [caml_nativeint_ops]
	mov	[alloc_small_ptr_backup + 1 * sizeof value], rax
end macro

; Значение хранится в 1-м поле блока (после 0-го - с адресом методов).
nativeint_val equ (1 * sizeof value)

; Сохраняет результат в блоке, устанавливает адреса блока и аллокатора.
macro	nativeint_ret result
	mov	[alloc_small_ptr_backup + 2 * sizeof value], result
	lea	rax, [nativeint_val + alloc_small_ptr_backup]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 3 * sizeof value]
	ret
end macro


; Возвращает результат вычитания из 0 (смена знака) целого.
; RDI - адрес целого;
C_primitive caml_nativeint_neg
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	neg	rax
	nativeint_ret	rax
end C_primitive


; Возвращает сумму двух целых.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_nativeint_add
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	add	rax, [nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive


; Возвращает разность двух целых.
; RDI - адрес 1-го уменьшаемое;
; RSI - адрес 2-го вычитаемое.
C_primitive caml_nativeint_sub
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	sub	rax, [nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive


; Возвращает произведение двух целых.
; RDI - адрес 1-го множителя;
; RSI - адрес 2-го множителя.
C_primitive caml_nativeint_mul
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	imul	qword[nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive


; Возвращает частное от деления двух целых.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_nativeint_div
	nativeint_header
	mov	rcx, [nativeint_val + rsi]
	test	rcx, rcx
	jz	caml_raise_zero_divide
; 	При делении 0x8000000000000000 на -1 генерируется SIGFPE, поскольку
;	частное положительно и выходит за допустимый диапазон.
;	Вернём в таком случае делимое (как в эталонной реализации).
	mov	rax, 1 shl (sizeof value * 8 - 1)
	cmp	rax, [nativeint_val + rdi]
	jz	.max_neg
	mov	rax, [nativeint_val + rdi]
.div:	cqo
	idiv	rcx
.retm:	nativeint_ret	rax
.max_neg:
	cmp	rcx, -1
	jnz	.div
	mov	rax, rdi
	ret
end C_primitive


; Возвращает остаток от деления (по модулю) двух целых.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_nativeint_mod
	nativeint_header
	mov	rcx, [nativeint_val + rsi]
	test	rcx, rcx
	jz	caml_raise_zero_divide
; 	При делении 0x8000000000000000 на -1 генерируется SIGFPE (см. div).
;	В случае деления на -1 остаток всегда 0, вернём его непосредственно.
	zero	edx
	cmp	rcx, -1
	jz	.ret0
	mov	rax, [nativeint_val + rdi]
	cqo
	idiv	rcx
.ret0:	nativeint_ret	rdx
end C_primitive


; Возвращает результат поразрядной конъюнкции (И) двух целых.
; RDI - адрес 1-го множителя;
; RSI - адрес 2-го множителя.
C_primitive caml_nativeint_and
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	and	rax, [nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive


; Возвращает результат поразрядной дизъюнкции (включающего ИЛИ) двух целых.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_nativeint_or
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	or	rax, [nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive


; Возвращает сумму по модулю 2 (исключающее ИЛИ) двух целых.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_nativeint_xor
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	xor	rax, [nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive


; Сдвиг влево целого.
; Возвращает адрес результата.
; RDI - адрес сдвигаемого аргумента;
; RSI - количество бит, на которое следует сдвинуть аргумент (OCaml value)
C_primitive caml_nativeint_shift_left
	nativeint_header
	Int_val	esi
	mov	ecx, esi
	mov	rax, [nativeint_val + rdi]
	shl	rax, cl
	nativeint_ret	rax
end C_primitive


; Сдвиг вправо арифметический (с учётом знака).
; Возвращает адрес результата.
; RDI - адрес сдвигаемого аргумента;
; RSI - количество бит, на которое следует сдвинуть аргумент (OCaml value)
C_primitive caml_nativeint_shift_right
	nativeint_header
	Int_val	esi
	mov	ecx, esi
	mov	rax, [nativeint_val + rdi]
	sar	rax, cl
	nativeint_ret	rax
end C_primitive


; Сдвиг вправо без учёта знака.
; Возвращает адрес результата.
; RDI - адрес сдвигаемого аргумента;
; RSI - количество бит, на которое следует сдвинуть аргумент (OCaml value)
C_primitive caml_nativeint_shift_right_unsigned
	nativeint_header
	Int_val	esi
	mov	ecx, esi
	mov	rax, [nativeint_val + rdi]
	shr	rax, cl
	nativeint_ret	rax
end C_primitive


; Меняет местами байты в представлении числа.
; RDI - адрес целого.
C_primitive caml_nativeint_bswap
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	bswap	rax
	nativeint_ret rax
end C_primitive


; Возвращает адрес целого, полученного из OCaml value.
; RDI - OCaml value
C_primitive caml_nativeint_of_int
	nativeint_header
	Int_val	rdi
	nativeint_ret	rdi
end C_primitive


; Возвращает OCaml value, полученное из 64-х разрядного целого.
C_primitive caml_nativeint_to_int
	mov	rax, [nativeint_val + rdi]
	Val_int	rax
	ret
end C_primitive


C_primitive caml_nativeint_of_float
end C_primitive


C_primitive caml_nativeint_to_float
end C_primitive


; Возвращает целое, сконвертированное из 32-х разрядного.
; RDI - адрес 32-х разрядного.
C_primitive caml_nativeint_of_int32
	nativeint_header
	movsxd	rax, [int32_val + rdi]
	nativeint_ret	rax
end C_primitive


; Возвращает 32-х разрядное целое, полученное из 64-х разрядного.
C_primitive caml_nativeint_to_int32
	int32_header
	mov	eax, [nativeint_val + rdi]
	cdqe
	int32_ret rax
end C_primitive


; Сравнивает 2 целых числа.
C_primitive caml_nativeint_compare
	mov	rax, [int32_val + rdi]
	cmp	rax, [int32_val + rsi]
	mov	eax, Val_int 0
	mov	ecx, Val_int 1
	mov	rdx, Val_int -1
	cmovnz	eax, ecx
	cmovs	rax, rdx
	ret
end C_primitive


; Преобразует число в текстовую форму, располагая строку в текущие адреса кучи.
; Может приводить к инкременту указателя кучи.
; Возвращает в RAX длину строки-результата, выходящую за пределы указателя кучи.
; RSI - знаковое целое (в OCaml-представлении).
; RDI, RSI, RDX, RCX - не определены;
; R8, R9, R10 и R11 не используются.
proc	format_int_dec
	Int_val rsi

; RSI - знаковое целое.
format_nativeint_signed:
	test	rsi, rsi
	jns	format_nativeint
	neg	rsi
	mov	byte[alloc_small_ptr_backup], '-'
	inc	alloc_small_ptr_backup

; Преобразует число в текстовую форму, располагая строку в текущие адреса кучи.
; Возвращает в RAX длину строки-результата.
; RSI - беззнаковое целое
; RDI, RDX, RCX - не определены;
; R8 и R9 не используются по требованию caml_alloc_sprintf1.
; R10 и R11 не используются по требованию format_floating_point_number.
format_nativeint:
	zero	edx

; RDX - минимальное количество выводимых разрядов.
format_nativeint_pos:
	zero	ecx
	zero	edi
;	Определяем количество цифр, вычисляя десятичный логарифм простым циклом.
;	(вариант корректировки log2(n)*19/64 по таблице иногда быстрее, но объёмнее).
	mov	eax, 10
.log10:	inc	ecx
	cmp	rsi, rax
	jb	.@
	lea	rax, [rax * 5]
	add	rax, rax
	jnc	.log10
	inc	ecx
.@:	cmp	edx, ecx
	cmovc	edx, ecx

; EDI - количество младших цифр, после которого следует вывести разделитель.
;	Разделитель находится в разрядах 32..39 RDI
; EDX - количество цифр (младших разрядов), подлежащих выводу.
format_nativeint_n:
	mov	ecx, edx
	push	rcx
;	Делим на 10, умножая на магическое число.
.@:	dec	rdi
	test	edi, edi
	jz	.delimiter
	mov	rax, rsi
	mov	rdx, 0xCCCCCCCCCCCCCCCD
	mul	rdx
	shr	rdx, 3		; частное
	mov	rax, rsi
	mov	rsi, rdx
	lea	rdx, [rdx * 4 + rdx]
	sub	rax, rdx
	sub	rax, rdx	; остаток
;	Сохраняем остаток в виде символа.
	add	al ,'0'
.@1:	dec	ecx
	mov	[alloc_small_ptr_backup + rcx], al
	jnz	.@
	pop	rax	; размер строки
	ret
.delimiter:
	shr	rdi, 32
	mov	al, dil
	zero	edi
	jmp	.@1
end proc


; Преобразует число в шестнадцатеричный текст, располагая строку в текущие адреса кучи.
; Возвращает в RAX длину строки-результата.
; RSI - беззнаковое целое.
; DL - символ соответствующий 10, т.е. 'A' или 'a'.
; R8 и R9 не используются.
proc	format_nativeint_hex
	zero	rdi
	sub	dl, '9' + 1
	mov	ecx, sizeof value * 8 / 4
.skip_leading_zeroes:
	mov	rax, rsi
	shr	rax, (sizeof value - 1) * 8 + 4
	jnz	.hd
	shl	rsi, 4
	loop	.skip_leading_zeroes
	inc	ecx
.hex_digit:
	mov	rax, rsi
	shr	rax, (sizeof value - 1) * 8 + 4
.hd:	add	al, '0'
	cmp	al, '9'
	jbe	.dig
	add	al, dl
.dig:	mov	[alloc_small_ptr_backup + rdi], al
	inc	rdi
	shl	rsi, 4
	loop	.hex_digit
	mov	rax, rdi
	ret
end proc


; Преобразует число в восьмеричный текст, располагая строку в текущие адреса кучи.
; Возвращает в RAX длину строки-результата.
; RSI - беззнаковое целое.
proc	format_nativeint_oct
	zero	rdi
	mov	ecx, sizeof value * 8 / 3
;	1 + 21 * 3 бит. Обрабатываем старший разряд восьмеричного числа отдельно.
	shl	rsi, 1
	jc	.high1
.skip_leading_zeroes:
	mov	rax, rsi
	shr	rax, sizeof value * 8 - 3
	jnz	.od
	shl	rsi, 3
	loop	.skip_leading_zeroes
	inc	ecx
.oct_digit:
	mov	rax, rsi
	shr	rax, sizeof value * 8 - 3
.od:	add	al, '0'
	mov	[alloc_small_ptr_backup + rdi], al
	inc	rdi
	shl	rsi, 3
	loop	.oct_digit
	mov	rax, rdi
	ret
.high1:	mov	byte[alloc_small_ptr_backup], '1'
	inc	rdi
	jmp	.oct_digit
end proc


; Преобразует число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат; см. format_of_iconv в stdlib/camlinternalFormat.ml
; RSI - адрес блока с целым.
C_primitive caml_nativeint_format
	or	rdx, -1
	mov	rsi, [nativeint_val + rsi]
	jmp	caml_alloc_sprintf1
end C_primitive


; Возвращает целое OCaml value, сконвертированное из текстового представления.
; RDI - адрес строки.
C_primitive caml_nativeint_of_string
	nativeint_header
	mov	cl, sizeof value * 8
	call	parse_intnat
	nativeint_ret rax
end C_primitive
