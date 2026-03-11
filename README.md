# Brainstormer

Take any idea from rough concept to dev-ready deliverables — PRD, phased plan, and dependency-ordered GitHub issues — using structured Claude Code skills.

## Why

Scope creep, vague requirements, and dev misalignment kill projects before they start. Brainstormer is a consulting toolkit that forces clarity before a single line of code is written. The output is a structured handoff package that any dev team can pick up and run with.

## Who It's For

Consultants, product owners, founders, and technical leads — working with any tech stack. Clone this template per engagement to guide a client from "I have an idea" to "here are the issues, start building."

## What You Get

- **PRD** — Comprehensive requirements document, submitted as a GitHub issue
- **Phased plan** — Vertical-slice implementation plan saved to `./plans/`
- **GitHub issues** — Dependency-ordered, independently-grabbable work items with HITL/AFK classification

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated
- A GitHub repository for the engagement

## Quick Start

1. Clone this template into your engagement repo
2. Run `/ask` and describe your idea
3. Follow the workflow through to issue creation

## Skills

| Skill | Command | Purpose |
|-------|---------|---------|
| Ask | `/ask` | Discovery interview — pressure-test the idea, surface constraints |
| Blueprint | `/blueprint` | Structured interview to produce a PRD (GitHub issue) |
| Carve | `/carve` | Break PRD into phased vertical slices (`./plans/`) |
| Dispatch | `/dispatch` | Create dependency-ordered GitHub issues from PRD |
| Lean | `/lean` | Check any decision for over-engineering |


## Recommended Workflow

### 1. Discovery — `/ask`

Start here with a rough idea. Claude runs a structured interview covering the problem, users, business model, constraints, and domain-specific concerns. Walk away with a clear summary of decisions and open questions.

### 2. Requirements — `/blueprint`

Formalize the discovery output into a Product Requirements Document. Claude interviews you, sketches system components, and submits the PRD as a GitHub issue with user stories, implementation decisions, and validation strategy.

### 3. Planning — `/carve`

Break the PRD into tracer-bullet phases. Each phase is a thin vertical slice cutting through the full system end-to-end. Output is a markdown plan in `./plans/`.

### 4. Issues — `/dispatch`

Convert the plan into GitHub issues. Each issue is a vertical slice classified as AFK (autonomous) or HITL (needs human input), created in dependency order with blocker links.

> Use `/lean` at any point to gut-check a decision against MVP principles.

## Example Session

```
# Got a rough idea for a client portal? Start with discovery.
/ask
> "We need a portal where clients can upload documents and track project status"
> Claude probes: who are the clients, how many, what document types,
> sensitivity level, existing systems, timeline, budget...

# Formalize into requirements
/blueprint
> Claude interviews, creates GitHub issue #1 with full PRD

# Break into phases
/carve
> Creates ./plans/client-portal.md with vertical slices

# Create trackable issues
/dispatch
> "The PRD is issue #1"
> Creates issues #2-#8 in dependency order, ready for dev handoff
```

## Extending

Brainstormer stays technology-agnostic at the planning layer. After the tech stack is decided, add project-specific skills per engagement (e.g., TDD workflows, deployment procedures).

---

Each skill is conversational — Claude will ask questions and iterate with you before taking action.
