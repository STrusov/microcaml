; Конфигурация.

VERSION equ '0.2'

; Необходимы для прохождения тестов (basic-more/bounds).
ORIGINAL_MESSAGES	:= 1

; Использовать ли оригинальные сообщения об ошибках (на английском).
ORIGINAL_ERROR_MESSAGES := ORIGINAL_MESSAGES

; OCaml для формата a выводит infinity (см. caml_hexstring_of_float()).
ORIGINAL_INFINITY_MESSAGE := ORIGINAL_MESSAGES

; Отделяет целую часть числа от дробной.
DECIMAL_SEPARATOR := '.'

; Активен ли сборщик мусора
HEAP_GC := 1

; Минимальный начальный размер кучи (м.б. увеличен из-за выравнивания секций).
HEAP_INIT_SIZE := 2 * 1000h	; 4096
; Размер, на который по умолчанию увеличивается куча.
HEAP_INCREMENT := 1000h	; 4096
; Размер пространства после выделенной для кучи памяти,
; при обращении к адресам которого происходит автоматическое увеличение кучи.
; см. heap_sigsegv_handler.add_page: - выделяется дополнительно HEAP_INCREMENT.
HEAP_INCREMENT_GAP := 31 * HEAP_INCREMENT

; Использовать ли для всех типов данных универсальную процедуру
; сравнения значений вместо специализированных.
GENERIC_COMPARE := 1
