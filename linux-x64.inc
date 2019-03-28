; fasmg/examples/x86/'
include 'x86/include/x64.inc'

; https://wiki.osdev.org/ELF
; https://ru.bmstu.wiki/ELF_(Executable_and_Linkable_Format)

; из fasmg/source/linux/selfhost.inc'

macro format?.ELF64? variant
	match , variant
		format binary as 'o'
		include 'format/elf64.inc'
		use64
	else match =executable? settings, variant:
		ELF.Settings.Class = ELFCLASS64
		ELF.Settings.Machine = EM_X86_64
		ELF.Settings.BaseAddress = 40000000h
		match brand =at? base:, settings
			ELF.Settings.ABI = brand
			ELF.Settings.BaseAddress = base
		else match =at? base:, settings
			ELF.Settings.BaseAddress = base
		else match brand:, settings
			ELF.Settings.ABI = brand
		end match
		include 'format/elfexe.inc'
		use64
	else
		err 'invalid argument'
	end match
end macro

include 'macros.inc'

include 'linux/syscall_x64.inc'

include 'linux/errno.inc'
include 'linux/fcntl.inc'
include 'linux/mman.inc'
include 'linux/unistd.inc'
