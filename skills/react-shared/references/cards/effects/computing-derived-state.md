---
id: effects/computing-derived-state
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#updating-state-based-on-props-or-state
---

# Computing derived state in `useEffect`

Storing data in state and then keeping it in sync with props or other state via
`useEffect` is unnecessary indirection. The derived value is recomputed during
render anyway — pushing it through state forces an extra render, makes the
component harder to reason about, and risks the synced value falling out of
date when the effect's dependency list is wrong.

If a value can be calculated from existing props or state, calculate it during
render. Reach for `useMemo` only when the calculation is measurably expensive
on the render path.

## Detection

The pattern is semantic, not syntactic — `useEffect` calling a setter whose
new value is computed from variables already available in the render scope.
A regex catches the obvious cases but misses the long tail. Use `llm-judge`
to evaluate each `useEffect` body and decide whether the setter argument is
derivable from props or other state without the effect.

Trigger conditions to flag:

- The effect's body is dominated by a single `setX(...)` call.
- The argument to the setter is a pure expression over the effect's
  dependency array.
- The effect has no cleanup function and no asynchronous work.

## Bad

```tsx
function Form() {
  const [firstName, setFirstName] = useState('Taylor');
  const [lastName, setLastName] = useState('Swift');
  const [fullName, setFullName] = useState('');

  useEffect(() => {
    setFullName(firstName + ' ' + lastName);
  }, [firstName, lastName]);

  return <p>{fullName}</p>;
}
```

`fullName` is fully derivable from `firstName` and `lastName`. The effect
adds an extra render every time either input changes and offers nothing the
expression `firstName + ' ' + lastName` does not give for free.

## Good

```tsx
function Form() {
  const [firstName, setFirstName] = useState('Taylor');
  const [lastName, setLastName] = useState('Swift');
  const fullName = firstName + ' ' + lastName;

  return <p>{fullName}</p>;
}
```

For an expensive derivation, wrap in `useMemo`:

```tsx
const fullName = useMemo(
  () => firstName + ' ' + lastName,
  [firstName, lastName],
);
```

## Severity guidance

- **Friction** (default) — extra render, no user-visible bug.
- **Blocker** — when the derived state diverges (stale dependency array, or
  the setter is conditional and a code path forgets to call it), the UI
  shows incorrect data. Upgrade severity for any occurrence in a render
  hot path or a critical surface (auth, payment, navigation).

## Citation

react.dev — [You Might Not Need an Effect — Updating state based on props or state](https://react.dev/learn/you-might-not-need-an-effect#updating-state-based-on-props-or-state).
