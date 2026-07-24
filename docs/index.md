# The Wyr Book

**TWB** is the guide and reference for [Wyr](https://github.com/HUSKI3/Wyr) — a hobby
intermediate language (`.wyr` files) that the reference compiler lowers to NASM for
Linux x86-64.

Wyr source **is** the IR: a human-readable, line-oriented language designed to stay
small and close to the metal. If you want to learn NASM without writing every
syscall by hand, Wyr is a readable stepping stone.

## Why Wyr?

- **Simple** — declarations, assignments, `if`/`while`, functions, and a handful of intrinsics.
- **Clean** — one `.wyr` file maps to one assembly listing you can inspect.
- **Honest** — IR v1 is versioned (`wyr 1`) and documented normatively in this book.

Wyr is a hobby project and still evolving. See the [Roadmap](roadmap.md) for planned work.

## Start here

1. [Installation](getting-started/installation.md) — V, NASM, binutils, clone the repo.
2. [Quickstart](getting-started/quickstart.md) — compile and run your first example.
3. [Language overview](language/overview.md) — how a `.wyr` module is structured.

## Reference

- [Full IR specification (v1)](language/ir-spec.md) — normative prose for the language.
- [Formal grammar (EBNF)](language/grammar.md) — machine-readable subset.
- [Examples walkthrough](examples/index.md) — annotated samples from `examples/`.
- [Compiler CLI](tools/compiler-cli.md) and [wyr-inspect](tools/wyr-inspect.md).

## Building this book locally

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

Open the URL printed by MkDocs (usually `http://127.0.0.1:8000`).
