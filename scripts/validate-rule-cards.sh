#!/usr/bin/env bash
# Validates rule-card frontmatter under skills/react-shared/references/cards/.
# Schema (per PRD #1):
#   Mandatory: id, category, detect, source
#   Optional:  (bad/good live as inline body sections, not frontmatter fields)
# Categories: effects rerenders shadcn a11y tanstack server-client typescript styling
# Detect:     regex ast llm-judge
# Body must reference the source URL host (self-contained citation).
# Exit 0 = all cards valid, Exit 1 = violations found.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CARDS_DIR="$REPO_ROOT/skills/react-shared/references/cards"

VALID_CATEGORIES="effects rerenders shadcn a11y tanstack server-client typescript styling"
VALID_DETECT="regex ast llm-judge"

errors=()
card_count=0

if [[ ! -d "$CARDS_DIR" ]]; then
  echo "Rule card validation failed:"
  echo "  cards directory not found: ${CARDS_DIR#"$REPO_ROOT/"}"
  exit 1
fi

# Extract a single scalar frontmatter field (first --- ... --- block).
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

# Print everything after the closing frontmatter ---.
extract_body() {
  awk '
    /^---$/ { fm++; next }
    fm >= 2 { print }
  ' "$1"
}

while IFS= read -r -d '' card; do
  # The index.md lives in the same directory but is not a rule card; skip it
  # in the per-card schema loop and validate it separately below.
  if [[ "$(basename "$card")" == "index.md" ]]; then
    continue
  fi
  card_count=$((card_count + 1))
  rel="${card#"$REPO_ROOT/"}"

  id=$(extract_field "$card" id)
  category=$(extract_field "$card" category)
  detect=$(extract_field "$card" detect)
  source=$(extract_field "$card" source)

  [[ -z "$id" ]]       && errors+=("$rel: missing 'id'")
  [[ -z "$category" ]] && errors+=("$rel: missing 'category'")
  [[ -z "$detect" ]]   && errors+=("$rel: missing 'detect'")
  [[ -z "$source" ]]   && errors+=("$rel: missing 'source'")

  if [[ -n "$category" ]] && [[ " $VALID_CATEGORIES " != *" $category "* ]]; then
    errors+=("$rel: invalid category '$category' (must be one of: $VALID_CATEGORIES)")
  fi

  if [[ -n "$detect" ]] && [[ " $VALID_DETECT " != *" $detect "* ]]; then
    errors+=("$rel: invalid detect '$detect' (must be one of: $VALID_DETECT)")
  fi

  # id must match the slash-pathed location under cards/.
  expected_id="${rel#skills/react-shared/references/cards/}"
  expected_id="${expected_id%.md}"
  if [[ -n "$id" && "$id" != "$expected_id" ]]; then
    errors+=("$rel: id '$id' does not match path-derived id '$expected_id'")
  fi

  if [[ -n "$source" && ! "$source" =~ ^https?:// ]]; then
    errors+=("$rel: source '$source' is not a URL")
  fi

  body="$(extract_body "$card")"
  if [[ -z "${body//[[:space:]]/}" ]]; then
    errors+=("$rel: body is empty (card must be self-contained)")
  elif [[ -n "$source" ]]; then
    src_host="${source#http://}"
    src_host="${src_host#https://}"
    src_host="${src_host%%/*}"
    if [[ -n "$src_host" && "$body" != *"$src_host"* ]]; then
      errors+=("$rel: body does not cite source host '$src_host'")
    fi
  fi
done < <(find "$CARDS_DIR" -type f -name '*.md' -print0)

if [[ "$card_count" -eq 0 ]]; then
  errors+=("no cards found under skills/react-shared/references/cards/")
fi

# Index file — bidirectional consistency between cards/ tree and index.md.
INDEX_FILE="$CARDS_DIR/index.md"
INDEX_REL="${INDEX_FILE#"$REPO_ROOT/"}"
if [[ ! -f "$INDEX_FILE" ]]; then
  errors+=("missing index file: $INDEX_REL")
else
  # Every card file under cards/ must be referenced in index.md by its
  # category-prefixed relative path (e.g. "(effects/foo.md)").
  while IFS= read -r -d '' card; do
    [[ "$(basename "$card")" == "index.md" ]] && continue
    rel_to_cards="${card#"$CARDS_DIR/"}"
    if ! grep -qF "($rel_to_cards)" "$INDEX_FILE"; then
      errors+=("$INDEX_REL: card '$rel_to_cards' not listed")
    fi
  done < <(find "$CARDS_DIR" -type f -name '*.md' -print0)

  # Every link target in index.md must point to a real card file.
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if [[ ! -f "$CARDS_DIR/$target" ]]; then
      errors+=("$INDEX_REL: link target '$target' does not exist")
    fi
  done < <(grep -oE '\(([a-z][a-z0-9-]*/[a-z0-9-]+\.md)\)' "$INDEX_FILE" | tr -d '()')
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "Rule card validation failed:"
  printf '  %s\n' "${errors[@]}"
  exit 1
fi

echo "All $card_count rule cards valid (index OK)."
