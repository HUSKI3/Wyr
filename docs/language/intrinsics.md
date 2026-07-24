# Intrinsics

Intrinsics are built-in operations spelled with a leading `.` (dot).

| Intrinsic | Form | Semantics |
|-----------|------|-----------|
| `.output` | `.output buf` | Write buffer (syscall) |
| `.input` | `.input buf` | Read into buffer |
| `.clear_buff` | `.clear_buff buf` | Zero buffer |
| `.add` | `.add dst,src` | Add to 16-bit `ax` path (legacy) |
| `.sub` | `.sub dst,src` | Subtract (legacy) |
| `.ret` | `.ret` or `.ret expr` | Return from function; `expr` required if return type is not `void` |

## IO example

From [`examples/name.wyr`](https://github.com/HUSKI3/Wyr/blob/main/examples/name.wyr):

```wyr
promptbuf<<prompt
.output promptbuf
.input name
```

## Return example

```wyr
fn i32 @answer () {
	.ret 42
}
```

## Legacy arithmetic

`.add` and `.sub` operate on the 16-bit `ax` path and appear in older examples such as
[`examples/conditionals.wyr`](https://github.com/HUSKI3/Wyr/blob/main/examples/conditionals.wyr):

```wyr
.add y,1
```

Prefer scalar assignment with expression grammar where possible for new code.

## Related

- [Functions & ABI](functions-and-abi.md) — where `.ret` is used
- [IR specification — Intrinsics](ir-spec.md#intrinsics-leading)
