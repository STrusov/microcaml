..C_PRIM_COUNT = 0
..C_PRIM_IMPLEMENTED = 0
..C_PRIM_UNIMPLEMENTED = 0

; Использовать ли для всех типов данных универсальную процедуру
; сравнения значений вместо специализированных.
GENERIC_COMPARE = 1

macro C_primitive name
name:
.C_primitive_name equ `name
..C_PRIM_COUNT = ..C_PRIM_COUNT + 1
end macro

macro end?.C_primitive!
	if $ = .
		int3
		..C_PRIM_UNIMPLEMENTED = ..C_PRIM_UNIMPLEMENTED + 1
	else
		..C_PRIM_IMPLEMENTED = ..C_PRIM_IMPLEMENTED + 1
	end if
end macro

macro C_primitive_stub
	display .C_primitive_name, ' stub ',10
end macro

macro caml_invalid_argument msg
	lea	rdi, [.m]
	puts	rdi
	mov	eax, -EINVAL
	jmp	sys_exit
.m	db	msg, 10, 0
end macro


C_primitive_first:

C_primitive caml_abs_float

end C_primitive



C_primitive caml_acos_float

end C_primitive



C_primitive caml_add_debug_info

end C_primitive



C_primitive caml_add_float

end C_primitive



C_primitive caml_alloc_dummy

end C_primitive



C_primitive caml_alloc_dummy_float

end C_primitive



C_primitive caml_alloc_dummy_function

end C_primitive



C_primitive caml_alloc_float_array

end C_primitive


; Копирует элементы из первого массива во второй.
; RDI - источник;
; RSI - начальный индекс источника;
; RDX - приёмник;
; RCX - начальный индекс приёмника;
; R8 - количество элементов.
C_primitive caml_array_blit
	Int_val rsi
	Int_val rcx
	Int_val r8
	lea	rsi, [rdi + rsi * sizeof value]
	lea	rdi, [rdx + rcx * sizeof value]
	mov	rcx, r8
;	Если приёмник попадает между началом и концом источника,
;	необходимо копировать от старших адресов к младшим.
;	rdi - rsi < размер (в байтах);
	shl	r8, 3	; * 8
	mov	rax, rdi
	sub	rax, rsi
	cmp	rax, r8
	jc	.topdown
rep	movs	qword[rdi], [rsi]
	mov	eax, Val_unit
	ret
.topdown:
	lea	rsi, [rsi + (rcx - 1) * sizeof value]
	lea	rdi, [rdi + (rcx - 1) * sizeof value]
	std
rep	movs	qword[rdi], [rsi]
	cld
	mov	eax, Val_unit
	ret
end C_primitive


; Возвращает элемент массива обычного или вещественных чисел.
; RDI - адрес массива
; RSI - индекс элемента (OCaml value)
C_primitive caml_array_get
	cmp	byte[rdi - sizeof value], Double_array_tag
	jz	caml_array_get_float
end C_primitive
; продолжает выполнение.


; Возвращает значение элемента массива.
; RDI - адрес массива
; RSI - индекс элемента (OCaml value)
C_primitive caml_array_get_addr
C_primitive_stub
	Long_val rsi
	js	.bound_error	; caml_array_bound_error
	mov	rax, Val_header[rdi - sizeof value]
	from_wosize rax
	cmp	rax, rsi
	jc	.bound_error
	mov	rax, [rdi + rsi * sizeof value]
	ret
.bound_error:
	caml_invalid_argument	'Выход за пределы массива'
end C_primitive


; Возвращает элемент массива вещественных чисел.
; RDI - адрес массива
; RSI - индекс элемента (OCaml value)
C_primitive caml_array_get_float
	Long_val rsi
	js	caml_array_get_addr.bound_error	; caml_array_bound_error
	mov	rax, Val_header[rdi - sizeof value]
	from_wosize rax
	cmp	rax, rsi
	jc	caml_array_get_addr.bound_error
	mov	Val_header[alloc_small_ptr_backup], 1 wosize or Double_tag
	mov	rax, [rdi + rsi * sizeof value]
	mov	Val_header[alloc_small_ptr_backup + sizeof value], rax
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive



C_primitive caml_array_set

end C_primitive



C_primitive caml_array_set_addr

end C_primitive



C_primitive caml_array_set_float

end C_primitive


; Следующие 3 функции в оригинале вызывает универсальную caml_array_gather.

; Возвращает (ссылку на) массив, созданный из подмножества элементов исходного.
; RDI - адрес исходного массива;
; RSI - номер (от 0) первого элемента подмножества.
; RDX - количество элементов подмножества.
C_primitive caml_array_sub
	Int_val	rdx
;	В случае итогового массива из 0 элементов возвращаем Atom(0)
	lea	rax, [Atom 0]
	jz	.exit
;	Создаём заголовок из тега исходного массива + размер нового.
	movzx	eax, byte[rdi - sizeof value]
	mov	rcx, rdx
	to_wosize rdx
	or	rax, rdx
;	Сохраняем ссылку на массив на случай сборки мусора.
	push	rdi
	mov	[alloc_small_ptr_backup], rax
;	Копируем подмножество элементов в новый массив.
	Int_val	rsi
	lea	rsi, [rdi + rsi * sizeof value]
	lea	rdi, [alloc_small_ptr_backup + sizeof value]
rep	movs	qword[rdi], [rsi]
	from_wosize rax
	neg	rax
	lea	rax, [rdi + rax * sizeof value]
	mov	alloc_small_ptr_backup, rdi
	pop	rdi
.exit:	ret
end C_primitive


; Возвращает ссылку на объединение 2-х массивов.
; RDI - 1-й массив;
; RSI - 2-й массив.
C_primitive caml_array_append
;	Суммируем размеры массивов, а тег копируем из 1го (прибавляя его к 0).
	mov	rdx, Val_header[rsi - sizeof value]
	mov	rcx, Val_header[rdi - sizeof value]
	and	rdx, not 0xff
	lea	rax, [rcx + rdx]
;	В случае итогового массива из 0 элементов возвращаем Atom(0)
	test	rax, not 0xff
	jz	.atom0
	mov	Val_header[alloc_small_ptr_backup], rax
;	Сохраняем ссылки на массивы на случай сборки мусора.
	push	rsi rdi
	mov	rsi, rdi
	from_wosize rcx
	from_wosize rdx
	lea	rdi, [alloc_small_ptr_backup + sizeof value]
rep	movs	qword[rdi], [rsi]
	pop	rsi	; Адрес первого массива более не нужен.
	mov	rsi, [rsp]
	mov	rcx, rdx
rep	movs	qword[rdi], [rsi]
	pop	rsi	; Адрес второго массива более не нужен.
	from_wosize rax
	neg	rax
	lea	rax, [rdi + rax * sizeof value]
	mov	alloc_small_ptr_backup, rdi
	ret
.atom0:	lea	rax, [Atom 0]
	ret
end C_primitive


; Возвращает объединённый массив.
; RDI - список подлежащих объединению массивов.
C_primitive caml_array_concat
	cmp	rdi, Val_int(0)
	jz	.atom0
;	Счётчик общего числа элементов в результирующем массиве.
;	В случае массива из 0 элементов вернём Atom(0).
	zero	rdx
;	Обнулим заголовок, что бы сборщик мусора мог определить частично
;	созданный блок. Далее копируем элементы. Заголовок скорректируем,
;	когда размер результирующего массива станет известен.
	mov	Val_header[alloc_small_ptr_backup], rdx
	mov	rax, rdi
	lea	rdi, [alloc_small_ptr_backup + sizeof value]
;	0-е поле элемента списка содержит ссылку на массив.
.cp_ar:	mov	rsi, [rax + 0 * sizeof value]
	mov	rcx, Val_header[rsi - sizeof value]
;	Суммируем длины и копируем тег.
	and	rdx, not 0xff
	add	rdx, rcx
;	Копируем очередной массив.
	from_wosize rcx
rep	movs	qword[rdi], [rsi]
;	1-е поле элемента списка содержит ссылку на следующий элемент,
;	либо Val_int(0).
	mov	rax, [rax + 1 * sizeof value]
	cmp	rax, Val_int(0)
	jnz	.cp_ar
	test	rdx, not 0xff
	jz	.atom0
	mov	Val_header[alloc_small_ptr_backup], rdx
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	mov	alloc_small_ptr_backup, rdi
	ret
.atom0:	lea	rax, [Atom 0]
	ret
end C_primitive


C_primitive caml_array_unsafe_get

end C_primitive



C_primitive caml_array_unsafe_get_float

end C_primitive



C_primitive caml_array_unsafe_set

end C_primitive



C_primitive caml_array_unsafe_set_addr

end C_primitive



C_primitive caml_array_unsafe_set_float

end C_primitive



C_primitive caml_asin_float

end C_primitive



C_primitive caml_atan2_float

end C_primitive



C_primitive caml_atan_float

end C_primitive



C_primitive caml_backtrace_status

end C_primitive



C_primitive caml_bitvect_test

end C_primitive


; RDI	- адрес начала источника.
; RSI	- смещение от адреса начала источника (OCaml value).
; RDX	- адрес начала приёмника.
; RCX	- смещение от адреса начала приёмника (OCaml value).
; R8	- количество байт для копирования.
C_primitive caml_blit_bytes
caml_blit_string:
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



C_primitive caml_bswap16

end C_primitive



C_primitive caml_bytes_compare

end C_primitive



C_primitive caml_bytes_equal

end C_primitive



C_primitive caml_bytes_get

end C_primitive



C_primitive caml_bytes_greaterequal

end C_primitive



C_primitive caml_bytes_greaterthan

end C_primitive



C_primitive caml_bytes_lessequal

end C_primitive



C_primitive caml_bytes_lessthan

end C_primitive



C_primitive caml_bytes_notequal

end C_primitive



C_primitive caml_bytes_set

end C_primitive



C_primitive caml_ceil_float

end C_primitive



C_primitive caml_channel_descriptor

end C_primitive



C_primitive caml_classify_float

end C_primitive



C_primitive caml_convert_raw_backtrace

end C_primitive



C_primitive caml_convert_raw_backtrace_slot

end C_primitive



C_primitive caml_copysign_float

end C_primitive



C_primitive caml_cos_float

end C_primitive



C_primitive caml_cosh_float

end C_primitive


; EDI - целое; количество байт для строки.
; Возвращает адрес строки (за заголовком).
proc caml_alloc_string
	mov	ecx, edi
;	size = (len + sizeof(value)) / sizeof(value);
	add	edi, sizeof value
	and	edi, not (sizeof value - 1)
	mov	edx, edi
	dec	edx
	sub	edx, ecx
	and	edx, (sizeof value - 1)
	mov	ecx, edi
	shr	ecx, sizeof_value_log2
;	shr	rdi, sizeof_value_log2
;	to_wosize rdi
	shl	rdi, wosize_shift - sizeof_value_log2
	or	rdi, String_tag
	mov	Val_header[alloc_small_ptr_backup], rdi
;	Завершающий байт = размер блока в байтах - 1 - длина строки
	mov	[alloc_small_ptr_backup + (1 + rcx) * sizeof value - 1], dl
;	Предыдущая команда может изменить содержимое alloc_small_ptr_backup,
;	потому порядок выполнения важен.
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + (rcx + 1) * sizeof value]
	ret
end proc


; RDI - количество байт для строки в формате OCaml.
C_primitive caml_create_bytes
	Long_val	rdi
	mov	rcx, Max_wosize * sizeof value
	cmp	rdi, rcx
	jbe	caml_alloc_string
	caml_invalid_argument "Bytes.create"
end C_primitive



C_primitive caml_create_string

end C_primitive



C_primitive caml_div_float

end C_primitive



C_primitive caml_dynlink_add_primitive

end C_primitive



C_primitive caml_dynlink_close_lib

end C_primitive



C_primitive caml_dynlink_get_current_libs

end C_primitive



C_primitive caml_dynlink_lookup_symbol

end C_primitive



C_primitive caml_dynlink_open_lib

end C_primitive


; RDI - требуемый размер стека (OCaml value)
; Нужно ли заранее отображать страницы стека?
C_primitive caml_ensure_stack_capacity
	ret
end C_primitive



C_primitive caml_ephe_blit_data

end C_primitive



C_primitive caml_ephe_blit_key

end C_primitive



C_primitive caml_ephe_check_data

end C_primitive



C_primitive caml_ephe_check_key

end C_primitive



C_primitive caml_ephe_create

end C_primitive



C_primitive caml_ephe_get_data

end C_primitive



C_primitive caml_ephe_get_data_copy

end C_primitive



C_primitive caml_ephe_get_key

end C_primitive



C_primitive caml_ephe_get_key_copy

end C_primitive



C_primitive caml_ephe_set_data

end C_primitive



C_primitive caml_ephe_set_key

end C_primitive



C_primitive caml_ephe_unset_data

end C_primitive



C_primitive caml_ephe_unset_key

end C_primitive


macro caml_string_length str_reg, result_reg, tmp_reg
	mov	result_reg, [str_reg - sizeof value]
;	from_wosize	result_reg
	shr	result_reg, wosize_shift - sizeof_value_log2
	and	result_reg, not (sizeof value - 1)
	dec	result_reg
	movzx	tmp_reg, byte[str_reg + result_reg]
	sub	result_reg, tmp_reg
end macro


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
	ja	.arbitrary_ptr
ud2
.arbitrary_ptr:
	mov	rax, rdi
	cmp	rax, rsi
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
.str_c:	mov	dl, [val1]
	cmp	dl, [val2]
	jnz	.result
	dec	rcx
	jnz	.str_c
;	Если длины строк совпадают, продолжаем сравнение оставшихся элементов.
	test	rax, rax
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


; RDI - адрес 1-го вещественного числа
; RSI - адрес 2-го вещественного числа
if GENERIC_COMPARE
caml_eq_float	:= caml_equal
else
C_primitive caml_eq_float

end C_primitive
end if


if GENERIC_COMPARE
caml_neq_float	:= caml_notequal
else
C_primitive caml_neq_float

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


C_primitive caml_exp_float

end C_primitive



C_primitive caml_expm1_float

end C_primitive



C_primitive caml_fill_bytes

end C_primitive



C_primitive caml_fill_string

end C_primitive



C_primitive caml_final_register

end C_primitive



C_primitive caml_final_register_called_without_value

end C_primitive



C_primitive caml_final_release

end C_primitive



C_primitive caml_float_of_int

end C_primitive



C_primitive caml_float_of_string

end C_primitive



C_primitive caml_floor_float

end C_primitive



C_primitive caml_fmod_float

end C_primitive



C_primitive caml_format_float

end C_primitive


; RDI - формат; см. format_of_iconv в stdlib/camlinternalFormat.ml
; RSI - целое (в OCaml-представлении).
C_primitive caml_format_int
;	в pervasives.ml встречается только %d (см. string_of_int)
	cmp	word[rdi], '%d'
	jnz	.fmt
	zero	ecx
;	Обнуляем заголовок. Скоректируем его, когда строка будет готова.
	mov	[alloc_small_ptr_backup], rcx
	Int_val rsi
	jns	.pos
	neg	rsi
	mov	byte[alloc_small_ptr_backup + rcx + sizeof value], '-'
	inc	ecx
.pos:	mov	edi, ecx	; позиция первого символа числа нужна в .rev:
;	Делим на 10, умножая на магическое число.
.@:	mov	rax, rsi
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
	mov	[alloc_small_ptr_backup + rcx + sizeof value], al
	inc	ecx
	test	rsi, rsi
	jnz	.@
;	mov	byte[alloc_small_ptr_backup + rcx + sizeof value], 0
	push	rcx
;	Цифры числа расположены в обратном порядке, переставляем.
.rev:	dec	ecx
	cmp	edi, ecx
	jnc	.order
	mov	al, [alloc_small_ptr_backup + rdi + sizeof value]
	mov	dl, [alloc_small_ptr_backup + rcx + sizeof value]
	mov	[alloc_small_ptr_backup + rcx + sizeof value], al
	mov	[alloc_small_ptr_backup + rdi + sizeof value], dl
	inc	edi
	jmp	.rev
.order:	pop	rdi	; размер строки
	jmp	caml_alloc_string
.fmt:
int3
end C_primitive


;CAMLprim value caml_fresh_oo_id (value v)
; RDI - value - игнорируется
C_primitive caml_fresh_oo_id
	mov	rax, [oo_last_id]
	add	[oo_last_id], 2
	ret
end C_primitive



C_primitive caml_frexp_float

end C_primitive



C_primitive caml_gc_compaction

end C_primitive



C_primitive caml_gc_counters

end C_primitive


; EDI - не используется.
C_primitive caml_gc_full_major
if HEAP_GC
	mov	alloc_small_ptr, alloc_small_ptr_backup
	call	heap_mark_compact_gc
	mov	alloc_small_ptr_backup, alloc_small_ptr
end if
	ret
end C_primitive



C_primitive caml_gc_get

end C_primitive



C_primitive caml_gc_huge_fallback_count

end C_primitive



C_primitive caml_gc_major

end C_primitive



C_primitive caml_gc_major_slice

end C_primitive



C_primitive caml_gc_minor

end C_primitive



C_primitive caml_gc_minor_words

end C_primitive



C_primitive caml_gc_quick_stat

end C_primitive



C_primitive caml_gc_set

end C_primitive



C_primitive caml_gc_stat

end C_primitive



C_primitive caml_get_current_callstack

end C_primitive



C_primitive caml_get_current_environment

end C_primitive



C_primitive caml_get_exception_backtrace

end C_primitive



C_primitive caml_get_exception_raw_backtrace

end C_primitive



C_primitive caml_get_global_data

end C_primitive



C_primitive caml_get_major_bucket

end C_primitive



C_primitive caml_get_major_credit

end C_primitive



C_primitive caml_get_minor_free

end C_primitive



C_primitive caml_get_public_method

end C_primitive



C_primitive caml_get_section_table

end C_primitive



C_primitive caml_hash

end C_primitive



C_primitive caml_hash_univ_param

end C_primitive



C_primitive caml_hexstring_of_float

end C_primitive



C_primitive caml_hypot_float

end C_primitive



C_primitive caml_input_value

end C_primitive



C_primitive caml_input_value_from_string

end C_primitive



C_primitive caml_input_value_to_outside_heap

end C_primitive



C_primitive caml_install_signal_handler

end C_primitive



C_primitive caml_int32_add

end C_primitive



C_primitive caml_int32_and

end C_primitive



C_primitive caml_int32_bits_of_float

end C_primitive



C_primitive caml_int32_bswap

end C_primitive



C_primitive caml_int32_compare

end C_primitive



C_primitive caml_int32_div

end C_primitive



C_primitive caml_int32_float_of_bits

end C_primitive



C_primitive caml_int32_format

end C_primitive



C_primitive caml_int32_mod

end C_primitive



C_primitive caml_int32_mul

end C_primitive



C_primitive caml_int32_neg

end C_primitive



C_primitive caml_int32_of_float

end C_primitive



C_primitive caml_int32_of_int

end C_primitive



C_primitive caml_int32_of_string

end C_primitive



C_primitive caml_int32_or

end C_primitive



C_primitive caml_int32_shift_left

end C_primitive



C_primitive caml_int32_shift_right

end C_primitive



C_primitive caml_int32_shift_right_unsigned

end C_primitive



C_primitive caml_int32_sub

end C_primitive



C_primitive caml_int32_to_float

end C_primitive



C_primitive caml_int32_to_int

end C_primitive



C_primitive caml_int32_xor

end C_primitive



C_primitive caml_int64_add

end C_primitive



C_primitive caml_int64_and

end C_primitive



C_primitive caml_int64_bits_of_float

end C_primitive



C_primitive caml_int64_bswap

end C_primitive



C_primitive caml_int64_compare

end C_primitive



C_primitive caml_int64_div

end C_primitive


; RDI - адрес источника для копирования в кучу числа с плавающей точкой.
C_primitive caml_int64_float_of_bits
	mov	eax, 1 wosize or Double_tag
	mov	[alloc_small_ptr_backup], rax
	mov	rax, [rdi]
	mov	[alloc_small_ptr_backup + sizeof value], rax
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive



C_primitive caml_int64_format

end C_primitive



C_primitive caml_int64_mod

end C_primitive



C_primitive caml_int64_mul

end C_primitive



C_primitive caml_int64_neg

end C_primitive



C_primitive caml_int64_of_float

end C_primitive



C_primitive caml_int64_of_int

end C_primitive



C_primitive caml_int64_of_int32

end C_primitive



C_primitive caml_int64_of_nativeint

end C_primitive



C_primitive caml_int64_of_string

end C_primitive



C_primitive caml_int64_or

end C_primitive



C_primitive caml_int64_shift_left

end C_primitive



C_primitive caml_int64_shift_right

end C_primitive



C_primitive caml_int64_shift_right_unsigned

end C_primitive



C_primitive caml_int64_sub

end C_primitive



C_primitive caml_int64_to_float

end C_primitive



C_primitive caml_int64_to_int

end C_primitive



C_primitive caml_int64_to_int32

end C_primitive



C_primitive caml_int64_to_nativeint

end C_primitive



C_primitive caml_int64_xor

end C_primitive



C_primitive caml_int_as_pointer

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



C_primitive caml_int_of_float

end C_primitive



C_primitive caml_int_of_string

end C_primitive



C_primitive caml_invoke_traced_function

end C_primitive



C_primitive caml_lazy_follow_forward

end C_primitive



C_primitive caml_lazy_make_forward

end C_primitive



C_primitive caml_ldexp_float

end C_primitive



C_primitive caml_lex_engine

end C_primitive



C_primitive caml_log10_float

end C_primitive



C_primitive caml_log1p_float

end C_primitive



C_primitive caml_log_float

end C_primitive


; RDI - ссылка на исходный массив.
; Если массив состоит из ссылок на числа с плавающей точкой,
; формирует из них массив значений.
; Иначе возвращает ссылку на исходный массив.
C_primitive caml_make_array
	mov	rax, rdi
	mov	rcx, Val_header[rdi - sizeof value]
	from_wosize rcx
	jz	.exit
	mov	rdx, [rdi]
;	Выходим, если целое число
	test	rdx, 1
	jnz	.exit
;	или за пределами кучи
	cmp	rdx, heap_small
	jc	.exit
	cmp	rdx, [heap_descriptor.uncommited]
	jnc	.exit
;	или по ссылке хранится не вещественное число
	cmp	byte[rdx - sizeof value], Double_tag
	jnz	.exit
;	Формируем заголовок массива вещественных чисел, взяв размер от исходного.
	mov	rax, Val_header[rdi - sizeof value]
	mov	al, Double_array_tag
	mov	Val_header[alloc_small_ptr_backup], rax
	zero	edx
;	Разыменовываем ссылки и заносим значения в массив.
.cp:	mov	rax, [rdi + rdx * sizeof value]
	mov	rax, [rax]
	mov	[alloc_small_ptr_backup + (rdx + 1) * sizeof value], rax
	inc	rdx
	dec	rcx
	jnz	.cp
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + (rdx + 1) * sizeof value]
.exit:	ret
end C_primitive



C_primitive caml_make_float_vect

end C_primitive


; Создаёт массив идентичных элементов заданного размера.
; RDI - длина вектора.
; RSI - элемент
C_primitive caml_make_vect
	Long_val rdi
	lea	rax, [Atom 0]
	jz	.exit
	mov	rcx, rdi
	to_wosize rdi
;	надо: if (wsize > Max_wosize) caml_invalid_argument("Array.make");
;	Проверяем, не является ли элемент ссылкой на вещественное число.
	test	rsi, 1
	jnz	.val
	cmp	rsi, heap_small
	jc	.val
	cmp	rsi, [heap_descriptor.uncommited]
	jnc	.val
	cmp	byte[rsi - sizeof value], Double_tag
	jnz	.val
	or	rdi, Double_array_tag
	mov	rsi, [rsi]
.val:	mov	Val_header[alloc_small_ptr_backup], rdi
	zero	rdx
.@:	mov	[alloc_small_ptr_backup + (1 + rdx) * sizeof value], rsi
	inc	rdx
	dec	rcx
	jnz	.@
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + (1 + rdx) * sizeof value]
.exit:	ret
end C_primitive



C_primitive caml_marshal_data_size

end C_primitive



C_primitive caml_md5_chan

end C_primitive



C_primitive caml_md5_string

end C_primitive



C_primitive caml_ml_bytes_length

end C_primitive



C_primitive caml_ml_channel_size

end C_primitive



C_primitive caml_ml_channel_size_64

end C_primitive



C_primitive caml_ml_close_channel

end C_primitive



C_primitive caml_ml_enable_runtime_warnings

end C_primitive


; RDI - виртуальный канал
C_primitive caml_ml_flush
;	В оригинале обеспечен эксклюзивный доступ
	virtual at rdi - sizeof value
	.co	channel_operations_object
	end virtual
	mov	rdi, [.co.channel]
	virtual at rdi
	.channel	channel
	end virtual
	cmp	[.channel.fd], -1
	jz	.exit
.again:	call	caml_flush_partial
	test	eax, eax
	jz	.again
.exit:	mov	eax, Val_unit
	ret
end C_primitive



C_primitive caml_ml_flush_partial

end C_primitive



C_primitive caml_ml_input

end C_primitive



C_primitive caml_ml_input_char

end C_primitive



C_primitive caml_ml_input_int

end C_primitive



C_primitive caml_ml_input_scan_line

end C_primitive


IO_BUFFER_SIZE	:= 4096 - 6 * 8 ; В оригинале 65536
struct channel
	.fd	dd ?	; Описатель файла
	.flags	dd ?	; Флаги (поле перемещено)
	.offset	dq ?	; Позиция в файле
	.end	dq ?	; Адрес старшей границы буфера
	.curr	dq ?	; Адрес текущей позиции буфера
	.max	dq ?	; Адрес границы буфера для чтения
;	.mutex	dq ?	; /* Placeholder for mutex (for systhreads) */
	.next	dq ?	; Односвязный (в оригинале 2-х) список каналов
;	.prev	dq ?	; для flush_all
;	.revealed	dd ?	; /* For Cash only */
;	.old_revealed	dd ?	; /* For Cash only */
;	.refcount	dd ?	; /* For flush_all and for Cash */
	.buff	rb IO_BUFFER_SIZE	; Тело буфера
;	.name	dq ?	; char* /* Optional name (to report fd leaks) */
end struct
assert 4096 = sizeof ch_stdin

; RDI - int fd
; Реализовано только для стандартных каналов, буфера выделены статически.
proc caml_open_descriptor_in
	cmp	edi, STDERR_FILENO
	jbe	.stdfile
int3
.stdfile:
	virtual at rax
	.channel	channel
	end virtual
	mov	.channel, rdi
	shl	.channel, bsr 4096
	lea	.channel, [ch_stdin + .channel]
	mov	[.channel.fd], edi
	and	[.channel.flags], 0
	and	[.channel.offset], 0	; lseek(fd, 0, SEEK_CUR)
	lea	rcx, [.channel.buff]
	mov	[.channel.curr], rcx
	mov	[.channel.max], rcx
	add	rcx, IO_BUFFER_SIZE
	mov	[.channel.end], rcx
	mov	rcx, [caml_all_opened_channels]
	mov	[.channel.next], rcx
	mov	[caml_all_opened_channels], .channel
	ret
end proc


struct channel_operations_object
	.tag		dq ?
	.operations	dq ?
	.channel	dq ?
end struct


; RDI - fd Value
; Возвращает адрес объекта
C_primitive caml_ml_open_descriptor_in
C_primitive_stub
;  return caml_alloc_channel(caml_open_descriptor_in(Int_val(fd)));
	Int_val	edi
	call	caml_open_descriptor_in
end C_primitive
; продолжает выполнение.

; RAX - адрес канала
; Возвращает объект вирт. канала.
caml_alloc_channel:
;	Для сборщика мусора требуется:
;	chan->refcount++;             /* prevent finalization during next alloc */
;	add_to_custom_table (&caml_custom_table, result, mem, max);
	virtual at alloc_small_ptr_backup
	.co	channel_operations_object
	end virtual
;	Длина без учёта заголовка (tag)
	mov	[.co.tag], 2 wosize or Custom_tag
	mov	[.co.operations], channel_operations
	mov	[.co.channel], rax
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof .co]
	ret


; RDI - int fd
proc caml_open_descriptor_out
	call	caml_open_descriptor_in
	virtual at rax
	.channel	channel
	end virtual
	mov	[.channel.max], 0
	ret
end proc


; RDI - fd Value
C_primitive caml_ml_open_descriptor_out
C_primitive_stub
;	return caml_alloc_channel(caml_open_descriptor_out(Int_val(fd)));
	Int_val	edi
	call	caml_open_descriptor_out
	jmp	caml_alloc_channel
end C_primitive



C_primitive caml_ml_out_channels_list
	mov	edx, Val_emptylist
	virtual at rdi
	.channel	channel
	end virtual
	mov	.channel, [caml_all_opened_channels]
.ch:	test	.channel, .channel
	jz	.exit
	cmp	[.channel.max], 0
	jnz	.next
	mov	rax, .channel
	call	caml_alloc_channel
	mov	Val_header[alloc_small_ptr_backup], (1+2) wosize or Pair_tag
	mov	[alloc_small_ptr_backup + 2 * sizeof value], rdx ; хвост
	lea	rdx, [alloc_small_ptr_backup + 1 * sizeof value]
	mov	[rdx], rax ; канал
	lea	alloc_small_ptr_backup, [3 * sizeof value + alloc_small_ptr_backup]
.next:	mov	.channel, [.channel.next]
	jmp	.ch
.exit:	mov	rax, rdx
	retn
end C_primitive

; RDI - канал
; RSI - начальный адрес блока, отправляемого в канал.
; RDX - длина
; Возвращает количество отправленных байт.
; Поскольку размер буфера ограничен, может быть отправлена только часть блока.
proc caml_putblock
	virtual at rax
	.channel	channel
	end virtual
	mov	rax, rdi
	mov	rcx, [.channel.end]
	mov	rdi, [.channel.curr]
	sub	rcx, rdi
	cmp	rdx, rcx
	jae	.over
;	Места в буфере канала достаточно, копируем блок.
	mov	rcx, rdx
rep	movs	byte[rdi], [rsi]
	mov	[.channel.curr], rdi
	mov	rax, rdx
	ret
.over:;	Сохраняем в буфер сколько поместится.
	push	rcx
rep	movs	byte[rdi], [rsi]
	lea	rsi, [.channel.buff]
	mov	rdx, [.channel.end]
	sub	rdx, rsi	; длина
	push	rsi rdx rax	; rax - channel
	mov	edi, [.channel.fd]
	call	caml_write
	pop	rdx rcx	rdi	; теперь rdx = channel, rcx = длина, а rdi = буфер
	cmp	rax, rcx
	je	.all_written
;	Перемещаем остаток в начало буфера.
	sub	rcx, rax
	lea	rsi, [rdi + rax]
rep	movs	byte[rdi], [rsi]
.all_written:
	virtual at rdx
	.chan	channel
	end virtual
	add	[.chan.offset], rax
	neg	rax
	add	rax, [.chan.end]
	mov	[.chan.curr], rax
	pop	rax
	ret
end proc


; см. caml_ml_output_bytes
;C_primitive caml_ml_output
caml_ml_output:
;	jmp	caml_ml_output_bytes
;end C_primitive

; RDI - виртуальный канал
; RSI - буфер
; RDX - смещение от начала в буфера
; RCX - длина
C_primitive caml_ml_output_bytes
C_primitive_stub
	virtual at rdi - sizeof value
	.co	channel_operations_object
	end virtual
	mov	rdi, [.co.channel]
	Ulong_val rdx
	lea	rsi, [rsi + rdx]
	Ulong_val rcx
	jecxz	.exit
	mov	rdx, rcx
.again:	push	rdi rsi rdx
	call	caml_putblock
	pop	rdx rsi rdi
	add	rsi, rax
	sub	rdx, rax
	ja	.again
.exit:	mov	eax, Val_unit
	ret
end C_primitive


; RDI - описатель (дескриптор) файла
; RSI - флаги (не используются)
; RDX - начальный адрес буфера
; RCX - длина
;proc caml_write_fd

; RDI - описатель (дескриптор) файла.	Значение сохраняется.
; RSI - начальный адрес буфера. 	Значение сохраняется.
; RDX - длина
proc caml_write	;_fd_noflag
.again:	push	rdi rsi rdx
	sys.write
	pop	rdx rsi rdi
	j_err	.err
	ret
.err:	cmp	rax, -EINTR
	jz	.again
	cmp	rax, -EAGAIN
	jz	.eagain
	cmp	rax, -EWOULDBLOCK
	jz	.eagain
.fail:
int3
.eagain:cmp	rdx, 1
	jbe	.fail
	mov	rdx, 1
	jmp	.again
end proc


; RDI - channel. 	Значение сохраняется.
; Возвращает 1 если содержимое буфера успешно отправлено в файл.
proc caml_flush_partial
	virtual at rdi
	.channel	channel
	end virtual
	mov	rdx, [.channel.curr]	; 3й для caml_write
	lea	rsi, [.channel.buff]	; 2й для caml_write
	sub	rdx, rsi	; количество байт для записи
	jbe	.exit
;	push	rsi
	push	rdi rdx
	mov	edi, [.channel.fd]	; 1й для caml_write
	call	caml_write
	pop	rdx rdi
;	pop	rsi
	add	[.channel.offset], rax
	sub	[.channel.curr], rax
	sub	rdx, rax
;	jz	.exit
	mov	rcx, rdx
	push	rdi
	lea	rsi, [rdi + rax]
rep	movs	byte[rdi], [rsi]
	pop	rdi
.exit:	zero	eax
	sub	rsi, [.channel.curr]
	setz	al
	ret
end proc


; RDI - виртуальный канал
; RSI - символ
C_primitive caml_ml_output_char
	virtual at rdi - sizeof value
	.co	channel_operations_object
	end virtual
	mov	rdi, [.co.channel]
	virtual at rdi
	.channel	channel
	end virtual
	Ulong_val esi
	mov	rax, [.channel.curr]
	cmp	rax, [.channel.end]
	jc	.putch
;	push	.channel
	push	rsi
	call	caml_flush_partial
	pop	rsi
;	pop	.channel
.putch:	mov	rax, [.channel.curr]
	mov	byte[rax], sil
	inc	 [.channel.curr]
	mov	eax, Val_unit
	ret
end C_primitive



C_primitive caml_ml_output_int

end C_primitive



C_primitive caml_ml_output_partial

end C_primitive



C_primitive caml_ml_pos_in

end C_primitive



C_primitive caml_ml_pos_in_64

end C_primitive



C_primitive caml_ml_pos_out

end C_primitive



C_primitive caml_ml_pos_out_64

end C_primitive



C_primitive caml_ml_runtime_warnings_enabled

end C_primitive



C_primitive caml_ml_seek_in

end C_primitive



C_primitive caml_ml_seek_in_64

end C_primitive



C_primitive caml_ml_seek_out

end C_primitive



C_primitive caml_ml_seek_out_64

end C_primitive



C_primitive caml_ml_set_binary_mode

end C_primitive



C_primitive caml_ml_set_channel_name

end C_primitive


; RDI - адрес строки (за заголовком)
C_primitive caml_ml_string_length
	caml_string_length rdi, rax, rcx
	Val_int	rax
	retn
end C_primitive



C_primitive caml_modf_float

end C_primitive



C_primitive caml_mul_float

end C_primitive



C_primitive caml_nativeint_add

end C_primitive



C_primitive caml_nativeint_and

end C_primitive



C_primitive caml_nativeint_bswap

end C_primitive



C_primitive caml_nativeint_compare

end C_primitive



C_primitive caml_nativeint_div

end C_primitive



C_primitive caml_nativeint_format

end C_primitive



C_primitive caml_nativeint_mod

end C_primitive



C_primitive caml_nativeint_mul

end C_primitive



C_primitive caml_nativeint_neg

end C_primitive



C_primitive caml_nativeint_of_float

end C_primitive



C_primitive caml_nativeint_of_int

end C_primitive



C_primitive caml_nativeint_of_int32

end C_primitive



C_primitive caml_nativeint_of_string

end C_primitive



C_primitive caml_nativeint_or

end C_primitive



C_primitive caml_nativeint_shift_left

end C_primitive



C_primitive caml_nativeint_shift_right

end C_primitive



C_primitive caml_nativeint_shift_right_unsigned

end C_primitive



C_primitive caml_nativeint_sub

end C_primitive



C_primitive caml_nativeint_to_float

end C_primitive



C_primitive caml_nativeint_to_int

end C_primitive



C_primitive caml_nativeint_to_int32

end C_primitive



C_primitive caml_nativeint_xor

end C_primitive



C_primitive caml_neg_float

end C_primitive



C_primitive caml_new_lex_engine

end C_primitive



C_primitive caml_obj_add_offset

end C_primitive



C_primitive caml_obj_block

end C_primitive


; RDI - адрес исходного объекта.
; Возвращает адрес созданной копии.
C_primitive caml_obj_dup
;	В оригинале проверяется No_scan_tag
	mov	rcx, Val_header[rdi - sizeof value]
	mov	[alloc_small_ptr_backup], rcx
	from_wosize rcx
	mov	rsi, rdi
	lea	rdi, [alloc_small_ptr_backup + sizeof value]
	mov	rax, rdi
rep	movs	Val_header[rdi], [rsi]
	mov	alloc_small_ptr_backup, rdi
	ret
end C_primitive



C_primitive caml_obj_is_block

end C_primitive



C_primitive caml_obj_reachable_words

end C_primitive



C_primitive caml_obj_set_tag

end C_primitive



C_primitive caml_obj_tag

end C_primitive



C_primitive caml_obj_truncate

end C_primitive



C_primitive caml_output_value

end C_primitive



C_primitive caml_output_value_to_buffer

end C_primitive



C_primitive caml_output_value_to_string

end C_primitive



C_primitive caml_parse_engine

end C_primitive



C_primitive caml_power_float

end C_primitive



C_primitive caml_raw_backtrace_length

end C_primitive



C_primitive caml_raw_backtrace_next_slot

end C_primitive



C_primitive caml_raw_backtrace_slot

end C_primitive



C_primitive caml_realloc_global

end C_primitive



C_primitive caml_record_backtrace

end C_primitive



C_primitive caml_register_channel_for_spacetime

end C_primitive



C_primitive caml_register_code_fragment

end C_primitive


; CAMLprim value caml_register_named_value(value vname, value val)
C_primitive caml_register_named_value
C_primitive_stub
; Вызывается для "Pervasives.array_bound_error", "Pervasives.do_at_exit"
	mov	rax, Val_unit
	ret
end C_primitive


C_primitive caml_reify_bytecode

end C_primitive



C_primitive caml_remove_debug_info

end C_primitive



C_primitive caml_runtime_parameters

end C_primitive



C_primitive caml_runtime_variant

end C_primitive



C_primitive caml_set_oo_id

end C_primitive



C_primitive caml_set_parser_trace

end C_primitive



C_primitive caml_sin_float

end C_primitive



C_primitive caml_sinh_float

end C_primitive



C_primitive caml_spacetime_enabled

end C_primitive



C_primitive caml_spacetime_only_works_for_native_code

end C_primitive



C_primitive caml_sqrt_float

end C_primitive



C_primitive caml_static_alloc

end C_primitive



C_primitive caml_static_free

end C_primitive



C_primitive caml_static_release_bytecode

end C_primitive



C_primitive caml_static_resize

end C_primitive


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


C_primitive caml_string_equal

end C_primitive



C_primitive caml_string_get

end C_primitive



C_primitive caml_string_get16

end C_primitive



C_primitive caml_string_get32

end C_primitive



C_primitive caml_string_get64

end C_primitive



C_primitive caml_string_greaterequal

end C_primitive



C_primitive caml_string_greaterthan

end C_primitive



C_primitive caml_string_lessequal

end C_primitive



C_primitive caml_string_lessthan

end C_primitive



C_primitive caml_string_notequal

end C_primitive



C_primitive caml_string_set

end C_primitive



C_primitive caml_string_set16

end C_primitive



C_primitive caml_string_set32

end C_primitive



C_primitive caml_string_set64

end C_primitive



C_primitive caml_sub_float

end C_primitive



C_primitive caml_sys_chdir

end C_primitive



C_primitive caml_sys_close

end C_primitive


; Возвращает Val_false на Low Endian
C_primitive caml_sys_const_big_endian
	mov	eax, Val_false
	ret
end C_primitive


; Возвращает размер целого с битах - 63
; (т.к. 0й бит используется для различения целых и ссылок).
C_primitive caml_sys_const_int_size
	mov	eax, Val_int(8 * sizeof(value) - 1)
	ret
end C_primitive


; Возвращает максимальный размер объекта (блока) на куче.
; В данной реализации размер умещается в 32 бита, что меньше чем оригинале 0x7fffffffffffff.
C_primitive caml_sys_const_max_wosize
	mov	rax, Val_int(Max_wosize)
	ret
end C_primitive


; Возвращает тип Val_int(1) - интерпретатор байткода.
caml_sys_const_backend_type:

; Возвращает Val_true на *nix системах.
C_primitive caml_sys_const_ostype_unix
	mov	eax, Val_true
	ret
end C_primitive


; Возвращает Val_true в случае Cygwin, Val_false в данной реализации.
caml_sys_const_ostype_cygwin:

; Возвращает Val_true в случае ОС Windows, Val_false в данной реализации.
C_primitive caml_sys_const_ostype_win32
	mov	eax, Val_false
	ret
end C_primitive


; Возвращает размер слова с битах - 64.
C_primitive caml_sys_const_word_size
	mov	eax, Val_int(8 * sizeof(value))
	ret
end C_primitive


; edi = Value
; Произвольный код может быть возвращён вызовом sys_exit библиотеки Pervasives.
C_primitive caml_sys_exit
	Int_val	edi	; 1й
; Данная точка входа используется для завершения процесса в случаях,
; когда системные вызовы возвращают ошибку. Такие коды ошибок отрицательны.
; Ядро преобразует код по формуле (error_code & 0xff) << 8;
; см. linux/kernal/exit.c SYSCALL_DEFINE1(exit, int, error_code)
; Если в caml_sys_exit передаются небольшие положительные числа,
; пользовательские коды завершения не пересекаются и отличаются от системных.
; Пока не найдено лучшее решение (sysexits.h ?), по-видимому, оптимально
; возвращать отрицательные коды из errno.inc в качестве ошибок интерпретатора.
sys_exit:
	sys.exit
	ud2
end C_primitive



C_primitive caml_sys_file_exists

end C_primitive


; EDI - не используется
; Возвращает пару значений:
; 0й - строка с именем исполняемого файла (байт-кода);
; 1й - массив из аргументов (начинается с имени исполняемого файла).
;
; Реализация не полная:
; имя исполняемого файла задано строковой константой в интерпретаторе.
C_primitive caml_sys_get_argv
C_primitive_stub
;	Вычисляем длину строки и копируем её на кучу.
	zero	edi
	zero	eax
	mov	rsi, [bytecode_filename]
.cnt:	cmp	[rsi + rdi], al
	jz	.len
	inc	edi
	jmp	.cnt
.len:	push	rdi rsi
	call	caml_alloc_string
	pop	rsi rcx
	mov	rdi, rax
rep	movs	byte[rdi], [rsi]
;	Сохраняем ссылку на exe_name на случай вызова сборщика мусора.
	push	rax
;	После данной команды память доступна и ссылки валидны.
	test	[alloc_small_ptr_backup + (2 + 2) * sizeof value], rax
;	argv = массив из 1го элемента (с тегом 0)
	mov	ecx, 1 wosize
	mov	[alloc_small_ptr_backup + 0 * sizeof value], rcx
	pop	rax
	mov	[alloc_small_ptr_backup + 1 * sizeof value], rax
;	Формируем возвращаемый объект.
;	mov	ecx, 2 wosize
	add	ecx, ecx
	mov	[alloc_small_ptr_backup + 2 * sizeof value], rcx
;	0й элемент пары - ссылка на строку с именем исполняемого файла.
	mov	[alloc_small_ptr_backup + 3 * sizeof value], rax
;	1й элемент пары - ссылка на масив.
	lea	rax, [alloc_small_ptr_backup + 1 * sizeof value]
	mov	[alloc_small_ptr_backup + 4 * sizeof value], rax
	lea	rax, [alloc_small_ptr_backup +(2 + 1) * sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 5 * sizeof value]
	ret
end C_primitive


; EDI - не используется
; Возвращает кортеж из 3-х элементов:
; 0-й - тип ОС (строка "Unix");
; 1-й - размер Value в битах (64);
; 2-й - является ли архитектура исполняющей машины Big Endian (Val_false).
C_primitive caml_sys_get_config
	mov	edi, 4
	call	caml_alloc_string
	mov	dword[rax], 'Unix'
;	Сохраняем ссылку на тип ОС на случай вызова сборщика мусора.
	push	rax
	mov	eax, 3 wosize
	mov	Val_header[alloc_small_ptr_backup + 0 * sizeof value], rax
	mov	eax, Val_int (8 * sizeof value)
	mov	[alloc_small_ptr_backup + (1 + 1) * sizeof value], rax
	mov	eax, Val_false
	mov	[alloc_small_ptr_backup + (2 + 1) * sizeof value], rax
	pop	rax
	mov	[alloc_small_ptr_backup + (0 + 1) * sizeof value], rax
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + (3 + 1) * sizeof value]
	ret
end C_primitive



C_primitive caml_sys_getcwd

end C_primitive



C_primitive caml_sys_getenv

end C_primitive




C_primitive caml_sys_isatty

end C_primitive



C_primitive caml_sys_is_directory

end C_primitive



C_primitive caml_sys_open

end C_primitive



C_primitive caml_sys_random_seed

end C_primitive



C_primitive caml_sys_read_directory

end C_primitive



C_primitive caml_sys_remove

end C_primitive



C_primitive caml_sys_rename

end C_primitive



C_primitive caml_sys_system_command

end C_primitive



C_primitive caml_sys_time

end C_primitive



C_primitive caml_sys_unsafe_getenv

end C_primitive



C_primitive caml_tan_float

end C_primitive



C_primitive caml_tanh_float

end C_primitive



C_primitive caml_terminfo_backup

end C_primitive



C_primitive caml_terminfo_resume

end C_primitive



C_primitive caml_terminfo_setup

end C_primitive



C_primitive caml_terminfo_standout

end C_primitive



C_primitive caml_update_dummy

end C_primitive



C_primitive caml_weak_blit

end C_primitive



C_primitive caml_weak_check

end C_primitive



C_primitive caml_weak_create

end C_primitive



C_primitive caml_weak_get

end C_primitive



C_primitive caml_weak_get_copy

end C_primitive



C_primitive caml_weak_set

end C_primitive

display_num "Реализовано C-примитивов: ", ..C_PRIM_TOTAL - ..C_PRIM_UNIMPLEMENTED
display_num " (включая ", ..C_PRIM_TOTAL - ..C_PRIM_COUNT
display_num_ln " синонимов) из ", ..C_PRIM_TOTAL
display_num_ln "Занимают байт (включая int3 заглушки): ", $-C_primitive_first
