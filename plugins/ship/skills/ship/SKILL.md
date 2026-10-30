---
name: ship
version: 1.1.0
description: "Lint, type-check, commit, and push in one flow. Use when user says /ship or asks to commit+push."
---

# /ship — Lint, Commit & Push

Run all steps in order without pausing for confirmation. Invoking /ship is the approval to commit and push.

When an error blocks shipping (lint, types, a failing pre-commit hook, a rebase conflict), do not ask whether to fix it. Say in one line what failed, fix it, re-run the check, and continue. Stop only on the conditions listed under Rules.

## Step 1 — Pre-flight checks (conditional, parallel)

Before running checks, detect what tooling is available:

1. Check if `package.json` exists in the repo root.
2. If it does, look for the `lint:ci` and `types` scripts inside it.
3. Run **only** the scripts that exist — in parallel:
   - `pnpm lint:ci` (if script `lint:ci` is defined)
   - `pnpm types` (if script `types` is defined)
4. If `package.json` does not exist or neither script is defined, **skip this step entirely** and proceed to Step 2.

If a check fails:

1. Report it in one line, e.g. `pnpm types: 3 errors in src/api.ts — fixing`.
2. Fix the root cause. Never silence an error instead of fixing it: no `@ts-ignore` / `@ts-expect-error`, no `eslint-disable` / `biome-ignore`, no widening to `any`, no deleting or skipping tests, no loosening the lint or tsconfig.
3. Re-run every check that ran, not only the one that failed, since a fix can break another check.
4. Repeat until all checks pass. The fixed files ship in the same commit as the rest of the changes.

## Step 2 — Gather git context (parallel)

Run all three **in parallel**:

```
git status
git diff --staged && git diff
git log --oneline -5
```

If there are no changes to commit, inform the user and **stop**.

## Step 3 — Stage & Commit

- Stage only the relevant changed files by name — never `git add -A` or `git add .`
- Do NOT stage files that likely contain secrets (.env, credentials, etc.)
- Analyze the diff and recent log to draft a commit message matching the repo's style (conventional commits, concise)
- Commit right away. Do not show the message for approval first
- Use HEREDOC format for the commit message with Co-Authored-By trailer

If a pre-commit hook fails, the commit did not happen. Report the hook's error in one line, fix the cause, re-stage, and create the commit again. It is a new commit: no `--amend`, no `--no-verify`.

## Step 4 — Pull & Push

Always pull before push to avoid rejection:

```
git pull --rebase && git push
```

If the rebase stops on conflicts:

1. List the conflicting files in one line.
2. Resolve each conflict so both sides' changes survive.
3. Re-run the Step 1 checks and fix any failure as in Step 1.
4. `git add` the resolved files, `git rebase --continue`, then push.

If a conflict cannot be resolved without guessing which side's behavior is wanted, run `git rebase --abort` (the local commit stays intact) and stop with a report.

## Step 5 — Report

After the push, report in a few lines:

- the commit hash and message, and the files it contains
- every fix made along the way: what failed and what changed
- the branch and remote that were pushed

## Rules

- Never `git push --force`
- Never skip hooks (`--no-verify`)
- Never amend existing commits unless user explicitly asks
- Never silence a check to make it pass (see Step 1)
- Stop and report, without committing or pushing anything further, only when:
  - the same check still fails after 3 fix attempts. Report what was tried and leave the working tree as it is
  - a rebase conflict needs a judgment call (see Step 4)
  - the push fails for a reason code cannot fix (auth, network, protected branch)
