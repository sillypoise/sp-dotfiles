# TigerStyle Rulebook — React (TypeScript) / Pragmatic / Full

## Preamble

### Purpose

This is the React-specific TigerStyle rulebook. It merges TigerStyle heuristics with React best
practices for React DOM, React Native, and React Server Components (RSC). Rule IDs match the base
TigerStyle for cross-referencing. This is the pragmatic variant: strong recommendations with
documented exceptions.

### Design Goal Priority

All rules serve three design goals, in this order:

1. Safety
2. Performance
3. Developer Experience

When goals conflict, higher-priority goals win.

### Keyword Definitions

- SHOULD — Strong recommendation.
- PREFER — Default choice.
- CONSIDER — Evaluate in context.
- AVOID — Strong discouragement.

### Exception Clause

Any rule in this document may be overridden in a specific instance if:

1. The exception is documented in a code comment or commit message.
2. The comment explains why the rule does not apply.
3. The exception is reviewed and approved by at least one other contributor.

Undocumented exceptions are violations.

### React Baseline

- Language: TypeScript with `strict: true`.
- Linting: `oxc` with React + TS rules.
- React Compiler: enable when available; follow compiler constraints.

### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: a recommendation, a rationale, and a React/TypeScript example or template.
- Rules marked **(React-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Avoid recursion.

All control flow SHOULD be simple, explicit, and statically analyzable. AVOID recursion.

Rationale: React render paths are hard to reason about when recursion hides termination.

```tsx
function renderList(items: Item[]) {
  return items.map((item) => <Row key={item.id} item={item} />)
}
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and backoffs SHOULD have fixed upper bounds.

Rationale: Unbounded work causes lockups and tail-latency spikes.

```ts
for (let retry = 0; retry < maxRetries; retry += 1) {
  if (await tryConnect()) break
}
```

### SAF-03 — Use explicit domain types. Avoid implicit coercion. **(React-adapted)**

Numeric domains (ids, counts, indexes) SHOULD be explicit and not rely on implicit coercion.
Avoid `any` and unsafe casts.

Rationale: Type ambiguity is the main source of UI edge-case bugs.

```ts
type UserId = string & { readonly brand: unique symbol }
```

### SAF-04 — Assert preconditions, postconditions, and invariants.

Functions SHOULD assert their preconditions, postconditions, and invariants.

Rationale: UI bugs are easier to detect when invalid states fail fast.

React note: render must be pure. Do not read browser APIs or perform side effects during render.
Move browser reads to effects or pre-hydration scripts.

```ts
if (!user) throw new Error('User must be loaded before rendering profile.')
```

### SAF-05 — Maintain assertion density (>= 2 per function).

The codebase SHOULD average at least two assertions per function.

Rationale: Assertions surface latent bugs earlier in dev and tests.

```ts
if (items.length === 0) throw new Error('Items required.')
if (items.length > MAX_ITEMS) throw new Error('Too many items.')
```

### SAF-06 — Pair assertions across code paths.

CONSIDER adding at least two assertions on different code paths per enforced property.

Rationale: Bugs hide at boundary transitions.

### SAF-07 — Split compound assertions.

PREFER split assertions over compound conditions.

Rationale: Split assertions isolate failure causes.

```ts
if (!isReady) throw new Error('Not ready.')
if (!hasAccess) throw new Error('Access required.')
```

### SAF-08 — Use single-line implication asserts.

PREFER implication checks as `if (a) assert(b)`.

Rationale: Preserves logical intent.

```ts
if (isHydrated) {
  if (!nodeRef.current) throw new Error('Hydrated render must have a node.')
}
```

### SAF-09 — Assert constants and environment constraints.

Compile-time constants and environment requirements SHOULD be asserted at startup.

Rationale: Configuration mismatches are correctness failures.

React note: SSR paths must not require `window`/`document`. Guard access explicitly.

```ts
if (!process.env.API_URL) throw new Error('API_URL is required.')
```

### SAF-10 — Assert both positive and negative space.

Assertions SHOULD cover expected and not-expected ranges.

Rationale: Boundary bugs are common in UI state.

### SAF-11 — Test valid, invalid, and boundary transitions.

Tests SHOULD cover valid inputs, invalid inputs, and boundary transitions.

Rationale: Most failures are invalid state transitions.

### SAF-12 — Avoid unbounded allocations in render. **(React-adapted)**

PREFER static allocations and reuse in hot paths. Avoid per-render allocations when costly.

Rationale: Render allocations are a primary source of jank.

```ts
const EMPTY: Item[] = []
```

### SAF-13 — Declare variables at the smallest scope.

Variables SHOULD be declared at the smallest possible scope.

Rationale: Reduces misuse in complex components.

### SAF-14 — Keep functions short (~70 lines).

Functions SHOULD NOT exceed ~70 lines, including components and hooks.

Rationale: Short components are easier to reason about.

### SAF-15 — Centralize control flow in parent functions.

Branching logic SHOULD remain in parent components. Helpers SHOULD be pure.

Rationale: Centralized control flow reduces hidden branches.

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

State mutation SHOULD occur in parent handlers or reducers. Helpers SHOULD be pure.

Rationale: Pure helpers enable predictable renders.

```ts
const [state, dispatch] = useReducer(reducer, initial)
```

### SAF-17 — Treat warnings as errors; use strict tooling. **(React-adapted)**

All compiler/linter warnings SHOULD be enabled and resolved. TypeScript `strict` and `oxc`
rules SHOULD be enforced.

Rationale: Warnings indicate latent correctness issues.

### SAF-18 — Batch external events. **(React-adapted)**

External events SHOULD be batched and processed in controlled updates.

Rationale: Batching prevents render storms.

React note: user interactions belong in event handlers. Effects are only for external
synchronization. Use transitions for non-urgent updates.

```ts
startTransition(() => setQuery(nextQuery))
```

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions SHOULD be split into nested branches.

Rationale: Explicit branches are easier to verify.

### SAF-20 — State invariants positively.

PREFER positive form; AVOID negations.

Rationale: Positive statements reduce logical errors.

### SAF-21 — Handle all errors explicitly. **(React-adapted)**

Errors SHOULD be handled explicitly. AVOID ignored promises or silent catches.

Rationale: Silent failures mask UI corruption.

React note: use Error Boundaries for render-time failures and handle async rejections.

```ts
try {
  await save()
} catch (error) {
  report(error)
}
```

### SAF-22 — Always state the why.

Non-obvious decisions SHOULD have a “why” comment or commit message.

Rationale: Maintainers need the rationale, not the restatement.

### SAF-23 — Pass explicit options. Avoid defaults.

All options SHOULD be passed explicitly to library calls.

Rationale: Defaults change and cause regressions.

```ts
fetch(url, { method: 'GET', cache: 'no-store' })
```

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance SHOULD be considered during design, not deferred to profiling.

Rationale: Architecture-level wins cannot be retrofitted.

### PERF-02 — Perform back-of-the-envelope resource sketches.

Rough calculations SHOULD be done for network, memory, and CPU.

Rationale: Simple math prevents obviously impossible designs.

### PERF-03 — Optimize the slowest resource first.

Optimization SHOULD target the slowest resource, weighted by frequency.

Rationale: Bottleneck-focused optimization yields the biggest gains.

### PERF-04 — Separate control plane from data plane.

Control flow and data processing SHOULD be separated.

Rationale: Separation enables batching and predictable flow.

### PERF-05 — Amortize costs via batching.

Costs SHOULD be amortized by batching (e.g., lists, updates, network calls).

Rationale: Per-item overhead dominates at scale.

React note: virtualize long lists (DOM and RN) and batch UI updates with transitions.

### PERF-06 — Keep CPU work predictable.

Hot paths SHOULD have predictable, linear control flow.

Rationale: Predictable work uses caches effectively.

### PERF-07 — Be explicit. Avoid compiler magic.

Performance-critical code SHOULD be explicit. AVOID relying on compiler heuristics.

Rationale: Compiler heuristics are fragile.

### PERF-08 — Use primitive arguments in hot loops. **(React-adapted)**

Hot path components SHOULD receive primitives or stable references.

Rationale: Stable props reduce re-renders and memo misses.

React note: avoid inline objects/functions in list items; prefer stable callbacks.

```tsx
<Row id={item.id} title={item.title} />
```

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names SHOULD capture what a thing is or does with precision.

Rationale: Good names are the essence of good code.

### DX-02 — Use React/TypeScript naming conventions. **(React-adapted)**

Functions/variables SHOULD use lowerCamelCase; components use UpperCamelCase.

Rationale: Consistency improves tooling and readability.

### DX-03 — Do not abbreviate names.

Names SHOULD NOT be abbreviated except trivial loop counters.

Rationale: Abbreviations are ambiguous.

### DX-04 — Capitalize acronyms consistently.

Acronyms SHOULD use standard capitalization (HTTPClient, SQLQuery).

Rationale: Consistent acronyms reduce confusion.

### DX-05 — Append units and qualifiers at the end.

Units and qualifiers SHOULD be appended to names, sorted by significance.

Rationale: Related names align visually.

### DX-06 — Use meaningful lifecycle names.

Resource names SHOULD convey lifecycle and ownership.

Rationale: Cleanup expectations must be obvious.

### DX-07 — Align related names by length when feasible.

CONSIDER aligning names for related variables.

Rationale: Visual symmetry reduces mistakes.

### DX-08 — Prefix helpers with caller name.

Helpers SHOULD be prefixed with the caller’s name.

Rationale: Names show call hierarchy.

### DX-09 — Callbacks go last in parameter lists.

Callback parameters SHOULD be last.

Rationale: Mirrors control flow.

### DX-10 — Public API first.

Public API SHOULD appear first in a file.

Rationale: Files are read top-down.

### DX-11 — Struct/class layout: fields → types → methods.

Struct/class layout SHOULD be predictable.

Rationale: Navigability matters at scale.

### DX-12 — Avoid overloaded domain terms.

AVOID names that mean two things in the same system.

Rationale: Overloaded terms cause confusion.

### DX-13 — Prefer nouns for externally referenced names.

Externally referenced names SHOULD be nouns.

Rationale: Noun names compose cleanly.

### DX-14 — Use named option objects for confusable args.

Confusable arguments SHOULD use named option objects.

Rationale: Prevents silent swaps.

```ts
type FetchOptions = { url: string; retries: number }
```

### DX-15 — Name nullable parameters for clarity.

Nullable parameters SHOULD make `null`/`undefined` meaning clear.

Rationale: `foo(undefined)` is meaningless without context.

### DX-16 — Singleton params ordered general → specific.

Singleton constructor params SHOULD be ordered from general to specific.

Rationale: Consistent ordering reduces cognitive load.

### DX-17 — Write descriptive commit messages.

Commit messages SHOULD explain the purpose of the change.

Rationale: Commit history is permanent documentation.

### DX-18 — Explain “why” in comments.

Comments SHOULD explain why, not what.

Rationale: “Why” enables safe changes.

### DX-19 — Tests and complex logic explain “how”.

Tests SHOULD describe goal and methodology.

Rationale: Tests are documentation.

### DX-20 — Comments are well-formed sentences.

Comments SHOULD be complete sentences.

Rationale: Precision signals careful thinking.

---

## Cache Invalidation & State Hygiene (CIS)

### CIS-01 — Single source of truth.

Every piece of state SHOULD have exactly one source of truth.

Rationale: Duplicate state desynchronizes.

React note: prefer derived state and fallback patterns (`value ?? prop`). Use
`useSyncExternalStore` for external sources of truth.

```tsx
const total = items.reduce(sum, 0)
```

### CIS-02 — Avoid passing large objects by value. **(React-adapted)**

Large objects SHOULD not be passed as props when an id or primitive suffices.

Rationale: Large props cause re-render churn.

### CIS-03 — Prefer lazy initialization for expensive state. **(React-adapted)**

Expensive initial state SHOULD be computed lazily.

Rationale: Avoids work on every render.

```ts
const [state] = useState(() => buildInitialState())
```

### CIS-04 — If any state is derived, derive all. **(React-adapted)**

If a value can be derived, the entire derived chain SHOULD be derived at render time.

Rationale: Mixed storage causes drift.

React note: avoid syncing state in effects; use keys to reset state or derive in render.

### CIS-05 — Declare variables close to use.

Variables SHOULD be declared and computed near use.

Rationale: Reduces TOCTOU errors.

### CIS-06 — Prefer simpler return types.

PREFER simpler return types: void > bool > number > optional > Result.

Rationale: Simpler types reduce call-site branching.

### CIS-07 — Do not suspend between assertion and use. **(React-adapted)**

Do not `await` between a guard and its dependent use; re-assert after suspension.

Rationale: Suspension can invalidate preconditions.

### CIS-08 — Guard against buffer bleeds. **(React-adapted)**

If using typed arrays or binary buffers, unused space SHOULD be zeroed.

Rationale: Buffer underflow can leak data.

### CIS-09 — Group setup and cleanup in effects. **(React-adapted)**

Setup and cleanup SHOULD be visually grouped in a single effect.

Rationale: Reduces resource leaks in subscriptions.

React note: prefer `useSyncExternalStore` over manual subscribe/unsubscribe when possible.

```ts
useEffect(() => {
  const stop = subscribe(handler)
  return () => stop()
}, [handler])
```

---

## Off-by-One & Arithmetic (OBO)

### OBO-01 — Index, count, and size are distinct.

Indexes, counts, and sizes SHOULD be treated as distinct concepts.

Rationale: Off-by-one errors dominate list bugs.

### OBO-02 — Use explicit division semantics.

Division semantics SHOULD be explicit (exact, floor, ceiling).

Rationale: Implicit rounding is error-prone.

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter.

All code SHOULD be formatted by the project formatter.

Rationale: Automated formatting reduces review noise.

### FMT-02 — Use the project’s indentation standard.

Indentation SHOULD follow the project standard (default 2 spaces in JS/TS).

Rationale: Consistent indentation improves scanning.

### FMT-03 — Keep lines under 100 columns.

Lines SHOULD NOT exceed 100 columns.

Rationale: Side-by-side review needs short lines.

### FMT-04 — Use braces on if statements.

If statements SHOULD have braces unless single-line.

Rationale: Braces prevent “goto fail” bugs.

---

## Dependencies & Tooling (DEP)

### DEP-01 — Minimize dependencies.

Dependencies SHOULD be minimized and justified.

Rationale: Every dependency is risk and cost.

### DEP-02 — Prefer existing tools.

New tools SHOULD NOT be introduced when existing tools suffice.

Rationale: Tool sprawl increases maintenance cost.

### DEP-03 — Prefer typed tooling for scripts. **(React-adapted)**

Scripts SHOULD be written in typed, portable languages (TypeScript, Node). Shell only for
trivial glue.

Rationale: Typed scripts are safer and more portable.

---

## Appendix: Rule Index

| ID | Rule (short form) | React-adapted? |
|----|-------------------|----------------|
| SAF-01 | Simple explicit control flow; no recursion | |
| SAF-02 | Bound everything | |
| SAF-03 | Explicit domain types; avoid coercion | Yes |
| SAF-04 | Assert pre/post/invariants | |
| SAF-05 | Assertion density ≥ 2/function | |
| SAF-06 | Pair assertions across paths | |
| SAF-07 | Split compound assertions | |
| SAF-08 | Single-line implication asserts | |
| SAF-09 | Assert constants and env | Yes |
| SAF-10 | Assert positive and negative space | |
| SAF-11 | Test valid, invalid, and boundary | |
| SAF-12 | Avoid unbounded render allocations | Yes |
| SAF-13 | Smallest possible variable scope | |
| SAF-14 | ~70-line function limit | |
| SAF-15 | Centralize control flow in parent | |
| SAF-16 | Centralize state mutation; pure leaves | |
| SAF-17 | Strict warnings and lint | Yes |
| SAF-18 | Batch external events | Yes |
| SAF-19 | Split compound conditions | |
| SAF-20 | Positive invariants; no negations | |
| SAF-21 | Handle all errors explicitly | Yes |
| SAF-22 | Always state the why | |
| SAF-23 | Explicit options; no defaults | |
| PERF-01 | Design for performance from start | |
| PERF-02 | Back-of-envelope resource sketches | |
| PERF-03 | Optimize slowest resource first | |
| PERF-04 | Separate control and data planes | |
| PERF-05 | Amortize via batching | |
| PERF-06 | Predictable CPU work | |
| PERF-07 | Explicit; no compiler reliance | |
| PERF-08 | Primitive args in hot paths | Yes |
| DX-01 | Precise nouns and verbs | |
| DX-02 | React naming conventions | Yes |
| DX-03 | No abbreviations | |
| DX-04 | Consistent acronym capitalization | |
| DX-05 | Units/qualifiers appended last | |
| DX-06 | Meaningful lifecycle names | |
| DX-07 | Align related names by length | |
| DX-08 | Prefix helpers with caller name | |
| DX-09 | Callbacks last in params | |
| DX-10 | Public API first in file | |
| DX-11 | Struct/class layout order | |
| DX-12 | No overloaded domain terms | |
| DX-13 | Noun names for external reference | |
| DX-14 | Named options for confusable args | |
| DX-15 | Name nullable params clearly | |
| DX-16 | Singletons general → specific | |
| DX-17 | Descriptive commit messages | |
| DX-18 | Explain "why" in comments | |
| DX-19 | Explain "how" in tests | |
| DX-20 | Comments are sentences | |
| CIS-01 | No state duplication or aliasing | |
| CIS-02 | Avoid large object props | Yes |
| CIS-03 | Lazy init for expensive state | Yes |
| CIS-04 | Derived state stays derived | Yes |
| CIS-05 | Declare close to use | |
| CIS-06 | Simpler return types | |
| CIS-07 | No suspension with active assertions | Yes |
| CIS-08 | Guard against buffer bleeds | Yes |
| CIS-09 | Group setup/cleanup in effects | Yes |
| OBO-01 | Index ≠ count ≠ size | |
| OBO-02 | Explicit division semantics | |
| FMT-01 | Run the formatter | |
| FMT-02 | Use project indentation | Yes |
| FMT-03 | 100-column hard limit | |
| FMT-04 | Braces on if (unless single-line) | |
| DEP-01 | Minimize dependencies | |
| DEP-02 | Prefer existing tools | |
| DEP-03 | Typed portable scripts | Yes |
