; Процедуры (C примитивы) буферизированного ввода-вывода.


IO_BUFFER_SIZE	:= 4096 - 6 * 8 ; В оригинале 65536
struct channel
	.fd	dd ?	; Описатель файла
	.flags	dd ?	; Флаги (поле перемещено)
	.offset	dq ?	; Позиция в файле
	.end	dq ?	; Адрес старшей границы буфера
	.curr	dq ?	; Адрес текущей позиции буфера
	.max	dq ?	; Адрес границы буфера для чтения
;	.mutex	dq ?	; /* Placeholder for mutex (for systhreads) */
	.next	dq ?	; Односвязный (в оригинале 2-х) список каналов
;	.prev	dq ?	; для flush_all
;	.revealed	dd ?	; /* For Cash only */
;	.old_revealed	dd ?	; /* For Cash only */
;	.refcount	dd ?	; /* For flush_all and for Cash */
	.buff	rb IO_BUFFER_SIZE	; Тело буфера
;	.name	dq ?	; char* /* Optional name (to report fd leaks) */
end struct
assert 4096 = sizeof ch_stdin


; RDI - int fd
; Реализовано только для стандартных каналов, буфера выделены статически.
proc caml_open_descriptor_in
	cmp	edi, STDERR_FILENO
	jbe	.stdfile
int3
.stdfile:
	virtual at rax
	.channel	channel
	end virtual
	mov	.channel, rdi
	shl	.channel, bsr 4096
	lea	.channel, [ch_stdin + .channel]
	mov	[.channel.fd], edi
	and	[.channel.flags], 0
	and	[.channel.offset], 0	; lseek(fd, 0, SEEK_CUR)
	lea	rcx, [.channel.buff]
	mov	[.channel.curr], rcx
	mov	[.channel.max], rcx
	add	rcx, IO_BUFFER_SIZE
	mov	[.channel.end], rcx
	mov	rcx, [caml_all_opened_channels]
	mov	[.channel.next], rcx
	mov	[caml_all_opened_channels], .channel
	ret
virtual Data
	; Связный список каналов для их сброса при завершении приложения.
	caml_all_opened_channels	dq 0
end virtual
end proc


; RDI - int fd
proc caml_open_descriptor_out
	call	caml_open_descriptor_in
	virtual at rax
	.channel	channel
	end virtual
	mov	[.channel.max], 0
	ret
end proc


; RDI - описатель (дескриптор) файла
; RSI - флаги (не используются)
; RDX - начальный адрес буфера
; RCX - длина
;proc caml_write_fd

; RDI - описатель (дескриптор) файла.	Значение сохраняется.
; RSI - начальный адрес буфера. 	Значение сохраняется.
; RDX - длина
proc caml_write	;_fd_noflag
.again:	push	rdi rsi rdx
	sys.write
	pop	rdx rsi rdi
	j_err	.err
	ret
.err:	cmp	rax, -EINTR
	jz	.again
	cmp	rax, -EAGAIN
	jz	.eagain
	cmp	rax, -EWOULDBLOCK
	jz	.eagain
.fail:	mov	edi, NO_ARG
int3
;!!!	jmp	caml_sys_io_error
.eagain:cmp	rdx, 1
	jbe	.fail
	mov	rdx, 1
	jmp	.again
end proc


; RDI - channel. 	Значение сохраняется.
; Возвращает 1 если содержимое буфера успешно отправлено в файл.
proc caml_flush_partial
	virtual at rdi
	.channel	channel
	end virtual
	mov	rdx, [.channel.curr]	; 3й для caml_write
	lea	rsi, [.channel.buff]	; 2й для caml_write
	sub	rdx, rsi	; количество байт для записи
	jbe	.exit
;	push	rsi
	push	rdi rdx
	mov	edi, [.channel.fd]	; 1й для caml_write
	call	caml_write
	pop	rdx rdi
;	pop	rsi
	add	[.channel.offset], rax
	sub	[.channel.curr], rax
	sub	rdx, rax
;	jz	.exit
	mov	rcx, rdx
	push	rdi
	lea	rsi, [rdi + rax]
rep	movs	byte[rdi], [rsi]
	pop	rdi
.exit:	zero	eax
	sub	rsi, [.channel.curr]
	setz	al
	ret
end proc


; RDI - канал
; RSI - начальный адрес блока, отправляемого в канал.
; RDX - длина
; Возвращает количество отправленных байт.
; Поскольку размер буфера ограничен, может быть отправлена только часть блока.
proc caml_putblock
	virtual at rax
	.channel	channel
	end virtual
	mov	rax, rdi
	mov	rcx, [.channel.end]
	mov	rdi, [.channel.curr]
	sub	rcx, rdi
	cmp	rdx, rcx
	jae	.over
;	Места в буфере канала достаточно, копируем блок.
	mov	rcx, rdx
rep	movs	byte[rdi], [rsi]
	mov	[.channel.curr], rdi
	mov	rax, rdx
	ret
.over:;	Сохраняем в буфер сколько поместится.
	push	rcx
rep	movs	byte[rdi], [rsi]
	lea	rsi, [.channel.buff]
	mov	rdx, [.channel.end]
	sub	rdx, rsi	; длинна
	push	rsi rdx rax	; rax - channel
	mov	edi, [.channel.fd]
	call	caml_write
	pop	rdx rcx	rdi	; теперь rdx = channel, rcx = длинна, а rdi = буфер
	cmp	rax, rcx
	je	.all_written
;	Перемещаем остаток в начало буфера.
	sub	rcx, rax
	lea	rsi, [rdi + rax]
rep	movs	byte[rdi], [rsi]
.all_written:
	virtual at rdx
	.chan	channel
	end virtual
	add	[.chan.offset], rax
	neg	rax
	add	rax, [.chan.end]
	mov	[.chan.curr], rax
	pop	rax
	ret
end proc


struct channel_operations_object
	.tag		dq ?
	.operations	dq ?
	.channel	dq ?
end struct


; RDI - fd Value
; Возвращает адрес объекта
C_primitive caml_ml_open_descriptor_in
C_primitive_stub
;  return caml_alloc_channel(caml_open_descriptor_in(Int_val(fd)));
	Int_val	edi
	call	caml_open_descriptor_in
end C_primitive
; продолжает выполнение.

; RAX - адрес канала
; Возвращает объект виртуального канала.
caml_alloc_channel:
;	Для сборщика мусора требуется:
;	chan->refcount++;             /* prevent finalization during next alloc */
;	add_to_custom_table (&caml_custom_table, result, mem, max);
	virtual at alloc_small_ptr_backup
	.co	channel_operations_object
	end virtual
;	Длина без учёта заголовка (tag)
	mov	[.co.tag], 2 wosize or Custom_tag
	mov	[.co.operations], channel_operations
	mov	[.co.channel], rax
	lea	rax, [alloc_small_ptr_backup + sizeof value]
	lea	alloc_small_ptr_backup, [alloc_small_ptr_backup + sizeof .co]
	ret


; RDI - fd Value
C_primitive caml_ml_open_descriptor_out
C_primitive_stub
	Int_val	edi
	call	caml_open_descriptor_out
	jmp	caml_alloc_channel
end C_primitive


C_primitive caml_ml_set_channel_name
end C_primitive


C_primitive caml_ml_out_channels_list
	mov	edx, Val_emptylist
	virtual at rdi
	.channel	channel
	end virtual
	mov	.channel, [caml_all_opened_channels]
.ch:	test	.channel, .channel
	jz	.exit
	cmp	[.channel.max], 0
	jnz	.next
	mov	rax, .channel
;	Запоминаем ссылку на блок списка на случай сборки мусора.
	push	rdx
	call	caml_alloc_channel
;	Запоминаем ссылку на блок канала на случай сборки мусора.
	push	rax
	mov	Val_header[alloc_small_ptr_backup], 2 wosize or Pair_tag
;	Форсируем аллокацию.
	test	[alloc_small_ptr_backup + (1 + 1) * sizeof value], rax
;	В случае уплотнения кучи значения скорректированы.
	pop	rax
	pop	rdx
	mov	[alloc_small_ptr_backup + (1 + 1) * sizeof value], rdx ; хвост
	lea	rdx, [alloc_small_ptr_backup + (1 + 0) * sizeof value]
	mov	[rdx], rax ; канал
	lea	alloc_small_ptr_backup, [3 * sizeof value + alloc_small_ptr_backup]
.next:	mov	.channel, [.channel.next]
	jmp	.ch
.exit:	mov	rax, rdx
	retn
end C_primitive


C_primitive caml_channel_descriptor
end C_primitive


C_primitive caml_ml_close_channel
end C_primitive


C_primitive caml_ml_channel_size
end C_primitive


C_primitive caml_ml_channel_size_64
end C_primitive


C_primitive caml_ml_set_binary_mode
end C_primitive


C_primitive caml_ml_flush_partial
end C_primitive


; RDI - виртуальный канал
C_primitive caml_ml_flush
;	В оригинале обеспечен эксклюзивный доступ
	virtual at rdi - sizeof value
	.co	channel_operations_object
	end virtual
	mov	rdi, [.co.channel]
	virtual at rdi
	.channel	channel
	end virtual
	cmp	[.channel.fd], -1
	jz	.exit
.again:	call	caml_flush_partial
	test	eax, eax
	jz	.again
.exit:	mov	eax, Val_unit
	ret
end C_primitive


; RDI - виртуальный канал
; RSI - символ
C_primitive caml_ml_output_char
	virtual at rdi - sizeof value
	.co	channel_operations_object
	end virtual
	mov	rdi, [.co.channel]
	virtual at rdi
	.channel	channel
	end virtual
	Ulong_val esi
	mov	rax, [.channel.curr]
	cmp	rax, [.channel.end]
	jc	.putch
;	push	.channel
	push	rsi
	call	caml_flush_partial
	pop	rsi
;	pop	.channel
.putch:	mov	rax, [.channel.curr]
	mov	byte[rax], sil
	inc	 [.channel.curr]
	mov	eax, Val_unit
	ret
end C_primitive


C_primitive caml_ml_output_int
end C_primitive


C_primitive caml_ml_output_partial
end C_primitive


; RDI - виртуальный канал
; RSI - буфер
; RDX - смещение от начала в буфера
; RCX - длина
C_primitive caml_ml_output_bytes
C_primitive_stub
	virtual at rdi - sizeof value
	.co	channel_operations_object
	end virtual
	mov	rdi, [.co.channel]
	Ulong_val rdx
	lea	rsi, [rsi + rdx]
	Ulong_val rcx
	jecxz	.exit
	mov	rdx, rcx
.again:	push	rdi rsi rdx
	call	caml_putblock
	pop	rdx rsi rdi
	add	rsi, rax
	sub	rdx, rax
	ja	.again
.exit:	mov	eax, Val_unit
	ret
end C_primitive


caml_ml_output := caml_ml_output_bytes


C_primitive caml_ml_seek_out
end C_primitive


C_primitive caml_ml_seek_out_64
end C_primitive


C_primitive caml_ml_pos_out
end C_primitive


C_primitive caml_ml_pos_out_64
end C_primitive


C_primitive caml_ml_input_char
end C_primitive


C_primitive caml_ml_input_int
end C_primitive


C_primitive caml_ml_input
end C_primitive


C_primitive caml_ml_seek_in
end C_primitive


C_primitive caml_ml_seek_in_64
end C_primitive


C_primitive caml_ml_pos_in
end C_primitive


C_primitive caml_ml_pos_in_64
end C_primitive


C_primitive caml_ml_input_scan_line
end C_primitive
