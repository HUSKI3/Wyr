# Functions & ABI

## Function declaration

```text
fn return_type @name (type arg1, type arg2, ...)
```

Body ends with `}` (with `if`/`fi`/`esle` structure inside as needed). Parameters are
`type name`, comma-separated.

Example from [`examples/functions.wyr`](https://github.com/HUSKI3/Wyr/blob/main/examples/functions.wyr):

```wyr
fn void @askname () {
	promptbuf<<prompt
	.output promptbuf
	.input name
	.clear_buff promptbuf
}

fn i32 @answer () {
	.ret 42
}
```

## Calls

Statement or expression position:

```text
@name()
@name(arg1, arg2)
```

Using a call as an expression:

```wyr
scratch:i32 0
scratch = @answer()
```

## Calling convention (v1, Linux x86-64 SysV)

The first six integer/pointer arguments are passed in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`
(32-bit values in the low 32 bits of those registers). The callee preserves `rbp`/`rbx`/`r12`–`r15`
per ABI; the reference implementation uses a simple `push rbp` / `mov rbp, rsp` prologue.

## Syscall numbers

Syscall numbers used by the reference lowering are named in
[`src/wyr/linux_amd64_syscalls.v`](https://github.com/HUSKI3/Wyr/blob/main/src/wyr/linux_amd64_syscalls.v)
(`sys_read`, `sys_write`, …) so the builtin layer does not scatter magic immediates.

## Scoping reminder

Parameters and body locals may shadow globals for the duration of the function. Duplicate
parameter or local names within one function are rejected.

See [Lexical rules & types — Scoping](lexical-and-types.md#scoping-version-1).

## Related

- [Intrinsics](intrinsics.md) — `.ret` and IO builtins
- [IR specification — Functions](ir-spec.md#functions)
