# Brainstormer — Planning Workspace

This is a **planning-only workspace**. There is no application source code here — only skills, plans, and deliverables for taking a client from rough idea to dev-ready output.

## Workflow

The recommended skill order (not enforced):

1. `/ask` — Discovery interview to pressure-test the idea
2. `/blueprint` — Formalize requirements into a PRD (GitHub issue)
3. `/carve` — Break the PRD into phased vertical slices (saved to `./plans/`)
4. `/dispatch` — Create dependency-ordered GitHub issues for dev handoff
5. `/tdd` — Implement issues using red-green-refactor with vertical slices (`/tdd #123`)

Additional skills:
- `/lean` — Standalone MVP advisor. Invoke anytime to check for over-engineering.
- `/brainstorm` — Orchestrated workflow that guides through all phases end-to-end.
- `/ship` — Lint, type-check, commit, and push in one flow.
- `/improve-claude-md` — Audit and improve CLAUDE.md files with conditional importance tags.
- `/llm-council` — Multi-perspective council for strategic decisions.
- `/agent-cli` — Design and audit CLIs intended for AI agents (seven principles + severity rubric).
- `/handoff` — Capture the current chat as a structured handoff doc (.md + .txt) for Codex, Cursor, or another IDE agent.
- `/orient` — Zoom out a layer of abstraction and get a map of relevant modules + callers in project vocabulary. Invoke when unfamiliar with an area of code.

## Session Rules

- Exhaust one topic fully before moving to the next. No compound questions.
- Restate decisions back to the client before finalizing.
- Technology choices appear in deliverables **only** when the client explicitly states them.
- GitHub is required — PRDs are submitted as issues, plans go to `./plans/`.

## Tone

Professional, direct, thorough. This is a consulting engagement — treat every session as billable time with a client.

## Plugin Structure

This repo is both a direct workspace and a distributable plugin. Skills live in `skills/` with mirrored copies in `plugins/` for marketplace distribution. See `llms.txt` for a machine-readable index of all skills and references.

## Commit validation

`skills/` must stay byte-synced with the `plugins/` mirror, `.claude-plugin/marketplace.json`, and `llms.txt`. Four validators (`scripts/validate-*.sh`) enforce this and run three ways:

- **Git-native (every clone — do this first):** run `git config core.hooksPath .githooks` once per clone. `.githooks/pre-commit` then runs all four validators and blocks the commit on failure. This is the source of truth and the only agent-independent layer.
- **Agent PreToolUse gate:** `.claude/settings.json` (Claude Code) and `.codex/hooks.json` (Codex) register `scripts/hook-precommit-sync.sh`, which runs the same validators before an agent's `git commit` and blocks it with exit code 2 on drift, so the agent sees the failure in-transcript. Codex additionally requires `[features].codex_hooks = true` in `~/.codex/config.toml` — a per-machine setting, not tracked in this repo.
- **CI:** the same checks run on every PR.

Override intentionally with `git commit --no-verify`.
