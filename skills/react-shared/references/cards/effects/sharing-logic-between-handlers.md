---
id: effects/sharing-logic-between-handlers
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#sharing-logic-between-event-handlers
---

# Sharing logic between event handlers via `useEffect`

Two handlers — say `handleBuy` and `handleCheckout` — both need to fire
the same downstream side effect, like showing a "Added to cart!"
notification. The instinct to deduplicate pulls the shared logic into a
`useEffect` that watches the state both handlers write to. The effect
fires whenever that state changes, and the notification appears from a
single place. Tidy on paper.

The bug is that the effect now fires for *any* reason that state changes
— not just the user clicking buy or checkout. A reload that hydrates the
cart from local storage flashes the notification. A server-driven update
of `cart` (push notification, websocket, optimistic update rollback)
fires it. The user sees "Added to cart!" without having done anything.

The right deduplication is a plain function called by both handlers.
Effects run because *the component rendered*; handlers run because *the
user did something*. The shared logic in question is the latter, so it
belongs in a handler-shaped helper.

## Detection

The pattern is semantic: an effect whose body fires a user-visible side
effect (toast / notification / analytics event / dialog open) and whose
dependency array contains state that is written by ≥2 event handlers in
the same component.

Trigger conditions to flag:

- The effect's body calls a user-facing side effect: `showNotification`,
  `toast.success`, `dialog.open`, `analytics.track(...)`, or any
  function that surfaces something to the user.
- The dependency array contains state.
- ≥2 event handlers in the same component set that state.
- The same state can also change for non-user reasons (hydration, server
  push, parent prop change, optimistic update).

Pure analytics pings tied to *page view* (component mount) are not the
pattern — those are legitimate mount effects.

## Bad

```tsx
function ProductPage({ product }: { product: Product }) {
  const [cart, setCart] = useState<Cart>(emptyCart);

  useEffect(() => {
    if (cart.justAddedId === product.id) {
      showNotification(`Added ${product.name} to cart!`);
    }
  }, [cart, product]);

  function handleBuy() {
    setCart(addToCart(cart, product));
  }

  function handleCheckout() {
    setCart(addToCart(cart, product));
    navigate('/checkout');
  }

  return (
    <>
      <button onClick={handleBuy}>Buy</button>
      <button onClick={handleCheckout}>Checkout</button>
    </>
  );
}
```

If `cart` hydrates from local storage on mount with `justAddedId`
already set, the notification flashes for no user action. If the server
pushes an optimistic-rollback update that re-asserts the `justAddedId`,
the notification flashes a second time.

## Good

```tsx
function ProductPage({ product }: { product: Product }) {
  const [cart, setCart] = useState<Cart>(emptyCart);

  function buyProduct() {
    setCart(addToCart(cart, product));
    showNotification(`Added ${product.name} to cart!`);
  }

  function handleBuy() {
    buyProduct();
  }

  function handleCheckout() {
    buyProduct();
    navigate('/checkout');
  }

  return (
    <>
      <button onClick={handleBuy}>Buy</button>
      <button onClick={handleCheckout}>Checkout</button>
    </>
  );
}
```

The notification fires only when the user *acts*. Hydration, server
pushes, and optimistic rollbacks change `cart` without triggering the
toast.

## Severity guidance

- **Friction** (default) — unexpected notifications on hydration, no
  data corruption.
- **Blocker** — when the user-facing side effect has a real-world cost
  (analytics event that affects billing or funnel reporting; transaction
  confirmation that triggers downstream automation; emails or push
  notifications sent to other parties), the spurious fire is a Blocker.

## Citation

react.dev — [You Might Not Need an Effect — Sharing logic between event handlers](https://react.dev/learn/you-might-not-need-an-effect#sharing-logic-between-event-handlers).
