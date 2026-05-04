# Code Status Tags

Every code block in the handoff doc carries exactly one status tag. Rejection reasons are mandatory on `[SUPERSEDED]` and `[REJECTED]` — without them the next model re-suggests the same wrong thing.

## The four tags

| Tag | Meaning | Reason required? |
|-----|---------|------------------|
| `[FINAL]` | The version that was accepted and is currently in use | No |
| `[SUPERSEDED]` | An earlier version that was replaced | **Yes — `Replaced because:`** |
| `[REJECTED]` | A version that was tried and explicitly thrown out | **Yes — `Rejected because:`** |
| `[DRAFT]` | Proposed in chat but never finalized | No |

## Truncation prohibition

**Never abbreviate or truncate `[FINAL]` code blocks.** Emit the full file contents verbatim.

Forbidden inside `[FINAL]` and `[SUPERSEDED]` blocks:

- `[... rest of file ...]`
- `[... see repo for full content ...]`
- `[... truncated for brevity ...]`
- Ellipsis comments standing in for omitted code

The receiving model has zero filesystem access to your environment. A pointer to a path it cannot reach is useless. If a file is 800 lines, output 800 lines. The same rule applies to `[SUPERSEDED]` blocks: the *whole reason* for including a superseded version is so the next model can see exactly what was changed and why — abbreviating defeats the purpose.

## Concept-level rejections

The only blocks that may be abbreviated are `[REJECTED]` ones where the rejection happened at the concept level and no actual code was ever written. In that case write `(no code; behavioral choice)` and explain in prose:

```
### [REJECTED] Use Redis for session state
**Rejected because:** Hosting plan caps add-ons at $0/mo and the team prefers
Postgres for everything. (no code; behavioral choice)
```

## Block format

Every code block must include the file path it belongs to (or `no file -- one-off snippet`) and the language tag.

```
### [FINAL] src/lib/auth.ts
```ts
{full file contents, verbatim}
```

### [SUPERSEDED] src/lib/auth.ts
**Replaced because:** Original used `jsonwebtoken`, we moved to `jose` for edge runtime support.
```ts
{full prior file contents, verbatim}
```

### [REJECTED] src/lib/auth-passport.ts
**Rejected because:** Passport pulled in 14 transitive deps for a feature we did not need.
```ts
{contents that were tried}
```

### [DRAFT] proposed but not finalized — auth helper signature
```ts
{snippet}
```
```
