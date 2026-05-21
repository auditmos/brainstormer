---
id: rerenders/missing-memo-on-list-row
category: rerenders
detect: llm-judge
source: https://www.react.doctor/
---

# Missing `React.memo` on list row component

A list parent renders an array of rows. When any state in the parent
changes — selection, filter, hover — React re-renders every row in the
list, even rows whose props are identical to the previous render. For a
list of 200 items where the user clicks a single row, React re-renders
all 200 rows: 199 of them produce identical output.

Wrapping the row component in `React.memo` short-circuits the renders for
rows whose props haven't changed. The interactive row pays its own
re-render; the other 199 skip work entirely.

`memo` only helps if the row's props are *referentially stable*. A `memo`
boundary fed by inline object/array literals (see `rerenders/inline-object-prop`
and `rerenders/inline-array-prop`) is a no-op — the parent rebuilds the
props every render and `memo` reports them as changed. Audit these
together: a missing `memo` on a list row is almost always paired with at
least one unstable prop further up the tree.

## Detection

Semantic. A regex against `.map(...)` alone produces too many false
positives (list-of-primitives renders, `Fragment`-wrapped maps,
maps that don't return JSX, etc.), so this card uses `llm-judge`:
the agent reads the full file and applies the three-step rule below
itself, returning each occurrence as `{ line, snippet, context }`.

Three-step rule the judge must apply for every scanned file:

1. **Identify candidate maps.** Find every JSX subtree of the shape
   `<arrayExpr>.map(<cb>)` where the callback returns JSX. Ignore
   maps whose callback returns a primitive (`items.map(s => s)`) or
   a bare DOM element with no child component (`items.map(name =>
   <li>{name}</li>`).
2. **Resolve the rendered component.** The map callback returns a JSX
   element whose tag identifier must resolve to a function-component
   declaration the auditor controls (declared in the same file, or
   imported from a sibling project module). Ignore third-party
   components — the auditor cannot rewrap them.
3. **Check for `React.memo` wrapping.** Flag the occurrence if and
   only if the resolved component declaration is *not* wrapped in
   `memo(...)` and not exported via `export default memo(Component)`.

For each flagged occurrence, report:

- `line` — the line carrying the `.map(` call.
- `snippet` — the offending line, trimmed.
- `context` — two lines before, the offending line, two lines after.

False-positive exemptions the judge applies before reporting:

- Rows that render only primitives (`<li>{name}</li>`) and have no
  internal state, hooks, or further descendants. The render cost is
  rounding-error.
- Lists with fewer than ~10 items at all times (small lookup menus,
  fixed-arity tab strips). Still report but mark severity as
  Optimization rather than Friction.

Cache: per the Code Scanner contract, llm-judge calls are cached per
`(file_hash, rule_id)` within a single scan run; the judge is invoked
at most once per file for this rule even if the file is re-considered
during dependency analysis.

## Bad

```tsx
function ProductRow({ product, onSelect }: { product: Product; onSelect: (id: string) => void }) {
  return (
    <li onClick={() => onSelect(product.id)}>
      <span>{product.name}</span>
      <span>${product.price}</span>
    </li>
  );
}

function ProductList({ products, onSelect }: { products: Product[]; onSelect: (id: string) => void }) {
  const [filter, setFilter] = useState('');
  // Every keystroke in the filter input re-renders all N ProductRow components.
  return (
    <>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ul>
        {products.filter((p) => p.name.includes(filter)).map((product) => (
          <ProductRow key={product.id} product={product} onSelect={onSelect} />
        ))}
      </ul>
    </>
  );
}
```

The filter input is the only state that changes. The list still
re-renders the entire row population on every keystroke.

## Good

```tsx
const ProductRow = memo(function ProductRow(
  { product, onSelect }: { product: Product; onSelect: (id: string) => void },
) {
  return (
    <li onClick={() => onSelect(product.id)}>
      <span>{product.name}</span>
      <span>${product.price}</span>
    </li>
  );
});

function ProductList({ products, onSelect }: { products: Product[]; onSelect: (id: string) => void }) {
  const [filter, setFilter] = useState('');
  const stableOnSelect = useCallback(onSelect, [onSelect]);
  const filtered = useMemo(
    () => products.filter((p) => p.name.includes(filter)),
    [products, filter],
  );
  return (
    <>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ul>
        {filtered.map((product) => (
          <ProductRow key={product.id} product={product} onSelect={stableOnSelect} />
        ))}
      </ul>
    </>
  );
}
```

Three things changed in concert: `memo(ProductRow)`, `useCallback` on the
handler so the prop reference is stable across filter changes, and
`useMemo` on the filtered list so the array reference is stable when the
filter doesn't change. Any one of them on its own is insufficient.

## Severity guidance

- **Optimization** (default) — for lists under ~50 items with cheap row
  internals.
- **Friction** — for lists of 50+ items, especially when the parent has
  high-frequency state churn (typing into an input, drag-tracking, etc.).
- **Blocker** — for virtualized lists (TanStack Table, react-virtual,
  AG Grid), tables on the critical path (admin panels, dashboards),
  or any list rendered inside a render hot path (`src/auth/`,
  `src/payment/`, `src/router/`, `*Provider.tsx`, `*Layout.tsx`,
  `App.tsx`, `_app.tsx`, `route.tsx`).

## Citation

react-doctor — [www.react.doctor](https://www.react.doctor/) catalog,
implementation in [millionco/react-doctor](https://github.com/millionco/react-doctor).
This card pairs with `rerenders/inline-object-prop` and
`rerenders/inline-array-prop` — a `memo`-wrapped row whose parent passes
inline literals receives no benefit. Audit and resolve them together.
