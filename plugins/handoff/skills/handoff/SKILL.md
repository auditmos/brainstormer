---
name: handoff
description: Capture the entire current chat as a structured handoff document the user can paste into Codex, Cursor, or another IDE-based AI coding agent. Triggers on /handoff, /export-context, /dump, "package this for codex", "send this to cursor", "make a handoff doc", "i wanna take this to another model", or similar phrasing indicating intent to continue work elsewhere. Produces lossless distillation — every meaningful detail survives, with discarded approaches explicitly labeled by reason so the next model does not re-suggest rejected paths.
---

# Handoff — Chat-to-Handoff Distillation

Generate a complete, structured handoff document from the current chat session, optimized for consumption by Codex, Cursor, or other IDE-based AI coding agents.

Two output files with identical content in different formats:

- `handoff-{slug}-{YYYY-MM-DD}.md` — markdown with headings, code fences, tables
- `handoff-{slug}-{YYYY-MM-DD}.txt` — flat text with ASCII section dividers

## When to Invoke

Any of the following — explicit or loose intent to move the session elsewhere:

- `/handoff`, `/export-context`, `/brief codex`, `/give to cursor`, `/dump`
- "package this for codex", "export this chat", "make a handoff doc", "send this to cursor", "i wanna take this to another model"

If the user clearly wants to continue the work in another tool, run the skill — do not ask first.

## Core Principle

This is **lossless distillation**, not transcription. Every meaningful detail from the chat survives, but reorganized so the next model can act immediately. The biggest single value-add is **explicitly labeling discarded approaches with the reason they were rejected**, so the next model does not re-suggest them.

Do not paraphrase technical details. File paths, function names, error messages, version numbers, command strings, and config values must appear verbatim. Prose around them can be tightened.

## Output

- Save both files to `./handoffs/` in the current repo (create the directory if missing — same convention as `./plans/`).
- Project slug: lowercase, hyphenated, inferred from the chat (repo name, app name, or main subject). Fallback: `session`.
- Multiple handoffs same day: append `-1`, `-2`, etc. to the slug.

## Workflow

### Step 1 — Walk the chat

Read the conversation start to current turn. Extract the eleven categories listed in [extraction-checklist.md](./references/extraction-checklist.md). Throwaway details count — `port 465 needs secure: true` is exactly the kind of thing the next model needs.

### Step 2 — Label every code block

Tag every code block with one of `[FINAL]`, `[SUPERSEDED]`, `[REJECTED]`, `[DRAFT]`. Rejection reasons are mandatory for `[SUPERSEDED]` and `[REJECTED]`. **Never abbreviate or truncate `[FINAL]` or `[SUPERSEDED]` blocks** — the receiving model has no FS access. Full rules in [code-status-tags.md](./references/code-status-tags.md).

### Step 3 — Render the `.md`

Follow the section order in [output-template.md](./references/output-template.md). Omit a section only if it would be empty — but prefer marking empty sections `_(none recorded in this session)_` so the receiving model knows nothing was missed.

### Step 4 — Render the `.txt`

Convert the `.md` content using the substitution rules in [txt-format.md](./references/txt-format.md). Same content, different chrome.

### Step 5 — Write & report

Write both files with the `Write` tool. Print to chat:

1. The absolute paths of both files.
2. A one-line summary: code-block counts per status, decision count, error count.
3. A recommended first prompt for the receiving model: `"Read this handoff doc, then continue from Next Step 1."`

## Skill-Specific Rules

- **One-shot.** Never ask clarifying questions. Infer the project slug; fall back to `session` if genuinely ambiguous.
- **Verbatim discipline.** Identifiers, paths, error strings, version numbers, command strings appear exactly as in the chat. Only surrounding prose may be tightened.
- **No em-dashes in the output files.** Use double hyphens (`--`) or commas. Many downstream tools render or parse em-dashes inconsistently. (This rule applies to the generated `.md` and `.txt` only — not to this SKILL.md itself.)
- **No invented details.** If a section has no content, write `_(none recorded in this session)_`. Do not fabricate to fill space.
- **Never abbreviate `[FINAL]` or `[SUPERSEDED]` code blocks.** Full bytes only — no `[... rest of file ...]`, no `[... truncated ...]`, no `[... see repo ...]`. The next model cannot reach your filesystem.
- **Rejection reason is mandatory** on every `[SUPERSEDED]` and `[REJECTED]` block. Without it, the next model re-suggests the same wrong thing — that is the whole point of this skill.

## Acceptance Checklist

- [ ] Both files written to `./handoffs/` with the `handoff-{slug}-{YYYY-MM-DD}` naming convention
- [ ] Every code block from the chat carries a `[FINAL]`, `[SUPERSEDED]`, `[REJECTED]`, or `[DRAFT]` tag
- [ ] Every `[SUPERSEDED]` and `[REJECTED]` block has a rejection reason
- [ ] No `[FINAL]` or `[SUPERSEDED]` block was abbreviated or truncated
- [ ] Empty sections marked `_(none recorded in this session)_` rather than omitted
- [ ] No em-dashes in the output files
- [ ] Both files reported to the user with absolute paths and the summary line
