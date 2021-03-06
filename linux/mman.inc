; /usr/include/asm-generic/mman-common.h 

; POSIX
PROT_READ	:=	0x1	; страницы доступны для чтения
PROT_WRITE	:=	0x2	; страницы доступны для записи
PROT_EXEC	:=	0x4	; страницы доступны для выполнения
PROT_NONE	:=	0x0	; доступ запрещён

;PROT_SEM	:=	0x8	; страницы пригодны для атомарных операций
PROT_GROWSDOWN	:=	0x01000000	; распространить режим защиты вверх
PROT_GROWSUP	:=	0x02000000	; распространить режим защиты вниз

; POSIX
MAP_SHARED	:=	0x01	; страница разделяется между процессами
MAP_PRIVATE     :=	0x02	; изменения не переносятся в отображённый файл
MAP_FIXED	:=	0x10	; отобразить по заданному адресу

MAP_TYPE	:=	0x0f	; маска для режима отображения

MAP_ANONYMOUS	:=	0x20	; fd = -1, файл не используется
MAP_UNINITIALIZED	:=	0x4000000	; не инициализировать анонимные отображения

; /usr/include/asm-generic/mman.h 

MAP_GROWSDOWN	:=	0x0100	; создаёт стек и сторожевую страницу
;MAP_DENYWRITE	:=	0x0800
MAP_EXECUTABLE	:=	0x1000	; игнорируется
MAP_LOCKED	:=	0x2000	; страницы невыгружаемы
MAP_NORESERVE	:=	0x4000	; не проверять достаточный запас в подкачке
MAP_POPULATE	:=	0x8000	; опереждающее чтений из файла
MAP_NONBLOCK	:=	0x10000	; не ожидает заверщения чтения при MAP_NONBLOCK (отменяя)
MAP_STACK	:=	0x20000	; подбирает наиболее пригодный для организации стека адрес
MAP_HUGETLB	:=	0x40000	; отображает большие страницы
