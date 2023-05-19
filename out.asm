section .bss
	f_len equ 18
	f resb f_len
	fo_len equ 18
	fo resb fo_len
section .data
	msg: db "Inside"
	msg_len: equ $ - msg
	msgo: db "Outside"
	msgo_len: equ $ - msgo
	nl: db 10
	nl_len: equ $ - nl
	y: dd 2
	x: dd 2
	msgfinal: db "Cleaned"
	msgfinal_len: equ $ - msgfinal
section .text
	global _start
	_start:
	lea rsi, [msg]
	lea rdi, [f ]
	mov rcx, msg_len
	cld
	rep movsb
	lea rsi, [nl]
	lea rdi, [f  + msg_len]
	mov rcx, nl_len
	cld
	rep movsb
	lea rsi, [msgo]
	lea rdi, [fo ]
	mov rcx, msgo_len
	cld
	rep movsb
	lea rsi, [nl]
	lea rdi, [fo  + msgo_len]
	mov rcx, nl_len
	cld
	rep movsb
	mov rsi, fo
	mov rdx, fo_len
	mov rax, 1
	mov rdi, 1
	syscall
	mov eax, [y]
	cmp eax, [x]
	jne iftree_0_ne
	mov rsi, f
	mov rdx, f_len
	mov rax, 1
	mov rdi, 1
	syscall
iftree_0_ne:
	mov rsi, fo
	mov rdx, fo_len
	mov rax, 1
	mov rdi, 1
	syscall
	mov edi, f
	mov ecx, f_len
	xor al, al
	cld
	rep stosb
	syscall
	mov edi, fo
	mov ecx, fo_len
	xor al, al
	cld
	rep stosb
	syscall
	mov rsi, fo
	mov rdx, fo_len
	mov rax, 1
	mov rdi, 1
	syscall
	lea rsi, [msgfinal]
	lea rdi, [fo  + msgo_len + nl_len]
	mov rcx, msgfinal_len
	cld
	rep movsb
	lea rsi, [nl]
	lea rdi, [fo  + msgo_len + nl_len + msgfinal_len]
	mov rcx, nl_len
	cld
	rep movsb
	mov rsi, fo
	mov rdx, fo_len
	mov rax, 1
	mov rdi, 1
	syscall
done:
    mov rax, 60
    xor rdi, rdi
    syscall