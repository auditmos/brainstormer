---
id: rerenders/context-too-broad
category: rerenders
detect: llm-judge
source: https://www.react.doctor/
---

# Context provider value bundled too broadly

A single React Context Provider whose value bundles unrelated pieces of
state forces every consumer to re-render whenever any one of those pieces
changes. The most extreme version — an `AppContext` carrying user, theme,
feature flags, current route, and toasts — re-renders every consumer on
every change to any of those values, even consumers that only read one
field.

React Context uses `Object.is` reference equality on the provider value
to decide whether to notify consumers. There is no "subscribe to a slice"
API on raw Context: any change to the value object notifies *every*
`useContext` consumer in the subtree. Selectors built on top of Context
(via a wrapper hook) do not help — they only mask the work, the
re-renders still fire.

Two clean shapes. First: split the Provider by concern — separate
`UserContext`, `ThemeContext`, `FeatureFlagsContext`, etc. — so changes
isolate to consumers that actually need them. Second: for cases where
the values are genuinely co-evolving, switch to an external store
(Zustand, Jotai, Redux, `useSyncExternalStore`) that does support
selector-based subscriptions — Context is the wrong primitive.

## Detection

Semantic. The pattern is structural, not syntactic — a Provider whose
`value` is an object literal aggregating multiple unrelated state slices.
Trigger on a `Context.Provider` whose `value=` expression is an object
literal or `useMemo` over an object literal that contains *three or more*
distinct identifier sources (different `useState`s, different reducers,
different external subscriptions).

LLM-judge is required because deciding whether two state slices are
"unrelated" requires reading the consumer usage — auth + permissions in
one Context can be intentional, auth + toasts is almost always wrong.
The judge looks at:

1. The Provider's `value=` shape (count of independent state sources).
2. A sample of `useContext` consumers — do most of them destructure only
   one field?
3. Whether the change frequencies of the bundled slices differ by orders
   of magnitude (a toast that fires every 5s next to a user object that
   changes once per session).

When two or three of those hold, flag the finding. Cite the consumer
sample lines in the issue body alongside the Provider site.

False-positive exemptions:

- A Provider whose value is two tightly-coupled slices that always change
  together (current user + permission set derived from user). The bundle
  is intentional — surface at Optimization, not Friction.
- An external store wrapper that uses Context only to inject the *store
  instance* (a stable reference). The consumers subscribe via
  `useSyncExternalStore` and never read the Context value directly.

## Bad

```tsx
type AppValue = {
  user: User | null;
  theme: 'light' | 'dark';
  flags: Record<string, boolean>;
  toast: ToastState;
};

const AppContext = createContext<AppValue | null>(null);

function AppProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
  const [flags, setFlags] = useState<Record<string, boolean>>({});
  const [toast, setToast] = useState<ToastState>({ visible: false });

  // Every toast (5s lifetime) re-renders every consumer of AppContext —
  // including the user avatar, the theme switcher, every flag-gated
  // component, and every other tab in the app.
  return (
    <AppContext.Provider value={{ user, theme, flags, toast }}>
      {children}
    </AppContext.Provider>
  );
}
```

A toast firing forces the entire tree to re-render. The theme switcher
re-renders because the user typed `:tada:` in a chat. None of these
re-renders produce changed output.

## Good

```tsx
const UserContext = createContext<User | null>(null);
const ThemeContext = createContext<'light' | 'dark'>('light');
const FlagsContext = createContext<Record<string, boolean>>({});
const ToastContext = createContext<ToastState>({ visible: false });

function AppProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
  const [flags, setFlags] = useState<Record<string, boolean>>({});
  const [toast, setToast] = useState<ToastState>({ visible: false });

  return (
    <UserContext.Provider value={user}>
      <ThemeContext.Provider value={theme}>
        <FlagsContext.Provider value={flags}>
          <ToastContext.Provider value={toast}>
            {children}
          </ToastContext.Provider>
        </FlagsContext.Provider>
      </ThemeContext.Provider>
    </UserContext.Provider>
  );
}
```

Or, for genuinely co-evolving state with selector-based subscriptions,
reach for an external store:

```tsx
import { create } from 'zustand';
import { useShallow } from 'zustand/react/shallow';

const useAppStore = create<AppValue>(() => ({
  user: null,
  theme: 'light',
  flags: {},
  toast: { visible: false },
}));

function UserAvatar() {
  const user = useAppStore((s) => s.user);
  // Re-renders only when `user` changes.
}
```

## Severity guidance

- **Friction** (default) — extra renders, no user-visible bug. The
  default is one step higher than the other rerender cards because the
  blast radius of a broad Context is the entire subtree, not a single
  child.
- **Blocker** — when the Provider sits at the application root
  (`App.tsx`, `_app.tsx`, `RootProvider.tsx`, the topmost layout in
  Next/Remix/TanStack Router) and the bundle includes at least one
  high-frequency-changing slice (toasts, timers, mouse position,
  in-flight network state). The cascade is system-wide.

## Citation

react-doctor — [www.react.doctor](https://www.react.doctor/) catalog,
canonical implementation in [millionco/react-doctor](https://github.com/millionco/react-doctor).
The rule sits at the boundary between "rerender hygiene" and "state
architecture" — when a `/react-audit` run surfaces this finding it
usually points at a refactor, not a one-line fix, which is why the card
spells out the two clean shapes explicitly.
