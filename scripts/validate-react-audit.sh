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
    "Issue Manager"
  do
    if ! grep -qF "## $required_heading" "$SKILL_FILE"; then
      errors+=("SKILL.md: missing section '## $required_heading'")
    fi
  done

  # Each module must declare a concrete contract symbol.
  for required_symbol in \
    "loadCard(" \
    "scan(" \
    "createIssue("
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
