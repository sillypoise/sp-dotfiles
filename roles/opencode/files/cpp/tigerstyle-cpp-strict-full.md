# TigerStyle Rulebook — C++ / Strict / Full

## Preamble

### Purpose

This document is a comprehensive C++ coding rulebook derived from TigerBeetle's TigerStyle. It is
intended to be dropped into any C++ codebase as part of an `AGENTS.md` file, a system prompt, or a
code review checklist. Every rule is actionable and enforceable.

This is the **C++-specific** variant. Rule IDs match the language-agnostic TigerStyle rulebook for
cross-referencing. Where C++ idioms differ from the language-agnostic version, the adaptation is
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

### C++ Baseline and Tooling

- Target: **C++20**.
- Formatter: `clang-format` (mandatory).
- Compilers: `clang` and `gcc` (both supported).
- Warnings are errors: `-Wall -Wextra -Werror -Wpedantic` at minimum (mandatory).
- Tests MUST run with sanitizers (`-fsanitize=address,undefined`) in CI.
- Prefer `clang-tidy` with a project-defined profile for high-signal diagnostics.

### Undefined Behavior Policy

- Undefined behavior MUST be treated as a correctness defect.
- Type-punning MUST use `std::memcpy` or `std::bit_cast`, not aliasing casts.
- Signed overflow MUST be avoided; use explicit bounds checks.

### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: an imperative statement, a rationale, and a C++ example or template.
- Rules marked **(C++-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Do not use recursion.

All control flow MUST be simple, explicit, and statically analyzable. Recursion MUST NOT be used.
This ensures all executions that should be bounded are bounded.

Rationale: Predictable, bounded execution is the foundation of safety. Recursion makes it difficult
to prove termination and risks stack overflow.

```cpp
for (std::uint32_t index = 0; index < max_iterations; index++) {
    process(items[index]);
}
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work MUST have a fixed
upper bound. Where a loop cannot terminate (e.g., an event loop), this MUST be asserted.

Rationale: Unbounded work causes infinite loops, tail-latency spikes, and resource exhaustion.

```cpp
for (std::uint32_t retry = 0; retry < max_retries; retry++) {
    if (try_connect()) {
        break;
    }
}
assert(retry < max_retries);
```

### SAF-03 — Use explicitly-sized integer types. **(C++-adapted)**

Integer types MUST be explicitly sized (`std::int32_t`, `std::int64_t`). `size_t` MUST NOT be used
unless required for indexing or API compatibility.

Rationale: Implicit sizing creates architecture-specific behavior and makes overflow analysis
impossible without knowing the target.

```cpp
std::uint32_t count = 0;
std::int64_t offset = 0;
std::size_t length = buffer.size(); // Only for API size/index.
```

### SAF-04 — Assert all preconditions, postconditions, and invariants.

Every function MUST assert its preconditions, postconditions, and invariants. A function MUST NOT
operate blindly on unchecked data.

Rationale: Assertions detect programmer errors. The only correct response to corrupt code is to
crash.

```cpp
void transfer(Account &from, Account &to, std::int64_t amount) {
    assert(&from != &to);
    assert(amount > 0);
    assert(from.balance >= amount);

    from.balance -= amount;
    to.balance += amount;

    assert(from.balance >= 0);
    assert(to.balance > 0);
}
```

### SAF-05 — Maintain assertion density of at least 2 per function.

The assertion density of the codebase MUST average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs.

```cpp
std::uint32_t process_batch(const Batch &batch, std::uint32_t max_size) {
    assert(batch.count <= max_size);
    assert(batch.items != nullptr);
    return batch.count;
}
```

### SAF-06 — Pair assertions across different code paths.

Every enforced property MUST have paired assertions on at least two different code paths.

Rationale: Bugs hide at the boundary between valid and invalid data.

```cpp
assert(record.checksum == compute_checksum(record));
write_record(record);

record = read_record();
assert(record.checksum == compute_checksum(record));
```

### SAF-07 — Split compound assertions.

Compound assertions MUST be split into individual assertions. PREFER `assert(a); assert(b);` over
`assert(a && b)`.

Rationale: Split assertions are simpler to read and provide precise failure information.

```cpp
assert(index >= 0);
assert(index < length);
```

### SAF-08 — Use single-line implication assertions.

When a property B must hold whenever condition A is true, express this as a single-line
implication: `if (a) assert(b)`.

Rationale: Preserves logical intent without complex boolean expressions or unnecessary nesting.

```cpp
if (is_leader) {
    assert(term == current_term);
}
```

### SAF-09 — Assert compile-time constants and type sizes. **(C++-adapted)**

Relationships between compile-time constants, type sizes, and configuration values MUST be
asserted at compile time (`static_assert`) or at program startup.

Rationale: Compile-time assertions verify design integrity before the program executes.

```cpp
static_assert(sizeof(Header) == 64, "header size must be 64 bytes");
static_assert(max_batch_size <= buffer_capacity, "batch too large");
```

### SAF-10 — Assert both positive and negative space.

Assertions MUST cover both the positive space (what is expected) AND the negative space (what is
not expected).

Rationale: Most interesting bugs occur at the boundary between valid and invalid states.

```cpp
if (index < length) {
    assert(buffer[index] != sentinel);
} else {
    assert(index == length);
}
```

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests MUST exercise valid inputs, invalid inputs, and the transitions between valid and invalid
states. Tests MUST NOT only cover the happy path.

Rationale: Most catastrophic failures stem from incorrect handling of non-fatal errors.

```text
Test valid:
- amount=100, balance=200 -> success

Test invalid:
- amount=0, balance=200 -> reject (zero amount)
- amount=300, balance=200 -> reject (insufficient funds)

Test boundary:
- amount=200, balance=200 -> success
- amount=201, balance=200 -> reject
```

### SAF-12 — Prefer static allocation after initialization. Avoid runtime reallocation.

All memory MUST be statically allocated at initialization. AVOID dynamically allocating or freeing
and reallocating memory after initialization.

Rationale: Dynamic allocation introduces unpredictable latency and fragmentation.

```cpp
static std::array<std::uint8_t, buffer_capacity> buffer;
initialize(buffer.data(), buffer.size());
```

### SAF-13 — Declare variables at the smallest possible scope.

Variables MUST be declared at the smallest possible scope and the number of variables in any given
scope MUST be minimized.

Rationale: Fewer variables in scope reduces the probability of misuse.

```cpp
for (std::uint32_t index = 0; index < count; index++) {
    std::uint32_t checksum = compute_checksum(items[index]);
    assert(checksum == items[index].checksum);
}
```

### SAF-14 — Keep functions short (~70 lines hard limit).

Functions MUST NOT exceed approximately 70 lines.

Rationale: There is a sharp cognitive discontinuity between a function that fits on screen and one
that requires scrolling.

```text
If a function approaches 70 lines, split it:
- Keep control flow in the parent function.
- Move non-branching logic into helpers.
- Keep leaf functions pure.
```

### SAF-15 — Centralize control flow in parent functions.

When splitting a large function, all branching logic (if/switch) MUST remain in the parent
function. Helper functions MUST NOT contain control flow that determines program behavior.

Rationale: Centralizing control flow means there is exactly one place to understand all branches.

```cpp
switch (request.type) {
case RequestType::Read:
    return read_helper(request.key);
case RequestType::Write:
    return write_helper(request.key, request.value);
default:
    assert(false);
    return Error::Invalid;
}
```

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

Parent functions MUST own state mutation. Helper functions MUST compute and return values without
mutating shared state.

Rationale: Pure helper functions are easier to test and reason about.

```cpp
void update_balance(Account &account, std::int64_t amount) {
    std::int64_t new_balance = compute_new_balance(account.balance, amount);
    assert(new_balance >= 0);
    account.balance = new_balance;
}

std::int64_t compute_new_balance(std::int64_t balance, std::int64_t amount) {
    return balance - amount;
}
```

### SAF-17 — Treat all warnings as errors; require sanitizers. **(C++-adapted)**

All compiler warnings MUST be enabled at the strictest available setting. Sanitizers MUST be
enabled for CI test builds.

Rationale: Warnings and UB hide correctness issues.

```text
Required flags:
-std=c++20 -Wall -Wextra -Werror -Wpedantic
-fsanitize=address,undefined (tests/CI)
```

### SAF-18 — Do not react directly to external events. Batch and process at your own pace.

Programs MUST NOT perform work directly in response to external events. Events MUST be queued and
processed in controlled batches.

Rationale: Batching restores control and bounds work per time period.

```cpp
event_queue.push(event);
if (event_queue.size() >= max_batch) {
    process_batch(event_queue);
}
```

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions MUST be split into nested if/else branches.

Rationale: Makes case coverage explicit and verifiable.

```cpp
if (is_valid) {
    if (is_authorized) {
        execute();
    } else {
        reject("unauthorized");
    }
} else {
    reject("invalid");
}
```

### SAF-20 — State invariants positively. Avoid negations.

Conditions MUST be stated in positive form. Comparisons MUST follow the natural grain of the
domain.

Rationale: Negations are error-prone and harder to verify.

```cpp
if (index < length) {
    use_index(index);
} else {
    handle_oob(index);
}
```

### SAF-21 — Handle all errors explicitly.

Every error MUST be handled explicitly. No error MUST be silently ignored or discarded.

Rationale: Error-handling bugs are the dominant cause of catastrophic production failures.

```cpp
auto result = write(fd, buffer, length);
if (result < 0) {
    log_errno("write failed");
    return Error::Io;
}
```

### SAF-22 — Always state the "why" in comments and commit messages.

Every non-obvious decision MUST be accompanied by a comment or commit message explaining why.

Rationale: The "why" enables safe future changes.

```cpp
// Why: batch to amortize syscalls; one-at-a-time caused 3x latency.
process_batch(items);
```

### SAF-23 — Pass explicit options to library calls. Avoid relying on defaults.

All options and configuration values MUST be passed explicitly at the call site. Defaults MUST NOT
be relied upon.

Rationale: Defaults can change across library versions, causing latent bugs.

```cpp
IoOptions options{ .timeout_ms = 5000, .retries = 3, .mode = IoMode::Sync };
io_request(options);
```

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance MUST be considered during the design phase, not deferred to profiling. The largest
performance wins come from architecture.

Rationale: It is harder and less effective to fix a system after implementation.

```text
During design, answer:
- What is the bottleneck resource? (network / disk / memory / CPU)
- What is the expected throughput?
- What is the latency budget per operation?
- Can work be batched?
```

### PERF-02 — Perform back-of-the-envelope resource sketches.

Back-of-the-envelope calculations MUST be performed for network, disk, memory, and CPU.

Rationale: Sketches are cheap. They guide design into the right 90% of the solution space.

```text
Example sketch:
- 10,000 requests/sec
- 1 KB payload
- Network: 10 MB/sec (fits in 1 Gbps)
- Disk: 2 MB/sec (fits in SSD bandwidth)
- Memory: 40 MB working set
```

### PERF-03 — Optimize the slowest resource first, weighted by frequency.

Optimization MUST target the slowest resource first, adjusted by access frequency.

Rationale: Bottleneck-focused optimization yields the largest gains.

```text
Priority order (adjust by frequency):
1. Network
2. Disk
3. Memory
4. CPU
```

### PERF-04 — Separate control plane from data plane.

The control plane (scheduling, coordination, metadata) MUST be clearly separated from the data
plane (bulk data processing).

Rationale: Mixing control and data operations prevents effective batching.

```text
Control plane: validate, schedule, assert
Data plane: execute in bulk
```

### PERF-05 — Amortize costs via batching.

Network, disk, memory, and CPU costs MUST be amortized by batching accesses. AVOID per-item
processing when batching is feasible.

Rationale: Per-item overhead dominates at high throughput.

```cpp
collect_batch(items, max_batch_size, batch);
write_all(batch.data(), batch.size());
```

### PERF-06 — Keep CPU work predictable. Avoid erratic control flow.

Hot paths MUST have predictable, linear control flow. AVOID branching and pointer chasing.

Rationale: Predictability enables prefetching and cache utilization.

```cpp
for (std::uint32_t index = 0; index < count; index++) {
    process(buffer[index]);
}
```

### PERF-07 — Be explicit. Do not depend on compiler optimizations.

Performance-critical code MUST be written explicitly. Do not depend on compiler unrolling or
vectorization.

Rationale: Compiler optimizations are heuristic and fragile.

```cpp
process(items[0]);
process(items[1]);
process(items[2]);
process(items[3]);
```

### PERF-08 — Use primitive arguments in hot loops. Avoid large receiver access.

Hot loop functions MUST take primitive arguments directly. Avoid accessing large structs in tight
loops.

Rationale: Primitive arguments are register-friendly.

```cpp
void hot_loop(const std::uint8_t *data, std::uint32_t length, std::uint32_t stride) {
    for (std::uint32_t index = 0; index < length; index++) {
        process(data[index * stride]);
    }
}
```

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names MUST capture what a thing is or does with precision. Take time to find the name that
provides a crisp mental model.

Rationale: Great names are the essence of great code.

```text
Prefer: pipeline, transfer, checkpoint, replica
Avoid: data, info, manager, handler
```

### DX-02 — Use snake_case for files, functions, and variables. **(C++-adapted)**

All file names, function names, and variable names MUST use snake_case. Types MUST follow project
convention consistently.

Rationale: Underscores separate words clearly and encourage descriptive names.

```text
Prefer: process_batch, user_account, latency_ms_max
```

### DX-03 — Do not abbreviate names (except trivial loop counters).

Variable and function names MUST NOT be abbreviated unless the variable is a primitive integer used
as a loop counter.

Rationale: Abbreviations are ambiguous.

```text
Prefer: connection, request, response, configuration
Avoid: conn, req, res, cfg
```

### DX-04 — Capitalize acronyms consistently.

Acronyms in names MUST use their standard capitalization, not title case.

Rationale: Standard capitalization is unambiguous.

```text
Prefer: HTTPClient, SQLQuery
Avoid: HttpClient, SqlQuery
```

### DX-05 — Append units and qualifiers at the end, sorted by significance.

Units and qualifiers MUST be appended to variable names, sorted from most significant to least.

Rationale: This causes related variables to align visually and group semantically.

```text
Prefer: latency_ms_max, latency_ms_min, latency_ms_p99
```

### DX-06 — Use meaningful names that indicate lifecycle and ownership.

Resource names MUST convey their lifecycle, ownership, or allocation strategy.

Rationale: Knowing whether a resource needs cleanup is critical for correctness.

```text
Prefer: arena, pool, lease
```

### DX-07 — Align related names by character length when feasible.

When choosing names for related variables, names MUST be aligned by character count when feasible.

Rationale: Symmetrical code is easier to scan and verify.

```text
Prefer: source_offset, target_offset
Avoid: src_offset, dest_offset
```

### DX-08 — Prefix helper/callback names with the caller's name.

When a function calls a helper or callback, the helper's name MUST be prefixed with the calling
function's name.

Rationale: The prefix makes the call hierarchy visible in the name itself.

```text
Prefer: read_sector_validate, read_sector_callback
```

### DX-09 — Callbacks go last in parameter lists.

Callback parameters MUST be the last parameters in a function signature.

Rationale: Parameter order should mirror control flow.

```cpp
using ReadCallback = void (*)(int status);
void read_sector(int fd, std::uint32_t sector_id, ReadCallback callback);
```

### DX-10 — Order declarations by importance. Put main/entry first.

Within a file, the most important declarations (entry points, public API) MUST appear first.

Rationale: Files are read top-down on first encounter.

```text
File order:
1. Public API
2. Core logic
3. Helpers
4. Utilities and constants
```

### DX-11 — Struct layout: fields, then types, then methods.

Struct definitions MUST be ordered: data fields first, then nested type definitions, then
functions that operate on the struct.

Rationale: Predictable layout lets the reader find what they need by position.

```cpp
struct Replica {
    std::uint64_t term;
    std::uint64_t index;
};

enum class ReplicaStatus {
    Follower,
    Leader,
};
```

### DX-12 — Do not overload names that conflict with domain terminology.

Names MUST NOT be reused across different concepts in the same system.

Rationale: Overloaded terminology causes confusion.

```text
Prefer: pending_transfer, consensus_prepare
Avoid: two_phase_commit
```

### DX-13 — Prefer nouns over adjectives/participles for externally-referenced names.

Names that appear in documentation, logs, or external communication MUST be nouns or noun
phrases.

Rationale: Noun names compose cleanly into derived identifiers and work in prose.

```text
Prefer: pipeline, queue, snapshot
```

### DX-14 — Use named option structs when arguments can be confused.

When a function takes two or more arguments of the same type, or arguments whose meaning is not
obvious at the call site, a named options struct MUST be used.

Rationale: Positional arguments of the same type are silently swappable.

```cpp
struct TransferOptions {
    Account *from;
    Account *to;
    std::int64_t amount;
};

void transfer(TransferOptions options);

transfer({ .from = &account_a, .to = &account_b, .amount = 100 });
```

### DX-15 — Name nullable parameters so null's meaning is clear at the call site.

If a parameter accepts null, the parameter name MUST make the meaning of null obvious.

Rationale: `foo(nullptr)` is meaningless without context.

```cpp
struct ConnectOptions {
    const char *host;
    const std::uint32_t *timeout_ms_or_null;
};
```

### DX-16 — Thread singletons positionally: general to specific.

Constructor parameters that are singletons MUST be passed positionally, ordered from most general
to most specific.

Rationale: Consistent constructor signatures reduce cognitive load.

```cpp
server_init(allocator, logger, config);
```

### DX-17 — Write descriptive commit messages.

Commit messages MUST be descriptive, informative, and explain the purpose of the change.

Rationale: Commit history is permanent documentation.

```text
Prefer:
"Bound retry queue to prevent tail-latency spikes"
```

### DX-18 — Explain "why" in code comments.

Comments MUST explain why the code was written this way, not what the code does.

Rationale: Without rationale, future maintainers cannot evaluate whether the decision still
applies.

```cpp
// Why: fsync after every batch because we promised durability to the client.
fsync(fd);
```

### DX-19 — Explain "how" for tests and complex logic.

Tests and complex algorithms MUST include a description at the top explaining the goal and
methodology.

Rationale: Tests are documentation of expected behavior.

```cpp
// Test: verify overdraft rejection.
// Method: use exact balance, balance+1, and zero to cover boundaries.
```

### DX-20 — Comments are well-formed sentences.

Comments MUST be complete sentences: space after the delimiter, capital letter, full stop.

Rationale: Well-written prose is easier to read and signals careful thinking.

```cpp
// This avoids double-counting when a transfer is posted twice.
```

---

## Cache Invalidation & State Hygiene (CIS)

### CIS-01 — Do not duplicate variables or alias state.

Every piece of state MUST have exactly one source of truth. Duplicating or aliasing state is
prohibited.

Rationale: Duplicated state will eventually desynchronize.

```cpp
total = compute_total(items);
```

### CIS-02 — Pass large arguments by const reference. **(C++-adapted)**

Function arguments larger than 16 bytes MUST be passed by `const &`, not by value.

Rationale: Passing large structs by value creates implicit copies.

```cpp
void process_config(const Config &config);
```

### CIS-03 — Prefer in-place initialization via out pointers. **(C++-adapted)**

Large structs MUST be initialized in-place by passing a target/out pointer, rather than returning a
value that is then copied.

Rationale: In-place initialization avoids intermediate copies and ensures pointer stability.

```cpp
void init_config(Config *out_config);
```

### CIS-04 — If any field requires in-place init, the whole struct does. **(C++-adapted)**

If any field of a struct requires in-place initialization, the entire containing struct MUST also
be initialized in-place.

Rationale: Mixing initialization strategies breaks pointer stability.

```cpp
void init_container(Container *out_container) {
    init_substruct(&out_container->substruct);
    out_container->value = 0;
}
```

### CIS-05 — Declare variables close to use. Shrink scope.

Variables MUST be computed or checked as close as possible to where they are used.

Rationale: Minimizing the check-to-use gap reduces TOCTOU risk.

```cpp
std::uint32_t offset = compute_offset(index);
buffer[offset] = value;
```

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

Return types MUST be as simple as possible. PREFER `void` over `bool`, `bool` over `int`, `int`
over optional, optional over error types.

Rationale: Each additional dimension creates branches at every call site.

```cpp
void validate_input(const Input &input) {
    assert(input.is_valid);
}
```

### CIS-07 — Functions should run to completion without re-entrancy.

Functions that contain precondition assertions MUST run to completion without re-entering event
loops or calling back into user code between assertion and use.

Rationale: Re-entrancy can invalidate preconditions, making assertions misleading.

```cpp
assert(connection_is_alive(connection));
send_data(connection, buffer, length);
```

### CIS-08 — Guard against buffer underflow (buffer bleeds).

All buffers MUST be fully utilized or the unused portion MUST be explicitly zeroed.

Rationale: Buffer underflow can leak sensitive information.

```cpp
std::memset(buffer + data_length, 0, buffer_size - data_length);
```

### CIS-09 — Group allocation with deallocation using blank lines.

Resource allocation and its corresponding deallocation MUST be visually grouped using blank lines.

Rationale: Visual grouping makes resource leaks easy to spot.

```cpp
auto file = std::fopen(path, "rb");
assert(file != nullptr);
defer_close(file);
```

---

## Off-by-One & Arithmetic (OBO)

### OBO-01 — Treat index, count, and size as distinct types.

Indexes, counts, and sizes MUST be treated as conceptually distinct. Conversions MUST be explicit.

Rationale: Casual interchange is the primary source of off-by-one errors.

```cpp
std::uint32_t last_index = 9;
std::uint32_t count = last_index + 1;
std::uint32_t size_bytes = count * item_size;
```

### OBO-02 — Use explicit division semantics. **(C++-adapted)**

All integer division MUST use an explicitly-named operation: exact, floor, or ceiling.

Rationale: Default `/` rounding behavior is easy to misread.

```cpp
auto pages = div_ceil(total_bytes, page_size);
auto slots = div_exact(buffer_size, slot_size);
```

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter. **(C++-adapted)**

All code MUST be formatted by `clang-format`.

Rationale: Automated formatting eliminates style debates.

```text
clang-format -i src/*.cc include/*.h
```

### FMT-02 — Use 4-space indentation.

Indentation MUST be 4 spaces unless the project explicitly declares a different standard.

Rationale: 4 spaces is more visually distinct than 2 spaces at a distance.

```cpp
if (condition) {
    do_work();
}
```

### FMT-03 — Hard limit all lines to 100 columns.

No line MUST exceed 100 columns.

Rationale: 100 columns allows two files side-by-side on a standard monitor.

```text
If a line exceeds 100 columns, wrap it or add a trailing comma for formatter wrapping.
```

### FMT-04 — Always use braces on if statements (unless single-line).

If statements MUST have braces unless the entire statement fits on a single line.

Rationale: Braceless multi-line if statements are the root cause of "goto fail" style bugs.

```cpp
if (done) {
    cleanup();
    return;
}
```

---

## Dependencies & Tooling (DEP)

### DEP-01 — Minimize dependencies.

The number of external dependencies MUST be minimized. Every dependency MUST be justified.

Rationale: Dependencies introduce supply chain risk, safety risk, performance risk, and
installation complexity.

```text
Before adding a dependency, answer:
1. Can the standard library do this?
2. Can we write this in <100 lines?
3. Is the dependency actively maintained?
```

### DEP-02 — Prefer existing tools over adding new ones.

New tools MUST NOT be introduced when an existing tool can accomplish the task.

Rationale: A small, standardized toolbox is simpler to operate than specialized instruments.

```text
Before adding a new tool, answer:
1. Can an existing tool do this?
2. Is the marginal benefit worth the maintenance cost?
```

### DEP-03 — Prefer typed, portable tooling for scripts.

Scripts and automation MUST prefer typed, portable languages over shell scripts.

Rationale: Shell scripts are not portable, not type-safe, and fail silently.

```text
Prefer: scripts/deploy.cc, scripts/migrate.py
Avoid: scripts/deploy.sh (complex logic)
```

---

## Appendix: Rule Index

| ID | Rule (short form) | C++-adapted? |
|----|-------------------|--------------|
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
| CIS-02 | Large args by const reference | Yes |
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
