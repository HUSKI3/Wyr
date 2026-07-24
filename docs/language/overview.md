# Language overview

Wyr (`.wyr`) is the **intermediate representation**: a human-readable, line-oriented
language lowered to NASM by the reference compiler. This chapter introduces module
structure; the [full IR specification](ir-spec.md) is normative for IR version 1.

## What a module looks like

A `.wyr` file is a sequence of lines:

1. Optional version header (`wyr 1`)
2. Top-level declarations (`name:type value`)
3. Top-level statements (assignments, control flow, calls, intrinsics)
4. Function definitions (`fn … { … }`)

Execution begins at generated `_start`, which runs top-level statements then exits.

## Version header

The first non-comment, non-empty line may be:

```text
wyr 1
```

If present, the compiler checks the integer matches the supported revision. If absent,
the file is treated as `wyr 1` for backward compatibility.

Breaking IR changes bump the integer in `wyr N`. Tools should reject unknown major versions.

## Comments and lines

- Comments start with `//` and run to end of line.
- The compiler is **line-oriented**: each statement shape occupies one logical line
  (see [Formal grammar](grammar.md)).

## Top-level vs functions

| Region | Contents |
|--------|----------|
| **Global** | Declarations before `_start` lowering; duplicate top-level names are rejected |
| **Function** | Parameters plus body locals; may shadow globals for the duration of the function |

See [Lexical rules & types](lexical-and-types.md#scoping-version-1) for scoping rules.

## Language map

| Topic | Chapter |
|-------|---------|
| Comments, identifiers, types, initialization | [Lexical rules & types](lexical-and-types.md) |
| Declarations, assignment, expressions | [Declarations & expressions](declarations-and-expressions.md) |
| `if` / `while` | [Control flow](control-flow.md) |
| `fn`, `@call`, SysV ABI | [Functions & ABI](functions-and-abi.md) |
| `.output`, `.input`, `.ret`, … | [Intrinsics](intrinsics.md) |
| Complete normative spec | [IR specification (v1)](ir-spec.md) |
| EBNF subset | [Grammar](grammar.md) |

## Entry point

There is no explicit `main`. The compiler emits `_start`, runs module-level code in order,
then exits. Put your program logic in top-level statements and/or functions you call from there.
