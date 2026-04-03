# Brainstormer

Take any idea from rough concept to dev-ready deliverables — PRD, phased plan, and dependency-ordered GitHub issues — using structured AI-assisted skills.

## Why

Scope creep, vague requirements, and dev misalignment kill projects before they start. Brainstormer is a consulting toolkit that forces clarity before a single line of code is written. The output is a structured handoff package that any dev team can pick up and run with.

## Who It's For

Consultants, product owners, founders, and technical leads — working with any tech stack. Use this per engagement to guide a client from "I have an idea" to "here are the issues, start building."

## What You Get

- **PRD** — Comprehensive requirements document, submitted as a GitHub issue
- **Phased plan** — Vertical-slice implementation plan saved to `./plans/`
- **GitHub issues** — Dependency-ordered, independently-grabbable work items with HITL/AFK classification

## Installation

### Claude Code Plugin

```bash
claude plugin install <repo-url>
```

All 10 skills become available via `/` commands in any project.

### Manual Install (Claude Code)

Copy `skills/` into your project's `.claude/skills/` or your global `~/.claude/skills/`:

```bash
cp -R skills/* ~/.claude/skills/
```

### Direct Workspace

Clone and work directly in the repo:

```bash
git clone <repo-url>
cd brainstormer
# Run /brainstorm to start the full workflow
```

## Prerequisites

- An AI code assistant ([Claude Code](https://docs.anthropic.com/en/docs/claude-code), Cursor, GitHub Copilot, etc.)
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated (required for `/blueprint` and `/dispatch`)
- A GitHub repository for the engagement

## Skills

| Skill | Command | Purpose |
|-------|---------|---------|
| Brainstorm | `/brainstorm` | Full orchestrated workflow — discovery through issue creation |
| Ask | `/ask` | Discovery interview — pressure-test the idea, surface constraints |
| Blueprint | `/blueprint` | Structured interview to produce a PRD (GitHub issue) |
| Carve | `/carve` | Break PRD into phased vertical slices (`./plans/`) |
| Dispatch | `/dispatch` | Create dependency-ordered GitHub issues from PRD |
| TDD | `/tdd` | Red-green-refactor workflow with GitHub issue + plan integration |
| Lean | `/lean` | Check any decision for over-engineering |
| Ship | `/ship` | Lint, type-check, commit, and push in one flow |
| LLM Council | `/llm-council` | Multi-perspective advisory council for strategic decisions |
| Improve CLAUDE.md | `/improve-claude-md` | Audit and optimize CLAUDE.md files with conditional importance tags |

## Recommended Workflow

### 1. Discovery — `/ask`

Start here with a rough idea. The assistant runs a structured interview covering the problem, users, business model, constraints, and domain-specific concerns. Walk away with a clear summary of decisions and open questions.

### 2. Requirements — `/blueprint`

Formalize the discovery output into a Product Requirements Document. The assistant interviews you, sketches system components, and submits the PRD as a GitHub issue with user stories, implementation decisions, and validation strategy.

### 3. Planning — `/carve`

Break the PRD into tracer-bullet phases. Each phase is a thin vertical slice cutting through the full system end-to-end. Output is a markdown plan in `./plans/`.

### 4. Issues — `/dispatch`

Convert the plan into GitHub issues. Each issue is a vertical slice classified as AFK (autonomous) or HITL (needs human input), created in dependency order with blocker links.

### 5. Implementation — `/tdd`

Pick up an issue and implement it using red-green-refactor. Pass a GitHub issue number (`/tdd #123`) to pull in scope and acceptance criteria automatically, or start from scratch. The skill reads plans from `./plans/` for architectural context.

> Use `/lean` at any point to gut-check a decision against MVP principles.

Or run `/brainstorm` to be guided through all phases in sequence.

## For Other AI Assistants

Brainstormer works with any AI code assistant that reads instruction files:

- **Claude Code** reads `CLAUDE.md` (symlinked to `AGENTS.md`)
- **GitHub Copilot**, **Cursor**, and others read `AGENTS.md`
- **Any agent** can fetch `llms.txt` for a machine-readable index of all skills and references

## For Agent Developers

Point your agent at `llms.txt` in the repo root for programmatic discovery of all skills, templates, and references. Each entry links to the relevant file with a one-line description.

## Example Session

```
# Got a rough idea for a client portal? Start with discovery.
/ask
> "We need a portal where clients can upload documents and track project status"
> Assistant probes: who are the clients, how many, what document types,
> sensitivity level, existing systems, timeline, budget...

# Formalize into requirements
/blueprint
> Assistant interviews, creates GitHub issue #1 with full PRD

# Break into phases
/carve
> Creates ./plans/client-portal.md with vertical slices

# Create trackable issues
/dispatch
> "The PRD is issue #1"
> Creates issues #2-#8 in dependency order, ready for dev handoff

# Implement with TDD
/tdd #2
> Fetches issue #2, reads ./plans/client-portal.md for context,
> walks through red-green-refactor cycles with you
```

## AI Company

These skills power [Brainstormer Consulting](https://github.com/auditmos/brainstormer-co) — a 5-agent AI company built on the [Agent Companies](https://agentcompanies.io) protocol. Deploy on [Paperclip](https://paperclip.ing) for multi-agent orchestration with org charts, budgets, and approval gates.

## Extending

Brainstormer is technology-agnostic at the planning layer. After the tech stack is decided, add project-specific skills per engagement (e.g., deployment procedures, coding standards).

## License

[MIT](LICENSE)

---

Each skill is conversational — the assistant will ask questions and iterate with you before taking action.
