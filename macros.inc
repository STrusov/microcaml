; Часть макросов заимствована (с изменениями) из из fasmg/doc/manual.txt

; Многострочный комментарий
;	comment ~
;		Any text may follow here.
;	~
macro comment?! ender
	macro ?! line&
		if `line = `ender
			purge ?
		end if
	end macro
end macro


; Выводит текстовую строку и значение
macro display_num description, value
	repeat 1, d:value
		display description,`d
	end repeat
end macro

macro display_num_ln description, value
	display_num <description>, value
	display 13,10
end macro


; Выравнивает код, добавляя пустые команды.
macro align_code bytes
	assert bsr bytes = bsf bytes
	align bytes, 0x90
;	if $ mod bytes <> 0
;		repeat	bytes - $ mod bytes
;			nop
;		end repeat
;	end if
end macro


; Определение процедуры.
; Ассемблируется только в случае использования
macro proc? name
	name:
	if used name
end macro

macro end?.proc?!
	end if
	.end:
end macro


; Определяет аналоги С-структур
macro struct? definition&
	struc definition
		label . : .%top - .
		namespace .
end macro

macro end?.struct?!
			%top:
		end namespace
	end struc
end macro


; Генерирует исключение #UD (невалидный опкод)
macro ud2?
	db	0fh, 0bh
end macro


; Обнуляет регистр
macro zero? reg
	xor	reg, reg
end macro

