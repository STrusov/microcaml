; Процедуры (C примитивы) обеспечивающие системные вызовы.


NO_ARG	:= Val_int(0)


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


C_primitive caml_sys_open
end C_primitive


C_primitive caml_sys_close
end C_primitive


C_primitive caml_sys_file_exists
end C_primitive


C_primitive caml_sys_is_directory
end C_primitive


C_primitive caml_sys_remove
end C_primitive


C_primitive caml_sys_rename
end C_primitive


C_primitive caml_sys_chdir
end C_primitive


C_primitive caml_sys_getcwd
end C_primitive


; Возвращает строку со значением переменной окружения.
; RDI - адрес строки с именем переменной окружения.
C_primitive caml_sys_unsafe_getenv
	caml_string_length rdi, rdx, rcx	; rdx длина строки
	jz	caml_raise_not_found		; флаги установлены макросом
	mov	r8, [environment_variables]
.check_var_name:
	mov	rsi, [r8]
	test	rsi, rsi
	jz	caml_raise_not_found
	add	r8, 8
	zero	ecx
.scmp:	lods	byte[rsi]
	cmp	[rdi + rcx], al
	jnz	.check_var_name
	inc	ecx
	cmp	ecx, edx
	jnz	.scmp
	lods	byte[rsi]
	cmp	al, '='
	jnz	.check_var_name
.found:	zero	edi
	mov	Val_header[alloc_small_ptr_backup], String_tag
.copy:	lods	byte[rsi]
	mov	[alloc_small_ptr_backup + rdi + sizeof value], al
	inc	edi
	test	al, al
	jnz	.copy
	dec	edi
	jmp	caml_alloc_string
end C_primitive


;!!! следует выполнить проверки аналогичные secure_getenv
C_primitive caml_sys_getenv
C_primitive_stub
	jmp	caml_sys_unsafe_getenv
end C_primitive


; EDI - не используется
; Возвращает пару значений:
; 0й - строка с именем исполняемого файла (байт-кода);
; 1й - массив из аргументов (начинается с имени исполняемого файла).
;
; Реализация не полная:
; Массив аргументов включает лишь первый элемент. См. так же main.1arg:
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


C_primitive caml_sys_system_command
end C_primitive


C_primitive caml_sys_time
end C_primitive


C_primitive caml_sys_random_seed
end C_primitive


; Возвращает Val_false на Low Endian
C_primitive caml_sys_const_big_endian
	mov	eax, Val_false
	ret
end C_primitive


; Возвращает размер слова с битах - 64.
C_primitive caml_sys_const_word_size
	mov	eax, Val_int(8 * sizeof(value))
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


C_primitive caml_sys_read_directory
end C_primitive


C_primitive caml_sys_isatty
end C_primitive
