; Процедуры (C примитивы) для работы с вещественными числами двойной точности.
; float здесь соотвествует типу double в C.


Negative_double	:= 0x8000000000000000	; знак в 63-м бите, согласно IEEE 754
Infinity	:= 0x7ff0000000000000
;NaN		:= 0x7fffffffffffffff
NaN		:= 0x7ff0000000000001
Mantissa_bits	:= 52

; Преобразует вещественное число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат вывода;
; RSI - вещественное число (в OCaml-представлении).
C_primitive caml_format_float
C_primitive_stub
	mov	rsi, [rsi]
	jmp	caml_alloc_sprintf1
end C_primitive


; Преобразует вещественное число в строку, располагая в текущие адреса кучи.
; Может приводить к инкременту указателя кучи.
; Возвращает в RAX длину строки-результата, выходящую за пределы указателя кучи.
; DIL - формат (символ a e f g).
; DIH - верхний/нижний регистр. 0 для e f g и ('a' xor 'A') для E F G.
; RSI - двоичное представление вещественного числа.
; EDX - точность (количество значащих разрядов); отрицательна, если не задана.
;	52+1 бита мантиссы позволяют хранить 15 десятичных разрядов.
; Отрицательная точность не встречалась и не обрабатывается.
; R8 и R9 не используются по требованию caml_alloc_sprintf1.
format_floating_point_number:
exp	equ r11
fmt	equ r10
fmtl	equ r10l
	mov	ecx, edx
;	mov	fmt, rdi	; сохраняется в format_nativeint
;	Обнуляем старшие 32 разряда, в них дальше может сохраняться кол-во 0-й.
	mov	r10d, edi
;	Поскольку sprintf различает 0.0 и -0.0, inf и -inf,
;	определим знак числа и выведем символ '-' для отрицательных.
	test	rsi, rsi
	jns	.positive
	mov	byte[alloc_small_ptr_backup], '-'
	inc	alloc_small_ptr_backup
	mov	rax, not Negative_double
	and	rsi, rax	; абсолютное значение числа
.positive:
	mov	rax, NaN
	cmp	rsi, rax
	jz	.nan
	mov	rax, Infinity
	cmp	rsi, rax
	jz	.infinity
	cmp	fmtl, 'a'
	je	.a_format
	movq	xmm0, rsi
	cmp	fmtl, 'e'
	je	.e_format
;	%g - если 0.0001 > значение > 0, выводим в формате e.
	cmp	fmtl, 'g'
	jne	.f_format
	test	rsi, rsi
	je	.f_format
;	Если точность равна 0, следует вывести как минимум один разряд.
;	lea	edx, [rcx + 1]
	inc	edx
	test	ecx, ecx
	cmovz	ecx, edx
	mov	rax, 0.000095	; при единичной точности округляется до 0.0001
	cmp	rsi, rax
	jb	.e_format_g
;	Для дробных значений следует увеличить точность
;	на количество нулей после разделителя.
	mov	rax, 0.1
	cmp	rsi, rax
	lea	edx, [rcx + 1]
	cmovc	ecx, edx
	mov	rax, 0.01
	cmp	rsi, rax
	lea	edx, [rcx + 1]
	cmovc	ecx, edx
	mov	rax, 0.001
	cmp	rsi, rax
	lea	edx, [rcx + 1]
	cmovc	ecx, edx
;	%g - если целая часть равна 0, она выводится помимо значащих разрядов
;	дробной части; округляем к 0, что бы увеличить точность в таком случае.
	cvttsd2si rsi, xmm0
	lea	edx, [rcx + 1]
	test	rsi, rsi
	cmovz	ecx, edx
.f_format:
	zero	edx
	mov	eax, 10
	cvtsd2si rsi, xmm0
;	Отдельно обработаем значения, выходящие за диапазон знакового целого,
;	Тогда RSI = 0x8000000000000000. Иные отрицательные значения исключены.
	test	rsi, rsi
	js	.f_format_big
.cint:	inc	edx
	cmp	rsi, rax
	jc	.calc_fmt
	lea	rax, [rax * 5]
	add	rax, rax
	jmp	.cint
;	%g - вычисляем количество цифр после разделителя (известно общее).
;	%f - вычисляем общее количество цифр (известно количество в дробной части).
.calc_fmt:
	cmp	fmtl, 'g'
	jnz	.total
;	%g - если для вывода значения требуется в целой части знаков больше,
;	     чем точность, выводим в формате e.
	cmp	ecx, edx
	jc	.e_format_g
	sub	ecx, edx
;	%g - если число целое, обнуляем формат, что бы избежать удаления нулей
;	в младших разрядах (см. .g_0s:).
	cmovz	fmt, rcx
.total:	add	edx, ecx
;	Десятичный разделитель (OCaml не использует локализацию?)
	mov	edi, DECIMAL_SEPARATOR
	shl	rdi, 32
	test	ecx, ecx
	jz	.prec0
;	64-х разрядное число даёт 19 десятичных разрядов, следует избежать
;	переполнения при умножении.
	mov	eax, 19;+1
	sub	eax, edx
	jnc	.d19
	add	ecx, eax
	add	edx, eax
	neg	eax
	shl	rax, 32
	or	fmt, rax
.d19:
;	Десятичный разделитель увеличивает количество  символов на 1.
	inc	edx
;	Указываем его позицию от младшего разряда (дробной части) числа.
	lea	rdi, [rdi + rcx + 1]
;	Перенесём требуемое после запятой количество знаков в целую часть,
;	умножив на 10 в степени n. Результат округляем.
	test	ecx, ecx
	jz	.prec0
	mov	eax, 1
;	Возведение в степень n выполняем сдвигом + сложением (lea) n раз,
;	а не двоичным разложением n, поскольку для малых n количество итераций
;	различается незначительно (5 при n=6), но нет умножения и ветвления.
.pow:	lea	rax, [rax * 5]
	add	rax, rax
;	jc	.overflow
	dec	ecx
	jnz	.pow
	cvtsi2sd xmm1, rax
	mulsd	xmm0, xmm1
.prec0:	cvtsd2si rsi, xmm0
;	Превышающие 92233720368547752.0 значения проходят проверку на кол-во
;	разрядов, но выходят за диапазон знаковых целых.
	test	rsi, rsi
	jns	.format_decimal
	mov	rax, 0.1
	movq	xmm1, rax
	mulsd	xmm0, xmm1
	dec	edx
	dec	rdi
	cvtsd2si rsi, xmm0
	mov	rax, 1 shl 32
	add	fmt, rax
.format_decimal:
;	Форматируем целое представление числа в строку.
	call	format_nativeint_n
;	%g - незначащие нули справа следует откинуть.
	cmp	fmtl, 'g'
	je	.g_0s
;	%e - следует вывести значение экспоненты.
	cmp	fmtl, 'e'
	je	.e_exp
;	Для %g, выводимого как %e, исключаем незначащие нули перед экспонентой.
	cmp	fmtl, 'G'
	je	.g_exp
;	%f - возможно, требуется вывести дополнительные 0-ли в младших разрядах.
	shr	fmt, 32
	jnz	.f_0s
.exit:	ret
.f_0s:	mov	byte[alloc_small_ptr_backup + rax], '0'
	inc	eax
	dec	fmt
	jnz	.f_0s
	ret
.g_0s:	cmp	byte[alloc_small_ptr_backup + rax - 1], '0'
	jnz	.g_dot
	dec	eax
	jmp	.g_0s
;	Десятичный разделитель нужен только если есть дробная часть.
.g_dot: cmp	byte[alloc_small_ptr_backup + rax - 1], '.'
	jnz	.exit
	dec	eax
	ret
.infinity:
if ORIGINAL_INFINITY_MESSAGE
;	OCaml для формата a выводит infinity (см. caml_hexstring_of_float()).
	cmp	fmtl, 'a'
	jnz	.inf
	mov	rax, 'infinity'
	mov	[alloc_small_ptr_backup], rax
	mov	eax, 8
	ret
end if
.inf:	mov	dword[alloc_small_ptr_backup], 'inf'
.exit3:	mov	eax, 3
	ret
.nan:	mov	dword[alloc_small_ptr_backup], 'nan'
	jmp	.exit3
.f_format_big:
	cmp	fmtl, 'g'
	jz	.e_format_g
;	Делим на 10, пока не попадём в диапазон знакового целого. Практическая
;	польза подобных представлений не достаточна для усложнения алгоритма.
	mov	rax, 0.1
	movq	xmm1, rax
	zero	eax
.f_nrm:	mulsd	xmm0, xmm1
	inc	eax
	cvttsd2si rsi, xmm0
	test	rsi, rsi
	js	.f_nrm
	zero	rdi
	mov	exp, rcx
	mov	fmt, rax
	mov	rax, 1000000000000000000
	cmp	rsi, rax
	mov	edx, 19
	lea	eax, [rdx - 1]
	cmovc	edx, eax
	call	format_nativeint_n
	add	fmt, exp
.f_0:	mov	cl, '0'
	mov	dl, '.'
	cmp	fmt, exp
	cmovz	ecx, edx
	mov	byte[alloc_small_ptr_backup + rax], cl
	inc	eax
	dec	fmt
	jns	.f_0
;	Завершающая точка исключается.
	lea	ecx, [rax - 1]
	test	exp, exp
	cmovz	eax, ecx
	ret
.a_format:
;	Выделяем экспоненту.
	mov	exp, rsi
	shr	exp, Mantissa_bits
;	У нормализованных чисел в старшем разряде неявная 1.
	jz	.a_denormal
	mov	dword[alloc_small_ptr_backup], '0x1'
	add	alloc_small_ptr_backup, 3
	sub	exp, 1023
.a_fract:
	mov	rax, 1 shl Mantissa_bits - 1
	and	rsi, rax
;	Разделитель не выводится:
;	- если точность нулевая;
;	- если точность не задана (отрицательна) и дробная часть нулевая.
	test	edx, edx
	mov	eax, edx
	cmovs	rax, rsi
	test	rax, rax
	jz	.a_exp
;	Сдвигаем значащие полубайты в старшие разряды.
	mov	cl, 64 - Mantissa_bits
	shl	rsi, cl
	mov	eax, 63
	bsf	rcx, rsi
	cmovz	ecx, eax
;	Количество подлежащих выводу разрядов.
	shr	ecx, 2
	neg	ecx
	add	ecx, 16
;	Если точность не задана (отрицательна), выводим все значащие разряды.
	test	edx, edx
	cmovns	ecx, edx
	mov	byte[alloc_small_ptr_backup], DECIMAL_SEPARATOR
	inc	alloc_small_ptr_backup
	mov	dl, fmtl	; 'a'
	call	format_nativeint_hex_n
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + rax]
;	Выводим экспоненту.
.a_exp:	mov	cx, 'p-'
	mov	ax, 'p+'
	zero	edx
.exp:	mov	rsi, exp
	neg	rsi
	test	exp, exp
	cmovs	eax, ecx
	cmovns	rsi, exp
	shr	fmt, 8
	xor	al, fmtl
	mov	[alloc_small_ptr_backup], ax
	add	alloc_small_ptr_backup, 2
	call	format_nativeint_pos
	ret
.a_denormal:
	mov	dword[alloc_small_ptr_backup], '0x0'
	add	alloc_small_ptr_backup, 3
	lea	rax, [exp - 1022]
	test	esi, esi
	cmovnz	exp, rax
	jmp	.a_fract
;	Возможен единственный 0 в целой части.
.g_exp: dec	eax
	jz	.g_e
	cmp	byte[alloc_small_ptr_backup + rax], '0'
	jz	.g_exp
	cmp	byte[alloc_small_ptr_backup + rax], DECIMAL_SEPARATOR
	jz	.e_exp
.g_e:	inc	eax
;	Результат округления возможен 10.0, следует скорректировать его.
;	В таком случае в esi после format_nativeint_pos остаётся 1.
.e_exp:	test	esi, esi
	jz	.e_e
	mov	byte[alloc_small_ptr_backup], '1'
	inc	exp
.e_e:	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + rax]
	mov	cx, 'e-'
	mov	ax, 'e+'
	mov	edx, 2	; минимум 2 цифры.
	jmp	.exp
.e_format_g:
	dec	ecx
	mov	fmtl, 'G'	; особый вариант обработки экспоненты.
	movq	rsi, xmm0
;	%e - следует преобразовать число к виду d.ddd, вычислив экспоненту.
.e_format:
	zero	exp
	mov	rax, 10.0
	movq	xmm2, rax
	cmp	rax, rsi
	lea	rdx, [.exps10]
	jbe	.e_big
;	Числа с одним и менее целым разрядом - умножаем до нормализации
;	представления (1 разряд в целой части). Алгоритм соответствует
;	возведению в степень бинарным разложением показателя.
;	(см. для примера uclibc-ng/libc/stdio/_fpmaxtostr.c)
	mov	eax, 1 shl (.exps10_size - 1)
.e_sl:	movsd	xmm1, [rdx]
	mulsd	xmm1, xmm0
	ucomisd	xmm1, xmm2
	jae	.e_s0
	movsd	xmm0, xmm1
	sub	exp, rax
.e_s0:	add	rdx, 8
	shr	eax, 1
	jnz	.e_sl
;	%e - количество цифр после разделителя известно и равно точности,
;	     общее на 1 больше.
	mov	edx, 1
	jmp	.total
;	Числа с более чем одним целым разрядом -
;	делим до нормализации представления.
.e_big:	mov	rax, 1.0
	movq	xmm2, rax
	mov	eax, 1 shl (.exps10_size - 1)
	add	rdx, 8 * .exps10_size
.e_bl:	movsd	xmm1, [rdx]
	mulsd	xmm1, xmm0
	ucomisd	xmm1, xmm2
	jb	.e_b0
	movsd	xmm0, xmm1
	add	exp, rax
.e_b0:	add	rdx, 8
	shr	eax, 1
	jnz	.e_bl
	mov	edx, 1
	jmp	.total
virtual QConst
.exps10		dq 1e256, 1e128, 1e64, 1e32, 1e16, 1e8, 1e4, 100.0, 10.0
.exps10_size := ($-.exps10)/8
; Замена деления умножением в данном случае может привести к потери точности,
; поскольку множители не являются степенью 2.
		dq 1e-256, 1e-128, 1e-64, 1e-32, 1e-16, 1e-8, 1e-4, 0.01, 0.1
end virtual
restore exp, fmt, fmtl

; Преобразует вещественное число в строковое шестнадцатеричное представление,
; (см. формат %a caml_alloc_sprintf1), располагая в текущие адреса кучи.
; Возвращает в RAX длину строки-результата.
; RDI - вещественное число (в OCaml-представлении).
; RSI - точности (OCaml-целое).
; RDX - флаг - пробел или + (OCaml-целое).
C_primitive caml_hexstring_of_float
;	Пролог частично повторяет caml_alloc_sprintf1.
;	Создаём заголовок с нулевой длиной. Скорректируем её по готовности строки.
	mov	qword[alloc_small_ptr_backup], String_tag
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof value]
	push	alloc_small_ptr_backup
	Int_val	rsi
	Int_val	edx
	mov	cl, dl
	mov	r11, rsi	; precision
	mov	rsi, [rdi]
	zero	r9		; fmtlen
	jmp	caml_alloc_sprintf1.floating_point_number_a
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
virtual Const
.msg:	db	'float_of_string', 0
end virtual
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
