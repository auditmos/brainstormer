#!/usr/bin/env bash
# Validates that every skill in skills/ has a mirrored copy in plugins/
# Plugin copies intentionally omit the "Session Rules" footer (inherited from
# the host workspace CLAUDE.md), so we strip that section before comparing.
# Exit 0 = all synced, Exit 1 = drift detected

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=()

# Strip "## Session Rules" section and any trailing blank lines
strip_session_rules() {
  # Remove Session Rules section, then trim trailing blank lines
  sed '/^## Session Rules$/,$d' "$1" | awk 'NF{p=1} p' | tac | awk 'NF{p=1} p' | tac
}

for skill_dir in "$REPO_ROOT"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  plugin_skill_dir="$REPO_ROOT/plugins/$skill_name/skills/$skill_name"
  plugin_json="$REPO_ROOT/plugins/$skill_name/.claude-plugin/plugin.json"

  # Check plugin.json exists
  if [[ ! -f "$plugin_json" ]]; then
    errors+=("MISSING: plugins/$skill_name/.claude-plugin/plugin.json")
    continue
  fi

  # Diff all skill files
  while IFS= read -r -d '' file; do
    rel="${file#"$skill_dir"}"
    mirror="$plugin_skill_dir/$rel"
    if [[ ! -f "$mirror" ]]; then
      errors+=("MISSING: plugins/$skill_name/skills/$skill_name/$rel")
    elif [[ "$rel" == "SKILL.md" ]]; then
      # Compare SKILL.md without Session Rules footer
      if ! diff <(strip_session_rules "$file") <(strip_session_rules "$mirror") >/dev/null 2>&1; then
        errors+=("DRIFT:   plugins/$skill_name/skills/$skill_name/$rel differs from skills/$skill_name/$rel (ignoring Session Rules)")
      fi
    elif ! diff -q "$file" "$mirror" >/dev/null 2>&1; then
      errors+=("DRIFT:   plugins/$skill_name/skills/$skill_name/$rel differs from skills/$skill_name/$rel")
    fi
  done < <(find "$skill_dir" -type f -print0)
done

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "Plugin sync validation failed:"
  printf '  %s\n' "${errors[@]}"
  echo ""
  echo "Fix: copy changed files from skills/ to plugins/ before committing."
  exit 1
fi

echo "All skills synced with plugins/."
