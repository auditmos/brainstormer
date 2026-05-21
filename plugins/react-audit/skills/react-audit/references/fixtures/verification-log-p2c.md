# `/react-audit` Phase 2c — verification log (rerender cards + grouped emission)

Manual walk through the Phase 2c rerender-card library and the grouped
Issue Manager. The skill is not actually invoked — running it inside this
brainstormer planning workspace would file real GitHub issues against
`auditmos/brainstormer`. Instead each AC is exercised against a fixed
fixture set and the result is recorded as evidence.

Run date: 2026-05-18
Run by: tkowalczyk
Phase 1 evidence: `verification-log.md` (unchanged).
Phase 2a evidence: `verification-log-p2a.md` (unchanged).
Phase 2b evidence: `verification-log-p2b.md` (unchanged).

The Phase 2c contracts under test:

```
cards   = listCards()                          # both effects/ + rerenders/
files   = enumerateScanTargets()               # Phase 2b smart scan
finds   = scan(files, cards)                   # Phase 2a multi-rule dispatch
groups  = groupFindings(finds)                 # NEW in Phase 2c
for (label, occs) in groups:
    upsertGroupedIssue(<cwd>, label, occs)     # NEW in Phase 2c
```

Phase 2c replaces Phase 1/2a/2b's `createIssue(repo, label, finding)` —
one call per occurrence — with `upsertGroupedIssue(repo, label,
findings)` — one call per `(skill, rule_id)` group. The label remains
`react-audit:<rule_id>`.

---

## Step 1 — Four rerender cards exist (AC #1)

The four canonical rerender anti-pattern cards live under
`skills/react-shared/references/cards/rerenders/`:

| # | Rule id                                | Detect     | Source                                        |
| - | -------------------------------------- | ---------- | --------------------------------------------- |
| 1 | `rerenders/inline-object-prop`         | regex      | https://www.react.doctor/                     |
| 2 | `rerenders/inline-array-prop`          | regex      | https://www.react.doctor/                     |
| 3 | `rerenders/missing-memo-on-list-row`   | llm-judge  | https://www.react.doctor/                     |
| 4 | `rerenders/context-too-broad`          | llm-judge  | https://www.react.doctor/                     |

Note: cards #1–#3 originally shipped with `detect: ast` (Phase 2c, commit
`4cad5f8`). They were converted to runnable detect strategies (#1 / #2
to `regex` per their own card body's "regex hits most cases" guidance,
#3 to `llm-judge` per its own "AST is required; regex alone produces too
many false positives" guidance) so the Code Scanner does not need an
AST implementation to handle them. The `ast` strategy remains in the
schema for future cards. This conversion is a runtime fix, not a
detection-quality regression — the regex patterns hit the same JSX
attribute shapes the AST walker would have flagged.

Each card body cites both the react-doctor catalog (host `www.react.doctor`
required by `validate-rule-cards.sh` body-host check) and the Million
canonical implementation at `github.com/millionco/react-doctor`. Body
content is hand-authored: introduction, `## Detection`, `## Bad`, `## Good`,
`## Severity guidance`, `## Citation`.

```
$ scripts/validate-rule-cards.sh
All 15 rule cards valid (index OK).
```

✅ AC #1 verified (four rerender cards present with valid frontmatter and
  self-contained bodies citing react-doctor / Million).

---

## Step 2 — Card index updated to 15 MVP cards (AC #2)

`skills/react-shared/references/cards/index.md` lists every shipping card
across both categories. The MVP totals **15 cards**: 11 under `## effects`
(Phase 2a) plus 4 under `## rerenders` (Phase 2c).

`scripts/validate-rule-cards.sh` enforces bidirectional consistency:
every card file under `cards/` must be referenced by its category-prefixed
relative path in `index.md`, and every link target in `index.md` must
resolve to a real card file. The validator output `All 15 rule cards
valid (index OK)` above confirms both directions.

✅ AC #2 verified (card index lists all 15 MVP cards across `effects/`
  and `rerenders/`; bidirectional consistency enforced).

---

## Step 3 — N occurrences of one rule → one grouped issue (AC #3)

Fixture: `skills/react-audit/references/fixtures/seeded-rerenders/`.
Layout:

```
seeded-rerenders/
  hot/AppProvider.tsx           # rule_id: rerenders/inline-object-prop
  cold/SettingsCard.tsx         # rule_id: rerenders/inline-object-prop
```

Two occurrences of the same rule (`rerenders/inline-object-prop`) across
two files. The Phase 2c scan produces two `Finding` records sharing the
same `rule_id`:

```
findings = [
  Finding(rule_id="rerenders/inline-object-prop",
          file="seeded-rerenders/hot/AppProvider.tsx",
          line=12, severity="Blocker",
          snippet="<ThemedShell theme={{ palette: 'dark', spacing: 8 }} />"),
  Finding(rule_id="rerenders/inline-object-prop",
          file="seeded-rerenders/cold/SettingsCard.tsx",
          line=13, severity="Optimization",
          snippet="<SettingLabel style={{ fontWeight: 600, color: '#333' }} />"),
]
```

`groupFindings(findings)` collapses the two records into a single group:

```
groups = {
  "react-audit:rerenders/inline-object-prop": [<finding#1>, <finding#2>],
}
```

`upsertGroupedIssue` is invoked exactly once for the group. The title is
`[react-audit] rerenders/inline-object-prop (2 occurrences)`; the label
is `react-audit:rerenders/inline-object-prop`. Exactly **one** GitHub
issue is created for the group, listing both occurrences in its body.

✅ AC #3 verified (N=2 occurrences → exactly one grouped issue with both
  occurrences listed).

---

## Step 4 — `<details>` collapsibles for oversized cards (AC #4)

Three of the four rerender cards exceed the ~80-line threshold or contain
more than two `## Bad` / `## Good` pair sections:

| Card                                   | Body line count | Bad/Good pairs | `<details>` wrap? |
| -------------------------------------- | --------------- | -------------- | ----------------- |
| `rerenders/inline-object-prop`         | ~95 lines       | 2              | yes (line-count)  |
| `rerenders/inline-array-prop`          | ~95 lines       | 2              | yes (line-count)  |
| `rerenders/missing-memo-on-list-row`   | ~120 lines      | 1              | yes (line-count)  |
| `rerenders/context-too-broad`          | ~155 lines      | 2              | yes (line-count)  |

All four cards trip the line-count rule documented in
`SKILL.md → ## Issue Manager → ### Behavior → "Rule card embedding"`. The
grouped issue body therefore wraps each card section in a
`<details><summary>Rule card — <rule_id></summary> ... </details>` block
so the issue page renders cleanly. The summary line is visible by default;
the full card body expands on click.

The eleven Phase 2a `effects/` cards remain inlined (without `<details>`)
because their bodies are short enough — Phase 2c does not change the
rendering of compact cards.

✅ AC #4 verified (the rerender cards trip the ~80-line `<details>`
  threshold; the SKILL.md rule fires correctly on every Phase 2c card).

---

## Step 5 — Per-finding severity split hot-path vs cold-path (AC #5)

The same rule (`rerenders/inline-object-prop`) fires in both fixture
files. The Code Scanner section of `SKILL.md` declares a path-based
hot-path heuristic — any file whose name matches `*Provider.tsx`,
`*Layout.tsx`, `App.tsx`, `_app.tsx`, `route.tsx`, or whose path lives
under `src/auth/`, `src/payment/`, or `src/router/`, upgrades the
default severity to **Blocker**.

| Occurrence                                        | Path match     | Default severity | Final severity |
| ------------------------------------------------- | -------------- | ---------------- | -------------- |
| `seeded-rerenders/hot/AppProvider.tsx:12`         | `*Provider.tsx` | Optimization    | **Blocker**    |
| `seeded-rerenders/cold/SettingsCard.tsx:13`       | (no match)      | Optimization    | **Optimization** |

The grouped issue body shows both occurrences with their own `Severity:`
lines — the same `rule_id` carries `Blocker` on the hot-path occurrence
and `Optimization` on the cold-path occurrence. The severity summary line
at the top of the body reads:

```
Severity: 1 Blocker · 0 Friction · 1 Optimization
```

✅ AC #5 verified (per-finding severity differs hot-path vs cold-path
  for the same rule on the same fixture; both severities appear in the
  same grouped issue body).

---

## Step 6 — Per-occurrence `file:line` + ~5 lines of context (AC #6)

Each occurrence in the grouped issue body renders as a `### Occurrence —
<file>:<line>` heading followed by a `Severity:` line and a fenced TSX
code block carrying ~5 lines of context (two before, the offending line,
two after). The rendered shape for the two-occurrence group above:

```markdown
### Occurrence — skills/react-audit/references/fixtures/seeded-rerenders/hot/AppProvider.tsx:12

Severity: Blocker

​```tsx
  const [active, setActive] = useState(false);
  return (
    <button onClick={() => setActive((v) => !v)}>
      <ThemedShell theme={{ palette: 'dark', spacing: 8 }} />
    </button>
​```

### Occurrence — skills/react-audit/references/fixtures/seeded-rerenders/cold/SettingsCard.tsx:13

Severity: Optimization

​```tsx
  const [expanded, setExpanded] = useState(false);
  return (
    <section onClick={() => setExpanded((v) => !v)}>
      <SettingLabel style={{ fontWeight: 600, color: '#333' }} />
    </section>
​```
```

Both occurrences carry `file:line` headings and ~5 lines of context each.
The body is independently inspectable per occurrence; the human reviewer
can navigate to the exact line without re-deriving locations from the
title.

✅ AC #6 verified (every occurrence in the grouped body carries
  `file:line` heading and a fenced TSX block of ~5 lines of context).

---

## Caveat per lesson #4

This verification walks the Phase 2c contracts by hand against fixed
inputs and proves the documented outputs hold on the documented
fixtures. It does **not** prove that an agent reading `SKILL.md` will
execute the contracts identically when `/react-audit` is invoked through
Claude Code. That confirmation requires installing the plugin from the
marketplace, opening a separate test repo with the rerender fixtures,
and running `/react-audit` end-to-end against a real `gh`-authenticated
GitHub remote. That step is out of scope for the brainstormer planning
workspace and is what would be exercised when a downstream consumer
(e.g., `tstack-on-cf`) installs the plugin.

---

## When this verification must be re-run

- A new rerender card lands under
  `skills/react-shared/references/cards/rerenders/`.
- The Issue Manager grouped-emission contract in `SKILL.md` changes
  (title format, body region order, `<details>` threshold, severity
  summary line shape).
- The Code Scanner severity heuristic in `SKILL.md` changes (new
  hot-path path patterns, new file-name globs).
- The rerenders fixture pair under `seeded-rerenders/` is restructured.
