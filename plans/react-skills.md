# Plan: React/UI audit skill suite

> Source PRD: [auditmos/brainstormer#1](https://github.com/auditmos/brainstormer/issues/1)

## Architectural decisions

Durable decisions that apply across all phases:

- **Architecture style**: four manually-invoked Claude Code skills (`/react-audit`, `/react-review`, `/react-rules`, `/react-rules-sync`) sharing a common knowledge base. No hooks, no scheduled execution.
- **Knowledge representation**: rule cards as one-file-per-rule, strict frontmatter (`id`, `category`, `detect`, `bad`, `good`, `source`). Card index file enables cheap pre-load lookup. Cards live in a shared references folder (`react-shared`).
- **Detection strategy declaration**: each card declares its own detection mechanism — `regex`, `ast`, or `llm-judge`. Skill dispatches accordingly.
- **Severity model**: Blocker / Friction / Optimization, matching `/agent-cli`. Severity assigned per-finding contextually based on render hot-path heuristics and file-path signals (e.g., test fixtures auto-downgrade).
- **Output mechanism**: every skill that emits findings writes them as GitHub issues via the `gh` CLI. Issues labeled `<skill>:<rule_id>`.
- **Issue lifecycle**: dedup by label across re-runs. Open issue with matching label is updated in place (preserving human comments). Empty findings → close. Resurfaced finding after close → new issue with backlink to the closed one.
- **Issue body**: full rule card content embedded; `<details>` collapsibles for cards over ~80 lines or >2 bad/good pairs. Each finding lists `file:line` plus ~5 lines of code context.
- **Source content handling**: canonical source quotes/snippets embedded in cards at authoring time. `/react-rules-sync` is the only skill that performs live fetching (Exa MCP for web, `gh` for GitHub-hosted). Sync output is preview-only; user manually applies updates.
- **Plugin distribution**: canonical files in `skills/<name>/`, mirror in `plugins/<name>/`, indexed via `llms.txt`.
- **Issue target repos**: `/react-audit` and `/react-review` open issues in the *current* repo being audited. `/react-rules` opens issues in the *template* repo being audited. `/react-rules-sync` produces no issues (preview only).
- **Shared deep modules**: Rule Card Library (load + index cards), Code Scanner (apply rules to code, produce findings), Issue Manager (gh CRUD with dedup logic). Source Sync is a fourth shared module used only by `/react-rules-sync`.

---

## Phase 1: Tracer bullet — `/react-audit` end-to-end with one rule

**Status**: ✅ shipped — issue #2 — commit 7bad0a6

**User stories**: 1, 8, 11, 13, 16, 19, 20, 31, 33, 34, 35

### What to build

A working `/react-audit` skill that, given a fixture repo containing exactly one occurrence of one seeded anti-pattern (`effects/computing-derived-state`), produces exactly one GitHub issue in that repo with:

- Title containing the rule id
- Label `react-audit:effects/computing-derived-state`
- Body embedding the full rule card content (id, severity, detect, bad/good snippets, source link)
- One `file:line` reference with ~5 lines of code context

This phase establishes the end-to-end path through Rule Card Library, Code Scanner (single-rule dispatch), and Issue Manager (create-only). No smart scan, no grouping, no dedup. Single rule shipped: `effects/computing-derived-state`.

### Acceptance criteria

- [x] `skills/react-audit/SKILL.md` exists with manual-trigger metadata
- [x] `skills/react-shared/references/cards/effects/computing-derived-state.md` exists with valid frontmatter and self-contained body
- [x] Rule Card Library loads the card and exposes it via a documented interface
- [x] Code Scanner dispatches the card's `detect` strategy and produces a Finding for the seeded fixture
- [x] Issue Manager creates a GitHub issue via `gh` with the correct label, title, and embedded body
- [x] Running the skill on a clean fixture (no anti-patterns) produces zero issues
- [x] All `gh` calls are observable in the skill's log; no other GitHub interaction mechanism is used

---

## Phase 2a: Effects card library — 11 cards from react.dev

**Status**: ✅ shipped — issue #3 — commit ffafedd

**User stories**: 29, 31, 32

### What to build

The full set of 11 useEffect anti-pattern cards from [react.dev/learn/you-might-not-need-an-effect](https://react.dev/learn/you-might-not-need-an-effect), all hand-authored with frontmatter, bad/good snippets, source citations, and detect strategies. Card index file (`references/cards/index.md`) lists every shipping card by id and category for cheap lookup.

`/react-audit` now dispatches across all 11 cards on each scan. Each finding still produces its own issue (one issue per occurrence — grouping comes in Phase 2c).

### Acceptance criteria

- [x] All 11 effects cards exist with valid frontmatter and self-contained bodies, each citing the canonical react.dev URL with anchor
- [x] Card index file lists every shipping card by id and category
- [x] Schema-validation script confirms 100% of cards parse and contain mandatory fields
- [x] `/react-audit` on a fixture seeded with one occurrence of each rule produces 11 GitHub issues
- [x] Detect strategy correctly dispatches per card (regex / ast / llm-judge)
- [x] LLM-judge calls are cached per `(file_hash, rule_id)` within a single run

---

## Phase 2b: Smart scan with interactive threshold prompt

**Status**: ✅ shipped — issue #4 — commit pending

**User stories**: 2

### What to build

`/react-audit` no longer scans every `*.tsx`/`*.jsx` blindly. Before scanning, the skill enumerates candidate files via `git ls-files`, filters out `node_modules/`, `dist/`, `build/`, `.next/`, `coverage/`, `**/*.test.*`, `**/*.stories.*`. If matching count is below 50, scan proceeds immediately. If 50 or more, the skill groups files by directory and prompts the user with the file count per group, asking which to include.

### Acceptance criteria

- [x] On a fixture with <50 matching files, no prompt is shown
- [x] On a fixture with ≥50 matching files, prompt lists directory groups with file counts
- [x] User can accept all, reject all, or select a subset of groups
- [x] Selected scope is logged before the scan begins
- [x] Excluded directories are never read regardless of threshold
- [x] Threshold value is documented in the skill so it can be adjusted without changing skill logic

---

## Phase 2c: Rerender cards + grouping

**User stories**: 8, 14, 23, 24

### What to build

Four rerender anti-pattern cards added to the library (`rerenders/inline-object-prop`, `rerenders/inline-array-prop`, `rerenders/missing-memo-on-list-row`, `rerenders/context-too-broad`), all hand-authored from react-doctor / Million guidance.

Issue Manager evolves from one-issue-per-finding to grouped emission: all findings sharing the same `(skill, rule_id)` are collapsed into a single issue with a body that lists every occurrence (`file:line` + context) under one card embedding. Severity is now assigned per-finding contextually — same rule can be Friction in a settings page and Blocker in a hot render path.

### Acceptance criteria

- [ ] All 4 rerender cards exist with valid frontmatter, citing react-doctor / Million sources
- [ ] Card index updated to include all 15 MVP cards
- [ ] On a fixture with N occurrences of the same rule, exactly one issue is created with N occurrences listed in the body
- [ ] Issue body uses `<details>` collapsibles when card content exceeds ~80 lines
- [ ] Severity assignment differs between hot-path and cold-path occurrences of the same rule on the same fixture
- [ ] Per-finding `file:line` and ~5 lines of context appear in every grouped issue

---

## Phase 3: Re-run lifecycle — full Issue Manager

**User stories**: 9, 10, 22

### What to build

Issue Manager reaches its full validation surface. On a re-run:

- Open issue with matching label and matching findings → body updated in place; no new issue created. Human comments preserved (only the body region marked as skill-managed is rewritten).
- Open issue with matching label but no findings remaining → closed with a comment noting the resolution date.
- Closed issue with matching label and a finding resurfaces → new issue created with a backlink to the closed one. Closed issues are never reopened.

No skill ever auto-suggests fixes or patches in issue bodies; findings remain read-only.

### Acceptance criteria

- [ ] Two consecutive runs on identical fixtures produce no duplicate issues; the original issue body is updated in place on the second run
- [ ] A run with fewer findings than the previous run closes the resolved issues with a comment
- [ ] A run that reintroduces a previously-closed finding creates a new issue with a backlink to the closed one
- [ ] Human comments on existing issues survive the body update on subsequent runs
- [ ] No issue body contains a "suggested fix" or patch block
- [ ] Label-collision test confirms two simultaneous runs do not both create an issue for the same label

---

## Phase 4: `/react-review` on diff + 1-hop neighbors

**User stories**: 3, 4, 25

### What to build

A new skill, `/react-review`, that scans only the changed files on the current branch versus a base branch (default `main`), expanded by 1-hop import neighbors — files that import or are imported by changed files. The skill reuses Rule Card Library, Code Scanner, and Issue Manager unchanged. A new thin component, Diff Scanner, computes the file set.

If a PR exists for the current branch, the skill records that context in the issue body. If no PR exists, the skill opens a standalone issue with the branch ref in the title.

### Acceptance criteria

- [ ] `skills/react-review/SKILL.md` exists with manual-trigger metadata
- [ ] Skill correctly identifies changed files via `git diff --name-only <base>...HEAD`
- [ ] 1-hop import neighbors are added to the scan set via static import analysis
- [ ] Excluded directories (matching the smart-scan exclusion list) are never scanned
- [ ] On a branch with no open PR, a standalone issue is created with the branch ref in the title
- [ ] On a branch with an open PR, the issue body links to the PR
- [ ] All issue lifecycle behaviors from Phase 3 work for `/react-review` issues

---

## Phase 5: `/react-rules` — rule-file read + drift detection

**User stories**: 5, 6, 7, 21, 27

### What to build

A new skill, `/react-rules`, that audits the UI-rules surface of a single template repo. The skill reads every rule source it can find:

- Cursor rules under `.cursor/rules/`
- `CLAUDE.md` at root and any nested variants
- `AGENTS.md`
- `.github/copilot-instructions.md`
- `.windsurfrules`, `.clinerules`
- README sections related to UI/components/styling

It also reads source code under conventional UI directories (`src/components/`, `src/app/`, `app/`, `src/routes/`, `src/pages/`) for drift detection.

For each rule statement found in the rules files, the skill classifies the finding into one of five categories:

- **Gaps** — canonical rules from the card library that are missing from the template's rule files
- **Conflicts** — template rules that contradict the canonical card library
- **Outdated** — rules referencing deprecated patterns (e.g., class components, `defaultProps`, `React.FC`, legacy Context API)
- **Vague** — rules that don't give an agent an actionable check (e.g., "write good components")
- **Drift** — rules whose prose disagrees with the actual code (e.g., "use shadcn primitives" but `src/components/` has hand-rolled modals)

Drift detection uses LLM-judge against a sampled subset of the source code. Issues are opened in the *template* repo, not in brainstormer.

### Acceptance criteria

- [ ] `skills/react-rules/SKILL.md` exists with manual-trigger metadata
- [ ] Skill reads every rule source listed above and reports which sources were found
- [ ] On a fixture template seeded with one of each finding category, all five categories surface in the output
- [ ] Drift detection LLM-judge calls are cached per `(file_hash, rule_id)` within a run
- [ ] Issues are opened in the audited template repo, not in brainstormer
- [ ] Issue grouping and lifecycle behaviors from Phase 3 apply
- [ ] No card content from the canonical library is mutated by `/react-rules`; the skill only reads cards

---

## Phase 6: `/react-rules-sync` — source fetch + diff preview

**User stories**: 17, 18, 36

### What to build

A new skill, `/react-rules-sync`, that refreshes the canonical source quotes embedded in the rule card library. The skill iterates over every shipping card, fetches the source URL declared in the card's frontmatter (Exa MCP for web sources, `gh` CLI for GitHub-hosted sources), and diffs the fetched content against the embedded quote/snippet in the card body.

Output is a preview-only report listing every card with a detected drift. No card file is mutated by the skill — the user manually applies updates after reviewing the preview. The skill produces no GitHub issues.

### Acceptance criteria

- [ ] `skills/react-rules-sync/SKILL.md` exists with manual-trigger metadata
- [ ] Skill fetches every card's source via the appropriate fetch path (Exa for web, `gh` for GitHub)
- [ ] Diff output clearly identifies which cards drift and shows the proposed change
- [ ] Skill exits without modifying any card file under any circumstances
- [ ] Skill produces no GitHub issues
- [ ] Source Sync deep module is isolated from `/react-audit`, `/react-review`, `/react-rules` code paths
- [ ] Static check confirms no live fetch (Exa, WebFetch, curl) occurs in the other three skills

---

## Phase 7: Remaining card categories + plugin polish

**User stories**: 23, 24, 25, 26, 27, 28, 37

### What to build

Card library expanded with the remaining six categories, each authored hand-by-hand from canonical sources:

- `shadcn/*` — primitive bypass, missing `cn()`/cva use, custom variants, naming convention violations
- `a11y/*` — label-input pairing, focus traps, missing `aria-label`, `forwardRef` correctness
- `tanstack/*` — Query (fetching-in-effect), Router (loaders), Form (controlled state)
- `server-client/*` — `"use client"` misuse, hydration mismatches, server/client boundary leaks
- `typescript/*` — `Readonly`/`Required` props, `any` in handlers, `forwardRef` typing, `children` typing
- `styling/*` — inline styles, design-token CSS vars, arbitrary-value misuse

Cards may land inkrementalnie within this phase; the phase closes when each of the six categories has at least one shipping card and the plugin distribution is in a marketplace-ready state.

Plugin polish:

- `plugins/<name>/` mirrors created for the four new skills
- `llms.txt` updated to index the four skills, the shared cards index, and any new references
- Schema-validation script run as part of the phase exit checklist

### Acceptance criteria

- [ ] At least one card exists in each of the six new categories with valid frontmatter and source citation
- [ ] Card index file lists every shipping card across all categories
- [ ] `plugins/react-audit/`, `plugins/react-review/`, `plugins/react-rules/`, `plugins/react-rules-sync/` mirror the canonical `skills/<name>/` folders
- [ ] `llms.txt` includes all four new skills and the shared cards index
- [ ] Schema-validation script passes for the full library with zero violations
- [ ] `/react-audit` on a real Auditmos template (e.g., `tstack-on-cf`) produces actionable findings across at least three categories
