module wyr

pub fn default_builtin_syscalls() map[string][]string {
	return {
		'output':     [
			asm_mov_rax_syscall(sys_write) + '\tmov rdi, 1\n' + '\tsyscall\n',
		]
		'input':      [
			asm_mov_rax_syscall(sys_read) + '\tmov rdi, 0\n' + '\tsyscall\n' + '\tmov edi, eax\n' +
				'\tdec edi\n' + '\tadd rsi, rdi\n' + '\tmov byte [rsi], 0\n',
		]
		'clear_buff': []string{}
		'add':        []string{}
		'sub':        []string{}
	}
}
