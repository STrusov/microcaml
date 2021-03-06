..C_PRIM_COUNT = 0
..C_PRIM_IMPLEMENTED = 0
..C_PRIM_UNIMPLEMENTED = 0
..C_PRIM_UNIMPLEMENTED_BYTES = 0


macro C_primitive name
name:
.C_primitive_name equ `name
..C_PRIM_COUNT = ..C_PRIM_COUNT + 1
end macro

macro end?.C_primitive!
	if $ = .
		puts	.msg
		mov	edx, -EINVAL
		jmp	sys_exit
	.msg	db	.C_primitive_name, 10, 0
		..C_PRIM_UNIMPLEMENTED = ..C_PRIM_UNIMPLEMENTED + 1
		..C_PRIM_UNIMPLEMENTED_BYTES = ..C_PRIM_UNIMPLEMENTED_BYTES + $ - .
	else
		..C_PRIM_IMPLEMENTED = ..C_PRIM_IMPLEMENTED + 1
	end if
end macro

macro C_primitive_stub
	display .C_primitive_name, ' stub ',10
end macro


C_primitive_first:

include 'fail.asm'

include 'alloc.asm'
include 'array.asm'
include 'str.asm'
include 'compare.asm'	; использует caml_string_length из str.asm
include 'ints.asm'
include 'floats.asm'
include 'obj.asm'
include 'sys.asm'
include 'io.asm'
include 'gc_ctrl.asm'


; RDI - требуемый размер стека (OCaml value)
; Нужно ли заранее отображать страницы стека?
C_primitive caml_ensure_stack_capacity
	ret
end C_primitive


; Обратные OCaml вызовы из C.

; CAMLprim value caml_register_named_value(value vname, value val)
C_primitive caml_register_named_value
C_primitive_stub
; Вызывается для "Pervasives.array_bound_error", "Pervasives.do_at_exit"
	mov	rax, Val_unit
	ret
end C_primitive


; Обработка сигналов.

C_primitive caml_install_signal_handler
end C_primitive


; Раскрутка стека при необработанных исключениях (backtrace_prim и backtrace).

C_primitive caml_add_debug_info
end C_primitive

C_primitive caml_remove_debug_info
end C_primitive

C_primitive caml_get_current_callstack
end C_primitive


C_primitive caml_record_backtrace
end C_primitive

C_primitive caml_backtrace_status
end C_primitive

C_primitive caml_get_exception_raw_backtrace
end C_primitive

C_primitive caml_convert_raw_backtrace_slot
end C_primitive

C_primitive caml_convert_raw_backtrace
end C_primitive

C_primitive caml_raw_backtrace_length
end C_primitive

C_primitive caml_raw_backtrace_slot
end C_primitive

C_primitive caml_raw_backtrace_next_slot
end C_primitive

C_primitive caml_get_exception_backtrace
end C_primitive


; Динамическое связывание.

C_primitive caml_dynlink_open_lib
end C_primitive

C_primitive caml_dynlink_close_lib
end C_primitive

C_primitive caml_dynlink_lookup_symbol
end C_primitive

C_primitive caml_dynlink_add_primitive
end C_primitive

C_primitive caml_dynlink_get_current_libs
end C_primitive


; Операции над эфемерами и слабыми массивами (weak arrays).

C_primitive caml_ephe_create
end C_primitive

caml_weak_create := caml_ephe_create

C_primitive caml_ephe_set_key
end C_primitive

C_primitive caml_ephe_unset_key
end C_primitive

C_primitive caml_weak_set
end C_primitive

C_primitive caml_ephe_set_data
end C_primitive

C_primitive caml_ephe_unset_data
end C_primitive

C_primitive caml_ephe_get_key
end C_primitive

caml_weak_get := caml_ephe_get_key

C_primitive caml_ephe_get_data
end C_primitive

C_primitive caml_ephe_get_key_copy
end C_primitive

caml_weak_get_copy := caml_ephe_get_key_copy

C_primitive caml_ephe_get_data_copy
end C_primitive

C_primitive caml_ephe_check_key
end C_primitive

caml_weak_check := caml_ephe_check_key

C_primitive caml_ephe_check_data
end C_primitive

C_primitive caml_ephe_blit_key
end C_primitive

C_primitive caml_ephe_blit_data
end C_primitive

caml_weak_blit := caml_ephe_blit_key


; Финализаторы

C_primitive caml_final_register
end C_primitive

C_primitive caml_final_register_called_without_value
end C_primitive

C_primitive caml_final_release
end C_primitive


; Обобщённое хеширование.

C_primitive caml_hash
end C_primitive

C_primitive caml_hash_univ_param
end C_primitive


; Структурированный ввод.

C_primitive caml_input_value
end C_primitive

C_primitive caml_input_value_to_outside_heap
end C_primitive

C_primitive caml_input_value_from_string
end C_primitive

C_primitive caml_marshal_data_size
end C_primitive


; Структурированный вывод.

C_primitive caml_output_value
end C_primitive

C_primitive caml_output_value_to_string
end C_primitive

C_primitive caml_output_value_to_buffer
end C_primitive


; Поддержка табличных анализаторов лексики (лексеров), сгенерированных camllex.

C_primitive caml_lex_engine
end C_primitive

C_primitive caml_new_lex_engine
end C_primitive


; Автоматизация для анализаторов синтаксиса (парсеров), сгенерированных camlyacc.

C_primitive caml_parse_engine
end C_primitive

C_primitive caml_set_parser_trace
end C_primitive


; Поддержка интерактивного интерпретатора.

C_primitive caml_get_global_data
end C_primitive

C_primitive caml_get_section_table
end C_primitive

C_primitive caml_reify_bytecode
end C_primitive

C_primitive caml_static_release_bytecode
end C_primitive

C_primitive caml_register_code_fragment
end C_primitive

C_primitive caml_realloc_global
end C_primitive

C_primitive caml_get_current_environment
end C_primitive

C_primitive caml_invoke_traced_function
end C_primitive


; Чтение и вывод команд терминала.

C_primitive caml_terminfo_setup
end C_primitive

C_primitive caml_terminfo_backup
end C_primitive

C_primitive caml_terminfo_standout
end C_primitive

C_primitive caml_terminfo_resume
end C_primitive


; MD5

C_primitive caml_md5_string
end C_primitive

C_primitive caml_md5_chan
end C_primitive


; Профилирование (не поддерживается для интерпретируемого байт-кода).

C_primitive caml_spacetime_only_works_for_native_code
end C_primitive

C_primitive caml_spacetime_enabled
end C_primitive

C_primitive caml_register_channel_for_spacetime
end C_primitive


display_num "Реализовано C-примитивов: ", ..C_PRIM_TOTAL - ..C_PRIM_UNIMPLEMENTED
display_num " (включая ", ..C_PRIM_TOTAL - ..C_PRIM_COUNT
display_num_ln " синонимов) из ", ..C_PRIM_TOTAL
display_num_ln "Занимают байт: ", $-C_primitive_first
display_num_ln "В том числе заглушки с именами нереализованных: ", ..C_PRIM_UNIMPLEMENTED_BYTES
