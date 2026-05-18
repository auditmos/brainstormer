---
name: react-audit
description: Audit a React/TSX repository for React anti-patterns by loading rule cards from the brainstormer card library, scanning source files via each card's declared detect strategy, and filing one grouped GitHub issue per `(skill, rule_id)` via the `gh` CLI. Phase 2c collapses findings — every occurrence of the same rule lands in a single issue body with per-occurrence `file:line`, ~5 lines of context, and per-finding severity — and adds the four canonical rerender cards from react-doctor / Million on top of Phase 2a's 11 effects cards (15 MVP total). Phase 2b's smart-scan front step (`git ls-files`, canonical exclusion list, threshold prompt at `SMART_SCAN_THRESHOLD=50`) stays unchanged. Manual invocation only — no hooks. Triggers on `/react-audit`, "audit this repo for react anti-patterns", "scan for useEffect or re-render anti-patterns", "run a react audit". Skip design questions, scaffolding, or audits of non-React frameworks (Vue, Svelte, Solid).
---

# React Audit — Phase 2c (rerender cards + grouped emission)

Manual-invocation skill that loads every shipping card from the
brainstormer card library, scans the current repository for occurrences of
each anti-pattern, and files **one grouped GitHub issue per
`(skill, rule_id)`** — every occurrence of the same rule collapses into a
single issue whose body lists each finding with its own `file:line`,
context block, and contextually-assigned severity. Phase 2c ships the
four canonical rerender cards from
[www.react.doctor](https://www.react.doctor/) /
[millionco/react-doctor](https://github.com/millionco/react-doctor) on top
of the Phase 2a 11-card effects library from
[react.dev/learn/you-might-not-need-an-effect](https://react.dev/learn/you-might-not-need-an-effect)
(15 MVP cards total). The Phase 2b smart-scan front step (candidate
enumeration, canonical exclusion list, interactive threshold prompt)
remains unchanged. Dedup / re-run lifecycle arrives in Phase 3.

## Usage

```
/react-audit
```

The skill takes no arguments. It loads every shipping card via
`listCards()` (no category filter — Phase 2c dispatches across both
`effects/` and `rerenders/`, fifteen cards total), scans every tracked
`*.tsx`/`*.jsx` file in the current repo, groups findings by
`(skill, rule_id)`, and creates one issue per group.

## Scope Boundaries (Phase 2c)

- **All shipping cards across `effects/` and `rerenders/`** — Phase 2c
  loads every card listed in `skills/react-shared/references/cards/index.md`
  regardless of category. The MVP totals fifteen cards (eleven effects +
  four rerenders). Adding a new card to the index automatically extends
  the scan; no skill-side change required.
- **Grouped emission** — findings collapse by `(skill, rule_id)` and ship
  as one issue per group. The body lists every occurrence under one card
  embedding, with per-occurrence `file:line`, ~5 lines of context, and
  per-finding severity. Phase 2c replaces Phase 1/2a/2b's issue-per-
  occurrence model.
- **Smart scan front step** — Phase 2b's `enumerateScanTargets()` runs
  unchanged ahead of the scan. Candidate files come from `git ls-files`;
  the canonical exclusion list is applied unconditionally; the threshold
  prompt fires only when the post-exclusion count meets
  `SMART_SCAN_THRESHOLD`.
- **Create-only** — no dedup, no in-place body update, no regression
  backlinking. Re-running creates duplicate grouped issues. Dedup arrives
  in Phase 3.
- **`gh` CLI only** — no `curl`, no `WebFetch`, no Octokit. All GitHub
  interaction goes through the `gh` binary already configured in the user's
  shell.

## Workflow

1. Resolve the rule set: `cards = listCards()`. The Rule Card Library
   reads `references/cards/index.md` and returns every shipping card —
   Phase 2c returns fifteen cards (eleven `effects/` + four `rerenders/`).
2. Enumerate scan targets via Smart Scan:
   `files = enumerateScanTargets()`. The module runs `git ls-files`, applies
   the canonical exclusion list, then either returns the file set
   immediately (count below `SMART_SCAN_THRESHOLD`) or prompts the user to
   accept-all / reject-all / select a subset of directory groups (count at
   or above the threshold). The selected scope is logged before step 3.
3. Produce findings: `findings = scan(files, cards)`. The scanner dispatches
   each card by its declared `detect` strategy. Severity is assigned
   per-finding contextually via the hot-path heuristic in the Code Scanner
   section — the same `rule_id` can appear at different severities in the
   same scan.
4. Group findings by `(skill, rule_id)`:
   `groups = groupFindings(findings)`. Each group's key is the
   `react-audit:<rule_id>` label; the value is the list of every
   occurrence (preserving severity per-finding).
5. For each group, file one issue:
   `upsertGroupedIssue(repo=<cwd>, label="react-audit:" + rule_id, findings)`.
   The body embeds the matched card once, then lists each occurrence with
   its own `file:line`, severity, and ~5-line context block.
6. Print every created issue URL to stdout for the user.

If `findings` is empty, exit with a single-line summary `0 findings` and
create no issues. If all rules return zero findings, no issues are filed
at all; partial-rule emptiness simply means the empty rule contributes
no group.

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

Phase 2c collapses findings by `(skill, rule_id)` and emits one issue per
group. Create-only — re-runs still duplicate; dedup / re-run lifecycle
arrives in Phase 3.

### Contract

```
groupFindings(findings: Finding[]) → Map<label, Finding[]>
upsertGroupedIssue(repo: string, label: string, findings: Finding[]) → URL
```

`groupFindings` keys each group by `react-audit:<rule_id>` — the same
shape as the `label` argument to `upsertGroupedIssue`. The map preserves
the per-finding severity assigned by the Code Scanner; the Issue Manager
never recomputes severity.

### Behavior

- `repo` is always the current working directory (`gh` resolves the GitHub
  repo from git remotes).
- `label` is always `react-audit:<rule_id>` — e.g.
  `react-audit:rerenders/inline-object-prop`. One label per group; the
  same label is applied to every issue created for that `(skill, rule_id)`
  pair.
- Title: `[react-audit] <rule_id> (<N> occurrence<s>)` where `N =
  findings.length`. Example: `[react-audit] rerenders/inline-object-prop
  (4 occurrences)`. The single-occurrence title is allowed to read
  `(1 occurrence)`; do not silently drop the count.
- Body shape — three regions, in order:

  1. **Rule card embedding.** The card body verbatim, identical to how
     Phase 1/2a/2b rendered it. When the card body exceeds ~80 lines
     *or* contains more than two `## Bad` / `## Good` pair sections, the
     full card is wrapped in a single `<details>` block whose
     `<summary>` reads `Rule card — <rule_id>` and the card body lives
     inside. Cards under the threshold are inlined without `<details>`
     so the high-signal short cards stay easy to skim.
  2. **Severity summary line.** A single line of the form
     `Severity: <count Blocker> Blocker · <count Friction> Friction ·
     <count Optimization> Optimization` so the reader sees the per-finding
     severity split at a glance without scrolling through occurrences.
  3. **Occurrence list.** One `### Occurrence — <file:line>` heading per
     finding, each followed by:
     - a `Severity:` line carrying that occurrence's per-finding severity
       (so the same `rule_id` can list a `Blocker` and a `Friction`
       occurrence in the same body — see Code Scanner §Severity
       assignment for how the value is determined);
     - the ~5-line context block (two lines before, the offending line,
       two lines after) in a fenced TSX code block. The fenced block uses
       `tsx` as the language tag so syntax highlighting works on
       github.com.

  When the occurrence count exceeds 10, the occurrence list is itself
  wrapped in a `<details>` whose `<summary>` reads `<N> occurrences` —
  the per-occurrence file:line headings stay visible inside, but the
  block is collapsed by default so the issue page renders cleanly on
  scan-heavy days.

- Implementation: shell out to
  `gh issue create --title <title> --label <label> --body-file <tmpfile>`.
  One invocation per `(skill, rule_id)` group. No other GitHub
  interaction mechanism is permitted (no `curl`, no `WebFetch`, no
  Octokit, no `api.github.com` direct calls).
- Returns the URL printed by `gh issue create` on success. On `gh`
  failure, surface the stderr verbatim — do not retry (avoids creating a
  duplicate grouped issue on transient failure).

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

## Acceptance Checklist (Phase 2c)

Inherits the Phase 2a multi-rule-dispatch checks and the Phase 2b
smart-scan front-step checks, and layers on the rerender-cards +
grouped-emission checks introduced by issue #5:

- [ ] `listCards()` returns every shipping card listed in
      `references/cards/index.md` — fifteen at Phase 2c (eleven `effects/`
      + four `rerenders/`)
- [ ] All four canonical rerender cards
      (`rerenders/inline-object-prop`, `rerenders/inline-array-prop`,
      `rerenders/missing-memo-on-list-row`, `rerenders/context-too-broad`)
      exist with valid frontmatter and self-contained bodies citing
      react-doctor / Million sources
- [ ] `scan(seeded_p2a_fixture_files, cards)` continues to produce
      eleven `effects/` Findings (Phase 2a contract preserved)
- [ ] `scan(seeded_rerenders_fixture_files, cards)` produces multiple
      occurrences of at least one `rerenders/` rule across both hot-path
      and cold-path files, so the per-finding severity split is
      observable
- [ ] `groupFindings(findings)` collapses every occurrence sharing a
      `(skill, rule_id)` pair into a single group keyed by
      `react-audit:<rule_id>`
- [ ] `upsertGroupedIssue` is called once per group; on a fixture with N
      occurrences of the same rule, exactly one issue is created with N
      occurrences listed in the body
- [ ] The issue body wraps the card section in `<details>` when the card
      body exceeds ~80 lines or contains more than two `## Bad`/`## Good`
      pair sections
- [ ] The issue body's severity summary line and per-occurrence
      `Severity:` lines reflect the per-finding severity assigned by the
      Code Scanner — the same `rule_id` can show a `Blocker` occurrence
      and a `Friction` occurrence in the same grouped body
- [ ] Each occurrence in the grouped body shows a `### Occurrence —
      <file:line>` heading followed by a fenced TSX code block with ~5
      lines of context
- [ ] LLM-judge calls remain cached per `(file_hash, rule_id)` within a
      single run
- [ ] No call to `curl`, `WebFetch`, `@octokit`, or `api.github.com` is
      made anywhere in the skill's execution path
- [ ] `enumerateScanTargets()` continues to return immediately when the
      post-exclusion count is below `SMART_SCAN_THRESHOLD` and to prompt
      with directory groups at or above the threshold
- [ ] The Phase 2b canonical exclusion list (`node_modules/`, `dist/`,
      `build/`, `.next/`, `coverage/`, `**/*.test.*`, `**/*.stories.*`)
      and `SMART_SCAN_THRESHOLD = 50` declaration both remain in place
      unchanged
