
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
; Указатели имеют нулевой младший бит.
; #define Val_long(x)     ((intnat) (((uintnat)(x) << 1)) + 1)
; lea	accu, [Val_int accu]
define Val_int	1 + 2 *
Val_int_0	:= Val_int 0
Val_int_1	:= Val_int 1
Val_unit	:= Val_int_0
Val_emptylist	:= Val_int_0
Val_false	:= Val_int 0
Val_true	:= Val_int 1
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

; Используется на стадии сканирования кучи для временной маркировки блоков
; CLOSURE, содержащих Infix_tag. Такие блоки сканируются на стадии сжатия кучи.
; В оригинальной реализации отсутствует.
; В ранних версиях был равен Infix_tag, однако блоки дожны различаться,
; в частности для избежания ложных вызовов heap_mark_compact_gc.infix_tag_from_stack
; и зацикливание в basic-more/pr2719.ml.
; Должен отличаться от Forward_tag, см. соотв. комментарий.
;!!! Нужно ли модифицировать тег, не проще ли сразу создавать блок с ним?
Closurerec_tag	:=	245	; 0xf5

Closure_tag	:=	247	; 0xf7
Object_tag	:=	248	; 0xf8
Infix_tag	:=	249	; 0xf9
; basic/patmatch.ml формирует объекты (caml_obj_set_tag) с тегом 250 (0xfa)
; где единственное поле равно 1.
;Forward_tag	:=	250	; 0xfa

; Тэги со значением равным и выше не содержат указателей и не подлежат сканированию.
No_scan_tag	:=	251	; 0xfb
;Abstract_tag	:=	251	; 0xfb

String_tag	:=	252	; 0xfc
Double_tag	:=	253	; 0xfd
Double_array_tag :=	254	; 0xfe
Custom_tag	:=	255	; 0xff
