#!/usr/bin/env bash
# Validates that every SKILL.md frontmatter `description:` field is <= 1024
# characters. The Codex plugin loader (and other tooling) hard-fails on
# longer descriptions with "invalid description: exceeds maximum length of
# 1024 characters" — we catch it at commit time instead of at install time.
#
# Multi-line YAML descriptions are supported: lines after `description:` that
# are indented (don't match `^[a-z_]+:` or `^---$`) are concatenated with a
# single space separator, matching how YAML folded scalars are read.
#
# Exit 0 = all under limit, Exit 1 = at least one violation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAX_LEN=1024

errors=()
warnings=()

extract_description() {
  awk '
    /^---$/ { fm++; if (fm == 2) exit; next }
    fm == 1 && started && /^[a-z_]+:/ { exit }
    fm == 1 && started && /^---$/ { exit }
    fm == 1 && started { printf " %s", $0; next }
    fm == 1 && /^description:/ {
      sub(/^description: */, "")
      printf "%s", $0
      started = 1
    }
  ' "$1"
}

while IFS= read -r -d '' skill_file; do
  rel="${skill_file#"$REPO_ROOT/"}"
  desc=$(extract_description "$skill_file")
  len=${#desc}

  if [[ "$len" -gt "$MAX_LEN" ]]; then
    errors+=("OVER ($len > $MAX_LEN): $rel")
  elif [[ "$len" -gt $((MAX_LEN - 100)) ]]; then
    warnings+=("NEAR ($len, ${MAX_LEN} limit): $rel")
  fi
done < <(find "$REPO_ROOT/skills" "$REPO_ROOT/plugins" -name SKILL.md -type f -print0 2>/dev/null)

if [[ ${#warnings[@]} -gt 0 ]]; then
  echo "SKILL.md description length warnings (within 100 chars of limit):"
  printf '  %s\n' "${warnings[@]}"
  echo ""
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "SKILL.md description length validation failed:"
  printf '  %s\n' "${errors[@]}"
  echo ""
  echo "Fix: trim each description to <= $MAX_LEN characters. The Codex plugin"
  echo "loader rejects anything longer with 'invalid description: exceeds"
  echo "maximum length of $MAX_LEN characters'."
  exit 1
fi

echo "All SKILL.md descriptions within $MAX_LEN-char limit."
