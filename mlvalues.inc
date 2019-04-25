
virtual at 0
label	value:qword
end virtual

struc value val
	.	dq val
end struc
sizeof_value_log2 := bsr 8	; sizeof qword

Val_header	equ qword

; Макросы преобразования именуются В_ИЗ
; Val_int означает "Value из Целого"
; Числа характеризуются единичным младшим битом, значащие биты сдвинуты влево.
; Указатели имеют нулевой младщий бит.
; #define Val_long(x)     ((intnat) (((uintnat)(x) << 1)) + 1)
; lea	accu, [Val_int accu]
define Val_int	1 + 2 *
Val_int_0	:= Val_int 0
Val_int_1	:= Val_int 1
Val_unit	:= Val_int_0
Val_emptylist	:= Val_int_0
Val_false	:= Val_int 0
assert Val_int_0 = 1
assert Val_int_1 = 3

; OCaml Value из целого
macro Val_int	reg
	lea	reg, [2*reg+1]
end macro


Atom equ caml_atom_table + sizeof value + sizeof value *

; целое из OCaml Value
macro Int_val	reg
	sar	reg, 1
end macro

; целое из OCaml Value
macro Long_val	reg
	sar	reg, 1
end macro

; беззнаковое целое из OCaml Value
macro Ulong_val	reg
	shr	reg, 1
end macro


;	Структура заголовка блока в оригинальном интерпретаторе:
;	+-----------------+------+-----+
;	| размер в словах | цвет | тэг |
;	+-----------------+------+-----+
; биты  63              10 9    8 7   0
;
;	Структура заголовка в данной имплементации:
;	+------+-----------------+-----+
;	|маркер| размер в словах | тэг |
;	+------+-----------------+-----+
; биты  63   40 39              8 7   0
;
; Маркер используется внутри сборщика мусора (на стадии маркировки).
;
; Указатель на блок равен адресу после заголовка, где и располагаются данные.

wosize_shift := 8

; 3 wosize ; преобразует размер к формату заголовка
wosize	equ shl wosize_shift
macro to_wosize reg
	shl	reg, wosize_shift
end macro

macro from_wosize reg
	shr	reg, wosize_shift
end macro

Max_wosize	:= 1 shl 32 - 1	; В оригинале 54. Умещаем в младшие 32 бита регистра.

Wosize_mask	:= 1 shl (bsr (Max_wosize+1) + wosize_shift) - 1


Pair_tag	:=	0

Closure_tag	:=	247
Object_tag	:=	248
Infix_tag	:=	249

; Тэги со значением равным и выше не содержат указателей и не подлежат сканированию.
No_scan_tag	:=	251

String_tag	:=	252

Custom_tag	:=	255
