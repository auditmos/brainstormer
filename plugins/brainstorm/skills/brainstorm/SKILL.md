---
name: brainstorm
version: 1.1.0
description: Orchestrated planning workflow — guides through discovery, PRD creation, vertical-slice phasing, and GitHub issue generation. Use when starting a new project or feature from scratch.
---

# Brainstorm — Full Workflow

Guide the client through the complete brainstormer workflow, from rough idea to dev-ready GitHub issues. This is the recommended entry point for new engagements.

If `$ARGUMENTS` contains an idea description, use it as the starting context. Otherwise, ask the client to describe their idea.

## Workflow Phases

Each phase runs the named skill — that skill's own instructions carry the details.

1. **Discovery (`/ask`)** — pressure-test the idea. Do not advance until the client confirms the discovery summary is complete.
2. **Requirements (`/blueprint`)** — formalize discovery into a PRD. Do not advance until the PRD issue is created and the client approves it.
3. **Planning (`/carve`)** — break the PRD into tracer-bullet phases saved to `./plans/`. Do not advance until the client approves the phase breakdown.
4. **Issues (`/dispatch`)** — convert the plan into dependency-ordered GitHub issues.

After completion, suggest `/improve-claude-md` if the target project has a CLAUDE.md that could benefit from optimization.

## Phase Transitions

Before moving to the next phase:

1. Summarize what was accomplished in the current phase
2. Confirm the client is ready to proceed
3. Mention that `/lean` is available at any point to check for over-engineering, and `/llm-council` for strategic decisions that warrant multi-perspective analysis
