# Plan: <Feature Name>

> Source PRD: <brief identifier or link>

## Architectural decisions

Durable decisions that apply across all phases:

- **Architecture style**: ...
- **Data model**: ...
- **Key entities**: ...
- **Integrations**: ...
- (add/remove sections as appropriate)

---

## Phase 1: <Title>

**User stories**: <list from PRD>

### What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

### Assumptions carried in

What this phase relies on from earlier phases (or from the wider environment) and will NOT rebuild. Examples:
- "Auth from Phase 0 works; no changes to login flow."
- "PostgreSQL is reachable at $DATABASE_URL; no infra setup in this phase."

### Out of scope for this phase

What is intentionally deferred. Protects against scope creep during `/tdd` or implementation. Examples:
- "No admin UI — admins use psql directly until Phase 4."
- "No email notifications — in-app only."

### Acceptance criteria

Each AC must be verifiable as (a) automated test, (b) observable artifact, or (c) runnable command. Annotate with the verification mechanism in square brackets.

- [ ] Criterion 1 — [test: `tests/phase1/test_x.py::test_happy_path`]
- [ ] Criterion 2 — [observable: `audit_log` row appears within 5s of action]
- [ ] Criterion 3 — [command: `make smoke-phase1` exits 0]

---

## Phase 2: <Title>

**User stories**: <list from PRD>

### What to build

...

### Assumptions carried in

- ...

### Out of scope for this phase

- ...

### Acceptance criteria

- [ ] ... — [verification: ...]

<!-- Repeat for each phase -->
