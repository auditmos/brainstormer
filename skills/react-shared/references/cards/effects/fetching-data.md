---
id: effects/fetching-data
category: effects
detect: llm-judge
source: https://react.dev/learn/you-might-not-need-an-effect#fetching-data
---

# Fetching data inside `useEffect`

Spawning a `fetch` (or any data-loader) directly inside `useEffect` is the
default reflex but rarely the right move. The naive shape — `useEffect(() =>
{ fetch(url).then(setData) }, [url])` — has three structural problems: it
runs only after paint (extra round-trip before the user sees anything), it
has no built-in deduplication or cache, and it ships with a classic race
condition where a slow earlier response overwrites a fast later one when the
dependency changes.

Prefer a data-fetching primitive that owns the cache and lifecycle:
TanStack Query, RTK Query, SWR, a framework loader (TanStack Router /
Next.js / Remix), or — for one-off cases — an `useEffect` with an `ignore`
flag or `AbortController` and an extracted custom hook.

## Detection

The pattern is semantic: an effect whose body fires a network call (any of
`fetch`, `axios`, custom client) and pipes the result back into component
state via a setter. The judge must inspect the effect body, identify the
network call, and confirm that the response is consumed via local state
without a race-condition guard and without delegation to a data primitive.

Trigger conditions to flag:

- The effect body invokes a network primitive (`fetch`, `axios.get`,
  `apiClient.foo()`).
- The result is written to component state via `setX(...)` on success.
- No `ignore` flag, `AbortController`, or cancellation cleanup is present.
- The surrounding file does not also use `useQuery`, `useSWR`, a loader
  hook, or framework data primitives.

Do not flag examples that already use a data primitive elsewhere and merely
call `fetch` for a side effect (analytics, logging) — those are covered by
`effects/sending-post-request`.

## Bad

```tsx
function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    fetch(`/api/users/${userId}`)
      .then((res) => res.json())
      .then((data) => setUser(data));
  }, [userId]);

  if (!user) return <Spinner />;
  return <ProfileCard user={user} />;
}
```

A slow response for `userId=1` can land after a fast response for
`userId=2`, leaving stale data in the UI. No cache, no retry, no
deduplication — every mount and every `userId` change re-fetches from
scratch.

## Good

```tsx
function UserProfile({ userId }: { userId: string }) {
  const { data: user } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetch(`/api/users/${userId}`).then((r) => r.json()),
  });

  if (!user) return <Spinner />;
  return <ProfileCard user={user} />;
}
```

Or, if a data primitive is genuinely unavailable, guard the race manually
and extract to a hook:

```tsx
function useUser(userId: string) {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => {
    let ignore = false;
    fetch(`/api/users/${userId}`)
      .then((r) => r.json())
      .then((data) => { if (!ignore) setUser(data); });
    return () => { ignore = true; };
  }, [userId]);
  return user;
}
```

## Severity guidance

- **Friction** (default) — wasted round-trips and missing cache, no
  visible bug on a single-shot render.
- **Blocker** — race-condition exposure on any prop-driven dependency
  array, or any occurrence in a render hot path (auth, payment,
  navigation). Stale-overwrite bugs surface as "I clicked B, why am I
  seeing A's data?" — promote to Blocker on first detection.

## Citation

react.dev — [You Might Not Need an Effect — Fetching data](https://react.dev/learn/you-might-not-need-an-effect#fetching-data).
