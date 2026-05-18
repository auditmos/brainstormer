---
id: rerenders/missing-memo-on-list-row
category: rerenders
detect: ast
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

Structural. Look for:

1. A JSX subtree that maps an array (`items.map(item => <Row .../>)`).
2. The `Row` component is a function component declared in the same file
   or imported from a sibling module.
3. The `Row` component is *not* wrapped in `React.memo` (no `memo(...)`
   call on the declaration or on the default export).

AST is required: regex against `.map(...)` alone produces too many false
positives (list-of-primitives renders, `Fragment`-wrapped maps, etc.).
The walker checks the JSX call target against the file's declarations and
flags only when the rendered component is itself a function component
that the parent could memoize.

Trigger conditions to flag:

- A `CallExpression` on an array (e.g. `items.map(...)`) appearing inside
  a `JSXExpressionContainer`.
- The map callback returns a JSX element whose tag identifier resolves to
  a function-component declaration the auditor controls.
- That declaration is not wrapped in `React.memo` and not exported via
  `export default memo(Row)`.

False-positive exemptions:

- Rows that render only primitives (`<li>{name}</li>`) and have no
  internal state, hooks, or further descendants. The render cost is
  rounding-error.
- Lists with fewer than ~10 items at all times (small lookup menus,
  fixed-arity tab strips). Surface at Optimization severity.

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
