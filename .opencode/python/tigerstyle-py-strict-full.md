# TigerStyle Rulebook — Python / Strict / Full

## Preamble

### Purpose

This document is a comprehensive Python 3 rulebook derived from TigerBeetle's TigerStyle. It is
intended to be dropped into any Python codebase as part of an `AGENTS.md` file, a system prompt, or
a code review checklist. Every rule is actionable and enforceable.

This is the **Python-specific** variant. Rule IDs match the language-agnostic TigerStyle rulebook
for cross-referencing. Where Python idioms differ from the language-agnostic version, the
adaptation is noted.

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

### Python Baseline and Tooling

- Target runtime: **Python 3.11+**.
- Formatter: **black** (line length 100) OR `ruff format` with identical settings.
- Lint: **ruff** (no ignored warnings).
- Typing: **mypy** in strict mode.
- Tests: **pytest** with warnings treated as errors (`-W error`).

### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: an imperative statement, a rationale, and a Python example or template.
- Rules marked **(Py-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Do not use recursion.

All control flow MUST be simple, explicit, and statically analyzable. Recursion MUST NOT be used.
This ensures all executions that should be bounded are bounded.

Rationale: Predictable, bounded execution is the foundation of safety. Recursion makes it difficult
to prove termination and risks stack overflow.

```python
# Do: explicit loop with fixed bound
for index in range(max_iterations):
    process(items[index])

# Do not: recursive call
def process(items: list[Item]) -> None:
    if not items:
        return
    process(items[1:])  # VIOLATION
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work MUST have a fixed
upper bound. Where a loop cannot terminate (e.g., an event loop), this MUST be asserted.

Rationale: Unbounded work causes infinite loops, tail-latency spikes, and resource exhaustion.
The fail-fast principle demands that violations are detected sooner rather than later.

```python
MAX_RETRIES = 5

for attempt in range(MAX_RETRIES):
    if try_connect():
        break
assert attempt < MAX_RETRIES, "connection retries exhausted"

class BoundedQueue[T]:
    def __init__(self, max_size: int) -> None:
        self._items: list[T] = []
        self._max_size = max_size

    def enqueue(self, item: T) -> None:
        assert len(self._items) < self._max_size, "queue full"
        self._items.append(item)
```

### SAF-03 — Use precise types and explicit bounds. Avoid `Any`. **(Py-adapted)**

All values MUST have the most precise type possible. `Any` MUST NOT be used. Use `typing.NewType`
or `typing.Annotated` to encode units and semantic distinctions. Use `int` for counts and indexes,
and avoid `float` for integral quantities. Range checks MUST be explicit at boundaries.

Rationale: Python lacks explicit integer sizing. Precise types, unit annotations, and runtime
guards are the Python equivalent of explicitly-sized types.

```python
from typing import NewType

UserId = NewType("UserId", int)
OrderId = NewType("OrderId", int)

def get_user(user_id: UserId) -> User:
    ...

def parse_port(raw: object) -> int:
    assert isinstance(raw, int), "port must be int"
    assert 1 <= raw <= 65535, "port out of range"
    return raw
```

### SAF-04 — Assert all preconditions, postconditions, and invariants.

Every function MUST assert its preconditions (valid arguments), postconditions (valid return values),
and any invariants that must hold during execution. A function MUST NOT operate blindly on unchecked
data.

Rationale: Assertions detect programmer errors. Unlike operating errors which must be handled,
assertion failures are unexpected. The only correct response to corrupt code is to crash. Assertions
downgrade catastrophic correctness bugs into liveness bugs.

```python
def transfer(from_account: Account, to_account: Account, amount: int) -> None:
    assert from_account.id != to_account.id, "cannot transfer to self"
    assert amount > 0, "amount must be positive"
    assert from_account.balance >= amount, "insufficient balance"

    from_account.balance -= amount
    to_account.balance += amount

    assert from_account.balance >= 0, "balance must not go negative"
    assert to_account.balance > 0, "target balance must be positive"
```

### SAF-05 — Maintain assertion density of at least 2 per function.

The assertion density of the codebase MUST average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs through testing and
fuzzing. Low assertion density leaves large regions of state space unchecked.

```python
def process_batch(items: list[Item], max_size: int) -> list[Result]:
    assert len(items) <= max_size, "batch exceeds max size"
    results = do_work(items)
    assert len(results) == len(items), "result count mismatch"
    return results
```

### SAF-06 — Pair assertions across different code paths.

For every property to enforce, there MUST be at least two assertions on different code paths that
verify the property. For example, assert validity before writing and after reading.

Rationale: Bugs hide at the boundary between valid and invalid data. A single assertion covers one
side; paired assertions cover the transition.

```python
assert record.checksum == compute_checksum(record.data)
write_to_disk(record)

loaded = read_from_disk(record.id)
assert loaded.checksum == compute_checksum(loaded.data)
```

### SAF-07 — Split compound assertions.

Compound assertions MUST be split into individual assertions. Prefer `assert(a); assert(b);` over
`assert(a and b)`.

Rationale: Split assertions are simpler to read and provide precise failure information.

```python
assert index >= 0, "index must be non-negative"
assert index < length, "index must be within bounds"
```

### SAF-08 — Use single-line implication assertions.

When a property B must hold whenever condition A is true, this MUST be expressed as a single-line
implication: `if a: assert b`.

Rationale: Preserves logical intent without introducing complex boolean expressions.

```python
if is_committed:
    assert has_quorum, "committed without quorum"
```

### SAF-09 — Assert constants and type relationships.

Relationships between constants and configuration values MUST be asserted at import time or program
startup.

Rationale: Assertions verify design integrity before the program executes real work.

```python
PAGE_SIZE = 4096
BLOCK_SIZE = 16384
assert BLOCK_SIZE % PAGE_SIZE == 0, "block must align to page size"
```

### SAF-10 — Assert both positive and negative space.

Assertions MUST cover both the positive space (what is expected) AND the negative space (what is not
expected). Where data moves across the valid/invalid boundary, both sides MUST be asserted.

Rationale: Most interesting bugs occur at the boundary between valid and invalid states.

```python
if index < length:
    assert buffer[index] is not None, "slot must be populated"
else:
    assert index == length, "index must not skip values"
```

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests MUST exercise valid inputs, invalid inputs, and the transitions between valid and invalid
states. Tests MUST NOT only cover the happy path.

Rationale: An analysis of production failures found that 92% of catastrophic failures resulted from
incorrect handling of non-fatal errors. Testing only valid data misses the majority of real-world
failure modes.

```python
def test_transfer() -> None:
    assert_transfer_ok(amount=100, balance=200)
    assert_transfer_fail(amount=0, balance=200)
    assert_transfer_fail(amount=300, balance=200)
    assert_transfer_ok(amount=200, balance=200)
    assert_transfer_fail(amount=201, balance=200)
```

### SAF-12 — Avoid unbounded allocations. Pre-size and reuse. **(Py-adapted)**

Allocations in hot paths MUST be minimized. Lists and buffers MUST be pre-sized where the upper
bound is known. Object creation inside loops or per-event handlers MUST be avoided when reuse is
feasible.

Rationale: Excessive allocation increases GC pressure and tail latency. Pre-sizing and reuse
improve predictability.

```python
buffer: bytearray = bytearray(MAX_BUFFER_SIZE)

def process_batch(items: list[Item]) -> None:
    assert len(items) <= MAX_BATCH_SIZE
    for index, item in enumerate(items):
        buffer[index] = item.value
```

### SAF-13 — Declare variables at the smallest possible scope.

Variables MUST be declared at the smallest possible scope and the number of variables in any given
scope MUST be minimized.

Rationale: Fewer variables in scope reduces the probability that a variable is misused or confused
with another.

```python
for item in batch:
    checksum = compute_checksum(item)
    assert checksum == item.expected_checksum
```

### SAF-14 — Hard limit function length to 70 lines.

No function SHALL exceed 70 lines. This is a hard limit, not a guideline.

Rationale: There is a sharp cognitive discontinuity between a function that fits on screen and one
that requires scrolling. The 70-line limit forces clean decomposition.

### SAF-15 — Centralize control flow in parent functions.

When splitting a large function, all branching logic (if/match) MUST remain in the parent function.
Helper functions MUST NOT contain control flow that determines program behavior.

Rationale: Centralizing control flow means there is exactly one place to understand all branches.

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

Parent functions MUST own state mutation. Helper functions MUST compute and return values without
mutating shared state. Keep leaf functions pure.

Rationale: Pure helper functions are easier to test, reason about, and compose.

### SAF-17 — Treat warnings as errors; require strict typing. **(Py-adapted)**

`black`, `ruff`, and `mypy --strict` MUST pass with no warnings. Tests MUST run with warnings treated
as errors (`pytest -W error`).

Rationale: Warnings frequently indicate latent correctness issues. Strict typing eliminates a class
of runtime errors.

### SAF-18 — Do not react directly to external events. Batch and process at your own pace.

Programs MUST NOT perform work directly in response to external events. Instead, events MUST be
queued and processed in controlled batches at the program's own pace.

Rationale: Reacting directly to external events surrenders control flow to the environment, making
it impossible to bound work per time period.

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions MUST be split into nested if/else branches. Complex `elif` chains MUST
be rewritten as nested `else: if` blocks.

Rationale: Compound conditions obscure case coverage. Nested branches make every case explicit.

### SAF-20 — State invariants positively. Avoid negations.

Conditions MUST be stated in positive form. Comparisons MUST follow the natural grain of the domain.

Rationale: Negations are error-prone and harder to verify.

### SAF-21 — Handle all errors explicitly.

Every error MUST be handled explicitly. No exception SHALL be silently ignored. Bare `except` MUST
NOT be used.

Rationale: Error-handling bugs are the dominant cause of catastrophic production failures.

```python
try:
    data = read_file(path)
except OSError as error:
    logger.error("read failed", exc_info=error)
    raise
```

### SAF-22 — Always state the "why" in comments and commit messages.

Every non-obvious decision MUST be accompanied by a comment or commit message explaining why.

Rationale: The "what" is in the code. The "why" is the only thing that enables safe future changes.

### SAF-23 — Pass explicit options to library calls. Do not rely on defaults.

All options and configuration values MUST be passed explicitly at the call site. Default values
MUST NOT be relied upon.

Rationale: Defaults can change across library versions, causing latent, potentially catastrophic bugs.

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance MUST be considered during the design phase, not deferred to profiling.

Rationale: Architecture-level wins (1000x) cannot be retrofitted.

### PERF-02 — Perform back-of-the-envelope resource sketches.

Before implementation, back-of-the-envelope calculations MUST be performed for network, disk,
memory, and CPU.

Rationale: Sketches are cheap. They guide design into the right 90%.

### PERF-03 — Optimize the slowest resource first, weighted by frequency.

Optimization effort MUST target the slowest resource first (network > disk > memory > CPU), after
adjusting for frequency of access.

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

### PERF-07 — Be explicit. Do not depend on interpreter optimizations.

Performance-critical code MUST be written explicitly. Do not rely on interpreter optimizations.

Rationale: Interpreter optimizations are heuristic and fragile across versions.

### PERF-08 — Use primitive arguments in hot loops. Avoid implicit global lookups. **(Py-adapted)**

Hot loop functions MUST take primitive arguments directly. Avoid repeated global lookups in tight
loops; bind local variables where helpful.

Rationale: Local variable access is faster than global lookups in Python.

```python
def process_range(data: list[float], start: int, end: int) -> float:
    total = 0.0
    local_data = data
    for index in range(start, end):
        total += local_data[index]
    return total
```

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names MUST capture what a thing is or does with precision.

Rationale: Great names are the essence of great code.

### DX-02 — Use snake_case for functions/variables; PascalCase for classes. **(Py-adapted)**

Functions and variables MUST use `snake_case`. Classes MUST use `PascalCase`. File names MUST use
`snake_case`.

Rationale: This is Python's established convention (PEP 8).

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

Resource names MUST convey lifecycle and ownership.

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

### DX-11 — Class layout: fields, then types, then methods.

Class definitions MUST be ordered: data fields first, then nested types, then methods.

Rationale: Predictable layout lets the reader find what they need by position.

### DX-12 — Do not overload names that conflict with domain terminology.

Names MUST NOT be reused across different concepts in the same system.

Rationale: Overloaded terminology causes confusion in documentation and code review.

### DX-13 — Prefer nouns over adjectives/participles for externally-referenced names.

Names that appear in documentation, logs, or external communication MUST be nouns or noun phrases.

Rationale: Noun names compose cleanly into derived identifiers.

### DX-14 — Use named option objects when arguments can be confused.

When a function takes two or more arguments of the same type, or arguments whose meaning is not
obvious at the call site, a named options object MUST be used.

Rationale: Positional arguments of the same type are silently swappable.

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class TransferOptions:
    from_account: AccountId
    to_account: AccountId
    amount: int

def transfer(options: TransferOptions) -> None:
    ...
```

### DX-15 — Name nullable parameters so None's meaning is clear at the call site.

If a parameter accepts `None`, the parameter name MUST make the meaning of `None` obvious when read
at the call site.

Rationale: `foo(None)` is meaningless without context.

### DX-16 — Thread singletons positionally: general to specific.

Constructor parameters that are singletons (logger, config, tracer) MUST be passed positionally,
ordered from most general to most specific.

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

Comments MUST be complete sentences: space after `#`, capital letter, full stop (or colon if
followed by related content). Inline comments may be phrases without punctuation.

Rationale: Well-written prose is easier to read and signals careful thinking.

---

## Cache Invalidation & State Hygiene (CIS)

### CIS-01 — Do not duplicate variables or alias state.

Every piece of state MUST have exactly one source of truth. Variables MUST NOT be duplicated or
aliased unless there is a compelling performance reason, in which case the alias MUST be documented
and its synchronization asserted.

Rationale: Duplicated state will eventually desynchronize.

### CIS-02 — Avoid copying large objects. Pass by reference. **(Py-adapted)**

Large objects MUST NOT be shallow-copied via `dict(...)`, `list(...)`, or `copy()` in hot paths.
Prefer passing the original reference and using `typing.Final` or `@dataclass(frozen=True)` to
signal immutability.

Rationale: Copying large objects creates GC pressure and can mask mutation bugs.

### CIS-03 — Prefer in-place construction. Avoid intermediate copies. **(Py-adapted)**

Large objects MUST be constructed in-place rather than via intermediate objects that are then
copied or updated.

Rationale: Intermediate copies waste memory and CPU cycles.

### CIS-04 — If any field requires builder-pattern init, use it for the whole object. **(Py-adapted)**

If any field of a complex object requires multi-step initialization, the entire object MUST use the
same strategy for consistency.

Rationale: Mixing initialization strategies makes the construction sequence harder to reason about.

### CIS-05 — Declare variables close to use. Shrink scope.

Variables MUST be computed or checked as close as possible to where they are used. Do not introduce
variables before they are needed.

Rationale: Minimizing the check-to-use gap reduces TOCTOU-style bugs.

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

Return types MUST be as simple as possible: `None` > `bool` > `int` > `T | None` > `Result`-like.

Rationale: Each additional dimension creates branches at every call site.

### CIS-07 — Do not `await` between assertions and dependent code. **(Py-adapted)**

Functions with precondition assertions MUST NOT `await` between the assertion and the code that
depends on it. If async work is required, re-assert after resumption.

Rationale: `await` yields control; preconditions may no longer hold on resume.

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

### OBO-02 — Use explicit division semantics.

All integer division MUST use explicit semantics: exact, floor, or ceiling.

Rationale: Default division may be ambiguous; explicit helpers show intent.

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter.

All code MUST be formatted by `black` (or `ruff format`) with line length 100.

Rationale: Automated formatting eliminates style debates and ensures consistency.

### FMT-02 — Use 4-space indentation. **(Py-adapted)**

Indentation MUST be 4 spaces. Tabs MUST NOT be used.

Rationale: 4 spaces is Python's standard indentation depth.

### FMT-03 — Hard limit all lines to 100 columns.

No line SHALL exceed 100 columns.

Rationale: 100 columns allows two files side-by-side on a standard monitor.

### FMT-04 — Always use braces on if statements (unless single-line).

This rule is not applicable in Python. The equivalent rule is: one statement per line and no
semicolon-separated statements. Multi-line `if` blocks MUST use proper indentation.

Rationale: Python uses indentation to define scope; mixing statements on one line hides control flow.

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

### DEP-03 — Prefer Python for scripts and automation. **(Py-adapted)**

Scripts and automation MUST be written in Python. Shell scripts are acceptable only for trivial glue
(< 20 lines) with no logic.

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
| SAF-14 | 70-line function limit | |
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
