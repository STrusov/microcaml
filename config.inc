; Конфигурация.

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
; Размер, на который увеличивается куча.
HEAP_INCREMENT := 1000h	; 4096


; Использовать ли для всех типов данных универсальную процедуру
; сравнения значений вместо специализированных.
GENERIC_COMPARE := 1
