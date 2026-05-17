---
name: react-audit
description: Audit a React/TSX repository for React anti-patterns by loading rule cards from the brainstormer card library, scanning source files via the strategy each card declares, and filing one GitHub issue per finding via the `gh` CLI. Phase 2b adds a smart-scan front step that enumerates candidates via `git ls-files`, applies a canonical exclusion list, and asks the user before scanning when the matching count meets the documented threshold. Phase 2a's full 11-card effects library from react.dev/learn/you-might-not-need-an-effect remains in scope; manual invocation only — no hooks, no scheduled execution. Triggers on `/react-audit`, "audit this repo for react anti-patterns", "scan for useEffect anti-patterns", "run a react audit", or similar phrasing requesting a React/UI quality scan with GitHub-issue output. Skip for design questions, scaffolding requests, or audits of non-React frameworks (Vue, Svelte, Solid).
---

# React Audit — Phase 2b (smart scan + 11-card effects dispatch)

Manual-invocation skill that loads every shipping card under the `effects/`
category, scans the current repository for occurrences of each anti-pattern,
and files a GitHub issue per finding. Phase 2b layers a Smart Scan front
step (candidate enumeration, canonical exclusion list, interactive
threshold prompt) on top of the Phase 2a 11-card dispatch from
[react.dev/learn/you-might-not-need-an-effect](https://react.dev/learn/you-might-not-need-an-effect)
— no grouping, no dedup; those arrive in Phases 2c / 3.

## Usage

```
/react-audit
```

The skill takes no arguments. It loads every card in the `effects/` category
via `listCards("effects")`, scans every tracked `*.tsx`/`*.jsx` file in the
current repo, and creates one issue per finding (one issue per occurrence,
per rule — grouping arrives in Phase 2c).

## Scope Boundaries (Phase 2b)

- **All shipping `effects/` cards** — Phase 2a ships eleven cards. The
  scanner dispatches across each card listed in
  `skills/react-shared/references/cards/index.md` under the `effects/`
  category. Adding a new card to the index automatically extends the scan;
  no skill-side change required.
- **Smart scan front step** — Phase 2b inserts `enumerateScanTargets()`
  ahead of the scan. Candidate files come from `git ls-files`; the canonical
  exclusion list is applied unconditionally; the threshold prompt fires only
  when the post-exclusion count meets the documented constant.
- **Create-only** — no dedup, no in-place body update, no regression
  backlinking. Re-running creates duplicate issues. Dedup arrives in Phase 3.
- **No grouping** — one issue per occurrence per rule. Grouping by
  `(skill, rule_id)` arrives in Phase 2c.
- **`gh` CLI only** — no `curl`, no `WebFetch`, no Octokit. All GitHub
  interaction goes through the `gh` binary already configured in the user's
  shell.

## Workflow

1. Resolve the rule set: `cards = listCards("effects")`. The Rule Card
   Library reads `references/cards/index.md` and returns every card whose
   category is `effects`. Phase 2a returns eleven cards.
2. Enumerate scan targets via Smart Scan:
   `files = enumerateScanTargets()`. The module runs `git ls-files`, applies
   the canonical exclusion list, then either returns the file set
   immediately (count below `SMART_SCAN_THRESHOLD`) or prompts the user to
   accept-all / reject-all / select a subset of directory groups (count at
   or above the threshold). The selected scope is logged before step 3.
3. Produce findings: `findings = scan(files, cards)`. The scanner dispatches
   each card by its declared `detect` strategy (Phase 2a — all eleven cards
   use `llm-judge`).
4. For each finding, file an issue:
   `createIssue(repo=<cwd>, label="react-audit:" + finding.rule_id, finding)`.
   The label is derived per-finding from the matched rule, not hardcoded.
5. Print every created issue URL to stdout for the user.

If `findings` is empty, exit with a single-line summary `0 findings` and
create no issues.

## Rule Card Library

Reads cards from `skills/react-shared/references/cards/`, the canonical
shared-knowledge folder consumed by the React audit skill suite.

### Contract

```
loadCard(id: string) → Card
listCards(category?: string) → Card[]
```

`Card` shape:

```
{
  id: string,         // e.g. "effects/computing-derived-state"
  category: string,   // one of: effects rerenders shadcn a11y tanstack server-client typescript styling
  detect: string,     // one of: regex ast llm-judge
  source: string,     // canonical citation URL with anchor
  body: string,       // markdown body after frontmatter — embedded verbatim into issue body
}
```

### Behavior

- `loadCard("effects/computing-derived-state")` reads
  `skills/react-shared/references/cards/effects/computing-derived-state.md`,
  parses the YAML frontmatter for the four mandatory fields, captures the
  body verbatim (everything after the closing `---`), and returns a `Card`.
- On a missing id (file does not exist), throw an error whose message names
  the missing id literally — e.g. `Card not found: "effects/foo-bar"`.
- On malformed frontmatter (any mandatory field missing), throw an error
  naming the missing field — e.g. `Card "effects/x": missing 'detect'`.
- The first call performs disk I/O. Subsequent calls in the same session
  return the in-memory cached card (cache key = id). `listCards` builds the
  index once from the directory tree.

`scripts/validate-rule-cards.sh` enforces the schema offline; the library's
runtime errors restate the same constraints so a misconfigured card surfaces
the exact problem at the call site.

## Code Scanner

Single-rule dispatch at Phase 1: invoke the strategy declared in the card's
`detect` frontmatter field and produce a `Finding[]` containing every match
with its location and surrounding context.

### Contract

```
scan(files: string[], cards: Card[]) → Finding[]
```

`Finding` shape:

```
{
  rule_id: string,    // mirrors card.id
  file: string,       // absolute or repo-relative path
  line: number,       // 1-indexed line of the anti-pattern's anchor
  severity: "Blocker" | "Friction" | "Optimization",
  snippet: string,    // the offending line, trimmed
  context: string,    // ~5 lines around the snippet (2 before, the line, 2 after)
}
```

### Dispatch by `detect`

- `regex` — compile the card's regex from its body's "Detection" section
  and apply it line-by-line. Each match becomes one Finding.
- `ast` — parse the file as TSX/JSX and walk the AST per the card's rule.
  Phase 1 ships no `ast` cards; the dispatcher must surface
  `unsupported detect: ast` if invoked rather than silently skipping.
- `llm-judge` — read each file, prompt the agent itself with the card body
  and the file content, and require a structured response listing each
  occurrence as `{ line, snippet, context }`. The card body's "Detection"
  section enumerates the trigger conditions the judge must check. Cache
  results per `(file_hash, rule_id)` for the duration of a single run so a
  re-prompt for the same file in the same scan reuses the prior verdict.

### Severity assignment

Read the card body's "Severity guidance" section. Use the declared default
(Friction for `effects/computing-derived-state`). Upgrade to Blocker when
the file path matches a hot-path heuristic — at Phase 1 this means any path
under `src/auth/`, `src/payment/`, `src/router/`, or any file whose name
matches `*Provider.tsx`, `*Layout.tsx`, `App.tsx`, `_app.tsx`, `route.tsx`.
Never downgrade.

## Issue Manager

Create-only at Phase 1. Re-runs duplicate; dedup arrives in Phase 3.

### Contract

```
createIssue(repo: string, label: string, finding: Finding) → URL
```

### Behavior

- `repo` is always the current working directory (`gh` resolves the GitHub
  repo from git remotes).
- `label` is always `react-audit:<finding.rule_id>` — e.g.
  `react-audit:effects/computing-derived-state`. Must be applied to the
  created issue.
- Title: `[react-audit] <finding.rule_id> at <basename(finding.file)>:<finding.line>`.
- Body: the full card body (verbatim), followed by an "## Occurrence"
  section with `<finding.file>:<finding.line>`, the severity, and the 5-line
  context block in a fenced TSX code block.
- Implementation: shell out to
  `gh issue create --title <title> --label <label> --body-file <tmpfile>`.
  No other GitHub interaction mechanism is permitted (no `curl`, no
  `WebFetch`, no Octokit, no `api.github.com` direct calls).
- Returns the URL printed by `gh issue create` on success. On `gh` failure,
  surface the stderr verbatim — do not retry (avoids creating a duplicate
  on transient failure).

## Smart Scan

Front step inserted in Phase 2b. Enumerates candidate files via
`git ls-files`, applies the canonical exclusion list **before any other
logic runs**, then either proceeds immediately or asks the user to confirm
the scope when the post-exclusion count meets the documented threshold.

### Contract

```
enumerateScanTargets() → string[]
```

The returned array is the file set the Code Scanner is permitted to read.
Files outside this set are never opened by `scan(...)`, regardless of how
they appear on disk.

### Exclusion list (canonical)

```
node_modules/
dist/
build/
.next/
coverage/
**/*.test.*
**/*.stories.*
```

Applied to the output of `git ls-files '*.tsx' '*.jsx'` unconditionally —
exclusions are evaluated **before** the threshold check, so excluded files
never count toward the threshold and never enter a prompt-selected subset.
The list is mirrored verbatim in the `Configuration` section so a reader
can confirm parity at a glance.

### Configuration

#### Threshold

```
SMART_SCAN_THRESHOLD = 50
```

Single source of truth. Adjust here; the Workflow and Smart Scan sections
reference this constant by name rather than hardcoding the value. Lowering
the constant makes the prompt fire on smaller repos; raising it lets
larger repos scan silently.

#### Exclusion list (mirror)

```
node_modules/
dist/
build/
.next/
coverage/
**/*.test.*
**/*.stories.*
```

Must match the canonical list above byte-for-byte. The validator does not
yet enforce parity programmatically (Phase 2b ships the lists in lockstep
and the schema check arrives with the broader rule-card validator
refactor in a later phase) but a drifted copy should be treated as a
SKILL.md bug.

### Dispatch order

1. `candidates = git ls-files '*.tsx' '*.jsx'`
2. `filtered = candidates \ exclusion_list` — exclusions strip
   `node_modules/`, `dist/`, `build/`, `.next/`, `coverage/`,
   `**/*.test.*`, `**/*.stories.*` paths. Excluded files are dropped and
   never re-considered.
3. If `len(filtered) < SMART_SCAN_THRESHOLD` → return `filtered` and log
   `smart-scan: <N> files, below threshold, scanning all`.
4. Otherwise → group `filtered` by top-level directory, show the user a
   prompt of the form:

   ```
   <N> matching files found (threshold: 50). Select directories to scan:
     [a] src/components/   15 files
     [b] src/features/auth/   15 files
     [c] src/features/billing/   15 files
     [d] src/routes/   15 files
     [all] accept all   [none] reject all   [comma-separated letters] subset
   ```

   Accept the user's selection (`all`, `none`, or a subset). Log the
   selected directory groups and the resulting file count as
   `smart-scan: <N> files across <K> groups, scanning <M>` before the
   scan begins.
5. Return the selected file set. If the user picks `none` the returned
   set is empty and the workflow short-circuits with `0 findings`.

### Behavior

- `git ls-files` is invoked from the repo root. Untracked TSX/JSX files
  are intentionally not scanned — they are by definition not part of the
  reviewed code surface, and including them would surface noise from
  scratch files and IDE drafts.
- The exclusion list is applied via path-prefix match
  (`node_modules/`, `dist/`, `build/`, `.next/`, `coverage/`) and glob
  match (`**/*.test.*`, `**/*.stories.*`). The two mechanisms are
  intentionally separate to keep both cheap and unambiguous.
- The prompt is interactive — the skill blocks until the user responds.
  In automation contexts where no user is present the skill should fail
  loudly rather than silently fall through to "accept all"; Phase 2b
  does not ship a `--yes` flag.
- The selected scope is always logged before the Code Scanner runs, even
  on the below-threshold path (the log line confirms which file count
  flowed into the scan). This makes the audit reproducible from logs
  alone.

## Acceptance Checklist (Phase 2b)

Inherits the Phase 2a multi-rule-dispatch checks and layers on the Smart
Scan front-step checks introduced by issue #4:

- [ ] `listCards("effects")` returns every shipping `effects/` card listed
      in `references/cards/index.md` (eleven at Phase 2a)
- [ ] `scan(seeded_p2a_fixture_files, cards)` produces exactly eleven
      Findings — one per shipping card, anchored at the seeded fixture's
      `useEffect` block
- [ ] `scan(clean_fixture_files, cards)` produces zero Findings
- [ ] Each `createIssue` invocation labels with
      `react-audit:" + finding.rule_id` and embeds the matched card's body
      verbatim in the issue body
- [ ] LLM-judge calls are cached per `(file_hash, rule_id)` within a single
      run so a re-prompt for the same file × rule reuses the prior verdict
- [ ] No call to `curl`, `WebFetch`, `@octokit`, or `api.github.com` is made
      anywhere in the skill's execution path
- [ ] `enumerateScanTargets()` returns immediately (no prompt) when the
      post-exclusion file count is below `SMART_SCAN_THRESHOLD`
- [ ] `enumerateScanTargets()` groups files by top-level directory and
      prompts the user with per-group counts when the post-exclusion file
      count is at or above `SMART_SCAN_THRESHOLD`
- [ ] The prompt accepts `all`, `none`, and comma-separated letter subsets;
      the resulting file set matches the user's selection
- [ ] A `smart-scan: <N> files ...` log line is emitted before the Code
      Scanner runs, on both the below-threshold and above-threshold paths
- [ ] Every path under `node_modules/`, `dist/`, `build/`, `.next/`,
      `coverage/`, `**/*.test.*`, `**/*.stories.*` is dropped before the
      threshold check; the Code Scanner never opens these files
- [ ] `SMART_SCAN_THRESHOLD` is declared as a named constant in
      `## Smart Scan → ### Configuration` so it can be adjusted without
      editing the Workflow or dispatch prose
