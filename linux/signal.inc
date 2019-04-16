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
