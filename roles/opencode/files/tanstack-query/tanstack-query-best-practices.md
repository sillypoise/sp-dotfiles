# TanStack Query Best Practices (TypeScript, React)

Version: 0.1 (draft)
Date: February 2026

This document consolidates TanStack Query best practices into a TypeScript-first guide. It targets
React DOM and React Native and assumes TanStack Query v5. Framework-specific SSR notes are labeled.

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

## Baseline Setup and Defaults

- Use a single `QueryClientProvider` at the app root.
- Configure defaults intentionally; know the built-in behavior:
  - Queries are **stale by default** (`staleTime: 0`).
  - Stale queries refetch on mount, focus, and reconnect.
  - Failed queries retry **3 times** with exponential backoff.
  - Inactive queries are GC'd after **5 minutes** (`gcTime`).
  - Structural sharing keeps data references stable for JSON data.

```ts
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,
      gcTime: 5 * 60 * 1000,
      retry: 2,
    },
  },
})
```

---

## Query Keys and Identity

- Query keys MUST be arrays and JSON-serializable.
- Include every variable used by the `queryFn` in the key.
- Treat key order as semantic; array order changes the cache identity.
- Prefer structured keys (string + params object) for clarity.

```ts
useQuery({ queryKey: ['todos', { status, page }], queryFn: fetchTodos })
```

---

## Query Functions

- Query functions MUST return a promise and **throw** on errors.
- If using `fetch`, throw on non-OK responses.
- Use the provided `AbortSignal` to support cancellation.

```ts
const query = useQuery({
  queryKey: ['todo', todoId],
  queryFn: async ({ signal }) => {
    const response = await fetch(`/todos/${todoId}`, { signal })
    if (!response.ok) throw new Error('Request failed')
    return response.json()
  },
})
```

---

## Options and Type Inference

- Use `queryOptions`/`mutationOptions` to share typed options across usage sites.
- Prefer `select` for render minimization and derive view-specific data.
- Memoize `select` with `useCallback` or a stable function.

```ts
function groupOptions(id: number) {
  return queryOptions({
    queryKey: ['groups', id],
    queryFn: () => fetchGroups(id),
    staleTime: 5 * 1000,
  })
}

const query = useQuery({
  ...groupOptions(1),
  select: useCallback((data) => data.name, []),
})
```

---

## Caching, Staleness, and Refetching

- Set `staleTime` deliberately for each domain.
- Use `refetchOnWindowFocus`/`refetchOnReconnect` only when the user expects live updates.
- Use `refetchInterval` sparingly; prefer event-driven refresh.
- Use `initialData` only for **complete** data. Use `placeholderData` for partial data.

```ts
const query = useQuery({
  queryKey: ['projects', page],
  queryFn: () => fetchProjects(page),
  placeholderData: keepPreviousData,
})
```

---

## Parallelism and Waterfalls

- Parallelize independent queries (multiple `useQuery` calls in the same component are parallel).
- With Suspense, use `useSuspenseQueries` to avoid serial fetches.
- Avoid dependent queries when possible; refactor APIs to flatten waterfalls.
- Prefetch to flatten unavoidable waterfalls (router or event-based prefetching).

```ts
const [users, teams] = useSuspenseQueries({
  queries: [
    { queryKey: ['users'], queryFn: fetchUsers },
    { queryKey: ['teams'], queryFn: fetchTeams },
  ],
})
```

---

## Disabling and Lazy Queries

- Prefer `enabled` for conditional queries; avoid permanently disabled queries.
- In TS, `skipToken` is type-safe, but `refetch()` will not work with it.

```ts
const query = useQuery({
  queryKey: ['todos', filter],
  queryFn: filter ? () => fetchTodos(filter) : skipToken,
})
```

---

## Mutations and Invalidation

- Invalidate queries on mutation success to keep server state fresh.
- Prefer targeted invalidation with query keys or filters.
- Use `setQueryData` to update from mutation responses (avoid refetches).
- Update cache immutably; never mutate cached objects in place.

```ts
const mutation = useMutation({
  mutationFn: updateTodo,
  onSuccess: (data, variables) => {
    queryClient.setQueryData(['todo', { id: variables.id }], data)
  },
})
```

---

## Optimistic Updates

- Use `onMutate` to snapshot and optimistically update.
- Roll back in `onError` using the snapshot.
- Always invalidate on `onSettled` to reconcile with server.

---

## Pagination and Infinite Queries

- Prefer `placeholderData` or `keepPreviousData` to avoid UI flicker.
- For infinite queries, guard `fetchNextPage` when already fetching.
- Consider `maxPages` to bound memory usage.

```tsx
const query = useInfiniteQuery({
  queryKey: ['projects'],
  queryFn: fetchProjects,
  initialPageParam: 0,
  getNextPageParam: (lastPage) => lastPage.nextCursor,
  maxPages: 3,
})
```

---

## SSR and Hydration (Framework-Specific)

- Create the `QueryClient` **inside** the app, per request.
- Prefer `dehydrate`/`HydrationBoundary` over `initialData` for SSR.
- Use `prefetchQuery` for server preloading; `fetchQuery` only when you need errors.
- Serialize safely in custom SSR; use safe serializers (e.g., devalue).

```tsx
const [queryClient] = React.useState(
  () => new QueryClient({ defaultOptions: { queries: { staleTime: 60 * 1000 } } })
)
```

---

## Network Mode and Cancellation

- Choose network mode intentionally: `online`, `offlineFirst`, or `always`.
- Use `AbortSignal` for cancellation and `queryClient.cancelQueries` for manual cancel.

---

## Render Optimizations

- Use `select` to subscribe to the smallest slice.
- Avoid object rest destructuring on query results; it disables tracked props.
- Prefer stable `select` functions to reduce recomputation.

---

## React Native Notes

- Wire focus and online status using `focusManager` and `onlineManager`.
- Use `AppState` and network listeners to keep refetch consistent.
- Consider `subscribed: isFocused` to avoid updates on unfocused screens.

---

## Testing

- Use a fresh `QueryClient` per test and wrap in `QueryClientProvider`.
- Disable retries for failing tests (`retry: false`).
- Consider `gcTime: Infinity` to prevent lingering timers in Jest.

---

## Footguns and Anti-Patterns

- Unstable query keys (objects/functions created in render).
- Missing variables in query keys.
- `initialData` with partial data (use `placeholderData` instead).
- Over-invalidating (use targeted `invalidateQueries`).
- Using Suspense queries serially instead of `useSuspenseQueries`.
- Mutating cached objects directly.
- Duplicating `QueryClient` instances per component.

---

## References

- https://tanstack.com/query/latest
