---
id: effects/sending-post-request
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#sending-a-post-request
---

# Sending a POST request from `useEffect`

Two POSTs are not the same. Sending an analytics ping after a page mounts
is a side effect of the component appearing on screen — that belongs in an
effect. Sending the user's form submission is a side effect of them
clicking submit — that belongs in the event handler.

The buggy version is the second case smuggled into an effect: code reads
some "submitted" or "isDirty" flag, the component renders, the effect runs
and POSTs the data. The chain works, but it couples the request to render
rather than to the user's intent. The handler is the place where you know
*who* triggered the request and *what* should happen on success — the
effect knows neither.

## Detection

The pattern is semantic: an effect whose body issues a write-style network
call (`POST`, `PUT`, `DELETE`, `axios.post`, an action with a mutation
client) and whose dependency array gates the call on a piece of state that
exists only because an event handler set it (e.g. `submitted`,
`isDirty`, `pendingPayment`).

Trigger conditions to flag:

- The effect body invokes a network primitive with a non-GET method (or a
  mutation client method).
- The dependency array contains a flag-like state (`submitted`,
  `isSaving`, `pending*`, `dirty*`, etc.).
- The same flag is the target of a setter call elsewhere in an event
  handler (`onSubmit`, `onClick`, `onChange`).
- The call has no rate-limit, retry, or de-duplication wrapper that would
  justify the indirection.

The mount-only analytics ping case (`POST /telemetry/page-view` on first
render, no event coupling) is *not* the pattern and must not flag.

## Bad

```tsx
function Form() {
  const [first, setFirst] = useState('');
  const [last, setLast] = useState('');
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    if (submitted) {
      fetch('/api/register', {
        method: 'POST',
        body: JSON.stringify({ first, last }),
      });
    }
  }, [submitted]);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitted(true);
  }

  return <form onSubmit={handleSubmit}>{/* ... */}</form>;
}
```

`submitted` exists only to talk to the effect. Two state writes per click,
no place to attach success/error UI, and the request fires again if React
ever re-runs the effect (e.g. Strict Mode mount→unmount→mount).

## Good

```tsx
function Form() {
  const [first, setFirst] = useState('');
  const [last, setLast] = useState('');

  useEffect(() => {
    // Analytics ping on mount — legitimate effect.
    post('/analytics/form-viewed', { name: 'register' });
  }, []);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    post('/api/register', { first, last });
  }

  return <form onSubmit={handleSubmit}>{/* ... */}</form>;
}
```

The mount ping stays in an effect (driven by the component appearing). The
submit POST moves to the handler (driven by the user's intent). The
`submitted` flag disappears entirely.

## Severity guidance

- **Friction** (default) — duplicated state, awkward success-handling,
  but the request usually still completes.
- **Blocker** — when the effect can fire twice (Strict Mode, dependency
  array changes after submit), the POST may double-charge / double-create
  / double-send. Any payment, registration, or mutation surface is a
  Blocker by default; assume idempotency is not guaranteed.

## Citation

react.dev — [You Might Not Need an Effect — Sending a POST request](https://react.dev/learn/you-might-not-need-an-effect#sending-a-post-request).
