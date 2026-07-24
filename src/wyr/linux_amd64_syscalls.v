module wyr

// Linux x86-64 syscall numbers (reference compiler targets this ABI only).
pub const sys_read  = i64(0)
pub const sys_write = i64(1)
pub const sys_exit  = i64(60)

pub fn asm_mov_rax_syscall(n i64) string {
	return '\tmov rax, ${n}\n'
}
