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

  # Bulk-fixture opt-out: a directory containing a `_bulk-fixture` marker
  # file is treated as a presence-only fixture mass (e.g., 60 stub TSX
  # files exercising a threshold prompt). Per-file llms.txt indexing
  # would inflate the index 60-fold without adding navigational value;
  # instead the marker file itself is indexed and the validator skips the
  # subtree.
  bulk_roots=()
  while IFS= read -r -d '' marker; do
    bulk_roots+=("$(dirname "$marker")/")
  done < <(find "$REPO_ROOT/skills" -path '*/references/*' -type f -name '_bulk-fixture' -print0)

  is_under_bulk() {
    local file="$1"
    for root in "${bulk_roots[@]}"; do
      if [[ "$file" == "$root"* && "$file" != "${root}_bulk-fixture" ]]; then
        return 0
      fi
    done
    return 1
  }

  while IFS= read -r -d '' ref_file; do
    rel_path="${ref_file#"$REPO_ROOT/"}"
    if is_under_bulk "$ref_file"; then
      continue
    fi
    if ! grep -qF "($rel_path)" "$llms_txt"; then
      errors+=("LLMS.TXT:    $rel_path missing from llms.txt")
    fi
  done < <(find "$REPO_ROOT/skills" -path '*/references/*' -type f -print0)

  # -------------------------------------------------------------------------
  # Version-marker currency: the presence checks above prove each SKILL.md is
  # LINKED from llms.txt, but not that the entry TEXT is current. The observed
  # drift (skill shipped Phase 3 while its llms.txt line still said Phase 2b)
  # slipped through with a green checkbox. Rule: every `Phase N` token in a
  # skill's frontmatter description must also appear in that skill's llms.txt
  # entry. Curated summaries stay hand-written; only the version marker is
  # mechanically pinned. Low false-positive — only react-audit ships a Phase
  # marker today (verified 2026-07-09).
  # -------------------------------------------------------------------------
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    is_shared_refs "$skill_dir" && continue
    skill_link="skills/$skill_name/SKILL.md"
    llms_line=$(grep -F "($skill_link)" "$llms_txt" || true)
    [[ -z "$llms_line" ]] && continue   # missing-entry already reported above
    desc=$(sed -n 's/^description: *//p' "$skill_dir/SKILL.md" | head -1)
    while IFS= read -r phase; do
      [[ -z "$phase" ]] && continue
      if ! grep -qF "$phase" <<<"$llms_line"; then
        errors+=("LLMS.TXT:    $skill_link description says \"$phase\" but its llms.txt entry does not (stale version marker)")
      fi
    done < <(grep -oE 'Phase [0-9]+[a-z]?' <<<"$desc" | sort -u)
  done

  # -------------------------------------------------------------------------
  # Dead-link guard: the complement of the presence checks — every skills/
  # link target written into llms.txt must resolve to a real file, so a
  # rename or typo can't leave a phantom entry pointing at nothing.
  # -------------------------------------------------------------------------
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if [[ ! -e "$REPO_ROOT/$target" ]]; then
      errors+=("LLMS.TXT:    dead link -> $target (referenced in llms.txt, file missing)")
    fi
  done < <(grep -oE '\]\(skills/[^)]+\)' "$llms_txt" | sed -E 's/^\]\(//; s/\)$//' | sort -u)
fi

# ---------------------------------------------------------------------------
# Intra-skill link guard: every relative .md link inside a skills/ markdown
# file must resolve to a real file. The dead-link guard above covers only
# llms.txt — without this check, deleting or renaming a reference file breaks
# the SKILL.md (or reference-to-reference) link silently at skill runtime.
# Canonical tree only: pass 1/2 byte-sync guarantees mirrors match.
# ---------------------------------------------------------------------------
while IFS= read -r -d '' md_file; do
  rel_file="${md_file#"$REPO_ROOT/"}"
  md_dir=$(dirname "$md_file")
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    target="${target%%#*}"                          # drop #fragment
    case "$target" in
      ''|http://*|https://*|mailto:*|/*) continue ;; # external or absolute
      *'{'*|*'<'*|*'...'*|*'…'*) continue ;;         # template placeholders
    esac
    [[ "$target" != *.md ]] && continue              # only markdown targets
    if [[ "$target" == skills/* ]]; then
      resolved="$REPO_ROOT/$target"                  # repo-root-relative (shared refs)
    else
      resolved="$md_dir/$target"                     # file-relative
    fi
    if [[ ! -f "$resolved" ]]; then
      errors+=("LINK:        $rel_file -> $target (target missing)")
    fi
  done < <(grep -oE '\]\([^)]+\)' "$md_file" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//' | sort -u)
done < <(find "$REPO_ROOT/skills" -type f -name '*.md' -print0)

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "Plugin sync validation failed:"
  printf '  %s\n' "${errors[@]}"
  echo ""
  echo "Fix: copy changed files from skills/ to plugins/, then update marketplace.json and llms.txt before committing."
  exit 1
fi

echo "All skills synced with plugins, marketplace, and llms.txt."
