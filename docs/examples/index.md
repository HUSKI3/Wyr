# Examples walkthrough

The repository ships sample `.wyr` files under [`examples/`](https://github.com/HUSKI3/Wyr/tree/main/examples).
Run any of them with:

```bash
./build.sh examples/<name>.wyr
```

This page highlights what each example teaches — open the full file in the repo for complete source.

## Starter samples

### `name.wyr` — IO and buffers

Interactive hello-name program. Covers string/buffer declarations, `buffer<<`, `.output`, `.input`.

```wyr
prompt:string "Name: "
promptbuf:buffer 16
name:buffer 16

promptbuf<<prompt
.output promptbuf
.input name
```

### `buffers.wyr` — append chains

Builds output by appending strings and buffers into a shared scratch buffer before `.output`.

### `maths.wyr` — scalar expressions

Integer arithmetic with `+`, `-`, `*`, `/`, `%` in assignment expressions.

## Control flow

### `conditionals.wyr` — if / else

Demonstrates `if (…) … fi`, `else … esle`, and legacy `.add`:

```wyr
if (y == x)
	f<<msg
fi
else
	f<<msge
esle
```

### `while.wyr` — loops

Count-up loop with `while (y < against) { … }` and buffer output each iteration.

## Functions

### `functions.wyr` — calls and returns

Multiple `fn` definitions, `@call` statements, and using `@answer()` in an assignment:

```wyr
fn i32 @answer () {
	.ret 42
}

scratch:i32 0
scratch = @answer()
```

### `ret_and_call.wyr` — return values

Focuses on non-void returns and passing results through expressions.

## Advanced

### `advanced.wyr`

Larger sample combining `fn`, nested `@` calls, `while`, `%`, and condition checks. Good second
step after `name.wyr`.

### `scope_shadow.wyr`

Shows function-local names shadowing globals (see [Scoping](../language/lexical-and-types.md#scoping-version-1)).

### `game.wyr`

A longer program demonstrating how far v1 IR can be pushed in one module.

### `ir_showcase.wyr`

Comprehensive handwritten IR demo: sized ints, `const`, expressions in conditions, dynamic
buffer growth, six SysV arguments, modulo/division, and more. Read the header comment in the
file for v1 caveats and parser limitations.

```wyr
wyr 1
// ir_showcase.wyr — large handwritten IR demo (v1)
// Exercises: sized ints, const, fn + @calls in expressions, if/else, while, …
```

!!! tip
    `ir_showcase.wyr` is the best single file for seeing many v1 features together, but it
    also documents known sharp edges — read its top comment block before copying patterns.

## Map examples to language chapters

| Example | Topics |
|---------|--------|
| `name.wyr` | [Intrinsics](../language/intrinsics.md), buffers |
| `conditionals.wyr`, `while.wyr` | [Control flow](../language/control-flow.md) |
| `functions.wyr`, `ret_and_call.wyr` | [Functions & ABI](../language/functions-and-abi.md) |
| `maths.wyr` | [Expressions](../language/declarations-and-expressions.md) |
| `scope_shadow.wyr` | [Scoping](../language/lexical-and-types.md#scoping-version-1) |
| `ir_showcase.wyr` | Full v1 surface (see file header) |
