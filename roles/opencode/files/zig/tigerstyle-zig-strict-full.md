# TigerStyle Rulebook — Zig / Strict / Full

## Preamble

### Purpose

This document is a comprehensive Zig coding rulebook derived from TigerBeetle's TigerStyle. It is
intended to be dropped into any Zig codebase as part of an `AGENTS.md` file, a system prompt, or a
code review checklist. Every rule is actionable and enforceable.

This is the **Zig-specific** variant. Rule IDs match the language-agnostic TigerStyle rulebook for
cross-referencing. Where Zig idioms differ from the language-agnostic version, the adaptation is
noted.

### Design Goal Priority

All rules serve three design goals, in this order:

1. **Safety** — correctness, bounded behavior, crash on corruption.
2. **Performance** — mechanical sympathy, batching, resource awareness.
3. **Developer Experience** — clarity, naming, readability, maintainability.

When goals conflict, higher-priority goals win.

### Keyword Definitions (RFC 2119)

- **MUST / SHALL** — Absolute requirement. Violations are defects.
- **MUST NOT / SHALL NOT** — Absolute prohibition. Violations are defects.
- **REQUIRED** — Equivalent to MUST.

Non-compliance with any MUST/SHALL rule is a blocking review finding unless the rule is explicitly
marked as not applicable to the project in a project-level override document.

### Zig Baseline and Tooling

- Target: **latest stable Zig**.
- Formatter: `zig fmt` (mandatory).
- Build/test: `zig build test` (mandatory).
- Runtime safety MUST NOT be disabled except in audited hot paths with documented invariants.

### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: an imperative statement, a rationale, and a Zig example or template.
- Rules marked **(Zig-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Do not use recursion.

All control flow MUST be simple, explicit, and statically analyzable. Recursion MUST NOT be used.
This ensures all executions that should be bounded are bounded.

Rationale: Predictable, bounded execution is the foundation of safety. Recursion makes it difficult
to prove termination and risks stack overflow.

```zig
for (0..max_iterations) |index| {
    process(items[index]);
}

// Do not
fn process(items: []Item) void {
    if (items.len == 0) return;
    process(items[1..]); // VIOLATION
}
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work MUST have a fixed
upper bound. Where a loop cannot terminate (e.g., an event loop), this MUST be asserted.

Rationale: Unbounded work causes infinite loops, tail-latency spikes, and resource exhaustion.

```zig
const max_retries: u32 = 5;

var attempt: u32 = 0;
while (attempt < max_retries) : (attempt += 1) {
    if (tryConnect()) break;
}
std.debug.assert(attempt < max_retries);
```

### SAF-03 — Use explicitly-sized integer types.

All integer types MUST be explicitly sized (`u32`, `i64`, etc.). Architecture-dependent `usize`
MUST NOT be used unless required for indexing or API compatibility.

Rationale: Implicit sizing creates architecture-specific behavior and makes overflow analysis
impossible without knowing the target.

```zig
const count: u32 = 0;
const offset: i64 = 0;
```

### SAF-04 — Assert all preconditions, postconditions, and invariants.

Every function MUST assert its preconditions (valid arguments), postconditions (valid return values),
and any invariants that must hold during execution. A function MUST NOT operate blindly on unchecked
data.

Rationale: Assertions detect programmer errors. The only correct response to corrupt code is to
crash. Assertions downgrade catastrophic correctness bugs into liveness bugs.

```zig
fn transfer(from: *Account, to: *Account, amount: i64) void {
    std.debug.assert(from.id != to.id);
    std.debug.assert(amount > 0);
    std.debug.assert(from.balance >= amount);

    from.balance -= amount;
    to.balance += amount;

    std.debug.assert(from.balance >= 0);
    std.debug.assert(to.balance > 0);
}
```

### SAF-05 — Maintain assertion density of at least 2 per function.

The assertion density of the codebase MUST average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs through testing and
fuzzing. Low assertion density leaves large regions of state space unchecked.

### SAF-06 — Pair assertions across different code paths.

For every property to enforce, there MUST be at least two assertions on different code paths that
verify the property.

Rationale: Bugs hide at the boundary between valid and invalid data.

### SAF-07 — Split compound assertions.

Compound assertions MUST be split into individual assertions. Prefer `assert(a); assert(b);` over
`assert(a and b)`.

Rationale: Split assertions are simpler to read and provide precise failure information.

### SAF-08 — Use single-line implication assertions.

When a property B must hold whenever condition A is true, this MUST be expressed as a single-line
implication: `if (a) assert(b)`.

Rationale: Preserves logical intent without introducing complex boolean expressions.

### SAF-09 — Assert compile-time constants and type sizes. **(Zig-adapted)**

Relationships between compile-time constants, type sizes, and configuration values MUST be asserted
at compile time (or at startup if not possible).

Rationale: Compile-time assertions verify design integrity before the program executes.

```zig
const page_size: usize = 4096;
const block_size: usize = 16384;

comptime {
    if (block_size % page_size != 0) {
        @compileError("block must align to page size");
    }
}
```

### SAF-10 — Assert both positive and negative space.

Assertions MUST cover both the positive space (what is expected) AND the negative space (what is not
expected). Where data moves across the valid/invalid boundary, both sides MUST be asserted.

Rationale: Most interesting bugs occur at the boundary between valid and invalid states.

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests MUST exercise valid inputs, invalid inputs, and the transitions between valid and invalid
states. Tests MUST NOT only cover the happy path.

Rationale: Most catastrophic failures stem from incorrect handling of non-fatal errors.

### SAF-12 — Allocate at initialization. Avoid runtime reallocation.

All memory MUST be statically allocated at initialization. No memory SHALL be dynamically allocated
or freed and reallocated after initialization.

Rationale: Dynamic allocation introduces unpredictable latency and fragmentation.

```zig
var buffer: [max_buffer_size]u8 = undefined; // allocated at init
```

### SAF-13 — Declare variables at the smallest possible scope.

Variables MUST be declared at the smallest possible scope and the number of variables in any given
scope MUST be minimized.

Rationale: Fewer variables in scope reduces the probability of misuse.

### SAF-14 — Hard limit function length to 70 lines.

No function SHALL exceed 70 lines. This is a hard limit, not a guideline.

Rationale: There is a sharp cognitive discontinuity between a function that fits on screen and one
that requires scrolling.

### SAF-15 — Centralize control flow in parent functions.

When splitting a large function, all branching logic (if/switch) MUST remain in the parent function.
Helper functions MUST NOT contain control flow that determines program behavior.

Rationale: Centralizing control flow means there is exactly one place to understand all branches.

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

Parent functions MUST own state mutation. Helper functions MUST compute and return values without
mutating shared state.

Rationale: Pure helper functions are easier to test and reason about.

### SAF-17 — Treat warnings as errors; keep runtime safety on. **(Zig-adapted)**

`zig fmt` MUST be run. Build/test MUST pass with warnings treated as errors. Runtime safety MUST NOT
be disabled except in audited hot paths with documented invariants.

Rationale: Warnings and disabled safety hide correctness issues.

### SAF-18 — Do not react directly to external events. Batch and process at your own pace.

Programs MUST NOT perform work directly in response to external events. Instead, events MUST be
queued and processed in controlled batches at the program's own pace.

Rationale: Reacting directly to external events surrenders control flow to the environment.

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions MUST be split into nested if/else branches.

Rationale: Compound conditions obscure case coverage.

### SAF-20 — State invariants positively. Avoid negations.

Conditions MUST be stated in positive form. Comparisons MUST follow the natural grain of the domain.

Rationale: Negations are error-prone and harder to verify.

### SAF-21 — Handle all errors explicitly.

Every error MUST be handled explicitly. No error SHALL be silently ignored or discarded.

Rationale: Error-handling bugs are the dominant cause of catastrophic production failures.

### SAF-22 — Always state the "why" in comments and commit messages.

Every non-obvious decision MUST be accompanied by a comment or commit message explaining why.

Rationale: The "what" is in the code. The "why" is the only thing that enables safe future changes.

### SAF-23 — Pass explicit options to library calls. Do not rely on defaults.

All options and configuration values MUST be passed explicitly at the call site. Default values
MUST NOT be relied upon.

Rationale: Defaults can change across library versions, causing latent bugs.

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance MUST be considered during the design phase, not deferred to profiling.

Rationale: Architecture-level wins cannot be retrofitted.

### PERF-02 — Perform back-of-the-envelope resource sketches.

Before implementation, back-of-the-envelope calculations MUST be performed for network, disk,
memory, and CPU.

Rationale: Sketches are cheap. They guide design into the right 90%.

### PERF-03 — Optimize the slowest resource first, weighted by frequency.

Optimization effort MUST target the slowest resource first, after adjusting for frequency.

Rationale: Bottleneck-focused optimization yields the largest gains.

### PERF-04 — Separate control plane from data plane.

The control plane (scheduling, coordination, metadata) MUST be clearly separated from the data
plane (bulk data processing).

Rationale: Mixing control and data operations prevents effective batching.

### PERF-05 — Amortize costs via batching.

Network, disk, memory, and CPU costs MUST be amortized by batching accesses. Per-item processing
MUST be avoided when batching is feasible.

Rationale: Per-item overhead dominates at high throughput.

### PERF-06 — Keep CPU work predictable. Avoid erratic control flow.

Hot paths MUST have predictable, linear control flow.

Rationale: Predictability enables cache utilization and reduces branch misprediction.

### PERF-07 — Be explicit. Do not depend on compiler optimizations.

Performance-critical code MUST be written explicitly. Do not rely on the compiler to inline or
optimize the code.

Rationale: Compiler optimizations are heuristic and fragile.

### PERF-08 — Use primitive arguments in hot loops. Avoid large receiver access.

Hot loop functions MUST take primitive arguments directly. They MUST NOT access large structs in
tight loops when performance matters.

Rationale: Primitive arguments allow the compiler to keep values in registers.

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names MUST capture what a thing is or does with precision.

Rationale: Great names are the essence of great code.

### DX-02 — Use snake_case for files/functions/variables. **(Zig-adapted)**

File, function, and variable names MUST use `snake_case`. Use Zig naming conventions for types.

Rationale: The underscore is the closest thing to a space and improves readability.

### DX-03 — Do not abbreviate names (except trivial loop counters).

Names MUST NOT be abbreviated unless the variable is a trivial loop counter (`i`, `j`, `k`).

Rationale: Abbreviations are ambiguous.

### DX-04 — Capitalize acronyms consistently.

Acronyms in names MUST use their standard capitalization (HTTPClient, SQLQuery).

Rationale: Standard capitalization is unambiguous.

### DX-05 — Append units and qualifiers at the end, sorted by significance.

Units and qualifiers MUST be appended to variable names, sorted from most significant to least
significant.

Rationale: Groups related variables visually and semantically.

### DX-06 — Use meaningful names that indicate lifecycle and ownership.

Resource names MUST convey lifecycle and ownership (arena, pool, buffer).

Rationale: Cleanup expectations should be obvious from the name.

### DX-07 — Align related names by character length when feasible.

When choosing names for related variables, PREFER names with the same character count so that
related expressions align visually.

Rationale: Symmetry improves visual parsing.

### DX-08 — Prefix helper/callback names with the caller's name.

When a function calls a helper or callback, the helper's name MUST be prefixed with the calling
function's name.

Rationale: The prefix makes the call hierarchy visible in the name itself.

### DX-09 — Callbacks go last in parameter lists.

Callback parameters MUST be the last parameters in a function signature.

Rationale: Callbacks are invoked last. Parameter order should mirror control flow.

### DX-10 — Order declarations by importance. Put public API first.

Within a file, the most important declarations (public API, entry points) MUST appear first.

Rationale: Files are read top-down on first encounter.

### DX-11 — Struct layout: fields, then types, then methods.

Struct definitions MUST be ordered: data fields first, then nested type definitions, then methods.

Rationale: Predictable layout lets the reader find what they need by position.

### DX-12 — Do not overload names that conflict with domain terminology.

Names MUST NOT be reused across different concepts in the same system.

Rationale: Overloaded terminology causes confusion in documentation and code review.

### DX-13 — Prefer nouns over adjectives/participles for externally-referenced names.

Names that appear in documentation, logs, or external communication MUST be nouns or noun phrases.

Rationale: Noun names compose cleanly into derived identifiers.

### DX-14 — Use named option structs when arguments can be confused.

When a function takes two or more arguments of the same type, or arguments whose meaning is not
obvious at the call site, a named options struct MUST be used.

Rationale: Positional arguments of the same type are silently swappable.

### DX-15 — Name nullable parameters so null's meaning is clear at the call site.

If a parameter accepts `null`, the parameter name MUST make the meaning of `null` obvious when read
at the call site.

Rationale: `foo(null)` is meaningless without context.

### DX-16 — Thread singletons positionally: general to specific.

Constructor parameters that are singletons (allocator, tracer) MUST be passed positionally, ordered
from most general to most specific.

Rationale: Consistent constructor signatures reduce cognitive load.

### DX-17 — Write descriptive commit messages.

Commit messages MUST be descriptive, informative, and explain the purpose of the change.

Rationale: Commit history is permanent documentation.

### DX-18 — Explain "why" in code comments.

Comments MUST explain why the code was written this way, not what the code does.

Rationale: Without rationale, future maintainers cannot evaluate whether the decision still applies.

### DX-19 — Explain "how" for tests and complex logic.

Tests and complex algorithms MUST include a description at the top explaining the goal and
methodology.

Rationale: Tests are documentation of expected behavior.

### DX-20 — Comments are well-formed sentences.

Comments MUST be complete sentences: space after `//`, capital letter, full stop (or colon if
followed by related content). End-of-line comments may be phrases without punctuation.

Rationale: Well-written prose is easier to read and signals careful thinking.

---

## Cache Invalidation & State Hygiene (CIS)

### CIS-01 — Do not duplicate variables or alias state.

Every piece of state MUST have exactly one source of truth. Variables MUST NOT be duplicated or
aliased unless there is a compelling performance reason, in which case the alias MUST be documented
and its synchronization asserted.

Rationale: Duplicated state will eventually desynchronize.

### CIS-02 — Pass large arguments by const pointer. **(Zig-adapted)**

Function arguments larger than 16 bytes MUST be passed by `*const`, not by value.

Rationale: Passing large structs by value creates implicit copies that waste stack space.

### CIS-03 — Prefer in-place initialization via out pointers. **(Zig-adapted)**

Large structs MUST be initialized in-place by passing an out pointer, rather than returning a value
that is then copied.

Rationale: In-place initialization avoids intermediate copies and ensures pointer stability.

### CIS-04 — If any field requires in-place init, the whole struct does. **(Zig-adapted)**

In-place initialization is viral. If any field requires in-place initialization, the entire
containing struct MUST also be initialized in-place.

Rationale: Mixing strategies breaks pointer stability.

### CIS-05 — Declare variables close to use. Shrink scope.

Variables MUST be computed or checked as close as possible to where they are used.

Rationale: Minimizes check-to-use gaps (POCPOU/TOCTOU risk).

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

Return types MUST be as simple as possible: `void` > `bool` > integer > optional > error union.

Rationale: Each additional dimension creates branches at every call site.

### CIS-07 — Do not suspend between assertions and dependent code.

Functions with precondition assertions MUST run to completion without suspension between the
assertion and the code that depends on it.

Rationale: Suspension can invalidate preconditions, making assertions misleading.

### CIS-08 — Guard against buffer underflow (buffer bleeds).

Unused buffer space MUST be explicitly zeroed before use or transmission.

Rationale: Buffer underflow leaks sensitive data.

### CIS-09 — Group allocation with deallocation using blank lines.

Resource allocation and its corresponding deallocation MUST be visually grouped using blank lines.

Rationale: Visual grouping makes resource leaks easy to spot during code review.

---

## Off-by-One & Arithmetic (OBO)

### OBO-01 — Treat index, count, and size as distinct types.

Indexes, counts, and sizes MUST be treated as conceptually distinct types. Conversions between
them MUST be explicit:
- index → count: add 1.
- count → size: multiply by unit size.

Rationale: The casual interchange of index, count, and size is the primary source of off-by-one
errors.

### OBO-02 — Use explicit division semantics. **(Zig-adapted)**

All integer division MUST use explicit semantics: `@divExact`, `@divFloor`, or `@divCeil`.

Rationale: Explicit division shows intent and rounding behavior.

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter.

All code MUST be formatted by `zig fmt`.

Rationale: Automated formatting eliminates style debates and ensures consistency.

### FMT-02 — Use 4-space indentation.

Indentation MUST be 4 spaces (as produced by `zig fmt`).

Rationale: 4 spaces is Zig's standard indentation depth.

### FMT-03 — Hard limit all lines to 100 columns.

No line SHALL exceed 100 columns.

Rationale: 100 columns allows two files side-by-side on a standard monitor.

### FMT-04 — Always use braces on if statements (unless single-line).

If statements MUST have braces unless the entire statement fits on a single line.

Rationale: Braceless multi-line if statements are the root cause of "goto fail" style bugs.

---

## Dependencies & Tooling (DEP)

### DEP-01 — Minimize dependencies.

The number of external dependencies MUST be minimized. Every dependency MUST be justified by a
clear, documented need that cannot be reasonably met by the standard library.

Rationale: Dependencies introduce supply chain risk, safety risk, performance risk, and
installation complexity.

### DEP-02 — Prefer existing tools over adding new ones.

New tools MUST NOT be introduced when an existing tool in the project's toolchain can accomplish
the task.

Rationale: Tool sprawl increases complexity and maintenance burden.

### DEP-03 — Prefer Zig for scripts and automation. **(Zig-adapted)**

Scripts and automation MUST be written in Zig. Shell scripts are acceptable only for trivial glue
(< 20 lines) with no logic.

Rationale: Zig scripts are portable, type-safe, and consistent with the toolchain.

---

## Appendix: Rule Index

| ID | Rule (short form) | Zig-adapted? |
|----|-------------------|--------------|
| SAF-01 | Simple explicit control flow; no recursion | |
| SAF-02 | Bound everything | |
| SAF-03 | Explicitly-sized types; avoid usize | Yes |
| SAF-04 | Assert pre/post/invariants | |
| SAF-05 | Assertion density ≥ 2/function | |
| SAF-06 | Pair assertions across paths | |
| SAF-07 | Split compound assertions | |
| SAF-08 | Single-line implication asserts | |
| SAF-09 | Assert compile-time constants | Yes |
| SAF-10 | Assert positive and negative space | |
| SAF-11 | Test valid, invalid, and boundary | |
| SAF-12 | Static allocation only | |
| SAF-13 | Smallest possible variable scope | |
| SAF-14 | 70-line function limit | |
| SAF-15 | Centralize control flow in parent | |
| SAF-16 | Centralize state mutation; pure leaves | |
| SAF-17 | zig fmt; runtime safety on | Yes |
| SAF-18 | Batch external events | |
| SAF-19 | Split compound conditions | |
| SAF-20 | Positive invariants; no negations | |
| SAF-21 | Handle all errors explicitly | |
| SAF-22 | Always state the why | |
| SAF-23 | Explicit options; no defaults | |
| PERF-01 | Design for performance from start | |
| PERF-02 | Back-of-envelope resource sketches | |
| PERF-03 | Optimize slowest resource first | |
| PERF-04 | Separate control and data planes | |
| PERF-05 | Amortize via batching | |
| PERF-06 | Predictable CPU work | |
| PERF-07 | Explicit; no compiler reliance | |
| PERF-08 | Primitive args in hot loops | |
| DX-01 | Precise nouns and verbs | |
| DX-02 | snake_case files/functions/vars | Yes |
| DX-03 | No abbreviations | |
| DX-04 | Consistent acronym capitalization | |
| DX-05 | Units/qualifiers appended last | |
| DX-06 | Meaningful lifecycle names | |
| DX-07 | Align related names by length | |
| DX-08 | Prefix helpers with caller name | |
| DX-09 | Callbacks last in params | |
| DX-10 | Public API first in file | |
| DX-11 | Struct: fields → types → methods | |
| DX-12 | No overloaded domain terms | |
| DX-13 | Noun names for external reference | |
| DX-14 | Named options for confusable args | |
| DX-15 | Name nullable params clearly | |
| DX-16 | Singletons: general → specific | |
| DX-17 | Descriptive commit messages | |
| DX-18 | Explain "why" in comments | |
| DX-19 | Explain "how" in tests | |
| DX-20 | Comments are sentences | |
| CIS-01 | No state duplication or aliasing | |
| CIS-02 | Large args by const pointer | Yes |
| CIS-03 | In-place init via out pointers | Yes |
| CIS-04 | In-place init is viral | Yes |
| CIS-05 | Declare close to use | |
| CIS-06 | Simpler return types | |
| CIS-07 | No suspension with active assertions | |
| CIS-08 | Guard against buffer bleeds | |
| CIS-09 | Group alloc/dealloc visually | |
| OBO-01 | Index ≠ count ≠ size | |
| OBO-02 | Explicit division semantics | Yes |
| FMT-01 | Run zig fmt | |
| FMT-02 | 4-space indent | |
| FMT-03 | 100-column hard limit | |
| FMT-04 | Braces on if (unless single-line) | |
| DEP-01 | Minimize dependencies | |
| DEP-02 | Prefer existing tools | |
| DEP-03 | Zig for scripts | Yes |
