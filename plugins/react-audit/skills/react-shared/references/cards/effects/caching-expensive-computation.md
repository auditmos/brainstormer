---
id: effects/caching-expensive-computation
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#caching-expensive-calculations
---

# Caching expensive computation through `useEffect` + `useState`

The intent here is reasonable — "this calculation is too expensive to run
every render, so let me cache it." The execution misreaches for `useState`
and a synchronizing `useEffect`. The component renders once with the stale
or empty cached value, the effect fires, the setter triggers a second
render with the fresh result. The "cache" actively makes the first render
slower than no cache at all and forces an extra commit on every
dependency change.

`useMemo` is the cache. It runs during render, before the component
returns, and skips recomputation when its dependencies are referentially
equal. No extra render, no stale frame, no risk that the cache and the
inputs drift out of sync because of a wrong dependency array on the
effect.

Use `useMemo` only after profiling confirms the computation is expensive
enough to matter. For trivial transforms, the right answer is just to
compute inline — that case is covered by
`effects/transforming-data-for-render`.

## Detection

The pattern is semantic and pairs closely with
`transforming-data-for-render`. The distinguishing feature is intent —
the comment, function name, or shape of the operation signals that the
author is caching, not just transforming. Common tells: the helper is
named `compute*`, `calculate*`, `derive*`, `aggregate*`, a comment
mentions "memo", "cache", or "expensive", or the operation contains
nested loops / heavy regex / large sort.

Trigger conditions to flag:

- The effect's body is dominated by a single `setX(...)` call.
- The argument is the result of a function call that signals expense
  (heavy helper, nested map/reduce, large `.sort`).
- The same data could be returned from a `useMemo(() => ..., deps)`
  with the same dependency array.
- The author's intent is caching (helper name, comment, or operation
  shape) — not merely transforming for render.

If the operation is cheap and the intent is "the list rendered should
reflect props," prefer `effects/transforming-data-for-render`.

## Bad

```tsx
function TodoList({ todos, filter }: { todos: Todo[]; filter: string }) {
  const [visibleTodos, setVisibleTodos] = useState<Todo[]>([]);

  useEffect(() => {
    // expensive: sorts then filters then groups
    setVisibleTodos(buildVisibleTodos(todos, filter));
  }, [todos, filter]);

  return <TodoTable rows={visibleTodos} />;
}
```

The first render paints with `visibleTodos = []`. The effect fires, the
"cache" populates, a second render paints with the real data. Worst of
both worlds — an extra commit *and* a stale first frame.

## Good

```tsx
function TodoList({ todos, filter }: { todos: Todo[]; filter: string }) {
  const visibleTodos = useMemo(
    () => buildVisibleTodos(todos, filter),
    [todos, filter],
  );

  return <TodoTable rows={visibleTodos} />;
}
```

`useMemo` recomputes only when `todos` or `filter` changes by reference,
and the value is available on the first render — no stale frame, no
extra commit.

## Severity guidance

- **Friction** (default) — extra render, possibly a stale frame; no
  logical bug.
- **Blocker** — when the effect's dependency array drifts from the
  function's inputs, the cached value lags behind its inputs and the UI
  shows incorrect data. Promote to Blocker in any list view that drives
  identity, payment, or auth decisions; the stale-cache failure mode is
  far more dangerous when the cached data is consulted by handlers, not
  just rendered.

## Citation

react.dev — [You Might Not Need an Effect — Caching expensive calculations](https://react.dev/learn/you-might-not-need-an-effect#caching-expensive-calculations).
