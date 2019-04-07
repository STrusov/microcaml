
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
assert Val_int_0 = 1
assert Val_int_1 = 3

; OCaml Value из целого
macro Val_int	reg
	lea	reg, [2*reg+1]
end macro


Atom equ caml_atom_table + sizeof value + sizeof value *

; целое из OCaml Value
macro Int_val	reg
	shr	reg, 1
end macro


;	Структура заголовка
;	+-----------------+------+-----+
;	| размер в словах | цвет | тэг |
;	+-----------------+------+-----+
; биты  63              10 9    8 7   0
;
; Указатель на блок равен адресу после заголовка, где и располагаются данные.

; 3 wosize ; преобразует размер к формату заголовка
wosize	equ shl 10
macro to_wosize reg
	shl	reg, 10
end macro

macro from_wosize reg
	shr	reg, 10
end macro

Caml_white	:= 0 shl 8
Caml_gray	:= 1 shl 8
Caml_blue	:= 2 shl 8
Caml_black	:= 3 shl 8


Closure_tag	:=	247
Object_tag	:=	248
Infix_tag	:=	249

String_tag	:=	252

Custom_tag	:=	255
