#!/usr/bin/env bash
# Validates that every skill in skills/ has a mirrored copy in plugins/.
# Plugin copies intentionally omit the "Session Rules" footer (inherited from
# the host workspace CLAUDE.md), so we strip that section before comparing.
#
# Skill-less folders under skills/ (no SKILL.md, e.g. skills/react-shared/) are
# treated as shared-references libraries: they get no plugin.json and no
# marketplace entry, but their files must be mirrored into every consuming
# plugin (any plugin whose canonical SKILL.md mentions the shared folder
# path).
#
# Exit 0 = all synced, Exit 1 = drift detected.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=()

# Strip "## Session Rules" section and any trailing blank lines
strip_session_rules() {
  sed '/^## Session Rules$/,$d' "$1" | awk 'NF{p=1} p' | tail -r | awk 'NF{p=1} p' | tail -r
}

is_shared_refs() {
  [[ ! -f "$1/SKILL.md" ]]
}

# ---------------------------------------------------------------------------
# Pass 1: regular skills (folders with SKILL.md) — full plugin mirror required
# ---------------------------------------------------------------------------
for skill_dir in "$REPO_ROOT"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  is_shared_refs "$skill_dir" && continue

  plugin_skill_dir="$REPO_ROOT/plugins/$skill_name/skills/$skill_name"
  plugin_json="$REPO_ROOT/plugins/$skill_name/.claude-plugin/plugin.json"

  if [[ ! -f "$plugin_json" ]]; then
    errors+=("MISSING: plugins/$skill_name/.claude-plugin/plugin.json")
    continue
  fi

  while IFS= read -r -d '' file; do
    rel="${file#"$skill_dir"}"
    mirror="$plugin_skill_dir/$rel"
    if [[ ! -f "$mirror" ]]; then
      errors+=("MISSING: plugins/$skill_name/skills/$skill_name/$rel")
    elif [[ "$rel" == "SKILL.md" ]]; then
      if ! diff <(strip_session_rules "$file") <(strip_session_rules "$mirror") >/dev/null 2>&1; then
        errors+=("DRIFT:   plugins/$skill_name/skills/$skill_name/$rel differs from skills/$skill_name/$rel (ignoring Session Rules)")
      fi
    elif ! diff -q "$file" "$mirror" >/dev/null 2>&1; then
      errors+=("DRIFT:   plugins/$skill_name/skills/$skill_name/$rel differs from skills/$skill_name/$rel")
    fi
  done < <(find "$skill_dir" -type f -print0)
done

# ---------------------------------------------------------------------------
# Pass 2: shared-references folders — mirrored only into consuming plugins
# ---------------------------------------------------------------------------
for shared_dir in "$REPO_ROOT"/skills/*/; do
  shared_name=$(basename "$shared_dir")
  is_shared_refs "$shared_dir" || continue

  consumers=()
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    consumer_name=$(basename "$skill_dir")
    consumer_skill_md="$skill_dir/SKILL.md"
    [[ ! -f "$consumer_skill_md" ]] && continue
    if grep -qF "skills/$shared_name/" "$consumer_skill_md"; then
      consumers+=("$consumer_name")
    fi
  done

  if [[ ${#consumers[@]} -eq 0 ]]; then
    errors+=("ORPHAN:  skills/$shared_name/ is shared-refs but no plugin SKILL.md references it")
    continue
  fi

  for consumer_name in "${consumers[@]}"; do
    while IFS= read -r -d '' file; do
      rel="${file#"$shared_dir"}"
      mirror="$REPO_ROOT/plugins/$consumer_name/skills/$shared_name/$rel"
      if [[ ! -f "$mirror" ]]; then
        errors+=("MISSING: plugins/$consumer_name/skills/$shared_name/$rel (shared from skills/$shared_name/)")
      elif ! diff -q "$file" "$mirror" >/dev/null 2>&1; then
        errors+=("DRIFT:   plugins/$consumer_name/skills/$shared_name/$rel differs from skills/$shared_name/$rel")
      fi
    done < <(find "$shared_dir" -type f -print0)
  done
done

# ---------------------------------------------------------------------------
# marketplace.json — only regular skills require an entry
# ---------------------------------------------------------------------------
marketplace_json="$REPO_ROOT/.claude-plugin/marketplace.json"
if [[ -f "$marketplace_json" ]]; then
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    is_shared_refs "$skill_dir" && continue
    if ! grep -q "\"name\": \"$skill_name\"" "$marketplace_json"; then
      errors+=("MARKETPLACE: $skill_name missing from .claude-plugin/marketplace.json")
    fi
  done
fi

# ---------------------------------------------------------------------------
# llms.txt — index every SKILL.md (regular skills only) and every reference
# ---------------------------------------------------------------------------
llms_txt="$REPO_ROOT/llms.txt"
if [[ -f "$llms_txt" ]]; then
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    is_shared_refs "$skill_dir" && continue
    skill_link="skills/$skill_name/SKILL.md"
    if ! grep -qF "($skill_link)" "$llms_txt"; then
      errors+=("LLMS.TXT:    $skill_link missing from llms.txt")
    fi
  done

  while IFS= read -r -d '' ref_file; do
    rel_path="${ref_file#"$REPO_ROOT/"}"
    if ! grep -qF "($rel_path)" "$llms_txt"; then
      errors+=("LLMS.TXT:    $rel_path missing from llms.txt")
    fi
  done < <(find "$REPO_ROOT/skills" -path '*/references/*' -type f -print0)
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "Plugin sync validation failed:"
  printf '  %s\n' "${errors[@]}"
  echo ""
  echo "Fix: copy changed files from skills/ to plugins/, then update marketplace.json and llms.txt before committing."
  exit 1
fi

echo "All skills synced with plugins, marketplace, and llms.txt."
