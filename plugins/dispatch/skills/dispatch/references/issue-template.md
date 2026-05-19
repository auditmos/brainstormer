# Issue Template

## Parent PRD

#<prd-issue-number>

## Type

HITL or AFK. AFK = an agent can implement, verify, and merge without human input. HITL = explicit human checkpoint required (and which checkpoint).

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation. Reference specific sections of the parent PRD rather than duplicating content.

## Assumptions

What already exists in the repo and is NOT scope of this issue. Lets the implementing agent know what to trust without verifying. Examples:
- "User auth is implemented and tested (issue #12)."
- "Database schema for `users` table exists; do not alter it."

## Out of scope for this issue

Explicit "do NOT touch X, Y, Z" list. Protects the implementing agent from drifting into adjacent improvements. Examples:
- "Do NOT refactor the existing email-sending code in `mailer/`."
- "Do NOT add a UI; this issue is API-only."

## Acceptance criteria

Each AC must be agent-verifiable. Annotate with the verification mechanism.

- [ ] Criterion 1 — [test: `tests/test_x.py::test_happy_path`]
- [ ] Criterion 2 — [observable: row appears in `audit_log` within 5s]
- [ ] Criterion 3 — [command: `make smoke` exits 0]

If this is HITL, mark the subjective gate explicitly, e.g. `[HITL: design review by @owner before merge]`.

## How to verify

End-to-end verification recipe — the exact steps an agent (or reviewer) follows to confirm every AC above. Should be runnable top-to-bottom.

Example:
1. `make setup && make migrate`
2. `pytest tests/test_x.py`
3. Trigger the flow via `curl -X POST localhost:8080/foo` and check response is `{"ok": true}`
4. `psql -c "select count(*) from audit_log where event = 'foo';"` returns ≥ 1

## Blocked by

- Blocked by #<issue-number> (if any)

Or "None - can start immediately" if no blockers.

## User stories addressed

Reference by number from the parent PRD:

- User story 3
- User story 7
