#!/usr/bin/env bash
# detect-curriculum.sh — Classify a directory as TMB curriculum state.
#
# Output: JSON
#   { state: "fresh"      — empty or non-existent dir
#          | "v0.3-partial"  — spine + briefs but missing module pages
#          | "v0.3-complete" — spine + briefs + every module page present
#          | "v0.4-partial"  — same plus research.yaml
#          | "v0.4-complete" — research.yaml + every module page
#          | "v0.2"        — modules/*/README.md detected
#          | "non-tmb"     — non-empty dir that doesn't match TMB shape,
#     module_count: N (number of briefs found),
#     missing_pages: [slug,...] (only when state == *-partial) }
#
# Exit always 0; classification is in stdout JSON.
# This is the single source of truth for /tmb:create resume detection
# and /tmb:review precondition checks.

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"state":"error","error":"usage: detect-curriculum.sh <dir>"}' >&2; exit 2; }
command -v jq >/dev/null || { echo '{"state":"error","error":"jq not found"}' >&2; exit 2; }

# Non-existent or empty.
if [ ! -d "$ROOT" ]; then
  jq -nc '{state: "fresh", module_count: 0, missing_pages: []}'; exit 0
fi
if [ -z "$(ls -A "$ROOT" 2>/dev/null)" ]; then
  jq -nc '{state: "fresh", module_count: 0, missing_pages: []}'; exit 0
fi

# v0.2 detection.
if ls "$ROOT"/modules/*/README.md >/dev/null 2>&1; then
  jq -nc '{state: "v0.2", module_count: 0, missing_pages: []}'; exit 0
fi

# v0.3+ requires spine + briefs.
spine="$ROOT/curriculum_spine.md"
briefs_dir="$ROOT/briefs"
if [ ! -f "$spine" ] || [ ! -d "$briefs_dir" ]; then
  jq -nc '{state: "non-tmb", module_count: 0, missing_pages: []}'; exit 0
fi

# Count briefs and check pages.
shopt -s nullglob
briefs=("$briefs_dir"/*.yaml)
count=${#briefs[@]}
missing="[]"
for b in "${briefs[@]}"; do
  slug=$(basename "$b" .yaml)
  page="$ROOT/site/content/modules/$slug/_index.md"
  [ -f "$page" ] || missing=$(jq -c --arg s "$slug" '. + [$s]' <<< "$missing")
done

has_research="false"
[ -f "$ROOT/research.yaml" ] && has_research="true"

if [ "$(jq 'length' <<< "$missing")" -eq 0 ]; then
  state=$( [ "$has_research" = "true" ] && echo "v0.4-complete" || echo "v0.3-complete" )
else
  state=$( [ "$has_research" = "true" ] && echo "v0.4-partial" || echo "v0.3-partial" )
fi

jq -nc --arg s "$state" --argjson c "$count" --argjson m "$missing" \
  '{state: $s, module_count: $c, missing_pages: $m}'
