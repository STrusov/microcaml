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
	jz	.f
	dec	r8
;	однако, функция вызывается и со следующей строкой формата:
	cmp	dword[rdi], '%.6f'
	jnz	.fmt
.f:	mov	rdx, [rsi]
;	Поскольку sprintf различает 0.0 и -0.0, inf и -inf,
;	определим знак числа и выведем символ '-' для отрицательных.
	mov	rax, Negative_double
	test	[rsi], rax
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
;	Выделяем целую часть, округляя к 0, и форматируем её в строку.
	cvttsd2si rsi, xmm0
	call	format_nativeint_dec
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + rax]
;	Выделяем дробную часть абсолютного значения числа.
	cvttsd2si rdx, xmm0
	cvtsi2sd xmm1, rdx
	subsd	xmm0, xmm1	; дробная часть
	test	r8, r8
	jns	.g12
;	Выделяем 6 знаков для случая '%.6f'
	mov	eax, 1000000
	cvtsi2sd xmm1, eax
	mulsd	xmm0, xmm1
;	Преобразуем без усечения, иначе 0.1 -> 0.09999.
;	.1234567 выводится как .123457, что соответствует sprintf (и OCaml).
	cvtsd2si esi, xmm0
;	format_nativeint_dec не выводит незначащие нули,
;	создаём фиктивный значащий старший разряд, что бы вывести остальные.
	add	esi, eax
;	Выводим число, содержащее требуемую дробную часть.
	call	format_nativeint_dec
;	Располагаем десятичную точку (OCaml не использует локализацию?)
;	поверх единицы в старшем разряде, полученной прибавлением 1000000 ранее.
	mov	byte[alloc_small_ptr_backup], '.'
.exit:	lea	rdi, [rax + alloc_small_ptr_backup]
	pop	alloc_small_ptr_backup
	sub	rdi, alloc_small_ptr_backup
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup - sizeof value]
	jmp	caml_alloc_string
;	Дробная часть формата "%.12g". Выводятся только значащие цифры.
.g12:	mov	byte[alloc_small_ptr_backup], '.'
	inc	alloc_small_ptr_backup
;	В eax количество уже выведенных цифр.
;	В rdx целая часть. Если она 0, значит была выведена незначащая цифра.
;	Вычислим в ecx, сколько осталось вывести из 12-ти значащих цифр.
	test	rdx, rdx
	mov	edx, 13
	mov	ecx, 12
	cmovz	ecx, edx
	sub	ecx, eax
	jbe	.exit
;	Корректируем значение остатка, что бы избежать округления значений,
;	имеющих неточное представление: 0.12345678912 -> 0.123456789119
;!!!	Константы (данная и следующая) получены эмпирически и требуют уточнения.
	mov	rax, 3e-17
	movq	xmm2, rax
	addsd	xmm0, xmm2
;	Нулём считаем значения меньшие или равные данному:
	mov	rax, 1e-5
	movq	xmm3, rax
	mov	eax, 10
	cvtsi2sd xmm2, eax
.g12_digit:
;	Если остаток отличен от 0 на величину дельты (xmm3),
;	выводим старшую цифру остатка, умножая на 10.
	zero	eax
	ucomisd	xmm0, xmm3
	jbe	.exit
	mulsd	xmm0, xmm2
	cvttsd2si eax, xmm0
	cvtsi2sd xmm1, eax
	subsd	xmm0, xmm1	; дробная часть
	add	eax, '0'
	mov	[alloc_small_ptr_backup], al
	inc	alloc_small_ptr_backup
	loop	.g12_digit
	zero	eax
	jmp	.exit
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


C_primitive caml_float_of_string
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


C_primitive caml_atan_float
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


C_primitive caml_classify_float
end C_primitive
