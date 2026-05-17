# `/react-audit` Phase 2a — verification log (11-card dispatch)

Manual walk through the multi-rule scan path. The skill is not actually
invoked — running it against this brainstormer planning workspace would
file 11 real GitHub issues against `auditmos/brainstormer`. Instead each
card × fixture pair is walked by hand exactly as `SKILL.md` specifies and
the results are frozen here as evidence for the Phase 2a acceptance
criteria.

Run date: 2026-05-17
Run by: tkowalczyk
Phase 1 evidence: `verification-log.md` (unchanged; the P1 fixture
`seeded/UserCard.tsx` was extended in P2a with a `// rule_id:` header on
line 2 to pair with the new fixture-coverage check — `useEffect` remains
on line 13, all P1 line-number assertions hold).

---

## Step 1 — Rule Card Library

`listCards("effects")` reads `skills/react-shared/references/cards/index.md`
and returns the eleven cards under `effects/`:

1. `effects/computing-derived-state`
2. `effects/transforming-data-for-render`
3. `effects/caching-expensive-computation`
4. `effects/resetting-all-state-on-prop-change`
5. `effects/adjusting-state-on-prop-change`
6. `effects/sharing-logic-between-handlers`
7. `effects/sending-post-request`
8. `effects/fetching-data`
9. `effects/chains-of-computations`
10. `effects/initializing-application`
11. `effects/notifying-parent-state-changes`

`scripts/validate-rule-cards.sh` confirms the schema and index↔file
bidirectional consistency:

```
$ scripts/validate-rule-cards.sh
All 11 rule cards valid (index OK).
```

Each card declares `detect: llm-judge`. The detection criteria live in
the body's `## Detection` section and are evaluated by the agent itself
at scan time.

✅ AC #1 verified (11 cards present, frontmatter valid).
✅ AC #2 verified (index.md lists every shipping card; bidirectional
  consistency enforced by validator).
✅ AC #3 verified (`validate-rule-cards.sh` exits 0; all cards parse).

---

## Step 2 — Code Scanner

`scan(seeded_fixture_files, listCards("effects"))` dispatches the eleven
cards across the eleven seeded fixtures under
`skills/react-audit/references/fixtures/seeded/`. Each fixture carries a
`// rule_id:` header that pairs it with exactly one card. Per-fixture
detection produces exactly one `Finding`:

| # | Rule id                                            | Fixture file                  | Anchor line | Severity   |
| - | -------------------------------------------------- | ----------------------------- | ----------- | ---------- |
| 1 | effects/computing-derived-state                    | seeded/UserCard.tsx           | 13          | Friction   |
| 2 | effects/transforming-data-for-render               | seeded/TodoList.tsx           | 24          | Friction   |
| 3 | effects/caching-expensive-computation              | seeded/ReportTable.tsx        | 26          | Friction   |
| 4 | effects/resetting-all-state-on-prop-change         | seeded/ProfilePage.tsx        | 13          | Friction   |
| 5 | effects/adjusting-state-on-prop-change             | seeded/SelectableList.tsx     | 16          | Friction   |
| 6 | effects/sharing-logic-between-handlers             | seeded/ProductPage.tsx        | 28          | Friction   |
| 7 | effects/sending-post-request                       | seeded/RegistrationForm.tsx   | 9           | Friction   |
| 8 | effects/fetching-data                              | seeded/FetchUserList.tsx      | 12          | Friction   |
| 9 | effects/chains-of-computations                     | seeded/Game.tsx               | 14          | Friction   |
| 10 | effects/initializing-application                  | seeded/App.tsx                | 8           | Blocker    |
| 11 | effects/notifying-parent-state-changes            | seeded/Toggle.tsx             | 11          | Friction   |

Anchor lines were verified by re-counting each fixture against the line
of the `useEffect` invocation triggering the rule's detection criteria.

Severity assignment notes:

- Every card declares `Friction` as its default. The scanner upgrades to
  `Blocker` only when the file path matches a hot-path heuristic (per
  Phase 1 `SKILL.md`: `src/auth/`, `src/payment/`, `src/router/`, or
  filenames `*Provider.tsx`, `*Layout.tsx`, `App.tsx`, `_app.tsx`,
  `route.tsx`).
- `seeded/App.tsx` matches `App.tsx` → upgraded to **Blocker**. The
  `initializing-application` card explicitly endorses this promotion
  ("Always promote in `App.tsx`/`_app.tsx`/`main.tsx` if a payment or
  auth client is initialized inside the effect").
- No other fixture path matches a hot-path heuristic. Severity stays at
  the card-declared default for ten of the eleven findings.

Each Finding carries the six mandatory fields: `rule_id`, `file`,
`line`, `severity`, `snippet`, and `context` (the five lines surrounding
the anchor — two before, the anchor, two after).

### LLM-judge caching across the 11-card dispatch

The Code Scanner is run once per rule × file. The cache key is the
literal pair `(file_hash, rule_id)`. Two consequences:

- A second card scanning the same fixture (rare but possible if a
  fixture genuinely matched two rules) would issue a *separate*
  llm-judge call — different `rule_id`. The cache rejects only the
  exact `(file_hash, rule_id)` repeat.
- A re-prompt for the same file × same rule within the same run reuses
  the prior verdict deterministically.

In this Phase 2a fixture set, every fixture is paired 1-to-1 with its
rule (enforced by the `// rule_id:` header convention and the
fixture-coverage check in `validate-react-audit.sh`). No file × rule
combination repeats inside one run, so each fixture triggers exactly one
llm-judge call. The cache property *holds vacuously* over this fixture
set but is documented for the realistic case where a single repo file
under audit will be evaluated against all eleven cards.

✅ AC #4 verified (11 findings produced — exactly one per shipping card —
  on a fixture seeded with one occurrence of each rule).
✅ AC #5 verified (cache key `(file_hash, rule_id)` documented in the
  Phase 1 `SKILL.md` contract and restated here; cache holds across the
  Phase 2a dispatch).

---

## Step 3 — Issue Manager

For each of the eleven Findings the Issue Manager invokes
`gh issue create` once. The full template (per Phase 1 SKILL.md):

```bash
gh issue create \
  --title "[react-audit] <rule_id> at <basename(file)>:<line>" \
  --label "react-audit:<rule_id>" \
  --body-file /tmp/react-audit-<rule_id-slugified>-001.md
```

Concretely, the eleven invocations would be:

```bash
gh issue create --title "[react-audit] effects/computing-derived-state at UserCard.tsx:13"            --label "react-audit:effects/computing-derived-state"            ...
gh issue create --title "[react-audit] effects/transforming-data-for-render at TodoList.tsx:24"      --label "react-audit:effects/transforming-data-for-render"      ...
gh issue create --title "[react-audit] effects/caching-expensive-computation at ReportTable.tsx:26"  --label "react-audit:effects/caching-expensive-computation"    ...
gh issue create --title "[react-audit] effects/resetting-all-state-on-prop-change at ProfilePage.tsx:13" --label "react-audit:effects/resetting-all-state-on-prop-change" ...
gh issue create --title "[react-audit] effects/adjusting-state-on-prop-change at SelectableList.tsx:16"  --label "react-audit:effects/adjusting-state-on-prop-change" ...
gh issue create --title "[react-audit] effects/sharing-logic-between-handlers at ProductPage.tsx:28"     --label "react-audit:effects/sharing-logic-between-handlers" ...
gh issue create --title "[react-audit] effects/sending-post-request at RegistrationForm.tsx:9"           --label "react-audit:effects/sending-post-request" ...
gh issue create --title "[react-audit] effects/fetching-data at FetchUserList.tsx:12"                    --label "react-audit:effects/fetching-data" ...
gh issue create --title "[react-audit] effects/chains-of-computations at Game.tsx:14"                    --label "react-audit:effects/chains-of-computations" ...
gh issue create --title "[react-audit] effects/initializing-application at App.tsx:8"                    --label "react-audit:effects/initializing-application" ...
gh issue create --title "[react-audit] effects/notifying-parent-state-changes at Toggle.tsx:11"          --label "react-audit:effects/notifying-parent-state-changes" ...
```

Each body file embeds the full card body verbatim followed by an
`## Occurrence` section with file:line, severity, and the 5-line code
context block in a fenced TSX block. Phase 2a still files one issue per
occurrence; grouping arrives in Phase 2c (re-runs may produce duplicates
— dedup arrives in Phase 3).

✅ Issue Manager contract from Phase 1 unchanged; eleven separate
  invocations produce eleven labeled issues. The clean-fixture path
  (zero findings → zero invocations) is unaffected.

---

## Caveat per lesson #4

This verification walks the Phase 2a contracts by hand against fixed
inputs and proves the documented outputs hold on the documented fixtures.
It does **not** prove that an agent reading `SKILL.md` will execute the
contracts identically when `/react-audit` is invoked through Claude
Code. That confirmation requires installing the plugin from the
marketplace, opening a separate test repo seeded with the eleven
fixtures, and running `/react-audit` end-to-end against a real
`gh`-authenticated GitHub remote. That step is out of scope for the
brainstormer planning workspace and is what would be exercised when a
downstream consumer (e.g., `tstack-on-cf`) installs the plugin.

---

## When this verification must be re-run

- A card body's `## Detection` section changes (criteria drift).
- A fixture file changes (line numbers may shift; magic header may move).
- The Code Scanner contract in `SKILL.md` changes.
- The Issue Manager body-rendering rules in `SKILL.md` change.
- A new card is added to the library (extend the table; verify the new
  pair contributes one Finding to the fixture-set scan).
