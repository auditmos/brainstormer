---
name: tdd
description: Test-Driven Development workflow using vertical slices. Use when implementing features with TDD, writing tests before code, or doing red-green-refactor cycles.
---

# Test-Driven Development

## Usage

```
/tdd              — start TDD from scratch (manual planning)
/tdd #123         — start TDD from GitHub issue #123 (pulls scope + acceptance criteria)
/tdd #123 #124    — batch related issues into one TDD session
```

When invoked with a GitHub issue, fetch the issue body with `gh issue view <number>` and use it as the scope for the planning step. The issue's acceptance criteria become the initial behavior list.

If a plan exists in `./plans/` for the feature being implemented, read it for architectural decisions and phase context. Plans are created by `/carve` and contain vertical slices, durable decisions, and dependency ordering that should inform your test strategy.

## Philosophy

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists.

## Workflow

### 1. Plan

Before writing any code:

- If a GitHub issue was provided, review its scope and acceptance criteria
- If a plan file exists in `./plans/`, review architectural decisions and phase boundaries
- Confirm what interface changes are needed
- Confirm which behaviors to test (prioritize — you can't test everything)
- Identify opportunities for deep modules (small interface, deep implementation)
- Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors are most important to test?"

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test fails
GREEN: Write minimal code to pass → test passes
```

This proves the path works end-to-end.

### 3. Incremental Loop

For each remaining behavior:

```
RED:   Write next test → fails
GREEN: Minimal code to pass → passes
```

One test at a time. Only enough code to pass the current test. Don't anticipate future tests.

### 4. Refactor

After all tests pass:

- Extract duplication
- Deepen modules (move complexity behind simple interfaces)
- Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.**

Tests written in bulk test _imagined_ behavior, not _actual_ behavior. You end up testing the shape of things rather than user-facing behavior. Tests become insensitive to real changes.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
```

## Conventions

- Co-locate tests: `foo.test.ts` next to `foo.ts` (not a parallel `__tests__/` tree)
- Wrap in `describe` named after the unit under test
- Test names describe behavior: "calculates total for multiple items", not "test calculateTotal"
- Coverage thresholds apply per file — simplify unreachable code rather than lowering thresholds

## Mocking Rules

Mock **only** at system boundaries:

- External APIs, databases, time (`Date.now`), randomness (`Math.random`), file system

**Never** mock things you control:

- Your own modules, internal collaborators, utility functions, data transformations

If you feel the need to mock an internal module, the code is doing too much or you're testing at the wrong level.

For patterns (dependency injection, SDK wrappers, examples of good vs bad mocks), see [mocking.md](./references/mocking.md).

## Acceptance Checklist

```
[ ] Test describes behavior, not implementation
[ ] Test uses the public interface
[ ] Test would survive an internal refactor
[ ] Mocks only at system boundaries
[ ] Co-located next to source file
[ ] Code is minimal for this test
[ ] No speculative features added
[ ] Coverage thresholds pass for the file under test
```
