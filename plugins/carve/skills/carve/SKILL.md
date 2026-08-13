---
name: carve
version: 1.1.0
description: Turn a PRD into a multi-phase implementation plan using tracer-bullet vertical slices, saved as a local Markdown file in ./plans/. Use when user wants to break down a PRD, create an implementation plan, plan phases from a PRD, or mentions "tracer bullets".
---

# Carve — PRD to Plan

Break a PRD into a phased implementation plan using vertical slices (tracer bullets). Output is a Markdown file in `./plans/`.

> **CLI tools — special case.** If the PRD describes a command-line tool, suggest running `/agent-cli` in design mode before slicing. Locking flags, output formats, and error model up front prevents rework once vertical slices start landing.

## Process

### 1. Confirm the PRD is in context

If it isn't, ask the user to paste it or point you to the file.

### 2. Identify durable architectural decisions

**Reasoning approach:** Mentally trace 2-3 likely implementation paths through the PRD end-to-end. A "durable" decision is one all paths share. Reason through alternatives before listing — surface hidden assumptions, then prune.

Before slicing, identify high-level decisions that are unlikely to change throughout implementation:

- System architecture style
- Data model shape and key entities
- Authentication / authorization approach
- Third-party service boundaries
- Key constraints (compliance, performance, budget)

These go in the plan header so every phase can reference them.

### 3. Draft vertical slices

**Reasoning approach:** Hold the full PRD in mind while slicing; verify each slice mentally before writing.

Break the PRD into **tracer bullet** phases. Each phase is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer:

- Each slice delivers a narrow but COMPLETE path from user-facing behavior through to data persistence
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- Do NOT include specific file names, function names, or implementation details that are likely to change as later phases are built
- DO include durable decisions: architecture style, data model shapes, entity names

**Push back on slice creep.** Every slice must trace to an explicit user story in the PRD. If a draft slice includes functionality not in the PRD ("while we're in there, let's also add X"), cut X — propose it as a follow-up phase or send it back to `/blueprint`. Phases that drift past the PRD turn `/tdd` into an open-ended design exercise.

**Acceptance criteria must be verifiable.** Every AC must reduce to an automated test, an observable artifact, or a runnable command — the plan template shows the annotation format. "It works" or "feature complete" do not qualify; sharpen before the phase ships to `/dispatch` or `/tdd`.

### 4. Quiz the user

Present the proposed breakdown as a numbered list showing each phase's title and the user stories from the PRD it covers. Ask whether the granularity feels right (too coarse / too fine) and whether any phases should be merged or split. Iterate until the user approves the breakdown.

### 5. Write the plan file

Create `./plans/` if it doesn't exist. Write the plan as a Markdown file named after the feature (e.g. `./plans/user-onboarding.md`). Use the template in [plan-template.md](./references/plan-template.md).
