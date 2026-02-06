# TigerStyle Rulebook — C / Pragmatic / Full

## Preamble

### Purpose

This document is a comprehensive C coding rulebook derived from TigerBeetle's TigerStyle. It is
intended to be dropped into any C codebase as part of an `AGENTS.md` file, a system prompt, or a
code review checklist. Every rule is actionable. This is the pragmatic variant: rules are strong
recommendations that acknowledge tradeoffs and existing codebases.

This is the **C-specific** variant. Rule IDs match the language-agnostic TigerStyle rulebook for
cross-referencing. Where C idioms differ from the language-agnostic version, the adaptation is
noted.

### Design Goal Priority

All rules serve three design goals, in this order:

1. **Safety** — correctness, bounded behavior, crash on corruption.
2. **Performance** — mechanical sympathy, batching, resource awareness.
3. **Developer Experience** — clarity, naming, readability, maintainability.

When goals conflict, higher-priority goals win.

### Keyword Definitions

- **SHOULD** — Strong recommendation. Follow unless there is a documented, justifiable reason not
  to.
- **PREFER** — Default choice. Use this approach unless an alternative is clearly better for the
  specific situation.
- **CONSIDER** — Worth evaluating. Apply when the benefit outweighs the cost in context.
- **AVOID** — Strong discouragement. Do not use unless there is a documented, justifiable reason.

### Exception Clause

Any rule in this document may be overridden in a specific instance if:

1. The exception is documented in a code comment or commit message.
2. The comment explains **why** the rule does not apply.
3. The exception is reviewed and approved by at least one other contributor.

Undocumented exceptions are violations.

### C Baseline and Tooling

- Target: **C17** (or later) with `clang` and `gcc` compatibility.
- Formatter: `clang-format`.
- Warnings SHOULD be treated as errors; enable `-Wall -Wextra -Werror -Wpedantic` at minimum.
- Tests SHOULD run with sanitizers (`-fsanitize=address,undefined`) in CI.

### Undefined Behavior Policy

- Undefined behavior SHOULD be treated as a correctness defect.
- Type-punning SHOULD use `memcpy`, not aliasing casts.
- Signed overflow SHOULD be avoided; use explicit bounds checks.

### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: a recommendation, a rationale, and a C example or template.
- Rules marked **(C-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Avoid recursion.

All control flow SHOULD be simple, explicit, and statically analyzable. AVOID recursion.

Rationale: Predictable, bounded execution is the foundation of safety.

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work SHOULD have a
fixed upper bound.

Rationale: Unbounded work causes infinite loops and tail-latency spikes.

### SAF-03 — Use explicitly-sized integer types. **(C-adapted)**

Integer types SHOULD be explicitly sized (`uint32_t`, `int64_t`). AVOID `size_t` and `long` unless
required for indexing or API compatibility.

Rationale: Implicit sizing creates architecture-specific behavior and makes overflow analysis
impossible without knowing the target.

### SAF-04 — Assert all preconditions, postconditions, and invariants.

Every function SHOULD assert its preconditions, postconditions, and invariants.

Rationale: Assertions detect programmer errors early and localize faults.

### SAF-05 — Maintain assertion density of at least 2 per function.

The assertion density of the codebase SHOULD average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs.

### SAF-06 — Pair assertions across different code paths.

CONSIDER adding at least two assertions on different code paths per enforced property.

Rationale: Bugs hide at the boundary between valid and invalid data.

### SAF-07 — Split compound assertions.

PREFER split assertions over compound assertions.

Rationale: Split assertions isolate failure causes and improve readability.

### SAF-08 — Use single-line implication assertions.

PREFER expressing implications as: `if (a) assert(b)`.

Rationale: Preserves logical intent without complex boolean expressions.

### SAF-09 — Assert compile-time constants and type sizes. **(C-adapted)**

Constants and type relationships SHOULD be asserted at compile time (`_Static_assert`) or startup.

Rationale: Catches design integrity violations before runtime.

### SAF-10 — Assert both positive and negative space.

Assertions SHOULD cover both the positive space (expected) and the negative space (not expected).

Rationale: Boundary-crossing bugs are common.

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests SHOULD exercise valid inputs, invalid inputs, and boundary transitions.

Rationale: Most catastrophic failures stem from incorrect handling of non-fatal errors.

### SAF-12 — Allocate at initialization. Avoid runtime reallocation.

Memory SHOULD be statically allocated at initialization. Avoid runtime reallocation when possible.

Rationale: Dynamic allocation introduces unpredictable latency and fragmentation.

### SAF-13 — Declare variables at the smallest possible scope.

Variables SHOULD be declared at the smallest possible scope.

Rationale: Tight scoping reduces misuse.

### SAF-14 — Keep functions short (~70 lines hard limit).

Functions SHOULD NOT exceed approximately 70 lines.

Rationale: Forces clean decomposition.

### SAF-15 — Centralize control flow in parent functions.

Branching logic SHOULD remain in parent functions. Helpers SHOULD NOT determine control flow.

Rationale: Centralizes case analysis in one place.

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

Parent functions SHOULD own state mutation. Helpers SHOULD be pure.

Rationale: Localizes bugs and improves testability.

### SAF-17 — Treat warnings as errors; enable sanitizers. **(C-adapted)**

All compiler warnings SHOULD be enabled at the strictest available setting. Test builds SHOULD run
with sanitizers (`address`, `undefined`) enabled.

Rationale: Warnings and UB hide correctness issues that are cheaper to catch early.

### SAF-18 — Do not react directly to external events. Batch and process at your own pace.

Programs SHOULD NOT perform work directly in response to external events. Events SHOULD be queued
and processed in controlled batches.

Rationale: Batching restores control and bounds work per time period.

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions SHOULD be split into nested if/else branches.

Rationale: Makes case coverage explicit and verifiable.

### SAF-20 — State invariants positively. Avoid negations.

PREFER positive form. Comparisons SHOULD follow the natural grain of the domain.

Rationale: Positive conditions are easier to verify.

### SAF-21 — Handle all errors explicitly.

Every error SHOULD be handled explicitly. Avoid silently ignoring errors or return values.

Rationale: Error-handling bugs are the dominant cause of catastrophic production failures.

### SAF-22 — Always state the "why" in comments and commit messages.

Every non-obvious decision SHOULD be accompanied by a comment or commit message explaining why.

Rationale: "Why" enables safe future changes.

### SAF-23 — Pass explicit options to library calls. Avoid relying on defaults.

All options SHOULD be passed explicitly at the call site. AVOID relying on defaults.

Rationale: Defaults can change across versions, introducing latent bugs.

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance SHOULD be considered during the design phase, not deferred to profiling.

Rationale: Architecture-level wins cannot be retrofitted.

### PERF-02 — Perform back-of-the-envelope resource sketches.

Back-of-the-envelope calculations SHOULD be performed for network, disk, memory, and CPU.

Rationale: Rough math guides design into the right 90%.

### PERF-03 — Optimize the slowest resource first, weighted by frequency.

Optimization SHOULD target the slowest resource first, adjusted by access frequency.

Rationale: Bottleneck-focused optimization yields the largest gains.

### PERF-04 — Separate control plane from data plane.

Control plane SHOULD be clearly separated from data plane.

Rationale: Enables batching without sacrificing assertion safety.

### PERF-05 — Amortize costs via batching.

Costs SHOULD be amortized by batching. AVOID per-item processing when batching is feasible.

Rationale: Per-item overhead dominates at high throughput.

### PERF-06 — Keep CPU work predictable. Avoid erratic control flow.

Hot paths SHOULD have predictable, linear control flow.

Rationale: Predictability enables cache utilization.

### PERF-07 — Be explicit. Do not depend on compiler optimizations.

Performance-critical code SHOULD be explicit. AVOID relying on compiler magic.

Rationale: Compiler optimizations are heuristic and fragile.

### PERF-08 — Use primitive arguments in hot loops. Avoid large receiver access.

Hot loop functions SHOULD take primitive arguments directly. Avoid accessing large structs in tight
loops.

Rationale: Primitive arguments are register-friendly.

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names SHOULD capture what a thing is or does with precision.

Rationale: Great names are the essence of great code.

### DX-02 — Use snake_case for files/functions/variables. **(C-adapted)**

File, function, and variable names SHOULD use `snake_case`. Types SHOULD use consistent, readable
`snake_case` or `UpperCamelCase` based on project convention.

Rationale: Underscores separate words clearly.

### DX-03 — Do not abbreviate names (except trivial loop counters).

Names SHOULD NOT be abbreviated unless the variable is a trivial loop counter.

Rationale: Abbreviations are ambiguous.

### DX-04 — Capitalize acronyms consistently.

Acronyms SHOULD use standard capitalization.

Rationale: Standard capitalization is unambiguous.

### DX-05 — Append units and qualifiers at the end, sorted by significance.

Units and qualifiers SHOULD be appended to names, sorted from most significant to least.

Rationale: Groups related variables visually and semantically.

### DX-06 — Use meaningful names that indicate lifecycle and ownership.

Resource names SHOULD convey lifecycle and ownership.

Rationale: Cleanup expectations should be obvious from the name.

### DX-07 — Align related names by character length when feasible.

CONSIDER names with the same character count for related variables.

Rationale: Symmetry improves visual parsing.

### DX-08 — Prefix helper/callback names with the caller's name.

Helpers SHOULD be prefixed with the calling function's name.

Rationale: Makes call hierarchy visible in the name.

### DX-09 — Callbacks go last in parameter lists.

Callback parameters SHOULD be last.

Rationale: Mirrors control flow.

### DX-10 — Order declarations by importance. Put public API first.

Public API SHOULD appear first in a file.

Rationale: Files are read top-down.

### DX-11 — Struct layout: fields, then types, then methods.

Struct definitions SHOULD be ordered: fields first, then nested types, then functions that operate
on the struct.

Rationale: Predictable layout.

### DX-12 — Do not overload names that conflict with domain terminology.

AVOID reusing names across different concepts.

Rationale: Overloaded terms cause confusion.

### DX-13 — Prefer nouns over adjectives/participles for externally-referenced names.

Externally-referenced names SHOULD be nouns.

Rationale: Noun names compose cleanly in docs.

### DX-14 — Use named option structs when arguments can be confused.

Functions with confusable arguments SHOULD use named option structs.

Rationale: Prevents silent transposition bugs.

### DX-15 — Name nullable parameters so null's meaning is clear at the call site.

Nullable parameters SHOULD be named so `NULL` meaning is clear.

Rationale: `foo(NULL)` is meaningless without context.

### DX-16 — Thread singletons positionally: general to specific.

Singleton constructor params SHOULD be ordered from most general to most specific.

Rationale: Consistent ordering reduces cognitive load.

### DX-17 — Write descriptive commit messages.

Commit messages SHOULD be descriptive and explain the purpose of the change.

Rationale: Commit history is permanent documentation.

### DX-18 — Explain "why" in code comments.

Comments SHOULD explain why, not what.

Rationale: "Why" enables safe future changes.

### DX-19 — Explain "how" for tests and complex logic.

Tests SHOULD include a description of goal and methodology.

Rationale: Tests are documentation.

### DX-20 — Comments are well-formed sentences.

Comments SHOULD be complete sentences.

Rationale: Well-written prose signals careful thinking.

---

## Cache Invalidation & State Hygiene (CIS)

### CIS-01 — Do not duplicate variables or alias state.

Every piece of state SHOULD have exactly one source of truth. AVOID duplication or aliasing.

Rationale: Duplicated state will desynchronize.

### CIS-02 — Pass large arguments by const pointer. **(C-adapted)**

Arguments larger than 16 bytes SHOULD be passed by `const` pointer, not by value.

Rationale: Avoids implicit copies and stack waste.

### CIS-03 — Prefer in-place initialization via out pointers. **(C-adapted)**

Large structs SHOULD be initialized in-place via out pointers.

Rationale: Avoids copies and ensures pointer stability.

### CIS-04 — If any field requires in-place init, the whole struct does. **(C-adapted)**

If any field requires in-place init, the entire struct SHOULD be initialized in-place.

Rationale: In-place init is viral; mixing strategies breaks pointer stability.

### CIS-05 — Declare variables close to use. Shrink scope.

Variables SHOULD be declared and computed as close as possible to their point of use.

Rationale: Minimizes check-to-use gaps.

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

PREFER simpler return types: void > bool > integer > optional > error struct.

Rationale: Each dimension creates viral call-site branching.

### CIS-07 — Do not suspend between assertions and dependent code.

AVOID re-entering event loops or user callbacks between an assertion and dependent code.

Rationale: Re-entrancy can invalidate preconditions.

### CIS-08 — Guard against buffer underflow (buffer bleeds).

Unused buffer space SHOULD be explicitly zeroed before use or transmission.

Rationale: Buffer underflow leaks sensitive data.

### CIS-09 — Group allocation with deallocation using blank lines.

Allocation and cleanup SHOULD be visually grouped with blank lines.

Rationale: Makes resource leaks easy to spot.

---

## Off-by-One & Arithmetic (OBO)

### OBO-01 — Treat index, count, and size as distinct types.

Indexes, counts, and sizes SHOULD be treated as distinct concepts with explicit conversions.

Rationale: Casual interchange is the primary source of off-by-one errors.

### OBO-02 — Use explicit division semantics. **(C-adapted)**

All integer division SHOULD use explicit semantics via helper functions (`div_exact`, `div_floor`,
`div_ceil`). AVOID bare `/` when rounding behavior matters.

Rationale: Explicit division shows intent and rounding behavior.

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter. **(C-adapted)**

All code SHOULD be formatted by `clang-format`.

Rationale: Eliminates style debates and ensures consistency.

### FMT-02 — Use 4-space indentation.

Indentation SHOULD be 4 spaces.

Rationale: 4 spaces is C's common indentation depth.

### FMT-03 — Hard limit all lines to 100 columns.

Lines SHOULD NOT exceed 100 columns.

Rationale: Ensures side-by-side review with no horizontal scroll.

### FMT-04 — Always use braces on if statements (unless single-line).

If statements SHOULD have braces unless the entire statement fits on a single line.

Rationale: Prevents "goto fail" class bugs.

---

## Dependencies & Tooling (DEP)

### DEP-01 — Minimize dependencies.

External dependencies SHOULD be minimized and justified.

Rationale: Supply chain risk, safety risk, performance risk, installation complexity.

### DEP-02 — Prefer existing tools over adding new ones.

New tools SHOULD NOT be introduced when an existing tool suffices.

Rationale: Tool sprawl increases complexity and maintenance burden.

### DEP-03 — Prefer typed, portable tooling for scripts.

Scripts SHOULD prefer typed, portable languages over shell scripts.

Rationale: Shell scripts are not portable, not type-safe, and fail silently.

---

## Appendix: Rule Index

| ID | Rule (short form) | C-adapted? |
|----|-------------------|------------|
| SAF-01 | Simple explicit control flow; no recursion | |
| SAF-02 | Bound everything | |
| SAF-03 | Explicitly-sized types; avoid size_t | Yes |
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
| SAF-17 | Warnings as errors; sanitizers | Yes |
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
| FMT-01 | Run clang-format | Yes |
| FMT-02 | 4-space indent | |
| FMT-03 | 100-column hard limit | |
| FMT-04 | Braces on if (unless single-line) | |
| DEP-01 | Minimize dependencies | |
| DEP-02 | Prefer existing tools | |
| DEP-03 | Typed portable scripts | |
