# React Best Practices — Unified Draft (TypeScript, React DOM + React Native)

Version: 0.1 (draft)
Date: February 2026

This document consolidates React best practices from the provided sources into a single
TypeScript-first guide. It covers React DOM, React Native, and React Server Components (RSC).
Framework-specific guidance is clearly labeled.

---

## Scope and Assumptions

- Language: TypeScript.
- Targets: React DOM and React Native.
- React Server Components (RSC): included as React core.
- Framework-specific rules are optional addenda.

---

## Design Goal Priority

All guidance serves three goals, in this order:

1. Safety — correctness and bounded behavior.
2. Performance — predictable, efficient execution.
3. Developer Experience — clarity and maintainability.

When goals conflict, higher-priority goals win.

---

## Exception Clause

Any rule in this document may be overridden in a specific instance if:

1. The exception is documented in a code comment or commit message.
2. The comment explains why the rule does not apply.
3. The exception is reviewed and approved by at least one other contributor.

Undocumented exceptions are violations.

---

## Tooling Baseline

- TypeScript: `strict: true` required.
- Linting: `oxc` with React + TypeScript rules enabled.
- React Compiler: enable when available; follow compiler-specific constraints.

Rationale: Strict typing and linting catch the highest rate of React bugs early. Compiler rules
reduce manual memoization and stabilize performance.

React Compiler notes:

- Destructure functions early in render (avoid `router.push()` dot access in handlers).
- React Native: use `.get()`/`.set()` for Reanimated shared values (compiler tracking).

---

## How to Use This Document

- Apply the core invariants across React DOM, React Native, and RSC.
- Use DOM- or RN-specific sections only when relevant to the platform.
- Treat framework-specific addenda as optional and opt-in.
- Prefer rules with concrete examples when implementing or refactoring.

## Core React Invariants

### 1) State is minimal ground truth

If a value can be derived from props or state, derive it during render. Do not store duplicates.

```tsx
// Bad: redundant state + effect
const [fullName, setFullName] = useState('')
useEffect(() => {
  setFullName(firstName + ' ' + lastName)
}, [firstName, lastName])

// Good: derive in render
const fullName = `${firstName} ${lastName}`
```

### 2) Use fallback state for user intent

Initialize state to `undefined` and use a fallback value from props or server data. This keeps
state as user intent and avoids sync effects.

```tsx
const [_theme, setTheme] = useState<string | undefined>(undefined)
const theme = _theme ?? serverTheme
```

### 3) Effects are for external synchronization only

If no external system is involved, do not use `useEffect`. Use event handlers or derive in
render. Effects are for DOM subscriptions, timers, network sync, and non-React systems.

```tsx
// Bad: event logic in effect
useEffect(() => {
  if (submitted) post('/api/register')
}, [submitted])

// Good: event logic in handler
function handleSubmit() {
  post('/api/register')
}
```

### 4) Use functional updates when state depends on current state

```tsx
setItems((current) => [...current, newItem])
```

Functional updates prevent stale closures and allow stable callbacks.

### 5) Avoid unnecessary memoization

Do not wrap simple primitive expressions with `useMemo`. Use memoization only for expensive
computations or referential stability across renders.

```tsx
// Bad
const isLoading = useMemo(() => a || b, [a, b])

// Good
const isLoading = a || b
```

### 6) Use refs for transient or high-frequency values

If a value changes often and does not need to re-render the UI, keep it in a ref.

```tsx
const pointerXRef = useRef(0)
```

### 7) Narrow effect dependencies

Depend on primitives rather than objects to avoid unnecessary re-runs.

```tsx
useEffect(() => {
  log(user.id)
}, [user.id])
```

### 8) Prefer `useSyncExternalStore` for external subscriptions

Avoid manual `useEffect` + `useState` sync for external stores. Use
`useSyncExternalStore` to keep subscriptions stable.

### 9) Avoid setState during render (last resort only)

If you must adjust state during render, guard it with a condition and keep it local to the
component. Prefer key resets or derived state instead.

---

### 10) When fetching in effects, handle race conditions

If you fetch in an effect, ignore stale responses in cleanup to prevent out-of-order updates.

```tsx
useEffect(() => {
  let ignore = false
  fetch(url).then((json) => {
    if (!ignore) setData(json)
  })
  return () => {
    ignore = true
  }
}, [url])
```

---

## Concurrency, Identity, and Safety

### 1) No side effects in render

Render must be pure. Do not mutate global state, perform I/O, or read browser APIs.

### 2) Avoid mutating props and state

Use immutable array helpers (`toSorted`, `toSpliced`, `toReversed`) or spread copies.

```tsx
const sorted = items.toSorted(compare)
```

### 3) Stable identity for instance-safe components

If you inject DOM IDs or run scripts, use `useId` to avoid collisions when multiple instances
render.

```tsx
const id = useId()
```

### 4) Event handlers in portals or alternate windows

When attaching global listeners in DOM, use the `ownerDocument` window for portal support.

```tsx
const win = node?.ownerDocument.defaultView ?? window
```

---

## Server Rendering, RSC, and Hydration

### 1) No browser APIs during server render

`window`, `document`, and `localStorage` are client-only. Access them inside effects or via
pre-hydration scripts.

### 2) Prevent hydration flicker for client-only values

If you must read client storage for critical UI (theme, locale), set it via a synchronous
inline script before hydration.

### 3) Suppress expected hydration mismatches only

Use `suppressHydrationWarning` only when a mismatch is intentional (timestamps, locale).

### 4) Minimize serialized props at RSC boundaries

Only pass fields a client component needs. Avoid passing large objects when only a subset is
used.

Prefer passing primitives or IDs and re-fetching on the client when needed.

### 5) Avoid duplicate serialization

Deduplication is by reference. Do not pass both a list and a transformed copy to client
components if the client can derive the transform.

### 6) Avoid waterfalls in server data fetching

Start independent async work immediately and `await` later. Compose server components to
parallelize data fetching.

### 7) Use `React.cache` for per-request deduplication

Wrap server-side queries to deduplicate within a single request.

### 8) Protect server-only values (experimental)

Use `experimental_taintUniqueValue` or `experimental_taintObjectReference` to prevent
accidental client serialization of secrets.

### 9) Initialize once per app load (not per mount)

If logic must run once per app load, guard it with a module-level flag. Components should be
resilient to remounts.

---

## Async and Waterfall Avoidance (React DOM + RSC)

### 1) Defer `await` until needed

Move awaits into the branches that use them.

### 2) Parallelize independent work

Use `Promise.all` for independent async operations. Start promises early and
`await` later.

### 3) Compose server components to parallelize

In RSC, split components so independent fetches run concurrently.

### 4) Use Suspense boundaries to stream UI

Wrap async subtrees in `Suspense` so layout renders while data loads.

---

## Rendering and Interaction Performance

### 1) Prefer explicit conditional rendering

Avoid `value && <Component />` when `value` can be `0` or `''`. On DOM it can render
unexpected text; on React Native it can crash.

```tsx
{count > 0 ? <Badge count={count} /> : null}
```

### 2) Use transitions for non-urgent updates

Wrap expensive, non-urgent state updates in `startTransition` or `useTransition`.

### 3) Prefer stable handler refs for subscriptions

When an effect subscribes to external events, use `useEffectEvent` (React 19+, experimental)
or a ref-based `useLatest` to avoid re-subscribing on every render.

---

## React DOM-Specific Practices

### 1) Use passive event listeners for scroll and touch

```ts
document.addEventListener('wheel', handler, { passive: true })
```

### 2) Avoid layout thrashing

Batch DOM reads and writes; prefer CSS classes over inline styles.

### 3) Hoist static JSX

Move static JSX out of render to avoid re-creation.

### 4) Use `content-visibility` for long lists

```css
.row {
  content-visibility: auto;
  contain-intrinsic-size: 0 72px;
}
```

### 5) Animate SVG wrappers, not SVG elements

Wrap the SVG in a `div` and animate the wrapper for better GPU acceleration.

---

## Bundle Size and Loading

### 1) Avoid barrel imports for large libraries

Import direct entry points when barrel files pull in large module graphs.

### 2) Use dynamic imports for heavy components

Lazy-load heavy or rarely used UI chunks (framework support required).

### 3) Preload on user intent

Preload bundles on hover/focus or feature-flag activation to reduce perceived
latency.

---

## React Native-Specific Practices

### 1) Strings must be rendered inside `<Text>`

```tsx
<View>
  <Text>{title}</Text>
</View>
```

### 2) Avoid `&&` with falsy renderables

`0` and `''` crash when rendered outside `<Text>`. Use explicit checks or ternaries.

### 3) Virtualize all lists

Prefer `FlashList` or `LegendList` over `ScrollView` for mapped lists.

### 4) Keep list items lightweight

No queries, heavy hooks, or expensive computation inside list items. Pass primitives.

### 5) Avoid inline objects in list item props

Inline objects break memoization. Hoist objects or pass primitives instead.

### 6) Keep list item references stable

Do not `map`/`filter` into new objects before passing data to virtualized lists.
Stable references prevent unnecessary re-renders.

### 7) Do not track scroll position in `useState`

Use Reanimated shared values or refs to avoid render thrash.

### 8) Animate with transform/opacity

Avoid layout properties in animations (`width`, `height`, `top`, `left`).

### 9) Use derived values for animation state

State represents truth (`pressed`, `progress`); visual values are derived.

### 10) Prefer `Pressable` or Gesture Handler

Use `Pressable` instead of legacy touchables. For animated press states, prefer
`GestureDetector` + Reanimated.

### 11) Prefer native navigation and modals

Use native stacks and tabs. Prefer native modals (`formSheet`) over JS bottom sheets.

---

## JavaScript Performance (Shared)

These are low-impact and only worth applying in hot paths.

- Avoid layout thrashing: batch DOM reads/writes.
- Build `Map`/`Set` for repeated lookups.
- Cache repeated function calls and storage reads.
- Combine multiple array iterations into one loop.
- Use `toSorted()` instead of `sort()` to avoid mutation.

---

## Optional Ecosystem Picks (React Native)

These are strong recommendations from the sources, but are not React core:

- Images: `expo-image` (or `solito/image`) for caching and performance.
- Menus: `zeego` for native menus.
- Galleries: `@nandorojo/galeria` for lightbox + shared transitions.

---

## Framework-Specific Addendum (Optional)

These apply when using framework-specific features and are not React core.

### Next.js

- Authenticate Server Actions like API routes.
- Use `after()` for non-blocking side effects.
- Use `next/dynamic` for heavy components and defer non-critical third-party
  libraries.
- Avoid barrel imports or use `optimizePackageImports`.

---

## References

- https://react.dev
- https://reactnative.dev
- https://vercel.com/blog/how-we-optimized-package-imports-in-next-js
- https://vercel.com/blog/how-we-made-the-vercel-dashboard-twice-as-fast
