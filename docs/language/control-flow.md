# Control flow

Wyr v1 provides `if`/`else` and `while` with comparison-based conditions.

## If / else

```text
if ( condition ) … fi
if ( condition ) … else … esle
```

- Opening keyword: `if ( condition )`
- Close the then-branch with `fi`
- Optional `else` branch closes with `esle` (note the spelling)

Example from [`examples/conditionals.wyr`](https://github.com/HUSKI3/Wyr/blob/main/examples/conditionals.wyr):

```wyr
y:i16 1
x:i16 1

if (y == x)
	f<<msg
fi
else
	f<<msge
esle
```

## While

```text
while ( condition ) { … }
```

The closing `}` ends the loop body.

Example from [`examples/while.wyr`](https://github.com/HUSKI3/Wyr/blob/main/examples/while.wyr):

```wyr
y:i16 0
against:i16 327

while (y < against) {
	f<<msg
	f<<nl
	.output f
	.add y,1
	.clear_buff f
}
```

## Conditions

A condition is `lhs op rhs` where:

| `op` | Meaning |
|------|---------|
| `==` `!=` | Equality / inequality |
| `<` `>` `<=` `>=` | Ordered comparison |

Each side is a numeric literal, identifier, or parenthesized scalar expression. Boolean
combinators (`&&`, `||`) are **not** in v1 — see the [Roadmap](../roadmap.md).

## Related

- [Declarations & expressions](declarations-and-expressions.md) — expression grammar for operands
- [IR specification — Control flow](ir-spec.md#control-flow)
