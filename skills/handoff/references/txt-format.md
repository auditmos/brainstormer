# TXT Format — Substitution Rules

The `.txt` variant carries the same content as the `.md` but uses ASCII chrome that survives plaintext clients (terminal pastes, ticket systems, email).

## Substitutions

| Markdown | Plaintext |
|----------|-----------|
| `# Heading` | `=== HEADING ===` (uppercase, padded with `=`) |
| `## Subheading` | `--- Subheading ---` (mixed case, padded with `-`) |
| `### Sub-subheading` | `Sub-subheading:` (no padding, trailing colon) |
| `> blockquote` | indented 2 spaces, no `>` prefix |
| Markdown table | aligned plaintext table with `|` separators and `-` divider rows |
| Code fence ` ```lang ` ... ` ``` ` | 4-space indent block; header `--- CODE: {path} [{status}] ---`; footer `--- END ---` |
| Bullets `- item` | `* item` |
| Numbered list `1. item` | `1. item` (unchanged) |
| `**bold**` | strip — emit plain text |
| `_italic_` | strip — emit plain text |
| Inline `` `code` `` | strip backticks — emit plain text |

## Code-block example

`.md`:

```ts
const auth = jwt.sign(payload, secret);
```

`.txt`:

```
--- CODE: src/lib/auth.ts [FINAL] ---
    const auth = jwt.sign(payload, secret);
--- END ---
```

## Table example

`.md`:

```
| Decision | Rationale |
|----------|-----------|
| Use jose | Edge runtime support |
```

`.txt`:

```
| Decision | Rationale            |
|----------|----------------------|
| Use jose | Edge runtime support |
```

(Pad columns to the widest cell so the dividers align.)

## Hard rules — `.txt`

- Same content as the `.md`, just different chrome. Never drop information during conversion.
- Same em-dash prohibition: use `--` or commas.
- Empty sections still rendered as `_(none recorded in this session)_` (the underscores are fine in plaintext, they signal "intentionally empty").
