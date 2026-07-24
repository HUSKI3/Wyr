# Build & test

This page covers manual compilation and running the V unit test suite.

## Manual build pipeline

From the repository root:

```bash
# 1. Build the compiler
v -o wyr .

# 2. Compile a .wyr source to NASM
./wyr -s examples/name.wyr

# 3. Assemble and link (produces a.out)
nasm -felf64 out.asm && ld out.o

# 4. Run
./a.out
```

`build.sh` wraps steps 1–4 for a single source file:

```bash
./build.sh examples/name.wyr
```

If a future layout moves scripts under `scripts/`, the same flags apply — only the path to
`build.sh` changes.

## Compiler flags

| Flag | Meaning |
|------|---------|
| `-s`, `--source` | Path to the `.wyr` source file (required) |
| `-d`, `--debug` | Enable debug output from the compiler |
| `--version` | Print compiler version |

Full details: [Compiler CLI](../tools/compiler-cli.md).

## Inspect generated assembly

After `./wyr -s file.wyr`, open `out.asm` in your editor. The listing is flat NASM for
Linux x86-64 — useful for learning what the IR lowers to.

For a live side-by-side view while debugging, use [wyr-inspect](../tools/wyr-inspect.md).

## Unit tests

The reference compiler has V unit tests under `src/wyr/`:

```bash
./run_tests.sh
```

This runs `v -stats test src/wyr`. Failures print V test output; fix or report as an issue.

## Cleaning up artifacts

A typical build leaves:

| File | Role |
|------|------|
| `wyr` | Compiled compiler binary |
| `out.asm` | Generated NASM |
| `out.o` | Object file from NASM |
| `a.out` | Linked executable |

These are local build products — safe to delete when iterating.
