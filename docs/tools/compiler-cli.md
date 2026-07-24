# Compiler CLI

The `wyr` binary is the reference compiler. It reads a `.wyr` source file and writes NASM
assembly (default `out.asm`).

## Build the compiler

From the repository root:

```bash
v -o wyr .
```

`build.sh` runs this step automatically before compiling your source.

## Usage

```bash
./wyr -s path/to/file.wyr
./wyr --source path/to/file.wyr
```

| Flag | Short | Description |
|------|-------|-------------|
| `--source` | `-s` | Path to `.wyr` source (required) |
| `--debug` | `-d` | Enable compiler debug output |
| `--version` | | Print version (currently `0.0.13`) |
| `--help` | `-h` | Show help |

If `-s` is omitted, the compiler exits with *Source not provided*.

## Output

- **Assembly**: `out.asm` in the current working directory (flat NASM for Linux x86-64).
- Assemble and link separately:

```bash
nasm -felf64 out.asm && ld out.o
./a.out
```

Or use `./build.sh examples/name.wyr` for the full pipeline.

## Pipeline overview

```mermaid
flowchart LR
  WYR[".wyr source"] --> COMP["wyr -s file.wyr"]
  COMP --> ASM["out.asm"]
  ASM --> NASM["nasm -felf64"]
  NASM --> LD["ld out.o"]
  LD --> EXE["a.out"]
```

## Source layout

Implementation lives under `src/wyr/` (lexer, parser, IR validation, NASM backend) with
entry point `src/main.v`.

## Related

- [Build & test](../getting-started/build-and-test.md)
- [wyr-inspect](wyr-inspect.md) — debug with a TUI + GDB
