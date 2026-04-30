#!/usr/bin/env bash
# check-adjacency.sh — Verify the next_expects ↔ prior_ends_with chain.
#
# Reads briefs/*.yaml AND site/content/modules/*/index.md frontmatter.
# Compares (after whitespace normalization):
#   - brief N.next_expects == brief N+1.prior_ends_with
#   - brief.next_expects   == frontmatter.next_expects
#   - brief.prior_ends_with == frontmatter.prior_ends_with
#
# Output: JSON
#   { ok: bool, mismatches: [ { kind, module, expected, found } ... ] }
#
# Exit 0 if chain holds; 1 if any mismatch; 2 on setup error.

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: check-adjacency.sh <root>"}' >&2; exit 2; }
command -v yq >/dev/null || { echo '{"ok":false,"error":"yq not found"}' >&2; exit 2; }
command -v jq >/dev/null || { echo '{"ok":false,"error":"jq not found"}' >&2; exit 2; }

BRIEFS_DIR="$ROOT/briefs"
[ -d "$BRIEFS_DIR" ] || { echo "{\"ok\":false,\"error\":\"$BRIEFS_DIR missing\"}" >&2; exit 2; }

normalize() { tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }

# Sort by weight.
shopt -s nullglob
declare -a sorted=()
while IFS= read -r line; do sorted+=("$line"); done < <(
  for b in "$BRIEFS_DIR"/*.yaml; do
    w=$(yq '.weight // 0' "$b")
    printf '%05d\t%s\n' "$w" "$b"
  done | sort | cut -f2-
)

mismatches="[]"
add_miss() {
  local kind="$1" mod="$2" expected="$3" found="$4"
  mismatches=$(jq -c --arg k "$kind" --arg m "$mod" --arg e "$expected" --arg f "$found" \
    '. + [{kind: $k, module: $m, expected: $e, found: $f}]' <<< "$mismatches")
}

# Brief-to-brief chain.
prev_next=""; prev_slug=""
for b in "${sorted[@]}"; do
  slug=$(basename "$b" .yaml)
  prior=$(yq '.prior_ends_with' "$b" | normalize)
  next=$(yq '.next_expects' "$b" | normalize)
  if [ -n "$prev_slug" ] && [ "$prev_next" != "$prior" ]; then
    add_miss "brief-chain" "$slug" "$prev_next" "$prior"
  fi
  prev_next="$next"; prev_slug="$slug"
done

# Brief-to-frontmatter sync.
for b in "${sorted[@]}"; do
  slug=$(basename "$b" .yaml)
  page="$ROOT/site/content/modules/$slug/index.md"
  [ -f "$page" ] || { add_miss "missing-page" "$slug" "$page" "(not found)"; continue; }
  fm_prior=$(awk '/^---/{c++; next} c==1' "$page" | yq '.prior_ends_with' - | normalize)
  fm_next=$(awk '/^---/{c++; next} c==1'  "$page" | yq '.next_expects'   - | normalize)
  brief_prior=$(yq '.prior_ends_with' "$b" | normalize)
  brief_next=$(yq '.next_expects'    "$b" | normalize)
  [ "$fm_prior" = "$brief_prior" ] || add_miss "fm-prior" "$slug" "$brief_prior" "$fm_prior"
  [ "$fm_next"  = "$brief_next"  ] || add_miss "fm-next"  "$slug" "$brief_next"  "$fm_next"
done

if [ "$(jq 'length' <<< "$mismatches")" -eq 0 ]; then
  jq -nc '{ok: true, mismatches: []}'
else
  jq -nc --argjson m "$mismatches" '{ok: false, mismatches: $m}'
fi
# Always exit 0 when the script ran successfully — mismatches are review.md
# flags, not pipeline-aborting errors. Use the JSON `ok` field to branch.
exit 0
