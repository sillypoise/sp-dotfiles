# TigerStyle Rulebook — Go / Strict / Full

## Preamble

### Purpose

This document is a comprehensive Go coding rulebook derived from TigerBeetle's TigerStyle. It is
intended to be dropped into any Go codebase as part of an `AGENTS.md` file, a system prompt, or a
code review checklist. Every rule is actionable and enforceable.

This is the **Go-specific** variant. Rule IDs match the language-agnostic TigerStyle rulebook for
cross-referencing. Where Go idioms differ from the language-agnostic version, the adaptation is
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

### Go Tooling Requirements

- `gofmt` MUST be run on all Go files. Tabs are required by `gofmt`.
- `go vet` MUST pass with no warnings.
- `staticcheck` MUST pass with no warnings (or an equivalent lint toolchain).
- `go test ./...` MUST pass; `-race` MUST be used in CI for concurrency-heavy code.

### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: an imperative statement, a rationale, and a Go example or template.
- Rules marked **(Go-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Do not use recursion.

All control flow MUST be simple, explicit, and statically analyzable. Recursion MUST NOT be used.
This ensures all executions that should be bounded are bounded.

Rationale: Predictable, bounded execution is the foundation of safety. Recursion makes it difficult
to prove termination and risks stack overflow.

```go
// Do: explicit loop with fixed bound
for i := 0; i < maxIterations; i++ {
	process(items[i])
}

// Do not: recursive call
func process(items []Item) {
	if len(items) == 0 {
		return
	}
	process(items[1:]) // VIOLATION
}
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work MUST have a fixed
upper bound. Where a loop cannot terminate (e.g., an event loop), this MUST be asserted.

Rationale: Unbounded work causes infinite loops, tail-latency spikes, and resource exhaustion.
The fail-fast principle demands that violations are detected sooner rather than later.

```go
const maxRetries = 5

for attempt := 0; attempt < maxRetries; attempt++ {
	if tryConnect() {
		break
	}
}
assert(attempt < maxRetries, "connection retries exhausted")

// Bounded queue
type BoundedQueue[T any] struct {
	items   []T
	maxSize int
}

func (q *BoundedQueue[T]) Enqueue(item T) {
	assert(len(q.items) < q.maxSize, "queue full")
	q.items = append(q.items, item)
}
```

### SAF-03 — Use explicitly-sized integer types. **(Go-adapted)**

All integer types MUST be explicitly sized (`int32`, `uint64`, etc.). Architecture-dependent
`int`/`uint` MUST NOT be used unless required by the Go standard library (e.g., `len`, `make`,
`copy`, `append` indices).

Rationale: Implicit sizing creates architecture-specific behavior and makes overflow analysis
impossible without knowing the target.

```go
// Do
var count uint32 = 0
var offset int64 = 0

// Do not
var count int = 0 // VIOLATION: architecture-dependent
```

### SAF-04 — Assert all preconditions, postconditions, and invariants.

Every function MUST assert its preconditions (valid arguments), postconditions (valid return values),
and any invariants that must hold during execution. A function MUST NOT operate blindly on unchecked
data.

Rationale: Assertions detect programmer errors. Unlike operating errors which must be handled,
assertion failures are unexpected. The only correct response to corrupt code is to crash. Assertions
downgrade catastrophic correctness bugs into liveness bugs.

```go
func transfer(from *Account, to *Account, amount int64) {
	assert(from.ID != to.ID, "cannot transfer to self")
	assert(amount > 0, "amount must be positive")
	assert(from.Balance >= amount, "insufficient balance")

	from.Balance -= amount
	to.Balance += amount

	assert(from.Balance >= 0, "balance must not go negative")
	assert(to.Balance > 0, "target balance must be positive")
}
```

### SAF-05 — Maintain assertion density of at least 2 per function.

The assertion density of the codebase MUST average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs through testing and
fuzzing. Low assertion density leaves large regions of state space unchecked.

```go
func processBatch(items []Item, maxSize int) []Result {
	assert(len(items) <= maxSize, "batch exceeds max size")
	results := doWork(items)
	assert(len(results) == len(items), "result count mismatch")
	return results
}
```

### SAF-06 — Pair assertions across different code paths.

For every property to enforce, there MUST be at least two assertions on different code paths that
verify the property. For example, assert validity before writing and after reading.

Rationale: Bugs hide at the boundary between valid and invalid data. A single assertion covers one
side; paired assertions cover the transition.

```go
// Assert before write
assert(record.Checksum == computeChecksum(record.Data), "checksum mismatch")
writeToDisk(record)

// Assert after read
loaded := readFromDisk(record.ID)
assert(loaded.Checksum == computeChecksum(loaded.Data), "checksum mismatch")
```

### SAF-07 — Split compound assertions.

Compound assertions MUST be split into individual assertions. Prefer `assert(a); assert(b);` over
`assert(a && b)`.

Rationale: Split assertions are simpler to read and provide precise failure information. A compound
assertion that fails gives no indication of which condition was violated.

```go
// Do
assert(index >= 0, "index must be non-negative")
assert(index < length, "index must be within bounds")

// Do not
assert(index >= 0 && index < length, "bounds") // VIOLATION
```

### SAF-08 — Use single-line implication assertions.

When a property B must hold whenever condition A is true, this MUST be expressed as a single-line
implication: `if a { assert(b) }`.

Rationale: Preserves logical intent without introducing complex boolean expressions or unnecessary
nesting.

```go
if isCommitted {
	assert(hasQuorum, "committed without quorum")
}
if isLeader {
	assert(term == currentTerm, "leader term mismatch")
}
```

### SAF-09 — Assert compile-time constants and type sizes.

Relationships between compile-time constants, type sizes, and configuration values MUST be asserted
at compile time (or at startup if compile-time assertions are not possible).

Rationale: Compile-time assertions verify design integrity before the program executes.

```go
const (
	PageSize   = 4096
	BlockSize  = 16384
	MaxEntries = 1024
)

var _ [1]struct{} = [1]struct{}{} // placeholder for compile-time checks

func init() {
	assert(BlockSize%PageSize == 0, "block must align to page size")
}
```

### SAF-10 — Assert both positive and negative space.

Assertions MUST cover both the positive space (what is expected) AND the negative space (what is not
expected). Where data moves across the valid/invalid boundary, both sides MUST be asserted.

Rationale: Most interesting bugs occur at the boundary between valid and invalid states.

```go
if index < length {
	assert(buffer[index] != sentinel, "slot must be populated")
} else {
	assert(index == length, "index must not skip values")
}
```

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests MUST exercise valid inputs, invalid inputs, and the transitions between valid and invalid
states. Tests MUST NOT only cover the happy path.

Rationale: An analysis of production failures found that 92% of catastrophic failures resulted from
incorrect handling of non-fatal errors. Testing only valid data misses the majority of real-world
failure modes.

```go
func TestTransfer(t *testing.T) {
	assertTransferOK(t, 100, 200)
	assertTransferFail(t, 0, 200)
	assertTransferFail(t, 300, 200)
	assertTransferOK(t, 200, 200)
	assertTransferFail(t, 201, 200)
}
```

### SAF-12 — Pre-allocate and reuse. Avoid unbounded allocations. **(Go-adapted)**

Allocations in hot paths MUST be minimized. Slices and buffers MUST be pre-allocated where the
upper bound is known. Reuse buffers across calls. Use `sync.Pool` only when reuse is proven to help.

Rationale: Excessive allocation increases GC pressure and tail latency. Pre-allocation and reuse
improve predictability.

```go
// Do: pre-allocate
buf := make([]byte, 0, maxSize)

func process(items []Item) {
	buf = buf[:0]
	for _, item := range items {
		buf = append(buf, item.Bytes()...)
	}
}
```

### SAF-13 — Declare variables at the smallest possible scope.

Variables MUST be declared at the smallest possible scope and the number of variables in any given
scope MUST be minimized.

Rationale: Fewer variables in scope reduces the probability that a variable is misused or confused
with another. Tight scoping limits the blast radius of errors.

```go
for _, item := range batch {
	checksum := computeChecksum(item)
	assert(checksum == item.ExpectedChecksum, "checksum mismatch")
}
```

### SAF-14 — Hard limit function length to 70 lines.

No function SHALL exceed 70 lines. This is a hard limit, not a guideline.

Rationale: There is a sharp cognitive discontinuity between a function that fits on screen and one
that requires scrolling. The 70-line limit forces clean decomposition.

```go
// If a function approaches 70 lines, split it:
// - Keep control flow (if/switch) in the parent function.
// - Move non-branching logic into helper functions.
// - Keep leaf functions pure (no state mutation).
```

### SAF-15 — Centralize control flow in parent functions.

When splitting a large function, all branching logic (if/switch) MUST remain in the parent function.
Helper functions MUST NOT contain control flow that determines program behavior.

Rationale: Centralizing control flow means there is exactly one place to understand all branches.

```go
func processRequest(request Request) Response {
	switch request.Type {
	case Read:
		data := readHelper(request.Key)
		return respond(data)
	case Write:
		writeHelper(request.Key, request.Value)
		return acknowledge()
	default:
		panic("unexpected request type")
	}
}
```

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

Parent functions MUST own state mutation. Helper functions MUST compute and return values without
mutating shared state. Keep leaf functions pure.

Rationale: Pure helper functions are easier to test, reason about, and compose. When only one
function mutates state, bugs are localized to one site.

```go
func updateBalance(account *Account, amount int64) {
	newBalance := computeNewBalance(account.Balance, amount)
	assert(newBalance >= 0, "balance must not go negative")
	account.Balance = newBalance
}

func computeNewBalance(balance int64, amount int64) int64 {
	return balance - amount
}
```

### SAF-17 — Treat all warnings as errors; require vet and staticcheck. **(Go-adapted)**

All compiler and linter warnings MUST be enabled at the strictest available setting. `go vet` and
`staticcheck` MUST pass with no warnings.

Rationale: Warnings frequently indicate latent correctness issues. Suppressing them normalizes
ignoring the tool that is best positioned to catch mechanical errors.

```text
Required tools:
- gofmt (format)
- go vet (static analysis)
- staticcheck (advanced lint)
- go test ./... (tests)
- go test -race ./... (race detection in CI)
```

### SAF-18 — Do not react directly to external events. Batch and process at your own pace.

Programs MUST NOT perform work directly in response to external events (network, user input,
signals). Instead, events MUST be queued and processed in controlled batches at the program's own
pace.

Rationale: Reacting directly to external events surrenders control flow to the environment, making
it impossible to bound work per time period.

```go
var eventQueue []Event

func onMessage(event Event) {
	assert(len(eventQueue) < maxQueueSize, "queue full")
	eventQueue = append(eventQueue, event)
}

func tick() {
	batch := eventQueue
	if len(batch) > maxBatchSize {
		batch = batch[:maxBatchSize]
	}
	processBatch(batch)
	copy(eventQueue, eventQueue[len(batch):])
	eventQueue = eventQueue[:len(eventQueue)-len(batch)]
}
```

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions (evaluating multiple booleans in one expression) MUST be split into
nested if/else branches. Complex `else if` chains MUST be rewritten as `else { if { } }` trees.

Rationale: Compound conditions obscure case coverage. Nested branches make every case explicit and
verifiable.

```go
if isValid {
	if isAuthorized {
		execute()
	} else {
		reject("unauthorized")
	}
} else {
	reject("invalid")
}
```

### SAF-20 — State invariants positively. Avoid negations.

Conditions MUST be stated in positive form. Comparisons MUST follow the natural grain of the domain
(e.g., `index < length` rather than `!(index >= length)`).

Rationale: Negations are error-prone and harder to verify.

```go
if index < length {
	// invariant holds
} else {
	// invariant violated
}
```

### SAF-21 — Handle all errors explicitly.

Every error MUST be handled explicitly. No error SHALL be silently ignored or discarded. Blank
identifier `_` MUST NOT be used to ignore errors.

Rationale: Error-handling bugs are the dominant cause of catastrophic production failures.

```go
data, err := readFile(path)
if err != nil {
	return err
}

// Do not
_, _ = readFile(path) // VIOLATION: error ignored
```

### SAF-22 — Always state the "why" in comments and commit messages.

Every non-obvious decision MUST be accompanied by a comment or commit message explaining why.

Rationale: The "what" is in the code. The "why" is the only thing that enables safe future changes.

```go
// Why: batch to amortize syscall overhead; per-item writes caused 3x latency.
writeBatch(items)
```

### SAF-23 — Pass explicit options to library calls. Do not rely on defaults.

All options and configuration values MUST be passed explicitly at the call site. Default values
MUST NOT be relied upon.

Rationale: Defaults can change across library versions, causing latent, potentially catastrophic bugs.

```go
client := &http.Client{
	Timeout: 5 * time.Second,
}
req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
if err != nil {
	return err
}
resp, err := client.Do(req)
```

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance MUST be considered during the design phase, not deferred to profiling. The largest
performance wins (1000x) come from architectural decisions that cannot be retrofitted.

Rationale: It is harder and less effective to fix a system after implementation.

```text
Design sketch:
- Bottleneck resource? (network/disk/memory/CPU)
- Expected throughput?
- Latency budget?
- Can work be batched?
```

### PERF-02 — Perform back-of-the-envelope resource sketches.

Before implementation, back-of-the-envelope calculations MUST be performed for the four core
resources (network, disk, memory, CPU) across bandwidth and latency.

Rationale: Sketches are cheap. They guide design into the right 90% of the solution space.

```text
Example sketch:
- 10,000 req/s * 1 KB = 10 MB/s network
- 10,000 writes/s * 200 B = 2 MB/s disk
- 10,000 objects * 2 KB = 20 MB memory
```

### PERF-03 — Optimize the slowest resource first, weighted by frequency.

Optimization effort MUST target the slowest resource first (network > disk > memory > CPU), after
adjusting for frequency of access.

Rationale: Bottleneck-focused optimization yields the largest gains.

### PERF-04 — Separate control plane from data plane.

The control plane (scheduling, coordination, metadata) MUST be clearly separated from the data plane
(bulk data processing).

Rationale: Mixing control and data operations prevents effective batching.

```go
batch := controlPlanePrepare(requests)
assert(batch.Valid, "invalid batch")
dataPlaneExecute(batch)
```

### PERF-05 — Amortize costs via batching.

Network, disk, memory, and CPU costs MUST be amortized by batching accesses. Per-item processing
MUST be avoided when batching is feasible.

Rationale: Per-item overhead dominates at high throughput.

```go
items := collectBatch(maxBatchSize)
writeAll(items) // one syscall
```

### PERF-06 — Keep CPU work predictable. Avoid erratic control flow.

Hot paths MUST have predictable, linear control flow.

Rationale: Predictability enables prefetching, branch prediction, and cache utilization.

```go
for i := 0; i < count; i++ {
	process(buffer[i])
}
```

### PERF-07 — Be explicit. Do not depend on compiler optimizations.

Performance-critical code MUST be written explicitly. Do not rely on the compiler to inline or
optimize the code.

Rationale: Compiler optimizations are heuristic and fragile.

### PERF-08 — Use primitive arguments in hot loops. Avoid `receiver` in tight loops. **(Go-adapted)**

Hot loop functions MUST take primitive arguments directly. They MUST NOT access large receiver
structs in tight loops when performance matters.

Rationale: Primitive arguments allow the compiler to keep values in registers and avoid alias
analysis overhead.

```go
func processRange(data []float64, start int, end int) float64 {
	sum := 0.0
	for i := start; i < end; i++ {
		sum += data[i]
	}
	return sum
}
```

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names MUST capture what a thing is or does with precision.

Rationale: Great names are the essence of great code.

### DX-02 — Use snake_case for variables/functions where applicable. **(Go-adapted)**

Use Go idioms: `mixedCaps` for identifiers, `MixedCaps` for exported names, `snake_case` for file
names. Do not introduce non-idiomatic naming conventions.

Rationale: Consistency with Go conventions reduces friction and improves readability.

```go
type ReplicaManager struct {}
func (m *ReplicaManager) processBatch() {}
// File: replica_manager.go
```

### DX-03 — Do not abbreviate names (except trivial loop counters).

Variable and function names MUST NOT be abbreviated unless the variable is a primitive integer used
as a loop counter (`i`, `j`, `k`).

Rationale: Abbreviations are ambiguous.

### DX-04 — Capitalize acronyms consistently.

Acronyms in names MUST use their standard capitalization (HTTPServer, SQLClient).

Rationale: Standard capitalization is unambiguous.

### DX-05 — Append units and qualifiers at the end, sorted by significance.

Units and qualifiers MUST be appended to variable names, sorted from most significant to least
significant.

Rationale: Groups related variables visually and semantically.

```go
latencyMsMax := 500
latencyMsMin := 10
```

### DX-06 — Use meaningful names that indicate lifecycle and ownership.

Resource names MUST convey their lifecycle and ownership (pool, arena, buffer).

Rationale: Cleanup expectations should be obvious from the name.

### DX-07 — Align related names by character length when feasible.

When choosing names for related variables, PREFER names with the same character count so that
related expressions align visually.

Rationale: Symmetry improves visual parsing and correctness checking.

### DX-08 — Prefix helper/callback names with the caller's name.

When a function calls a helper or callback, the helper's name MUST be prefixed with the calling
function's name.

Rationale: The prefix makes the call hierarchy visible in the name itself.

### DX-09 — Callbacks go last in parameter lists.

Callback parameters MUST be the last parameters in a function signature.

Rationale: Callbacks are invoked last. Parameter order should mirror control flow.

### DX-10 — Order declarations by importance. Put exported API first.

Within a file, the most important declarations (exports, public API) MUST appear first.

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

```go
type TransferOptions struct {
	From   AccountID
	To     AccountID
	Amount int64
}

func Transfer(options TransferOptions) {}
```

### DX-15 — Name nullable parameters so nil's meaning is clear at the call site.

If a parameter accepts `nil`, the parameter name MUST make the meaning of `nil` obvious when read
at the call site.

Rationale: `foo(nil)` is meaningless without context.

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

### CIS-02 — Pass large arguments by pointer. **(Go-adapted)**

Function arguments larger than 16 bytes MUST be passed by pointer, not by value.

Rationale: Passing large structs by value creates implicit copies that waste stack space and can
mask bugs.

### CIS-03 — Prefer in-place initialization via out pointers. **(Go-adapted)**

Large structs MUST be initialized in-place via pointers or builder patterns, rather than returned by
value in performance-critical code.

Rationale: In-place initialization avoids intermediate copies and ensures pointer stability.

### CIS-04 — If any field requires in-place init, the whole struct does. **(Go-adapted)**

In-place initialization is viral. If any field of a struct requires in-place initialization, the
entire containing struct MUST also be initialized in-place.

Rationale: Mixing strategies breaks pointer stability.

### CIS-05 — Declare variables close to use. Shrink scope.

Variables MUST be computed or checked as close as possible to where they are used.

Rationale: Minimizes check-to-use gaps (POCPOU/TOCTOU risk).

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

Return types MUST be as simple as possible: `void` > `bool` > `int` > `*T` > `Result`-like structs.

Rationale: Each dimension in the return type creates viral call-site branching.

### CIS-07 — Assertions must remain valid across goroutines. **(Go-adapted)**

Functions with precondition assertions MUST run to completion without crossing a goroutine boundary
that could invalidate the preconditions. If concurrency is required, re-assert after synchronization.

Rationale: Concurrency can invalidate preconditions, making assertions misleading. Avoid data races.

### CIS-08 — Guard against buffer underflow (buffer bleeds).

Unused buffer space MUST be explicitly zeroed before use or transmission.

Rationale: Buffer underflow leaks sensitive data (Heartbleed class).

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

All integer division MUST use explicit semantics: exact, floor, or ceiling. Use helper functions or
document the rounding behavior.

Rationale: Default `/` rounding varies by language; explicit shows intent.

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter.

All code MUST be formatted by `gofmt` (or `gofmt`-equivalent tools). No manual formatting overrides
are permitted.

Rationale: Automated formatting eliminates style debates and ensures consistency.

### FMT-02 — Indentation MUST follow gofmt (tabs). **(Go-adapted)**

Indentation MUST use tabs as produced by `gofmt`. Spaces MUST NOT be used for indentation.

Rationale: Go tooling assumes `gofmt` output; tabs are the standard.

### FMT-03 — Hard limit all lines to 100 columns.

No line SHALL exceed 100 columns. No exceptions.

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

### DEP-03 — Prefer Go for scripts and automation. **(Go-adapted)**

Scripts and automation MUST be written in Go. Shell scripts are acceptable only for trivial glue
(< 20 lines) with no logic.

Rationale: Go scripts are portable, type-safe, and consistent with the toolchain.

---

## Appendix: Rule Index

| ID | Rule (short form) | Go-adapted? |
|----|-------------------|-------------|
| SAF-01 | Simple explicit control flow; no recursion | |
| SAF-02 | Bound everything | |
| SAF-03 | Explicitly-sized types; avoid int/uint | Yes |
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
| SAF-14 | 70-line function limit | |
| SAF-15 | Centralize control flow in parent | |
| SAF-16 | Centralize state mutation; pure leaves | |
| SAF-17 | gofmt/vet/staticcheck; warnings as errors | Yes |
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
| PERF-08 | Primitive args in hot loops; avoid receiver | Yes |
| DX-01 | Precise nouns and verbs | |
| DX-02 | Go naming idioms; snake_case files | Yes |
| DX-03 | No abbreviations | |
| DX-04 | Consistent acronym capitalization | |
| DX-05 | Units/qualifiers appended last | |
| DX-06 | Meaningful lifecycle names | |
| DX-07 | Align related names by length | |
| DX-08 | Prefix helpers with caller name | |
| DX-09 | Callbacks last in params | |
| DX-10 | Exported API first in file | |
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
| CIS-02 | Large args by pointer | Yes |
| CIS-03 | In-place init via pointers/builders | Yes |
| CIS-04 | In-place init is viral | Yes |
| CIS-05 | Declare close to use | |
| CIS-06 | Simpler return types | |
| CIS-07 | No goroutine boundary with active assertions | Yes |
| CIS-08 | Guard against buffer bleeds | |
| CIS-09 | Group alloc/dealloc visually | |
| OBO-01 | Index ≠ count ≠ size | |
| OBO-02 | Explicit division semantics | |
| FMT-01 | Run gofmt | |
| FMT-02 | gofmt tabs required | Yes |
| FMT-03 | 100-column hard limit | |
| FMT-04 | Braces on if (unless single-line) | |
| DEP-01 | Minimize dependencies | |
| DEP-02 | Prefer existing tools | |
| DEP-03 | Go for scripts | Yes |
