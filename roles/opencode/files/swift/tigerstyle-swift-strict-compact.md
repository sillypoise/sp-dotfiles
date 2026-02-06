# TigerStyle Rulebook — Swift / Strict / Compact

## Preamble

This is the compact Swift variant of the TigerStyle Strict rulebook. Each rule is an imperative
with a one-line rationale. For full rationale and Swift examples, see
`tigerstyle-swift-strict-full.md`.

**Design goal priority:** Safety > Performance > Developer Experience.

**Keywords:** MUST, SHALL, MUST NOT — absolute requirements. Violations are defects.

**Swift baseline:** Swift 5.9. `swift-format` is mandatory. Warnings MUST be treated as errors.
`swift test` MUST pass in CI.

Rule IDs are stable across all TigerStyle variants for cross-referencing.
Rules marked **(Sw)** have been adapted from the language-agnostic version.

---

## Safety & Correctness (SAF)

**SAF-01** — All control flow MUST be simple and explicit. Recursion MUST NOT be used.
Rationale: Ensures bounded, analyzable execution.

**SAF-02** — All loops, queues, retries, and buffers MUST have a fixed upper bound.
Rationale: Prevents infinite loops, tail-latency spikes, and resource exhaustion.

**SAF-03** **(Sw)** — Integer types MUST be explicitly sized (Int64, UInt32). Int/UInt
MUST NOT be used unless indexing/API requires.
Rationale: Eliminates architecture-specific behavior and overflow ambiguity.

**SAF-04** — Every function MUST assert its preconditions, postconditions, and invariants.
Rationale: Assertions catch programmer errors early; crashing is correct on corruption.

**SAF-05** — Assertion density MUST average at least 2 per function.
Rationale: High density is a force multiplier for correctness and testing yield.

**SAF-06** — Every enforced property MUST have paired assertions on at least two different code
paths.
Rationale: Bugs hide at the boundary between valid and invalid data.

**SAF-07** — Compound assertions MUST be split: `precondition(a); precondition(b);` not
`precondition(a && b)`.
Rationale: Split assertions isolate failure causes and improve readability.

**SAF-08** — Implications MUST be expressed as single-line asserts:
`if a { precondition(b) }`.
Rationale: Preserves logical intent without complex boolean expressions.

**SAF-09** — Constants and type relationships MUST be asserted at compile time or startup.
Rationale: Catches design integrity violations before runtime.

**SAF-10** — Assertions MUST cover both positive space (expected) and negative space
(not expected).
Rationale: Boundary-crossing bugs are the most common class of correctness errors.

**SAF-11** — Tests MUST exercise valid inputs, invalid inputs, and boundary transitions.
Rationale: 92% of catastrophic failures stem from incorrect handling of non-fatal errors.

**SAF-12** **(Sw)** — Allocations in hot paths MUST be minimized. Collections MUST be
pre-allocated and reused.
Rationale: Excessive allocation causes ARC/allocator overhead and tail-latency spikes.

**SAF-13** — Variables MUST be declared at the smallest scope; minimize variables in
scope.
Rationale: Reduces misuse probability and limits blast radius of errors.

**SAF-14** — No function SHALL exceed 70 lines.
Rationale: Forces clean decomposition; eliminates scrolling discontinuity.

**SAF-15** — All branching logic (if/switch) MUST remain in parent functions, not helpers.
Rationale: Centralizes case analysis in one place.

**SAF-16** — State mutation MUST be centralized in parent functions. Leaf functions MUST be pure.
Rationale: Localizes bugs to one mutation site; enables testable helpers.

**SAF-17** **(Sw)** — `swift-format` MUST pass. Warnings MUST be treated as errors
(`-warnings-as-errors`).
Rationale: Warnings hide latent correctness issues.

**SAF-18** — External events MUST be queued and batch-processed, not handled inline.
Rationale: Keeps control flow bounded and internal.

**SAF-19** — Compound boolean conditions MUST be split into nested if/else branches.
Rationale: Makes case coverage explicit and verifiable.

**SAF-20** — Invariants MUST be stated positively. Negated conditions MUST NOT be used.
Rationale: Positive form aligns with natural reasoning about bounds and validity.

**SAF-21** **(Sw)** — Every error MUST be handled explicitly. `try?`/`try!` MUST NOT be
used unless justified.
Rationale: Error-handling bugs are the dominant cause of catastrophic production failures.

**SAF-22** — Every non-obvious decision MUST have a comment or commit message explaining why.
Rationale: Rationale enables safe future changes; code without "why" is incomplete.

**SAF-23** — All options MUST be passed explicitly to library calls. Defaults MUST NOT be relied on.
Rationale: Defaults can change across versions, introducing latent bugs.

---

## Performance & Design (PERF)

**PERF-01** — Performance MUST be considered during design, not deferred to profiling.
Rationale: Architecture-level wins (1000x) cannot be retrofitted.

**PERF-02** — Back-of-the-envelope calculations MUST be performed for network, disk, memory, and
CPU.
Rationale: Rough math guides design into the right 90% of solution space.

**PERF-03** — Optimization MUST target the slowest resource first, weighted by access frequency.
Rationale: Bottleneck-focused optimization yields the largest gains.

**PERF-04** — Control plane (scheduling, metadata) MUST be separated from data plane
(bulk processing).
Rationale: Enables batching without sacrificing assertion safety.

**PERF-05** — Network, disk, memory, and CPU costs MUST be amortized via batching.
Rationale: Per-item overhead dominates at high throughput.

**PERF-06** — Hot paths MUST have predictable, linear control flow.
Rationale: Predictability enables cache utilization and branch prediction.

**PERF-07** — Performance-critical code MUST be explicit. Compiler optimizations MUST NOT be
relied on.
Rationale: Compiler heuristics are fragile and non-portable.

**PERF-08** **(Sw)** — Hot loop functions MUST take primitive arguments. Large `self` access
in tight loops MUST be avoided.
Rationale: Enables register allocation without alias analysis overhead.

---

## Developer Experience & Naming (DX)

**DX-01** — Names MUST capture what a thing is or does with precision.
Rationale: Great names are the essence of great code.

**DX-02** **(Sw)** — Functions/vars: lowerCamelCase. Types: UpperCamelCase. Enum cases:
lowerCamelCase. Follow file naming conventions.
Rationale: Swift naming conventions reduce friction and improve tooling compatibility.

**DX-03** — Names MUST NOT be abbreviated (except trivial loop counters i, j, k).
Rationale: Abbreviations are ambiguous; full names are unambiguous.

**DX-04** — Acronyms MUST use standard capitalization (HTTPClient, SQLQuery).
Rationale: Standard form is unambiguous.

**DX-05** — Units and qualifiers MUST be appended to names, sorted by descending significance.
Rationale: Groups related variables visually and semantically.

**DX-06** — Resource names MUST convey lifecycle and ownership.
Rationale: Cleanup expectations should be obvious from the name.

**DX-07** — Related variable names SHOULD be aligned by character length when feasible.
Rationale: Symmetry improves visual parsing and correctness checking.

**DX-08** — Helper/callback names MUST be prefixed with the calling function's name.
Rationale: Makes call hierarchy visible in the name.

**DX-09** — Callbacks MUST be the last parameter in function signatures.
Rationale: Mirrors control flow (callbacks are invoked last).

**DX-10** — Important declarations (public API) MUST appear first in a file.
Rationale: Files are read top-down; important context comes first.

**DX-11** — Struct layout MUST follow: fields → types → methods.
Rationale: Predictable layout enables navigation by position.

**DX-12** — Names MUST NOT be overloaded with multiple domain-specific meanings.
Rationale: Overloaded terms cause confusion across contexts.

**DX-13** — Externally-referenced names MUST be nouns that work as prose and section headers.
Rationale: Noun names compose cleanly in documentation and conversation.

**DX-14** — Functions with confusable arguments MUST use named option structs.
Rationale: Prevents silent transposition bugs at the call site.

**DX-15** — Nullable parameters MUST be named so nil's meaning is clear at the call site.
Rationale: `foo(nil)` is meaningless; `foo(timeout_ms: nil)` is not.

**DX-16** — Singleton constructor params MUST be ordered from most general to most specific.
Rationale: Consistent ordering reduces cognitive load.

**DX-17** — Commit messages MUST be descriptive and explain the purpose of the change.
Rationale: Commit history is permanent documentation visible in `git blame`.

**DX-18** — Comments MUST explain "why," not "what."
Rationale: "Why" enables safe future changes; "what" restates the code.

**DX-19** — Tests and complex logic MUST include a description of goal and methodology.
Rationale: Tests are documentation; readers need context to understand or skip them.

**DX-20** — Comments MUST be well-formed sentences (space, capital, full stop).
Rationale: Sloppy comments signal sloppy thinking.

---

## Cache Invalidation & State Hygiene (CIS)

**CIS-01** — Every piece of state MUST have exactly one source of truth.
Duplication/aliasing MUST NOT occur.
Rationale: Duplicated state will desynchronize.

**CIS-02** **(Sw)** — Arguments larger than 16 bytes MUST be passed by reference
(`inout`/reference types).
Rationale: Avoids implicit copies and stack waste.

**CIS-03** **(Sw)** — Large structs MUST be initialized in-place via `inout` builders or
pointers.
Rationale: Avoids copies and ensures pointer stability.

**CIS-04** **(Sw)** — If any field requires in-place init, the entire struct MUST be
initialized in-place.
Rationale: In-place init is viral; mixing strategies breaks pointer stability.

**CIS-05** — Variables MUST be declared and computed as close as possible to their point of use.
Rationale: Minimizes check-to-use gaps (POCPOU/TOCTOU risk).

**CIS-06** — Simpler return types MUST be preferred: Void > Bool > int > optional >
Result.
Rationale: Each dimension in the return type creates viral call-site branching.

**CIS-07** **(Sw)** — `await` MUST NOT appear between an assertion and the code that depends
on it.
Rationale: `await` yields control; preconditions may no longer hold on resume.

**CIS-08** — Unused buffer space MUST be explicitly zeroed before use or transmission.
Rationale: Buffer underflow leaks sensitive data.

**CIS-09** — Allocation and cleanup MUST be visually grouped with blank lines.
Rationale: Makes resource leaks easy to spot during code review.

---

## Off-by-One & Arithmetic (OBO)

**OBO-01** — Index, count, and size MUST be treated as distinct concepts with explicit conversions.
Rationale: Casual interchange is the primary source of off-by-one errors.

**OBO-02** — All integer division MUST use explicit semantics: exact, floor, or ceiling.
Rationale: Default `/` rounding varies by language; explicit shows intent.

---

## Formatting & Code Style (FMT)

**FMT-01** — All code MUST be formatted by `swift-format`.
Rationale: Eliminates style debates and ensures consistency.

**FMT-02** — Indentation MUST be 4 spaces (or the project's declared standard).
Rationale: 4 spaces is visually distinct at a distance.

**FMT-03** — Lines MUST NOT exceed 100 columns.
Rationale: Ensures side-by-side review with no horizontal scroll.

**FMT-04** — If statements MUST have braces unless the entire statement fits on a single line.
Rationale: Prevents "goto fail" class bugs.

---

## Dependencies & Tooling (DEP)

**DEP-01** — External dependencies MUST be minimized and justified.
Rationale: Supply chain risk, safety risk, performance risk, installation complexity.

**DEP-02** — New tools MUST NOT be introduced when an existing tool suffices.
Rationale: Tool sprawl increases complexity and maintenance burden.

**DEP-03** **(Sw)** — Scripts MUST be written in Swift. Shell scripts only for trivial glue
(<20 lines).
Rationale: Swift scripts are portable, type-safe, and consistent with the toolchain.

---

## Appendix: Rule Index

| ID | Rule (short form) | Sw? |
|----|-------------------|-----|
| SAF-01 | Simple explicit control flow; no recursion | |
| SAF-02 | Bound everything | |
| SAF-03 | Explicitly-sized types; avoid Int/UInt | Yes |
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
| SAF-17 | swift-format; warnings as errors | Yes |
| SAF-18 | Batch external events | |
| SAF-19 | Split compound conditions | |
| SAF-20 | Positive invariants; no negations | |
| SAF-21 | Handle errors; avoid try?/try! unless justified | Yes |
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
| DX-02 | Swift naming conventions | Yes |
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
| CIS-03 | In-place init via inout/pointers | Yes |
| CIS-04 | In-place init is viral | Yes |
| CIS-05 | Declare close to use | |
| CIS-06 | Simpler return types | |
| CIS-07 | No await between assert and use | Yes |
| CIS-08 | Guard against buffer bleeds | |
| CIS-09 | Group alloc/dealloc visually | |
| OBO-01 | Index ≠ count ≠ size | |
| OBO-02 | Explicit division semantics | |
| FMT-01 | Run swift-format | |
| FMT-02 | 4-space indent | |
| FMT-03 | 100-column hard limit | |
| FMT-04 | Braces on if (unless single-line) | |
| DEP-01 | Minimize dependencies | |
| DEP-02 | Prefer existing tools | |
| DEP-03 | Swift for scripts | Yes |
