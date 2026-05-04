# Output Template — `.md` Format

Use this exact section order. Omit a section only if it would be empty — and prefer marking empty sections `_(none recorded in this session)_` so the receiving model knows nothing was missed.

```
# Session Handoff: {Project Name}

> Generated {ISO timestamp} for handoff to Codex / Cursor.
> Source: chat session with Claude.

## TL;DR

{3-5 bullets. What was being built, where we landed, what is next.}

## Project Context

- **Name:** ...
- **Repo:** ...
- **Local path:** ...
- **Stack:** ...
- **Deployment:** ...
- **Key deps:** ...
- **Branch / working state:** ...

## Session Goal

{One paragraph. What the user came in wanting to accomplish.}

## Timeline

{Chronological, tight. Each item: what happened, why, outcome. One or two lines each. The narrative spine.}

1. ...
2. ...

## Decisions

| Decision | Rationale | Alternatives Rejected |
|---|---|---|
| ... | ... | ... |

## Constraints, Gotchas, and Hard Rules

{Non-obvious stuff. Environment quirks, library version pins, "do not do X" rules from the user, platform-specific behavior. Each as a bullet.}

- ...

## Files Touched

| Path | Purpose | Status |
|---|---|---|
| ... | ... | created / modified / deleted |

## Code Artifacts

### [FINAL] {file path}
```{lang}
{code}
```

### [SUPERSEDED] {file path}
**Replaced because:** {reason}
```{lang}
{code}
```

### [REJECTED] {description}
**Rejected because:** {reason}
```{lang}
{code}
```

{... repeat for every code block in the chat — see code-status-tags.md ...}

## Errors and Fixes

| Error | Root Cause | Fix |
|---|---|---|
| ... | ... | ... |

## Commands

{Shell commands, git operations, deploy steps. Verbatim. Group by purpose.}

```bash
# Local dev
...

# Deploy
...
```

## User Preferences and Style Rules

{Anything the user expressed about how they want code, naming, tone, formatting.}

- ...

## Open Threads

{Unresolved questions, known bugs, deferred work.}

- ...

## Next Steps

{Ordered, imperative. The next model should be able to start executing from item 1.}

1. ...
2. ...

## Raw Notes

{Anything that did not fit cleanly above but might matter. Dump zone. Do not omit detail to keep this section short.}
```

## Section rules

- **Order is fixed.** TL;DR first, Raw Notes last.
- **Empty sections** prefer `_(none recorded in this session)_` over outright omission, so the receiving model knows nothing was lost.
- **No em-dashes** anywhere in the output. Use `--` or commas.
- **Tables** must use the markdown pipe format (the `.txt` renderer converts these to aligned plaintext).
- **Code Artifacts** is the heart of the document. Every code block in the chat appears here with a status tag — see [code-status-tags.md](./code-status-tags.md).
