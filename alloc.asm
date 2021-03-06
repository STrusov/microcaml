; Процедуры (C примитивы) для размещения данных в куче.


; Формирует в куче OCaml-строку из С-строки
; RDI - адрес исходной строки.
; RDX разрушается.
proc caml_copy_string
	mov	rdx, rdi
	zero	edi
	mov	qword[alloc_small_ptr_backup], rdi
.copy:	mov	al, [rdx + rdi]
	test	al, al
	jz	caml_alloc_string
	mov	[alloc_small_ptr_backup + rdi + sizeof value], al
	inc	edi
	jmp	.copy
end proc

; EDI - целое; количество байт для строки.
; Возвращает адрес строки (за заголовком).
proc caml_alloc_string
	mov	eax, edi
;	size = (len + sizeof(value)) / sizeof(value);
	add	edi, sizeof value
	and	edi, not (sizeof value - 1)
	mov	edx, edi
	dec	edx
	sub	edx, eax
	and	edx, (sizeof value - 1)
	mov	eax, edi
	shr	eax, sizeof_value_log2
;	shr	rdi, sizeof_value_log2
;	to_wosize rdi
	shl	rdi, wosize_shift - sizeof_value_log2
	or	rdi, String_tag
	mov	Val_header[alloc_small_ptr_backup], rdi
;	Завершающий байт = размер блока в байтах - 1 - длина строки
;	равен количеству байт в последнем слове, не принадлежащих строке.
;	Обнулим чужие байты.
	mov	ecx, edx
	or	rsi, -1
	shl	ecx, 3	; *8
	shr	rsi, 8
	shr	rsi, cl
	shl	rdx, 7 * 8
	and	rsi, [alloc_small_ptr_backup + rax * sizeof value]
	or	rdx, rsi
	mov	[alloc_small_ptr_backup + rax * sizeof value], rdx
;	Предыдущая команда может изменить содержимое alloc_small_ptr_backup,
;	потому порядок выполнения важен.
	lea	rdx, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + (rax + 1) * sizeof value]
	mov	rax, rdx
	ret
end proc


C_primitive caml_alloc_float_array
end C_primitive


; Резервирует место в куче под массив вещественных чисел.
; RDI - размер (OCaml value) размещаемого в памяти блока в словах.
; На AMD64 вещественное число занимает столько же места, сколько другое значение.
caml_alloc_dummy_float := caml_alloc_dummy


; Резервирует место в куче для функции.
; RDI - размер (OCaml value) размещаемого в памяти блока в словах.
; RSI - арность. В оригинале используется js_of_ocaml runtime.
caml_alloc_dummy_function := caml_alloc_dummy


; Резервирует место в куче.
; RDI - размер (OCaml value) размещаемого в памяти блока в словах.
C_primitive caml_alloc_dummy
	zero	rsi
.tag:	Int_val	rdi
	lea	rax, [Atom 0]
	jz	.exit
	to_wosize rdi
	or	rdi, rsi
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
