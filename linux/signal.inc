; /usr/include/asm-generic/signal.h

_NSIG		:=	64

SIGHUP		:=	1
SIGINT		:=	2
SIGQUIT		:=	3
SIGILL		:=	4
SIGTRAP		:=	5
SIGABRT		:=	6
SIGIOT		:=	6
SIGBUS		:=	7
SIGFPE		:=	8
SIGKILL		:=	9
SIGUSR1		:=	10
SIGSEGV		:=	11
SIGUSR2		:=	12
SIGPIPE		:=	13
SIGALRM		:=	14
SIGTERM		:=	15
SIGSTKFLT	:=	16
SIGCHLD		:=	17
SIGCONT		:=	18
SIGSTOP		:=	19
SIGTSTP		:=	20
SIGTTIN		:=	21
SIGTTOU		:=	22
SIGURG		:=	23
SIGXCPU		:=	24
SIGXFSZ		:=	25
SIGVTALRM	:=	26
SIGPROF		:=	27
SIGWINCH	:=	28
SIGIO		:=	29
SIGPOLL		:=	SIGIO

SIGLOST		:=	29

SIGPWR		:=	30
SIGSYS		:=	31
SIGUNUSED	:=	31

SIGRTMIN	:=	32
SIGRTMAX	:=	_NSIG

SA_NOCLDSTOP	:= 0x00000001	; Отключить SIGCHLD при остановвке наследников.
SA_NOCLDWAIT	:= 0x00000002	; Подавлять 'зомби' 
SA_SIGINFO	:= 0x00000004	; sa_sigaction вместо sa_handler 
SA_ONSTACK	:= 0x08000000	; Используется зарегистрированный стек stack_t.
SA_RESTART	:= 0x10000000	; 
SA_NODEFER	:= 0x40000000	; В обработчике сигнал не маскируется.
SA_RESETHAND	:= 0x80000000	; Обработчик отключается после доставки сигнала.

SA_NOMASK	:=	SA_NODEFER
SA_ONESHOT	:=	SA_RESETHAND

SA_RESTORER	:= 0x4000000


struct kernel_sigaction
	.sa_handler	dq ?	; или .sa_sigaction
	.sa_flags	dq ?
	.sa_restorer	dq ?
	.sa_mask	rq _NSIG / 8
end struct


; Коды (.si_code) SIGSEGV
SEGV_MAPERR	:= 1	; Память по адресу не отображена
SEGV_ACCERR	:= 2	; Нет прав для доутупа к памяти
SEGV_BNDERR	:= 3
SEGV_PKUERR	:= 4
NSIGSEGV	:= 4

; siginfo для SIGILL, SIGFPE, SIGSEGV, SIGBUS
struct siginfo_sigfault
	.si_signo	dd ?	; № сигнала
	.si_errno	dd ?	;
	.si_code	dd ?, ?	; Код сигнала (см. выше)
	.si_addr	dq ?	; Исключение (fault) при обращении к этому адресу.
;	.si_addr_lsb	dw ?
;	.si_lower	dq ?
;	.si_upper	dq ?
end struct


struct sigaltstack
	.ss_sp		dq ?
	.ss_flags	dd ?, ?	;
	.ss_size	dq ?	;
end struct	; stack_t


struct sigcontext
	.r8	dq ?
	.r9	dq ?
	.r10	dq ?
	.r11	dq ?
	.r12	dq ?
	.r13	dq ?
	.r14	dq ?
	.r15	dq ?
	.rdi	dq ?
	.rsi	dq ?
	.rbp	dq ?
	.rbx	dq ?
	.rdx	dq ?
	.rax	dq ?
	.rcx	dq ?
	.rsp	dq ?
	.rip	dq ?
	.eflags	dq ?
	.cs	dw ?
	.gs	dw ?
	.fs	dw ?
	.ss	dw ?
	.err	dq ?
	.trapno	dq ?
	.oldmask	dq ?
	.cr2		dq ?
	.fpstate	dq ?	; Адрес struct _fpstate или 0
	.reserved1	rb 8
end struct


struct ucontext
	.uc_flags	dq ?
	.uc_link	dq ?	; struct ucontext  *
	.uc_stack	sigaltstack	; Альтернативный стек, если определён.
	.uc_mcontext	sigcontext
	.uc_sigmask	dq ?
end struct
