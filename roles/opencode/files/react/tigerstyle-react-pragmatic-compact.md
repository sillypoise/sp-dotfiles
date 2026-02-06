# TigerStyle Rulebook — React (TypeScript) / Pragmatic / Compact

## Preamble

Compact React variant of TigerStyle Pragmatic. For full rationale and examples, see
`tigerstyle-react-pragmatic-full.md`.

**Design goal priority:** Safety > Performance > Developer Experience.

**Keywords:** SHOULD, PREFER, CONSIDER, AVOID — strong recommendations that acknowledge tradeoffs.

**Exception clause:** Any rule may be overridden if the exception is documented in a code comment
or commit message explaining why, and reviewed by at least one other contributor.

**React baseline:** TypeScript strict, oxc linting, React Compiler when available.

Rule IDs are stable across all TigerStyle variants for cross-referencing.
Rules marked **(React)** are adapted from base TigerStyle.

---

## Safety & Correctness (SAF)

**SAF-01** — All control flow SHOULD be simple and explicit. AVOID recursion.
Rationale: Bounded, analyzable execution.

**SAF-02** — All loops, queues, retries, buffers SHOULD have fixed upper bounds.
Rationale: Prevents infinite work and tail-latency spikes.

**SAF-03** **(React)** — Use explicit domain types; AVOID implicit coercion and `any`.
Rationale: Ambiguous types cause UI edge-case bugs.

**SAF-04** — Functions SHOULD assert preconditions, postconditions, invariants.
Rationale: Fail fast on invalid state.

**SAF-05** — Assertion density SHOULD average ≥2 per function.
Rationale: Assertions surface latent bugs early.

**SAF-06** — CONSIDER paired assertions across code paths.
Rationale: Bugs hide at boundaries.

**SAF-07** — PREFER split assertions over compound checks.
Rationale: Split checks isolate failure causes.

**SAF-08** — PREFER single-line implication asserts.
Rationale: Clearer logical intent.

**SAF-09** **(React)** — Assert constants and environment requirements at startup.
Rationale: Config mismatches are correctness failures.

**SAF-10** — Assertions SHOULD cover positive and negative space.
Rationale: Boundary-crossing bugs are common.

**SAF-11** — Tests SHOULD cover valid, invalid, and boundary transitions.
Rationale: Most failures are invalid transitions.

**SAF-12** **(React)** — AVOID unbounded allocations in render/hot paths.
Rationale: Render allocations cause jank.

**SAF-13** — Variables SHOULD be declared at the smallest scope.
Rationale: Minimizes misuse.

**SAF-14** — Functions SHOULD NOT exceed ~70 lines.
Rationale: Enforces clean decomposition.

**SAF-15** — Branching SHOULD remain in parent components; helpers stay pure.
Rationale: Centralizes control flow.

**SAF-16** — State mutation SHOULD be centralized; leaf helpers pure.
Rationale: Predictable renders.

**SAF-17** **(React)** — Treat warnings as errors; enforce TS strict + oxc.
Rationale: Warnings hide correctness issues.

**SAF-18** **(React)** — External events SHOULD be batched.
Rationale: Prevents render storms.

**SAF-19** — Compound conditions SHOULD be split into nested branches.
Rationale: Explicit case coverage.

**SAF-20** — PREFER positive invariants. AVOID negations.
Rationale: Positive form is clearer.

**SAF-21** **(React)** — Handle errors explicitly; AVOID silent catches.
Rationale: Silent failures corrupt UI state.

**SAF-22** — Non-obvious decisions SHOULD include a “why” comment.
Rationale: Rationale enables safe change.

**SAF-23** — All options SHOULD be passed explicitly. AVOID defaults.
Rationale: Defaults change across versions.

---

## Performance & Design (PERF)

**PERF-01** — Performance SHOULD be considered during design.
Rationale: Architecture wins cannot be retrofitted.

**PERF-02** — Back-of-the-envelope resource sketches SHOULD be done.
Rationale: Rough math keeps designs realistic.

**PERF-03** — Optimize the slowest resource first.
Rationale: Bottleneck-focused wins are largest.

**PERF-04** — Separate control plane from data plane.
Rationale: Enables batching and predictability.

**PERF-05** — Amortize costs via batching.
Rationale: Per-item overhead dominates at scale.

**PERF-06** — Hot paths SHOULD be predictable and linear.
Rationale: Predictable work uses caches well.

**PERF-07** — Performance-critical code SHOULD be explicit.
Rationale: Compiler heuristics are fragile.

**PERF-08** **(React)** — Hot components SHOULD take primitives/stable refs.
Rationale: Stable props reduce re-renders.

---

## Developer Experience & Naming (DX)

**DX-01** — Names SHOULD capture what a thing is or does.
Rationale: Clear names are the essence of clear code.

**DX-02** **(React)** — Use React/TS naming conventions (camelCase, PascalCase).
Rationale: Consistency improves tooling and readability.

**DX-03** — Names SHOULD NOT be abbreviated.
Rationale: Abbreviations are ambiguous.

**DX-04** — Acronyms SHOULD use standard capitalization.
Rationale: Standard form is unambiguous.

**DX-05** — Units/qualifiers SHOULD be appended last.
Rationale: Related names align visually.

**DX-06** — Resource names SHOULD convey lifecycle/ownership.
Rationale: Cleanup expectations are obvious.

**DX-07** — CONSIDER aligning related names by length.
Rationale: Symmetry improves parsing.

**DX-08** — Helper names SHOULD be prefixed with caller name.
Rationale: Makes call hierarchy visible.

**DX-09** — Callbacks SHOULD be last parameters.
Rationale: Mirrors control flow.

**DX-10** — Public API SHOULD appear first in a file.
Rationale: Files are read top-down.

**DX-11** — Struct/class layout SHOULD be fields → types → methods.
Rationale: Predictable layout aids navigation.

**DX-12** — AVOID overloaded domain terms.
Rationale: Overloaded terms cause confusion.

**DX-13** — Externally referenced names SHOULD be nouns.
Rationale: Noun names compose cleanly.

**DX-14** — Confusable args SHOULD use named option objects.
Rationale: Prevents silent swaps.

**DX-15** — Nullable params SHOULD be named to clarify null meaning.
Rationale: `foo(undefined)` is meaningless otherwise.

**DX-16** — Singleton params SHOULD be ordered general → specific.
Rationale: Consistent ordering reduces cognitive load.

**DX-17** — Commit messages SHOULD explain purpose.
Rationale: History is permanent documentation.

**DX-18** — Comments SHOULD explain “why,” not “what.”
Rationale: Rationale enables safe change.

**DX-19** — Tests SHOULD explain goal and method.
Rationale: Tests are documentation.

**DX-20** — Comments SHOULD be well-formed sentences.
Rationale: Precision signals careful thinking.

---

## Cache Invalidation & State Hygiene (CIS)

**CIS-01** — State SHOULD have one source of truth.
Rationale: Duplicate state desynchronizes.

**CIS-02** **(React)** — Avoid passing large objects as props.
Rationale: Large props trigger re-render churn.

**CIS-03** **(React)** — Expensive state SHOULD use lazy init.
Rationale: Avoids work on each render.

**CIS-04** **(React)** — If derivable, derive all (avoid mixed storage).
Rationale: Mixed storage causes drift.

**CIS-05** — Declare variables close to use.
Rationale: Reduces TOCTOU errors.

**CIS-06** — PREFER simpler return types: void > bool > number > optional > Result.
Rationale: Simpler types reduce branching.

**CIS-07** **(React)** — Do not `await` between guard and use.
Rationale: Suspension invalidates preconditions.

**CIS-08** **(React)** — Zero unused buffer space when using typed arrays.
Rationale: Prevents buffer bleeds.

**CIS-09** **(React)** — Group setup and cleanup in effects.
Rationale: Reduces resource leaks.

---

## Off-by-One & Arithmetic (OBO)

**OBO-01** — Index, count, size SHOULD be treated distinctly.
Rationale: Off-by-one is the dominant list bug.

**OBO-02** — Division semantics SHOULD be explicit.
Rationale: Implicit rounding is error-prone.

---

## Formatting & Code Style (FMT)

**FMT-01** — Code SHOULD be formatted by the project formatter.
Rationale: Eliminates style debates.

**FMT-02** — Indentation SHOULD follow project standard.
Rationale: Consistent indentation improves scanning.

**FMT-03** — Lines SHOULD NOT exceed 100 columns.
Rationale: Side-by-side review needs short lines.

**FMT-04** — If statements SHOULD use braces unless single-line.
Rationale: Prevents “goto fail” bugs.

---

## Dependencies & Tooling (DEP)

**DEP-01** — Dependencies SHOULD be minimized and justified.
Rationale: Dependencies add risk and cost.

**DEP-02** — New tools SHOULD NOT be introduced if existing ones suffice.
Rationale: Tool sprawl increases maintenance.

**DEP-03** **(React)** — Scripts SHOULD be typed; shell only for trivial glue.
Rationale: Typed scripts are safer and portable.
