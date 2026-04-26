---
name: improve-claude-md
description: Audit and improve CLAUDE.md files by wrapping conditionally-relevant sections in <important if> tags, removing linter territory, and ensuring project accuracy. Use when user wants to optimize their CLAUDE.md for better agent performance.
---

# Improve CLAUDE.md — Structured Optimization

Audit an existing CLAUDE.md (or create one from scratch) by scanning the project, scoring the file across eight dimensions, and rewriting it section-by-section with user approval at each step.

## Usage

```
/improve-claude-md                 -- improve ./CLAUDE.md in current project
/improve-claude-md path/to/file    -- improve a specific file
```

## Core Principle

Wrap conditionally-relevant sections in `<important if="condition">` XML tags. This prevents the system reminder from dismissing instructions as "may or may not be relevant" — the condition tells the agent exactly when the guidance applies.

Foundational context (identity, directory map) stays bare. Everything else gets a targeted condition.

## Workflow

### Step 1 — Intake

1. Identify the target file. Default: `./CLAUDE.md`. Check for `AGENTS.md` symlinks.
2. If the file exists, read its full contents. If not, confirm the user wants to create one from scratch.
3. Confirm scope: "I'll audit and improve this file. Ready to proceed?"

### Step 2 — Project Scan

Read (never modify) project files to build context. Adapt the scan to what exists:

| Category | Files to check |
|----------|---------------|
| Language/Framework | `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile` |
| Commands | `Makefile`, `justfile`, `Taskfile.yml`, `package.json` scripts |
| CI/CD | `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile` |
| Linters/Formatters | `.eslintrc*`, `.prettierrc*`, `biome.json`, `ruff.toml`, `rustfmt.toml` |
| Testing | `vitest.config.*`, `jest.config.*`, `pytest.ini`, `phpunit.xml` |
| Config | `tsconfig.json`, `docker-compose.yml`, `.env.example` |
| Structure | Top two levels of the directory tree |

Present a one-paragraph summary: "This is a TypeScript monorepo using pnpm, Vitest, ESLint + Prettier, deployed via GitHub Actions." Ask the user to confirm or correct before proceeding.

### Step 3 — Audit

Score the existing CLAUDE.md across eight dimensions. Present findings one dimension at a time (exhaust each before moving on).

**Reasoning approach:** Many findings are cross-dimensional — e.g., a vague instruction nested inside a domain section, or a code snippet that duplicates linter rules. Hold all 8 dimensions in mind simultaneously while scoring each one. Reason silently through the full file before writing the scorecard. **Recommended for this step:** opus-4.7 with extended thinking (high effort).

**Dimensions:**

1. **Identity** — Is there a clear one-sentence project description? Is it bare (unwrapped)?
2. **Directory map** — Present or absent? Accurate against the actual project structure?
3. **Commands** — Are build/test/lint/deploy commands listed? Wrapped in a single `<important if="you need to run commands">` block?
4. **Rules granularity** — Are rules individually wrapped with specific conditions, or monolithic?
5. **Domain sections** — Are testing, API, state management, deployment sections wrapped with appropriate conditions?
6. **Linter overlap** — Identify instructions that duplicate what the project's linters/formatters already enforce. These are deletion candidates.
7. **Code snippets** — Are there inline code blocks that should be file path references instead?
8. **Vague instructions** — "Follow best practices," "keep code clean," etc. These add noise and should be deleted.

Output a scorecard:

```
Dimension          | Status     | Action
-------------------|------------|---------------------------
Identity           | Good       | None
Directory map      | Missing    | Generate from project scan
Commands           | Unwrapped  | Wrap in <important if>
Rules granularity  | Monolithic | Split into individual blocks
Domain sections    | Partial    | Add testing, API sections
Linter overlap     | 3 items    | Delete
Code snippets      | 2 found    | Replace with file refs
Vague instructions | 1 found    | Delete
```

### Step 4 — Rewrite

Address each scorecard action, one section at a time:

1. Show the **before** (current content or "missing")
2. Show the **after** (proposed content)
3. Explain the **rationale** (why this change improves agent performance)
4. Wait for user approval before proceeding to the next section

**Transformation rules:**
- Identity → one bare sentence at the top
- Directory map → bare, accurate against project scan
- Commands → single `<important if="you need to run commands to build, test, lint, or deploy">` block
- Rules → split into individual `<important if>` blocks with specific conditions (see [important-if-catalog.md](./references/important-if-catalog.md))
- Domain sections → wrap each with a relevant condition
- Linter overlap → delete entirely
- Code snippets → replace with file path references
- Vague instructions → delete entirely

Reference [claude-md-template.md](./references/claude-md-template.md) for the ideal structure.

### Step 5 — Verify & Apply

1. Present the complete proposed file for final review
2. Walk through the acceptance checklist
3. Only after explicit confirmation, write the file

## Skill-Specific Rules

- Present diffs section-by-section, not all at once.
- Never delete content without explaining why.
- If unsure whether something is linter territory, ask — don't assume.

## Acceptance Checklist

- [ ] Project scanned and summary confirmed by user
- [ ] Audit scorecard presented and discussed
- [ ] Identity section is one bare sentence
- [ ] Directory map is accurate and bare
- [ ] Commands wrapped in single `<important if>` block
- [ ] Each rule wrapped individually with a specific condition
- [ ] Domain sections wrapped with relevant conditions
- [ ] No linter-enforceable instructions remain
- [ ] No inline code snippets (replaced with file references)
- [ ] No vague instructions remain
- [ ] User approved final output before file was written
