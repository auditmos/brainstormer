---
name: tdd
version: 1.1.0
description: Test-Driven Development workflow using vertical slices. Use when implementing features with TDD, writing tests before code, or doing red-green-refactor cycles.
---

# Test-Driven Development

## Usage

```
/tdd              — start TDD from scratch (manual planning)
/tdd #123         — start TDD from GitHub issue #123 (pulls scope + acceptance criteria)
/tdd #123 #124    — batch related issues into one TDD session
```

## Philosophy

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists.

## Workflow

### 1. Plan

Before writing any code:

- If a GitHub issue was provided, fetch it with `gh issue view <number>` (with comments); its acceptance criteria become the initial behavior list
- If a plan file exists in `./plans/` (created by `/carve`), review its durable decisions and phase boundaries
- Confirm what interface changes are needed
- Confirm which behaviors to test (prioritize — you can't test everything)
- Identify opportunities for deep modules (small interface, deep implementation)
- Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors are most important to test?"

**State assumptions before RED.** Before writing the first failing test, write down — in a comment in the test file, in the session notes, or in the PR description — the assumptions the test will encode:

- Input shape (types, ranges, required/optional fields)
- Output shape (types, error modes, side effects)
- Boundary conditions (empty input, max input, null/undefined, concurrent calls)
- What is intentionally NOT tested in this iteration

Silent assumptions become test design choices that are expensive to reverse later.

**Stop and ask if an AC is ambiguous.** If an acceptance criterion in the issue or plan admits more than one reasonable interpretation, do NOT pick silently. Pause, surface the options, and ask. The entire test suite hangs off your interpretation — a wrong guess at this stage cascades through every RED→GREEN cycle that follows.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test fails
GREEN: Write minimal code to pass → test passes
```

This proves the path works end-to-end.

### 3. Incremental Loop

Repeat the same RED→GREEN cycle for each remaining behavior. One test at a time; only enough code to pass the current test; don't anticipate future tests.

### 4. Refactor

After all tests pass:

- Extract duplication
- Deepen modules (move complexity behind simple interfaces)
- Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.

## Surgical Scope

Even while GREEN, keep changes surgical:

- **Every changed line must trace to the current test.** If a line wasn't required to make the test pass (or to pass an earlier test), it doesn't belong in this change.
- **Don't "improve" adjacent code.** If you spot dead code, an unrelated bug, or a style issue near the code you're editing, mention it in the PR description — don't fix it in this commit.
- **Don't remove pre-existing dead code unless asked.** Only remove orphans your own changes created (unused imports, variables, helpers that nothing references after your edit).
- **Match existing style** even if you'd write it differently. Stylistic refactors belong in their own PR.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.**

Tests written in bulk test _imagined_ behavior, not _actual_ behavior. You end up testing the shape of things rather than user-facing behavior. Tests become insensitive to real changes.

## Conventions

- Co-locate tests: `foo.test.ts` next to `foo.ts` (not a parallel `__tests__/` tree)
- Wrap in `describe` named after the unit under test
- Test names describe behavior: "calculates total for multiple items", not "test calculateTotal"

## Mocking Rules

Mock **only** at system boundaries: external APIs, databases, time (`Date.now`), randomness (`Math.random`), file system. **Never** mock things you control — your own modules, internal collaborators, utilities, data transformations. If you feel the need to mock an internal module, the code is doing too much or you're testing at the wrong level. For patterns (dependency injection, SDK wrappers, good vs bad mocks), see [mocking.md](./references/mocking.md).

## Acceptance Checklist

```
[ ] Test describes behavior, not implementation
[ ] Test uses the public interface
[ ] Test would survive an internal refactor
[ ] Mocks only at system boundaries
[ ] Co-located next to source file
[ ] Every changed line traces to the current test (no adjacent improvements)
```
