# Wyr IR language specification (version 1)

Wyr (`.wyr`) is the **intermediate representation**: a human-readable, line-oriented IR lowered to NASM by the reference compiler. This document is normative for IR version 1.

## File header (optional)

The first non-comment, non-empty line may be:

```text
wyr 1
```

If present, the compiler checks the integer matches the supported revision. If absent, the file is treated as `wyr 1` for backward compatibility.

## Lexical rules

- **Comments**: `//` to end of line.
- **Whitespace**: spaces and tabs; lines are trimmed before classification.
- **Identifiers**: letters, digits, underscore; must not start with a digit.
- **String literals**: `"..."` (same escaping as today).
- **Integers**: decimal, optional leading `-` for numeric contexts.
- **Reserved punctuation**: `:`, `=`, `(`, `)`, `,`, `<<`, `.`, `@`, `fi`, `esle`, etc.

## Types

| Keyword  | Meaning |
|----------|---------|
| `i8` `i16` `i32` `i64` | Fixed-width integers in memory |
| `int`    | Deprecated alias; prefer sized integers |
| `string` | Immutable bytes + implicit `_len` symbol |
| `buffer` | Mutable byte region; size from initializer |
| `void`   | Only as function return type |

**Buffer**: initializer is byte length (non-zero) or `0` for linker-defined length (see implementation).

**String**: `name:string "text"` defines `name` and `name_len`.

## Initialization (normative)

Every **declaration** introduces a binding with the initializer on the same line:

| Form | Meaning |
|------|--------|
| `name:iN value` | Scalar integer: `value` is a decimal literal (or `const` suffix rules apply). Storage is emitted in `.data` (or `equ` when `const`). |
| `name:string "..."` | String: bytes of the literal; `name_len` is `equ $ - name`. |
| `name:buffer N` | `N > 0`: static size `N` bytes in `.bss`. `N == 0`: placeholder length symbol (implementation-defined linkage). |
| `fn …` parameters | Parameters are live for the whole function body; no default values. |

Reads of uninitialized scalars are not statically rejected in v1. **Buffers** appended with `<<` grow logical content in the compiler’s buffer model; reading uninitialized buffer bytes is undefined in v1.

## Scoping (version 1)

- **Global** declarations live in the top-level list before `_start`.
- **Function** parameters and body `variable` lines share one name list for the duration of lowering that function. A body or parameter name **may shadow** a global or outer symbol with the same identifier; after the function is lowered, the outer binding is visible again for the rest of the module.
- Within a single function, **parameter names must be unique**, and a body `variable` line **must not** reuse a parameter name or another body local name (`Duplicate name in function`).
- `validate_module` rejects duplicate **top-level** `variable` declarations and duplicate **`fn @name`** definitions.

## Declarations

```text
name:type initial_value
name:type initial_value const
```

With `const`, the binding is an assemble-time constant (`equ` for scalars) where supported.

## Assignment (scalar)

```text
name = expression
```

`name` must refer to an existing integer variable. `expression` uses the IR expression grammar (see below).

## Buffer append

```text
buffer<<source
```

`source` is a `string` or `buffer` symbol.

## Expressions (version 1)

Grammar (operator precedence, high to low):

1. Parentheses `( expr )`
2. Unary `-`
3. `*`, `/`, `%`
4. `+`, `-`
5. Leaves: integer literal, identifier (scalar int variable), or **call** `@name()` / `@name(expr, ...)` (same forms as a statement-level call; result is an `i32`-ish value in the lowered ABI)

Comparisons in conditions are **not** full boolean expressions: the condition inside `if`/`while` is `lhs op rhs` where `op` is one of `==`, `!=`, `<`, `>`, `<=`, `>=`, and `lhs`/`rhs` are either **numeric literals**, **identifiers**, or **parenthesized expressions** matching the scalar expression grammar above.

## Control flow

- **If**: `if ( condition )` … `fi` with optional `else` … `esle`.
- **While**: `while ( condition )` … `}` (closing brace ends body).
- **Condition**: as specified under expressions (comparison form).

## Functions

Declaration:

```text
fn return_type @name (type arg1, type arg2, ...)
```

Body ends with `}` (or `fi`/`esle` structure inside as today). Parameters are `type name` comma-separated.

Call:

```text
@name()
@name(arg1, arg2)
```

**Calling convention (version 1, Linux x86-64 SysV)**: the first six integer/pointer arguments are passed in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9` (32-bit values in the low 32 bits of those registers). The callee preserves `rbp`/`rbx`/`r12`–`r15` per ABI; the reference implementation uses a simple `push rbp` / `mov rbp, rsp` prologue.

**Syscall numbers** used by the reference lowering are named in `src/wyr/linux_amd64_syscalls.v` (`sys_read`, `sys_write`, …) so the builtin layer does not scatter magic immediates.

## Intrinsics (leading `.`)

| Intrinsic      | Form | Semantics |
|----------------|------|-----------|
| `.output`      | `.output buf` | Write buffer (syscall) |
| `.input`       | `.input buf`  | Read into buffer |
| `.clear_buff`  | `.clear_buff buf` | Zero buffer |
| `.add`         | `.add dst,src` | Add to 16-bit `ax` path (legacy) |
| `.sub`         | `.sub dst,src` | Subtract (legacy) |
| `.ret`         | `.ret` or `.ret expr` | Return from function; `expr` required if return type is not `void` |

## Entry

Execution starts at generated `_start`, which runs top-level statements then exits.

## Versioning

Breaking IR changes bump the integer in `wyr N`. Tools should reject unknown major versions.

## Formal grammar (EBNF)

A machine-readable subset is maintained in [grammar.ebnf](grammar.ebnf) alongside this prose spec.
