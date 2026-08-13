---
name: dispatch
description: Convert a PRD into independently-grabbable GitHub issues using vertical slices. Use when the user wants to create issues from a PRD, break down a PRD into tasks, or create GitHub issues from requirements.
---

# Dispatch — PRD to Issues

Break a PRD into independently-grabbable GitHub issues using vertical slices (tracer bullets).

> **CLI tools — special case.** If the PRD describes a command-line tool, suggest running `/agent-cli` in design mode before issue creation. Locking flags, output formats, and error model up front prevents rework across the dependency-ordered slices.

## Process

### 1. Locate the PRD

Ask the user for the PRD GitHub issue number (or URL).

If the PRD is not already in your context window, fetch it with `gh issue view <number>` (with comments).

### 2. Review existing context (optional)

If available, review `./plans/` for related plans and prior architectural decisions.

### 3. Draft vertical slices

Break the PRD into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer:

- Each slice delivers a narrow but COMPLETE path from user-facing behavior through to data persistence
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- Do NOT include specific file names, function names, or implementation details that are likely to change as later phases are built
- DO include durable decisions: architecture style, data model shapes, entity names

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

**Agent-loopable AC test — applied to every issue before creation:**

> *Could an AFK agent picking up this issue tomorrow tell, by itself, whether the work is done — without asking anyone?*

If the answer is no, the acceptance criteria are too weak. Sharpen them until each AC reduces to a test, an observable artifact, or a runnable command. AFK issues with vague ACs become HITL issues by accident.

**HITL issues are allowed subjective ACs**, but the issue must be explicitly marked HITL and the subjective gate named ("design review by @owner before merge"). Don't ship a subjective AC under an AFK label.

**Cut what wasn't asked.** Every slice traces to a user story in the PRD. If a draft issue includes work outside the PRD ("also refactor X while we're here"), drop it or file it as a separate issue. The downstream `/tdd` agent will implement exactly what the issue says — including the unscoped extra.

### 4. Quiz the user

Present the proposed breakdown as a numbered list showing each slice's title, type (HITL/AFK), blockers, and the user stories from the PRD it covers. Ask whether the granularity feels right (too coarse / too fine), the dependency relationships are correct, any slices should be merged or split, and the HITL/AFK labels are right. Iterate until the user approves the breakdown.

### 5. Create the GitHub issues

For each approved slice, create a GitHub issue using `gh issue create`. Use the template in [issue-template.md](./references/issue-template.md). Run `gh auth status` first; if it fails, inform the user and provide the fix command.

Create issues in dependency order (blockers first) so you can reference real issue numbers in the "Blocked by" field.

Do NOT close or modify the parent PRD issue.
