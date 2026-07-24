# Quickstart

The fastest way to try Wyr is to compile and run an example from the repo root.

## Hello, name

[`examples/name.wyr`](https://github.com/HUSKI3/Wyr/blob/main/examples/name.wyr) prompts for a
name and prints a greeting. From the repository root:

```bash
./build.sh examples/name.wyr
```

When prompted, type a name and press Enter.

### What `build.sh` does

The script (repo root):

1. Builds the compiler: `v -o wyr .`
2. Runs `./wyr -s examples/name.wyr` → writes `out.asm`
3. Assembles and links: `nasm -felf64 out.asm && ld out.o`
4. Runs `./a.out`

You can run the same steps manually if you prefer — see [Build & test](build-and-test.md).

## A peek at the source

```wyr
prompt:string "Name: "
promptbuf:buffer 16
name:buffer 16

promptbuf<<prompt
.output promptbuf
.input name

outbuf:buffer 255
msg:string "Hello "
outbuf<<msg
outbuf<<name
.output outbuf
```

Key ideas:

- `name:type value` declares a binding (string, buffer, integer).
- `buffer<<symbol` appends bytes from another string or buffer.
- `.output` and `.input` are [intrinsics](../language/intrinsics.md) for stdout/stdin.

## Version header

Many examples start with an optional first line:

```text
wyr 1
```

This declares IR version 1. If omitted, the compiler treats the file as v1 for backward compatibility. See [Overview](../language/overview.md).

## Next steps

- [Build & test](build-and-test.md) — manual compile flow and unit tests.
- [Examples walkthrough](../examples/index.md) — more samples with commentary.
- [Language overview](../language/overview.md) — module structure and entry point.
