
macro C_primitive name
name:
.C_primitive_name equ `name
end macro

macro end?.C_primitive!
	if $ = .
		int3
	end if
end macro

macro C_primitive_stub
	display .C_primitive_name, ' stub ',10
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



C_primitive caml_array_append

end C_primitive



C_primitive caml_array_blit

end C_primitive



C_primitive caml_array_concat

end C_primitive



C_primitive caml_array_get

end C_primitive



C_primitive caml_array_get_addr

end C_primitive



C_primitive caml_array_get_float

end C_primitive



C_primitive caml_array_set

end C_primitive



C_primitive caml_array_set_addr

end C_primitive



C_primitive caml_array_set_float

end C_primitive



C_primitive caml_array_sub

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



C_primitive caml_blit_bytes

end C_primitive



C_primitive caml_blit_string

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



C_primitive caml_compare

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



C_primitive caml_create_bytes

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



C_primitive caml_ensure_stack_capacity

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



C_primitive caml_eq_float

end C_primitive



C_primitive caml_equal

end C_primitive



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



C_primitive caml_float_compare

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


; RDI - формат
; RSI - целое
C_primitive caml_format_int

end C_primitive


;CAMLprim value caml_fresh_oo_id (value v)
; RDI - value - игнорируется
C_primitive caml_fresh_oo_id
	mov	accu, [oo_last_id]
	add	[oo_last_id], 2
	ret
end C_primitive



C_primitive caml_frexp_float

end C_primitive



C_primitive caml_gc_compaction

end C_primitive



C_primitive caml_gc_counters

end C_primitive



C_primitive caml_gc_full_major

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



C_primitive caml_ge_float

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



C_primitive caml_greaterequal

end C_primitive



C_primitive caml_greaterthan

end C_primitive



C_primitive caml_gt_float

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


;CAMLprim value caml_int64_float_of_bits(value vi)
C_primitive caml_int64_float_of_bits
C_primitive_stub
;  return caml_copy_double(caml_int64_float_of_bits_unboxed(Int64_val(vi)));
	mov	accu, '64_float'
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



C_primitive caml_int_compare

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



C_primitive caml_le_float

end C_primitive



C_primitive caml_lessequal

end C_primitive



C_primitive caml_lessthan

end C_primitive



C_primitive caml_lex_engine

end C_primitive



C_primitive caml_log10_float

end C_primitive



C_primitive caml_log1p_float

end C_primitive



C_primitive caml_log_float

end C_primitive



C_primitive caml_lt_float

end C_primitive



C_primitive caml_make_array

end C_primitive



C_primitive caml_make_float_vect

end C_primitive



C_primitive caml_make_vect

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
	virtual at rdi - sizeof Val_header
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


IO_BUFFER_SIZE	:= 4096 - 5 * 8 ; В оригинале 65536
struct channel
	.fd	dd ?	; Описатель файла
	.flags	dd ?	; Флаги (поле перемещено)
	.offset	dq ?	; Позиция в файле
	.end	dq ?	; Адрес старшей границы буфера
	.curr	dq ?	; Адрес текущей позиции буфера
	.max	dq ?	; Адрес границы буфера для чтения
;	.mutex	dq ?	; /* Placeholder for mutex (for systhreads) */
;	.next	dq ?	; Буфера организованы в двусвязный список
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
.alloc_channel:
;	Для сборщика мусора требуется:
;	chan->refcount++;             /* prevent finalization during next alloc */
;	add_to_custom_table (&caml_custom_table, result, mem, max);
	virtual at alloc_small_ptr_backup
	.co	channel_operations_object
	end virtual
	mov	[.co.tag], 3 wosize or Caml_black or Custom_tag
	mov	[.co.operations], channel_operations
	mov	[.co.channel], rax
	lea	rax, [alloc_small_ptr_backup + sizeof Val_header]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof .co]
	ret
end C_primitive


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
	jmp	caml_ml_open_descriptor_in.alloc_channel
end C_primitive



C_primitive caml_ml_out_channels_list
C_primitive_stub

	mov	eax, Val_emptylist
	retn
end C_primitive

; RDI - канал
; RSI - начальный адрес блока, отправляемого в канал.
; RDX - длина
; Возвращает количество отправленных байт.
proc caml_putblock
	virtual at rax
	.channel	channel
	end virtual
	mov	rax, rdi
	mov	rcx, [.channel.end]
	sub	rcx, [.channel.curr]
	cmp	rdx, rcx
	jae	.over
;	Места в буфере канала достаточно, копируем блок.
	mov	rcx, rdx
	mov	rdi, [.channel.curr]
rep	movs	byte[rdi], [rsi]
	mov	[.channel.curr], rdi
	mov	rax, rdx
	ret
.over:
int3
;	mov	edi, [.channel.fd]
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
	virtual at rdi - sizeof Val_header
	.co	channel_operations_object
	end virtual
	mov	rdi, [.co.channel]
	Ulong_val rdx
	lea	rsi, [rsi + rdx]
	Ulong_val rcx
	jecxz	.exit
	mov	rdx, rcx
.again:	push	rsi rdx
	call	caml_putblock
	pop	rdx rsi
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
	virtual at rdi - sizeof Val_header
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
	mov	rax, [rdi - sizeof value]
;	from_wosize	rax
	shr	rax, 10 - sizeof_value_log2
	and	rax, not (sizeof value - 1)
	dec	rax
	movzx	rcx, byte[rdi + rax]
	sub	rax, rcx
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



C_primitive caml_neq_float

end C_primitive



C_primitive caml_new_lex_engine

end C_primitive



C_primitive caml_notequal

end C_primitive



C_primitive caml_obj_add_offset

end C_primitive



C_primitive caml_obj_block

end C_primitive



C_primitive caml_obj_dup

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
; Вызыввается для "Pervasives.array_bound_error", "Pervasives.do_at_exit"
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



C_primitive caml_string_compare

end C_primitive



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



C_primitive caml_sys_const_backend_type

end C_primitive



C_primitive caml_sys_const_big_endian

end C_primitive



C_primitive caml_sys_const_int_size

end C_primitive



C_primitive caml_sys_const_max_wosize

end C_primitive



C_primitive caml_sys_const_ostype_cygwin

end C_primitive



C_primitive caml_sys_const_ostype_unix

end C_primitive



C_primitive caml_sys_const_ostype_win32

end C_primitive



C_primitive caml_sys_const_word_size

end C_primitive


; edi = Value
; Произвольный код может быть возвращён вызовом sys_exit библиотеки Pervasives.
C_primitive caml_sys_exit
	Int_val	edi	; 1й
.int:	sys.exit
	ud2
end C_primitive



C_primitive caml_sys_file_exists

end C_primitive



C_primitive caml_sys_get_argv

end C_primitive



C_primitive caml_sys_get_config

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

display_num_ln 'Размер C-примитивов: ', $-C_primitive_first