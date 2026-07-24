# Lexical rules & types

This chapter covers tokens, types, initialization, and scoping. Normative detail lives in
[IR specification — Lexical rules](ir-spec.md#lexical-rules) and following sections.

## Lexical rules

- **Comments**: `//` to end of line.
- **Whitespace**: spaces and tabs; lines are trimmed before classification.
- **Identifiers**: letters, digits, underscore; must not start with a digit.
- **String literals**: `"..."` (same escaping as today).
- **Integers**: decimal, optional leading `-` for numeric contexts.
- **Reserved punctuation**: `:`, `=`, `(`, `)`, `,`, `<<`, `.`, `@`, `fi`, `esle`, etc.

## Types

| Keyword | Meaning |
|---------|---------|
| `i8` `i16` `i32` `i64` | Fixed-width integers in memory |
| `int` | Deprecated alias; prefer sized integers |
| `string` | Immutable bytes + implicit `_len` symbol |
| `buffer` | Mutable byte region; size from initializer |
| `void` | Only as function return type |

### Buffer

Initializer is byte length (non-zero) or `0` for linker-defined length (see implementation).

### String

`name:string "text"` defines `name` and `name_len`.

## Initialization

Every **declaration** introduces a binding with the initializer on the same line:

| Form | Meaning |
|------|---------|
| `name:iN value` | Scalar integer: `value` is a decimal literal (or `const` suffix rules apply). Storage is emitted in `.data` (or `equ` when `const`). |
| `name:string "..."` | String: bytes of the literal; `name_len` is `equ $ - name`. |
| `name:buffer N` | `N > 0`: static size `N` bytes in `.bss`. `N == 0`: placeholder length symbol (implementation-defined linkage). |
| `fn …` parameters | Parameters are live for the whole function body; no default values. |

Reads of uninitialized scalars are not statically rejected in v1. **Buffers** appended with
`<<` grow logical content in the compiler's buffer model; reading uninitialized buffer bytes
is undefined in v1.

## Scoping (version 1)

- **Global** declarations live in the top-level list before `_start`.
- **Function** parameters and body `variable` lines share one name list for the duration of
  lowering that function. A body or parameter name **may shadow** a global or outer symbol with
  the same identifier; after the function is lowered, the outer binding is visible again for
  the rest of the module.
- Within a single function, **parameter names must be unique**, and a body `variable` line
  **must not** reuse a parameter name or another body local name (`Duplicate name in function`).
- `validate_module` rejects duplicate **top-level** `variable` declarations and duplicate
  **`fn @name`** definitions.

See also: [Declarations & expressions](declarations-and-expressions.md).
