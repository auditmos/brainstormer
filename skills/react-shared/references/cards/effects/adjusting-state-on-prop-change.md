---
id: effects/adjusting-state-on-prop-change
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#adjusting-some-state-when-a-prop-changes
---

# Adjusting one piece of state when a prop changes from `useEffect`

Sometimes only part of the state is invalidated by a prop change. The
component owns a `selection` that should clear whenever the `items` list
changes; or a `step` index that should reset when a `wizardId` changes;
or a derived `filter` whose value depends on a `dataset` prop. The naive
shape is a `useEffect` that watches the prop and calls one setter to
adjust the state in question.

That works, but it commits the *old* state once and the *adjusted* state
in the next frame. For a single piece of state, the cleaner pattern is
to keep the previous value of the prop alongside the state and adjust
*during render* when they disagree. React explicitly supports calling a
setter during render in this exact case; it short-circuits the current
render before the children see the stale value.

For many cases, the right fix is even simpler: store the *id* of the
selection rather than the selection itself, then look up the current
selection during render. The state then survives prop changes naturally
when the id is still valid and vanishes when it is not — no effect
involved.

## Detection

The pattern is semantic: an effect whose dependency array contains a
single prop and whose body is a single setter call adjusting a
prop-related slice of state.

Trigger conditions to flag:

- The effect's dependency array contains exactly one prop (or list/scalar
  derived from props).
- The effect's body is a single `setX(...)` call.
- `X` is a piece of state local to this component that depends
  conceptually on the watched prop (a filter, a selected id, a tab, a
  step index).
- The setter argument is a constant, an initial value, or a small
  expression — not a transform of other state.

Multi-setter resets belong to `effects/resetting-all-state-on-prop-change`.
Single derivable scalars belong to `effects/computing-derived-state`.
This card covers the in-between: one piece of state that *can* be carried
across prop changes when it still makes sense, but sometimes needs an
adjustment.

## Bad

```tsx
function List({ items }: { items: Item[] }) {
  const [isReverse, setIsReverse] = useState(false);
  const [selection, setSelection] = useState<Item | null>(null);

  useEffect(() => {
    setSelection(null);
  }, [items]);

  // ...
}
```

The list renders once with the stale selection (an item no longer in
`items`), and a second time with `selection = null`. Brief flash of a
ghost selection.

## Good

Adjust during render with a previous-prop comparison:

```tsx
function List({ items }: { items: Item[] }) {
  const [isReverse, setIsReverse] = useState(false);
  const [selection, setSelection] = useState<Item | null>(null);

  const [prevItems, setPrevItems] = useState(items);
  if (items !== prevItems) {
    setPrevItems(items);
    setSelection(null);
  }

  // ...
}
```

Even better, store the *id* rather than the item and derive:

```tsx
function List({ items }: { items: Item[] }) {
  const [isReverse, setIsReverse] = useState(false);
  const [selectionId, setSelectionId] = useState<string | null>(null);
  const selection = items.find((i) => i.id === selectionId) ?? null;
  // ...
}
```

`selection` becomes `null` automatically when the previously selected
id is no longer in `items`. No effect, no extra render, no flash.

## Severity guidance

- **Friction** (default) — one extra render, brief stale frame.
- **Blocker** — when the stale frame is visible to the user in a
  high-stakes context (a payment summary showing a previous user's saved
  card; a wizard step rendering with the wrong step data; a list flashing
  a selection that no longer exists in a security-sensitive context),
  promote to Blocker.

## Citation

react.dev — [You Might Not Need an Effect — Adjusting some state when a prop changes](https://react.dev/learn/you-might-not-need-an-effect#adjusting-some-state-when-a-prop-changes).
