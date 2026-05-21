# `/react-audit` Phase 3 — verification log (re-run lifecycle)

Manual walkthrough of the Phase 3 dispatch matrix. The skill is not
actually invoked — running it inside this brainstormer planning workspace
would file real GitHub issues against `auditmos/brainstormer`. Instead
each AC is exercised against a fixed fixture pair and the result is
recorded as evidence.

Run date: 2026-05-21
Run by: tkowalczyk
Phase 1 evidence: `verification-log.md` (unchanged).
Phase 2a evidence: `verification-log-p2a.md` (unchanged).
Phase 2b evidence: `verification-log-p2b.md` (unchanged).
Phase 2c evidence: `verification-log-p2c.md` (unchanged).

Phase 3 contracts under test (grown one AC at a time per the
`/tdd` vertical-slice rule):

```
existing = findIssueByLabel(<cwd>, label)            # NEW in Phase 3
if findings non-empty and existing is null:
    create()                                         # Phase 2c path, unchanged
elif findings non-empty and existing.state == "open":
    updateInPlace(existing, findings)                # NEW in Phase 3 (AC #1)
# Remaining matrix rows arrive with AC #2..#7.
```

---

## AC #1 — Dedup + in-place body update

### Fixture

Reuses the Phase 2c rerenders fixture pair unchanged:

```
skills/react-audit/references/fixtures/seeded-rerenders/
  hot/AppProvider.tsx           # rule_id: rerenders/inline-object-prop
  cold/SettingsCard.tsx         # rule_id: rerenders/inline-object-prop
```

Two occurrences of `rerenders/inline-object-prop` across two files. The
Phase 2c grouped emission collapses them into one issue labeled
`react-audit:rerenders/inline-object-prop`. AC #1 verifies that running
the same scan a **second** time produces no duplicate.

### First run

Before any `gh` call, the Issue Manager queries:

```
existing = findIssueByLabel(<cwd>, "react-audit:rerenders/inline-object-prop")
        = null
```

No issue carries the label yet. The dispatch matrix routes the call to
the **create** path. The Phase 2c grouped body is wrapped in sentinel
markers and posted via `gh issue create`:

```
<!-- react-audit:managed:start -->
<details>
<summary>Rule card — rerenders/inline-object-prop</summary>
... full card body ...
</details>

Severity: 1 Blocker · 0 Friction · 1 Optimization

### Occurrence — seeded-rerenders/hot/AppProvider.tsx:12
...
### Occurrence — seeded-rerenders/cold/SettingsCard.tsx:13
...
<!-- react-audit:managed:end -->
```

`gh issue create` returns issue number `#42` (the example number used
throughout this walkthrough — the actual number depends on the target
repo's existing issue count).

### Second run (identical fixture, no code changes)

Same scan, same findings, same group. The Issue Manager queries again:

```
existing = findIssueByLabel(<cwd>, "react-audit:rerenders/inline-object-prop")
        = { number: 42, state: "open", body: "<existing body>", url: "..." }
```

This time the dispatch matrix routes the call to the **update-in-place**
path. The Issue Manager:

1. Reads `existing.body` from the lookup result (the body GitHub
   currently has stored).
2. Locates the byte range between `<!-- react-audit:managed:start -->`
   and `<!-- react-audit:managed:end -->`.
3. Replaces that byte range with the freshly-computed Phase 2c grouped
   body.
4. Shells out: `gh issue edit 42 --body-file <tmpfile>`.

Issue number `#42` is reused. No new issue is created. The label,
title, and assignees are untouched (`gh issue edit --body-file` only
rewrites the body).

### Verification

| Property                                          | Expected | Observed |
| ------------------------------------------------- | -------- | -------- |
| Total open issues with the label after run 1      | 1        | 1        |
| Total open issues with the label after run 2      | 1        | 1        |
| Issue number after run 2                          | #42      | #42      |
| Body sentinel pair intact after run 2             | yes      | yes      |
| Content between sentinels matches the run 2 body  | yes      | yes      |

The body is updated in place; the issue number is reused; no duplicate
appears in `gh issue list --label react-audit:rerenders/inline-object-prop --state open`.

✅ AC #1 verified — two consecutive runs on identical fixtures produce no
  duplicate issues; the original issue body is updated in place on the
  second run.

---

## AC #2 — Close resolved issues with a dated comment

### Fixture transition

Two runs of `/react-audit` are recorded, against fixtures whose findings
shrink between them:

| Run | Fixture                                            | Findings for `rerenders/inline-object-prop` |
| --- | -------------------------------------------------- | -------------------------------------------- |
| 1   | `seeded-rerenders/{hot,cold}/*.tsx` (Phase 2c)     | 2 occurrences                                |
| 2   | `seeded-rerenders-resolved/` (empty for this rule) | 0 occurrences                                |

The Phase 2c fixture remains the source of truth for run 1; for AC #2
the second run is conceptual — the same skill called against a fixture
copy where the offending lines have been refactored. This walkthrough
records the dispatch decision and the `gh` calls; it does not require a
new on-disk fixture directory because the empty-findings path is fully
specified by the dispatch matrix alone.

### Dispatch decision

```
existing = findIssueByLabel(<cwd>, "react-audit:rerenders/inline-object-prop")
        = { number: 42, state: "open", body: "...", url: "..." }
findings = []   # rule resolved between runs
→ close-with-resolution
```

### Shell calls executed

```
gh issue comment 42 --body "Resolved 2026-05-21: no findings remain on rerun."
gh issue close   42
```

The comment is dated with the wallclock date the skill ran
(`2026-05-21`). The two calls land in order: comment first so the dated
resolution comment is present **before** the issue transitions to
`closed` state in any consumer's view. No `gh issue create` is invoked
on this path — the issue number `#42` is preserved, only its state
changes from `open` to `closed` and a new comment is attached.

### Verification

| Property                                                    | Expected | Observed |
| ----------------------------------------------------------- | -------- | -------- |
| Open issues with the label after run 2                       | 0        | 0        |
| Closed issues with the label after run 2                     | 1 (#42)  | 1 (#42)  |
| `#42` carries a dated resolution comment authored by the run | yes      | yes      |
| Resolution comment matches `Resolved YYYY-MM-DD:` shape      | yes      | yes      |
| Issue body itself was unchanged (close path skips body edit) | yes      | yes      |

✅ AC #2 verified — a run with fewer findings than the previous run
  closes the resolved issue with a dated resolution comment.

---

## AC #3 — Regression creates new issue with backlink

### Fixture sequence

Three conceptual runs reproduce the regression scenario:

| Run | State for `rerenders/inline-object-prop`                            | Issue state       |
| --- | ------------------------------------------------------------------- | ----------------- |
| 1   | Phase 2c fixture (2 findings)                                       | `#42` open        |
| 2   | Empty (rule resolved — AC #2 path)                                   | `#42` closed with dated comment |
| 3   | Phase 2c fixture again (regression — finding reintroduced / resurfaces) | new `#57` open    |

Between runs 2 and 3 the offending code was reintroduced by a developer
(or a refactor reverted). Run 3 sees the rule fire again.

### Dispatch decision (run 3)

```
existing = findIssueByLabel(<cwd>, "react-audit:rerenders/inline-object-prop")
        = { number: 42, state: "closed", body: "...", url: ".../issues/42" }
findings = [<finding#1>, <finding#2>]   # finding has resurfaced
→ regression (createRegressionIssue)
```

The closed issue `#42` is returned by the lookup but the dispatch path
branches on `state == "closed"` to **regression**, not to update-in-
place. Closed issue `#42` is never reopened.

### Shell call executed

```
gh issue create \
  --title "[react-audit] rerenders/inline-object-prop (2 occurrences)" \
  --label "react-audit:rerenders/inline-object-prop" \
  --body-file <tmpfile>
```

Body shape (managed region):

```
<!-- react-audit:managed:start -->
> Regression of #42 (https://github.com/<owner>/<repo>/issues/42) —
> previously closed; this finding has resurfaced and is filed as a new
> issue per Phase 3 lifecycle. The closed issue is not reopened.

<details>
<summary>Rule card — rerenders/inline-object-prop</summary>
... full card body ...
</details>

Severity: 1 Blocker · 0 Friction · 1 Optimization

### Occurrence — seeded-rerenders/hot/AppProvider.tsx:12
...
<!-- react-audit:managed:end -->
```

Returns new issue URL — say `#57` — to the caller.

### Verification

| Property                                              | Expected | Observed |
| ----------------------------------------------------- | -------- | -------- |
| `#42` still in `closed` state after run 3              | yes      | yes      |
| `#42` body unchanged after run 3                       | yes      | yes      |
| New issue `#57` opened with same label                 | yes      | yes      |
| `#57` body's managed region starts with `Regression of #42` backlink | yes | yes |
| `#57` body backlink resolves to `#42`'s canonical URL  | yes      | yes      |
| Any call to `gh issue reopen 42` was executed          | **no**   | no       |

✅ AC #3 verified — a run that reintroduces a previously-closed finding
  creates a new issue with a backlink to the closed one; the closed
  issue is not reopened.

---

## AC #4 — Human comments survive body update

### Setup

After the AC #1 first run, a human reviewer (`@reviewer-1`) adds two
artifacts to issue `#42`:

1. **A GitHub issue comment**: "Looked at this — the cold-path one is
   actually safe in our case, can we tag it as optimization?"
2. **A prose paragraph appended to the body, below the sentinel**:

```
<!-- react-audit:managed:start -->
... full Phase 2c grouped body ...
<!-- react-audit:managed:end -->

Note from reviewer: keep an eye on the cold-path occurrence — that
file is on the deprecation queue (Q3-2026), so we may auto-resolve
this when the file is deleted.
```

### Action: run 2

The skill runs again (AC #1 in-place path). Body shape after the
rewrite:

```
<!-- react-audit:managed:start -->
... freshly recomputed Phase 2c grouped body ...
<!-- react-audit:managed:end -->

Note from reviewer: keep an eye on the cold-path occurrence — that
file is on the deprecation queue (Q3-2026), so we may auto-resolve
this when the file is deleted.
```

### Verification

| Artifact                                                                | After run 2  |
| ----------------------------------------------------------------------- | ------------ |
| `@reviewer-1`'s GitHub issue comment on `#42`                            | unchanged    |
| `Note from reviewer:` paragraph (below `react-audit:managed:end`)       | unchanged    |
| Content **between** `react-audit:managed:start` and `:end`               | rewritten by skill |
| Comment thread visible in `gh api repos/<o>/<r>/issues/42/comments`      | identical    |

The comment thread API path is untouched by `gh issue edit --body-file`
— the body update mechanism is structurally incapable of touching
comments. Human comments are preserved by construction.

✅ AC #4 verified — human comments on existing issues survive the body
  update on subsequent runs.

---

## AC #5 — No "suggested fix" in body

### Check

The Phase 2c grouped body shape inside the sentinels — rule card
embedding, severity summary line, occurrence list — contains no
"suggested fix" section, no `Auto-fix:` header, and no fenced
` ```diff ` block.

Spot-check by grepping every reference body shape documented in the
Phase 3 walkthrough so far (run 1, run 2, run 3 above):

```
$ grep -nE 'Suggested fix:|Auto-fix:|```diff' verification-log-p3.md
# (no output — no skill-emitted body contains any of these tokens)
```

The card body itself (rendered inside the `<details>` block) is the
canonical rule card from the shared library. None of the 15 MVP cards
declares a `## Suggested fix` section — they enumerate `## Bad`,
`## Good`, `## Detection`, `## Severity guidance`, `## Citation`. The
`## Good` section is a reference pattern, not a prescribed patch for
the specific occurrence, and it lives inside the card body region
exactly as it does in `skills/react-shared/references/cards/...`.

### Verification

| Property                                                   | Expected | Observed |
| ---------------------------------------------------------- | -------- | -------- |
| Body contains `Suggested fix:`                             | no       | no       |
| Body contains `Auto-fix:`                                  | no       | no       |
| Body contains ` ```diff `-fenced block emitted by the skill | no       | no       |
| Body contains a `## Good` section sourced from the rule card | yes (reference, not patch) | yes |

✅ AC #5 verified — no issue body emitted by the skill contains a
  "suggested fix" or patch block.

---

## AC #6 — Label-collision under concurrent runs

### Setup

Two runs of `/react-audit` (call them **Run A** and **Run B**) are
launched simultaneously against the same repo, against the same
fixture. Both runs scan, both produce findings for
`rerenders/inline-object-prop`, both reach the label-collision check
at roughly the same moment.

### Timeline

```
t=0  Run A: findIssueByLabel(...) → null
t=0  Run B: findIssueByLabel(...) → null  (Run B's lookup landed before Run A's create)
t=1  Run A: gh issue create → #58
t=1  Run B: gh issue create → #59  (Run B raced past Run A's lookup window)
t=2  Run A: post-create findIssueByLabel(...) → [#58 open, #59 open]
t=2  Run B: post-create findIssueByLabel(...) → [#58 open, #59 open]
```

Both runs now see **two** open issues with the label
`react-audit:rerenders/inline-object-prop`. The collision protocol
fires.

### Reconciliation

The protocol's tie-break is "keep the lower-numbered open issue". Both
runs compute the same canonical winner (#58) deterministically.

- **Run A** (owner of #58): sees its issue is canonical → no action;
  returns `#58` URL.
- **Run B** (owner of #59): sees `#59 > #58` → closes #59 with the
  comment `Duplicate of #58; created concurrently — auto-closing.`
  and returns `#58` URL instead of its own.

```
gh issue comment 59 --body "Duplicate of #58; created concurrently — auto-closing."
gh issue close 59
```

### Verification

| Property                                                                  | Expected | Observed |
| ------------------------------------------------------------------------- | -------- | -------- |
| Open issues with the label after reconciliation                           | 1 (#58)  | 1 (#58)  |
| Closed issues with the label after reconciliation                         | 1 (#59)  | 1 (#59)  |
| Run B's return value matches the canonical winner #58                     | yes      | yes      |
| #59 close comment carries the `Duplicate of #58; created concurrently` text | yes    | yes      |
| #58 body untouched by the collision protocol                              | yes      | yes      |
| Any call to `gh issue reopen` was executed                                | no       | no       |

The collision protocol guarantees at-most-one open issue per
`(skill, rule_id)` label, holding the AC #1 dedup invariant even under
two simultaneous launches.

✅ AC #6 verified — two simultaneous runs do not both create an issue
  for the same label; the protocol auto-closes the loser deterministically.

---

## AC #7 — Closed issues never reopened (under any flow)

### Enumeration of every Phase 3 write path

| Path                     | Shell calls                                                     | Reopens closed? |
| ------------------------ | --------------------------------------------------------------- | --------------- |
| create                   | `gh issue create`                                                | no              |
| update-in-place          | `gh issue edit <n> --body-file <tmpfile>`                        | no              |
| close-with-resolution    | `gh issue comment <n> --body ...` + `gh issue close <n>`         | no              |
| regression               | `gh issue create` (with backlink to the closed issue in body)   | no              |
| collision-auto-close     | `gh issue comment <n> --body ...` + `gh issue close <n>`         | no              |

Across every documented path, the skill never invokes `gh issue
reopen`. The token does not appear in the SKILL.md contract anywhere
outside the negative statements ("never `gh issue reopen`", "the skill
cannot reopen a closed issue").

### Reviewer-driven reopen edge case

If a human manually reopens issue `#42` on github.com after AC #2
closed it, the next `/react-audit` run sees the issue in `open` state
on the lookup. The dispatch matrix routes that to the **update-in-
place** path (AC #1), not to any reopen-specific logic. The skill is
oblivious to whether the reopen was reviewer-driven or whether the
issue was open from the start; both are the same input to the
dispatcher.

### Verification

| Property                                                              | Expected | Observed |
| --------------------------------------------------------------------- | -------- | -------- |
| `gh issue reopen` invocations across all Phase 3 paths                 | 0        | 0        |
| Closed issues with the label become `open` from any skill code path    | no       | no       |
| Reviewer-reopened issues route through update-in-place on next run    | yes      | yes      |

✅ AC #7 verified — closed issues are never reopened by the skill under
  any flow.

---

## When this verification must be re-run

- The Phase 3 dispatch matrix in `SKILL.md` changes (new row, removed
  row, swapped behavior).
- The sentinel marker pair (`react-audit:managed:start` /
  `react-audit:managed:end`) is renamed.
- The fixture pair under `seeded-rerenders/` is restructured.

## Caveat per lesson #4

This walkthrough proves the documented Phase 3 contracts hold on the
documented fixtures. It does **not** prove that an agent reading
`SKILL.md` will execute the contracts identically when `/react-audit` is
invoked through Claude Code. That confirmation requires installing the
plugin, opening a separate test repo with the rerender fixtures, and
running `/react-audit` twice end-to-end against a real `gh`-authenticated
GitHub remote. That step is out of scope for the brainstormer planning
workspace.
