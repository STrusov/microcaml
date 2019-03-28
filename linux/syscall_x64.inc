;
; Номера системных вызовов /usr/include/asm/unistd_64.h
;
; Параметры для ядра передаются в регистрах:
; RDI	1й
; RSI	2й
; RDX	3й
; R10	4й	; RCX в режиме пользователя
; R8	5й
; R9	6й
;
; MOV	EAX, номер_вектора
; SYSCALL
;
; Результат вызова в RAX
; Значения -4095 .. -1 означают ошибку (-errno).
;
; SYSCALL разрушает RCX (копирует RIP) и R11 (копирует RFLAGS).
; см. linux/arch/x86/entry/entry_64.S
;

MAX_ERRNO := 4095

macro j_ok reg_or_lbl, lbl
	match lbl,
		cmp	eax, -MAX_ERRNO
		jc	reg_or_lbl
	else
		cmp	reg_or_lbl, -MAX_ERRNO
		jc	lbl
	end match
end macro

macro j_err reg_or_lbl, lbl
	match lbl,
		cmp	eax, -MAX_ERRNO
		jnc	reg_or_lbl
	else
		cmp	reg_or_lbl, -MAX_ERRNO
		jnc	lbl
	end match
end macro


macro 	define_syscall	name, vector, num_arg
	macro	sys.#name
		mov	eax, vector
		syscall
	end macro
end macro

; В ядре Linux размер ряда параметров увеличен c int до unsigned long.

; ssize_t read(uint fd, const char *buf, size_t count);
define_syscall	read,	0,	3

; ssize_t write(uint fd, const char *buf, size_t count);
define_syscall	write,	1,	3

; int open(const char *pathname, int flags, umode_t mode);
define_syscall	open,	2,	3

; int close(uint fd);
define_syscall	close,	3,	1

; int fstat(uint fd, struct stat *statbuf);
define_syscall	fstat,	5,	2


; void *mmap(void *addr, size_t length, ulong prot, ulong flags, ulong fd, off_t offset);
define_syscall	mmap,	9,	6

; int mprotect(void *addr, size_t len, ulong prot);
define_syscall	mprotect, 10,	3

; int munmap(void *addr, size_t length);
define_syscall	munmap,	11,	2


; void exit(int status);
define_syscall 	exit,	60,	1

