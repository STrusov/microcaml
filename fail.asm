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

; Прототипы и подлежат доработке.


macro caml_invalid_argument msg
	lea	rdi, [.m]
	puts	rdi
	mov	edx, -EINVAL
	jmp	sys_exit
.m	db	msg, 10, 0
end macro


proc caml_array_bound_error
	caml_invalid_argument	'Выход за пределы массива'
end proc
