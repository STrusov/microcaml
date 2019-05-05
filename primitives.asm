
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

macro caml_invalid_argument msg
	lea	rdi, [.m]
	puts	rdi
	mov	edi, EINVAL
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



C_primitive caml_array_append

end C_primitive



C_primitive caml_array_blit

end C_primitive



C_primitive caml_array_concat

end C_primitive



C_primitive caml_array_get

end C_primitive


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
	lea	rax, [rdi + rsi * sizeof value]
	ret
.bound_error:
	puts	.error_out_of_bounds
	mov	eax, -EINVAL
	jmp	sys_exit
.error_out_of_bounds	db 'Выход за пределы массива', 10, 0
end C_primitive



C_primitive caml_array_get_float

end C_primitive



C_primitive caml_array_set

end C_primitive



C_primitive caml_array_set_addr

end C_primitive



C_primitive caml_array_set_float

end C_primitive


; Возвращает (сылку на) массив, созданный из подмножества элементов исходного.
; RDI - адрес исходного массива;
; RSI - номер (от 0) первого элемента подмножества.
; RDX - количество элементов подмножества.
C_primitive caml_array_sub
;	В оригинале вызывает универсальную функцию.
;	Создаём заголовок из тега исходного массива + размер нового.
	movzx	eax, byte[rdi - sizeof value]
	Int_val	rdx
	mov	rcx, rdx
	to_wosize rdx
	or	rax, rdx
	mov	[alloc_small_ptr_backup], rax
;	Копируем подмножество элементов в новый массив.
	Int_val	rsi
	lea	rsi, [rdi + rsi * sizeof value]
	lea	rdi, [alloc_small_ptr_backup + sizeof value]
	mov	rax, rdi
rep	movs	qword[rdi], [rsi]
	mov	alloc_small_ptr_backup, rdi
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
	bswap	rdx
	mov	[alloc_small_ptr_backup + rcx * sizeof value], rdx
;	Предыдущая команда может изменить содержимое alloc_small_ptr_backup,
;	потому порядок выполнения важен.
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + (rcx + 1) * sizeof value]
	ret
end proc


; RDI - количество байт для строки в формате OCaml.
C_primitive caml_create_bytes
	Long_val	rdi
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


; EDI - требуемы размер стека (OCaml value)
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



C_primitive caml_eq_float

end C_primitive


; Возвращает:
; > 0	- 1е > 2го;
; 0	- значения равны;
; < 0	- 1е < 2го;
UNORDERED := 1 shl (8 * sizeof value - 1)
; RDI - 1-е значение;
; RSI - 2-e значение.
; RDX - --
proc compare_val
val1	equ rdi
val2	equ rsi
	cmp	val1, val2
	jz	.equal
	test	val1, 1
	jnz	.val1_is_long
	test	val2, 1
	jnz	.val2_is_long
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
	movzx	eax, byte[val1 - sizeof value]
;	cmp	al, Forward_tag
;	jz	.forward_tag
	movzx	ecx, byte[val2 - sizeof value]
;	cmp	cl, Forward_tag
;	jz	.forward_tag
	sub	eax, ecx
	jnz	.exit
;	cmp	al, Abstract_tag
;	je	.abstract_tag
;	jb	.tags
;	Теги равны - сравниваем размеры
	mov	rax, Val_header[val1 - sizeof value]
	mov	rcx, Val_header[val2 - sizeof value]
	sub	rax, rcx
	jnz	.exit
	from_wosize rcx
;	и значения.
.1:	mov	rax, [val1]
	sub	rax, [val2]
	jnz	.exit
	lea	val1, [val1 + sizeof value]
	lea	val2, [val2 + sizeof value]
	dec	rcx
	jnz	.1

.equal:	zero	eax
.exit:	ret

.tags:
.abstract_tag:
.forward_tag:
.arbitrary_ptr:
.val1_is_long:
.val2_is_long:
int3
ud2
restore	val2
restore	val1
end proc


; RDI - 1-е значение;
; RSI - 2-e значение.
C_primitive caml_equal
C_primitive_stub
	call	compare_val
	test	rax, rax
	mov	eax, Val_false
	mov	ecx, Val_true
	cmovz	eax, ecx
	ret
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


; EDI - адрес источника для копирования в кучу числа с плавающей точкой.
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
	mov	rax, [rdi - sizeof value]
;	from_wosize	rax
	shr	rax, wosize_shift - sizeof_value_log2
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
	lea	rsi, [bytecode_filename]
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

display_num_ln 'Размер C-примитивов: ', $-C_primitive_first
