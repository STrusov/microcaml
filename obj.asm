; Процедуры (C примитивы) для работы с объектами.


C_primitive caml_static_alloc
end C_primitive


C_primitive caml_static_free
end C_primitive


C_primitive caml_static_resize
end C_primitive


C_primitive caml_obj_is_block
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


; Задаёт тег объекту.
; RDI - адрес объекта;
; RSI - новый тег (OCaml value).
C_primitive caml_obj_set_tag
	Int_val	esi
	mov	byte[rdi - sizeof value], sil
	mov	eax, Val_unit
	ret
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


; Создаёт копию объекта и возвращает её адрес.
; RDI - адрес исходного объекта.
C_primitive caml_obj_dup
;	В оригинале проверяется No_scan_tag
	mov	rcx, Val_header[rdi - sizeof value]
	mov	[alloc_small_ptr_backup], rcx
	from_wosize rcx
	mov	rsi, rdi
	lea	rdi, [alloc_small_ptr_backup + sizeof value]
	mov	rax, rcx
	neg	rax
rep	movs	Val_header[rdi], [rsi]
	lea	rax, [rdi + rax * sizeof value]
	mov	alloc_small_ptr_backup, rdi
	ret
end C_primitive


C_primitive caml_obj_truncate
end C_primitive


C_primitive caml_obj_add_offset
end C_primitive


C_primitive caml_lazy_follow_forward
end C_primitive


C_primitive caml_lazy_make_forward
end C_primitive


C_primitive caml_get_public_method
end C_primitive


virtual Data
	oo_last_id	value	Val_int_0
end virtual

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


C_primitive caml_int_as_pointer
end C_primitive


C_primitive caml_obj_reachable_words
end C_primitive
