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

  # Each module must declare a concrete contract symbol.
  for required_symbol in \
    "loadCard(" \
    "scan(" \
    "createIssue(" \
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
