include 'linux/signal.inc'

macro	gc_init
	virtual at rsp
	.ksa	kernel_sigaction
	end virtual
	mov	rdi, rsp
	mov	rax, sigsegv_handler
	stos	qword[rdi]
	mov	eax, SA_SIGINFO or SA_RESTORER
	stos	qword[rdi]
	mov	rax, __restore_rt
	stos	qword[rdi]
	zero	eax
	mov	ecx, _NSIG / 8
	mov	r10, rcx
rep	stos	qword[rdi]
	mov	edi, SIGSEGV
	mov	rsi, rsp
	zero	edx
	sys.rt_sigaction
	j_ok	.sigseg_handler_installed
	push	rax
	puts	error_sigsegv_nohandler
	pop	rdi
	jmp	sys_exit
.sigseg_handler_installed:
end macro


proc sigsegv_handler
	puts	error_sigsegv_handler
	pop	rdi
	jmp	sys_exit

; См.	glibc/sysdeps/unix/sysv/linux/x86_64/sigaction.c
; и (?)	uClibc/libc/sysdeps/linux/arc/sigaction.c
align_code 16
__restore_rt:
	sys.rt_sigreturn
end proc
