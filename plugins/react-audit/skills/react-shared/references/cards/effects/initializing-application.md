---
id: effects/initializing-application
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#initializing-the-application
---

# Initializing the application from inside `useEffect`

A `useEffect(() => initApp(), [])` block at the top of `App.tsx` looks like
"run once on app start," but it has two problems. Strict Mode mounts every
component twice in development to surface destruction-and-recreation bugs,
so the effect runs twice; idempotency must be guaranteed at the call site.
And React makes no promise that `App` is mounted only once over the
process lifetime — a future shell or test harness may unmount and remount
it. App-wide setup that should literally run *once* belongs in module
scope, not in a component effect.

If the work needs the browser (`window`, `document`, `localStorage`), gate
it with `typeof window !== 'undefined'` or a top-level `if (!didInit)`
guard, then perform the work at module load.

## Detection

The pattern is semantic but has a tight syntactic signature: a
`useEffect(() => {...}, [])` block (empty dependency array) inside a
top-level component (`App.tsx`, `_app.tsx`, `main.tsx`, `root.tsx`, or
similar) whose body performs setup that has no logical relationship to
the component's lifecycle — analytics SDK init, theme load, feature flag
hydration, service worker registration, polyfill install.

Trigger conditions to flag:

- The file is a top-level entry component (filename matches one of:
  `App.tsx`, `_app.tsx`, `main.tsx`, `root.tsx`, `index.tsx` directly
  under `src/` or app root).
- The component contains a `useEffect(..., [])` with empty deps.
- The body calls a one-shot initialization API (analytics SDK,
  feature-flag client, service worker, theme loader, polyfill, etc.).
- The body is not synchronizing with the component's own render output.

Do not flag `useEffect(..., [])` that subscribes to a window event or
synchronizes against an external store *and* registers a cleanup — that
is a legitimate effect.

## Bad

```tsx
// App.tsx
export function App() {
  useEffect(() => {
    loadDataFromLocalStorage();
    initAnalytics();
  }, []);

  return <Routes />;
}
```

In Strict Mode this initializes twice in development; double-init can
register the analytics page-view twice, double-fire localStorage migrations,
or corrupt feature-flag state. Even outside Strict Mode, the work runs
every time `App` mounts — which is "once per app start" only by convention.

## Good

```tsx
// main.tsx — runs at module load, exactly once.
if (typeof window !== 'undefined') {
  loadDataFromLocalStorage();
  initAnalytics();
}

export function App() {
  return <Routes />;
}
```

Or, if the work must wait for first paint, guard it explicitly:

```tsx
let didInit = false;

export function App() {
  useEffect(() => {
    if (!didInit) {
      didInit = true;
      loadDataFromLocalStorage();
      initAnalytics();
    }
  }, []);
  return <Routes />;
}
```

## Severity guidance

- **Friction** (default) — silent double-init in development; production
  usually only runs once.
- **Blocker** — when the initializer touches money, identity, or any
  non-idempotent backend (analytics with billing implications, telemetry
  with quota, a one-shot migration that overwrites local data). Always
  promote in `App.tsx`/`_app.tsx`/`main.tsx` if a payment or auth client
  is initialized inside the effect.

## Citation

react.dev — [You Might Not Need an Effect — Initializing the application](https://react.dev/learn/you-might-not-need-an-effect#initializing-the-application).
