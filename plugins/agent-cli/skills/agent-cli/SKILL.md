---
name: agent-cli
description: Design and audit CLIs that AI agents (Claude Code, Codex, automated pipelines) consume. Applies ten agent-native principles, organized as Tier 1 (table stakes — non-interactive default, structured output, errors that enumerate, safe retries, bounded responses) and Tier 2 (compounding — cross-CLI vocabulary, three-layer introspection, async-aware execution, persistent profiles, two-way I/O). Uses a Blocker / Friction / Optimization severity rubric across six command classes (read, mutate, stream, bootstrap, async, config). Use when the user is building, reviewing, or specifying a command-line tool meant for agent invocation, mentions argparse, click, cobra, clap, commander, yargs, oclif, or thor, asks about agent-friendly or agent-native CLI design, --json output, exit codes for agents, idempotent commands, --wait flags, agent-context introspection, persistent profiles, --deliver routing, --force confirmation bypass, vocabulary consistency, or works in a repo containing cli.py, main.go, src/cli.rs, or bin/<tool>. Skip for general shell scripting unrelated to CLI tool design and for human-only interactive TUIs.
---

# Agent CLI — Design & Audit Skill

Audit an existing CLI (or design a new one from scratch) against ten agent-native principles, classifying every finding by severity so the user can prioritize fixes. Principles are organized into two tiers: Tier 1 (table stakes — defensive, prevent breakage) and Tier 2 (compounding — empowering, make the CLI more useful as agents accumulate persistent identity, async workflows, and feedback channels).

## Usage

```
/agent-cli                     -- ask which mode (audit existing or design new)
/agent-cli audit               -- review CLI source/spec in current repo
/agent-cli design <name>       -- guide design of a new CLI from zero
```

The skill also auto-loads when the conversation surfaces CLI design topics (frameworks, `--json` outputs, exit codes, idempotency, `--wait` flags, `agent-context` introspection, persistent profiles, `--deliver` routing, vocabulary consistency, agent invocation patterns).

## Core Principle

Agents pay real costs for every prompt that hangs, every line of unstructured output, every vague error, every retry that silently duplicates work, and every workflow that requires the agent to write its own polling loop. Designing for agents first removes the tax that the forgiving consumer (humans) was silently paying. A CLI optimized for agents is also better for humans — the reverse is not true.

## The Ten Principles

### Tier 1 — Table Stakes (defensive)

Don't break the agent. When these aren't met, the deck is stacked against the agent on every call.

| # | Principle | One-line test |
|---|-----------|---------------|
| 1 | Non-interactive by default | Run with `stdin=DEVNULL`; does it exit instead of hanging? |
| 2 | Structured, parseable output | Is `--json` (singular, canonical) available on every data-bearing command? |
| 3 | Errors that teach, and enumerate | Does the error name the fix and list the valid set inline? |
| 4 | Safe retries & explicit mutation boundaries | Does running the same mutating or async command twice corrupt state? |
| 5 | Bounded responses, at every layer | Does a routine query teach the agent how to narrow further, and does the MCP tool description fit a budget? |

### Tier 2 — Compounding (empowering)

Tier 1 keeps you in the game. Tier 2 makes the CLI better the more it gets used.

| # | Principle | One-line test |
|---|-----------|---------------|
| 6 | Cross-CLI vocabulary consistency | Are verbs `get`/`list`/`create`/`update`/`delete` and flags `--force`/`--json`/`--limit`/`--profile`? |
| 7 | Three-layer introspection | Does `<cli> --help`, `<cli> agent-context` (versioned JSON), and a skill manifest all describe the same surface? |
| 8 | Async-aware execution | Does `--wait` block until completion, and does a `jobs` ledger survive disconnect? |
| 9 | Persistent identity through profiles | Can the agent save a `--profile` once and reuse it across sessions, with explicit-flag > env > profile precedence? |
| 10 | Two-way I/O | Does `--deliver` route artifacts to stdout/file/webhook, and does `<cli> feedback` close the loop back to maintainers? |

Full explanation, rationale, and worked examples in [cli-principles.md](./references/cli-principles.md).

## Severity Rubric

Every finding maps to one of three levels. The level depends on what the command does — idempotency matters for mutating and async commands, irrelevant for streaming logs.

| Severity | Meaning | Example |
|----------|---------|---------|
| **Blocker** | Prevents reliable agent use | Command hangs awaiting input; no `--json` on data command; silent state corruption on retry; async submit returns `job_id` with no `--wait`; verbs contradict universal conventions (`info` instead of `get`) |
| **Friction** | Works but wastes tokens / retries | Errors name the problem but not the fix; inconsistent `--json` coverage; ANSI codes in piped output; `agent-context` exists but unversioned; profiles saved but not surfaced in introspection |
| **Optimization** | Functional but improvable | Help lacks examples; `--limit` defaults too broad; framework-idiomatic patterns missing; codegen recommendation for >20-command CLIs |

**Tier-aware default skew:** Tier 1 violations skew **Blocker** by default — they're table stakes. Tier 2 violations skew **Friction** by default unless the CLI is large enough that absence becomes load-bearing (see severity scaling under each principle in [audit-checklist.md](./references/audit-checklist.md)).

Per-principle × per-command-class severity mapping lives in [audit-checklist.md](./references/audit-checklist.md).

## Workflow — Audit Mode

### 1. Locate the CLI surface

Find the entry point and command tree. Common patterns: `cli.py` (argparse/click), `cmd/` (cobra), `src/main.rs` (clap), `bin/<tool>` (commander/yargs/oclif).

### 2. Classify commands

For each command, pick a class from six options:

- **read** — query, list, get, search, describe (no side effects)
- **mutate** — create, update, delete, deploy, publish, send (sync state change)
- **stream** — tail, follow, watch (long-running ongoing output)
- **bootstrap** — init, install, setup wizards (one-shot, often interactive by design)
- **async** — submit a job that completes off-band; returns job_id; wants `--wait` (Principles 4 + 8)
- **config** — profile, auth, preferences, local state (Principle 9)

Use the decision tree in [audit-checklist.md](./references/audit-checklist.md) for ambiguous cases. Severity weighting differs by class.

### 3. Run the checklist

Walk all 10 principles in [audit-checklist.md](./references/audit-checklist.md), Tier 1 first then Tier 2. For each finding record: principle number, command path, observed behavior, expected behavior, severity, suggested fix.

### 4. Output the report

Use the format in [Output Format](#output-format). Sort findings by severity (Blocker first), then by principle. Reference [framework-recipes.md](./references/framework-recipes.md) when the fix is framework-specific.

## Workflow — Design Mode

### 1. Establish constraints

Confirm: target framework, command scope (1 command vs. multi-resource tool), command classes likely to appear (read-only? async-heavy? config-driven?), primary agent consumers (Claude Code subagents? CI pipeline? interactive humans too?). Constraint set drives recipe choices.

### 2. Sketch the surface

Draft the command tree, flag set, output formats, and Tier 2 surfaces up front. For each command propose: invocation shape, `--json` schema, error catalog (with enumerated valid sets), dry-run behavior (mutating only), pagination defaults (read only), `--wait` and ledger entry (async only), profile resolution (config-aware only), `--deliver` schemes (artifact-emitting only). Sketch `agent-context` JSON shape at the top level.

### 3. Verify against all 10 principles

Walk every principle, both tiers, with the proposed surface. A design-mode pass fails the same way as an audit — write findings as if reviewing a finished tool.

### 4. Output the design doc

Same format as audit, plus a "Surface Sketch" section showing the proposed command tree and flag set in code blocks, plus a `agent-context` skeleton.

## Output Format

```
# CLI Agent Readiness — <tool name> (<audit|design>)

## Summary
<1–3 sentence verdict — overall readiness, headline issues>

## Findings (sorted by severity)
### Blocker — <Principle #N>: <command path>
**Observed:** <what the CLI does today / what the design proposes>
**Expected:** <what an agent-native CLI would do>
**Fix:** <concrete change, framework-idiomatic if possible>

### Friction — <Principle #N>: <command path>
...

### Optimization — <Principle #N>: <command path>
...

## Recommendations
<3–5 bullet prioritized list — what to fix first, what to defer>

## Architectural backstop (only if applicable)
<surfaced when CLI has >20 commands, repeated vocabulary inconsistencies,
 or agent-context drift; recommend codegen/schema-driven approach>
```

## Skill-Specific Rules

- Do not flag idempotency issues on streaming or read-only commands.
- Do not flag `--json` absence on bootstrap/install/wizard commands a human would always run.
- Do not flag profile system absence on CLIs with ≤2 commands or no credential state — surface as Optimization at most. For 3-5 commands using credentials, Friction. For >5, Blocker for daily use.
- Do not flag `agent-context` absence on CLIs with <5 commands; for 5-20 commands surface as Friction; for >20 commands surface as Blocker, AND additionally recommend schema/codegen approach (architectural backstop, see [cli-principles.md](./references/cli-principles.md)).
- When proposing a fix, prefer framework-idiomatic patterns over generic advice — pull from [framework-recipes.md](./references/framework-recipes.md). Tier 2 recipes ship for Click/Cobra/Commander/oclif; for argparse/clap/yargs the pattern transfers verbatim, just lift the helper functions.
- When a fix needs a regression test, link to the matching snippet in [test-recipes.md](./references/test-recipes.md) (pytest, vitest) so the user gets a CI-enforceable assertion alongside the fix.
- Severity is contextual: a missing `--json` on the only data command is Blocker; on one of fifteen is Friction. Same logic applies to Tier 2 (severity scaling tables in audit-checklist).
- Cite the principle number in every finding so the user can cross-reference [cli-principles.md](./references/cli-principles.md).

## Acceptance Checklist

- [ ] Every command in the CLI surface was classified into one of six classes (read / mutate / stream / bootstrap / async / config)
- [ ] All 10 principles (Tier 1 + Tier 2) were evaluated against the relevant command classes
- [ ] Each finding has principle reference, severity, observed/expected, and concrete fix
- [ ] Findings are sorted by severity in the output
- [ ] Recommendations section prioritizes Blockers over Friction over Optimizations
- [ ] Framework-specific fixes reference [framework-recipes.md](./references/framework-recipes.md) where applicable
- [ ] CI-enforceable test snippets from [test-recipes.md](./references/test-recipes.md) are linked for fixes that warrant regression coverage
- [ ] Architectural backstop (codegen / schema) surfaced as a recommendation when the CLI has >20 commands, repeated vocabulary inconsistencies, or `agent-context`/`--help` drift

## Attribution

The ten principles are adapted from Trevin Chow, "10 Principles for Agent-Native CLIs" (trevinsays.com, 2026-05-01). This supersedes the earlier "7 Principles for Agent-Friendly CLIs" (2026-03-26) per the author's own "replacement, not a sequel" framing — Tier 1 condenses the original seven into five with three substantive upgrades (single-canonical `--json`, errors that enumerate the valid set, MCP description budgets), and Tier 2 adds five new compounding principles. Full credit, original wording references, and architectural backstop note are preserved in [cli-principles.md](./references/cli-principles.md).
