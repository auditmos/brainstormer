---
id: effects/transforming-data-for-render
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#transforming-data-for-rendering
---

# Transforming data for render inside `useEffect`

A component holds a list (`todos`, `users`, `events`) and a transform of
that list (`visibleTodos`, `sortedUsers`, `upcoming`). The transform is
kept in `useState`, and an effect re-derives it whenever the source list
or filter changes. The list-and-its-derivative shape forces an extra
render every time the source changes — the component renders once with
stale `visibleTodos`, the effect runs, the setter triggers a second
render with the fresh value.

If the transform can be computed from the source, compute it during
render. If profiling shows the transform is genuinely expensive on the
render path, wrap it in `useMemo`. Storing the transform in `useState`
should be reserved for cases where the derived value cannot be recomputed
(e.g., a server-generated id that must persist).

## Detection

The pattern is semantic: an effect that takes one or more pieces of state
or props, applies a pure transform (filter / map / sort / group / count /
sum), and writes the result into another piece of state via its setter.

Trigger conditions to flag:

- The effect's body is dominated by a single `setX(...)` call.
- The argument is a transform expression (`.filter()`, `.map()`,
  `.sort()`, `.reduce()`, an inline list comprehension, or a pure helper
  call) over variables that exist in the render scope.
- The source and the target both live in the same component as `useState`
  pairs.
- The effect has no cleanup, no asynchronous work, and no external
  subscription.

This rule sits next to `effects/computing-derived-state`. That rule
covers single scalars (`fullName`, `total`); this rule covers collection
transforms where re-deriving each render is the cheap default and storing
is the expensive workaround.

## Bad

```tsx
function TodoList({ todos, filter }: { todos: Todo[]; filter: string }) {
  const [newTodo, setNewTodo] = useState('');
  const [visibleTodos, setVisibleTodos] = useState<Todo[]>([]);

  useEffect(() => {
    setVisibleTodos(getFilteredTodos(todos, filter));
  }, [todos, filter]);

  return (
    <>
      <NewTodo value={newTodo} onChange={setNewTodo} />
      <ul>
        {visibleTodos.map((t) => <li key={t.id}>{t.text}</li>)}
      </ul>
    </>
  );
}
```

Every `todos` or `filter` change renders the component with the old list,
then renders again with the new list. The user sees stale data for one
frame on every keystroke.

## Good

```tsx
function TodoList({ todos, filter }: { todos: Todo[]; filter: string }) {
  const [newTodo, setNewTodo] = useState('');
  const visibleTodos = getFilteredTodos(todos, filter);

  return (
    <>
      <NewTodo value={newTodo} onChange={setNewTodo} />
      <ul>
        {visibleTodos.map((t) => <li key={t.id}>{t.text}</li>)}
      </ul>
    </>
  );
}
```

For a genuinely expensive transform (verified by profiling):

```tsx
const visibleTodos = useMemo(
  () => getFilteredTodos(todos, filter),
  [todos, filter],
);
```

## Severity guidance

- **Friction** (default) — extra render, stale frame, no logical bug.
- **Blocker** — when the dependency array drifts from the inputs of the
  transform (a common refactor hazard), the stored value diverges from
  what the inputs imply and the UI shows incorrect data until the next
  render that touches the missing dependency. Promote to Blocker in any
  filter/sort surface that drives critical UX (payment summary, auth
  scope listing, search-result ranking).

## Citation

react.dev — [You Might Not Need an Effect — Transforming data for rendering](https://react.dev/learn/you-might-not-need-an-effect#transforming-data-for-rendering).
