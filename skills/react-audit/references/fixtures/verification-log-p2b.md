# `/react-audit` Phase 2b — verification log (smart scan)

Manual walk through the Phase 2b Smart Scan front step. The skill is not
actually invoked (running it inside this brainstormer planning workspace
would file real GitHub issues against `auditmos/brainstormer`); instead
each acceptance criterion is exercised against a fixed fixture set and
the result is recorded as evidence.

Run date: 2026-05-17
Run by: tkowalczyk
Phase 1 evidence: `verification-log.md` (unchanged).
Phase 2a evidence: `verification-log-p2a.md` (unchanged).

The Smart Scan contract under test:

```
files = enumerateScanTargets()
  1. candidates = git ls-files '*.tsx' '*.jsx'
  2. filtered   = candidates \ {node_modules/, dist/, build/, .next/,
                               coverage/, **/*.test.*, **/*.stories.*}
  3. if len(filtered) < SMART_SCAN_THRESHOLD → return filtered
  4. else → prompt for directory-group selection, return chosen subset
```

`SMART_SCAN_THRESHOLD = 50` is the canonical constant declared in
`skills/react-audit/SKILL.md`. The verification below references the
constant by name; if it changes, both the Workflow section and this log
must be updated in lockstep.

---

## Step 1 — Below-threshold path (AC #1)

Fixture: `skills/react-audit/references/fixtures/seeded/` — the eleven
Phase 2a seeded fixtures. Re-used because they constitute a real,
already-frozen scan target of <50 files.

```
$ git ls-files 'skills/react-audit/references/fixtures/seeded/*.tsx' | wc -l
11
```

Smart Scan trace:

```
candidates = [11 .tsx files under seeded/]
filtered   = candidates                    # none of the seeded paths
                                           # match the canonical exclusion
                                           # list
len(filtered) = 11
11 < SMART_SCAN_THRESHOLD (50)             # below threshold
→ return filtered, no prompt
```

Scope log line emitted before the scan begins (per Smart Scan §Dispatch
order step 3):

```
smart-scan: 11 files, below threshold, scanning all
```

No prompt is shown to the user. The Code Scanner receives all eleven
files and Phase 2a's 11-card dispatch produces the eleven Findings
already frozen in `verification-log-p2a.md`.

✅ AC #1 verified (fewer than 50 matching files → no prompt, immediate
  scan, scope log line emitted).

---

## Step 2 — Above-threshold path (AC #2, #3, #4)

Fixture: `skills/react-audit/references/fixtures/above-threshold/`.
Layout:

```
above-threshold/
  src/components/Btn{01..15}.tsx          (15 files)
  src/features/auth/Auth{01..15}.tsx      (15 files)
  src/features/billing/Bill{01..15}.tsx   (15 files)
  src/routes/Route{01..15}.tsx            (15 files)
  src/Card.test.tsx                       (excluded: **/*.test.*)
  src/Card.stories.tsx                    (excluded: **/*.stories.*)
  node_modules/react/Stub.tsx             (excluded: node_modules/)
  dist/Built.tsx                          (excluded: dist/)
  build/Compiled.tsx                      (excluded: build/)
  .next/cache/Chunk.tsx                   (excluded: .next/)
  coverage/Report.tsx                     (excluded: coverage/)
```

Counts:

```
$ find above-threshold -type f -name '*.tsx' | wc -l
67                                         # total tsx files in fixture
$ find above-threshold -type f -name '*.tsx' \
    ! -path '*/node_modules/*' \
    ! -path '*/dist/*' \
    ! -path '*/build/*' \
    ! -path '*/.next/*' \
    ! -path '*/coverage/*' \
    ! -name '*.test.*' \
    ! -name '*.stories.*' | wc -l
60                                         # post-exclusion (scanned)
```

Smart Scan trace:

```
candidates    = [67 .tsx files under above-threshold/]
filtered      = candidates \ exclusion_list   # 7 files stripped
len(filtered) = 60
60 >= SMART_SCAN_THRESHOLD (50)            # at or above threshold
→ group by top-level directory, prompt user
```

Prompt rendered by Smart Scan §Dispatch order step 4:

```
60 matching files found (threshold: 50). Select directories to scan:
  [a] src/components/        15 files
  [b] src/features/auth/     15 files
  [c] src/features/billing/  15 files
  [d] src/routes/            15 files
  [all] accept all   [none] reject all   [comma-separated letters] subset
```

Three user-response cases exercised (AC #3):

### 2.1 — Accept all

User input: `all`. Selected scope: every directory group → 60 files.
Scope log line:

```
smart-scan: 60 files across 4 groups, scanning 60
```

### 2.2 — Reject all

User input: `none`. Selected scope: empty. Workflow short-circuits with
`0 findings`; no Code Scanner invocation, no `gh issue create`.

Scope log line:

```
smart-scan: 60 files across 4 groups, scanning 0
```

### 2.3 — Subset

User input: `a,d` (components + routes only). Selected scope:
30 files. Scope log line:

```
smart-scan: 60 files across 4 groups, scanning 30
```

In all three sub-cases the scope log line precedes the Code Scanner.
Reproducibility from logs alone is preserved — a reader sees both the
candidate count and the scanned count without re-running the skill.

✅ AC #2 verified (60 matching files ≥ 50 → prompt rendered with all four
  directory groups and per-group counts).
✅ AC #3 verified (accept all / reject all / subset all produce the
  expected scoped file sets).
✅ AC #4 verified (the `smart-scan: <N> files ...` line is emitted before
  the Code Scanner runs on every path, including the empty-subset path).

---

## Step 3 — Exclusion guarantee (AC #5)

The seven excluded files in the above-threshold fixture are never read by
`/react-audit`, regardless of which sub-case from Step 2 was exercised:

| Excluded path                        | Rule              |
| ------------------------------------ | ----------------- |
| `node_modules/react/Stub.tsx`        | `node_modules/`   |
| `dist/Built.tsx`                     | `dist/`           |
| `build/Compiled.tsx`                 | `build/`          |
| `.next/cache/Chunk.tsx`              | `.next/`          |
| `coverage/Report.tsx`                | `coverage/`       |
| `src/Card.test.tsx`                  | `**/*.test.*`     |
| `src/Card.stories.tsx`               | `**/*.stories.*`  |

Smart Scan §Dispatch order step 2 strips exclusions **before** the
threshold check. As a result:

- The seven excluded files are not counted toward the threshold (`60`
  rather than `67`). The threshold check fires on the filtered count.
- They are not offered as directory groups in the prompt. The user
  cannot opt them back in via subset selection.
- They are not present in the `files` array returned by
  `enumerateScanTargets()`. The Code Scanner never opens them.

This holds on the below-threshold path as well: had any of the eleven
Phase 2a seeded fixtures lived under `node_modules/` (they do not),
they would have been stripped before the count check.

✅ AC #5 verified (excluded directories never read regardless of which
  threshold branch fires).

---

## Step 4 — Threshold documentation (AC #6)

The threshold lives in `skills/react-audit/SKILL.md` under
`## Smart Scan → ### Configuration → #### Threshold`:

```
SMART_SCAN_THRESHOLD = 50
```

To change the threshold, an editor updates this single declaration. The
Workflow section and the Smart Scan dispatch reference the constant by
name (`SMART_SCAN_THRESHOLD`), so no skill-logic prose needs editing —
only the constant. The validator (`scripts/validate-react-audit.sh`)
enforces the `^SMART_SCAN_THRESHOLD = 50$` literal until a future PR
adjusts both the constant and the assert in lockstep.

✅ AC #6 verified (threshold value declared as a named constant in one
  place; skill logic references it by name; an adjustment does not
  require rewriting the Workflow or Smart Scan prose).

---

## Caveat per lesson #4

This verification walks the Phase 2b contracts by hand against fixed
inputs and proves the documented outputs hold on the documented
fixtures. It does **not** prove that an agent reading `SKILL.md` will
execute the contracts identically when `/react-audit` is invoked through
Claude Code. That confirmation requires installing the plugin from the
marketplace, opening a separate test repo with both fixture shapes, and
running `/react-audit` end-to-end against a real `gh`-authenticated
GitHub remote with a real interactive prompt. That step is out of scope
for the brainstormer planning workspace and is what would be exercised
when a downstream consumer (e.g., `tstack-on-cf`) installs the plugin.

---

## When this verification must be re-run

- The Smart Scan dispatch order in `SKILL.md` changes.
- The canonical exclusion list in `SKILL.md` changes.
- `SMART_SCAN_THRESHOLD` is adjusted from `50`.
- The above-threshold fixture is restructured (group counts change, new
  excluded sample added/removed, etc.).
