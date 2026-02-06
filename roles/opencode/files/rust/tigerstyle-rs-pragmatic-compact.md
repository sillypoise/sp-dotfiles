# TigerStyle Rulebook — Rust / Pragmatic / Compact

## Preamble

This is the compact Rust variant of the TigerStyle Pragmatic rulebook. Each rule is a
recommendation with a one-line rationale. For full rationale and Rust examples, see
`tigerstyle-rs-pragmatic-full.md`.

**Design goal priority:** Safety > Performance > Developer Experience.

**Keywords:** SHOULD, PREFER, CONSIDER, AVOID — strong recommendations that acknowledge tradeoffs.

**Exception clause:** Any rule may be overridden if the exception is documented in a code comment
or commit message explaining why, and reviewed by at least one other contributor.

**Rust baseline:** latest stable. `rustfmt` and `clippy -D warnings` recommended.
Prefer `#![deny(warnings)]` and `cargo test` in CI.

**Unsafe policy:** `unsafe` SHOULD be minimized, scoped tightly, and documented with safety invariants.

**Error handling:** `unwrap`/`expect` SHOULD be avoided outside tests; if used, document why it is safe.

Rule IDs are stable across all TigerStyle variants for cross-referencing.
Rules marked **(Rs)** have been adapted from the language-agnostic version.

---

## Safety & Correctness (SAF)

**SAF-01** — All control flow SHOULD be simple and explicit. AVOID recursion.
Rationale: Ensures bounded, analyzable execution.

**SAF-02** — All loops, queues, retries, and buffers SHOULD have a fixed upper bound.
Rationale: Prevents infinite loops, tail-latency spikes, and resource exhaustion.

**SAF-03** **(Rs)** — Integer types SHOULD be explicitly sized (u32, i64). AVOID `usize` unless indexing/API requires.
Rationale: Eliminates architecture-specific behavior and overflow ambiguity.

**SAF-04** — Every function SHOULD assert its preconditions, postconditions, and invariants.
Rationale: Assertions catch programmer errors early; crashing is correct on corruption.

**SAF-05** — Assertion density SHOULD average at least 2 per function.
Rationale: High density is a force multiplier for correctness and testing yield.

**SAF-06** — CONSIDER pairing assertions on at least two different code paths per enforced property.
Rationale: Bugs hide at the boundary between valid and invalid data.

**SAF-07** — PREFER split assertions: `assert!(a); assert!(b);` over `assert!(a && b)`.
Rationale: Split assertions isolate failure causes and improve readability.

**SAF-08** — PREFER single-line implication asserts: `if a { assert!(b) }`.
Rationale: Preserves logical intent without complex boolean expressions.

**SAF-09** — Constants and type relationships SHOULD be asserted at compile time or startup.
Rationale: Catches design integrity violations before runtime.

**SAF-10** — Assertions SHOULD cover both positive space (expected) and negative space (not expected).
Rationale: Boundary-crossing bugs are the most common class of correctness errors.

**SAF-11** — Tests SHOULD exercise valid inputs, invalid inputs, and boundary transitions.
Rationale: 92% of catastrophic failures stem from incorrect handling of non-fatal errors.

**SAF-12** **(Rs)** — Allocations in hot paths SHOULD be minimized. Pre-allocate collections and reuse.
Rationale: Excessive allocation causes allocator overhead and tail-latency spikes.

**SAF-13** — Variables SHOULD be declared at the smallest possible scope; minimize variables in scope.
Rationale: Reduces misuse probability and limits blast radius of errors.

**SAF-14** — Functions SHOULD NOT exceed approximately 70 lines.
Rationale: Forces clean decomposition; eliminates scrolling discontinuity.

**SAF-15** — Branching logic (if/match) SHOULD remain in parent functions, not helpers.
Rationale: Centralizes case analysis in one place.

**SAF-16** — State mutation SHOULD be centralized in parent functions. Leaf functions SHOULD be pure.
Rationale: Localizes bugs to one mutation site; enables testable helpers.

**SAF-17** **(Rs)** — `rustfmt` and `clippy -D warnings` SHOULD pass. Treat warnings as errors.
Rationale: Warnings hide latent correctness issues.

**SAF-18** — External events SHOULD be queued and batch-processed, not handled inline.
Rationale: Keeps control flow bounded and internal.

**SAF-19** — Compound boolean conditions SHOULD be split into nested if/else branches.
Rationale: Makes case coverage explicit and verifiable.

**SAF-20** — PREFER stating invariants positively. AVOID negated conditions.
Rationale: Positive form aligns with natural reasoning about bounds and validity.

**SAF-21** **(Rs)** — Every error SHOULD be handled explicitly. AVOID `unwrap`/`expect` outside tests unless justified.
Rationale: Error-handling bugs are the dominant cause of catastrophic production failures.

**SAF-22** — Every non-obvious decision SHOULD have a comment or commit message explaining why.
Rationale: Rationale enables safe future changes; code without "why" is incomplete.

**SAF-23** — All options SHOULD be passed explicitly to library calls. AVOID relying on defaults.
Rationale: Defaults can change across versions, introducing latent bugs.

---

## Performance & Design (PERF)

**PERF-01** — Performance SHOULD be considered during design, not deferred to profiling.
Rationale: Architecture-level wins (1000x) cannot be retrofitted.

**PERF-02** — Back-of-the-envelope calculations SHOULD be performed for network, disk, memory, and CPU.
Rationale: Rough math guides design into the right 90% of solution space.

**PERF-03** — Optimization SHOULD target the slowest resource first, weighted by access frequency.
Rationale: Bottleneck-focused optimization yields the largest gains.

**PERF-04** — Control plane (scheduling, metadata) SHOULD be separated from data plane (bulk processing).
Rationale: Enables batching without sacrificing assertion safety.

**PERF-05** — Network, disk, memory, and CPU costs SHOULD be amortized via batching.
Rationale: Per-item overhead dominates at high throughput.

**PERF-06** — Hot paths SHOULD have predictable, linear control flow.
Rationale: Predictability enables cache utilization and branch prediction.

**PERF-07** — Performance-critical code SHOULD be explicit. AVOID depending on compiler optimizations.
Rationale: Compiler heuristics are fragile and non-portable.

**PERF-08** **(Rs)** — Hot loop functions SHOULD take primitive arguments. AVOID large `self` access in tight loops.
Rationale: Enables register allocation without alias analysis overhead.

---

## Developer Experience & Naming (DX)

**DX-01** — Names SHOULD capture what a thing is or does with precision.
Rationale: Great names are the essence of great code.

**DX-02** **(Rs)** — Functions/vars/modules: snake_case. Types/traits/enums: PascalCase. Consts: SCREAMING_SNAKE_CASE.
Rationale: Rust naming conventions reduce friction and improve tooling compatibility.

**DX-03** — Names SHOULD NOT be abbreviated (except trivial loop counters i, j, k).
Rationale: Abbreviations are ambiguous; full names are unambiguous.

**DX-04** — Acronyms SHOULD use standard capitalization (HTTPClient, SQLQuery).
Rationale: Standard form is unambiguous.

**DX-05** — Units and qualifiers SHOULD be appended to names, sorted by descending significance.
Rationale: Groups related variables visually and semantically.

**DX-06** — Resource names SHOULD convey lifecycle and ownership.
Rationale: Cleanup expectations should be obvious from the name.

**DX-07** — CONSIDER aligning related variable names by character length.
Rationale: Symmetry improves visual parsing and correctness checking.

**DX-08** — Helper/callback names SHOULD be prefixed with the calling function's name.
Rationale: Makes call hierarchy visible in the name.

**DX-09** — Callbacks SHOULD be the last parameter in function signatures.
Rationale: Mirrors control flow (callbacks are invoked last).

**DX-10** — Important declarations (public API) SHOULD appear first in a file.
Rationale: Files are read top-down; important context comes first.

**DX-11** — Struct layout SHOULD follow: fields → types → methods.
Rationale: Predictable layout enables navigation by position.

**DX-12** — AVOID overloading names with multiple domain-specific meanings.
Rationale: Overloaded terms cause confusion across contexts.

**DX-13** — Externally-referenced names SHOULD be nouns that work as prose and section headers.
Rationale: Noun names compose cleanly in documentation and conversation.

**DX-14** — Functions with confusable arguments SHOULD use named option structs.
Rationale: Prevents silent transposition bugs at the call site.

**DX-15** — Nullable parameters SHOULD be named so None's meaning is clear at the call site.
Rationale: `foo(None)` is meaningless; `foo(timeout_opt=None)` is not.

**DX-16** — Singleton constructor params SHOULD be ordered from most general to most specific.
Rationale: Consistent ordering reduces cognitive load.

**DX-17** — Commit messages SHOULD be descriptive and explain the purpose of the change.
Rationale: Commit history is permanent documentation visible in `git blame`.

**DX-18** — Comments SHOULD explain "why," not "what."
Rationale: "Why" enables safe future changes; "what" restates the code.

**DX-19** — Tests and complex logic SHOULD include a description of goal and methodology.
Rationale: Tests are documentation; readers need context to understand or skip them.

**DX-20** — Comments SHOULD be well-formed sentences (space, capital, full stop).
Rationale: Sloppy comments signal sloppy thinking.

---

## Cache Invalidation & State Hygiene (CIS)

**CIS-01** — Every piece of state SHOULD have exactly one source of truth. AVOID duplication or aliasing.
Rationale: Duplicated state will desynchronize.

**CIS-02** **(Rs)** — Arguments larger than 16 bytes SHOULD be passed by reference.
Rationale: Avoids implicit copies and stack waste.

**CIS-03** **(Rs)** — Large structs SHOULD be initialized in-place via builders/MaybeUninit.
Rationale: Avoids copies and ensures pointer stability.

**CIS-04** **(Rs)** — If any field requires in-place init, the entire struct SHOULD be initialized in-place.
Rationale: In-place init is viral; mixing strategies breaks pointer stability.

**CIS-05** — Variables SHOULD be declared and computed as close as possible to their point of use.
Rationale: Minimizes check-to-use gaps (POCPOU/TOCTOU risk).

**CIS-06** — PREFER simpler return types: () > bool > int > Option<T> > Result<T, E>.
Rationale: Each dimension in the return type creates viral call-site branching.

**CIS-07** **(Rs)** — AVOID `await` between an assertion and the code that depends on it. Re-assert after resumption.
Rationale: `await` yields control; preconditions may no longer hold on resume.

**CIS-08** — Unused buffer space SHOULD be explicitly zeroed before use or transmission.
Rationale: Buffer underflow leaks sensitive data.

**CIS-09** — Allocation and cleanup SHOULD be visually grouped with blank lines.
Rationale: Makes resource leaks easy to spot during code review.

---

## Off-by-One & Arithmetic (OBO)

**OBO-01** — Index, count, and size SHOULD be treated as distinct concepts with explicit conversions.
Rationale: Casual interchange is the primary source of off-by-one errors.

**OBO-02** — All integer division SHOULD use explicit semantics: exact, floor, or ceiling.
Rationale: Default `/` rounding varies by language; explicit shows intent.

---

## Formatting & Code Style (FMT)

**FMT-01** — All code SHOULD be formatted by `rustfmt`.
Rationale: Eliminates style debates and ensures consistency.

**FMT-02** — Indentation SHOULD be 4 spaces.
Rationale: 4 spaces is Rust's standard indentation depth.

**FMT-03** — Lines SHOULD NOT exceed 100 columns.
Rationale: Ensures side-by-side review with no horizontal scroll.

**FMT-04** — If statements SHOULD have braces unless the entire statement fits on a single line.
Rationale: Prevents "goto fail" class bugs.

---

## Dependencies & Tooling (DEP)

**DEP-01** — External dependencies SHOULD be minimized and justified.
Rationale: Supply chain risk, safety risk, performance risk, installation complexity.

**DEP-02** — New tools SHOULD NOT be introduced when an existing tool suffices.
Rationale: Tool sprawl increases complexity and maintenance burden.

**DEP-03** **(Rs)** — Scripts SHOULD be written in Rust. Shell scripts only for trivial glue (<20 lines).
Rationale: Rust scripts are portable, type-safe, and consistent with the toolchain.

---

## Appendix: Rule Index

| ID | Rule (short form) | Rs? |
|----|-------------------|-----|
| SAF-01 | Simple explicit control flow; no recursion | |
| SAF-02 | Bound everything | |
| SAF-03 | Explicitly-sized types; avoid usize | Yes |
| SAF-04 | Assert pre/post/invariants | |
| SAF-05 | Assertion density ≥ 2/function | |
| SAF-06 | Pair assertions across paths | |
| SAF-07 | Split compound assertions | |
| SAF-08 | Single-line implication asserts | |
| SAF-09 | Assert compile-time constants | |
| SAF-10 | Assert positive and negative space | |
| SAF-11 | Test valid, invalid, and boundary | |
| SAF-12 | Pre-allocate; reuse; minimize allocations | Yes |
| SAF-13 | Smallest possible variable scope | |
| SAF-14 | ~70-line function limit | |
| SAF-15 | Centralize control flow in parent | |
| SAF-16 | Centralize state mutation; pure leaves | |
| SAF-17 | rustfmt/clippy; warnings as errors | Yes |
| SAF-18 | Batch external events | |
| SAF-19 | Split compound conditions | |
| SAF-20 | Positive invariants; no negations | |
| SAF-21 | Handle errors; avoid unwrap/expect unless justified | Yes |
| SAF-22 | Always state the why | |
| SAF-23 | Explicit options; no defaults | |
| PERF-01 | Design for performance from start | |
| PERF-02 | Back-of-envelope resource sketches | |
| PERF-03 | Optimize slowest resource first | |
| PERF-04 | Separate control and data planes | |
| PERF-05 | Amortize via batching | |
| PERF-06 | Predictable CPU work | |
| PERF-07 | Explicit; no compiler reliance | |
| PERF-08 | Primitive args in hot loops; avoid self | Yes |
| DX-01 | Precise nouns and verbs | |
| DX-02 | snake_case vars, PascalCase types, SCREAMING consts | Yes |
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
| CIS-02 | Large args by reference | Yes |
| CIS-03 | In-place init via builders/MaybeUninit | Yes |
| CIS-04 | In-place init is viral | Yes |
| CIS-05 | Declare close to use | |
| CIS-06 | Simpler return types | |
| CIS-07 | No await between assert and use | Yes |
| CIS-08 | Guard against buffer bleeds | |
| CIS-09 | Group alloc/dealloc visually | |
| OBO-01 | Index ≠ count ≠ size | |
| OBO-02 | Explicit division semantics | |
| FMT-01 | Run rustfmt | |
| FMT-02 | 4-space indent | |
| FMT-03 | 100-column hard limit | |
| FMT-04 | Braces on if (unless single-line) | |
| DEP-01 | Minimize dependencies | |
| DEP-02 | Prefer existing tools | |
| DEP-03 | Rust for scripts | Yes |
| POL-01 | Unsafe blocks minimized, scoped, and documented | Yes |
