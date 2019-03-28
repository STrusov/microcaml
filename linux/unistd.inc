; /usr/include/unistd.h

; Константы

STDIN_FILENO	:=	0	; Standard input.
STDOUT_FILENO	:=	1	; Standard output.
STDERR_FILENO	:=	2	; Standard error output.


; /usr/include/asm/stat.h
struct stat
	.st_dev		dq ?
	.st_ino		dq ?
	.st_nlink	dq ?

	.st_mode	dd ?
	.st_uid		dd ?
	.st_gid		dd ?
	.__pad0		dd ?

	.st_rdev	dq ?
	.st_size	dq ?
	.st_blksize	dq ?
	.st_blocks	dq ?

	.st_atime	dq ?
	.st_atime_nsec	dq ?
	.st_mtime	dq ?
	.st_mtime_nsec	dq ?
	.st_ctime	dq ?
	.st_ctime_nsec	dq ?
	.__unused	dq ?,?,?
end struct
