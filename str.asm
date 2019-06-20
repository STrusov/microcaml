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
	caml_invalid_argument "Bytes.create"
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


caml_bytes_equal := caml_string_equal


; Возвращает результат сравнения строк:
; Val_true - строки различаются.
; Val_false - строки идентичны;
; RDI - 1-я строка;
; RSI - 2-я строка.
C_primitive caml_string_notequal
	mov	eax, Val_false
	jmp	caml_string_equal.cmp
end C_primitive


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


C_primitive caml_string_lessthan
end C_primitive


C_primitive caml_string_lessequal
end C_primitive


C_primitive caml_string_greaterthan
end C_primitive


C_primitive caml_string_greaterequal
end C_primitive


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


C_primitive caml_fill_bytes
end C_primitive


caml_fill_string := caml_fill_bytes


C_primitive caml_bitvect_test
end C_primitive
