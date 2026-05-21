---
id: rerenders/inline-array-prop
category: rerenders
detect: regex
source: https://www.react.doctor/
---

# Inline array literal as a prop

Variant of inline-object-prop with the same mechanism: any `[ ... ]`
literal written directly in JSX produces a new array reference on every
render. Children compare props by reference, so the new array breaks
downstream memoization just like a fresh object would. The failure mode is
the same — `React.memo` reports the prop as changed, dependency arrays in
`useMemo`/`useEffect` fire on every render, and renders cascade through
the subtree.

Two clean shapes. If the array's contents are stable, hoist to module
scope or stabilize with `useMemo`. If the array is genuinely render-scoped
(filter result, computed slice, mapped data), the inline literal is
inherent — but downstream `memo` boundaries need either a deeper
dependency-aware comparison or a different decomposition (pass primitives,
pass the source data, let the child do its own derivation).

## Detection

Syntactic. Match a JSX attribute whose value is a `{[`-opened array
literal on the same line. The opening `{[` is the syntactic tell —
`prop={[...]}` in JSX is always an inline array expression. Apply the
regex line-by-line against every scanned `*.tsx` / `*.jsx` file; each
match is one Finding anchored at the match line.

Primary regex (ERE):

```
[A-Za-z_][A-Za-z0-9_-]*=\{\[
```

Plain English: an attribute identifier, an `=`, an opening `{`, then a
`[` opening an array literal. Empty-array literals (`prop={[]}`) match
naturally — and are the most common silent offender (default-prop typing
hack); a `const EMPTY: never[] = []` hoisted to module scope is the
canonical fix.

Secondary regex (spread of an inline array — rarer):

```
\{\.\.\.\{[^}]*\[
```

Trigger conditions to flag:

- Any line matching either regex above.

False-positive exemptions:

- Render-scoped derivations that *must* be inline because they depend on
  per-render values (`items.filter(x => x.id === selectedId)`) — the
  regex won't fire on these because the value is an identifier/call
  expression, not a `[` literal. If the developer writes
  `prop={items.filter(...)}`, no match. The regex only flags literal
  brackets.
- Calls into stable helpers (`prop={getEmptyItems()}`) are likewise
  identifier-shaped and do not match.

## Bad

```tsx
function Dashboard({ user }: { user: User }) {
  // New [] every render — MemoizedSidebar.items prop is always "fresh".
  return (
    <MemoizedSidebar
      user={user}
      items={[]}
      tabs={['overview', 'activity', 'settings']}
    />
  );
}
```

Both `items={[]}` and `tabs={[...]}` build a new array per render. Any
memoized child receiving either prop re-renders even when the parent has
no state change of its own.

## Good

```tsx
const EMPTY_ITEMS: never[] = [];
const SIDEBAR_TABS = ['overview', 'activity', 'settings'] as const;

function Dashboard({ user }: { user: User }) {
  return (
    <MemoizedSidebar
      user={user}
      items={EMPTY_ITEMS}
      tabs={SIDEBAR_TABS}
    />
  );
}
```

For render-scoped derivations, stabilize with `useMemo`:

```tsx
const activeItems = useMemo(
  () => items.filter((item) => item.status === 'active'),
  [items],
);
```

## Severity guidance

- **Optimization** (default) — same rationale as inline-object-prop:
  extra renders, no user-visible bug.
- **Friction** — when the receiving child is `React.memo`-wrapped or
  enumerates the array in a `useEffect` dependency list.
- **Blocker** — when the inline array feeds a virtualized list, an
  expensive `useEffect` (network call, DOM mutation), or any render hot
  path. The cascade can amplify the per-render cost by orders of
  magnitude on large datasets.

## Citation

react-doctor — [www.react.doctor](https://www.react.doctor/) catalog,
canonical implementation in [millionco/react-doctor](https://github.com/millionco/react-doctor).
The inline-array-prop rule is a direct sibling of inline-object-prop and
shares its detection AST and severity heuristics; the rules ship as
distinct cards so issue grouping by `(skill, rule_id)` separates the two
findings even when they co-occur in the same file.
