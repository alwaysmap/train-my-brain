#!/usr/bin/env bash
# validate-research.sh — Gate on research.yaml completeness.
#
# Mirrors the "Required fields" section of references/research-schema.md.
# The researcher agent calls this before declaring success; the orchestrator
# can call it independently as a sanity check.
#
# Output: JSON
#   { ok: bool, gaps: [ string ... ] }
# Exit 0 if research.yaml passes; 1 if any gap; 2 on setup error.

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: validate-research.sh <root>"}' >&2; exit 2; }
command -v yq >/dev/null || { echo '{"ok":false,"error":"yq not found"}' >&2; exit 2; }
command -v jq >/dev/null || { echo '{"ok":false,"error":"jq not found"}' >&2; exit 2; }

R="$ROOT/research.yaml"
[ -f "$R" ] || { echo "{\"ok\":false,\"error\":\"$R missing\"}" >&2; exit 2; }

gaps="[]"
add() { gaps=$(jq -c --arg g "$1" '. + [$g]' <<< "$gaps"); }

# Top-level scalars.
for f in topic goal created researcher_version; do
  v=$(yq ".${f}" "$R")
  case "$v" in ""|null) add "${f} is empty" ;; esac
done

# Glossary >= 5.
gc=$(yq '.glossary | length' "$R")
[ "$gc" -lt 5 ] && add "glossary has $gc entries (need >= 5)"
# Each entry has term + definition.
bad=$(yq '[.glossary[] | select((.term // "") == "" or (.definition // "") == "")] | length' "$R")
[ "$bad" -gt 0 ] && add "$bad glossary entries missing term or definition"

# Sources >= 3 with sections[].
sc=$(yq '.sources | length' "$R")
[ "$sc" -lt 3 ] && add "sources has $sc entries (need >= 3)"
bad_src=$(yq '[.sources[] | select((.url // "") | test("^https?://") | not)] | length' "$R")
[ "$bad_src" -gt 0 ] && add "$bad_src sources have non-http(s) urls"
no_sec=$(yq '[.sources[] | select((.sections // []) | length == 0)] | length' "$R")
[ "$no_sec" -gt 0 ] && add "$no_sec sources have no sections"

# Concept map >= 5.
cc=$(yq '.concept_map | length' "$R")
[ "$cc" -lt 5 ] && add "concept_map has $cc entries (need >= 5)"

# Contrasts >= 2 with all four fields.
xc=$(yq '.contrasts | length' "$R")
[ "$xc" -lt 2 ] && add "contrasts has $xc entries (need >= 2)"
bad_x=$(yq '[.contrasts[] | select((.this // "") == "" or (.alternative // "") == "" or (.when_alt_wins // "") == "" or (.when_this_wins // "") == "")] | length' "$R")
[ "$bad_x" -gt 0 ] && add "$bad_x contrasts missing required fields"

# Authorities >= 2.
ac=$(yq '.authorities | length' "$R")
[ "$ac" -lt 2 ] && add "authorities has $ac entries (need >= 2)"

if [ "$(jq 'length' <<< "$gaps")" -eq 0 ]; then
  jq -nc '{ok: true, gaps: []}'
  exit 0
fi
jq -nc --argjson g "$gaps" '{ok: false, gaps: $g}'
exit 1
