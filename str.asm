; Процедуры (C примитивы) для работы с последовательностями байт (строками).


; Вычисляет размер строки в байтах.
macro caml_string_length str_reg, result_reg, tmp_reg
	mov	result_reg, [str_reg - sizeof value]
;	from_wosize	result_reg
	shr	result_reg, wosize_shift - sizeof_value_log2
	and	result_reg, not (sizeof value - 1)
	dec	result_reg
	movzx	tmp_reg, byte[str_reg + result_reg]
	sub	result_reg, tmp_reg
end macro


; RDI - адрес строки (за заголовком)
C_primitive caml_ml_string_length
	caml_string_length rdi, rax, rcx
	Val_int	rax
	retn
end C_primitive


caml_ml_bytes_length := caml_ml_string_length


C_primitive caml_create_string
end C_primitive


; RDI - количество байт для строки в формате OCaml.
C_primitive caml_create_bytes
	Int_val	rdi
	mov	rcx, Max_wosize * sizeof value
	cmp	rdi, rcx
	jbe	caml_alloc_string
	lea	rdi, [.msg]
	jmp	caml_invalid_argument
.msg	db	"Bytes.create", 0
end C_primitive


; Возвращает один из символов строки.
; RDI - адрес строки.
; RSI - индекс символа (OCaml value).
C_primitive caml_string_get
	Int_val	rsi
	js	caml_array_bound_error
	caml_string_length	rdi, rcx, rax
	cmp	rsi, rcx
	jae	caml_array_bound_error
	movzx	eax, byte[rdi + rsi]
	Val_int	eax
	ret
end C_primitive


caml_bytes_get	:= caml_string_get

caml_bytes_set := caml_string_set


; Модифицирует один из символов строки.
; RDI - адрес строки;
; RSI - индекс символа (OCaml value);
; EDX - новое значение.
C_primitive caml_string_set
	Int_val	rsi
	js	caml_array_bound_error
	caml_string_length	rdi, rcx, rax
	cmp	rsi, rcx
	jae	caml_array_bound_error
	Int_val	edx
	mov	[rdi + rsi], dl
	Val_int	eax
	ret
end C_primitive


C_primitive caml_string_get16
end C_primitive


C_primitive caml_string_get32
end C_primitive


C_primitive caml_string_get64
end C_primitive


C_primitive caml_string_set16
end C_primitive


C_primitive caml_string_set32
end C_primitive


C_primitive caml_string_set64
end C_primitive


; Возвращает результат сравнения строк:
; Val_true - строки идентичны;
; Val_false - строки различаются.
; RDI - 1-я строка;
; RSI - 2-я строка.
if 0;GENERIC_COMPARE
caml_string_equal := caml_equal
else
C_primitive caml_string_equal
	mov	eax, Val_true
.cmp:	mov	rcx, Val_header[rsi - sizeof value]
	mov	rdx, Val_header[rdi - sizeof value]
	cmp	rcx, rdx
	jnz	.ret_n
	from_wosize rcx
;	При сравнении с конца строк сразу проверяется различие в длинах до байта.
.@:	mov	rdx, [rsi + (rcx - 1) * sizeof value]
	cmp	rdx, [rdi + (rcx - 1) * sizeof value]
	jnz	.ret_n
	dec	rcx
	jnz	.@
	ret
.ret_n:	xor	eax, Val_true xor Val_false
	ret
end C_primitive
end if


caml_bytes_equal := caml_string_equal


; Возвращает результат сравнения строк:
; Val_true - строки различаются.
; Val_false - строки идентичны;
; RDI - 1-я строка;
; RSI - 2-я строка.
if 0;GENERIC_COMPARE
caml_string_notequal := caml_notequal
else
C_primitive caml_string_notequal
	mov	eax, Val_false
	jmp	caml_string_equal.cmp
end C_primitive
end if


caml_bytes_notequal := caml_string_notequal


; Возвращает результат сравнения строк:
; Val_int 1	- 1я > 2й;
; Val_int 0	- строки равны;
; Val_int -1	- 1я < 2й;
; RDI - 1-я строка;
; RSI - 2-я строка.
if GENERIC_COMPARE
caml_string_compare := compare_val
else
C_primitive caml_string_compare
end C_primitive
end if


if GENERIC_COMPARE
caml_string_lessthan := caml_lessthan
else
C_primitive caml_string_lessthan
end C_primitive
end if


if GENERIC_COMPARE
caml_string_lessequal := caml_lessequal
else
C_primitive caml_string_lessequal
end C_primitive
end if


if GENERIC_COMPARE
caml_string_greaterthan := caml_greaterthan
else
C_primitive caml_string_greaterthan
end C_primitive
end if


if GENERIC_COMPARE
caml_string_greaterequal := caml_greaterequal
else
C_primitive caml_string_greaterequal
end C_primitive
end if


caml_bytes_compare := caml_string_compare

caml_bytes_lessthan := caml_string_lessthan

caml_bytes_lessequal := caml_string_lessequal

caml_bytes_greaterthan := caml_string_greaterthan

caml_bytes_greaterequal := caml_string_greaterequal


; RDI	- адрес начала источника.
; RSI	- смещение от адреса начала источника (OCaml value).
; RDX	- адрес начала приёмника.
; RCX	- смещение от адреса начала приёмника (OCaml value).
; R8	- количество байт для копирования.
C_primitive caml_blit_bytes
	Ulong_val	rsi
	lea	rsi, [rdi + rsi]
	Ulong_val	rcx
	lea	rdi, [rdx + rcx]
	Ulong_val	r8
	mov	rcx, r8
	shr	rcx, 3	; / 8
rep	movs	qword[rdi], [rsi]
	mov	rcx, r8
	and	rcx, 8 - 1
rep	movs	byte[rdi], [rsi]
	ret
end C_primitive


caml_blit_string := caml_blit_bytes


; Заполняет массив байт константой.
; RDI	- адрес начала массива.
; RSI	- смещение от начала массива (OCaml value).
; RDX	- количество байт для копирования.
; CX	- константа для заполнения (OCaml value).
C_primitive caml_fill_bytes
	Ulong_val	rsi
	Int_val	ecx
	Ulong_val	rdx
	lea	rdi, [rdi + rsi]
	mov	eax, ecx
	mov	rcx, rdx
rep	stos	byte[rdi]
	mov	eax, Val_unit
	ret
end C_primitive


caml_fill_string := caml_fill_bytes


C_primitive caml_bitvect_test
end C_primitive


; Преобразует число в OCaml-строку (с заголовком) согласно формата.
; RDI - Формат; см. format_of_iconv в stdlib/camlinternalFormat.ml
; RSI - Число для вывода (может быть как целым, так и вещественным).
; RDX - Для форматов %u %o %X и %x - маска с разрядами, подлежащими выводу.
;       Служит для корректного вывода int32 и OCaml-целых.
;
; OCaml обрабатывает строку формата при трансляции, упрощая передаваемый в
; данную процедуру первым аргументом результат и гарантируя (?) его валидность.
; Нижеследующее описание стандартной библиотеки Си местами не соотвествует
; принятым в OCaml спецификаторам конверсий. Приведено для описания поведения
; процедуры, частично реализующей функционал sprintf().
;
; Спецификация строки формата по ISO/IEC 9899:201x §7.21.6.1 (с сокращениями):
; 3. Формат является многобайтной последовательностью, начинающейся и
;    заканчивающийся полным Unicode символом (in initial shift state).
;    Может состоять из произвольного количества директив: рядовых символов
;    (отличные от %), выводимых без изменения; так же спецификаторов конверсии,
;    каждый из которых может привести к преобразованию и выводу последующих
;    аргументов¹⁾.
; 4. Каждый спецификатор конверсии начинается с символа %, после которого
;    следует:
;    - Ноль или более флагов (в любой последовательности), модифицирующих
;      значение спецификатора.
;    - Опциональная минимальная ширина поля. Если значение преобразованного
;      аргумента содержит символов менее, чем ширина поля, происходит дополнение
;      пробелами (по умолчанию) слева (или справа, в случае наличия флага
;      выравнивания по левому краю, описанного далее). Ширина поля имеет форму
;      звёздочки * (описанной делее) или натурального числа²⁾.
;    - Опциональная точность, определяющая минимальное количество выводимых
;      разрядов для преобразований d, i, o, u, x и X, количество знаков после
;      десятичного разделителя для преобразований a, A, e, E, f и F,
;      максимальное количество значащих цифр для преобразований g и G, либо
;      максимальным количеством байт бля вывода для преобразования s³⁾.
;      Точность имеет форму точки (.) с последующей звёздочкой * или опциональным
;      десятичным целым, при его отсутствии точность принимается равной нулю.
;      Если точность сопутствует любому другому спецификатору, поведение не определено.
;    - Опциональный модификатор длины, специфицирующий размер аргумента.
;    - Символ спецификатора конверсии, определяющий тип преобразования.
; 5. Как указано выше, ширина поля и точность могут быть обозначены звёздочкой.
;    В таком случае, значение определяется целочисленным аргументом.³⁾ [...]
; 6. Символы-флаги и их значения:
;    -   Результат преобразования выравнивается по левому краю поля. (Без данного
;        флага выравнивание по правому краю.) ³⁾
;    +   Результат преобразования числа со знаком всегда начинается с символов
;        плюса или минуса.
;    ' ' (пробел) Если первый символ преобразования знакового целого не является
;        + или -, перед числом добавляется пробел. Если указаны оба флага "пробел"
;        и +, флаг "пробел" игнорируется.
;     #  Выполняется преобразование в "альтернативную форму". Для конверсии o
;        увеличивается точность, в случае необходимости, что бы первым разрядом
;        был ноль (если значение и точность равны 0, выводится единственный 0).
;        Для конверсии x (и X) ненулевой результат предваряется префиксом 0x
;        (соответственно 0X). Для конверсий a, A, e, E, f, F, g и G результат
;        преобразования непременно содержит десятичный разделитель, даже если
;        за ним не следуют цифры. (Обычно десятичный разделитель выводится в
;        случае наличия дробной части.) Для конверсий g и G завершающие нули
;        не удаляются из результата. Для остальных конверсий поведение не определено.
;     0  Для конверсий d, i, o, u, x, X, a, A, e, E, f, F, g и G для заполнения
;        ширины поля вместо пробелов используются ведущие нули (следующие за
;        знаком числа или префиксом системы счисления), кроме случаев
;        бесконечности и NaN. В случае наличия одновременно флагов 0 и -, первый
;        игнорируется. Для конверсий d, i, o, u, x и X, если указана точность,
;        флаг 0 игнорируется. Для остальных конверсий поведение не определено.
; 7. Модификаторы длины и их значения (прим.: сокращено, исключены упоминания
;    о  спецификаторе конверсии n³⁾; размеры указаны в байтах, а не типах Си):
;    hh Указывает, что последующий спецификатор конверсии d, i, o, u, x или X
;       применяется к младшему байту аргумента.³⁾
;    h  Указывает, что последующий спецификатор конверсии d, i, o, u, x или X
;       применяется к двум младшим байтам аргумента.³⁾
;    l  Указывает, что последующий спецификатор конверсии d, i, o, u, x или X
;       применяется к 64-х разрядному аргументу (long в LP64).
;    ll Указывает, что последующий спецификатор конверсии d, i, o, u, x или X
;       применяется к 64-х разрядному аргументу (long long в LP64).
;    j  Указывает, что последующий спецификатор конверсии d, i, o, u, x или X
;       применяется к аргументу intmax_t или uintmax_t.³⁾
;    z  Указывает, что последующий спецификатор конверсии d, i, o, u, x или X
;       применяется к аргументу size_t.³⁾
;    t  Указывает, что последующий спецификатор конверсии d, i, o, u, x или X
;       применяется к аргументу ptrdiff_t.³⁾
;    L  Указывает, что последующий спецификатор конверсии a, A, e, E, f, F, g
;       или G применяется к аргументу long double.³⁾
;    Если модификатор длины указан для неупомянутых выше конверсиий, поведение
;    не определено.
; 8. Спецификаторы конверсий и их значение:
;    d,i  Целочисленный аргумент преобразуется в десятичное представление вида
;         [-]dddd. Точность определяет минимальное количество выводимых разрядов.
;    o,u,x,X  Целочисленный аргумент рассматривается как число без знака и
;         выводится в восьмеричном (o), десятичном (u) или шестнадцатеричном
;         (x и X) представлении; символы abcdef используются в конверсии x, а
;         ABCDEF в конверсии X. Точность определяет минимальное количество
;         выводимых разрядов; если значение представимо меньшим количеством цифр,
;         в старших разрядах выводятся незначащие нули. Точность по умолчанию 1.
;         При преобразовании нуля с нулевой точностью символы не выводятся.
;    f,F  Вещественный аргумент выводится в виде десятичной дроби [-]ddd.ddd,
;         где количество разрядов после десятичного разделителя равно значению
;         точности. Если точность не указана, принимается 6; если точность 0 и
;         флаг # не указан, десятичный разделитель не выводится. При наличии
;         десятичного разделителя, как минимум один разряд выводится перед ним.
;         Значение округляется до соответствующего количества знаков.
;         Вещественное значение, представляющее собой бесконечность, преобразуется
;         к виду [-]inf или [-]infinity, определяемому имплементацией.
;         Вещественное значение, представляющее собой NaN ("не число"),
;         преобразуется к виду [-]nan или [-]nan(определённая-имплементацией-
;         последовательность-символов). Для спецификатора F выводятся
;         соответственно INF, INFINITY или NAN.
;    e,E  Вещественный аргумент выводится в виде [-]d.ddde±dd, с единственным
;         разрядом (отличным от 0 при ненулевом аргументе) перед десятичным
;         разделителем и количеством знаков после него, равным точности; в случае
;         отсутствия последней, она принимается 6; если точность равна нулю и
;         флаг # не указан, десятичный разделитель не выводится. Значение
;         округляется до соответствующего количества знаков. Для спецификатора
;         E выводится символ E вместо e, представляющим экспоненту. Экспонента
;         всегда содержит минимум две цифры, но не более чем необходимо для
;         отображения экспоненты. Для нулевого аргумента экспонента равна нулю.
;         Вещественное значение, представляющее собой бесконечность или NaN,
;         выводится в соответствии со спецификатором f или F.
;    g,G  Вещественный аргумент выводится в зависимости от значения и точности
;         аналогично f или e (для G соответственно F или E). Пусть P равно
;         точности, если она ненулевая, 6, если она не указана, или 1 в случае
;         нулевой. Тогда, если при конверсия в стиле E экспонента равна X:
;         - при P > X ≥ -4 преобразование выполняется в стиле f (или F), где
;           точность принимается P-(X+1).
;         - иначе - в стиле e (или E) c точностью P-1.
;         В итоге, если флаг # не указан, из дробной части удаляются незначащие
;         нули.
;         Вещественное значение, представляющее собой бесконечность или NaN,
;         выводится в соответствии со спецификатором f или F.
;    a,A  Вещественный аргумент выводится в виде [-]0xh.hhhp±d, с одной
;         шестнадцатеричной цифрой (отличной от нуля, если аргумент является
;         нормализованным числом, и неспецифицированой в ином случае) до
;         разделителя и шестнадцатеричных цифр в количестве, равном точности,
;         после; если точность не указана, и FLT_RADIX является степенью 2,
;         она принимается достаточной для вывода числа без округления;
;         [случай для иного FLT_RADIX опущен]
;         если точность равна нулю и флаг # не указан, десятичный разделитель
;         не выводится. Символы abcdef и ABCDEF используются для конверсий a и A
;         соответственно. Конверсия A выводит число с X и P вместо x и p.
;         Экспонента всегда представляется как минимум одной цифрой, но не более,
;         чем достаточно для представления степени 2. Если значение аргумента
;         нулевое, экспонента равна нулю.
;         Вещественное значение, представляющее собой бесконечность или NaN,
;         выводится в соответствии со спецификатором f или F.⁴⁾
;    с    ³⁾ (символ)
;    s    ³⁾ (строка)
;    p    ³⁾ (указатель)
;    n    ³⁾ (указатель на знаковое целое, куда сохраняется количество
;            выведенных символов)
;    %    Выводится символ %. Конверсия аргументов не выполняется. Полный
;         спецификатор конверсии имеет вид %%.
; 9. Если спецификатор конверсии невалиден, результат не определён. Если тип
;    аргумента не соответствует спецификатору конверсии, поведение не определено.
;
; ¹⁾ Данная реализация обрабатывает единственный аргумент.
; ²⁾ 0 считается флагом, а не началом ширины поля.
; ³⁾ В OCaml не используется, как и в данной реализации.
; ⁴⁾ В OCaml используется отдельная функция caml_hexstring_of_float().
;
; Процедура вызывает format_nativeint и format_floating_point_number
; и требует сохранности r8 и r9 (первый адресует кучу, может быть найден
; сборщиком мусора на стеке и ошибочно расценен как указатель на блок).
proc caml_alloc_sprintf1
fmtsrc equ r8
fmtlen equ r9
precision equ r11
;	Создаём заголовок с нулевой длиной. Скорректируем её по готовности строки.
	mov	qword[alloc_small_ptr_backup], String_tag
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof value]
	push	alloc_small_ptr_backup
	caml_string_length rdi, fmtlen, rax
;	Копируем префикс формата, пока не встретится %
.copy_fmt:
;	При отсутствии формата (символа '%') число не выводится.
	test	fmtlen, fmtlen
	jz	.exit0
	mov	al, [rdi]
	inc	rdi
	dec	fmtlen
	cmp	al, '%'
	jz	.format
.cpf:	mov	[alloc_small_ptr_backup], al
	inc	alloc_small_ptr_backup
	jmp	.copy_fmt
;	Обрабатываем спецификаторы формата.
.format:
	zero	ecx	; cl хранит флаг.
	mov	al, [rdi]
	mov	fmtsrc, rdi
;	Возможен один из флагов: + пробел # (- и 0 обрабатываются уровнем выше).
.flag:	cmp	al, '+'
	jz	.found_flag
	cmp	al, ' '
	jz	.found_flag
	cmp	al, '#'
	jz	.found_flag
;	Опциональная ширина поля. Не встречалась.
.field_width:
	movzx	eax, byte[fmtsrc]
;	Опциональная точность, начинается с точки.
.precision:
	or	precision, -1	; по умолчанию точность не указана.
	cmp	al, '.'
	jnz	.length_modifier
	inc	fmtsrc
	dec	fmtlen
	zero	precision
.calc_prec:
	mov	al, [fmtsrc]
	sub	al, '0'
	cmp	al, 9
	jnbe	.length_modifier
	inc	fmtsrc
	dec	fmtlen
	lea	precision, [precision * 5]
	lea	precision, [precision * 2 + rax]
	jmp	.calc_prec
;	Опциональный модификатор длины: L l n - просто пропускаем.
;	В данной реализации размер определяется маской в RDX.
;	В OCaml l соответствует int32, L - int64, а n - nativeint.
.length_modifier:
	mov	al, [fmtsrc]
	inc	fmtsrc
	dec	fmtlen
	cmp	al, 'n'
	jz	.conversion_specifier
	or	al, 'a'-'A'
	cmp	al, 'l'
	jz	.conversion_specifier
	dec	fmtsrc
	inc	fmtlen
;	Спецификатор конверсии: d i u o x X f g e E
.conversion_specifier:
	mov	al, [fmtsrc]
	inc	fmtsrc
	dec	fmtlen
	cmp	al, 'd'
	jz	.signed_decimal
	cmp	al, 'i'
	jz	.signed_decimal
	cmp	al, 'u'
	jz	.unsigned_decimal
	cmp	al, 'x'
	jz	.hexadecimal
	cmp	al, 'X'
	jz	.HEXadecimal
	cmp	al, 'o'
	jz	.octal
	cmp	al, 'f'
	jz	.floating_point_number_f
	cmp	al, 'g'
	jz	.floating_point_number_g
;	cmp	al, 'a'
;	jz	.floating_point_number_a
	cmp	al, 'e'
	jz	.floating_point_number_e
	cmp	al, 'E'
	jz	.floating_point_number_E
;	Формат не распознан - выводим %
;	и откатываем источник на следующий за ним символ.
	add	fmtlen, fmtsrc
	sub	fmtlen, rdi
	mov	al, '%'
	jmp	.cpf
.found_flag:
	mov	cl, al
	inc	fmtsrc
	dec	fmtlen
	jmp	.field_width

;	Вызывается из caml_hexstring_of_float
.floating_point_number_a:
	mov	di, 'a'
	jmp	.fpn
.floating_point_number_e:
	mov	di, 'e'
	jmp	.fpn
.floating_point_number_E:
	mov	di, 'e' + ('a' xor 'A') shl 8
	jmp	.fpn
.floating_point_number_g:
	mov	di, 'g'
	mov	rdx, precision
	jmp	.fpn
.floating_point_number_f:
	mov	di, 'f'
.fpn:	mov	rdx, precision
;	Если задано флагами, выводим + или пробел.
;	- выводится функцией форматирования.
	test	rsi, rsi
	js	.ffmt
	mov	rax, 1 shl ' ' or 1 shl '+'
	shr	rax, cl
	test	eax, 1
	jz	.ffmt
	mov	[alloc_small_ptr_backup], cl
	inc	alloc_small_ptr_backup
.ffmt:	call	format_floating_point_number
	jmp	.copy_fmt_tail
.signed_decimal:
	test	rsi, rsi
	js	.neg
	mov	rax, 1 shl ' ' or 1 shl '+'
	shr	rax, cl
	test	eax, 1
	jnz	.scpy
	jmp	.unsigned_decimal
.neg:	neg	rsi
	mov	cl, '-'
.scpy:	mov	[alloc_small_ptr_backup], cl
	inc	alloc_small_ptr_backup
.unsigned_decimal:
	and	rsi, rdx
	call	format_nativeint
	jmp	.copy_fmt_tail
.octal:
	cmp	cl, '#'
	jnz	.oct_f
	mov	byte[alloc_small_ptr_backup], '0'
	inc	alloc_small_ptr_backup
.oct_f:	and	rsi, rdx
	call	format_nativeint_oct
	jmp	.copy_fmt_tail
.hexadecimal:
	cmp	cl, '#'
	jnz	.hex_a
	mov	word[alloc_small_ptr_backup], '0x'
	add	alloc_small_ptr_backup, 2
.hex_a:	and	rsi, rdx
	mov	dl, 'a'
	jmp	.hex_f
.HEXadecimal:
	cmp	cl, '#'
	jnz	.hex_A
	mov	word[alloc_small_ptr_backup], '0X'
	add	alloc_small_ptr_backup, 2
.hex_A:	and	rsi, rdx
	mov	dl, 'A'
.hex_f:	call	format_nativeint_hex
;	Копируем остаток строки формата, при наличии.
.copy_fmt_tail:
	lea	rdi, [rax + alloc_small_ptr_backup]
	mov	rcx, fmtlen
	mov	rsi, fmtsrc
rep	movs	byte[rdi], [rsi]
.exit:	pop	alloc_small_ptr_backup
	sub	rdi, alloc_small_ptr_backup
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup - sizeof value]
	jmp	caml_alloc_string
.exit0:	mov	rdi, alloc_small_ptr_backup
	jmp	.exit
restore fmtlen, fmtsrc, precision
end proc
