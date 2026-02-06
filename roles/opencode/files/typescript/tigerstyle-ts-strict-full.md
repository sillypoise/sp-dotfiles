# TigerStyle Rulebook — TypeScript / Strict / Full

## Preamble

### Purpose

This document is a comprehensive TypeScript coding rulebook derived from TigerBeetle's TigerStyle.
It is intended to be dropped into any TypeScript codebase as part of an `AGENTS.md` file, a system
prompt, or a code review checklist. Every rule is actionable and enforceable.

This is the **TypeScript-specific** variant. Rule IDs match the language-agnostic TigerStyle
rulebook for cross-referencing. Where TypeScript idioms differ from the language-agnostic version,
the adaptation is noted.

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

### TypeScript Runtime Context

**ESM is assumed** for both Node and browser environments.

**Node ESM:**
```typescript
// package.json: "type": "module"
// Use explicit file extensions in imports: "./foo.ts" or "./foo.js"
import assert from "node:assert/strict";
```

**Browser ESM:**
```typescript
// Browsers do not have node:assert. Use a lightweight assertion helper:
function assert(condition: unknown, message?: string): asserts condition {
  if (!condition) {
    throw new Error(message ?? "Assertion failed");
  }
}
```

**Shared guidance:**
- Use `import` / `export` exclusively. No `require()`.
- Use explicit file extensions where the runtime or bundler requires them.
- The assertion helper pattern above is portable across both environments.


### How to Use This Document

- Reference rules by ID (e.g., SAF-01, DX-05) in code reviews and commit messages.
- All 69 rules are organized into 7 categories.
- Each rule has: an imperative statement, a rationale, and a TypeScript example or template.
- Rules marked **(TS-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Do not use recursion.

All control flow MUST be simple, explicit, and statically analyzable. Recursion MUST NOT be used.
This ensures all executions that should be bounded are bounded.

Rationale: Predictable, bounded execution is the foundation of safety. Recursion makes it difficult
to prove termination and risks stack overflow.

```typescript
// Do: explicit loop with fixed bound
for (let i = 0; i < maxIterations; i++) {
  process(items[i]);
}

// Do not: recursive call
function process(items: Item[]): void {
  if (items.length === 0) return;
  process(items.slice(1)); // VIOLATION
}
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work MUST have a fixed
upper bound. Where a loop cannot terminate (e.g., an event loop or interval), this MUST be asserted.

Rationale: Unbounded work causes infinite loops, tail-latency spikes, and resource exhaustion.
The fail-fast principle demands that violations are detected sooner rather than later.

```typescript
const MAX_RETRIES = 5;

for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
  if (await tryConnect()) break;
}
assert(attempt < MAX_RETRIES, "connection retries exhausted");

// Bounded queue
class BoundedQueue<T> {
  private items: T[] = [];
  constructor(private readonly maxSize: number) {}

  enqueue(item: T): void {
    assert(this.items.length < this.maxSize, "queue full");
    this.items.push(item);
  }
}
```

### SAF-03 — Use precise types. Avoid `any`. Encode constraints in the type system. **(TS-adapted)**

All values MUST have the most precise type possible. `any` MUST NOT be used. `unknown` MUST be used
at system boundaries and narrowed explicitly. Use branded types to distinguish semantically different
values of the same underlying type. Use `bigint` when integer precision beyond `Number.MAX_SAFE_INTEGER`
is required.

Rationale: TypeScript lacks explicit integer sizing. Precise types, branded types, and runtime
guards are the TS equivalent of explicitly-sized types — they prevent unit confusion, overflow, and
type-level ambiguity.

```typescript
// Branded types for semantic distinction
type UserId = number & { readonly __brand: "UserId" };
type OrderId = number & { readonly __brand: "OrderId" };

function getUser(id: UserId): User { /* ... */ }
// getUser(orderId) — type error: OrderId is not UserId

// Unknown at boundaries, narrow explicitly
function parseInput(raw: unknown): Config {
  assert(typeof raw === "object" && raw !== null);
  assert("port" in raw && typeof raw.port === "number");
  assert(raw.port > 0 && raw.port <= 65535);
  return raw as Config;
}

// bigint for large precise values
const totalSupply: bigint = 1_000_000_000_000n;
```

### SAF-04 — Assert all preconditions, postconditions, and invariants.

Every function MUST assert its preconditions (valid arguments), postconditions (valid return values),
and any invariants that must hold during execution. A function MUST NOT operate blindly on unchecked
data.

Rationale: Assertions detect programmer errors. Unlike operating errors which must be handled,
assertion failures are unexpected. The only correct response to corrupt code is to crash. Assertions
downgrade catastrophic correctness bugs into liveness bugs.

```typescript
function transfer(from: Account, to: Account, amount: number): void {
  assert(from.id !== to.id, "cannot transfer to self");
  assert(amount > 0, "amount must be positive");
  assert(from.balance >= amount, "insufficient balance");

  from.balance -= amount;
  to.balance += amount;

  assert(from.balance >= 0, "balance must not go negative");
  assert(to.balance > 0, "target balance must be positive");
}
```

### SAF-05 — Maintain assertion density of at least 2 per function.

The assertion density of the codebase MUST average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs through testing and
fuzzing. Low assertion density leaves large regions of state space unchecked.

```typescript
function processBatch(items: Item[], maxSize: number): Result[] {
  assert(items.length <= maxSize, "batch exceeds max size");
  const results = doWork(items);
  assert(results.length === items.length, "result count mismatch");
  return results;
}
```

### SAF-06 — Pair assertions across different code paths.

For every property to enforce, there MUST be at least two assertions on different code paths that
verify the property. For example, assert validity before writing and after reading.

Rationale: Bugs hide at the boundary between valid and invalid data. A single assertion covers one
side; paired assertions cover the transition.

```typescript
// Assert before write
assert(record.checksum === computeChecksum(record.data));
await writeToDisk(record);

// Assert after read
const loaded = await readFromDisk(record.id);
assert(loaded.checksum === computeChecksum(loaded.data));
```

### SAF-07 — Split compound assertions.

Compound assertions MUST be split into individual assertions. Prefer `assert(a); assert(b);` over
`assert(a && b)`.

Rationale: Split assertions are simpler to read and provide precise failure information. A compound
assertion that fails gives no indication of which condition was violated.

```typescript
// Do
assert(index >= 0, "index must be non-negative");
assert(index < length, "index must be within bounds");

// Do not
assert(index >= 0 && index < length); // VIOLATION: compound
```

### SAF-08 — Use single-line implication assertions.

When a property B must hold whenever condition A is true, this MUST be expressed as a single-line
implication: `if (a) assert(b)`.

Rationale: Preserves logical intent without introducing complex boolean expressions or unnecessary
nesting.

```typescript
if (isCommitted) assert(hasQuorum, "committed without quorum");
if (isLeader) assert(term === currentTerm, "leader term mismatch");
```

### SAF-09 — Assert compile-time constants and type relationships.

Relationships between constants, configuration values, and type shapes MUST be asserted at build
time (using `satisfies`, conditional types, or startup assertions).

Rationale: Compile-time and startup assertions verify design integrity before the program runs in
production. They catch configuration drift and subtle invariant violations.

```typescript
// Compile-time: satisfies
const CONFIG = {
  maxBatchSize: 1024,
  bufferCapacity: 4096,
} as const satisfies Record<string, number>;

// Startup assertion
assert(
  CONFIG.maxBatchSize <= CONFIG.bufferCapacity,
  "batch must fit in buffer",
);

// Type-level assertion
type AssertExtends<T extends U, U> = T;
type _CheckHeader = AssertExtends<typeof HEADER_SIZE, 64>;
```

### SAF-10 — Assert both positive and negative space.

Assertions MUST cover both the positive space (what is expected) AND the negative space (what is not
expected). Where data moves across the valid/invalid boundary, both sides MUST be asserted.

Rationale: Most interesting bugs occur at the boundary between valid and invalid states. Asserting
only the happy path leaves the error path unchecked.

```typescript
if (index < length) {
  // Positive space: index is valid.
  assert(buffer[index] !== undefined, "buffer slot must be populated");
} else {
  // Negative space: index is out of bounds.
  assert(index === length, "index must not skip values");
}
```

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests MUST exercise valid inputs, invalid inputs, and the transitions between valid and invalid
states. Tests MUST NOT only cover the happy path.

Rationale: An analysis of production failures found that 92% of catastrophic failures resulted from
incorrect handling of non-fatal errors. Testing only valid data misses the majority of real-world
failure modes.

```typescript
describe("transfer", () => {
  it("succeeds with valid amount", () => {
    transfer(from, to, 100); // balance: 200
  });

  it("rejects zero amount", () => {
    expect(() => transfer(from, to, 0)).toThrow();
  });

  it("rejects overdraft", () => {
    expect(() => transfer(from, to, 300)).toThrow(); // balance: 200
  });

  it("handles exact balance (boundary)", () => {
    transfer(from, to, 200); // exact balance
    expect(from.balance).toBe(0);
  });

  it("rejects one over balance (boundary)", () => {
    expect(() => transfer(from, to, 201)).toThrow();
  });
});
```

### SAF-12 — Avoid unbounded allocations. Pre-size buffers. Reuse where possible. **(TS-adapted)**

Allocations in hot paths MUST be minimized. Arrays and buffers MUST be pre-sized where the upper
bound is known. Object creation inside loops or per-event handlers MUST be avoided when reuse is
feasible.

Rationale: While TypeScript runs on a garbage-collected runtime, excessive allocation causes GC
pressure, unpredictable pauses, and tail-latency spikes. Pre-sizing and reuse improve predictability.

```typescript
// Do: pre-sized buffer, reused across calls
const buffer = new ArrayBuffer(MAX_BUFFER_SIZE);
const view = new DataView(buffer);

function processBatch(items: Item[]): void {
  assert(items.length <= MAX_BATCH_SIZE);
  for (let i = 0; i < items.length; i++) {
    view.setUint32(i * 4, items[i].value);
  }
}

// Do not: allocate per event
function onMessage(msg: Message): void {
  const temp = new Uint8Array(msg.length); // VIOLATION: per-event allocation
  // ...
}
```

### SAF-13 — Declare variables at the smallest possible scope.

Variables MUST be declared at the smallest possible scope and the number of variables in any given
scope MUST be minimized. Use `const` by default; use `let` only when reassignment is required.
`var` MUST NOT be used.

Rationale: Fewer variables in scope reduces the probability that a variable is misused or confused
with another. `const` prevents accidental reassignment.

```typescript
// Do: const by default, smallest scope
for (const item of batch) {
  const checksum = computeChecksum(item);
  assert(checksum === item.expectedChecksum);
}

// Do not: var, premature declaration
var checksum = 0; // VIOLATION: var, declared far from use
// ... 30 lines ...
for (const item of batch) {
  checksum = computeChecksum(item);
}
```

### SAF-14 — Hard limit function length to 70 lines.

No function SHALL exceed 70 lines. This is a hard limit, not a guideline.

Rationale: There is a sharp cognitive discontinuity between a function that fits on screen and one
that requires scrolling. The 70-line limit forces clean decomposition.

```typescript
// If a function approaches 70 lines, split it:
// - Keep control flow (if/switch) in the parent function.
// - Move non-branching logic into helper functions.
// - Keep leaf functions pure (no state mutation).
```

### SAF-15 — Centralize control flow in parent functions.

When splitting a large function, all branching logic (if/switch) MUST remain in the parent function.
Helper functions MUST NOT contain control flow that determines program behavior.

Rationale: Centralizing control flow means there is exactly one place to understand all branches.
Scattered branching across helpers makes case analysis exponentially harder.

```typescript
// Do: parent owns all branching
function processRequest(request: Request): Response {
  switch (request.type) {
    case "read": {
      const data = readHelper(request.key);
      return respond(data);
    }
    case "write": {
      writeHelper(request.key, request.value);
      return acknowledge();
    }
    default:
      assert(false, `unexpected request type: ${request.type}`);
  }
}

// Do not: helper decides behavior
function readHelper(key: string, request: Request): Data {
  if (request.needsAuth) { // VIOLATION: control flow in helper
    authenticate(request);
  }
  // ...
}
```

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

Parent functions MUST own state mutation. Helper functions MUST compute and return values without
mutating shared state. Keep leaf functions pure.

Rationale: Pure helper functions are easier to test, reason about, and compose. When only one
function mutates state, bugs are localized to one site.

```typescript
// Do: helper computes, parent mutates
function updateBalance(account: Account, amount: number): void {
  const newBalance = computeNewBalance(account.balance, amount); // pure
  assert(newBalance >= 0, "balance must not go negative");
  account.balance = newBalance; // mutation in parent
}

function computeNewBalance(balance: number, amount: number): number {
  return balance - amount; // pure: no side effects
}

// Do not: helper mutates
function computeNewBalance(account: Account, amount: number): number {
  account.balance -= amount; // VIOLATION: mutation in leaf
  return account.balance;
}
```

### SAF-17 — Require TypeScript strict mode. Treat all warnings as errors. **(TS-adapted)**

`tsconfig.json` MUST enable `strict: true`. The following flags MUST be enabled explicitly (they are
included in `strict` but must not be disabled individually):

- `noImplicitAny`
- `strictNullChecks`
- `strictFunctionTypes`
- `strictBindCallApply`
- `noImplicitThis`
- `alwaysStrict`

Additionally, these MUST be enabled:
- `noUncheckedIndexedAccess`
- `noUnusedLocals`
- `noUnusedParameters`
- `exactOptionalPropertyTypes`

All ESLint (or Biome) warnings MUST be resolved, not suppressed.

Rationale: Strict mode catches the largest class of TypeScript bugs at compile time. Each disabled
flag is a category of bugs that becomes invisible.

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "target": "ESNext"
  }
}
```

### SAF-18 — Do not react directly to external events. Batch and process at your own pace.

Programs MUST NOT perform work directly in response to external events (network, user input,
timers). Instead, events MUST be queued and processed in controlled batches at the program's own
pace.

Rationale: Reacting directly to external events surrenders control flow to the environment, making
it impossible to bound work per time period. Batching restores control, improves throughput, and
enables assertion safety between batches.

```typescript
// Do: queue and batch
const eventQueue: Event[] = [];

function onMessage(event: Event): void {
  assert(eventQueue.length < MAX_QUEUE_SIZE, "event queue full");
  eventQueue.push(event);
}

function tick(): void {
  const batch = eventQueue.splice(0, MAX_BATCH_SIZE);
  processBatch(batch);
}

// Do not: react inline
function onMessage(msg: Message): void {
  process(msg); // VIOLATION: direct reaction, unbounded
}
```

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions (evaluating multiple booleans in one expression) MUST be split into
nested if/else branches. Complex `else if` chains MUST be rewritten as nested `else { if { } }`
trees.

Rationale: Compound conditions obscure case coverage. Nested branches make every case explicit and
verifiable.

```typescript
// Do: nested branches
if (isValid) {
  if (isAuthorized) {
    execute();
  } else {
    reject("unauthorized");
  }
} else {
  reject("invalid");
}

// Do not: compound condition
if (isValid && isAuthorized) { // VIOLATION: compound
  execute();
}
```

### SAF-20 — State invariants positively. Avoid negations.

Conditions MUST be stated in positive form. Comparisons MUST follow the natural grain of the domain
(e.g., `index < length` rather than `!(index >= length)`).

Rationale: Negations are error-prone and harder to verify. Positive conditions align with how
programmers naturally reason about loop bounds and index validity.

```typescript
// Do: positive form
if (index < length) {
  // invariant holds
} else {
  // invariant violated
}

// Do not: negated form
if (!(index < length)) { // VIOLATION: negation
  // ...
}
```

### SAF-21 — Handle all errors explicitly.

Every error MUST be handled explicitly. No error SHALL be silently ignored, swallowed, or discarded.
All Promises MUST have error handling. Unhandled rejections are defects.

Rationale: 92% of catastrophic production failures result from incorrect handling of non-fatal
errors. Silent error swallowing is the single largest class of preventable production failures.

```typescript
// Do: explicit error handling
try {
  const result = await fetchData();
  return result;
} catch (error: unknown) {
  assert(error instanceof Error, "unexpected error type");
  logger.error("fetchData failed", { error: error.message });
  throw error;
}

// Do not: swallowed error
await fetchData(); // VIOLATION: unhandled rejection possible
fetchData().catch(() => {}); // VIOLATION: silently swallowed
```

### SAF-22 — Always state the "why" in comments and commit messages.

Every non-obvious decision MUST be accompanied by a comment or commit message explaining why. Code
without rationale is incomplete.

Rationale: The "what" is in the code. The "why" is the only thing that enables safe future changes.
Without rationale, maintainers cannot evaluate whether the original decision still applies.

```typescript
// Do
// Why: batch to amortize network overhead; per-item fetch caused 3x latency.
await fetchBatch(items);

// Do not
await fetchBatch(items); // no explanation of design choice
```

### SAF-23 — Pass explicit options to library calls. Do not rely on defaults.

All options and configuration values MUST be passed explicitly at the call site. Default values
MUST NOT be relied upon.

Rationale: Defaults can change across library versions, causing latent, potentially catastrophic bugs
that are invisible at the call site.

```typescript
// Do: explicit options
const response = await fetch(url, {
  method: "GET",
  headers: { "Content-Type": "application/json" },
  signal: AbortSignal.timeout(5000),
});

// Do not: rely on defaults
const response = await fetch(url); // VIOLATION: implicit method, no timeout
```

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance MUST be considered during the design phase, not deferred to profiling. The largest
performance wins (1000x) come from architectural decisions that cannot be retrofitted.

Rationale: It is harder and less effective to fix a system after implementation. Mechanical sympathy
during design is like a carpenter working with the grain.

```typescript
// During design, answer:
// - What is the bottleneck resource? (network / disk / memory / CPU)
// - What is the expected throughput?
// - What is the latency budget per operation?
// - Can work be batched? Can we avoid serialization?
```

### PERF-02 — Perform back-of-the-envelope resource sketches.

Before implementation, back-of-the-envelope calculations MUST be performed for the four core
resources (network, disk, memory, CPU) across their two characteristics (bandwidth, latency).

Rationale: Sketches are cheap. They guide design into the right 90% of the solution space.

```typescript
// Example sketch for a message broker:
// - 10,000 messages/sec
// - Each message: ~1 KB JSON
// - Network: 10 MB/sec outbound (fits in 100 Mbps)
// - Memory: 10,000 * 1 KB in-flight = 10 MB (fine)
// - JSON.parse: ~10,000 calls/sec at ~0.1ms each = 1 sec of CPU/sec (BOTTLENECK)
// Decision: use binary format or batch parsing
```

### PERF-03 — Optimize the slowest resource first, weighted by frequency.

Optimization effort MUST target the slowest resource first (network > disk > memory > CPU), after
adjusting for frequency of access.

Rationale: Bottleneck-focused optimization yields the largest gains. Optimizing the wrong resource
wastes effort.

```typescript
// Priority order (adjust by frequency):
// 1. Network (ms latency, limited bandwidth)
// 2. Disk (us-ms latency, sequential vs random)
// 3. Memory (GC pressure, allocation rate, cache locality)
// 4. CPU (JSON parsing, crypto, compression)
```

### PERF-04 — Separate control plane from data plane.

The control plane (scheduling, coordination, metadata) MUST be clearly separated from the data plane
(bulk data processing).

Rationale: Mixing control and data operations prevents effective batching and forces a choice between
safety and throughput. Separation eliminates this tradeoff.

```typescript
// Control plane: validate, schedule, assert
const batch = controlPlane.prepare(requests);
assert(batch.isValid());

// Data plane: execute in bulk
await dataPlane.execute(batch);
```

### PERF-05 — Amortize costs via batching.

Network, disk, memory, and CPU costs MUST be amortized by batching accesses. Per-item processing
MUST be avoided when batching is feasible.

Rationale: Per-item overhead (round trips, context switches, GC pressure) dominates at high
throughput. Batching reduces overhead by orders of magnitude.

```typescript
// Do: batch
const items = collectBatch(MAX_BATCH_SIZE);
await writeAll(items); // one network call

// Do not: per-item
for (const item of items) {
  await write(item); // VIOLATION: round trip per item
}
```

### PERF-06 — Keep CPU work predictable. Avoid erratic control flow.

Hot paths MUST have predictable, linear control flow. Avoid branching, property lookups via dynamic
keys, and polymorphic call sites in performance-critical code.

Rationale: V8 optimizes for monomorphic call sites and predictable access patterns. Polymorphism
and dynamic property access cause deoptimization.

```typescript
// Do: monomorphic, predictable access
for (let i = 0; i < count; i++) {
  processItem(buffer[i]); // same shape every time
}

// Do not: polymorphic access
for (const item of mixedArray) {
  item.process(); // VIOLATION: different shapes deopt V8
}
```

### PERF-07 — Be explicit. Do not depend on engine optimizations.

Performance-critical code MUST be written explicitly. Do not rely on V8 to inline, unroll, or
optimize the code.

Rationale: Engine optimizations are heuristic and can regress across versions. Explicit code is
portable and verifiable.

```typescript
// Do: explicit, predictable
function sumArray(arr: number[], length: number): number {
  let total = 0;
  for (let i = 0; i < length; i++) {
    total += arr[i]!; // noUncheckedIndexedAccess: explicit assertion
  }
  return total;
}

// Do not: rely on engine magic
const total = arr.reduce((a, b) => a + b, 0); // allocation per step, less predictable
```

### PERF-08 — Use primitive arguments in hot loops. Avoid implicit `this`. **(TS-adapted)**

Hot loop functions MUST take primitive arguments directly. They MUST NOT access `this` or class
instance fields in tight loops where performance matters.

Rationale: Accessing `this` requires V8 to maintain hidden class chains and prevents certain
optimizations. Primitive arguments are register-friendly.

```typescript
// Do: standalone function with primitives
function processRange(data: Float64Array, start: number, end: number): number {
  let sum = 0;
  for (let i = start; i < end; i++) {
    sum += data[i]!;
  }
  return sum;
}

// Do not: method accessing this
class Processor {
  process(): number {
    let sum = 0;
    for (let i = this.start; i < this.end; i++) { // VIOLATION: this in hot loop
      sum += this.data[i]!;
    }
    return sum;
  }
}
```

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names MUST capture what a thing is or does with precision. Take time to find the name that provides
a crisp, intuitive mental model.

Rationale: Great names are the essence of great code. They reduce documentation burden and make the
code self-describing.

```typescript
// Do
pipeline, transfer, checkpoint, replica

// Do not
data, info, manager, handler, process // too vague
```

### DX-02 — Use camelCase for variables/functions, PascalCase for types. **(TS-adapted)**

Variables, functions, and methods MUST use `camelCase`. Types, interfaces, classes, and enums MUST
use `PascalCase`. File names MUST use `kebab-case`.

Rationale: These are the established TypeScript conventions. Consistency with the ecosystem reduces
friction for contributors and tools.

```typescript
// Variables and functions: camelCase
const maxRetries = 5;
function processRequest(request: Request): Response { /* ... */ }

// Types, interfaces, classes: PascalCase
interface TransferOptions { from: AccountId; to: AccountId; amount: number; }
class ReplicaManager { /* ... */ }

// Files: kebab-case
// transfer-engine.ts, replica-manager.ts, bounded-queue.ts
```

### DX-03 — Do not abbreviate names (except trivial loop counters).

Variable and function names MUST NOT be abbreviated unless the variable is a primitive integer used
as a loop counter (`i`, `j`, `k`). Script flags MUST use long form (`--force`, not `-f`).

Rationale: Abbreviations are ambiguous. The cost of typing extra characters is negligible; the cost
of misunderstanding is not.

```typescript
// Do
connection, request, response, configuration

// Do not
conn, req, res, cfg // VIOLATION: abbreviated
```

### DX-04 — Capitalize acronyms consistently.

Acronyms in names MUST use their standard capitalization in PascalCase contexts (`HTTPClient`,
`SQLQuery`). In camelCase contexts, treat the acronym as a word (`httpClient`, `sqlQuery`).

Rationale: Follow the TypeScript ecosystem convention: PascalCase preserves acronyms, camelCase
lowercases them. Be consistent within each casing context.

```typescript
// PascalCase context: preserve acronym
interface HTTPResponse { /* ... */ }
class SQLQueryBuilder { /* ... */ }

// camelCase context: lowercase acronym
const httpResponse = await fetch(url);
const sqlQuery = buildQuery(params);
```

### DX-05 — Append units and qualifiers at the end, sorted by significance.

Units and qualifiers MUST be appended to variable names, sorted from most significant to least
significant.

Rationale: This causes related variables to align visually and group semantically.

```typescript
// Do
const latencyMsMax = 500;
const latencyMsMin = 10;
const latencyMsP99 = 200;
const transferCountPending = 42;
const transferCountPosted = 100;

// Do not
const maxLatencyMs = 500; // VIOLATION: qualifier first
const minLatency = 10; // VIOLATION: no unit
```

### DX-06 — Use meaningful names that indicate lifecycle and ownership.

Resource names MUST convey their lifecycle, ownership, or allocation strategy.

Rationale: Knowing whether a resource needs explicit cleanup is critical for correctness.

```typescript
// Do: informative names
const connectionPool = createPool(config); // reader knows: return to pool
const requestAbortController = new AbortController(); // reader knows: can cancel

// Acceptable but less informative
const pool = createPool(config);
const controller = new AbortController();
```

### DX-07 — Align related names by character length when feasible.

When choosing names for related variables, PREFER names with the same character count so that
related expressions align visually.

Rationale: Symmetrical code is easier to scan and verify.

```typescript
// Do: "source" and "target" are both 6 characters
const sourceOffset = 0;
const targetOffset = 0;
copy(source.slice(sourceOffset), target.slice(targetOffset));

// Do not: "src" (3) and "dest" (4) misalign
const srcOffset = 0;
const destOffset = 0;
```

### DX-08 — Prefix helper/callback names with the caller's name.

When a function calls a helper or callback, the helper's name MUST be prefixed with the calling
function's name.

Rationale: The prefix makes the call hierarchy visible in the name itself.

```typescript
// Do
function readSector(disk: Disk, sectorId: number): Promise<Buffer> { /* ... */ }
function readSectorValidate(sector: Sector): void { /* ... */ }
function readSectorCallback(error: Error | null, data: Buffer): void { /* ... */ }

// Do not
function validateSector(sector: Sector): void { /* ... */ } // VIOLATION: no caller prefix
function onReadDone(data: Buffer): void { /* ... */ } // VIOLATION: inconsistent
```

### DX-09 — Callbacks go last in parameter lists.

Callback parameters MUST be the last parameters in a function signature.

Rationale: Callbacks are invoked last. Parameter order should mirror control flow.

```typescript
// Do
function readSector(
  disk: Disk,
  sectorId: number,
  callback: (error: Error | null, data: Buffer) => void,
): void { /* ... */ }

// Do not
function readSector(
  callback: (error: Error | null, data: Buffer) => void, // VIOLATION: first
  disk: Disk,
  sectorId: number,
): void { /* ... */ }
```

### DX-10 — Order declarations by importance. Put exports first.

Within a file, the most important declarations (exports, public API, entry points) MUST appear
first. Internal helpers and utilities follow.

Rationale: Files are read top-down on first encounter. The reader should encounter the most
important context first.

```typescript
// File structure:
// 1. Exports / public API
// 2. Core logic functions
// 3. Helper functions
// 4. Types, constants, utilities
```

### DX-11 — Interface/class layout: fields, then types, then methods. **(TS-adapted)**

Interface and class definitions MUST be ordered: data fields/properties first, then nested type
definitions, then methods.

Rationale: Predictable layout lets the reader find what they need by position.

```typescript
class Replica {
  // Fields first
  readonly term: number;
  readonly status: ReplicaStatus;
  private readonly log: Log;

  // Methods last
  constructor(config: ReplicaConfig) { /* ... */ }
  step(message: Message): void { /* ... */ }
}

// Types in a separate declaration
type ReplicaStatus = "follower" | "candidate" | "leader";
```

### DX-12 — Do not overload names that conflict with domain terminology.

Names MUST NOT be reused across different concepts in the same system.

Rationale: Overloaded terminology causes confusion in documentation, code review, and incident
response.

```typescript
// Do: distinct names for distinct concepts
interface PendingTransfer { /* ... */ } // domain: payment lifecycle
interface ConsensusProposal { /* ... */ } // domain: distributed protocol

// Do not: overloaded name
interface TwoPhaseCommit { /* ... */ } // VIOLATION: payments or consensus?
```

### DX-13 — Prefer nouns over adjectives/participles for externally-referenced names.

Names that appear in documentation, logs, or external communication MUST be nouns or noun phrases.

Rationale: Noun names compose cleanly into derived identifiers and work in prose without rephrasing.

```typescript
// Do
replica.pipeline; // "The pipeline is full" — works in docs
config.pipelineMax; // clean derived identifier

// Do not
replica.preparing; // "The preparing is..." — awkward in docs
```

### DX-14 — Use named option objects when arguments can be confused.

When a function takes two or more arguments of the same type, or arguments whose meaning is not
obvious at the call site, a named options object MUST be used.

Rationale: Positional arguments of the same type are silently swappable. Named fields make the call
site self-documenting.

```typescript
// Do: named options
interface TransferOptions {
  from: AccountId;
  to: AccountId;
  amount: number;
}

function transfer(options: TransferOptions): void { /* ... */ }

transfer({ from: accountA, to: accountB, amount: 100 });

// Do not: positional same-type args
function transfer(from: AccountId, to: AccountId, amount: number): void { /* ... */ }
transfer(accountA, accountB, 100); // which is from, which is to?
```

### DX-15 — Name nullable parameters so null's meaning is clear at the call site.

If a parameter accepts `null` or `undefined`, the parameter name MUST make the meaning of the
nullish value obvious when read at the call site.

Rationale: `foo(null)` is meaningless without context. `foo({ timeoutMs: undefined })` communicates
"no timeout."

```typescript
// Do
connect(host, { timeoutMs: undefined }); // clear: no timeout

// Do not
connect(host, undefined); // VIOLATION: meaning unclear
```

### DX-16 — Thread singletons positionally: general to specific.

Constructor parameters that are singletons (logger, config, database) MUST be passed positionally,
ordered from most general to most specific.

Rationale: Consistent constructor signatures reduce cognitive load.

```typescript
// Do: general -> specific
class UserService {
  constructor(
    private readonly logger: Logger,
    private readonly database: Database,
    private readonly config: UserServiceConfig,
  ) {}
}

// Do not: random order
class UserService {
  constructor(
    private readonly config: UserServiceConfig, // VIOLATION: most specific first
    private readonly logger: Logger,
    private readonly database: Database,
  ) {}
}
```

### DX-17 — Write descriptive commit messages.

Commit messages MUST be descriptive, informative, and explain the purpose of the change.

Rationale: Commit history is permanent documentation. Every `git blame` reader deserves context.

```text
# Do
"Enforce bounded retry queue to prevent tail-latency spikes

Previously, the retry queue grew unboundedly under sustained load,
causing p99 latency to spike to 500ms. This change adds a fixed
upper bound of 1024 entries and rejects new retries when full."

# Do not
"fix bug"
"update code"
"wip"
```

### DX-18 — Explain "why" in code comments.

Comments MUST explain why the code was written this way, not what the code does.

Rationale: Without rationale, future maintainers cannot evaluate whether the decision still applies.

```typescript
// Do
// Why: fsync-equivalent flush after every batch because we promised
// durability to the client. Losing acknowledged writes violates our SLA.
await flush(stream);

// Do not
// Flush the stream. // VIOLATION: restates the code
await flush(stream);
```

### DX-19 — Explain "how" for tests and complex logic.

Tests and complex algorithms MUST include a description at the top explaining the goal and
methodology.

Rationale: Tests are documentation of expected behavior. A reader should understand the test without
reading every assertion.

```typescript
/**
 * Test: verify that the transfer engine rejects overdrafts.
 *
 * Methodology: create an account with a known balance, attempt transfers
 * of exactly the balance (should succeed), balance + 1 (should fail),
 * and zero (should fail). Verify account balance is unchanged after
 * rejected transfers.
 */
describe("overdraft rejection", () => {
  // ...
});
```

### DX-20 — Comments are well-formed sentences.

Comments MUST be complete sentences: space after `//`, capital letter, full stop (or colon if
followed by related content). End-of-line comments may be phrases without punctuation.

Rationale: Well-written prose is easier to read and signals that the author has thought carefully.

```typescript
// Do
// This avoids double-counting when a transfer is posted twice.

// Do (end-of-line)
balance -= amount; // idempotent

// Do not
//this avoids double counting // VIOLATION: no space, no caps, no period
```

---

## Cache Invalidation & State Hygiene (CIS)

### CIS-01 — Do not duplicate variables or alias state.

Every piece of state MUST have exactly one source of truth. Variables MUST NOT be duplicated or
aliased unless there is a compelling performance reason, in which case the alias MUST be documented
and its synchronization asserted.

Rationale: Duplicated state will eventually desynchronize.

```typescript
// Do: single source of truth
const total = computeTotal(items);

// Do not: duplicated state
const cachedTotal = total; // VIOLATION: will desync if items change
```

### CIS-02 — Avoid copying large objects. Pass by reference. Avoid spread in hot paths. **(TS-adapted)**

Large objects MUST NOT be shallow-copied via spread (`...`) or `Object.assign` in hot paths.
Prefer passing the original reference and using `Readonly<T>` to signal immutability.

Rationale: Spreading large objects creates GC pressure and can mask bugs where the caller expects
mutations to be visible.

```typescript
// Do: pass by reference, signal immutability with Readonly
function processConfig(config: Readonly<LargeConfig>): void {
  assert(config.maxBatchSize > 0);
  // ... read config, don't mutate ...
}

// Do not: spread in hot path
function processConfig(config: LargeConfig): void {
  const copy = { ...config }; // VIOLATION: unnecessary copy
  // ...
}
```

### CIS-03 — Prefer in-place construction. Avoid intermediate copies. **(TS-adapted)**

Large objects MUST be constructed in-place (assign properties directly to the target) rather than
constructing an intermediate object and copying/spreading it.

Rationale: Intermediate copies waste memory and GC cycles. In-place construction is both faster and
clearer about the final shape.

```typescript
// Do: construct in place
function createReplica(config: ReplicaConfig): Replica {
  return {
    term: config.initialTerm,
    status: "follower",
    log: createLog(config.logCapacity),
  };
}

// Do not: intermediate then spread
function createReplica(config: ReplicaConfig): Replica {
  const base = createBaseReplica(); // intermediate
  return { ...base, term: config.initialTerm }; // VIOLATION: copy + override
}
```

### CIS-04 — If any property requires builder-pattern init, use it for the whole object. **(TS-adapted)**

If any field of a complex object requires multi-step initialization (builder pattern, async setup),
the entire object MUST use the same initialization strategy for consistency.

Rationale: Mixing initialization strategies makes the construction sequence harder to reason about.

```typescript
// Do: consistent builder
class ServerBuilder {
  private logger?: Logger;
  private database?: Database;

  setLogger(logger: Logger): this { this.logger = logger; return this; }
  setDatabase(database: Database): this { this.database = database; return this; }

  build(): Server {
    assert(this.logger !== undefined, "logger required");
    assert(this.database !== undefined, "database required");
    return new Server(this.logger, this.database);
  }
}
```

### CIS-05 — Declare variables close to use. Shrink scope.

Variables MUST be computed or checked as close as possible to where they are used. Do not introduce
variables before they are needed.

Rationale: Minimizing the gap between check and use reduces TOCTOU-style bugs.

```typescript
// Do: compute at point of use
const offset = computeOffset(index);
buffer[offset] = value;

// Do not: compute far from use
const offset = computeOffset(index);
// ... 20 lines of unrelated code ... // VIOLATION: gap
buffer[offset] = value;
```

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

Function return types MUST be as simple as possible. Prefer `void` over `boolean`, `boolean` over
`number`, `number` over `T | null`, `T | null` over `Result<T, E>`.

Rationale: Each additional dimension creates branches at every call site. This dimensionality is
viral, propagating through the call chain.

```typescript
// Preference order (simplest to most complex):
// void > boolean > number > T | null > T | undefined > Result<T, Error>

// Do: return void, assert internally
function validate(data: Data): void {
  assert(data.isValid(), "data must be valid");
}

// Avoid if possible: return result, force caller to branch
function validate(data: Data): Result<void, ValidationError> {
  // caller must handle error
}
```

### CIS-07 — Do not `await` between assertions and the code that depends on them. **(TS-adapted)**

Functions that contain precondition assertions MUST NOT have `await` expressions between the
assertion and the code that depends on it. If async work is required, assert again after resumption.

Rationale: `await` yields control. When execution resumes, the precondition may no longer hold. The
assertion becomes misleading documentation.

```typescript
// Do: assert and use without await
assert(connection.isAlive(), "connection must be alive");
connection.send(data); // synchronous send to buffer

// Do not: await between assert and use
assert(connection.isAlive());
await someOtherWork(); // VIOLATION: connection may have died
connection.send(data);

// If you must await, re-assert:
assert(connection.isAlive());
await someOtherWork();
assert(connection.isAlive(), "connection died during other work");
connection.send(data);
```

### CIS-08 — Guard against buffer underflow (buffer bleeds).

All buffers (ArrayBuffer, Uint8Array, etc.) MUST be fully utilized or the unused portion MUST be
explicitly zeroed. Buffers MUST NOT be sent or persisted with uninitialized or stale bytes.

Rationale: Buffer underflow can leak sensitive information and violate deterministic guarantees.

```typescript
// Do: zero unused space
const buffer = new Uint8Array(BUFFER_SIZE);
buffer.set(data);
buffer.fill(0, data.length); // zero the rest

// Do not: send buffer with stale padding
const buffer = new Uint8Array(BUFFER_SIZE);
buffer.set(data);
send(buffer); // VIOLATION: padding may contain stale data
```

### CIS-09 — Group allocation with cleanup using blank lines.

Resource allocation and its corresponding cleanup (try/finally, using, AbortController) MUST be
visually grouped using blank lines.

Rationale: Visual grouping makes resource leaks easy to spot during code review.

```typescript
// Do: visual grouping

const controller = new AbortController();
try {

  const response = await fetch(url, { signal: controller.signal });
  return await response.json();

} finally {
  controller.abort();
}
```

---

## Off-by-One & Arithmetic (OBO)

### OBO-01 — Treat index, count, and size as distinct concepts.

Indexes, counts, and sizes MUST be treated as conceptually distinct even though they share `number`.
Conversions MUST be explicit:
- index → count: add 1 (indexes are 0-based, counts are 1-based).
- count → size: multiply by unit size.

Consider branded types for critical numeric domains.

Rationale: Casual interchange of index, count, and size is the primary source of off-by-one errors.

```typescript
// Do: explicit conversion
const lastIndex = 9;
const count = lastIndex + 1; // 10 items (index -> count)
const sizeBytes = count * ITEM_SIZE; // count -> size

// Branded types for extra safety
type Index = number & { readonly __brand: "Index" };
type Count = number & { readonly __brand: "Count" };

function indexToCount(index: Index): Count {
  return (index + 1) as Count;
}

// Do not: implicit interchange
const buffer = new Uint8Array(lastIndex); // VIOLATION: is this count or index?
```

### OBO-02 — Use explicit division semantics.

All integer division MUST use a clearly-named helper that communicates rounding behavior.
JavaScript's `/` performs floating-point division; integer division requires `Math.floor`,
`Math.ceil`, or an exact-division assertion.

Rationale: JavaScript has no integer division operator. Using `/` without explicit rounding is
a latent bug in any integer context.

```typescript
function divExact(a: number, b: number): number {
  assert(b !== 0, "division by zero");
  assert(a % b === 0, `${a} is not exactly divisible by ${b}`);
  return a / b;
}

function divFloor(a: number, b: number): number {
  assert(b !== 0, "division by zero");
  return Math.floor(a / b);
}

function divCeil(a: number, b: number): number {
  assert(b !== 0, "division by zero");
  return Math.ceil(a / b);
}

// Do
const pages = divCeil(totalBytes, PAGE_SIZE);

// Do not
const pages = totalBytes / PAGE_SIZE; // VIOLATION: float result
```

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter.

All code MUST be formatted by the project's standard formatter (Prettier or Biome). No manual
formatting overrides are permitted.

Rationale: Automated formatting eliminates style debates in code review and ensures consistency.

```jsonc
// .prettierrc or biome.json — choose one, enforce in CI
{
  "semi": true,
  "singleQuote": false,
  "trailingComma": "all"
}
```

### FMT-02 — Use 2-space indentation. **(TS-adapted)**

Indentation MUST be 2 spaces. Tabs MUST NOT be used.

Rationale: 2 spaces is the established TypeScript/JavaScript convention and is the default for
Prettier, Biome, and the majority of TS codebases.

```typescript
// Do: 2 spaces
if (condition) {
  if (nested) {
    doWork();
  }
}
```

### FMT-03 — Hard limit all lines to 100 columns.

No line SHALL exceed 100 columns. No exceptions.

Rationale: 100 columns allows two files side-by-side on a standard monitor. The limit ensures code
is always fully visible during review and diffing.

```typescript
// If a line exceeds 100 columns, break it:
// - Add a trailing comma to trigger formatter wrapping.
// - Break at logical boundaries (after =>, after {, before arguments).
```

### FMT-04 — Always use braces on if statements (unless single-line).

If statements MUST have braces unless the entire statement (condition + body) fits on a single line.

Rationale: Braceless multi-line if statements are the root cause of "goto fail" style bugs.

```typescript
// Do: single-line, no braces needed
if (done) return;

// Do: multi-line, braces required
if (done) {
  cleanup();
  return;
}

// Do not: multi-line without braces
if (done)
  cleanup();
  return; // VIOLATION: not guarded by the if
```

---

## Dependencies & Tooling (DEP)

### DEP-01 — Minimize dependencies.

The number of external npm dependencies MUST be minimized. Every dependency MUST be justified by a
clear, documented need that cannot be reasonably met by the standard library, Web APIs, or a small
amount of custom code.

Rationale: npm dependencies introduce supply chain risk (typosquatting, malicious packages),
install-time cost, bundle size, and maintenance burden.

```typescript
// Before adding a dependency, answer:
// 1. Can the Web API or Node built-in do this?
// 2. Can we write this in <100 lines?
// 3. Is the dependency actively maintained?
// 4. What is the transitive dependency count? (check with `npm ls`)
// 5. What is the security track record? (check with `npm audit`)
```

### DEP-02 — Prefer existing tools over adding new ones.

New tools MUST NOT be introduced when an existing tool in the project's toolchain can accomplish
the task.

Rationale: A small, standardized toolbox is simpler to operate. Each new tool adds learning cost,
CI configuration, and cross-platform risk.

```typescript
// Before adding a new tool, answer:
// 1. Can an existing tool do this (perhaps with a flag or plugin)?
// 2. Is the marginal benefit worth the maintenance cost?
// 3. Will every team member need to learn this tool?
```

### DEP-03 — Prefer TypeScript for scripts and automation. **(TS-adapted)**

Scripts and automation MUST be written in TypeScript (via `tsx`, `ts-node`, or Deno). Shell scripts
are acceptable only for trivial glue (< 20 lines) with no logic.

Rationale: TypeScript scripts are type-safe, portable across macOS/Linux/Windows (via Node), and
catch errors at compile time.

```typescript
// Do: TypeScript script
// scripts/migrate.ts
import { readFile } from "node:fs/promises";

async function main(): Promise<void> {
  const data = await readFile("./data.json", "utf-8");
  // typed, cross-platform, testable
}

await main();
```

```bash
# Acceptable: trivial shell glue (< 20 lines, no logic)
#!/bin/bash
set -euo pipefail
npx tsx scripts/migrate.ts "$@"
```

---

## Appendix: Rule Index

| ID | Rule (short form) | TS-adapted? |
|----|-------------------|-------------|
| SAF-01 | Simple explicit control flow; no recursion | |
| SAF-02 | Bound everything | |
| SAF-03 | Precise types; no `any`; branded types | Yes |
| SAF-04 | Assert pre/post/invariants | |
| SAF-05 | Assertion density ≥ 2/function | |
| SAF-06 | Pair assertions across paths | |
| SAF-07 | Split compound assertions | |
| SAF-08 | Single-line implication asserts | |
| SAF-09 | Assert constants and type relationships | |
| SAF-10 | Assert positive and negative space | |
| SAF-11 | Test valid, invalid, and boundary | |
| SAF-12 | Avoid unbounded allocations; pre-size; reuse | Yes |
| SAF-13 | Smallest scope; const by default; no var | |
| SAF-14 | 70-line function limit | |
| SAF-15 | Centralize control flow in parent | |
| SAF-16 | Centralize state mutation; pure leaves | |
| SAF-17 | tsconfig strict; all warnings as errors | Yes |
| SAF-18 | Batch external events | |
| SAF-19 | Split compound conditions | |
| SAF-20 | Positive invariants; no negations | |
| SAF-21 | Handle all errors; no unhandled rejections | |
| SAF-22 | Always state the why | |
| SAF-23 | Explicit options; no defaults | |
| PERF-01 | Design for performance from start | |
| PERF-02 | Back-of-envelope resource sketches | |
| PERF-03 | Optimize slowest resource first | |
| PERF-04 | Separate control and data planes | |
| PERF-05 | Amortize via batching | |
| PERF-06 | Predictable CPU; monomorphic calls | |
| PERF-07 | Explicit; no engine reliance | |
| PERF-08 | Primitive args in hot loops; no this | Yes |
| DX-01 | Precise nouns and verbs | |
| DX-02 | camelCase vars/fns, PascalCase types, kebab files | Yes |
| DX-03 | No abbreviations | |
| DX-04 | Consistent acronym capitalization | |
| DX-05 | Units/qualifiers appended last | |
| DX-06 | Meaningful lifecycle names | |
| DX-07 | Align related names by length | |
| DX-08 | Prefix helpers with caller name | |
| DX-09 | Callbacks last in params | |
| DX-10 | Exports/public API first in file | |
| DX-11 | Class: fields → types → methods | Yes |
| DX-12 | No overloaded domain terms | |
| DX-13 | Noun names for external reference | |
| DX-14 | Named option objects for confusable args | |
| DX-15 | Name nullable params clearly | |
| DX-16 | Singletons: general → specific | |
| DX-17 | Descriptive commit messages | |
| DX-18 | Explain "why" in comments | |
| DX-19 | Explain "how" in tests | |
| DX-20 | Comments are sentences | |
| CIS-01 | No state duplication or aliasing | |
| CIS-02 | No spread/copy of large objects in hot paths | Yes |
| CIS-03 | In-place construction; no intermediate copies | Yes |
| CIS-04 | Consistent init strategy per object | Yes |
| CIS-05 | Declare close to use | |
| CIS-06 | Simpler return types | |
| CIS-07 | No await between assert and use | Yes |
| CIS-08 | Guard against buffer bleeds | |
| CIS-09 | Group alloc/cleanup visually | |
| OBO-01 | Index ≠ count ≠ size; branded types | |
| OBO-02 | Explicit division: divExact/divFloor/divCeil | |
| FMT-01 | Run Prettier or Biome | |
| FMT-02 | 2-space indent | Yes |
| FMT-03 | 100-column hard limit | |
| FMT-04 | Braces on if (unless single-line) | |
| DEP-01 | Minimize npm dependencies | |
| DEP-02 | Prefer existing tools | |
| DEP-03 | TypeScript for scripts | Yes |
