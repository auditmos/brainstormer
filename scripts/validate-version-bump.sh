#!/usr/bin/env bash
# Blocks a commit that changes a plugin's content without bumping its version.
#
# The installed-plugin cache keys on plugin.json "version"
# (~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/), so any content
# change shipped under an unchanged version silently never reaches users who
# already installed the plugin.
#
# Works on the STAGED diff (git diff --cached): for every plugins/<name>/
# path that is staged, the staged plugin.json "version" must differ from the
# HEAD version. New plugins (no version at HEAD) pass. With nothing staged
# (e.g. CI re-running the hook on a checked-out tree) the check passes
# vacuously — CI enforces tree-state sync; this hook enforces bump
# discipline at commit time.
#
# Exit 0 = ok, Exit 1 = at least one plugin changed without a bump.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

errors=()

staged=$(git diff --cached --name-only 2>/dev/null || true)
if [[ -z "$staged" ]]; then
  echo "Version bump check: nothing staged, skipping."
  exit 0
fi

json_version() {  # reads plugin.json content on stdin, prints the version
  sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' | head -1
}

while IFS= read -r pdir; do
  [[ -z "$pdir" ]] && continue
  plugin_name=$(basename "$pdir")
  pj="plugins/$plugin_name/.claude-plugin/plugin.json"
  old_version=$(git show "HEAD:$pj" 2>/dev/null | json_version || true)
  new_version=$(git show ":$pj" 2>/dev/null | json_version || true)
  [[ -z "$old_version" ]] && continue   # new plugin — nothing to bump against
  if [[ "$old_version" == "$new_version" ]]; then
    errors+=("NO-BUMP: plugins/$plugin_name/ content is staged but plugin.json version stays $old_version")
  fi
done < <(grep -oE '^plugins/[^/]+' <<<"$staged" | sort -u)

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "Version bump validation failed:"
  printf '  %s\n' "${errors[@]}"
  echo ""
  echo "Bump \"version\" in each listed plugin.json AND the matching version:"
  echo "in the skill's SKILL.md frontmatter (both trees), or installed caches"
  echo "will keep serving the old copy. Semver: patch = fix, minor = additive,"
  echo "major = breaking/removed behavior."
  exit 1
fi

echo "All staged plugin changes carry a version bump."
