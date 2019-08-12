; Процедуры (C примитивы) для работы с вещественными числами двойной точности.
; float здесь соотвествует типу double в C.


Negative_double	:= 0x8000000000000000	; знак в 63-м бите, согласно IEEE 754
Infinity	:= 0x7ff0000000000000
;NaN		:= 0x7fffffffffffffff
NaN		:= 0x7ff0000000000001

; Преобразует вещественное число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат вывода;
; RSI - вещественное число (в OCaml-представлении).
C_primitive caml_format_float
C_primitive_stub
;	Создаём заголовок с нулевой длиной. Скорректируем её по готовности строки.
	mov	qword[alloc_small_ptr_backup], String_tag
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof value]
	push	alloc_small_ptr_backup
;	в pervasives.ml string_of_float вызывает format_float с "%.12g"
	zero	r8	; сохраняется в format_nativeint_dec
	cmp	dword[rdi], '%.12'
	mov	ecx, 12
	jz	.f
	dec	r8
;	однако, функция вызывается и со следующей строкой формата:
	mov	ecx, 6
	cmp	dword[rdi], '%.6f'
	jnz	.fmt
.f:	mov	rdx, [rsi]
;	Поскольку sprintf различает 0.0 и -0.0, inf и -inf,
;	определим знак числа и выведем символ '-' для отрицательных.
	mov	rax, Negative_double
	test	rdx, rax
	jz	.positive
	mov	byte[alloc_small_ptr_backup], '-'
	inc	alloc_small_ptr_backup
	not	rax
	and	rdx, rax	; абсолютное значение числа
.positive:
	mov	rax, Infinity
	cmp	rdx, rax
	jz	.infinity
	mov	rax, NaN
	cmp	rdx, rax
	jz	.nan
	movq	xmm0, rdx
;	Подсчитываем количество цифр в целой части.
	zero	edx
	mov	eax, 10
;	%.g: если целая часть равна 0, она выводится помимо значащих разрядов
;	дробной части; округляем к 0, что бы увеличить точность в таком случае.
	cvttsd2si rsi, xmm0
	mov	rdi, rsi
	or	rdi, r8
	lea	edi, [ecx + 1]
	cmovz	ecx, edi
.cint:	inc	edx
;	js	.format_e
	cmp	rsi, rax
	jc	.calc_fmt
	lea	rax, [rax * 5]
	add	rax, rax
	jmp	.cint
;	%.g вычисляем количество цифр после запятой (известно общее).
;	%.f вычисляем общее количество цифр (известно количество в дробной части).
.calc_fmt:
	test	r8, r8
	jnz	.total
	zero	eax
	sub	ecx, edx
	cmovc	ecx, eax
.total:	add	edx, ecx
;	Десятичный разделитель (OCaml не использует локализацию?)
	mov	edi, '.'
	shl	rdi, 32
;	увеличивает количество  символов на 1.
	inc	edx
;	Указываем его позицию от младшего разряда (дробной части) числа.
	lea	rdi, [rdi + rcx + 1]
;	Перенесём требуемое после запятой количество знаков в целую часть,
;	умножив на 10 в степени n. Результат округляем.
	mov	eax, 1
;	Возведение в степень n выполняем сдвигом + сложением (lea) n раз,
;	а не двоичным разложением n, поскольку для малых n количество итераций
;	различается незначительно (5 при n=6), но нет умножения и ветвления.
	test	ecx, ecx
	jz	.p10
.pow:	lea	rax, [rax * 5]
	add	rax, rax
;	jc	.overflow
	dec	ecx
	jnz	.pow
.p10:	cvtsi2sd xmm1, rax
	mulsd	xmm0, xmm1
	cvtsd2si rsi, xmm0
;	Форматируем целое представление числа в строку.
	call	format_nativeint_dec_n
;	Для %.g незначащие нули справа следует откинуть.
	test	r8, r8
	js	.exit
.fnz:	cmp	byte[alloc_small_ptr_backup + rax - 1], '0'
	jnz	.exit
	dec	eax
	jmp	.fnz
.exit:	lea	rdi, [rax + alloc_small_ptr_backup]
	pop	alloc_small_ptr_backup
	sub	rdi, alloc_small_ptr_backup
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup - sizeof value]
	jmp	caml_alloc_string
.infinity:
	mov	dword[alloc_small_ptr_backup], 'inf'
	mov	eax, 3
	jmp	.exit
.nan:	mov	dword[alloc_small_ptr_backup], 'nan'
	mov	eax, 3
	jmp	.exit
.fmt:
int3
end C_primitive


C_primitive caml_hexstring_of_float
end C_primitive


; Возвращает вещественное число, сконвертированное из текстового представления.
; RDI - адрес строки.
C_primitive caml_float_of_string
C_primitive_stub	; частично поддержан экспоненциальный формат (P)
; см. parse_intnat
;base	equ rsi
sign	equ r8
	push	rdi
	zero	sign
	cmp	byte[rdi], '+'
	jz	.sign
	cmp	byte[rdi], '-'
	jnz	.positive
	mov	sign, Negative_double
.sign:	inc	rdi
.positive:
;	По умолчанию числа десятичные.
;	Проверим наличие префикса 0x или 0X (остальные не поддерживаются в оригинале).
	cmp	byte[rdi], '0'
	jnz	.s10
	mov	al, [rdi + 1]
	and	al, not ('a' xor 'A')
	add	rdi, 2
	mov	esi, 16
	cmp	al, 'X'
	jz	._1
;	mov	esi, 8
;	cmp	al, 'O'
;	jz	._1
;	mov	esi, 2
;	cmp	al, 'B'
;	jz	._1
	sub	rdi, 2
.s10:	mov	esi, 10
._1:;	Первый значащий символ может быть только цифрой.
	movzx	eax, byte[rdi]
	inc	rdi
	sub	eax, '0'
	jc	.fail
	cmp	eax, 9
	jbe	._1d
	and	eax, not (('a' - '0') xor ('A' - '0'))
	sub	eax, 'A' - '0' - 10
	jc	.fail
	cmp	eax, 0Fh
	ja	.fail
._1d:	cvtsi2sd xmm0, eax
	cvtsi2sd xmm1, esi
	cmp	eax, esi
	ja	.fail
.next:	movzx	eax, byte[rdi]
	inc	rdi
	cmp	eax, '_'
	jz	.next
	sub	eax, '0'
	jc	.done
	cmp	eax, 9
	jbe	.dgt
;	Для 'P' (0x50) и 'p' (0x40) маска 0xdf (см. далее) не подходит.
	cmp	eax, 'p' - '0'
	je	.exp_p
	cmp	eax, 'P' - '0'
	je	.exp_p
	and	eax, not (('a' - '0') xor ('A' - '0'))
	sub	eax, 'A' - '0' - 10
	jc	.done
	cmp	eax, 0Fh
	ja	.done
.dgt:	cvtsi2sd xmm2, eax
	cmp	eax, esi
	ja	.done
	mulsd	xmm0, xmm1
	addsd	xmm0, xmm2
	jmp	.next
.done:;	Проверяем, обработана ли вся входная строка.
	pop	rsi
	caml_string_length rsi, rcx, rdx
	dec	rdi
	sub	rdi, rcx
	cmp	rsi, rdi
	jnz	.fail2
;	Формируем вещественное число.
	mov	Val_header[alloc_small_ptr_backup], 1 wosize + Double_tag
;	cvtsi2sd xmm0, rax
; 	Устанавливаем знак в соответствии с наличием '-'.
	movq	xmm1, sign
	xorpd	xmm0, xmm1
	movsd	[alloc_small_ptr_backup + sizeof value], xmm0
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
;	'P' экспонента - степень двойки.
.exp_p:	zero	eax
	mov	esi, 10
	cmp	byte[rdi], 0
	jz	.fail
;!!!	Следует учесть отрицательные значения.
.exp_p_scan:
	movzx	ecx, byte[rdi]
	inc	rdi
	sub	ecx, '0'
	jc	.exp_p_done
	cmp	ecx, 9
	ja	.exp_p_done
	mul	esi
	jo	.fail
	add	eax, ecx
	jmp	.exp_p_scan
.exp_p_done:
	add	eax, 1023	; 0й порядок
;	В оригинале допустим диапазон INT_MIN .. INT_MAX
	cmp	eax, 1 shl 11
	jae	.fail
	shl	rax, 52
	movq	xmm1, rax
	mulsd	xmm0, xmm1
	jmp	.done
; 	При вызове caml_failwith нет необходимости выравнивать стек
.fail:;	pop	rdi
.fail2:	lea	rdi, [.msg]
	jmp	caml_failwith
.msg:	db	'float_of_string', 0
restore	sign
end C_primitive


; Возвращает целое OCaml value, преобразованное из вещественного числа.
; RDI - адрес вещественного числа.
C_primitive caml_int_of_float
	cvttsd2si rax, [rdi]
	Val_int	rax
	ret
end C_primitive


; Возвращает вещественное число, равное целому на входе
; RDI - целое OCaml value.
C_primitive caml_float_of_int
	mov	eax, 1 wosize or Double_tag
	mov	[alloc_small_ptr_backup], rax
	Int_val	rdi
	cvtsi2sd xmm0, rdi
	movsd	[alloc_small_ptr_backup + sizeof value], xmm0
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


C_primitive caml_neg_float
end C_primitive


C_primitive caml_abs_float
end C_primitive


; Возвращает сумму 2-х вещественных чисел.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_add_float
	mov	Val_header[alloc_small_ptr_backup], 1 wosize + Double_tag
	movsd	xmm0, [rdi]
	addsd	xmm0, [rsi]
	movsd	[alloc_small_ptr_backup + sizeof value], xmm0
	lea	rax, [alloc_small_ptr_backup + 1 * sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


; Возвращает разность 2-х вещественных чисел.
; RDI - адрес уменьшаемого;
; RSI - адрес вычитаемого.
C_primitive caml_sub_float
	mov	Val_header[alloc_small_ptr_backup], 1 wosize + Double_tag
	movsd	xmm0, [rdi]
	subsd	xmm0, [rsi]
	movsd	[alloc_small_ptr_backup + sizeof value], xmm0
	lea	rax, [alloc_small_ptr_backup + 1 * sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


; Возвращает произведение 2-х вещественных чисел.
; RDI - адрес 1-го множителя;
; RSI - адрес 2-го множителя.
C_primitive caml_mul_float
	mov	Val_header[alloc_small_ptr_backup], 1 wosize + Double_tag
	movsd	xmm0, [rdi]
	mulsd	xmm0, [rsi]
	movsd	[alloc_small_ptr_backup + sizeof value], xmm0
	lea	rax, [alloc_small_ptr_backup + 1 * sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


; Возвращает частное от деления 2-х вещественных чисел.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_div_float
	mov	Val_header[alloc_small_ptr_backup], 1 wosize + Double_tag
	movsd	xmm0, [rdi]
	divsd	xmm0, [rsi]
	movsd	[alloc_small_ptr_backup + sizeof value], xmm0
	lea	rax, [alloc_small_ptr_backup + 1 * sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


C_primitive caml_exp_float
end C_primitive


C_primitive caml_floor_float
end C_primitive


C_primitive caml_fmod_float
end C_primitive


C_primitive caml_frexp_float
end C_primitive


C_primitive caml_ldexp_float
end C_primitive


C_primitive caml_log_float
end C_primitive


C_primitive caml_log10_float
end C_primitive


C_primitive caml_modf_float
end C_primitive


C_primitive caml_sqrt_float
end C_primitive


C_primitive caml_power_float
end C_primitive


C_primitive caml_sin_float
end C_primitive


C_primitive caml_sinh_float
end C_primitive


C_primitive caml_cos_float
end C_primitive


C_primitive caml_cosh_float
end C_primitive


C_primitive caml_tan_float
end C_primitive


C_primitive caml_tanh_float
end C_primitive


C_primitive caml_asin_float
end C_primitive


C_primitive caml_acos_float
end C_primitive


; Возвращает арктангенс вещественного числа.
; RDI - адрес агремента.
C_primitive caml_atan_float
; только для аргумента 1.0
C_primitive_stub
	mov	Val_header[alloc_small_ptr_backup], 1 wosize + Double_tag
	mov	rax, 0x3ff0000000000000
	cmp	rax, [rdi]
	jnz	.@
	mov	rax, 0x3fe921fb54442d18
	mov	[alloc_small_ptr_backup + sizeof value], rax
	lea	rax, [alloc_small_ptr_backup + 1 * sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
.@:	int3
end C_primitive


C_primitive caml_atan2_float
end C_primitive


C_primitive caml_ceil_float
end C_primitive


C_primitive caml_hypot_float
end C_primitive


C_primitive caml_expm1_float
end C_primitive


C_primitive caml_log1p_float
end C_primitive


C_primitive caml_copysign_float
end C_primitive


; При сравнении:
; RDI - адрес 1-го вещественного числа
; RSI - адрес 2-го вещественного числа
if GENERIC_COMPARE
caml_neq_float	:= caml_notequal
else
C_primitive caml_neq_float
end C_primitive
end if


if GENERIC_COMPARE
caml_eq_float	:= caml_equal
else
C_primitive caml_eq_float
end C_primitive
end if


if GENERIC_COMPARE
caml_le_float	:= caml_lessequal
else
C_primitive caml_le_float
end C_primitive
end if


if GENERIC_COMPARE
caml_lt_float	:= caml_lessthan
else
C_primitive caml_lt_float
end C_primitive
end if


if GENERIC_COMPARE
caml_ge_float	:= caml_greaterequal
else
C_primitive caml_ge_float
end C_primitive
end if


if GENERIC_COMPARE
caml_gt_float	:= caml_greaterthan
else
C_primitive caml_gt_float
end C_primitive
end if


; Возвращает результат сравнения 2-х вещественных чисел:
; Val_int 1	- 1е > 2го;
; Val_int 0	- числа равны;
; Val_int -1	- 1е < 2го;
; RDI - адрес 1-го числа;
; RSI - адрес 2-го числа.
if GENERIC_COMPARE
caml_float_compare := compare_val
else
C_primitive caml_float_compare
end C_primitive
end if


FP_normal	:= 0
FP_subnormal	:= 1
FP_zero		:= 2
FP_infinite	:= 3
FP_nan		:= 4
; Возвращает тип вещественного числа.
; RDI - адрес числа.
C_primitive caml_classify_float
	mov	eax, Val_int FP_normal
	mov	rdx, [rdi]
;	Убираем знак.
	mov	ecx, Val_int FP_zero
	add	rdx, rdx
	cmovz	eax, ecx
;	Проверяем экспоненту.
	shr	rdx, 52 + 1
	mov	ecx, Val_int FP_subnormal
	cmovz	eax, ecx
	cmp	edx, 7ffh
	jz	.nans
	ret
.nans:	mov	rdx, [rdi]
	shl	rdx, 11 + 1
	mov	eax, Val_int FP_nan
	mov	ecx, Val_int FP_infinite
	cmovz	eax, ecx
	ret
end C_primitive
