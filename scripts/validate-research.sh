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
# Each entry has at least one reference link with http(s) URL. Glossary
# entries without external references strand the reader at the inline
# definition with no way to learn more — see references/research-schema.md.
no_refs=$(yq '[.glossary[] | select((.references // []) | length == 0)] | length' "$R")
[ "$no_refs" -gt 0 ] && add "$no_refs glossary entries missing references[] (every term needs at least one external link)"
bad_refs=$(yq '[.glossary[] | select((.references // []) | length > 0) | .references[] | select((.url // "") | test("^https?://") | not)] | length' "$R")
[ "$bad_refs" -gt 0 ] && add "$bad_refs glossary references have non-http(s) urls"
no_label=$(yq '[.glossary[] | .references[]? | select((.label // "") == "")] | length' "$R")
[ "$no_label" -gt 0 ] && add "$no_label glossary references missing label"

# Sources >= 3 with sections[].
sc=$(yq '.sources | length' "$R")
[ "$sc" -lt 3 ] && add "sources has $sc entries (need >= 3)"
bad_src=$(yq '[.sources[] | select((.url // "") | test("^https?://") | not)] | length' "$R")
[ "$bad_src" -gt 0 ] && add "$bad_src sources have non-http(s) urls"
no_sec=$(yq '[.sources[] | select((.sections // []) | length == 0)] | length' "$R")
[ "$no_sec" -gt 0 ] && add "$no_sec sources have no sections"

# Excerpts: every section SHOULD carry a 1-3 sentence verbatim quote so module-
# builders can produce inline footnote citations (not bare URL pointers). Half
# the sections missing excerpts is a coverage failure — modules will read as
# AI-generated prose with footnotes that say nothing more than "see <URL>".
sec_total=$(yq '[.sources[].sections[]?] | length' "$R")
sec_no_excerpt=$(yq '[.sources[].sections[]? | select((.excerpt // "") == "")] | length' "$R")
if [ "$sec_total" -gt 0 ] && [ "$sec_no_excerpt" -gt 0 ]; then
  ratio=$(( sec_no_excerpt * 100 / sec_total ))
  if [ "$ratio" -gt 50 ]; then
    add "$sec_no_excerpt of $sec_total source sections missing excerpt (need >= 50% coverage so module-builders can cite quoted passages, not bare URLs)"
  fi
fi

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
