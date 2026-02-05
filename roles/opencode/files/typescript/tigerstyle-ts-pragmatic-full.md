# TigerStyle Rulebook — TypeScript / Pragmatic / Full

## Preamble

### Purpose

This document is a comprehensive TypeScript coding rulebook derived from TigerBeetle's TigerStyle.
It is intended to be dropped into any TypeScript codebase as part of an `AGENTS.md` file, a system
prompt, or a code review checklist. Every rule is actionable. This is the pragmatic variant: rules
are strong recommendations that acknowledge tradeoffs and existing codebases.

This is the **TypeScript-specific** variant. Rule IDs match the language-agnostic TigerStyle
rulebook for cross-referencing. Where TypeScript idioms differ from the language-agnostic version,
the adaptation is noted.

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
- Each rule has: a recommendation, a rationale, and a TypeScript example or template.
- Rules marked **(TS-adapted)** have been adjusted from the language-agnostic version.

---

## Safety & Correctness (SAF)

### SAF-01 — Use simple, explicit control flow. Avoid recursion.

All control flow SHOULD be simple, explicit, and statically analyzable. AVOID recursion.

Rationale: Predictable, bounded execution is the foundation of safety. Recursion makes it difficult
to prove termination and risks stack overflow.

```typescript
// Prefer: explicit loop with fixed bound
for (let i = 0; i < maxIterations; i++) {
  process(items[i]);
}

// Avoid: recursive call
function process(items: Item[]): void {
  if (items.length === 0) return;
  process(items.slice(1));
}
```

### SAF-02 — Put a limit on everything.

All loops, queues, retries, buffers, and any form of repeated or accumulated work SHOULD have a
fixed upper bound. Where a loop cannot terminate (e.g., an event loop or interval), this SHOULD be
asserted.

Rationale: Unbounded work causes infinite loops, tail-latency spikes, and resource exhaustion.

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

All values SHOULD have the most precise type possible. AVOID `any`. Use `unknown` at system
boundaries and narrow explicitly. CONSIDER branded types to distinguish semantically different values
of the same underlying type. Use `bigint` when integer precision beyond `Number.MAX_SAFE_INTEGER`
is required.

Rationale: Precise types, branded types, and runtime guards are the TS equivalent of
explicitly-sized types — they prevent unit confusion, overflow, and type-level ambiguity.

```typescript
// Branded types for semantic distinction
type UserId = number & { readonly __brand: "UserId" };
type OrderId = number & { readonly __brand: "OrderId" };

function getUser(id: UserId): User { /* ... */ }

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

Every function SHOULD assert its preconditions, postconditions, and any invariants that must hold.

Rationale: Assertions detect programmer errors early. The only correct response to corrupt code is
to crash. Assertions downgrade catastrophic correctness bugs into liveness bugs.

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

The assertion density of the codebase SHOULD average a minimum of two assertions per function.

Rationale: High assertion density is a force multiplier for discovering bugs through testing.

```typescript
function processBatch(items: Item[], maxSize: number): Result[] {
  assert(items.length <= maxSize, "batch exceeds max size");
  const results = doWork(items);
  assert(results.length === items.length, "result count mismatch");
  return results;
}
```

### SAF-06 — Pair assertions across different code paths.

CONSIDER adding at least two assertions on different code paths per enforced property.

Rationale: Bugs hide at the boundary between valid and invalid data. Paired assertions cover the
transition.

```typescript
// Assert before write
assert(record.checksum === computeChecksum(record.data));
await writeToDisk(record);

// Assert after read
const loaded = await readFromDisk(record.id);
assert(loaded.checksum === computeChecksum(loaded.data));
```

### SAF-07 — Split compound assertions.

PREFER `assert(a); assert(b);` over `assert(a && b)`.

Rationale: Split assertions isolate failure causes and improve readability.

```typescript
// Prefer
assert(index >= 0, "index must be non-negative");
assert(index < length, "index must be within bounds");

// Avoid
assert(index >= 0 && index < length);
```

### SAF-08 — Use single-line implication assertions.

PREFER expressing implications as: `if (a) assert(b)`.

Rationale: Preserves logical intent without complex boolean expressions.

```typescript
if (isCommitted) assert(hasQuorum, "committed without quorum");
if (isLeader) assert(term === currentTerm, "leader term mismatch");
```

### SAF-09 — Assert compile-time constants and type relationships.

Constants, configuration values, and type relationships SHOULD be asserted at build time or startup.

Rationale: Catches design integrity violations before production.

```typescript
const CONFIG = {
  maxBatchSize: 1024,
  bufferCapacity: 4096,
} as const satisfies Record<string, number>;

assert(
  CONFIG.maxBatchSize <= CONFIG.bufferCapacity,
  "batch must fit in buffer",
);

type AssertExtends<T extends U, U> = T;
type _CheckHeader = AssertExtends<typeof HEADER_SIZE, 64>;
```

### SAF-10 — Assert both positive and negative space.

Assertions SHOULD cover both the positive space (expected) and the negative space (not expected).

Rationale: Most interesting bugs occur at the boundary between valid and invalid states.

```typescript
if (index < length) {
  assert(buffer[index] !== undefined, "buffer slot must be populated");
} else {
  assert(index === length, "index must not skip values");
}
```

### SAF-11 — Test valid data, invalid data, and boundary transitions exhaustively.

Tests SHOULD exercise valid inputs, invalid inputs, and the transitions between valid and invalid
states.

Rationale: 92% of catastrophic failures stem from incorrect handling of non-fatal errors.

```typescript
describe("transfer", () => {
  it("succeeds with valid amount", () => {
    transfer(from, to, 100);
  });

  it("rejects zero amount", () => {
    expect(() => transfer(from, to, 0)).toThrow();
  });

  it("rejects overdraft", () => {
    expect(() => transfer(from, to, 300)).toThrow();
  });

  it("handles exact balance (boundary)", () => {
    transfer(from, to, 200);
    expect(from.balance).toBe(0);
  });

  it("rejects one over balance (boundary)", () => {
    expect(() => transfer(from, to, 201)).toThrow();
  });
});
```

### SAF-12 — Avoid unbounded allocations. Pre-size buffers. Reuse where possible. **(TS-adapted)**

Allocations in hot paths SHOULD be minimized. Arrays and buffers SHOULD be pre-sized where the
upper bound is known. AVOID object creation inside loops or per-event handlers when reuse is
feasible.

Rationale: Excessive allocation causes GC pressure, unpredictable pauses, and tail-latency spikes.

```typescript
// Prefer: pre-sized buffer, reused across calls
const buffer = new ArrayBuffer(MAX_BUFFER_SIZE);
const view = new DataView(buffer);

function processBatch(items: Item[]): void {
  assert(items.length <= MAX_BATCH_SIZE);
  for (let i = 0; i < items.length; i++) {
    view.setUint32(i * 4, items[i].value);
  }
}

// Avoid: allocate per event
function onMessage(msg: Message): void {
  const temp = new Uint8Array(msg.length); // per-event allocation
}
```

### SAF-13 — Declare variables at the smallest possible scope.

Variables SHOULD be declared at the smallest possible scope. Use `const` by default; use `let` only
when reassignment is required. AVOID `var`.

Rationale: `const` prevents accidental reassignment. Tight scoping limits blast radius.

```typescript
// Prefer: const by default, smallest scope
for (const item of batch) {
  const checksum = computeChecksum(item);
  assert(checksum === item.expectedChecksum);
}

// Avoid: var, premature declaration
var checksum = 0;
// ... 30 lines ...
```

### SAF-14 — Keep functions short (~70 lines hard limit).

Functions SHOULD NOT exceed approximately 70 lines.

Rationale: Forces clean decomposition; eliminates scrolling discontinuity.

```typescript
// If a function approaches 70 lines, split it:
// - Keep control flow (if/switch) in the parent function.
// - Move non-branching logic into helper functions.
// - Keep leaf functions pure (no state mutation).
```

### SAF-15 — Centralize control flow in parent functions.

Branching logic (if/switch) SHOULD remain in the parent function. Helpers SHOULD NOT contain
control flow that determines program behavior.

Rationale: Centralizing control flow means one place to understand all branches.

```typescript
// Prefer: parent owns branching
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
```

### SAF-16 — Centralize state mutation. Keep leaf functions pure.

Parent functions SHOULD own state mutation. Helpers SHOULD compute and return values without
mutating shared state.

Rationale: Pure helpers are easier to test. Mutation localized to one site.

```typescript
// Prefer: helper computes, parent mutates
function updateBalance(account: Account, amount: number): void {
  const newBalance = computeNewBalance(account.balance, amount);
  assert(newBalance >= 0, "balance must not go negative");
  account.balance = newBalance;
}

function computeNewBalance(balance: number, amount: number): number {
  return balance - amount;
}
```

### SAF-17 — Require TypeScript strict mode. Enable all warnings. **(TS-adapted)**

`tsconfig.json` SHOULD enable `strict: true` and the following additional flags:

- `noUncheckedIndexedAccess`
- `noUnusedLocals`
- `noUnusedParameters`
- `exactOptionalPropertyTypes`

All ESLint (or Biome) warnings SHOULD be resolved, not suppressed.

Rationale: Strict mode catches the largest class of TypeScript bugs at compile time.

```jsonc
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

Programs SHOULD NOT perform work directly in response to external events. Events SHOULD be queued
and processed in controlled batches.

Rationale: Batching restores control, improves throughput, and enables assertion safety.

```typescript
// Prefer: queue and batch
const eventQueue: Event[] = [];

function onMessage(event: Event): void {
  assert(eventQueue.length < MAX_QUEUE_SIZE, "event queue full");
  eventQueue.push(event);
}

function tick(): void {
  const batch = eventQueue.splice(0, MAX_BATCH_SIZE);
  processBatch(batch);
}
```

### SAF-19 — Split compound conditions into nested branches.

Compound boolean conditions SHOULD be split into nested if/else branches.

Rationale: Nested branches make every case explicit and verifiable.

```typescript
// Prefer: nested branches
if (isValid) {
  if (isAuthorized) {
    execute();
  } else {
    reject("unauthorized");
  }
} else {
  reject("invalid");
}

// Avoid: compound condition
if (isValid && isAuthorized) {
  execute();
}
```

### SAF-20 — State invariants positively. Avoid negations.

PREFER positive form. Comparisons SHOULD follow the natural grain of the domain.

Rationale: Positive conditions align with natural reasoning about bounds and validity.

```typescript
// Prefer: positive form
if (index < length) {
  // invariant holds
} else {
  // invariant violated
}

// Avoid: negated form
if (!(index < length)) {
  // ...
}
```

### SAF-21 — Handle all errors explicitly.

Every error SHOULD be handled explicitly. AVOID silently ignoring errors. All Promises SHOULD have
error handling.

Rationale: 92% of catastrophic production failures result from incorrect error handling.

```typescript
// Prefer: explicit error handling
try {
  const result = await fetchData();
  return result;
} catch (error: unknown) {
  assert(error instanceof Error, "unexpected error type");
  logger.error("fetchData failed", { error: error.message });
  throw error;
}

// Avoid
await fetchData(); // unhandled rejection possible
fetchData().catch(() => {}); // silently swallowed
```

### SAF-22 — Always state the "why" in comments and commit messages.

Every non-obvious decision SHOULD be accompanied by a comment or commit message explaining why.

Rationale: "Why" enables safe future changes; "what" restates the code.

```typescript
// Prefer
// Why: batch to amortize network overhead; per-item fetch caused 3x latency.
await fetchBatch(items);

// Avoid
await fetchBatch(items); // no explanation
```

### SAF-23 — Pass explicit options to library calls. Avoid relying on defaults.

All options SHOULD be passed explicitly at the call site. AVOID relying on default values.

Rationale: Defaults can change across versions, introducing latent bugs.

```typescript
// Prefer: explicit options
const response = await fetch(url, {
  method: "GET",
  headers: { "Content-Type": "application/json" },
  signal: AbortSignal.timeout(5000),
});

// Avoid: implicit defaults
const response = await fetch(url);
```

---

## Performance & Design (PERF)

### PERF-01 — Design for performance from the start.

Performance SHOULD be considered during the design phase, not deferred to profiling.

Rationale: Architecture-level wins (1000x) cannot be retrofitted.

```typescript
// During design, answer:
// - What is the bottleneck resource?
// - What is the expected throughput?
// - What is the latency budget per operation?
// - Can work be batched?
```

### PERF-02 — Perform back-of-the-envelope resource sketches.

Back-of-the-envelope calculations SHOULD be performed for network, disk, memory, and CPU.

Rationale: Rough math guides design into the right 90%.

```typescript
// Example sketch for a message broker:
// - 10,000 messages/sec
// - Each message: ~1 KB JSON
// - JSON.parse: ~10,000 calls/sec at ~0.1ms each = 1 sec CPU/sec (BOTTLENECK)
// Decision: use binary format or batch parsing
```

### PERF-03 — Optimize the slowest resource first, weighted by frequency.

Optimization SHOULD target the slowest resource first, adjusted for access frequency.

Rationale: Bottleneck-focused optimization yields the largest gains.

```typescript
// Priority: network > disk > memory (GC) > CPU
```

### PERF-04 — Separate control plane from data plane.

Control plane SHOULD be clearly separated from data plane.

Rationale: Enables batching without sacrificing assertion safety.

```typescript
const batch = controlPlane.prepare(requests);
assert(batch.isValid());
await dataPlane.execute(batch);
```

### PERF-05 — Amortize costs via batching.

Costs SHOULD be amortized by batching. AVOID per-item processing when batching is feasible.

Rationale: Per-item overhead dominates at high throughput.

```typescript
// Prefer: batch
const items = collectBatch(MAX_BATCH_SIZE);
await writeAll(items);

// Avoid: per-item
for (const item of items) {
  await write(item);
}
```

### PERF-06 — Keep CPU work predictable. Avoid erratic control flow.

Hot paths SHOULD have predictable, linear control flow. AVOID polymorphic call sites and dynamic
property access in performance-critical code.

Rationale: V8 optimizes for monomorphic calls and predictable patterns.

```typescript
// Prefer: monomorphic, predictable
for (let i = 0; i < count; i++) {
  processItem(buffer[i]);
}

// Avoid: polymorphic
for (const item of mixedArray) {
  item.process(); // different shapes deopt V8
}
```

### PERF-07 — Be explicit. Do not depend on engine optimizations.

Performance-critical code SHOULD be written explicitly. AVOID relying on V8 to optimize.

Rationale: Engine optimizations are heuristic and can regress across versions.

```typescript
// Prefer: explicit
function sumArray(arr: number[], length: number): number {
  let total = 0;
  for (let i = 0; i < length; i++) {
    total += arr[i]!;
  }
  return total;
}

// Less predictable
const total = arr.reduce((a, b) => a + b, 0);
```

### PERF-08 — Use primitive arguments in hot loops. Avoid implicit `this`. **(TS-adapted)**

Hot loop functions SHOULD take primitive arguments. AVOID accessing `this` in tight loops.

Rationale: `this` requires hidden class chains and prevents optimizations.

```typescript
// Prefer: standalone function with primitives
function processRange(data: Float64Array, start: number, end: number): number {
  let sum = 0;
  for (let i = start; i < end; i++) {
    sum += data[i]!;
  }
  return sum;
}
```

---

## Developer Experience & Naming (DX)

### DX-01 — Choose precise nouns and verbs.

Names SHOULD capture what a thing is or does with precision.

Rationale: Great names are the essence of great code.

```typescript
// Prefer: pipeline, transfer, checkpoint, replica
// Avoid: data, info, manager, handler, process
```

### DX-02 — Use camelCase for variables/functions, PascalCase for types. **(TS-adapted)**

Variables, functions, methods: `camelCase`. Types, interfaces, classes, enums: `PascalCase`.
File names: `kebab-case`.

Rationale: Established TypeScript conventions reduce friction.

```typescript
const maxRetries = 5;
function processRequest(request: Request): Response { /* ... */ }
interface TransferOptions { from: AccountId; to: AccountId; amount: number; }
// File: transfer-engine.ts
```

### DX-03 — Do not abbreviate names (except trivial loop counters).

Names SHOULD NOT be abbreviated. Script flags SHOULD use long form.

Rationale: Abbreviations are ambiguous; full names are unambiguous.

```typescript
// Prefer: connection, request, response, configuration
// Avoid: conn, req, res, cfg
```

### DX-04 — Capitalize acronyms consistently.

PascalCase: preserve acronym (`HTTPClient`). camelCase: lowercase (`httpClient`).

Rationale: Consistent within each casing context.

```typescript
interface HTTPResponse { /* ... */ }
const httpResponse = await fetch(url);
```

### DX-05 — Append units and qualifiers at the end, sorted by significance.

Units and qualifiers SHOULD be appended, sorted from most significant to least.

Rationale: Groups related variables visually.

```typescript
const latencyMsMax = 500;
const latencyMsMin = 10;
const latencyMsP99 = 200;
```

### DX-06 — Use meaningful names that indicate lifecycle and ownership.

Resource names SHOULD convey lifecycle and ownership.

Rationale: Cleanup expectations should be obvious from the name.

```typescript
const connectionPool = createPool(config);
const requestAbortController = new AbortController();
```

### DX-07 — Align related names by character length when feasible.

CONSIDER names with the same character count for related variables.

Rationale: Symmetry improves visual parsing.

```typescript
const sourceOffset = 0;
const targetOffset = 0;
```

### DX-08 — Prefix helper/callback names with the caller's name.

Helpers SHOULD be prefixed with the calling function's name.

Rationale: Makes call hierarchy visible in the name.

```typescript
function readSector(disk: Disk, sectorId: number): Promise<Buffer> { /* ... */ }
function readSectorValidate(sector: Sector): void { /* ... */ }
function readSectorCallback(error: Error | null, data: Buffer): void { /* ... */ }
```

### DX-09 — Callbacks go last in parameter lists.

Callback parameters SHOULD be last.

Rationale: Mirrors control flow.

```typescript
function readSector(
  disk: Disk,
  sectorId: number,
  callback: (error: Error | null, data: Buffer) => void,
): void { /* ... */ }
```

### DX-10 — Order declarations by importance. Put exports first.

Exports and public API SHOULD appear first in a file.

Rationale: Files are read top-down.

```typescript
// 1. Exports / public API
// 2. Core logic
// 3. Helpers
// 4. Types, constants, utilities
```

### DX-11 — Interface/class layout: fields, then types, then methods. **(TS-adapted)**

Interface and class definitions SHOULD be ordered: fields first, then types, then methods.

Rationale: Predictable layout.

```typescript
class Replica {
  readonly term: number;
  readonly status: ReplicaStatus;
  private readonly log: Log;

  constructor(config: ReplicaConfig) { /* ... */ }
  step(message: Message): void { /* ... */ }
}

type ReplicaStatus = "follower" | "candidate" | "leader";
```

### DX-12 — Do not overload names that conflict with domain terminology.

AVOID reusing names across different concepts.

Rationale: Overloaded terms cause confusion.

```typescript
// Prefer: distinct names
interface PendingTransfer { /* ... */ }
interface ConsensusProposal { /* ... */ }

// Avoid
interface TwoPhaseCommit { /* ... */ } // payments or consensus?
```

### DX-13 — Prefer nouns over adjectives/participles for externally-referenced names.

Externally-referenced names SHOULD be nouns.

Rationale: Noun names compose cleanly in docs.

```typescript
replica.pipeline; // works as section header
config.pipelineMax; // clean derived identifier
```

### DX-14 — Use named option objects when arguments can be confused.

Functions with confusable arguments SHOULD use named option objects.

Rationale: Prevents silent transposition bugs.

```typescript
interface TransferOptions {
  from: AccountId;
  to: AccountId;
  amount: number;
}

function transfer(options: TransferOptions): void { /* ... */ }
transfer({ from: accountA, to: accountB, amount: 100 });
```

### DX-15 — Name nullable parameters so null's meaning is clear at the call site.

Nullable parameters SHOULD be named so the meaning of the nullish value is obvious.

Rationale: `foo(null)` is meaningless; `foo({ timeoutMs: undefined })` is not.

```typescript
connect(host, { timeoutMs: undefined }); // clear: no timeout
```

### DX-16 — Thread singletons positionally: general to specific.

Singleton constructor params SHOULD be ordered from most general to most specific.

Rationale: Consistent ordering reduces cognitive load.

```typescript
class UserService {
  constructor(
    private readonly logger: Logger,
    private readonly database: Database,
    private readonly config: UserServiceConfig,
  ) {}
}
```

### DX-17 — Write descriptive commit messages.

Commit messages SHOULD be descriptive and explain the purpose of the change.

Rationale: Commit history is permanent documentation.

```text
"Enforce bounded retry queue to prevent tail-latency spikes"
```

### DX-18 — Explain "why" in code comments.

Comments SHOULD explain why, not what.

Rationale: "Why" enables safe future changes.

```typescript
// Why: fsync-equivalent flush because we promised durability to the client.
await flush(stream);
```

### DX-19 — Explain "how" for tests and complex logic.

Tests SHOULD include a description of goal and methodology.

Rationale: Tests are documentation.

```typescript
/**
 * Test: verify that the transfer engine rejects overdrafts.
 * Methodology: create account with known balance, attempt transfers
 * at exact balance, balance + 1, and zero.
 */
describe("overdraft rejection", () => { /* ... */ });
```

### DX-20 — Comments are well-formed sentences.

Comments SHOULD be complete sentences. End-of-line comments may be phrases.

Rationale: Well-written prose signals careful thinking.

```typescript
// This avoids double-counting when a transfer is posted twice.
balance -= amount; // idempotent
```

---

## Cache Invalidation & State Hygiene (CIS)

### CIS-01 — Do not duplicate variables or alias state.

Every piece of state SHOULD have exactly one source of truth. AVOID duplication or aliasing.

Rationale: Duplicated state will desynchronize.

```typescript
const total = computeTotal(items);
// Avoid: const cachedTotal = total;
```

### CIS-02 — Avoid copying large objects. Pass by reference. Avoid spread in hot paths. **(TS-adapted)**

AVOID shallow-copying large objects via spread (`...`) or `Object.assign` in hot paths. PREFER
passing the original reference with `Readonly<T>`.

Rationale: Spreading creates GC pressure and can mask mutation bugs.

```typescript
function processConfig(config: Readonly<LargeConfig>): void {
  assert(config.maxBatchSize > 0);
  // read config, don't mutate
}

// Avoid
function processConfig(config: LargeConfig): void {
  const copy = { ...config }; // unnecessary copy
}
```

### CIS-03 — Prefer in-place construction. Avoid intermediate copies. **(TS-adapted)**

Large objects SHOULD be constructed in-place rather than via intermediate objects that are spread.

Rationale: Intermediate copies waste memory and GC cycles.

```typescript
// Prefer: construct in place
function createReplica(config: ReplicaConfig): Replica {
  return {
    term: config.initialTerm,
    status: "follower",
    log: createLog(config.logCapacity),
  };
}

// Avoid: intermediate then spread
function createReplica(config: ReplicaConfig): Replica {
  const base = createBaseReplica();
  return { ...base, term: config.initialTerm };
}
```

### CIS-04 — If any property requires builder-pattern init, use it for the whole object. **(TS-adapted)**

If any field requires multi-step initialization, the entire object SHOULD use the same strategy.

Rationale: Mixing strategies makes construction hard to reason about.

```typescript
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

Variables SHOULD be computed as close as possible to where they are used.

Rationale: Minimizes check-to-use gaps.

```typescript
const offset = computeOffset(index);
buffer[offset] = value;
// Avoid: 20 lines of unrelated code between compute and use
```

### CIS-06 — Prefer simpler return types to reduce call-site dimensionality.

PREFER simpler return types: void > boolean > number > T | null > Result<T, Error>.

Rationale: Each dimension creates viral call-site branching.

```typescript
// Prefer: return void, assert internally
function validate(data: Data): void {
  assert(data.isValid(), "data must be valid");
}
```

### CIS-07 — Do not `await` between assertions and the code that depends on them. **(TS-adapted)**

AVOID `await` between an assertion and the code that depends on it. If you must await, re-assert.

Rationale: `await` yields control; preconditions may no longer hold on resume.

```typescript
// Prefer
assert(connection.isAlive());
connection.send(data);

// If you must await, re-assert:
assert(connection.isAlive());
await someOtherWork();
assert(connection.isAlive(), "connection died during other work");
connection.send(data);
```

### CIS-08 — Guard against buffer underflow (buffer bleeds).

Unused buffer space SHOULD be explicitly zeroed before use or transmission.

Rationale: Buffer underflow can leak sensitive data.

```typescript
const buffer = new Uint8Array(BUFFER_SIZE);
buffer.set(data);
buffer.fill(0, data.length); // zero the rest
```

### CIS-09 — Group allocation with cleanup using blank lines.

Allocation and cleanup SHOULD be visually grouped with blank lines.

Rationale: Makes leaks easy to spot.

```typescript

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

Indexes, counts, and sizes SHOULD be treated as distinct. Conversions SHOULD be explicit.
CONSIDER branded types for critical numeric domains.

Rationale: Casual interchange is the primary source of off-by-one errors.

```typescript
const lastIndex = 9;
const count = lastIndex + 1; // index -> count
const sizeBytes = count * ITEM_SIZE; // count -> size

type Index = number & { readonly __brand: "Index" };
type Count = number & { readonly __brand: "Count" };
```

### OBO-02 — Use explicit division semantics.

All integer division SHOULD use a helper with clear rounding behavior. JavaScript's `/` is
floating-point; integer division requires explicit rounding.

Rationale: Using `/` without rounding is a latent bug in integer contexts.

```typescript
function divExact(a: number, b: number): number {
  assert(b !== 0, "division by zero");
  assert(a % b === 0, `${a} is not exactly divisible by ${b}`);
  return a / b;
}

const pages = divCeil(totalBytes, PAGE_SIZE);
```

---

## Formatting & Code Style (FMT)

### FMT-01 — Run the formatter.

All code SHOULD be formatted by the project's standard formatter (Prettier or Biome).

Rationale: Eliminates style debates and ensures consistency.

```jsonc
// .prettierrc or biome.json
{ "semi": true, "singleQuote": false, "trailingComma": "all" }
```

### FMT-02 — Use 2-space indentation. **(TS-adapted)**

Indentation SHOULD be 2 spaces. Tabs SHOULD NOT be used.

Rationale: 2 spaces is the established TS/JS convention.

```typescript
if (condition) {
  if (nested) {
    doWork();
  }
}
```

### FMT-03 — Hard limit all lines to 100 columns.

Lines SHOULD NOT exceed 100 columns.

Rationale: Ensures side-by-side review with no horizontal scroll.

```typescript
// Break long lines at logical boundaries, use trailing commas.
```

### FMT-04 — Always use braces on if statements (unless single-line).

If statements SHOULD have braces unless the entire statement fits on a single line.

Rationale: Prevents "goto fail" class bugs.

```typescript
if (done) return; // single-line: ok

if (done) {
  cleanup();
  return;
}
```

---

## Dependencies & Tooling (DEP)

### DEP-01 — Minimize dependencies.

npm dependencies SHOULD be minimized and justified.

Rationale: Supply chain risk, bundle size, maintenance burden.

```typescript
// Before adding a dependency:
// 1. Can the Web API or Node built-in do this?
// 2. Can we write this in <100 lines?
// 3. What is the transitive count? (npm ls)
// 4. Security track record? (npm audit)
```

### DEP-02 — Prefer existing tools over adding new ones.

New tools SHOULD NOT be introduced when an existing tool suffices.

Rationale: Tool sprawl increases complexity.

### DEP-03 — Prefer TypeScript for scripts and automation. **(TS-adapted)**

Scripts SHOULD be written in TypeScript (via `tsx`, `ts-node`, or Deno). Shell scripts are
acceptable for trivial glue (< 20 lines).

Rationale: TypeScript scripts are type-safe, portable, and testable.

```typescript
// scripts/migrate.ts
import { readFile } from "node:fs/promises";

async function main(): Promise<void> {
  const data = await readFile("./data.json", "utf-8");
  // typed, cross-platform, testable
}

await main();
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
| SAF-14 | ~70-line function limit | |
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
