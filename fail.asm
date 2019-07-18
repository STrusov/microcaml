; Вспомогательные процедуры, вызываемые C-примитивами в исключительных ситуациях.

OUT_OF_MEMORY_EXN	:= 0	; "Out_of_memory"
SYS_ERROR_EXN		:= 1	; "Sys_error"
FAILURE_EXN		:= 2	; "Failure"
INVALID_EXN		:= 3	; "Invalid_argument"
END_OF_FILE_EXN		:= 4	; "End_of_file"
ZERO_DIVIDE_EXN		:= 5	; "Division_by_zero"
NOT_FOUND_EXN		:= 6	; "Not_found"
MATCH_FAILURE_EXN	:= 7	; "Match_failure"
STACK_OVERFLOW_EXN	:= 8	; "Stack_overflow"
SYS_BLOCKED_IO		:= 9	; "Sys_blocked_io"
ASSERT_FAILURE_EXN	:= 10	; "Assert_failure"
UNDEFINED_RECURSIVE_MODULE_EXN	:=11	; "Undefined_recursive_module"

; RDI - адрес строки с текстом ошибки.
caml_failwith:
	mov	rax, [caml_global_data]
; В оригинале проверяется caml_global_data, т.к. вызов может произойти
; из input_value при заполнении глобальных данных. Здесь пока такого нет.
	mov	rsi, [rax + FAILURE_EXN * sizeof value]
;
; В оригинале порядок аргументов обратный.
; RSI - адрес тега.
; RDI - адрес строки с текстом ошибки.
caml_raise_with_string:
	push	rsi
	call	caml_copy_string
	mov	rsi, rax
	pop	rdi
;
; RDI - тег;
; RSI - аргумент.
caml_raise_with_arg:
	mov	Val_header[alloc_small_ptr_backup], 2 wosize or Pair_tag
	mov	[alloc_small_ptr_backup + (1 + 0) * sizeof value], rdi
	mov	[alloc_small_ptr_backup + (1 + 1) * sizeof value], rsi
	lea	rdi, [alloc_small_ptr_backup + 1 * sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + (1 + 2) * sizeof value]
;
; RDI - адрес информации об исключении.
caml_raise:
;	Восстанавливаем регистры виртуальной машины (см. C_CALL).
	mov	accu, rdi
	mov	alloc_small_ptr, alloc_small_ptr_backup
;	Указатель стека восстанавливается в обработчике инструкции.
	jmp	Instruct_RAISE


; RDI - адрес строки с текстом ошибки.
caml_invalid_argument:
	mov	rax, [caml_global_data]
; В оригинале проверяется caml_global_data, т.к. вызов может произойти
; из input_value при заполнении глобальных данных. Здесь пока такого нет.
	mov	rsi, [rax + INVALID_EXN * sizeof value]
	jmp	caml_raise_with_string


proc caml_array_bound_error
	lea	rdi, [.msg]
	jmp	caml_invalid_argument
if ORIGINAL_ERROR_MESSAGES
.msg	db 'index out of bounds', 0
else
.msg	db 'Выход за пределы массива', 0
end if
end proc


macro caml_raise_constant	exn_code
	mov	rax, [caml_global_data]
	mov	rdi, [rax + exn_code * sizeof value]
	jmp	caml_raise
end macro

; Деление на 0.
proc	caml_raise_zero_divide
	caml_raise_constant	ZERO_DIVIDE_EXN
end proc

proc	caml_raise_not_found
	caml_raise_constant	NOT_FOUND_EXN
end proc
