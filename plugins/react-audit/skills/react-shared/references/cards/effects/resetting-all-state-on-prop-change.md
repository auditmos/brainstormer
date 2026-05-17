---
id: effects/resetting-all-state-on-prop-change
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#resetting-all-state-when-a-prop-changes
---

# Resetting all state when a prop changes from `useEffect`

A component holds several pieces of state that belong to a specific
"thing" — `userId`, `pageId`, `conversationId`. When the thing changes,
all of that state is logically invalid. The naive fix is a single
`useEffect` watching the id, whose body fires every setter in the
component: `setComment('')`, `setDraft('')`, `setIsExpanded(false)`,
`setIsPublished(false)`, and so on.

Two problems. First, every setter call enqueues a render between the prop
change and the steady state — the user sees the old user's comment in
the input box, then it clears in the next frame. Second, the reset list
goes stale. Add a new piece of state next year, forget to add it to the
reset effect, and that field now leaks across user switches.

The idiomatic fix is to tell React that the component is conceptually a
*new instance* when the id changes: pass the id as a `key`. React
unmounts the old instance and mounts a fresh one with default state.
Every piece of state — present and future — resets automatically.

## Detection

The pattern is semantic: an effect that depends on an id-like prop
(`userId`, `id`, `*Id`, `slug`) and whose body is a sequence of two or
more setter calls that assign initial values.

Trigger conditions to flag:

- The effect's dependency array contains a single id-like prop.
- The effect's body contains ≥2 setter calls in sequence.
- The values passed to those setters are static literals (`''`, `false`,
  `null`, `0`, `[]`) or simple default expressions — i.e. they re-set
  the state to its initial value.
- The component is being mounted under a parent that already knows the
  id (suggested by destructuring the id from props).

A single reset (`setOne('')` in an effect when prop changes) is a weaker
signal and tends to belong to `effects/adjusting-state-on-prop-change`.
The trigger here is the *collective* reset.

## Bad

```tsx
function ProfilePage({ userId }: { userId: string }) {
  const [comment, setComment] = useState('');
  const [isPublished, setIsPublished] = useState(false);
  const [isExpanded, setIsExpanded] = useState(false);

  useEffect(() => {
    setComment('');
    setIsPublished(false);
    setIsExpanded(false);
  }, [userId]);

  // ...
}
```

Every `userId` change paints the *previous* user's state, then enqueues
three setters, then re-renders with the cleared state. Add a fourth piece
of state next month and forget the reset line and that field leaks
across users.

## Good

```tsx
// Parent
<ProfilePage key={userId} userId={userId} />

// Child
function ProfilePage({ userId }: { userId: string }) {
  const [comment, setComment] = useState('');
  const [isPublished, setIsPublished] = useState(false);
  const [isExpanded, setIsExpanded] = useState(false);

  // No reset effect — `key` forces a fresh instance per userId.
}
```

The `key` prop tells React that the component identity is tied to the
id. The old instance unmounts, a new one mounts, all state defaults
naturally. No extra render, no reset list to maintain.

## Severity guidance

- **Friction** (default) — extra render, the previous user's state may
  flash briefly.
- **Blocker** — if any of the leaked state is sensitive (a draft comment
  authored as user A appearing in user B's editor), promote to Blocker.
  Privacy leaks across users are not a "missed `useMemo`" — they are a
  bug that ships to production.

## Citation

react.dev — [You Might Not Need an Effect — Resetting all state when a prop changes](https://react.dev/learn/you-might-not-need-an-effect#resetting-all-state-when-a-prop-changes).
