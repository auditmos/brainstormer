---
id: rerenders/inline-object-prop
category: rerenders
detect: regex
source: https://www.react.doctor/
---

# Inline object literal as a prop

Every render builds a fresh `{}` object for any prop whose value is written
as an inline object literal in JSX. React compares props by reference, so
the child sees a new prop every render — even when the *contents* are
identical to the previous render. Any `React.memo` boundary, `useMemo` that
depends on the prop, or `useEffect` that lists the prop in its dependency
array is broken silently: the memoization yields nothing, the effect fires
on every render, and the render cascade widens with the component tree.

The fix has two shapes. If the object is logically stable, hoist it to
module scope or stabilize it with `useMemo`. If the object content actually
changes per render, the inline literal is correct — but then no `memo`
boundary downstream is going to help, and the component shape should be
revisited (lift state, pass primitives instead of an object, etc.).

## Detection

Syntactic. Match a JSX attribute whose value is a `{{`-opened object
literal (or a spread of an inline object) on the same line. The double
brace is the syntactic tell — `prop={{...}}` in JSX is always an inline
object expression. Apply the regex line-by-line against every scanned
`*.tsx` / `*.jsx` file; each match is one Finding anchored at the match
line.

Primary regex (ERE):

```
[A-Za-z_][A-Za-z0-9_-]*=\{\{[^}]
```

Plain English: an attribute identifier, an `=`, an opening `{`, then a
second `{` (object literal), then at least one character that is not a
closing brace. The trailing class rules out the empty `{{}}` edge case
(harmless — represents the empty-object literal but commonly used as a
typed placeholder; surface separately if desired).

Secondary regex (spread of an inline object — much rarer):

```
\{\.\.\.\{[^}]
```

Trigger conditions to flag:

- Any line matching either regex above.
- Common offender pattern: `style={{ ... }}` — flag unless the
  containing element clearly does not memoize anything downstream
  (the scanner cannot prove this; surface the finding and let the
  human decide severity).

False-positive exemptions:

- Components whose only consumer is the root `App` / `Layout` and that
  never memoize. The finding is real but the cost is zero — surface as
  Optimization severity rather than suppress.
- Top-of-file `const STYLE = { ... }` patterns where the literal is
  hoisted out of JSX are not flagged because the regex anchors on
  `<attr>={{` shape inside JSX, not on bare `{ ... }` object
  declarations.

## Bad

```tsx
function ProductRow({ product, onSelect }: { product: Product; onSelect: (id: string) => void }) {
  // New { padding, border } every render → MemoizedDetails always re-renders.
  return (
    <MemoizedDetails
      product={product}
      style={{ padding: 8, border: '1px solid #ddd' }}
      onSelect={onSelect}
    />
  );
}
```

`MemoizedDetails` is wrapped in `React.memo`, yet it re-renders on every
parent render because the inline `style` object is reference-fresh each
time. The memo boundary buys nothing.

## Good

```tsx
const ROW_STYLE = { padding: 8, border: '1px solid #ddd' };

function ProductRow({ product, onSelect }: { product: Product; onSelect: (id: string) => void }) {
  return (
    <MemoizedDetails
      product={product}
      style={ROW_STYLE}
      onSelect={onSelect}
    />
  );
}
```

If the style depends on render-scoped values, stabilize with `useMemo`:

```tsx
const style = useMemo(
  () => ({ padding: 8, border: highlighted ? '2px solid blue' : '1px solid #ddd' }),
  [highlighted],
);
```

## Severity guidance

- **Optimization** (default) — extra renders, no user-visible bug. The
  warning still has value because the inline literal silently breaks any
  downstream `memo` boundary the human might add later.
- **Friction** — when the receiving child is already wrapped in
  `React.memo` or runs an effect listing the prop in its dependency array.
  The intent of the memo boundary is being defeated by the parent.
- **Blocker** — when the prop is consumed inside a render hot path
  (`src/auth/`, `src/payment/`, `src/router/`, `*Provider.tsx`,
  `*Layout.tsx`, `App.tsx`, `_app.tsx`, `route.tsx`) and the unnecessary
  re-renders cascade across the subtree. Profile evidence is not required
  to upgrade — the hot-path heuristic is sufficient by policy.

## Citation

react-doctor — [www.react.doctor](https://www.react.doctor/) canonical
catalog of React render anti-patterns, maintained by Million as
[millionco/react-doctor](https://github.com/millionco/react-doctor). The
inline-object-prop rule is one of react-doctor's foundational lint targets;
the canonical implementation lives in the linked GitHub repository.
