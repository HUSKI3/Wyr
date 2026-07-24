# wyr-inspect

`wyr-inspect` is an interactive terminal UI for stepping through a compiled Wyr program under
GDB. It shows Wyr source beside generated NASM and tracks the current assembly line.

## Build & run

From the repository root:

```bash
./inspect.sh path/to/file.wyr
```

The script builds the inspector (`v -o wyr-inspect src/inspect`) and execs it with your arguments.

## What it does

1. Compiles the given `.wyr` with the reference compiler
2. Assembles and links a debug-friendly binary
3. Launches GDB in MI mode
4. Presents a split-pane TUI: Wyr source (left), NASM listing (right), registers/status footer

Useful when learning what IR lines map to which instructions, or when debugging lowering bugs.

## Requirements

Same toolchain as the main compiler:

- V
- NASM and `ld`
- GDB (for the debugging session)

## Related

- [Compiler CLI](compiler-cli.md) — generate `out.asm` manually
- [Build & test](../getting-started/build-and-test.md)
