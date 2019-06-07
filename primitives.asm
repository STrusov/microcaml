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



; Резервирует место в куче под массив вещественных чисел.
; RDI - размер (OCaml value) размещаемого в памяти блока в словах.
caml_alloc_dummy_float:
; На AMD64 вещественное число занимает столько же места, сколько другое значение.
int3


; Резервирует место в куче для функции.
; RDI - размер (OCaml value) размещаемого в памяти блока в словах.
; RSI - арность. В оригинале используется js_of_ocaml runtime.
caml_alloc_dummy_function:


; Резервирует место в куче.
; RDI - размер (OCaml value) размещаемого в памяти блока в словах.
C_primitive caml_alloc_dummy
	Int_val	rdi
	lea	rax, [Atom 0]
	jz	.exit
	to_wosize rdi
	mov	Val_header[alloc_small_ptr_backup], rdi
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	from_wosize rdi
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + (1 + rdi) * sizeof value]
.exit:	ret
end C_primitive


; Актуализирует зарезервированный блок новыми данными.
; RDI - адрес зарезервированного блока.
; RSI - адрес нового содержимого.
C_primitive caml_update_dummy
	mov	rcx, Val_header[rsi - sizeof value]
	mov	Val_header[rdi - sizeof value], rcx
	from_wosize rcx
rep	movs	qword[rdi], [rsi]
	mov	eax, Val_unit
	ret
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
	js	caml_array_bound_error
	mov	rax, Val_header[rdi - sizeof value]
	from_wosize rax
	cmp	rax, rsi
	jc	caml_array_bound_error
	mov	rax, [rdi + rsi * sizeof value]
	ret
end C_primitive


; Возвращает элемент массива вещественных чисел.
; RDI - адрес массива
; RSI - индекс элемента (OCaml value)
C_primitive caml_array_get_float
	Long_val rsi
	js	caml_array_bound_error
	mov	rax, Val_header[rdi - sizeof value]
	from_wosize rax
	cmp	rax, rsi
	jc	caml_array_bound_error
	mov	Val_header[alloc_small_ptr_backup], 1 wosize or Double_tag
	mov	rax, [rdi + rsi * sizeof value]
	mov	Val_header[alloc_small_ptr_backup + sizeof value], rax
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


proc caml_array_bound_error
	caml_invalid_argument	'Выход за пределы массива'
end proc


C_primitive caml_array_set

end C_primitive


; Модифицирует ячейку массива.
; RDI - адрес массива.
; RSI - индекс элемента (OCaml value).
; RDX - новое значение.
C_primitive caml_array_set_addr
	Int_val	rsi
	js	caml_array_bound_error
	mov	rcx, Val_header[rdi - sizeof value]
	from_wosize rcx
	cmp	rsi, rcx
	jae	caml_array_bound_error
	mov	[rdi + rsi * sizeof value], rdx
	ret
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


; Возвращает элемент массива (без проверки выхода за границы).
; RDI - адрес массива.
; RSI - индекс элемента (OCaml value).
C_primitive caml_array_unsafe_get
	cmp	byte[rdi - sizeof value], Double_array_tag
	jz	caml_array_unsafe_get_float
	Int_val	rsi
	mov	rax, [rdi + rsi * sizeof value]
	ret
end C_primitive


; Возвращает элемент массива вещественных чисел (без проверки выхода за границы).
; RDI - адрес массива.
; RSI - индекс элемента (OCaml value).
C_primitive caml_array_unsafe_get_float
;	Формируем в куче блок с вещественным числом и возвращаем его адрес.
	mov	Val_header[alloc_small_ptr_backup], 1 wosize + Double_tag
	mov	rax, [rdi]
	mov	[alloc_small_ptr_backup + sizeof value], rax
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + 2 * sizeof value]
	ret
end C_primitive


; Модифицирует элемент массива (без проверки выхода за границы).
; RDI - адрес массива.
; RSI - индекс элемента (OCaml value);
; RDX - новое значение.
C_primitive caml_array_unsafe_set
	cmp	byte[rdi - sizeof value], Double_array_tag
	jz	caml_array_unsafe_set_float
caml_array_unsafe_set_addr:
	Int_val	rsi
	mov	[rdi + rsi * sizeof value], rdx
	mov	eax, Val_unit
	ret
end C_primitive


; Модифицирует элемент массива вещественных чисел (без проверки выхода за границы).
; RDI - адрес массива.
; RSI - индекс элемента (OCaml value);
; RDX - новое значение.
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


caml_bytes_set := caml_string_set


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
.str_c:	mov	dl, [val1]
	cmp	dl, [val2]
	lea	val1, [val1 + 1]
	lea	val2, [val2 + 1]
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



C_primitive caml_float_of_string

end C_primitive



C_primitive caml_floor_float

end C_primitive



C_primitive caml_fmod_float

end C_primitive


Negative_double	:= 0x8000000000000000	; знак в 63-м бите, согласно IEEE 754
Infinity	:= 0x7ff0000000000000
;NaN		:= 0x7fffffffffffffff
NaN		:= 0x7ff0000000000001

; Преобразует вещественное число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат вывода;
; RSI - вещественное число (в OCaml-представлении).
C_primitive caml_format_float
;	Создаём заголовок с нулевой длиной. Скорректируем её по готовности строки.
	mov	qword[alloc_small_ptr_backup], String_tag
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof value]
	push	alloc_small_ptr_backup
;	в pervasives.ml string_of_float вызывает format_float с "%.12g"
;	однако, функция вызывается со следующей строкой формата:
	cmp	dword[rdi], '%.6f'
	jnz	.fmt
	mov	rdx, [rsi]
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
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + rdi]
;	Выделяем 6 знаков дробной части абсолютного значения числа.
	cvttsd2si rax, xmm0
	cvtsi2sd xmm1, rax
	subsd	xmm0, xmm1	; дробная часть
	mov	eax, 1000000
	cvtsi2sd xmm1, eax
	mulsd	xmm0, xmm1
;	Преобразуем без усечения, иначе 0.1 -> 0.09999.
;	.1234567 выводится как .123457, что соотвествует sprintf (и OCaml).
	cvtsd2si esi, xmm0
;	format_nativeint_dec не выводит незначащие нули,
;	создаём фиктивный значащий старший разряд, что бы вывести остальные.
	add	esi, eax
;	Выводим число, содержащее требуемую дробную часть.
	call	format_nativeint_dec
;	Располагаем десятичную точку (OCaml не использует локализацию?)
;	поверх единицы в старшем разряде, полученной прибавлением 1000000 ранее.
	mov	byte[alloc_small_ptr_backup], '.'
.exit:	add	rdi, alloc_small_ptr_backup
	pop	alloc_small_ptr_backup
	sub	rdi, alloc_small_ptr_backup
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup - sizeof value]
	jmp	caml_alloc_string
.infinity:
	mov	dword[alloc_small_ptr_backup], 'inf'
	mov	edi, 3
	jmp	.exit
.nan:	mov	dword[alloc_small_ptr_backup], 'nan'
	mov	edi, 3
	jmp	.exit
.fmt:
int3
end C_primitive


; Преобразует число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат; см. format_of_iconv в stdlib/camlinternalFormat.ml
; RSI - целое (в OCaml-представлении).
C_primitive caml_format_int
;	Создаём заголовок с нулевой длиной. Скорректируем её по готовности строки.
	mov	qword[alloc_small_ptr_backup], String_tag
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof value]
;	в pervasives.ml встречается только %d (см. string_of_int)
	cmp	word[rdi], '%d'
	jnz	.fmt
	call	format_int_dec
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup - sizeof value]
	jmp	caml_alloc_string
.fmt:
int3
end C_primitive


; Преобразует число в текстовую форму, располагая строку в текущие адреса кучи.
; Возвращает в RDI длину строки-результата.
; RSI - знаковое целое (в OCaml-представлении).
proc	format_int_dec
	Int_val rsi
; RSI - знаковое целое.
format_nativeint_dec:
	zero	ecx
	test	rsi, rsi
	jns	.pos
	neg	rsi
	mov	byte[alloc_small_ptr_backup + rcx], '-'
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
	mov	[alloc_small_ptr_backup + rcx], al
	inc	ecx
	test	rsi, rsi
	jnz	.@
;	mov	byte[alloc_small_ptr_backup + rcx], 0
	push	rcx
;	Цифры числа расположены в обратном порядке, переставляем.
.rev:	dec	ecx
	cmp	edi, ecx
	jnc	.order
	mov	al, [alloc_small_ptr_backup + rdi]
	mov	dl, [alloc_small_ptr_backup + rcx]
	mov	[alloc_small_ptr_backup + rcx], al
	mov	[alloc_small_ptr_backup + rdi], dl
	inc	edi
	jmp	.rev
.order:	pop	rdi	; размер строки
	ret
end proc


; Преобразует число в шестнадцатиричный текст, располагая строку в текущие адреса кучи.
; Возвращает в RDI длину строки-результата.
; RSI - беззнаковое целое.
; DL - символ соответствующий 10, т.е. 'A' или 'a'.
proc	format_nativeint_hex
	zero	rdi
	sub	dl, '9' + 1
	mov	ecx, sizeof value * 8 / 4
.skip_leading_zeroes:
	mov	rax, rsi
	shr	rax, (sizeof value - 1) * 8 + 4
	jnz	.hd
;	dec	ecx
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
	ret
end proc


; RDI - адрес объекта.
C_primitive caml_set_oo_id
	mov	rax, [oo_last_id]
	mov	[rdi + 1 * sizeof value], rax
	add	[oo_last_id], 2
	mov	rax, rdi
	ret
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


caml_gc_minor := caml_gc_full_major


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


; Возвращает результат поразрядной конъюнкции (И) двух целых.
; RDI - адрес 1-го множителя;
; RSI - адрес 2-го множителя.
C_primitive caml_int32_and
	int32_header
	mov	eax, [int32_val + rdi]
	and	eax, [int32_val + rsi]
	int32_ret rax	; обнуляем незначащие разряды
end C_primitive



C_primitive caml_int32_bits_of_float

end C_primitive



C_primitive caml_int32_bswap

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


; Возвращает частное от деления двух целых.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_int32_div
	int32_header
;!!!	Проверку делителя на 0 пока не выполняем.
	mov	ecx, [int32_val + rsi]
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



C_primitive caml_int32_float_of_bits

end C_primitive


; Преобразует 32-х разрядное число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат; см. format_of_iconv в stdlib/camlinternalFormat.ml
; RSI - адрес блока с целым.
C_primitive caml_int32_format
;	Для вывода шестнадцатеричных цифр следует удалить незначащие разряды.
	or	edx, -1
	jmp	caml_nativeint_format.mask
end C_primitive


; Возвращает остаток от деления (по модулю) двух целых.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_int32_mod
	int32_header
;!!!	Проверку делителя на 0 пока не выполняем.
; 	При 32-х разрядном делении 0x80000000 на -1 генерируется SIGFPE (см. div).
;	Используем 64-х разрядное.
	movsxd	rcx, [int32_val + rsi]
	movsxd	rax, [int32_val + rdi]
	cqo
	idiv	rcx
	int32_ret rdx
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


; Возвращает результат вычитания из 0 (смена знака) целого.
; RDI - адрес целого;
C_primitive caml_int32_neg
	int32_header
	mov	eax, [int32_val + rdi]
	neg	eax
	cdqe
	int32_ret rax
end C_primitive


; Возвращает адрес целого, полученного округлением вещественного числа.
; RDI - адрес вещественного числа.
C_primitive caml_int32_of_float
	int32_header
	cvttsd2si rax, [rdi]
	int32_ret	rax
end C_primitive


; Возвращает адрес целого, полученного из OCaml value.
; RDI - OCaml value
C_primitive caml_int32_of_int
	int32_header
	Int_val	rdi
	int32_ret rdi
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


; Возвращает результат поразрядной дизъюнкции (включающего ИЛИ) двух целых.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_int32_or
	int32_header
	mov	rax, [int32_val + rdi]
	or	rax, [int32_val + rsi]
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


; Возвращает вещественое число, полученное из int32.
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


; Возвращает целое OCaml value, преобразованное из int32.
; RDI - адрес целого числа.
C_primitive caml_int32_to_int
	movsxd	rax, [int32_val + rdi]
	Val_int	rax
	ret
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


; 64-х разрядные числа. Располагаются в куче.
; Соответствуют "родным". В эталонной реализации различаются таблицей методов.

; Значение хранится в 1-м поле блока (после 0-го - с адресом методов).
int64_val equ (1 * sizeof value)

caml_int64_add	:= caml_nativeint_add

caml_int64_and	:= caml_nativeint_and


C_primitive caml_int64_bits_of_float

end C_primitive



C_primitive caml_int64_bswap

end C_primitive


caml_int64_compare	:= caml_nativeint_compare

caml_int64_div	:= caml_nativeint_div


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


caml_int64_format	:= caml_nativeint_format

caml_int64_mod	:= caml_nativeint_mod

caml_int64_mul	:= caml_nativeint_mul

caml_int64_neg	:= caml_nativeint_neg


C_primitive caml_int64_of_float

end C_primitive


caml_int64_of_int	:= caml_nativeint_of_int

caml_int64_of_int32	:= caml_nativeint_of_int32


; Создаём копию, поскольку формат идентичен. (безопасно ли просто вернуть RDI?)
C_primitive caml_int64_of_nativeint
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	nativeint_ret	rax
end C_primitive


caml_int64_of_string	:= caml_nativeint_of_string

caml_int64_or	:= caml_nativeint_or

caml_int64_shift_left	:= caml_nativeint_shift_left

caml_int64_shift_right	:= caml_nativeint_shift_right

caml_int64_shift_right_unsigned := caml_nativeint_shift_right_unsigned

caml_int64_sub	:= caml_nativeint_sub


C_primitive caml_int64_to_float

end C_primitive


caml_int64_to_int	:= caml_nativeint_to_int

caml_int64_to_int32	:= caml_nativeint_to_int32

caml_int64_to_nativeint	:= caml_int64_of_nativeint

caml_int64_xor	:= caml_nativeint_xor


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


; Возвращает целое OCaml value, преобразованное из вещественного числа.
; RDI - адрес вещественного числа.
C_primitive caml_int_of_float
	cvttsd2si rax, [rdi]
	Val_int	rax
	ret
end C_primitive


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
.fail:	pop	rdi
.fail2:	;caml_failwith ***
	caml_invalid_argument 'parse_intnat'
restore	over
restore	sign
end proc


; Возвращает целое OCaml value, сконвертированное из текстового представления.
; RDI - адрес строки.
C_primitive caml_int_of_string
	mov	cl, sizeof value * 8 - 1
	call	parse_intnat
	Val_int	rax
	ret
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


caml_ml_bytes_length := caml_ml_string_length


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
;	Запоминаем ссылку на блок списка на случай сборки мусора.
	push	rdx
	call	caml_alloc_channel
	pop	rdx
	mov	Val_header[alloc_small_ptr_backup], 2 wosize or Pair_tag
	mov	[alloc_small_ptr_backup + (1 + 1) * sizeof value], rdx ; хвост
	lea	rdx, [alloc_small_ptr_backup + (1 + 0) * sizeof value]
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


; Возвращает сумму двух целых.
; RDI - адрес 1-го слагаемого;
; RSI - адрес 2-го слагаемого.
C_primitive caml_nativeint_add
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	add	rax, [nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive

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



C_primitive caml_nativeint_bswap

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


; Возвращает частное от деления двух целых.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_nativeint_div
	nativeint_header
;!!!	Проверку делителя на 0 пока не выполняем.
	mov	rcx, [nativeint_val + rsi]
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


; Преобразует число в OCaml-строку (с заголовком) согласно формата.
; RDI - формат; см. format_of_iconv в stdlib/camlinternalFormat.ml
; RSI - адрес блока с целым.
; RDX (для точки входа .mask) содержит маску с разрядами, подлежащими выводу
; в случае форматов %X и %x (служит для корректного вывода int32).
C_primitive caml_nativeint_format
	or	rdx, -1
;	Создаём заголовок с нулевой длиной. Скорректируем её по готовности строки.
.mask:	mov	qword[alloc_small_ptr_backup], String_tag
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof value]
	push	alloc_small_ptr_backup
	mov	rsi, [nativeint_val + rsi]
	caml_string_length rdi, rcx, rax
;	Копируем префикс формата, пока не встретится %
.cp_fmt:
	jecxz	.exit0
	mov	al, [rdi]
	inc	rdi
	dec	ecx
	cmp	al, '%'
	jz	.fmt
.cpf:	mov	[alloc_small_ptr_backup], al
	inc	alloc_small_ptr_backup
	jmp	.cp_fmt
.fmt:	lea	r8, [rdi + 2]
	lea	r9d, [ecx - 1]
	cmp	byte[rdi], 'd'
	jz	.dec
	cmp	byte[rdi], 'X'
	jz	.HEX
	inc	r8
	dec	r9d
	cmp	word[rdi], 'nd'
	jz	.dec
	jmp	.cpf
.dec:	call	format_nativeint_dec
	jmp	.cp_fmt_tail
.HEX:	and	rsi, rdx
	mov	dl, 'A'
	jmp	.hex_f
.hex:	and	rsi, rdx
	mov	dl, 'a'
.hex_f:	call	format_nativeint_hex
;	Копируем остаток строки формата, если она есть.
.cp_fmt_tail:
	test	r9d, r9d
	jz	.exit
	mov	al, [r8]
	mov	[alloc_small_ptr_backup], al
	inc	r8
	inc	alloc_small_ptr_backup
	jmp	.cp_fmt_tail
.exit:	add	rdi, alloc_small_ptr_backup
	pop	alloc_small_ptr_backup
	sub	rdi, alloc_small_ptr_backup
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup - sizeof value]
	jmp	caml_alloc_string
.exit0:	zero	edi
	jmp	.exit
end C_primitive


; Возвращает остаток от деления (по модулю) двух целых.
; RDI - адрес делимого;
; RSI - адрес делителя.
C_primitive caml_nativeint_mod
	nativeint_header
;!!!	Проверку делителя на 0 пока не выполняем.
	mov	rcx, [nativeint_val + rsi]
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


; Возвращает произведение двух целых.
; RDI - адрес 1-го множителя;
; RSI - адрес 2-го множителя.
C_primitive caml_nativeint_mul
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	imul	qword[nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive


; Возвращает результат вычитания из 0 (смена знака) целого.
; RDI - адрес целого;
C_primitive caml_nativeint_neg
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	neg	rax
	nativeint_ret	rax
end C_primitive



C_primitive caml_nativeint_of_float

end C_primitive


; Возвращает адрес целого, полученного из OCaml value.
; RDI - OCaml value
C_primitive caml_nativeint_of_int
	nativeint_header
	Int_val	rdi
	nativeint_ret	rdi
end C_primitive


; Возвращает целое, сконвертированное из 32-х разрядного.
; RDI - адрес 32-х разрядного.
C_primitive caml_nativeint_of_int32
	nativeint_header
	movsxd	rax, [int32_val + rdi]
	nativeint_ret	rax
end C_primitive


; Возвращает целое OCaml value, сконвертированное из текстового представления.
; RDI - адрес строки.
C_primitive caml_nativeint_of_string
	nativeint_header
	mov	cl, sizeof value * 8
	call	parse_intnat
	nativeint_ret rax
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


; Возвращает разность двух целых.
; RDI - адрес 1-го уменьшаемое;
; RSI - адрес 2-го вычитаемое.
C_primitive caml_nativeint_sub
	nativeint_header
	mov	rax, [nativeint_val + rdi]
	sub	rax, [nativeint_val + rsi]
	nativeint_ret	rax
end C_primitive



C_primitive caml_nativeint_to_float

end C_primitive


; Возвращает OCaml value, полученное из 64-х разрядного целого.
C_primitive caml_nativeint_to_int
	mov	rax, [nativeint_val + rdi]
	Val_int	rax
	ret
end C_primitive


; Возвращает 32-х разрядное целое, полученное из 64-х разрядного.
C_primitive caml_nativeint_to_int32
	int32_header
	mov	eax, [nativeint_val + rdi]
	cdqe
	int32_ret rax
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



C_primitive caml_neg_float

end C_primitive



C_primitive caml_new_lex_engine

end C_primitive



C_primitive caml_obj_add_offset

end C_primitive


; Размещает в куче объект, все поля которого Val_long(0).
; RDI - тэг (OCaml value)
; RSI - размер (OCaml value) размещаемого в памяти блока в словах.
C_primitive caml_obj_block
	Int_val	rdi
	Int_val	rsi
	lea	rax, [Atom rdi]
	jz	.exit
	mov	rcx, rsi
	to_wosize rsi
	or	rdi, rsi
	mov	Val_header[alloc_small_ptr_backup], rdi
.@:	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof value]
	mov	qword[alloc_small_ptr_backup], Val_int 0
	loopne	.@
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof value]
	from_wosize rsi
	neg	rsi
	lea	rax, [alloc_small_ptr_backup + rsi * sizeof value]
.exit:	ret
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


; Задаёт тег объекту.
; RDI - адрес объекта;
; RSI - новый тег (OCaml value).
C_primitive caml_obj_set_tag
	Int_val	esi
	mov	byte[rdi - sizeof value], sil
	mov	eax, Val_unit
	ret
end C_primitive


; Возвращает тег объекта, либо налог для значений вне кучи.
; RDI - адрес объекта
C_primitive caml_obj_tag
	mov	eax, Val_int 1000	; int_tag
	test	edi, 1
	jnz	.exit
	mov	eax, Val_int 1002	; unaligned_tag
	test	edi, sizeof value - 7
	jnz	.exit
	mov	eax, Val_int 1001	; out_of_heap_tag
	cmp	rdi, heap_small
	jc	.exit
	cmp	rdi, alloc_small_ptr_backup	; [heap_descriptor.uncommited]
	jnc	.exit
	movzx	eax, byte[rdi - sizeof value]
	Val_int	eax
.exit:	ret
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


; Возвращает результат сравнения строк:
; Val_true - строки различаются.
; Val_false - строки идентичны;
; RDI - 1-я строка;
; RSI - 2-я строка.
C_primitive caml_string_notequal
	mov	eax, Val_false
	jmp	caml_string_equal.cmp
end C_primitive


; Возвращает результат сравнения строк:
; Val_true - строки идентичны;
; Val_false - строки различаются.
; RDI - 1-я строка;
; RSI - 2-я строка.
C_primitive caml_string_equal
	mov	eax, Val_true
caml_string_equal.cmp:
	mov	rcx, Val_header[rsi - sizeof value]
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



C_primitive caml_string_greaterequal

end C_primitive



C_primitive caml_string_greaterthan

end C_primitive



C_primitive caml_string_lessequal

end C_primitive



C_primitive caml_string_lessthan

end C_primitive


C_primitive caml_string_set16

end C_primitive



C_primitive caml_string_set32

end C_primitive



C_primitive caml_string_set64

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
