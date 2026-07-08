#!/usr/bin/env bash
#
# scripts/hook-precommit-sync.sh
#
# PreToolUse commit gate shared by Claude Code (.claude/settings.json) and
# Codex (.codex/hooks.json). It runs every repo validator BEFORE a
# `git commit` Bash tool call and BLOCKS the commit if any validator fails.
#
# Three non-obvious reasons this wrapper exists (rather than pointing the
# hook straight at a validator):
#
#   1. Command scoping. A PreToolUse `matcher` filters by TOOL NAME only
#      (e.g. "Bash") — never by the command text. So the old
#      "Bash(git commit*)" matcher never matched the tool name "Bash" and
#      the hook never fired. Claude can additionally scope with an `if`
#      field, but Codex ignores `if`. So this wrapper reads the hook payload
#      on stdin and decides for itself whether the command is a commit —
#      one mechanism that works for both agents.
#
#   2. Blocking semantics. For PreToolUse, both Claude and Codex BLOCK the
#      tool call ONLY on EXIT CODE 2 (stderr is fed back to the agent). Any
#      other non-zero exit is a non-blocking warning that lets the commit
#      proceed. The validators exit 1 on drift, so we translate 1 -> 2.
#
#   3. Single source of truth. It runs .githooks/pre-commit — the same four
#      validators the native git hook runs — so new validators are picked up
#      automatically and enforcement is identical whether or not a clone has
#      `git config core.hooksPath .githooks` set.
#
# The payload JSON path (.tool_input.command) is identical for the Claude and
# Codex shell tools.

set -uo pipefail

payload="$(cat)"

# Extract the tool's command string from the hook payload. Prefer jq (used by
# the Codex hook convention), fall back to python3; if neither is available,
# fall back to the raw payload so the commit test below over-matches
# (fail safe: validate rather than silently skip).
extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$payload" \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null \
      && return 0
  fi
  printf '%s' "$payload"
}

cmd="$(extract_command)"

# Gate only real commits. Match `git commit` as a whole word at the start of
# the command or after a shell separator/whitespace, so compound commands
# (`git add -A && git commit -m ...`) are covered while avoiding false hits on
# `git committee`, `gitcommit`, etc.
commit_re='(^|[;&|[:space:]])git[[:space:]]+commit($|[[:space:]])'
if [[ ! "$cmd" =~ $commit_re ]]; then
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fi
cd "$repo_root" || exit 0

if output="$("$repo_root/.githooks/pre-commit" 2>&1)"; then
  exit 0
fi

{
  echo "── commit blocked: repo validators failed ──"
  echo "$output"
  echo ""
  echo "Sync skills/ -> plugins/ (and marketplace.json + llms.txt), then retry,"
  echo "or run 'git commit --no-verify' to override intentionally."
} >&2
exit 2
