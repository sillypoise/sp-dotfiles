# TigerStyle Rulebook — React (TypeScript) / Strict / Compact

## Preamble

Compact React variant of TigerStyle Strict. For full rationale and examples, see
`tigerstyle-react-strict-full.md`.

**Design goal priority:** Safety > Performance > Developer Experience.

**Keywords:** MUST, SHALL, MUST NOT — absolute requirements.

**React baseline:** TypeScript strict, oxc linting, React Compiler when available.

Rule IDs are stable across all TigerStyle variants for cross-referencing.
Rules marked **(React)** are adapted from base TigerStyle.

---

## Safety & Correctness (SAF)

**SAF-01** — All control flow MUST be simple and explicit. Recursion MUST NOT be used.
Rationale: Bounded, analyzable execution.

**SAF-02** — All loops, queues, retries, buffers MUST have fixed upper bounds.
Rationale: Prevents infinite work and tail-latency spikes.

**SAF-03** **(React)** — Use explicit domain types; `any` and implicit coercion MUST NOT be used.
Rationale: Ambiguous types cause UI edge-case bugs.

**SAF-04** — Functions MUST assert preconditions, postconditions, invariants.
Rationale: Fail fast on invalid state.

**SAF-05** — Assertion density MUST average ≥2 per function.
Rationale: Assertions surface latent bugs early.

**SAF-06** — Every enforced property MUST have paired assertions across paths.
Rationale: Bugs hide at boundaries.

**SAF-07** — Compound assertions MUST be split into independent checks.
Rationale: Split checks isolate failure causes.

**SAF-08** — Implication asserts MUST be single-line `if (a) assert(b)`.
Rationale: Clearer logical intent.

**SAF-09** **(React)** — Constants and env requirements MUST be asserted at startup.
Rationale: Config mismatches are correctness failures.

**SAF-10** — Assertions MUST cover positive and negative space.
Rationale: Boundary-crossing bugs are common.

**SAF-11** — Tests MUST cover valid, invalid, and boundary transitions.
Rationale: Most failures are invalid transitions.

**SAF-12** **(React)** — Unbounded allocations in render/hot paths MUST be avoided.
Rationale: Render allocations cause jank.

**SAF-13** — Variables MUST be declared at the smallest scope.
Rationale: Minimizes misuse.

**SAF-14** — Functions MUST NOT exceed ~70 lines.
Rationale: Enforces clean decomposition.

**SAF-15** — Branching MUST remain in parent components; helpers MUST be pure.
Rationale: Centralizes control flow.

**SAF-16** — State mutation MUST be centralized; leaf helpers MUST be pure.
Rationale: Predictable renders.

**SAF-17** **(React)** — Warnings MUST be treated as errors; TS strict + oxc enforced.
Rationale: Warnings hide correctness issues.

**SAF-18** **(React)** — External events MUST be batched.
Rationale: Prevents render storms.

**SAF-19** — Compound conditions MUST be split into nested branches.
Rationale: Explicit case coverage.

**SAF-20** — Invariants MUST be stated positively. Negations MUST NOT be used.
Rationale: Positive form is clearer.

**SAF-21** **(React)** — Errors MUST be handled explicitly. Silent catches MUST NOT be used.
Rationale: Silent failures corrupt UI state.

**SAF-22** — Non-obvious decisions MUST include a “why” comment.
Rationale: Rationale enables safe change.

**SAF-23** — All options MUST be passed explicitly. Defaults MUST NOT be relied on.
Rationale: Defaults change across versions.

---

## Performance & Design (PERF)

**PERF-01** — Performance MUST be considered during design.
Rationale: Architecture wins cannot be retrofitted.

**PERF-02** — Back-of-the-envelope resource sketches MUST be done.
Rationale: Rough math keeps designs realistic.

**PERF-03** — Optimization MUST target the slowest resource first.
Rationale: Bottleneck-focused wins are largest.

**PERF-04** — Control and data planes MUST be separated.
Rationale: Enables batching and predictability.

**PERF-05** — Costs MUST be amortized via batching.
Rationale: Per-item overhead dominates at scale.

**PERF-06** — Hot paths MUST be predictable and linear.
Rationale: Predictable work uses caches well.

**PERF-07** — Performance-critical code MUST be explicit.
Rationale: Compiler heuristics are fragile.

**PERF-08** **(React)** — Hot components MUST take primitives/stable refs.
Rationale: Stable props reduce re-renders.

---

## Developer Experience & Naming (DX)

**DX-01** — Names MUST capture what a thing is or does.
Rationale: Clear names are the essence of clear code.

**DX-02** **(React)** — Use React/TS naming conventions (camelCase, PascalCase).
Rationale: Consistency improves tooling and readability.

**DX-03** — Names MUST NOT be abbreviated.
Rationale: Abbreviations are ambiguous.

**DX-04** — Acronyms MUST use standard capitalization.
Rationale: Standard form is unambiguous.

**DX-05** — Units/qualifiers MUST be appended last.
Rationale: Related names align visually.

**DX-06** — Resource names MUST convey lifecycle/ownership.
Rationale: Cleanup expectations are obvious.

**DX-07** — Related names SHOULD be aligned by length when feasible.
Rationale: Symmetry improves parsing.

**DX-08** — Helper names MUST be prefixed with caller name.
Rationale: Makes call hierarchy visible.

**DX-09** — Callbacks MUST be last parameters.
Rationale: Mirrors control flow.

**DX-10** — Public API MUST appear first in a file.
Rationale: Files are read top-down.

**DX-11** — Struct/class layout MUST be fields → types → methods.
Rationale: Predictable layout aids navigation.

**DX-12** — Domain terms MUST NOT be overloaded.
Rationale: Overloaded terms cause confusion.

**DX-13** — Externally referenced names MUST be nouns.
Rationale: Noun names compose cleanly.

**DX-14** — Confusable args MUST use named option objects.
Rationale: Prevents silent swaps.

**DX-15** — Nullable params MUST be named to clarify null meaning.
Rationale: `foo(undefined)` is meaningless otherwise.

**DX-16** — Singleton params MUST be ordered general → specific.
Rationale: Consistent ordering reduces cognitive load.

**DX-17** — Commit messages MUST explain purpose.
Rationale: History is permanent documentation.

**DX-18** — Comments MUST explain “why,” not “what.”
Rationale: Rationale enables safe change.

**DX-19** — Tests MUST explain goal and method.
Rationale: Tests are documentation.

**DX-20** — Comments MUST be well-formed sentences.
Rationale: Precision signals careful thinking.

---

## Cache Invalidation & State Hygiene (CIS)

**CIS-01** — State MUST have one source of truth.
Rationale: Duplicate state desynchronizes.

**CIS-02** **(React)** — Large objects MUST NOT be passed as props.
Rationale: Large props trigger re-render churn.

**CIS-03** **(React)** — Expensive state MUST use lazy init.
Rationale: Avoids work on each render.

**CIS-04** **(React)** — If derivable, all derived state MUST be derived.
Rationale: Mixed storage causes drift.

**CIS-05** — Variables MUST be declared close to use.
Rationale: Reduces TOCTOU errors.

**CIS-06** — Return types MUST prefer: void > bool > number > optional > Result.
Rationale: Simpler types reduce branching.

**CIS-07** **(React)** — Do not `await` between guard and use.
Rationale: Suspension invalidates preconditions.

**CIS-08** **(React)** — Unused typed-buffer space MUST be zeroed.
Rationale: Prevents buffer bleeds.

**CIS-09** **(React)** — Effect setup and cleanup MUST be grouped.
Rationale: Reduces resource leaks.

---

## Off-by-One & Arithmetic (OBO)

**OBO-01** — Index, count, size MUST be treated distinctly.
Rationale: Off-by-one is the dominant list bug.

**OBO-02** — Division semantics MUST be explicit.
Rationale: Implicit rounding is error-prone.

---

## Formatting & Code Style (FMT)

**FMT-01** — Code MUST be formatted by the project formatter.
Rationale: Eliminates style debates.

**FMT-02** — Indentation MUST follow project standard.
Rationale: Consistent indentation improves scanning.

**FMT-03** — Lines MUST NOT exceed 100 columns.
Rationale: Side-by-side review needs short lines.

**FMT-04** — If statements MUST use braces unless single-line.
Rationale: Prevents “goto fail” bugs.

---

## Dependencies & Tooling (DEP)

**DEP-01** — Dependencies MUST be minimized and justified.
Rationale: Dependencies add risk and cost.

**DEP-02** — New tools MUST NOT be introduced if existing ones suffice.
Rationale: Tool sprawl increases maintenance.

**DEP-03** **(React)** — Scripts MUST be typed; shell only for trivial glue.
Rationale: Typed scripts are safer and portable.
