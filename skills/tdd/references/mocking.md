# Mocking Patterns

## Dependency Injection

Accept dependencies as parameters instead of importing directly:

```ts
// Hard to test — hidden dependency
export async function getUser(id: string) {
  const res = await fetch(`/api/users/${id}`);
  return res.json();
}

// Easy to test — injectable boundary
export async function getUser(id: string, fetcher = fetch) {
  const res = await fetcher(`/api/users/${id}`);
  return res.json();
}
```

## SDK-style Wrappers

Wrap external services in thin SDK classes. Mock the SDK, not raw HTTP:

```ts
// Good — mock the wrapper
class GitHubClient {
  async getRepo(owner: string, repo: string) { ... }
}

// Bad — mock the global
vi.stubGlobal("fetch", vi.fn(...))
```

## Good: Mock External API

```ts
test("fetches user from API", async () => {
  const mockFetch = vi.fn().mockResolvedValue({
    ok: true,
    json: () => Promise.resolve({ id: "1", name: "Alice" }),
  });

  const user = await getUser("1", mockFetch);
  expect(user).toEqual({ id: "1", name: "Alice" });
});
```

## Bad: Mock Internal Module

```ts
// DON'T — mocking your own utility couples the test to internal structure
vi.mock("./utils", () => ({
  formatName: vi.fn((name) => name.toUpperCase()),
}));
```

## Bad: Testing Private Methods

```ts
// Bad — reaching into internals
import { _normalizeEmail } from "./users";
test("normalizes email", () => {
  expect(_normalizeEmail("User@Example.COM")).toBe("user@example.com");
});

// Good — test through the public interface
import { createUser } from "./users";
test("normalizes email on creation", () => {
  const user = createUser({ email: "User@Example.COM", name: "Test" });
  expect(user.email).toBe("user@example.com");
});
```

## Decision Guide

| Situation | Action |
|-----------|--------|
| External API call | Mock it (inject or wrap in SDK) |
| Database query | Mock or use test DB |
| `Date.now`, `Math.random` | Mock it |
| Your own utility function | **Don't mock** — call the real thing |
| Internal collaborator module | **Don't mock** — test at a higher level |
| Private/unexported function | **Don't test directly** — test through public API |
