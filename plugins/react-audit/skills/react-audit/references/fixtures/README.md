# `/react-audit` — Phase 1 fixtures

Two minimal fixtures used to verify the tracer-bullet end-to-end path.
Both expose the same `UserCard` component shape; the divergence is whether
`fullName` is derived through `useEffect` (the seeded anti-pattern) or
computed during render (the clean baseline).

## Layout

- `seeded/UserCard.tsx` — exactly one occurrence of
  `effects/computing-derived-state`. Anchor line: the `useEffect` invocation.
- `clean/UserCard.tsx` — same component, no `useEffect`, derived during
  render. Zero anti-patterns.

## Manual verification procedure

`/react-audit` cannot run inside this brainstormer planning workspace —
running it would file real GitHub issues against `auditmos/brainstormer`.
The verification therefore walks the four-module path by hand and records
the evidence in `verification-log.md`.

For each fixture, perform:

1. **Rule Card Library** — read
   `skills/react-shared/references/cards/effects/computing-derived-state.md`.
   Confirm frontmatter (id, category, detect, source) and capture the body.
2. **Code Scanner** — apply the card's "Detection" trigger conditions
   line-by-line to the fixture file. Record every match as a `Finding`
   `(rule_id, file, line, severity, snippet, context)`. The card's `detect`
   is `llm-judge`, so the agent runs the check itself.
3. **Issue Manager** — for each Finding, render the issue body
   (full card content + `## Occurrence` block) and the exact
   `gh issue create` command that would file it. Do **not** invoke `gh` —
   record the command verbatim.

## Expected outcomes (frozen for AC verification)

- `seeded/UserCard.tsx` → exactly **one** Finding at line 13 (the
  `useEffect` block deriving `fullName`). One `gh issue create` invocation
  with label `react-audit:effects/computing-derived-state`.
- `clean/UserCard.tsx` → **zero** Findings. No `gh issue create`
  invocation. Skill exits with `0 findings`.

These are the AC #4, #5, #6 behavioral checkpoints. `verification-log.md`
records the actual run against these expectations.

## When the verification must be re-run

Re-execute the procedure whenever any of the following change:

- The card body for `effects/computing-derived-state`
- The fixture content
- The Code Scanner contract in `SKILL.md`
- The Issue Manager body-rendering rules in `SKILL.md`
