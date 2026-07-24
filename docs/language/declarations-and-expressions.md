# Declarations & expressions

## Declarations

```text
name:type initial_value
name:type initial_value const
```

With `const`, the binding is an assemble-time constant (`equ` for scalars) where supported.

Examples:

```wyr
ten:i32 10 const
msg:string "Hello "
promptbuf:buffer 16
x:i16 1
```

## Assignment (scalar)

```text
name = expression
```

`name` must refer to an existing integer variable. `expression` uses the IR expression grammar below.

```wyr
scratch:i32 0
scratch = @answer()
```

## Buffer append

```text
buffer<<source
```

`source` is a `string` or `buffer` symbol.

```wyr
outbuf:buffer 255
msg:string "Hello "
outbuf<<msg
outbuf<<name
```

## Expressions (version 1)

Grammar (operator precedence, high to low):

1. Parentheses `( expr )`
2. Unary `-`
3. `*`, `/`, `%`
4. `+`, `-`
5. Leaves: integer literal, identifier (scalar int variable), or **call** `@name()` /
   `@name(expr, ...)` (same forms as a statement-level call; result is an `i32`-ish value in
   the lowered ABI)

Comparisons in conditions are **not** full boolean expressions: the condition inside `if`/`while`
is `lhs op rhs` where `op` is one of `==`, `!=`, `<`, `>`, `<=`, `>=`, and `lhs`/`rhs` are either
**numeric literals**, **identifiers**, or **parenthesized expressions** matching the scalar
expression grammar above.

See [Control flow](control-flow.md) for condition usage.

## Related

- [Lexical rules & types](lexical-and-types.md) — type keywords and initialization table
- [Functions & ABI](functions-and-abi.md) — calls in expression position
- [IR specification](ir-spec.md) — normative prose
