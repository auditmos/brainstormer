---
name: ship
description: "Lint, type-check, commit, and push in one flow. Use when user says /ship or asks to commit+push."
---

# /ship — Lint, Commit & Push

Run all steps in order. Stop immediately on any failure.

## Step 1 — Pre-flight checks (conditional, parallel)

Before running checks, detect what tooling is available:

1. Check if `package.json` exists in the repo root.
2. If it does, look for the `lint:ci` and `types` scripts inside it.
3. Run **only** the scripts that exist — in parallel:
   - `pnpm lint:ci` (if script `lint:ci` is defined)
   - `pnpm types` (if script `types` is defined)
4. If `package.json` does not exist or neither script is defined, **skip this step entirely** and proceed to Step 2.

If any executed check fails, show the errors and **stop**. Do not commit broken code.

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
- Show the user the proposed commit message and files to be staged
- Wait for user confirmation before committing
- Use HEREDOC format for the commit message with Co-Authored-By trailer

## Step 4 — Pull & Push

Always pull before push to avoid rejection:

```
git pull --rebase && git push
```

If rebase has conflicts, show them and **stop** — let the user decide.

## Rules

- Never `git push --force`
- Never skip hooks (`--no-verify`)
- Never amend existing commits unless user explicitly asks
- If any step fails, stop and report — don't retry automatically
