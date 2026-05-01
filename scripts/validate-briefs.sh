#!/usr/bin/env bash
# validate-briefs.sh — Brief completeness gate.
#
# Walks every briefs/*.yaml under <curriculum_root> and verifies:
#   1. No null/empty/placeholder fields
#   2. concepts has 3..5 items
#   3. reading.primary.url + reading.secondary.url start with http(s)://
#   4. exercise_goal contains at least two [TODO: markers
#   5. Adjacency chain: brief N.next_expects == brief N+1.prior_ends_with
#
# Output:
#   stdout — JSON: { ok: bool, gaps: [ { brief, issue } ... ] }
#   exit 0 if all briefs pass; 1 if any gap; 2 if usage/setup error
#
# Replaces the in-agent gate logic from tmb-designer.

set -euo pipefail

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  echo '{"ok":false,"error":"usage: validate-briefs.sh <curriculum_root>"}' >&2
  exit 2
fi
if ! command -v yq >/dev/null 2>&1; then
  echo '{"ok":false,"error":"yq not found on PATH"}' >&2
  exit 2
fi

BRIEFS_DIR="$ROOT/briefs"
if [ ! -d "$BRIEFS_DIR" ]; then
  echo "{\"ok\":false,\"error\":\"$BRIEFS_DIR does not exist\"}" >&2
  exit 2
fi

shopt -s nullglob
briefs=("$BRIEFS_DIR"/*.yaml)
if [ ${#briefs[@]} -eq 0 ]; then
  echo '{"ok":false,"error":"no briefs found"}' >&2
  exit 2
fi

# Sort briefs by weight extracted from yaml so the adjacency chain is correct.
declare -a sorted=()
while IFS= read -r line; do
  sorted+=("$line")
done < <(
  for b in "${briefs[@]}"; do
    w=$(yq '.weight // 0' "$b")
    printf '%05d\t%s\n' "$w" "$b"
  done | sort | cut -f2-
)

gaps_json="[]"

emit_gap() {
  local brief="$1" issue="$2"
  gaps_json=$(jq --arg b "$(basename "$brief")" --arg i "$issue" \
    '. + [{brief: $b, issue: $i}]' <<< "$gaps_json")
}

# Per-brief checks.
for b in "${sorted[@]}"; do
  # Required scalar fields (must be non-empty, non-placeholder).
  for field in weight title short_title driving_question \
               contrast.alternative contrast.when_alternative_wins \
               prior_ends_with next_expects exercise_goal validation_scenario \
               reading.primary.url reading.primary.section \
               reading.secondary.url reading.secondary.section; do
    val=$(yq ".${field}" "$b")
    case "$val" in
      ""|null|TBD|"[placeholder]"|"???")
        emit_gap "$b" "${field} is empty or placeholder"
        ;;
    esac
  done

  # short_title constraints: <= 24 chars, no colon. Sidebar scannability gate.
  st=$(yq '.short_title' "$b")
  if [ -n "$st" ] && [ "$st" != "null" ]; then
    st_len=${#st}
    if [ "$st_len" -gt 24 ]; then
      emit_gap "$b" "short_title is $st_len chars (max 24 — drop the subtitle)"
    fi
    case "$st" in
      *:*) emit_gap "$b" "short_title contains a colon — split it: keep the part before the colon" ;;
    esac
  fi

  # Concepts: 3..5
  count=$(yq '.concepts | length' "$b")
  if [ "$count" -lt 3 ] || [ "$count" -gt 5 ]; then
    emit_gap "$b" "concepts has $count items (need 3..5)"
  fi

  # URL format
  for url_field in reading.primary.url reading.secondary.url; do
    url=$(yq ".${url_field}" "$b")
    case "$url" in
      http://*|https://*) ;;
      *) emit_gap "$b" "${url_field} is not http(s)" ;;
    esac
  done

  # exercise_goal TODO markers
  goal=$(yq '.exercise_goal' "$b")
  todo_count=$(printf '%s' "$goal" | grep -o '\[TODO:' | wc -l | tr -d ' ')
  if [ "$todo_count" -lt 2 ]; then
    emit_gap "$b" "exercise_goal has $todo_count [TODO: markers (need >= 2)"
  fi
done

# Adjacency chain.
prev_next=""
prev_brief=""
for b in "${sorted[@]}"; do
  prior=$(yq '.prior_ends_with' "$b" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')
  next=$(yq '.next_expects'   "$b" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')
  if [ -n "$prev_next" ] && [ "$prev_next" != "$prior" ]; then
    emit_gap "$prev_brief" "next_expects does not match next brief's prior_ends_with"
    emit_gap "$b" "prior_ends_with does not match previous brief's next_expects"
  fi
  prev_next="$next"
  prev_brief="$b"
done

if [ "$(jq 'length' <<< "$gaps_json")" -eq 0 ]; then
  jq -nc '{ok: true, gaps: []}'
  exit 0
fi

jq -nc --argjson g "$gaps_json" '{ok: false, gaps: $g}'
exit 1
