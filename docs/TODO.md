# Critical

> **Status legend:** `[x]` implemented in this tree · `[~]` partial / follow-up work remains.

* [x] Proper local variable scope inside functions — parameters and body locals shadow globals; bindings restored after each `fn`; duplicate names within one function are rejected.
* Arrays
* Array indexing (`arr[0]`)
* [x] Full expression support in conditions — `lhs` / `rhs` use the scalar expression grammar; full set `==`, `!=`, `<`, `>`, `<=`, `>=`. Boolean combinators (`&&`, `||`) still absent.
* Explicit block delimiters consistency
* [x] Defined initialization behavior — normative table and rules in `docs/IR.md` (**Initialization** section).
* Undefined behavior specification
* [x] IR validation rules — duplicate top-level `variable` names and duplicate `fn @name` (`validate.v`); typed IR validation for assignments/buffer bounds remains future work.
* Deterministic evaluation order
* Safer implicit conversion rules
* Explicit casts
* Boolean type (`bool`)
* Logical operators (`&&`, `||`, `!`)
* Safer buffer APIs with bounds checking
* Proper memory model
* Pointer types
* Structs / records
* Import/module system
* Separate compilation units
* [x] Formal grammar specification (EBNF) — see `docs/grammar.ebnf` (subset; kept in sync with IR v1 prose).

# Very Important

* Unsigned integer types (`u8`, `u16`, etc.)
* Floating point types (`f32`, `f64`)
* Operator assignment (`+=`, `-=`, etc.)
* Bitwise operators
* Shift operators
* `break` and `continue`
* `for` loops
* Function prototypes / forward declarations
* Explicit mutability modifiers
* String concatenation
* Mutable strings
* Dynamic buffers / resizing
* File IO
* Error handling model
* Assertions
* Panic/trap intrinsic
* [x] Syscall abstraction layer — Linux x86-64 syscall numbers are named constants (`linux_amd64_syscalls.v`); `.output` / `.input` lowering uses them. Portable multi-OS layer still out of scope.
* Standard library specification
* Documentation comment syntax
* UTF-8 string semantics
* Multiline strings
* Hex/binary integer literals
* Block comments
* Constant folding rules
* Compile-time evaluation
* Optimization hints
* Source map support
* Conformance test suite specification

# Important

* Enums
* Type aliases
* Slices / views into buffers
* Function overloading
* Default function arguments
* Inline functions
* Variadic functions
* Function pointers
* Return type inference
* Ternary operator
* Increment/decrement (`++`, `--`)
* `switch` / pattern matching
* Character type (`char`)
* Metadata/attributes/annotations
* Debug info directives
* IO formatting functions
* Random number generation
* Time/date intrinsics
* [x] Versioned feature flags — optional first line `wyr N` (`ir_header.v`); supported revision enforced against `default_ir_version`.
* Capability negotiation between compiler and IR
* Cleaner intrinsic syntax than leading `.`

# Nice to Have

* Anonymous functions / lambdas
* Reflection/introspection
* Package manager integration hooks
* Networking primitives
* Threading/concurrency primitives
* Atomic operations
* Coroutines/async support
* Garbage collection hooks or ownership model
* Calling convention selection
* Register constraints
* Inline assembly
* Explicit stack allocation
* Heap management model
* SSA-compatible form
* Labels and low-level jumps
* PHI-like merge semantics
* Macro/preprocessor system
* Readonly references
* Variable shadowing rules
