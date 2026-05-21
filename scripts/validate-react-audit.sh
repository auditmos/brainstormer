#!/usr/bin/env bash
# Validates the /react-audit skill artifacts:
#   - skills/react-audit/SKILL.md presence + frontmatter (name, description)
#   - SKILL.md documents the three minimal-scope deep modules
#       (Rule Card Library, Code Scanner, Issue Manager) with concrete contracts
#   - No GitHub-interaction mechanism other than `gh` CLI is referenced
# Exit 0 = skill conforms, Exit 1 = violations.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/react-audit/SKILL.md"

errors=()

extract_field() {
  awk -v f="$2" '
    /^---$/ { fm++; if (fm == 2) exit; next }
    fm == 1 && $0 ~ "^"f": " {
      sub("^"f": ", "")
      print
      exit
    }
  ' "$1"
}

# 1. Presence + frontmatter --------------------------------------------------
if [[ ! -f "$SKILL_FILE" ]]; then
  errors+=("missing: skills/react-audit/SKILL.md")
else
  name=$(extract_field "$SKILL_FILE" name)
  description=$(extract_field "$SKILL_FILE" description)

  [[ -z "$name" ]]        && errors+=("SKILL.md: missing 'name' frontmatter")
  [[ -z "$description" ]] && errors+=("SKILL.md: missing 'description' frontmatter")
  [[ -n "$name" && "$name" != "react-audit" ]] && errors+=("SKILL.md: name '$name' must be 'react-audit'")

  # Manual-trigger heuristic — description should reference the slash command or
  # natural-language match, mirroring sibling skills in this workspace.
  if [[ -n "$description" ]] && ! grep -qiE '/react-audit|audit (a |the )?(repo|repository|react|ui)' "$SKILL_FILE"; then
    errors+=("SKILL.md: description does not reference /react-audit trigger")
  fi
fi

# 2. Module interface sections (slice 3) ------------------------------------
if [[ -f "$SKILL_FILE" ]]; then
  for required_heading in \
    "Rule Card Library" \
    "Code Scanner" \
    "Issue Manager" \
    "Smart Scan"
  do
    if ! grep -qF "## $required_heading" "$SKILL_FILE"; then
      errors+=("SKILL.md: missing section '## $required_heading'")
    fi
  done

  # Each module must declare a concrete contract symbol. Phase 2c
  # supersedes Phase 1's `createIssue(` with `upsertGroupedIssue(` (one
  # issue per (skill, rule_id) group instead of one issue per occurrence);
  # the symbol list below is the current set.
  for required_symbol in \
    "loadCard(" \
    "scan(" \
    "upsertGroupedIssue(" \
    "enumerateScanTargets("
  do
    if ! grep -qF "$required_symbol" "$SKILL_FILE"; then
      errors+=("SKILL.md: missing contract symbol '$required_symbol'")
    fi
  done

  # Phase 2a — the Workflow section must invoke listCards(); the skill
  # dispatches across every shipping card in the effects category, not just
  # the Phase 1 tracer-bullet card.
  workflow_section=$(awk '
    /^## Workflow$/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$SKILL_FILE")
  if ! grep -qF 'listCards(' <<< "$workflow_section"; then
    errors+=("SKILL.md: Workflow section does not invoke listCards( — required for Phase 2a multi-rule dispatch")
  fi

  # Phase 2b — Workflow must invoke enumerateScanTargets() before scan(),
  # not after. The exclusion list and threshold check live in Smart Scan
  # and run unconditionally up-front; reversing the order would let the
  # scanner read excluded files.
  if ! grep -qF 'enumerateScanTargets(' <<< "$workflow_section"; then
    errors+=("SKILL.md: Workflow section does not invoke enumerateScanTargets( — required for Phase 2b smart-scan dispatch")
  else
    enum_line=$(grep -nF 'enumerateScanTargets(' <<< "$workflow_section" | head -1 | cut -d: -f1)
    scan_line=$(grep -nF 'scan(files' <<< "$workflow_section" | head -1 | cut -d: -f1)
    if [[ -n "$enum_line" && -n "$scan_line" && "$enum_line" -ge "$scan_line" ]]; then
      errors+=("SKILL.md: Workflow lists scan(files, ...) before enumerateScanTargets( — order must be enumerate → scan")
    fi
  fi

  # Phase 2b — the threshold value must be declared as a named constant in
  # SKILL.md so it can be adjusted without changing skill logic (AC #6).
  if ! grep -qE '^SMART_SCAN_THRESHOLD[[:space:]]*=[[:space:]]*50$' "$SKILL_FILE"; then
    errors+=("SKILL.md: missing 'SMART_SCAN_THRESHOLD = 50' literal declaration — AC #6 requires the threshold to be a named, adjustable constant")
  fi

  # Phase 2b — the canonical exclusion list must appear in SKILL.md so
  # excluded directories are documented and reviewable (AC #5).
  for excluded in \
    "node_modules/" \
    "dist/" \
    "build/" \
    ".next/" \
    "coverage/" \
    "**/*.test.*" \
    "**/*.stories.*"
  do
    if ! grep -qF "$excluded" "$SKILL_FILE"; then
      errors+=("SKILL.md: exclusion list missing entry '$excluded' — AC #5 requires the canonical exclusion list to be documented")
    fi
  done
fi

# 3. Fixtures + verification log (slice 4) ----------------------------------
FIXTURES_DIR="$REPO_ROOT/skills/react-audit/references/fixtures"
for required in \
  "seeded/UserCard.tsx" \
  "clean/UserCard.tsx" \
  "README.md" \
  "verification-log.md"
do
  if [[ ! -f "$FIXTURES_DIR/$required" ]]; then
    errors+=("missing fixture artifact: skills/react-audit/references/fixtures/$required")
  fi
done

# 4. Phase 2a — fixture↔card coverage + multi-rule verification log ---------
#    Each shipping card under cards/effects/ must have a seeded fixture that
#    carries the magic header comment `// rule_id: effects/<slug>`. The P2a
#    verification log must reference every shipping card by id.
CARDS_DIR_EFFECTS="$REPO_ROOT/skills/react-shared/references/cards/effects"
SEEDED_DIR="$FIXTURES_DIR/seeded"
P2A_LOG="$FIXTURES_DIR/verification-log-p2a.md"
if [[ -d "$CARDS_DIR_EFFECTS" ]]; then
  while IFS= read -r -d '' card; do
    base="$(basename "$card" .md)"
    [[ "$base" == "index" ]] && continue
    rule_id="effects/$base"
    if [[ ! -d "$SEEDED_DIR" ]]; then
      errors+=("missing seeded fixtures directory: ${SEEDED_DIR#"$REPO_ROOT/"}")
      break
    fi
    if ! grep -rqE "^// rule_id: ${rule_id}\$" "$SEEDED_DIR"; then
      errors+=("no seeded fixture carries '// rule_id: $rule_id' header under ${SEEDED_DIR#"$REPO_ROOT/"}/")
    fi
    if [[ -f "$P2A_LOG" ]]; then
      if ! grep -qF "$rule_id" "$P2A_LOG"; then
        errors+=("verification-log-p2a.md: rule '$rule_id' not referenced")
      fi
    fi
  done < <(find "$CARDS_DIR_EFFECTS" -maxdepth 1 -type f -name '*.md' -print0)

  if [[ ! -f "$P2A_LOG" ]]; then
    errors+=("missing P2a verification log: ${P2A_LOG#"$REPO_ROOT/"}")
  else
    # Cache contract must be restated in the P2a log so the (file_hash, rule_id)
    # guarantee is documented for the multi-rule run.
    if ! grep -qE 'file_hash.*rule_id|rule_id.*file_hash' "$P2A_LOG"; then
      errors+=("verification-log-p2a.md: missing (file_hash, rule_id) cache contract restatement")
    fi
  fi
fi

# 4b. Phase 2b — smart-scan verification artifacts -------------------------
P2B_LOG="$FIXTURES_DIR/verification-log-p2b.md"
ABOVE_DIR="$FIXTURES_DIR/above-threshold"

if [[ ! -f "$P2B_LOG" ]]; then
  errors+=("missing P2b verification log: ${P2B_LOG#"$REPO_ROOT/"}")
else
  # Below-threshold ack (AC #1): the log must record the no-prompt path
  # against an actual fixture set of fewer than 50 files.
  if ! grep -qiE 'below.?threshold|no prompt|< 50|fewer than 50' "$P2B_LOG"; then
    errors+=("verification-log-p2b.md: missing below-threshold (AC #1) evidence")
  fi
  # Above-threshold ack (AC #2/#3/#4): the log must document a fixture
  # with ≥50 candidate files, the directory-group prompt rendering, the
  # accept/reject/subset response, and the scope log line.
  if ! grep -qiE 'above.?threshold|≥ ?50|>= ?50|50 or more' "$P2B_LOG"; then
    errors+=("verification-log-p2b.md: missing above-threshold (AC #2) evidence")
  fi
  if ! grep -qiE 'accept all|reject all|subset' "$P2B_LOG"; then
    errors+=("verification-log-p2b.md: missing accept/reject/subset (AC #3) evidence")
  fi
  if ! grep -qiE 'smart-scan: .* files' "$P2B_LOG"; then
    errors+=("verification-log-p2b.md: missing 'smart-scan: ... files' scope-log line (AC #4)")
  fi
  # Exclusion-list ack (AC #5): the log must demonstrate that excluded
  # paths in the above-threshold fixture are not counted toward the
  # threshold and are not read.
  if ! grep -qiE 'excluded|not (scanned|read)' "$P2B_LOG"; then
    errors+=("verification-log-p2b.md: missing exclusion evidence (AC #5)")
  fi
  # Threshold-doc ack (AC #6): the log should reference the named
  # SMART_SCAN_THRESHOLD constant so changes to the value require a
  # documented log update.
  if ! grep -qF 'SMART_SCAN_THRESHOLD' "$P2B_LOG"; then
    errors+=("verification-log-p2b.md: missing SMART_SCAN_THRESHOLD reference (AC #6)")
  fi
fi

# Above-threshold fixture: must exist, must contain ≥50 .tsx/.jsx files
# under non-excluded paths, and must include at least one file under each
# of the canonical excluded paths to prove they are filtered out.
if [[ ! -d "$ABOVE_DIR" ]]; then
  errors+=("missing above-threshold fixture directory: ${ABOVE_DIR#"$REPO_ROOT/"}")
else
  scanned_count=$(find "$ABOVE_DIR" -type f \( -name '*.tsx' -o -name '*.jsx' \) \
    ! -path '*/node_modules/*' \
    ! -path '*/dist/*' \
    ! -path '*/build/*' \
    ! -path '*/.next/*' \
    ! -path '*/coverage/*' \
    ! -name '*.test.*' \
    ! -name '*.stories.*' \
    | wc -l | tr -d ' ')
  if (( scanned_count < 50 )); then
    errors+=("above-threshold fixture has only $scanned_count post-exclusion files — need ≥ 50 to exercise AC #2")
  fi
  # Each canonical exclusion path must be represented by at least one file
  # so the fixture proves AC #5 (excluded dirs never read regardless of
  # threshold).
  # Two exclusion families: directory prefixes vs file globs. Directory
  # entries (including dot-prefix ones like .next) are looked up as
  # `-type d`; glob entries (*.test.*, *.stories.*) are looked up as
  # `-type f`.
  for excl_dir in node_modules dist build .next coverage; do
    found=$(find "$ABOVE_DIR" -type d -name "$excl_dir" | head -1)
    if [[ -z "$found" ]]; then
      errors+=("above-threshold fixture missing exclusion sample directory '$excl_dir/' — AC #5 cannot be exercised without it")
    fi
  done
  for excl_glob in '*.test.*' '*.stories.*'; do
    found=$(find "$ABOVE_DIR" -type f -name "$excl_glob" | head -1)
    if [[ -z "$found" ]]; then
      errors+=("above-threshold fixture missing exclusion sample file matching '$excl_glob' — AC #5 cannot be exercised without it")
    fi
  done
fi

# 4c. Phase 2c — rerender cards + grouped issue contract -------------------
#    SKILL.md must document the grouped emission contract (one issue per
#    `(skill, rule_id)` group), the per-occurrence body shape (file:line +
#    ~5 lines of context per finding, per-occurrence severity), and the
#    `<details>` collapsible rule for oversized cards. The shared card
#    library must ship the four canonical rerender cards. A P2c
#    verification log must exist and walk each P2c AC.

CARDS_DIR_RERENDERS="$REPO_ROOT/skills/react-shared/references/cards/rerenders"
P2C_LOG="$FIXTURES_DIR/verification-log-p2c.md"

# Four canonical rerender cards (AC #1 / index AC #2).
for rerender_slug in \
  "inline-object-prop" \
  "inline-array-prop" \
  "missing-memo-on-list-row" \
  "context-too-broad"
do
  if [[ ! -f "$CARDS_DIR_RERENDERS/$rerender_slug.md" ]]; then
    errors+=("missing rerender card: skills/react-shared/references/cards/rerenders/$rerender_slug.md — Phase 2c AC #1 requires all four cards")
  fi
done

if [[ -f "$SKILL_FILE" ]]; then
  # Workflow must call into the grouped emission path. Phase 2c collapses
  # findings by `(skill, rule_id)` before issue creation — the Workflow
  # section needs an explicit invocation symbol so a reader sees the
  # grouping step (AC #3).
  workflow_section_p2c=$(awk '
    /^## Workflow$/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$SKILL_FILE")
  if ! grep -qE 'upsertGroupedIssue\(|groupFindings\(' <<< "$workflow_section_p2c"; then
    errors+=("SKILL.md: Workflow section does not invoke a grouped-emission symbol (upsertGroupedIssue( or groupFindings() — AC #3 requires one issue per (skill, rule_id) group")
  fi

  # Issue Manager section must declare the grouped contract symbol and
  # describe the per-occurrence body shape.
  issue_mgr_section=$(awk '
    /^## Issue Manager$/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$SKILL_FILE")
  if ! grep -qF 'upsertGroupedIssue(' <<< "$issue_mgr_section"; then
    errors+=("SKILL.md: Issue Manager section does not declare 'upsertGroupedIssue(' contract — AC #3 requires the grouped emission contract")
  fi
  if ! grep -qE '\(skill,[[:space:]]*rule_id\)|skill, rule_id' <<< "$issue_mgr_section"; then
    errors+=("SKILL.md: Issue Manager section does not reference grouping by '(skill, rule_id)' — AC #3 requires this as the group key")
  fi
  if ! grep -qiE '<details>|collapsible' <<< "$issue_mgr_section"; then
    errors+=("SKILL.md: Issue Manager section does not document '<details>' collapsible rule — AC #4 requires the >80-line / >2 bad-good pair threshold")
  fi
  if ! grep -qiE '80 ?lines?|>80|over 80|exceed.*80' <<< "$issue_mgr_section"; then
    errors+=("SKILL.md: Issue Manager section does not state the ~80-line threshold for <details> wrapping — AC #4")
  fi
  if ! grep -qiE 'per[- ]occurrence|per[- ]finding' <<< "$issue_mgr_section"; then
    errors+=("SKILL.md: Issue Manager section does not document per-occurrence (per-finding) severity in grouped body — AC #5 requires per-finding contextual severity to appear in the body")
  fi
  if ! grep -qiE 'file:line|file:.*line|<file>:<line>' <<< "$issue_mgr_section"; then
    errors+=("SKILL.md: Issue Manager section does not document 'file:line' per-occurrence format — AC #6 requires per-finding file:line in the grouped body")
  fi
  if ! grep -qiE '~?5[- ]lines? (of )?context|five lines of context' <<< "$issue_mgr_section"; then
    errors+=("SKILL.md: Issue Manager section does not document ~5 lines of context per occurrence — AC #6")
  fi

  # Workflow must dispatch across the rerenders/ category, not just
  # effects/. Phase 2c extends the load step to include all MVP cards.
  if ! grep -qE 'listCards\(\)|listCards\(\"rerenders\"|rerenders' <<< "$workflow_section_p2c"; then
    errors+=("SKILL.md: Workflow section does not load rerenders/ cards — AC #1 requires Phase 2c dispatch across all 15 MVP cards")
  fi
fi

# P2c verification log — walks AC #1 through #6 against the rerenders
# fixture pair.
if [[ ! -f "$P2C_LOG" ]]; then
  errors+=("missing P2c verification log: ${P2C_LOG#"$REPO_ROOT/"}")
else
  # AC #1 — four rerender cards referenced by id
  for rerender_id in \
    "rerenders/inline-object-prop" \
    "rerenders/inline-array-prop" \
    "rerenders/missing-memo-on-list-row" \
    "rerenders/context-too-broad"
  do
    if ! grep -qF "$rerender_id" "$P2C_LOG"; then
      errors+=("verification-log-p2c.md: rule '$rerender_id' not referenced (AC #1)")
    fi
  done
  # AC #2 — log mentions the 15-card total
  if ! grep -qE '15 (MVP )?cards?|fifteen cards|all 15' "$P2C_LOG"; then
    errors+=("verification-log-p2c.md: missing 15-card total (AC #2)")
  fi
  # AC #3 — grouped emission demonstrated
  if ! grep -qiE 'grouped|one issue per|single issue|N occurrences' "$P2C_LOG"; then
    errors+=("verification-log-p2c.md: missing grouped-emission evidence (AC #3)")
  fi
  # AC #4 — <details> collapsible mentioned
  if ! grep -qF '<details>' "$P2C_LOG"; then
    errors+=("verification-log-p2c.md: missing '<details>' collapsible evidence (AC #4)")
  fi
  # AC #5 — per-occurrence severity split demonstrated
  if ! grep -qiE 'hot.?path.*cold.?path|cold.?path.*hot.?path|Blocker.*Friction|Friction.*Blocker' "$P2C_LOG"; then
    errors+=("verification-log-p2c.md: missing hot-path/cold-path severity split (AC #5)")
  fi
  # AC #6 — per-occurrence file:line + ~5 lines of context
  if ! grep -qiE 'file:line|~?5[- ]lines? (of )?context' "$P2C_LOG"; then
    errors+=("verification-log-p2c.md: missing per-occurrence file:line + 5-line context evidence (AC #6)")
  fi
fi

# Rerenders fixture — at minimum a hot-path and a cold-path file
# demonstrating the same rule firing in both contexts (AC #5).
RERENDERS_FIXTURE_DIR="$FIXTURES_DIR/seeded-rerenders"
if [[ ! -d "$RERENDERS_FIXTURE_DIR" ]]; then
  errors+=("missing rerenders fixture directory: ${RERENDERS_FIXTURE_DIR#"$REPO_ROOT/"} — AC #3/#5 require a fixture demonstrating grouped emission and hot/cold severity split")
else
  rerenders_fixture_count=$(find "$RERENDERS_FIXTURE_DIR" -type f -name '*.tsx' | wc -l | tr -d ' ')
  if (( rerenders_fixture_count < 2 )); then
    errors+=("rerenders fixture has only $rerenders_fixture_count .tsx file(s) — need ≥ 2 (hot-path + cold-path) to exercise AC #5")
  fi
fi

# 4d. Phase 3 — re-run lifecycle (Issue Manager full validation surface) ---
#    Assertions grow one AC at a time alongside SKILL.md changes per the TDD
#    vertical-slice rule (see /tdd skill). AC #1 ships first; AC #2..#7 land
#    in subsequent slices.

P3_LOG="$FIXTURES_DIR/verification-log-p3.md"

if [[ -f "$SKILL_FILE" ]]; then
  issue_mgr_section_p3=$(awk '
    /^## Issue Manager$/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$SKILL_FILE")

  # AC #1 — lookup-by-label contract symbol present
  if ! grep -qF 'findIssueByLabel(' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section missing 'findIssueByLabel(' contract symbol — Phase 3 AC #1 requires label-based lookup before issue creation")
  fi
  # AC #1 — in-place rewrite documented
  if ! grep -qiE 'in[- ]place|update.*in place|rewrite.*body|body.*rewritten' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not document in-place body update — Phase 3 AC #1 requires the second-run path to rewrite the existing issue body")
  fi
  # AC #1 — sentinel markers documented (managed body region is the dedup mechanism)
  if ! grep -qF 'react-audit:managed:start' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section missing 'react-audit:managed:start' sentinel marker — Phase 3 AC #1 dedup mechanism")
  fi
  if ! grep -qF 'react-audit:managed:end' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section missing 'react-audit:managed:end' sentinel marker — Phase 3 AC #1 dedup mechanism")
  fi

  # AC #2 — close-with-dated-resolution-comment contract
  if ! grep -qF 'closeWithResolution(' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section missing 'closeWithResolution(' contract symbol — Phase 3 AC #2 requires a dedicated close-with-comment path")
  fi
  if ! grep -qiE 'resolution date|dated resolution|resolved <[^>]*date|YYYY-MM-DD' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not state that the close comment carries a date — Phase 3 AC #2 requires the resolution comment to be dated")
  fi
  if ! grep -qE 'gh issue close|gh issue comment' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not show the 'gh issue close' / 'gh issue comment' shell-out — Phase 3 AC #2 requires the close path to use the gh CLI explicitly")
  fi

  # AC #3 — regression path: createRegressionIssue + backlink to closed issue
  if ! grep -qF 'createRegressionIssue(' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section missing 'createRegressionIssue(' contract symbol — Phase 3 AC #3 requires a dedicated regression path")
  fi
  if ! grep -qiE 'backlink|Regression of #|previously[- ]closed' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not document the backlink-to-closed-issue requirement — Phase 3 AC #3")
  fi
  # AC #3 — explicit no-reopen statement for the regression path
  if ! grep -qiE 'never reopen|do not reopen|not reopened' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not state that the regression path never reopens the closed issue — Phase 3 AC #3")
  fi

  # AC #4 — human comments survive body updates (gh issue edit does not touch comments)
  if ! grep -qiE 'human comments? (preserved|survive|untouched)|comments? (are )?never (touched|edited|rewritten)' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not state that human comments survive the in-place body update — Phase 3 AC #4")
  fi
  # AC #4 — gh issue edit --body-file mechanism documented (only the body is rewritten; comments are separate API entities)
  if ! grep -qE 'gh issue edit .*--body-file|body-file' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not document the 'gh issue edit --body-file' mechanism — Phase 3 AC #4 relies on the fact that only the body (not comments) is rewritten")
  fi

  # AC #5 — read-only-findings invariant: no suggested fix / patch block
  if ! grep -qiE 'no (suggested fix|patch block|auto[- ]?fix)|never.*suggested fix|read[- ]only finding' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not state the no-suggested-fix / read-only-finding invariant — Phase 3 AC #5")
  fi

  # AC #6 — label-collision / concurrent-run protocol
  if ! grep -qiE 'label[- ]collision|concurrent|simultaneous|race' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not document a label-collision / concurrent-run protocol — Phase 3 AC #6")
  fi
  if ! grep -qiE 'post[- ]create reconciliation|after .*create|reconcil|auto[- ]closing' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not document the post-create reconciliation step for the collision protocol — Phase 3 AC #6")
  fi
  if ! grep -qiE 'at[- ]most[- ]one|only one open|single open issue' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not state the 'at most one open issue per label' invariant — Phase 3 AC #6")
  fi

  # AC #7 — never-reopen invariant: must be a top-level statement scoped to
  # "any flow" / "any path", not just a regression-section aside. The wording
  # "Phase 3 AC #7" must accompany the statement so the invariant is
  # discoverable and tied to its issue.
  if ! grep -qiE 'AC #7|AC#7|never-reopen invariant' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not anchor the never-reopen invariant with an 'AC #7' / 'never-reopen invariant' label — Phase 3 AC #7 requires the invariant to be discoverable as its own statement, not just a regression-section aside")
  fi
  if ! grep -qiE 'under any flow|under any path|on any path|under any (re-?run|circumstance)' <<< "$issue_mgr_section_p3"; then
    errors+=("SKILL.md: Issue Manager section does not state the never-reopen invariant 'under any flow / any path' — Phase 3 AC #7 requires the invariant to be scoped beyond a single dispatch path")
  fi
fi

if [[ ! -f "$P3_LOG" ]]; then
  errors+=("missing P3 verification log: ${P3_LOG#"$REPO_ROOT/"}")
else
  # AC #1 — dedup-in-place walkthrough
  if ! grep -qiE 'in[- ]place|no duplicate|same issue number|reused' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing in-place body update / dedup evidence (AC #1)")
  fi
  if ! grep -qF 'react-audit:managed:start' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing sentinel marker reference (AC #1)")
  fi

  # AC #2 — close-with-dated-resolution walkthrough
  if ! grep -qiE 'resolution date|closed with.*comment|dated resolution|resolved [0-9]{4}-[0-9]{2}-[0-9]{2}' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing close-with-dated-resolution evidence (AC #2)")
  fi
  if ! grep -qE 'gh issue close|gh issue comment' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing 'gh issue close' / 'gh issue comment' invocation in walkthrough (AC #2)")
  fi

  # AC #3 — regression walkthrough
  if ! grep -qiE 'regression|resurface|reintroduce' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing regression / resurface evidence (AC #3)")
  fi
  if ! grep -qiE 'backlink|Regression of #' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing backlink-to-closed-issue evidence (AC #3)")
  fi

  # AC #4 — human comments preserved walkthrough
  if ! grep -qiE 'human comments? (preserved|survive)' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing human-comments-survive evidence (AC #4)")
  fi

  # AC #5 — no-suggested-fix walkthrough
  if ! grep -qiE 'no .*(suggested fix|patch block|auto[- ]?fix)' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing no-suggested-fix evidence (AC #5)")
  fi

  # AC #6 — label-collision walkthrough
  if ! grep -qiE 'label[- ]collision|concurrent|simultaneous' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing label-collision evidence (AC #6)")
  fi

  # AC #7 — never-reopen walkthrough
  if ! grep -qiE 'never reopen|closed issues? .*not.*reopen|gh issue reopen.*not' "$P3_LOG"; then
    errors+=("verification-log-p3.md: missing never-reopen evidence (AC #7)")
  fi
fi

# 5. gh-only constraint guard (slice 7) -------------------------------------
#    Only flag forbidden patterns inside fenced code blocks. Prose mentions
#    (e.g. "no `curl`, no `WebFetch`") are descriptive and stay allowed.
if [[ -d "$REPO_ROOT/skills/react-audit" ]]; then
  forbidden_re='(^|[[:space:]])curl[[:space:]]|WebFetch\(|@octokit|api\.github\.com|fetch\([^)]*github'

  while IFS= read -r -d '' file; do
    rel="${file#"$REPO_ROOT/"}"
    # Print "<line_no>: <code-fenced line>" for every line inside ``` blocks.
    fenced=$(awk '
      BEGIN { in_block = 0 }
      /^```/ { in_block = !in_block; next }
      in_block { print NR": "$0 }
    ' "$file")
    [[ -z "$fenced" ]] && continue
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      if grep -qE "$forbidden_re" <<< "${entry#*: }"; then
        errors+=("non-gh GitHub mechanism in $rel:$entry")
      fi
    done <<< "$fenced"
  done < <(find "$REPO_ROOT/skills/react-audit" -type f \( -name '*.md' -o -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' -o -name '*.sh' \) -print0)
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "react-audit skill validation failed:"
  printf '  %s\n' "${errors[@]}"
  exit 1
fi

echo "react-audit skill validation passed."
