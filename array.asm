; Процедуры (C примитивы) для работы с массивами данных.


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
	Int_val	rsi
;	Формируем в куче блок с вещественным числом и возвращаем его адрес.
	mov	Val_header[alloc_small_ptr_backup], 1 wosize + Double_tag
	mov	rax, [rdi + rsi * sizeof value]
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
	jnz	caml_array_unsafe_set_addr
; RDX - адрес вещественного числа с новым значением.
caml_array_unsafe_set_float:
	mov	rdx, [rdx]
caml_array_unsafe_set_addr:
	Int_val	rsi
	mov	[rdi + rsi * sizeof value], rdx
	mov	eax, Val_unit
	ret
end C_primitive


; Создаёт массив вещественных чисел без инициализации элементов.
; RDI - длина вектора.
C_primitive caml_make_float_vect
	mov	esi, Double_array_tag
	jmp	caml_alloc_dummy.tag
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
