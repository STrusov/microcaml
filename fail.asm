; Вспомогательные процедуры, вызываемые C-примитивами в исключительных ситуациях.


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
