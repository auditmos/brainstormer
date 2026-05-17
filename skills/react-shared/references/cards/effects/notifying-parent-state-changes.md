---
id: effects/notifying-parent-state-changes
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#notifying-parent-components-about-state-changes
---

# Notifying parent components from `useEffect`

A component that owns a piece of state and pipes every change to a parent
via `useEffect(() => onChange(value), [value])` causes a render cascade:
the child renders with the new state, commits, runs the effect, calls
`onChange`, the parent re-renders, the child re-renders. The user
experiences two commits where one should have happened.

Worse, the timing is wrong. The parent learns about the change *after* the
child has already committed it to the DOM. If the parent rejects or
transforms the new value, the UI flashes the old-then-rejected sequence.

Two cleaner shapes exist. If the parent should *control* the state (it
already owns the canonical value), lift the state up — the child becomes
controlled and the effect disappears. If the child genuinely owns the
state, call `onChange` from the same event handler that calls the setter —
both updates happen in one render pass.

## Detection

The pattern is semantic but has a tight signature: an effect whose body
calls a function that came in via props (typically `onChange`,
`onSelect`, `onToggle`, `onCommit`, `onUpdate`), whose dependency array
contains the component's own state.

Trigger conditions to flag:

- The effect body calls a prop callback (an identifier matched by the
  component's destructured props or `props.X` accessor) named like
  `on*`/`set*`/a callback.
- The effect's dependency array contains state declared by `useState`
  *in this same component*.
- An event handler in the same component sets that state with a setter
  call — i.e., the change always originates from a known handler.
- The component is not synchronizing with an external store (no
  subscription, no event listener, no DOM ref read).

## Bad

```tsx
function Toggle({ onChange }: { onChange: (on: boolean) => void }) {
  const [isOn, setIsOn] = useState(false);

  useEffect(() => {
    onChange(isOn);
  }, [isOn, onChange]);

  function handleClick() {
    setIsOn((v) => !v);
  }

  return <button onClick={handleClick}>{isOn ? 'On' : 'Off'}</button>;
}
```

Click → child renders with `isOn=true` → commits → effect fires → parent
re-renders → child re-renders. Two commits per click. The first commit
already painted the "On" state before the parent had a chance to validate
or reject it.

## Good

```tsx
function Toggle({ onChange }: { onChange: (on: boolean) => void }) {
  const [isOn, setIsOn] = useState(false);

  function handleClick() {
    const next = !isOn;
    setIsOn(next);
    onChange(next);
  }

  return <button onClick={handleClick}>{isOn ? 'On' : 'Off'}</button>;
}
```

Or, if the parent should control the value, drop the local state entirely:

```tsx
function Toggle({ isOn, onChange }: { isOn: boolean; onChange: (on: boolean) => void }) {
  return <button onClick={() => onChange(!isOn)}>{isOn ? 'On' : 'Off'}</button>;
}
```

## Severity guidance

- **Friction** (default) — extra commit per change, no visible bug on
  ordinary inputs.
- **Blocker** — when the parent transforms or rejects the value (e.g.,
  validation, clamping, debouncing), the UI flashes the unvalidated state
  before the parent overrides it. Any controlled form, payment input,
  auth toggle, or critical path is a Blocker by default.

## Citation

react.dev — [You Might Not Need an Effect — Notifying parent components about state changes](https://react.dev/learn/you-might-not-need-an-effect#notifying-parent-components-about-state-changes).
