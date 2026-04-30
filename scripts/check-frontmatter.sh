#!/usr/bin/env bash
# check-frontmatter.sh — Verify each module's index.md frontmatter matches its brief.
#
# For every briefs/*.yaml, opens site/content/modules/<slug>/index.md and
# compares brief-sourced fields. Emits a JSON report of every mismatch and
# every missing page.
#
# Output: JSON
#   { ok: bool,
#     missing_pages: [ slug ... ],
#     mismatches:    [ { module, field, brief_value, frontmatter_value } ... ] }
#
# Exit 0 on full match; 1 on any mismatch or missing page; 2 on setup error.

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: check-frontmatter.sh <root>"}' >&2; exit 2; }
command -v yq >/dev/null || { echo '{"ok":false,"error":"yq not found"}' >&2; exit 2; }
command -v jq >/dev/null || { echo '{"ok":false,"error":"jq not found"}' >&2; exit 2; }

BRIEFS_DIR="$ROOT/briefs"
[ -d "$BRIEFS_DIR" ] || { echo "{\"ok\":false,\"error\":\"$BRIEFS_DIR missing\"}" >&2; exit 2; }

# Fields that must match between brief and frontmatter (string scalars).
FIELDS=(
  weight title driving_question
  contrast.alternative contrast.when_alternative_wins
  prior_ends_with next_expects
)

missing="[]"; mismatches="[]"
shopt -s nullglob

for b in "$BRIEFS_DIR"/*.yaml; do
  slug=$(basename "$b" .yaml)
  page="$ROOT/site/content/modules/$slug/index.md"
  if [ ! -f "$page" ]; then
    missing=$(jq -c --arg s "$slug" '. + [$s]' <<< "$missing")
    continue
  fi

  fm=$(awk '/^---/{c++; next} c==1' "$page")

  for f in "${FIELDS[@]}"; do
    bv=$(yq ".${f}" "$b" 2>/dev/null || echo "")
    fv=$(printf '%s' "$fm" | yq ".${f}" - 2>/dev/null || echo "")
    if [ "$bv" != "$fv" ]; then
      mismatches=$(jq -c --arg m "$slug" --arg field "$f" --arg b "$bv" --arg fv "$fv" \
        '. + [{module: $m, field: $field, brief_value: $b, frontmatter_value: $fv}]' \
        <<< "$mismatches")
    fi
  done
done

if [ "$(jq 'length' <<< "$missing")" -eq 0 ] && [ "$(jq 'length' <<< "$mismatches")" -eq 0 ]; then
  jq -nc '{ok: true, missing_pages: [], mismatches: []}'
  exit 0
fi
jq -nc --argjson mp "$missing" --argjson mm "$mismatches" \
  '{ok: false, missing_pages: $mp, mismatches: $mm}'
exit 1
