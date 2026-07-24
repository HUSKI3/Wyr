# Installation

Wyr is compiled by a reference implementation written in [V](https://vlang.io/).
You also need NASM and a linker to turn generated assembly into a runnable binary.

## Prerequisites

### V

Install V on Linux (adjust for your platform — see the [V docs](https://github.com/vlang/v/blob/master/doc/install.md)):

```bash
wget https://github.com/vlang/v/releases/latest/download/v_linux.zip
unzip v_linux.zip
cd v
sudo ./v symlink
```

Verify:

```bash
v version
```

### NASM and binutils

On Debian/Ubuntu:

```bash
sudo apt install nasm binutils
```

You need `nasm` to assemble `out.asm` and `ld` (from binutils) to link the object file.

## Clone Wyr

```bash
git clone https://github.com/HUSKI3/Wyr.git
cd Wyr
```

No separate install step — the compiler is built on demand by `build.sh` or manually with `v -o wyr .`.

## Optional: wyr-inspect

The interactive debugger UI is built by `inspect.sh`:

```bash
./inspect.sh --help
```

See [wyr-inspect](../tools/wyr-inspect.md) for usage.

## Next

[Quickstart](quickstart.md) — compile and run an example.
