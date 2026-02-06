# TigerStyle Rulebook — Swift / Strict / Full

## Preamble

### Purpose

This document is a comprehensive Swift coding rulebook derived from TigerBeetle's TigerStyle. It is
intended to be dropped into any Swift codebase as part of an `AGENTS.md` file, a system prompt, or a
code review checklist. Every rule is actionable and enforceable.

This is the **Swift-specific** variant. Rule IDs match the language-agnostic TigerStyle rulebook for
cross-referencing. Where Swift idioms differ from the language-agnostic version, the adaptation is
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

### Swift Baseline and Tooling

- Target: **Swift 5.9** (latest stable toolchain).
- Formatter: `swift-format` (mandatory).
- Warnings are errors: `-warnings-as-errors` (mandatory).
- Tests MUST pass with `swift test` (or the project test runner).

### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: an imperative statement, a rationale, and a Swift example or template.
- Rules marked **(Swift-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Do not use recursion.

All control flow MUST be simple, explicit, and statically analyzable. Recursion MUST NOT be used.
This ensures all executions that should be bounded are bounded.

Rationale: Predictable, bounded execution is the foundation of safety. Recursion makes it difficult
to prove termination and risks stack overflow.

```swift
for index in 0..<max_iterations {
    process(items[index])
}
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work MUST have a fixed
upper bound. Where a loop cannot terminate (e.g., an event loop), this MUST be asserted.

Rationale: Unbounded work causes infinite loops, tail-latency spikes, and resource exhaustion. The
fail-fast principle demands that violations are detected sooner rather than later.

```swift
for retry in 0..<max_retries {
    if try_connect() { break }
    precondition(retry + 1 < max_retries, "connection retries exhausted")
}
```

### SAF-03 — Use explicitly-sized integer types. **(Swift-adapted)**

Integer types MUST be explicitly sized (`Int64`, `UInt32`). `Int`/`UInt` MUST NOT be used unless
required for indexing or API compatibility.

Rationale: Implicit sizing creates architecture-specific behavior and makes overflow analysis
impossible without knowing the target.

```swift
let count: UInt32 = 0
let offset: Int64 = 0
```

### SAF-04 — Assert all preconditions, postconditions, and invariants.

Every function MUST assert its preconditions, postconditions, and invariants.

Rationale: Assertions detect programmer errors. The only correct response to corrupt code is to
crash.

```swift
func transfer(from: Account, to: Account, amount: Int64) {
    precondition(amount > 0)
    precondition(from.id != to.id)
    precondition(from.balance >= amount)

    from.balance -= amount
    to.balance += amount

    precondition(from.balance >= 0)
    precondition(to.balance > 0)
}
```

### SAF-05 — Maintain assertion density of at least 2 per function.

The assertion density of the codebase MUST average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs through testing and
fuzzing.

```swift
func process(batch: [Item], max_size: Int) -> [Result] {
    precondition(batch.count <= max_size)
    let result = do_work(batch)
    precondition(result.count == batch.count)
    return result
}
```

### SAF-06 — Pair assertions across different code paths.

Every enforced property MUST have at least two assertions on different code paths that verify the
property.

Rationale: Bugs hide at the boundary between valid and invalid data.

```swift
precondition(record.checksum == compute_checksum(record.data))
write(record)

let loaded = read_record()
precondition(loaded.checksum == compute_checksum(loaded.data))
```

### SAF-07 — Split compound assertions.

Compound assertions MUST be split into individual assertions. `precondition(a); precondition(b);`
is required over `precondition(a && b)`.

Rationale: Split assertions are simpler to read and provide precise failure information.

```swift
precondition(index >= 0)
precondition(index < count)
```

### SAF-08 — Use single-line implication assertions.

When a property must hold whenever a condition is true, it MUST be expressed as a single-line
implication: `if condition { precondition(invariant) }`.

Rationale: Preserves logical intent without complex boolean expressions.

```swift
if is_committed { precondition(has_quorum) }
if is_leader { precondition(term == current_term) }
```

### SAF-09 — Assert compile-time constants and type sizes.

Relationships between compile-time constants, type sizes, and configuration values MUST be
asserted at startup when compile-time assertions are unavailable.

Rationale: Assertions verify design integrity before the program executes.

```swift
precondition(block_size % page_size == 0)
precondition(MemoryLayout<Header>.size == 64)
```

### SAF-10 — Assert both positive and negative space.

Assertions MUST cover both the positive space (what is expected) and the negative space (what is
not expected).

Rationale: Most interesting bugs occur at the boundary between valid and invalid states.

```swift
if index < count {
    precondition(buffer[index] != sentinel)
} else {
    precondition(index == count, "index must not skip values")
}
```

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests MUST exercise valid inputs, invalid inputs, and the transitions between valid and invalid
states.

Rationale: The majority of catastrophic failures result from incorrect handling of non-fatal
errors.

```swift
func test_transfer_boundaries() {
    assert(transfer(amount: 100, balance: 200).ok)
    assert(transfer(amount: 0, balance: 200).is_error)
    assert(transfer(amount: 200, balance: 200).ok)
    assert(transfer(amount: 201, balance: 200).is_error)
}
```

### SAF-12 — Pre-allocate and reuse. Avoid unbounded allocations. **(Swift-adapted)**

Allocations in hot paths MUST be minimized. Collections MUST be pre-allocated and reused.

Rationale: Excessive allocation increases ARC/allocator overhead and tail latency.

```swift
var buffer: [UInt8] = []
buffer.reserveCapacity(max_size)
```

### SAF-13 — Declare variables at the smallest possible scope.

Variables MUST be declared at the smallest possible scope and the number of variables in any given
scope MUST be minimized.

Rationale: Tight scoping reduces the probability that a variable is misused or confused.

```swift
for item in batch {
    let checksum = compute_checksum(item)
    precondition(checksum == item.expected_checksum)
}
```

### SAF-14 — Keep functions short (~70 lines hard limit).

Functions MUST NOT exceed approximately 70 lines.

Rationale: There is a sharp cognitive discontinuity between a function that fits on screen and one
that requires scrolling.

```text
# If a function approaches 70 lines, split it:
# - Keep branching logic in the parent function.
# - Move non-branching logic into helpers.
# - Keep leaf functions pure.
```

### SAF-15 — Centralize control flow in parent functions.

When splitting a large function, all branching logic MUST remain in the parent function. Helper
functions MUST NOT contain control flow that determines program behavior.

Rationale: Centralizing control flow means there is exactly one place to understand all branches.

```swift
func process(request: Request) {
    if request.type == .read {
        let data = read_helper(key: request.key)
        respond(data)
    } else if request.type == .write {
        write_helper(key: request.key, value: request.value)
        acknowledge()
    }
}
```

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

Parent functions MUST own state mutation. Helper functions MUST compute and return values without
mutating shared state.

Rationale: Pure helper functions are easier to test and reason about.

```swift
func update_balance(account: Account, amount: Int64) {
    let new_balance = compute_new_balance(balance: account.balance, amount: amount)
    precondition(new_balance >= 0)
    account.balance = new_balance
}
```

### SAF-17 — Treat warnings as errors; format consistently. **(Swift-adapted)**

All compiler warnings MUST be enabled and treated as errors. `swift-format` MUST be used.

Rationale: Warnings frequently indicate latent correctness issues.

```text
# Build flags: -warnings-as-errors
# Formatter: swift-format
```

### SAF-18 — Do not react directly to external events. Batch and process at your own pace.

Programs MUST NOT perform work directly in response to external events. Events MUST be queued and
processed in controlled batches.

Rationale: Reacting directly to external events surrenders control flow to the environment.

```swift
event_queue.append(event)
let batch = event_queue.drain(max_batch_size)
process_batch(batch)
```

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions MUST be split into nested if/else branches.

Rationale: Compound conditions obscure case coverage.

```swift
if is_valid {
    if is_authorized {
        execute()
    } else {
        reject("unauthorized")
    }
} else {
    reject("invalid")
}
```

### SAF-20 — State invariants positively. Avoid negations.

Conditions MUST be stated in positive form. Negated conditions MUST NOT be used.

Rationale: Negations are error-prone and harder to verify.

```swift
if index < count {
    handle(index)
} else {
    reject("out of bounds")
}
```

### SAF-21 — Handle all errors explicitly; avoid `try?`/`try!` unless justified. **(Swift-adapted)**

Every error MUST be handled explicitly. `try?`/`try!` MUST NOT be used outside tests unless the
invariant is documented.

Rationale: Silent error swallowing is a dominant source of production failures.

```swift
do {
    let data = try load_config()
    use(data)
} catch {
    log(error)
    throw error
}
```

### SAF-22 — Always state the "why" in comments and commit messages.

Every non-obvious decision MUST be accompanied by a comment or commit message explaining why.

Rationale: The "why" enables safe future changes.

```swift
// Why: batch to amortize syscall overhead; one-at-a-time caused 3x latency.
process_batch(items)
```

### SAF-23 — Pass explicit options to library calls. Avoid relying on defaults.

All options and configuration values MUST be passed explicitly at the call site. Defaults MUST NOT
be relied on.

Rationale: Defaults can change across versions, causing latent bugs.

```swift
client.request(
    url: url,
    timeout_ms: 5_000,
    retries: 3,
    method: .get
)
```

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance MUST be considered during the design phase, not deferred to profiling.

Rationale: The largest performance wins come from architectural decisions.

```text
# During design, answer:
# - What is the bottleneck resource? (network / disk / memory / CPU)
# - What is the expected throughput?
# - What is the latency budget per operation?
# - Can work be batched?
```

### PERF-02 — Perform back-of-the-envelope resource sketches.

Back-of-the-envelope calculations MUST be performed for network, disk, memory, and CPU.

Rationale: Rough math guides design into the right 90% of the solution space.

```text
# Example sketch:
# - 10,000 requests/sec
# - Each request: 1 KB payload
# - Network: 10,000 KB/sec ≈ 10 MB/sec
```

### PERF-03 — Optimize the slowest resource first, weighted by frequency.

Optimization MUST target the slowest resource first, adjusted by access frequency.

Rationale: Bottleneck-focused optimization yields the largest gains.

```text
# Priority order (adjust by frequency):
# 1. Network  2. Disk  3. Memory  4. CPU
```

### PERF-04 — Separate control plane from data plane.

The control plane MUST be clearly separated from the data plane.

Rationale: Separation enables batching without sacrificing assertion safety.

```swift
let batch = control_plane_prepare(requests)
precondition(batch.is_valid)
data_plane_execute(batch)
```

### PERF-05 — Amortize costs via batching.

Network, disk, memory, and CPU costs MUST be amortized by batching accesses. Per-item processing
MUST NOT be used when batching is feasible.

Rationale: Per-item overhead dominates at high throughput.

```swift
let items = collect(max_batch_size)
write_all(items)
```

### PERF-06 — Keep CPU work predictable. Avoid erratic control flow.

Hot paths MUST have predictable, linear control flow. Branching and random access MUST be avoided
in performance-critical code.

Rationale: Predictable work enables prefetching and cache line utilization.

```swift
for index in 0..<count {
    process(buffer[index])
}
```

### PERF-07 — Be explicit. Do not depend on compiler optimizations.

Performance-critical code MUST be explicit. Compiler optimizations MUST NOT be relied on.

Rationale: Compiler heuristics are fragile and non-portable.

```swift
process(items[0])
process(items[1])
process(items[2])
process(items[3])
```

### PERF-08 — Use primitive arguments in hot loops. Avoid large receiver access. **(Swift-adapted)**

Hot loop functions MUST take primitive arguments directly. Large `self` access in tight loops MUST
be avoided.

Rationale: Primitive arguments enable register allocation without alias analysis.

```swift
func hot_loop(data: UnsafePointer<UInt8>, count: Int, stride: Int) {
    for index in 0..<count {
        process(data[index * stride])
    }
}
```

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names MUST capture what a thing is or does with precision.

Rationale: Great names are the essence of great code.

```text
# Prefer: pipeline, transfer, checkpoint, replica
# Avoid: data, info, manager, handler
```

### DX-02 — Use Swift naming conventions. **(Swift-adapted)**

Functions/variables MUST use lowerCamelCase. Types MUST use UpperCamelCase. Enum cases MUST use
lowerCamelCase. File names MUST follow project conventions.

Rationale: Swift conventions reduce friction and improve tooling compatibility.

```swift
struct AccountBalance { }
func processBatch(_ batch: [Record]) { }
enum ReplicaState { case follower, leader }
```

### DX-03 — Do not abbreviate names (except trivial loop counters).

Names MUST NOT be abbreviated unless the variable is a trivial loop counter.

Rationale: Abbreviations are ambiguous.

```swift
let connection = open_connection()
let response = read_response()
```

### DX-04 — Capitalize acronyms consistently.

Acronyms MUST use standard capitalization (HTTPClient, SQLQuery).

Rationale: Standard capitalization is unambiguous.

```swift
struct HTTPClient { }
struct SQLQuery { }
```

### DX-05 — Append units and qualifiers at the end, sorted by significance.

Units and qualifiers MUST be appended to names, sorted from most significant to least.

Rationale: Groups related variables visually and semantically.

```swift
let latency_ms_max = 120
let latency_ms_min = 3
```

### DX-06 — Use meaningful names that indicate lifecycle and ownership.

Resource names MUST convey lifecycle and ownership.

Rationale: Cleanup expectations should be obvious from the name.

```swift
let connection_pool = ConnectionPool()
let arena = ArenaAllocator()
```

### DX-07 — Align related names by character length when feasible.

Related names SHOULD be aligned by character length when feasible.

Rationale: Symmetry improves visual parsing.

```swift
let source_offset = 0
let target_offset = 0
```

### DX-08 — Prefix helper/callback names with the caller's name.

Helper names MUST be prefixed with the calling function's name.

Rationale: The prefix makes the call hierarchy visible in the name itself.

```swift
func read_sector() { }
func read_sector_validate() { }
```

### DX-09 — Callbacks go last in parameter lists.

Callback parameters MUST be the last parameters in a function signature.

Rationale: Callbacks are invoked last. Parameter order should mirror control flow.

```swift
func read_sector(disk: Disk, sector_id: Int, callback: (Result) -> Void) { }
```

### DX-10 — Order declarations by importance. Put public API first.

Within a file, the most important declarations (entry points, main functions, public API) MUST
appear first.

Rationale: Files are read top-down on first encounter.

```text
# File structure:
# 1. Entry point / main / public API
# 2. Core logic functions
# 3. Helper functions
# 4. Utilities and constants
```

### DX-11 — Struct layout: fields, then types, then methods.

Struct/class definitions MUST be ordered: data fields first, then nested types, then methods.

Rationale: Predictable layout lets the reader find what they need by position.

```swift
struct Replica {
    let term: Int64
    let status: Status

    enum Status { case follower, leader }

    func step(_ message: Message) { }
}
```

### DX-12 — Do not overload names that conflict with domain terminology.

Names MUST NOT be reused across different concepts in the same system.

Rationale: Overloaded terminology causes confusion.

```text
# Prefer: pending_transfer, consensus_prepare
# Avoid: two_phase_commit
```

### DX-13 — Prefer nouns over adjectives/participles for externally-referenced names.

Names that appear in documentation, logs, or external communication MUST be nouns or noun phrases.

Rationale: Noun names compose cleanly into derived identifiers and work in prose.

```swift
let pipeline_max = 32
logger.info("pipeline is full")
```

### DX-14 — Use named option structs when arguments can be confused.

When a function takes two or more arguments of the same type, a named options struct MUST be used.

Rationale: Positional arguments of the same type are silently swappable.

```swift
struct TransferOptions { let from: Account; let to: Account; let amount: Int64 }
transfer(TransferOptions(from: a, to: b, amount: 100))
```

### DX-15 — Name nullable parameters so nil's meaning is clear at the call site.

If a parameter accepts nil, the parameter name MUST make the meaning of nil obvious.

Rationale: `foo(nil)` is meaningless without context.

```swift
connect(host: host, timeout_ms: nil)
```

### DX-16 — Thread singletons positionally: general to specific.

Constructor parameters that are singletons MUST be passed positionally, ordered from most general
to most specific.

Rationale: Consistent constructor signatures reduce cognitive load.

```swift
Server(allocator, logger, configuration)
```

### DX-17 — Write descriptive commit messages.

Commit messages MUST be descriptive, informative, and explain the purpose of the change.

Rationale: Commit history is permanent documentation.

```text
Enforce bounded retry queue to prevent tail-latency spikes

Previously, the retry queue grew unboundedly under sustained load,
causing p99 latency to spike to 500ms. This change adds a fixed
upper bound of 1024 entries and rejects new retries when full.
```

### DX-18 — Explain "why" in code comments.

Comments MUST explain why the code was written this way, not what the code does.

Rationale: Without rationale, maintainers cannot evaluate whether the decision still applies.

```swift
// Why: fsync after every batch because we promised durability.
fsync(fd)
```

### DX-19 — Explain "how" for tests and complex logic.

Tests and complex algorithms MUST include a description at the top explaining the goal and
methodology.

Rationale: Tests are documentation of expected behavior.

```swift
// Test: verify that transfers reject overdrafts.
// Method: attempt balance, balance + 1, and zero.
func test_overdraft_rejection() { }
```

### DX-20 — Comments are well-formed sentences.

Comments MUST be complete sentences: space after delimiter, capital letter, full stop.
End-of-line comments may be phrases without punctuation.

Rationale: Well-written prose is easier to read and signals careful thinking.

```swift
// This avoids double-counting when a transfer is posted twice.
balance -= amount  // idempotent
```

---

## Cache Invalidation & State Hygiene (CIS)

### CIS-01 — Do not duplicate variables or alias state.

Every piece of state MUST have exactly one source of truth. Duplicating or aliasing state MUST NOT
be done.

Rationale: Duplicated state will eventually desynchronize.

```swift
let total = compute_total(items)
```

### CIS-02 — Pass large arguments by reference. **(Swift-adapted)**

Function arguments larger than 16 bytes MUST be passed by reference (`inout`, reference types, or
`UnsafePointer`) in performance-critical code.

Rationale: Passing large structs by value creates implicit copies.

```swift
func process(config: inout Config) { }
```

### CIS-03 — Prefer in-place initialization via `inout` or pointers. **(Swift-adapted)**

Large structs MUST be initialized in-place in performance-critical code.

Rationale: In-place initialization avoids intermediate copies and ensures pointer stability.

```swift
func init_config(target: inout Config) { }
```

### CIS-04 — If any field requires in-place init, the whole struct does. **(Swift-adapted)**

In-place initialization is viral. If any field requires in-place init, the entire containing
struct MUST also be initialized in-place.

Rationale: Mixing initialization strategies breaks pointer stability guarantees.

```swift
func init_container(target: inout Container) {
    init_subsystem(target: &target.subsystem)
    target.value = 0
}
```

### CIS-05 — Declare variables close to use. Shrink scope.

Variables MUST be computed or checked as close as possible to where they are used.

Rationale: Minimizing the check-to-use gap reduces TOCTOU-style bugs.

```swift
let offset = compute_offset(index)
buffer[offset] = value
```

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

Return types MUST be as simple as possible. `Void` > `Bool` > integer > optional > `Result`.

Rationale: Each additional dimension creates branches at every call site.

```swift
func validate(data: Data) {
    precondition(data.is_valid)
}
```

### CIS-07 — Do not `await` between assertions and dependent code. **(Swift-adapted)**

`await` MUST NOT occur between a precondition assertion and code that depends on it. Re-assert after
resumption.

Rationale: Suspension can invalidate preconditions.

```swift
precondition(connection.is_alive)
await other_work()
precondition(connection.is_alive)
connection.send(data)
```

### CIS-08 — Guard against buffer underflow (buffer bleeds).

All buffers MUST be fully utilized or the unused portion MUST be explicitly zeroed.

Rationale: Buffer underflow can leak sensitive information.

```swift
buffer.replaceSubrange(data.count..<buffer.count, with: repeatElement(0, count: pad))
```

### CIS-09 — Group allocation with deallocation using blank lines.

Resource allocation and its corresponding deallocation MUST be visually grouped using blank lines.

Rationale: Visual grouping makes resource leaks easy to spot during code review.

```swift
let fd = open(path)
defer { close(fd) }

let config = load_config()
```

---

## Off-by-One & Arithmetic (OBO)

### OBO-01 — Treat index, count, and size as distinct types.

Indexes, counts, and sizes MUST be treated as distinct concepts. Conversions MUST be explicit.

Rationale: Casual interchange of index, count, and size is the primary source of off-by-one errors.

```swift
let last_index = 9
let count = last_index + 1
let size_bytes = count * item_size
```

### OBO-02 — Use explicit division semantics.

All integer division MUST use an explicitly-named operation: exact, floor, or ceiling.

Rationale: Default `/` rounding behavior varies by language and surprises programmers.

```swift
let pages = div_ceil(total_bytes, page_size)
let aligned = div_floor(offset, alignment)
let slots = div_exact(buffer_size, slot_size)
```

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter.

All code MUST be formatted by `swift-format`.

Rationale: Automated formatting eliminates style debates in code review.

```text
swift-format --in-place Sources
```

### FMT-02 — Use 4-space indentation (or the project's declared standard).

Indentation MUST be 4 spaces unless the project explicitly declares a different standard.

Rationale: 4 spaces is visually distinct at a distance.

```swift
if condition {
    if nested {
        do_work()
    }
}
```

### FMT-03 — Hard limit all lines to 100 columns.

No line MUST exceed 100 columns.

Rationale: 100 columns allows two files side-by-side on a standard monitor.

```text
# If a line exceeds 100 columns, break it at logical boundaries.
```

### FMT-04 — Always use braces on if statements (unless single-line).

If statements MUST have braces unless the entire statement fits on a single line.

Rationale: Braceless multi-line if statements are the root cause of "goto fail" style bugs.

```swift
if done { return }

if done {
    cleanup()
    return
}
```

---

## Dependencies & Tooling (DEP)

### DEP-01 — Minimize dependencies.

The number of external dependencies MUST be minimized. Every dependency MUST be justified.

Rationale: Dependencies introduce supply chain risk, safety risk, performance risk, and
installation complexity.

```text
# Before adding a dependency, answer:
# 1. Can the standard library do this?
# 2. Can we write this in <100 lines?
# 3. Is the dependency actively maintained?
```

### DEP-02 — Prefer existing tools over adding new ones.

New tools MUST NOT be introduced when an existing tool can accomplish the task.

Rationale: A small, standardized toolbox is simpler to operate.

```text
# Before adding a new tool, answer:
# 1. Can an existing tool do this?
# 2. Is the marginal benefit worth the maintenance cost?
# 3. Will every team member need to learn this tool?
```

### DEP-03 — Prefer Swift for scripts and automation. **(Swift-adapted)**

Scripts MUST be written in Swift (or another typed, portable language). Shell scripts are allowed
only for trivial glue (< 20 lines).

Rationale: Typed scripts are portable, type-safe, and consistent with the toolchain.

```text
# Prefer: scripts/deploy.swift
# Avoid: scripts/deploy.sh
```

---

## Appendix: Rule Index

| ID | Rule (short form) | Swift-adapted? |
|----|-------------------|----------------|
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
