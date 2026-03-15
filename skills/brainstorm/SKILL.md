---
name: brainstorm
description: Orchestrated planning workflow — guides through discovery, PRD creation, vertical-slice phasing, and GitHub issue generation. Use when starting a new project or feature from scratch.
---

# Brainstorm — Full Workflow

Guide the client through the complete brainstormer workflow, from rough idea to dev-ready GitHub issues. This is the recommended entry point for new engagements.

## Getting Started

If `$ARGUMENTS` contains an idea description, use it as the starting context. Otherwise, ask the client to describe their idea.

## Workflow Phases

### Phase 1: Discovery (`/ask`)

Run a discovery interview to pressure-test the idea. Cover:
- Problem and target users
- Business model and constraints
- Scale and operations
- Domain-specific concerns

**Do not advance** until the client confirms the discovery summary is complete.

### Phase 2: Requirements (`/blueprint`)

Formalize the discovery output into a Product Requirements Document:
- Interview for remaining details
- Sketch system components
- Submit the PRD as a GitHub issue

**Do not advance** until the PRD issue is created and the client approves it.

### Phase 3: Planning (`/carve`)

Break the PRD into tracer-bullet vertical slices:
- Identify durable architectural decisions
- Draft phases as thin end-to-end slices
- Save the plan to `./plans/`

**Do not advance** until the client approves the phase breakdown.

### Phase 4: Issues (`/dispatch`)

Convert the plan into dependency-ordered GitHub issues:
- Each issue is a vertical slice classified as AFK or HITL
- Created in dependency order with blocker links

## Phase Transitions

Before moving to the next phase:
1. Summarize what was accomplished in the current phase
2. Confirm the client is ready to proceed
3. Mention that `/lean` is available at any point to check for over-engineering

## Session Rules

- Exhaust one topic fully before moving to the next. No compound questions.
- Restate decisions back to the client before finalizing.
- Technology choices appear in deliverables **only** when the client explicitly states them.
- Tone: Professional, direct, thorough. This is a consulting engagement.
