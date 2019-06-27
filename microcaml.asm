include 'config.inc'

include 'linux-x64.inc'

include 'mlvalues.inc'

PAGE_SIZE	:= 1000h	; 4096

;format	ELF64 executable ELFOSABI_LINUX
format ELF64
;entry	main
public _start

; Общесистемное соглашение о вызовах для Linux AMD64 (см. System V AMD64 ABI)
;
; Сохраняются при вызовах внешних функций: RBX RBP ESP R12 R13 R14 R15
;
; Параметры передаются в регистрах:
; RDI	1й
; RSI	2й
; RDX	3й
; RCX	4й	; R10 для вызовов ядра
; R8	5й
; R9	6й
;
; CALL library
;
; Результат возвращается в RAX, RDX [*]
; [*] Для структур данных размером более 128 бит
;     1м аргументом передаётся указатель на выделенную область памяти.

; Область стека сохраняется вызываемыми библиотечными функциями (но не в ядре)
red_zone equ (rsp-128)


; Формат исполняемого файла (образа) для виртуальной машины.
;
; Образ состоит из ряда секций:
;	может быть shebang #!/usr/bin/ocamlrun
;	данные 1й секции
;	данные 2й секции
;	...
;	данные Nй секции
;	описатель 1й секции
;	...
;	описатель Nй секции
;	exec_trailer
;
; Возможны 9 секций (согласно bytecomp/bytelink.ml) :
; 'RNTM'	путь до интерпретатора (в режиме use_runtime);
; 'CODE'	байт-код для виртуальной машины;
; 'DLPT'	дополнительные пути поиска динамических библиотек;
; 'DLLS'	имена динамически подключаемых библиотек;
; 'PRIM'	имена всех примитивов, разделены 0;
; 'DATA'	таблица глобальных данных;
; 'SYMB'	карта глобальных идентификаторов;
; 'CRCS'	CRC модулей;
; 'DBUG'	отладочная информация.
;
; В файле располагаются в вышеприведённом порядке, но могут отсутствовать.
;
; Таблицу секций обрабатываем от старших адресов к младшим, поскольку
; исходный формат разработан для чтения файла с SEEK_END.
; Поиск секций завершится по достижении 0го байта.
sect_names equ 'DBUG','CRCS','SYMB','DATA','PRIM','DLLS','DLPT','CODE','RNTM',0

; При использовании шебанга #!/usr/bin/ocamlrun секция кода выровнена
; по размеру слова (4 байта)

; !!! ocamlrun копирует секции и добавляет завершающий 0.
; Необходимости в этом не обнаружено.

; Описатель секции. Размер в big-endian формате.
struct section_descriptor
	.name	dd ?
	.len	dd ?
end struct

struct exec_trailer
	.num_sections	dd ?	; Количество секций
	.magic:
	.magic0		dd ?	; Сигнатура байткода
	.magic1		dd ?
	.magic2		dd ?
end struct

;  Сигнатура 'Caml1999X011'
EXEC_MAGIC0	:= 'Caml'
EXEC_MAGIC1	:= '1999'
EXEC_MAGIC2	:= 'X011'


; Машинный код
;segment	executable
section '.text' executable align 32

; 	Интерпретатор размещаем в начале страницы для выравнивания
include 'interp.asm'

;	Куча и сборщик мусора
include 'heap.asm'

; Вывод строки в stdout
; RSI - адрес строки
proc stdout_string
	mov	edi, STDOUT_FILENO	; 1й
	zero	edx			; 3й
.count:	cmp	byte [rsi+rdx], 1
	inc	edx
	jnc 	.count
	dec	edx
	sys.write
	ret
end proc

; Вывод шестнадцатеричного числа (в регистре AL)
proc stdout_hex_byte
	mov	ecx, eax
	and	eax, 0fh
	add	al, '0'
	cmp	al, '9'
	jna	.d1
	add	al, 'A' - '9' - 1
.d1:	mov	ah, al
	mov	al, cl
	shr	al, 4
	and	al, 0fh
	add	al, '0'
	cmp	al, '9'
	jna	.d2
	add	al, 'A' - '9' - 1
.d2:
	push	rax
	puts	rsp
	pop	rax
	ret
end proc

macro puts string
	lea	rsi, [string]
	call	stdout_string
end macro

_start:
main:
.stack_size	:= sizeof .st
;	Допустим 1 аргумент - имя файла байт-кода.
	mov	rcx, [rsp]	; argc
	cmp	ecx, 2
	jz	.1arg
	puts	error_about
	mov	edi, -EINVAL
	jmp	sys_exit
.1arg:	mov	rdi, [rsp + 16]	; argv
	mov	[bytecode_filename], rdi
	sub	rsp, .stack_size

;	Арифметический сопроцессор настроен как требует IEEE
;	везде, кроме версий FreeBSD до 4.0R
;	caml_init_ieee_floats

;	Желательно выполнить инициализацию на этапе компиляции.
;	с учётом: CAMLextern void caml_register_custom_operations()
;	caml_init_custom_operations

;	Должна быть возможна инициализация на этапе компиляции.
;	caml_ext_table_init(&caml_shared_libs_path, 8);

;	caml_external_raise = NULL;

;	caml_parse_ocamlrunparam

	mov	esi, O_RDONLY			; 2й
	sys.open
	test	eax, eax
	mov	ebx, eax	; дескриптор файла
	jns	.bytecode_opened

	puts	error_bytecode_open
	mov	edi, ebx
	jmp	sys_exit

.bytecode_opened:
;	В отличие от ocamlrun используем отображение файла в ОЗУ.
	virtual at rsp
	.st	stat
	end virtual
	and	[.st.st_size], 0
	mov	rsi, rsp	; 2й	struct stat *statbuf
	mov	edi, ebx	; 1й	int fd
	sys.fstat
;	файл нулевого размера не должен отобразиться
	zero	edi			; 1й
	mov	rsi, [.st.st_size]	; 2й
	mov	edx, PROT_READ		; 3й
	mov	r10d, MAP_PRIVATE	; 4й
	mov	r8, rbx			; 5й
	zero	r9			; 6й
; void *mmap(void *addr, size_t length, ulong prot, ulong flags, ulong fd, off_t offset);
	sys.mmap
	mov	edi, ebx
	mov	rbx, rax	; Адрес байткода
	sys.close
	j_ok	ebx, .bytecode_mapped

	puts	error_bytecode_map
	mov	edi, ebx
	jmp	sys_exit

.bytecode_mapped:
; 	Образ завершается сигнатурой "Caml1999X011"
	virtual at rbx+rdx - sizeof .exec_trailer
	.exec_trailer exec_trailer
	end virtual
	mov	rdx, [.st.st_size]
	mov	rax, EXEC_MAGIC0 or EXEC_MAGIC1	shl 32	; 'Caml1999'
	cmp	[.exec_trailer.magic], rax
	jnz	.invalid_bytecode
	cmp	[.exec_trailer.magic2], EXEC_MAGIC2	; 'X011'
	jz	.signature_ok

.invalid_bytecode:
	puts	error_bytecode_invalid
.invalid_bytecode_msg:
	mov	edi, -ENOEXEC
	jmp	sys_exit
.dlls_not_supported_yet:
	puts	error_bytecode_dlls
	jmp	.invalid_bytecode_msg

.signature_ok:
;	Размещаем переменные вместо st stat (макс. 144 байта)
	virtual at rsp
	.sect_addrs:
	.sect_dbug dq ?	; 'DBUG' отладочная информация.
	.sect_crcs dq ?	; 'CRCS' CRC модулей;
	.sect_symb dq ?	; 'SYMB' карта глобальных идентификаторов;
	.sect_data dq ?	; 'DATA' таблица глобальных данных;
	; req_prims
	.sect_prim dq ?	; 'PRIM' имена всех примитивов;
	; shared_libs
	.sect_dlls dq ?	; 'DLLS' имена динамически подключаемых библиотек;
	; shared_lib_path
	.sect_dlpt dq ?	; 'DLPT' дополнительные пути поиска динамических библиотек;
	; caml_start_code
	.sect_code dq ?	; 'CODE' байт-код;
	.sect_rntm dq ?	; 'RNTM' путь до интерпретатора (в режиме use_runtime);
	assert $ - rsp <= sizeof .st
	end virtual
;	Заполняем адреса (9шт. см. выше) для имеющихся в образе секций
;	(адреса отсутствующих секций следует обнулить).
;	Обрабатываем таблицу секций от старших адресов к младшим.
;	Секции следуют в строгом порядке, но некоторые могут отсутствовать.
;	Проверяем наличие в таблице каждого имени из списка sect_names (завершён 0м).
;	Для имеющегося описателя секции отнимаем его размер от адреса предыдущей
;	(от старших адресов, или с конца файла) секции или exec_trailer (r9).
;	Секции с нулевым размером считаем отсутствующей.
	mov	ecx, [.exec_trailer.num_sections]
	bswap	ecx		; из big endian
	neg	rcx
	lea	r9, [.exec_trailer-sizeof .sd]	; Старший элемент таблицы секций.
	lea	r8, [r9+rcx*8+sizeof .sd]	; Младший элемент таблицы секций.
;	Адрес "предыдущей" секции, т.е. находящейся в более старших адресах.
	mov	rcx, r8
	lea	rsi, [bytecode_sect_names]
	mov	rdi, rsp	; lea	rdi, [.sect_addrs]
.sect_desc:
	lods	dword[rsi]
	test	al, al
	jz	.sect_desc_done
;	Если секция отсуствует, её адрес останется 0.
	and	qword[rdi], 0
	virtual at r9
	.sd	section_descriptor
	end virtual
	cmp	.sd, r8
	jb	.sect_addr_none		; Проверили всю таблицу в образе?
	cmp	[.sd.name], eax
	jne	.sect_addr_none
	mov	eax, [.sd.len]
	test	eax, eax
	jz	.sect_empty
	bswap	eax
	sub	rcx, rax
	mov	[rdi], rcx
.sect_empty:
	sub	.sd, sizeof .sd		; r9
.sect_addr_none:
	add	rdi, 8
	jmp	.sect_desc

.sect_desc_done:
	mov	rax, [.sect_data]
; 	Для валидных адресов старшая часть идентична и не 0
	and	rax, [.sect_prim]
	and	rax, [.sect_code]
	jz	.invalid_bytecode

;	Примитивы во внешних библиотеках (dlopen+dlsym) пока не поддерживаются.	
	mov	rax, [.sect_dlls]
	or	rax, [.sect_dlpt]
	jnz	.dlls_not_supported_yet

;	caml_build_primitive_table() (см. byterun/dynlink.c) заполняет таблицу
;	примитивов caml_prim_table их адресами, для чего ищет перебором
;	каждое имя из секции 'PRIM' в массиве caml_names_of_builtin_cprim[], а
;	адрес имплементации берёт из связанного массива caml_builtin_cprim[].
;	Оба массива находятся в byterun/prims.c (файл генерируется при сборке).
;	Если байткод слинкован с интерпретатором статически, таблица примитивов
;	копируется из caml_builtin_cprim в caml_build_primitive_table_builtin().
;	Здесь создаём таблицу на этапе ассемблирования, см. caml_builtin_cprim

;	Инициализируем кучу.
;	Указатель на текущее свободное место в куче - alloc_small_ptr.
;	Выделение памяти происходит путём его увеличения, новые страницы
;	добавляются прозрачно по необходимости.
	heap_init

; Заголовок блока данных, расположенный перед ними.
;struct marshal_header
;	magic		dd ?
;	data_len	dd ?	; Размер данных в байтах.
;	num_objects	dd ?	; Количество объектов.
;	whsize32	dd ?	; Размер данных в 32-х разрядных словах.
;	whsize64	dd ?	; Размер данных в 64-ти разрядных словах.
;end struct

;	В начале секции 'DATA' располагается заголовок упорядоченных данных:
;	0   Сигнатура 0x84 0x95 0xA6 0xBE
Intext_magic_number_small := 0x8495A6BE bswap 4
;	4   Размер упорядоченных данных в байтах.
;	8   Количество общих (shared) блоков.
;	12   Размер в словах для 32-ти разрядной платформы.
;	16   Размер в словах для 64-х разрядной платформы.
;	Все числа 32-х разрядные, big endian.
	mov	rsi, [.sect_data]
	lods	dword[rsi]
	cmp	eax, Intext_magic_number_small
	jnz	invalid_datasection_sig
	lods	dword[rsi]
	lods	dword[rsi]
	bswap	eax		; num_objects
;	Выделяем на стеке место под временную таблицу с адресами объектов,
;	сохранив её размер. Требуется для обработки CODE_SHARED*
intern_obj_table equ (rbp + sizeof value)	; учитываем push rax дальше
obj_counter	equ r8
	neg	rax
	lea	rsp, [rsp + rax * sizeof value]
	neg	rax
	push	rax
	zero	obj_counter
	mov	rbp, rsp
	lods	dword[rsi]
	lods	dword[rsi]
	bswap	eax		; whsize64
	mov	ecx, eax
;	ocamlrun считывает значение функцией intern_rec() во внутреннее хранилище
;	и сохраняет ссылку в caml_global_data для доступа по инструкции GETGLOBAL.
;	Здесь сохраняются объекты при чтении из DATA.
intern_dest	equ alloc_small_ptr	; intern_block == intern_dest + sizeof value
dest		equ rbx
	lea	dest, [caml_global_data]
;	intern_rec()
;	Развёрнутая рекурсия. Счётчики циклов сохраняем на стеке.
	virtual at rsp
	label 	.intern_item:16
		.count	dq ?
		.dest	dq ?
	end virtual
	jmp	.read_code
;	Адреса объектов кешируем.
.read_obj_ok:
	mov	[intern_obj_table + obj_counter * sizeof value], rax
	inc	obj_counter
	jmp	.read_item_ok
;	Целые сохраняются в таблице ссылок непосредственно как значения.
.read_int_ok:
	lea	rax, [2*rax+1]
;	По завершению чтения элемента сохраняем его адрес в таблице ссылок.
.read_item_ok:
;	Поскольку dest < rdi, менеджер кучи добавит страницу.
	mov	[dest], rax
;OReadItems 	:= 0	; считывание элементов
.read_items:
PREFIX_SMALL_BLOCK	:= 0x80
PREFIX_SMALL_INT	:= 0x40
PREFIX_SMALL_STRING	:= 0x20
CODE_CUSTOM		:= 0x12
CODE_DOUBLE_ARRAY8_LITTLE	:= 0xE
CODE_DOUBLE_LITTLE	:= 0xC
CODE_STRING8		:= 0x9
CODE_BLOCK32		:= 0x8
CODE_SHARED16		:= 0x5
CODE_SHARED8		:= 0x4
CODE_INT64		:= 0x3
CODE_INT32		:= 0x2
CODE_INT16		:= 0x1
CODE_INT8		:= 0x0
	cmp	rsp, rbp
	jz	.read_items_finished
;	Следующий запланированный адрес в таблице ссылок
	mov	dest, [.dest]
	add	[.dest], sizeof value
	dec	[.count]
	jnz	.read_code
	lea	rsp, [rsp + sizeof .intern_item]
.read_code:
	lods	byte[rsi]
	cmp	al, PREFIX_SMALL_BLOCK
	jae	.small_block
	cmp	al, PREFIX_SMALL_INT
	jae	.small_int
	cmp	al, PREFIX_SMALL_STRING
	jae	.small_string
	cmp	al, CODE_BLOCK32
	jz	.code_block32
	cmp	al, CODE_STRING8
	jz	.code_string8
	cmp	al, CODE_DOUBLE_LITTLE
	jz	.code_double_little
	cmp	al, CODE_DOUBLE_ARRAY8_LITTLE
	jz	.code_double_array8_little
	cmp	al, CODE_INT8
	jz	.code_int8
	cmp	al, CODE_INT16
	jz	.code_int16
	cmp	al, CODE_INT32
	jz	.code_int32
	cmp	al, CODE_INT64
	jz	.code_int64
	cmp	al, CODE_SHARED8
	jz	.code_shared8
	cmp	al, CODE_SHARED16
	jz	.code_shared16
	cmp	al, CODE_CUSTOM
	jz	.code_custom

.unsupported_yet:
;	Пока поддержаны не все блоки данных.
	call	stdout_hex_byte
	puts	error_unsupported_data
	mov	edi, -EINVAL
	jmp	sys_exit

.small_int:
	and	eax, 0x3F
	jmp	.read_int_ok

.code_int8:
	movsx	rax, byte[rsi]
	inc	rsi
	jmp	.read_int_ok

.code_int16:
	lods	byte[rsi]
	shl	eax, 8
	lods	byte[rsi]
	movsx	rax, ax
	jmp	.read_int_ok

.code_int32:
	lods	dword[rsi]
	bswap	eax
	cdqe
	jmp	.read_int_ok

.code_int64:
	lods	qword[rsi]
	bswap	rax
	jmp	.read_int_ok

.code_shared8:
	zero	eax
	lods	byte[rsi]
.read_shared:
	neg	rax
	add	rax, obj_counter
	mov	rax, [intern_obj_table + rax * sizeof value]
	jmp	.read_item_ok
.code_shared16:
	lods	byte[rsi]
	shl	eax, 8
	lods	byte[rsi]
	movsx	rax, ax
	jmp	.read_shared

.small_block:
	mov	ecx, eax
	shr	ecx, 4
	and	ecx, 7		; размер
	and	eax, 0xF	; тег
.read_block:
	cmp	rcx, 0
	jz	.read_block_0
	lea	rsp, [rsp - sizeof .intern_item]
	mov	[.count], rcx
	mov	rdx, rcx
	to_wosize rdx
	cmp	eax, Object_tag	; al
	lea	rax, [rax + rdx]	; вместо OR, что бы сохранить флаги
	stos	Val_header[intern_dest]
	mov	[.dest], intern_dest
	jnz	.read_block_rest
;	Элементы объекта за исключением заголовка.
	sub	[.count], 2
;	CF = 1 или ZF = 1 -- нет элементов, копировать нечего
	jna	.read_block_2 
	add	[.dest], 2
;	Здесь следует запланировать OFreshOID
int3
;	Первые два элемента: таблица методов и OID
	lea	rsp, [rsp - sizeof .intern_item]
.read_block_2:
	mov	[.count], 2
	mov	[.dest], intern_dest
.read_block_rest:
	mov	rax, intern_dest
	lea	intern_dest, [intern_dest + sizeof value * rcx]
	jmp	.read_obj_ok
.read_block_0:
;	(((value) (((header_t *) (&(caml_atom_table [(tag)]))) + 1)))
	lea	rax, [caml_atom_table + (rax + 1) * sizeof value]
	jmp	.read_item_ok

.code_string8:
	movzx	rax, byte[rsi]
	inc	rsi
	jmp	.read_string
.small_string:
;	Длина строки
	and	eax, 1fh
.read_string:
	mov	ecx, eax
;	size = (len + sizeof(value)) / sizeof(value);
	add	eax, sizeof value
	and	eax, not (sizeof value - 1)
	mov	edx, eax
	sub	edx, 1
	sub	edx, ecx
;	shr	eax, sizeof_value_log2
;	to_wosize eax
	shl	rax, wosize_shift - sizeof_value_log2
	or	rax, String_tag
	stos	Val_header[intern_dest]
	push	intern_dest
rep	movs	byte[intern_dest], [rsi]
	mov	ecx, edx
	xor	eax, eax
rep	stos	byte[intern_dest]
;	Завершающий байт = размер блока в байтах - 1 - длина строки
	mov	eax, edx
	stos	byte[intern_dest]
	pop	rax
	jmp	.read_obj_ok

.code_double_little:
	mov	eax, 1 wosize or Double_tag
	stos	Val_header[intern_dest]
	mov	rax, intern_dest
	movs	qword[intern_dest], [rsi]
	jmp	.read_obj_ok

.code_double_array8_little:
	zero	eax
	lods	byte[rsi]
	mov	ecx, eax
	to_wosize rax
	or	eax, Double_array_tag
	stos	Val_header[intern_dest]
	mov	rax, intern_dest
rep	movs	qword[intern_dest], [rsi]
	jmp	.read_obj_ok

.code_block32:
	lods	dword[rsi]
	bswap	eax
	mov	ecx, eax
	shr	ecx, 10		; размер
	and	eax, 0xff	; тэг
	jmp	.read_block

.code_custom:
;	В блоке DATA пока встречаются типы:
;	'_j' (см. caml_int64_ops)
;	'_n' (см. caml_nativeint_ops)
;	Реализуем десериализацию непосредственно, без custom_operations.
	lods	word[rsi]
	inc	rsi
	cmp	ax, '_j'
	jz	._j
	cmp	ax, '_n'
	jz	._n
	cmp	ax, '_i'
	jz	._i
.uncb:	lea	rsi, [rsi - 3]
	puts	rsi
	puts	error_unsupported_custom_block
	mov	edi, -EINVAL
	jmp	sys_exit
._j:;	int64_deserialize()
	mov	rax, (1 + 1) wosize or Custom_tag
	stos	Val_header[intern_dest]
	push	intern_dest
	lea	rax, [caml_int64_ops]
	stos	qword[intern_dest]
._j8:	lods	qword[rsi]
	bswap	rax
	stos	qword[intern_dest]
	pop	rax
	jmp	.read_obj_ok
._n:;	nativeint_deserialize()
	mov	rax, (1 + 1) wosize or Custom_tag
	stos	Val_header[intern_dest]
	push	intern_dest
	lea	rax, [caml_nativeint_ops]
	stos	qword[intern_dest]
	lods	byte[rsi]
	dec	al
	jz	._i4
	dec	al
	jz	._j8
	dec	rsi
	jmp	.uncb
._i:;	int32_deserialize()
	mov	rax, (1 + 1) wosize or Custom_tag
	stos	Val_header[intern_dest]
	push	intern_dest
	lea	rax, [caml_nativeint_ops]
	stos	qword[intern_dest]
._i4:	lods	dword[rsi]
	bswap	eax
	cdqe
	stos	qword[intern_dest]
	pop	rax
	jmp	.read_obj_ok

restore	intern_dest
restore	dest
restore	obj_counter
restore	intern_obj_table
.read_items_finished:
;	Удаляем intern_obj_table
	pop	rax
	lea	rsp, [rsp + rax * sizeof value]
;	Инициализация необходимых для работы сборщика мусора переменных.
;	Текущее значение указателя стека используется как верхняя граница
;	при поиске ссылок (roots) на объекты в куче.
;	Объекты, расположенные до текущего значения alloc_small_ptr,
;	считаются статическими - не подлежат рассмотрению сборщиком мусора.
	heap_enable_gc

;	Подготавливаем виртуальную машину и переходим к первой инструкции
	mov	vm_pc, [.sect_code]
	
	interpreter_init
	Instruct_next
;	ud2

invalid_datasection_sig:
	puts	error_datasection_sig
	mov	edi, -EINVAL
	jmp	sys_exit

include 'primitives.asm'

; Данные только для чтения
;segment readable
section '.rodata'

;struct custom_operations {
;  char *identifier;
;  void (*finalize)(value v);
;  int (*compare)(value v1, value v2);
;  intnat (*hash)(value v);
;  void (*serialize)(value v,
;                    /*out*/ uintnat * bsize_32 /*size in bytes*/,
;                    /*out*/ uintnat * bsize_64 /*size in bytes*/);
;  uintnat (*deserialize)(void * dst);
;  int (*compare_ext)(value v1, value v2);
;};
channel_operations:
	.identifier	dq "_chan"	; в оригинале указатель на строку
	.finalize	dq 0 ;caml_finalize_channel
	.compare	dq 0 ;compare_channel,
	.hash		dq 0 ;hash_channel,
	.serialize	dq 0 ;custom_serialize_default,
	.deserialize	dq 0 ;custom_deserialize_default,
	.compare_ext	dq 0 ;custom_compare_ext_default

caml_nativeint_ops:
	.identifier	dq "_n"	; в оригинале указатель на строку
	.finalize	dq 0 ;custom_finalize_default
	.compare	dq 0 ;nativeint_cmp,
	.hash		dq 0 ;nativeint_hash,
	.serialize	dq 0 ;nativeint_serialize,
	.deserialize	dq 0 ;nativeint_deserialize,
	.compare_ext	dq 0 ;custom_compare_ext_default

caml_int64_ops:
	.identifier	dq "_j"	; в оригинале указатель на строку
	.finalize	dq 0 ;custom_finalize_default
	.compare	dq 0 ;int64_cmp,
	.hash		dq 0 ;int64_hash,
	.serialize	dq 0 ;int64_serialize,
	.deserialize	dq 0 ;int64_deserialize,
	.compare_ext	dq 0 ;custom_compare_ext_default

caml_int32_ops:
	.identifier	dq "_i"	; в оригинале указатель на строку
	.finalize	dq 0 ;custom_finalize_default
	.compare	dq 0 ;int32_cmp,
	.hash		dq 0 ;int32_hash,
	.serialize	dq 0 ;int32_serialize,
	.deserialize	dq 0 ;int32_deserialize,
	.compare_ext	dq 0 ;custom_compare_ext_default

; caml_builtin_cprim
include 'primitives.inc'

bytecode_sect_names	db sect_names

error_about db 'uCaml x64 v0.1', 10
	db 'Укажите имя файла в качестве аргумента.', 10, 0

error_bytecode_open	db 'Ошибка открытия файла', 10, 0
error_bytecode_map	db 'Ошибка чтения файла', 10, 0
error_bytecode_invalid	db ' Невалидный формат', 10, 0
error_bytecode_dlls	db 'Примитивы во внешних библиотеках пока не поддерживаются', 10, 0
error_datasection_sig	db 'Недействительная секция данных', 10, 0
error_unsupported_data	db ' Неподдерживаемый блок в секции DATA', 10, 0
error_unsupported_custom_block	db ' - неподдерживаемый пользовательский тип в секции DATA', 10, 0
error_sigsegv_nohandler	db 'Не установлен обработчик '
error_sigsegv_handler	db 'SIGSEGV', 10, 0


;segment readable writeable
section '.data' writeable align 4096

bytecode_filename	dq ?

oo_last_id	value	Val_int_0

; Глобальные данные из секции DATA
; value caml_global_data = 0;
caml_global_data	dq 0

; Связный список каналов для их сброса при завершении приложения.
caml_all_opened_channels	dq 0

; Описатель кучи.
heap_descriptor

;segment readable writeable
section '.bss' writeable ; align 4096

ch_stdin	channel
ch_stdout	channel
ch_srderr	channel

; Куча начинается здесь
heap_small__ends_bss
