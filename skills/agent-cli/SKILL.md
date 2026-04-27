---
name: agent-cli
description: Design and audit CLIs that AI agents (Claude Code, Codex, automated pipelines) consume. Applies seven principles — non-interactive default, structured output, actionable errors, safe retries, progressive help, composable I/O, bounded responses — with a Blocker / Friction / Optimization severity rubric. Use when the user is building, reviewing, or specifying a command-line tool meant for agent invocation, mentions argparse, click, cobra, clap, commander, yargs, oclif, or thor, asks about agent-friendly CLI design, --json output, exit codes for agents, idempotent commands, or works in a repo containing cli.py, main.go, src/cli.rs, or bin/<tool>. Skip for general shell scripting unrelated to CLI tool design and for human-only interactive TUIs.
---

# Agent CLI — Design & Audit Skill

Audit an existing CLI (or design a new one from scratch) against seven principles for agent-friendly tool design, classifying every finding by severity so the user can prioritize fixes.

## Usage

```
/agent-cli                     -- ask which mode (audit existing or design new)
/agent-cli audit               -- review CLI source/spec in current repo
/agent-cli design <name>       -- guide design of a new CLI from zero
```

The skill also auto-loads when the conversation surfaces CLI design topics (frameworks, --json outputs, exit codes, idempotency, agent invocation patterns).

## Core Principle

Agents pay real costs for every prompt that hangs, every line of unstructured output, every vague error, and every retry that silently duplicates work. A CLI optimized for agents is also better for humans — but the reverse is not true. Design for the strict consumer first.

## The Seven Principles (summary)

| # | Principle | One-line test |
|---|-----------|---------------|
| 1 | Non-interactive by default | Run with `stdin=DEVNULL`; does it exit instead of hanging? |
| 2 | Structured, parseable output | Is `--json` available on every data-bearing command? |
| 3 | Fail fast with actionable errors | Does the error name the fix, not just the symptom? |
| 4 | Safe retries & explicit mutation boundaries | Does running the same mutating command twice corrupt state? |
| 5 | Progressive help discovery | Can an agent learn invocation shape in two `--help` calls? |
| 6 | Composable & predictable structure | Do flags and subcommands follow a consistent pattern? |
| 7 | Bounded, high-signal responses | Does a routine query teach the agent how to narrow further? |

Full explanation, rationale, and worked examples in [cli-principles.md](./references/cli-principles.md).

## Severity Rubric

Every finding maps to one of three levels. The level depends on what the command does — idempotency matters for mutating commands, irrelevant for streaming logs.

| Severity | Meaning | Example |
|----------|---------|---------|
| **Blocker** | Prevents reliable agent use | Command hangs awaiting input; no `--json` on data command; silent state corruption on retry |
| **Friction** | Works but wastes tokens / retries | Errors name the problem but not the fix; inconsistent `--json` coverage; ANSI codes in piped output |
| **Optimization** | Functional but improvable | Help lacks examples; `--limit` defaults too broad; framework-idiomatic patterns missing |

Per-principle severity mapping lives in [audit-checklist.md](./references/audit-checklist.md).

## Workflow — Audit Mode

### 1. Locate the CLI surface

Find the entry point and command tree. Common patterns: `cli.py` (argparse/click), `cmd/` (cobra), `src/main.rs` (clap), `bin/<tool>` (commander/yargs/oclif).

### 2. Classify commands

For each command, classify as **read** (query/list), **mutate** (create/update/delete/deploy), or **stream** (tail/follow). Severity weighting differs by class — apply the relevant rows from the audit checklist.

### 3. Run the checklist

Walk [audit-checklist.md](./references/audit-checklist.md) principle by principle. For each finding record: principle, command path, observed behavior, expected behavior, severity, suggested fix.

### 4. Output the report

Use the format in [Output Format](#output-format). Sort findings by severity (Blocker first), then by principle. Reference [framework-recipes.md](./references/framework-recipes.md) when the fix is framework-specific.

## Workflow — Design Mode

### 1. Establish constraints

Confirm: target framework, command scope (1 command vs. multi-resource tool), primary agent consumers (Claude Code subagents? CI pipeline? interactive humans too?). Constraint set drives recipe choices.

### 2. Sketch the surface

Draft the command tree, flag set, and output formats up front. For each command propose: invocation shape, `--json` schema, error catalog, dry-run behavior (mutating only), pagination defaults (read only).

### 3. Verify against the seven principles

Walk every principle with the proposed surface. A design-mode pass fails the same way as an audit — write findings as if reviewing a finished tool.

### 4. Output the design doc

Same format as audit, plus a "Surface Sketch" section showing the proposed command tree and flag set in code blocks.

## Output Format

```
# CLI Agent Readiness — <tool name> (<audit|design>)

## Summary
<1–3 sentence verdict — overall readiness, headline issues>

## Findings (sorted by severity)
### Blocker — <Principle #N>: <command path>
**Observed:** <what the CLI does today / what the design proposes>
**Expected:** <what an agent-friendly CLI would do>
**Fix:** <concrete change, framework-idiomatic if possible>

### Friction — <Principle #N>: <command path>
...

### Optimization — <Principle #N>: <command path>
...

## Recommendations
<3–5 bullet prioritized list — what to fix first, what to defer>
```

## Skill-Specific Rules

- Do not flag idempotency issues on streaming or read-only commands.
- Do not flag `--json` absence on bootstrap/install/wizard commands a human would always run.
- When proposing a fix, prefer framework-idiomatic patterns over generic advice — pull from [framework-recipes.md](./references/framework-recipes.md).
- When a fix needs a regression test, link to the matching snippet in [test-recipes.md](./references/test-recipes.md) (pytest, vitest) so the user gets a CI-enforceable assertion alongside the fix.
- Severity is contextual: a missing `--json` on the only data command is Blocker; on one of fifteen is Friction.
- Cite the principle number in every finding so the user can cross-reference [cli-principles.md](./references/cli-principles.md).

## Acceptance Checklist

- [ ] Every command in the CLI surface was classified (read / mutate / stream)
- [ ] All seven principles were evaluated against the relevant command classes
- [ ] Each finding has principle reference, severity, observed/expected, and concrete fix
- [ ] Findings are sorted by severity in the output
- [ ] Recommendations section prioritizes Blockers over Optimizations
- [ ] Framework-specific fixes reference [framework-recipes.md](./references/framework-recipes.md) where applicable

## Attribution

The seven principles are adapted from Trevin Chow, "7 Principles for Agent-Friendly CLIs" (trevinsays.com, 2026-03-26). Full credit and original wording references are preserved in [cli-principles.md](./references/cli-principles.md).
