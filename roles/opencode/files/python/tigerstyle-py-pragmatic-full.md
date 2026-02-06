# TigerStyle Rulebook — Python / Pragmatic / Full

## Preamble

### Purpose

This document is a comprehensive Python 3 rulebook derived from TigerBeetle's TigerStyle. It is
intended to be dropped into any Python codebase as part of an `AGENTS.md` file, a system prompt, or
a code review checklist. Every rule is actionable. This is the pragmatic variant: rules are strong
recommendations that acknowledge tradeoffs and existing codebases.

This is the **Python-specific** variant. Rule IDs match the language-agnostic TigerStyle rulebook
for cross-referencing. Where Python idioms differ from the language-agnostic version, the
adaptation is noted.

### Design Goal Priority

All rules serve three design goals, in this order:

1. **Safety** — correctness, bounded behavior, crash on corruption.
2. **Performance** — mechanical sympathy, batching, resource awareness.
3. **Developer Experience** — clarity, naming, readability, maintainability.

When goals conflict, higher-priority goals win.

### Keyword Definitions

- **SHOULD** — Strong recommendation. Follow unless there is a documented, justifiable reason not to.
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

### Python Baseline and Tooling

- Target runtime: **Python 3.11+**.
- Formatter: **black** (line length 100) OR `ruff format` with identical settings.
- Lint: **ruff** (no ignored warnings).
- Typing: **mypy** in strict mode.
- Tests: **pytest** with warnings treated as errors (`-W error`).

### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: a recommendation, a rationale, and a Python example or template.
- Rules marked **(Py-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Avoid recursion.

All control flow SHOULD be simple, explicit, and statically analyzable. AVOID recursion.

Rationale: Predictable, bounded execution is the foundation of safety. Recursion makes it difficult
to prove termination and risks stack overflow.

```python
for index in range(max_iterations):
    process(items[index])

def process(items: list[Item]) -> None:
    if not items:
        return
    process(items[1:])
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work SHOULD have a
fixed upper bound. Where a loop cannot terminate, this SHOULD be asserted.

Rationale: Unbounded work causes infinite loops, tail-latency spikes, and resource exhaustion.

```python
MAX_RETRIES = 5
for attempt in range(MAX_RETRIES):
    if try_connect():
        break
assert attempt < MAX_RETRIES, "connection retries exhausted"
```

### SAF-03 — Use precise types and explicit bounds. Avoid `Any`. **(Py-adapted)**

All values SHOULD have the most precise type possible. AVOID `Any`. Use `typing.NewType` or
`typing.Annotated` to encode units and semantic distinctions. Use `int` for counts and indexes,
and avoid `float` for integral quantities. Range checks SHOULD be explicit at boundaries.

Rationale: Precise types, unit annotations, and runtime guards prevent unit confusion and ambiguity.

```python
from typing import NewType

UserId = NewType("UserId", int)
OrderId = NewType("OrderId", int)

def parse_port(raw: object) -> int:
    assert isinstance(raw, int), "port must be int"
    assert 1 <= raw <= 65535, "port out of range"
    return raw
```

### SAF-04 — Assert all preconditions, postconditions, and invariants.

Every function SHOULD assert its preconditions, postconditions, and invariants.

Rationale: Assertions detect programmer errors early and localize faults.

### SAF-05 — Maintain assertion density of at least 2 per function.

The assertion density of the codebase SHOULD average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs through testing.

### SAF-06 — Pair assertions across different code paths.

CONSIDER adding at least two assertions on different code paths per enforced property.

Rationale: Bugs hide at the boundary between valid and invalid data.

### SAF-07 — Split compound assertions.

PREFER split assertions over compound assertions.

Rationale: Split assertions isolate failure causes and improve readability.

### SAF-08 — Use single-line implication assertions.

PREFER expressing implications as: `if a: assert b`.

Rationale: Preserves logical intent without complex boolean expressions.

### SAF-09 — Assert constants and type relationships.

Constants and type relationships SHOULD be asserted at import time or startup.

Rationale: Catches design integrity violations before runtime.

### SAF-10 — Assert both positive and negative space.

Assertions SHOULD cover both the positive space (expected) and the negative space (not expected).

Rationale: Boundary-crossing bugs are common.

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests SHOULD exercise valid inputs, invalid inputs, and boundary transitions.

Rationale: Most catastrophic failures stem from incorrect handling of non-fatal errors.

### SAF-12 — Avoid unbounded allocations. Pre-size and reuse. **(Py-adapted)**

Allocations in hot paths SHOULD be minimized. Lists and buffers SHOULD be pre-sized where the upper
bound is known. AVOID object creation inside loops when reuse is feasible.

Rationale: Excessive allocation increases GC pressure and tail latency.

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

### SAF-17 — Treat warnings as errors; prefer strict typing. **(Py-adapted)**

`black`, `ruff`, and `mypy --strict` SHOULD pass with no warnings. Tests SHOULD run with warnings
treated as errors (`pytest -W error`).

Rationale: Warnings frequently indicate latent correctness issues.

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

Every error SHOULD be handled explicitly. AVOID silent exception swallowing. Bare `except` SHOULD
NOT be used.

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

### PERF-07 — Be explicit. Do not depend on interpreter optimizations.

Performance-critical code SHOULD be explicit. AVOID relying on interpreter optimizations.

Rationale: Interpreter optimizations are heuristic and fragile.

### PERF-08 — Use primitive arguments in hot loops. Avoid global lookups. **(Py-adapted)**

Hot loop functions SHOULD take primitive arguments directly. Avoid repeated global lookups in tight
loops; bind local variables where helpful.

Rationale: Local variable access is faster than global lookups in Python.

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names SHOULD capture what a thing is or does with precision.

Rationale: Great names are the essence of great code.

### DX-02 — Use snake_case for functions/variables; PascalCase for classes. **(Py-adapted)**

Functions and variables SHOULD use `snake_case`. Classes SHOULD use `PascalCase`. File names
SHOULD use `snake_case`.

Rationale: This is Python's established convention (PEP 8).

### DX-03 — Do not abbreviate names (except trivial loop counters).

Names SHOULD NOT be abbreviated unless the variable is a trivial loop counter.

Rationale: Abbreviations are ambiguous.

### DX-04 — Capitalize acronyms consistently.

Acronyms SHOULD use standard capitalization (HTTPClient, SQLQuery).

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

### DX-11 — Class layout: fields, then types, then methods.

Class definitions SHOULD be ordered: data fields first, then nested types, then methods.

Rationale: Predictable layout.

### DX-12 — Do not overload names that conflict with domain terminology.

AVOID reusing names across different concepts.

Rationale: Overloaded terms cause confusion.

### DX-13 — Prefer nouns over adjectives/participles for externally-referenced names.

Externally-referenced names SHOULD be nouns.

Rationale: Noun names compose cleanly in docs.

### DX-14 — Use named option objects when arguments can be confused.

Functions with confusable arguments SHOULD use named options objects.

Rationale: Prevents silent transposition bugs.

### DX-15 — Name nullable parameters so None's meaning is clear at the call site.

Nullable parameters SHOULD be named so `None` meaning is clear.

Rationale: `foo(None)` is meaningless without context.

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

### CIS-02 — Avoid copying large objects. Pass by reference. **(Py-adapted)**

AVOID copying large objects via `dict(...)`, `list(...)`, or `copy()` in hot paths. PREFER passing
the original reference and using immutability markers.

Rationale: Copying large objects creates GC pressure and can mask mutation bugs.

### CIS-03 — Prefer in-place construction. Avoid intermediate copies. **(Py-adapted)**

Large objects SHOULD be constructed in-place rather than via intermediate objects that are then
copied or updated.

Rationale: Intermediate copies waste memory and CPU cycles.

### CIS-04 — If any field requires builder-pattern init, use it for the whole object. **(Py-adapted)**

If any field requires multi-step initialization, the entire object SHOULD use the same strategy.

Rationale: Mixing initialization strategies makes construction hard to reason about.

### CIS-05 — Declare variables close to use. Shrink scope.

Variables SHOULD be declared and computed as close as possible to their point of use.

Rationale: Minimizes check-to-use gaps.

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

PREFER simpler return types: `None` > `bool` > `int` > `T | None` > `Result`-like.

Rationale: Each dimension creates viral call-site branching.

### CIS-07 — Do not `await` between assertions and dependent code. **(Py-adapted)**

AVOID `await` between an assertion and the code that depends on it. Re-assert after resumption.

Rationale: `await` yields control; preconditions may no longer hold on resume.

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

### OBO-02 — Use explicit division semantics.

Integer division SHOULD use explicit semantics: exact, floor, or ceiling.

Rationale: Explicit division shows intent and rounding behavior.

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter.

All code SHOULD be formatted by `black` (or `ruff format`) with line length 100.

Rationale: Eliminates style debates and ensures consistency.

### FMT-02 — Use 4-space indentation. **(Py-adapted)**

Indentation SHOULD be 4 spaces. Tabs SHOULD NOT be used.

Rationale: 4 spaces is Python's standard indentation depth.

### FMT-03 — Hard limit all lines to 100 columns.

Lines SHOULD NOT exceed 100 columns.

Rationale: Ensures side-by-side review with no horizontal scroll.

### FMT-04 — Python equivalent of braces: one statement per line. **(Py-adapted)**

Use one statement per line. Avoid semicolon-separated statements.

Rationale: Python uses indentation to define scope; multiple statements hide control flow.

---

## Dependencies & Tooling (DEP)

### DEP-01 — Minimize dependencies.

External dependencies SHOULD be minimized and justified.

Rationale: Supply chain risk, safety risk, performance risk, installation complexity.

### DEP-02 — Prefer existing tools over adding new ones.

New tools SHOULD NOT be introduced when an existing tool suffices.

Rationale: Tool sprawl increases complexity and maintenance burden.

### DEP-03 — Prefer Python for scripts and automation. **(Py-adapted)**

Scripts SHOULD be written in Python. Shell scripts only for trivial glue (< 20 lines).

Rationale: Python scripts are portable, type-safe (with mypy), and consistent with the toolchain.

---

## Appendix: Rule Index

| ID | Rule (short form) | Py-adapted? |
|----|-------------------|-------------|
| SAF-01 | Simple explicit control flow; no recursion | |
| SAF-02 | Bound everything | |
| SAF-03 | Precise types; no Any; explicit bounds | Yes |
| SAF-04 | Assert pre/post/invariants | |
| SAF-05 | Assertion density ≥ 2/function | |
| SAF-06 | Pair assertions across paths | |
| SAF-07 | Split compound assertions | |
| SAF-08 | Single-line implication asserts | |
| SAF-09 | Assert constants and type relationships | |
| SAF-10 | Assert positive and negative space | |
| SAF-11 | Test valid, invalid, and boundary | |
| SAF-12 | Avoid unbounded allocations; pre-size; reuse | Yes |
| SAF-13 | Smallest possible variable scope | |
| SAF-14 | ~70-line function limit | |
| SAF-15 | Centralize control flow in parent | |
| SAF-16 | Centralize state mutation; pure leaves | |
| SAF-17 | black/ruff/mypy strict; warnings as errors | Yes |
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
| PERF-07 | Explicit; no interpreter reliance | |
| PERF-08 | Primitive args in hot loops; local bindings | Yes |
| DX-01 | Precise nouns and verbs | |
| DX-02 | snake_case vars/fns, PascalCase classes | Yes |
| DX-03 | No abbreviations | |
| DX-04 | Consistent acronym capitalization | |
| DX-05 | Units/qualifiers appended last | |
| DX-06 | Meaningful lifecycle names | |
| DX-07 | Align related names by length | |
| DX-08 | Prefix helpers with caller name | |
| DX-09 | Callbacks last in params | |
| DX-10 | Public API first in file | |
| DX-11 | Class: fields → types → methods | |
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
| CIS-02 | No copies of large objects in hot paths | Yes |
| CIS-03 | In-place construction; no intermediate copies | Yes |
| CIS-04 | Consistent init strategy per object | Yes |
| CIS-05 | Declare close to use | |
| CIS-06 | Simpler return types | |
| CIS-07 | No await between assert and use | Yes |
| CIS-08 | Guard against buffer bleeds | |
| CIS-09 | Group alloc/dealloc visually | |
| OBO-01 | Index ≠ count ≠ size | |
| OBO-02 | Explicit division semantics | |
| FMT-01 | Run black/ruff format | |
| FMT-02 | 4-space indent | Yes |
| FMT-03 | 100-column hard limit | |
| FMT-04 | One statement per line (Python equivalent) | Yes |
| DEP-01 | Minimize dependencies | |
| DEP-02 | Prefer existing tools | |
| DEP-03 | Python for scripts | Yes |
