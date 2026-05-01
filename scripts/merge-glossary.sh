#!/usr/bin/env bash
# merge-glossary.sh — Merge canonical + per-module terms into glossary.md.
#
# Sources, in priority order:
#   1. research.yaml glossary entries (canonical, written once by tmb-researcher)
#   2. curriculum_spine.md glossary_seed (small list from interview)
#   3. modules/*/new_terms.yaml (terms each builder introduced)
#
# Same term + same definition (after whitespace normalize) → merge into one entry.
# Same term + different definition → conflict (emitted in JSON output).
#
# Writes <root>/glossary.md. Output: JSON
#   { ok: bool, term_count: N, conflicts: [ { term, definitions: [...] } ... ] }
#
# Exit 0 always when glossary writes successfully (conflicts are reported but
# don't fail the merge — glossary keeps the research.yaml or first-seen value
# and the conflict list lets the reviewer flag substantively).
# Exit 2 on setup error.

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: merge-glossary.sh <root>"}' >&2; exit 2; }
command -v yq >/dev/null || { echo '{"ok":false,"error":"yq not found"}' >&2; exit 2; }
command -v jq >/dev/null || { echo '{"ok":false,"error":"jq not found"}' >&2; exit 2; }

OUT="$ROOT/glossary.md"
RESEARCH="$ROOT/research.yaml"
SPINE="$ROOT/curriculum_spine.md"
MODULES_DIR="$ROOT/modules"

normalize() { tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }

# Build a JSON object: { term: { definition, source, alternates: [{def, source}] } }
db='{}'

add_term() {
  local term="$1" def="$2" source="$3"
  term_norm=$(printf '%s' "$term" | normalize)
  def_norm=$(printf '%s' "$def" | normalize)
  [ -z "$term_norm" ] && return
  [ -z "$def_norm" ] && return
  current=$(jq -r --arg t "$term_norm" '.[$t].definition // ""' <<< "$db")
  if [ -z "$current" ]; then
    db=$(jq -c --arg t "$term_norm" --arg d "$def" --arg s "$source" \
      '.[$t] = {definition: $d, source: $s, alternates: []}' <<< "$db")
  else
    cur_norm=$(printf '%s' "$current" | normalize)
    if [ "$cur_norm" != "$def_norm" ]; then
      db=$(jq -c --arg t "$term_norm" --arg d "$def" --arg s "$source" \
        '.[$t].alternates += [{definition: $d, source: $s}]' <<< "$db")
    fi
  fi
}

# 1. research.yaml (highest priority — written first, others append).
if [ -f "$RESEARCH" ]; then
  while IFS=$'\t' read -r term def; do
    [ -z "$term" ] && continue
    add_term "$term" "$def" "research.yaml"
  done < <(yq -r '.glossary[]? | [.term, .definition] | @tsv' "$RESEARCH" 2>/dev/null || true)
fi

# 2. spine glossary_seed (extracted from frontmatter).
if [ -f "$SPINE" ]; then
  spine_fm=$(awk '/^---/{c++; next} c==1' "$SPINE")
  while IFS=$'\t' read -r term def; do
    [ -z "$term" ] && continue
    add_term "$term" "$def" "spine"
  done < <(printf '%s' "$spine_fm" | yq -r '.glossary_seed[]? | [.term, .definition] | @tsv' - 2>/dev/null || true)
fi

# 3. per-module new_terms.yaml.
if [ -d "$MODULES_DIR" ]; then
  shopt -s nullglob
  for nt in "$MODULES_DIR"/*/new_terms.yaml; do
    slug=$(basename "$(dirname "$nt")")
    while IFS=$'\t' read -r term def; do
      [ -z "$term" ] && continue
      add_term "$term" "$def" "$slug"
    done < <(yq -r '.[]? | [.term, .definition] | @tsv' "$nt" 2>/dev/null || true)
  done
fi

# Sort and write glossary.md to both locations:
#   1. <root>/glossary.md             — data file at curriculum root (canonical)
#   2. <root>/site/content/glossary.md — Hugo content (the served URL /glossary/)
# Both files are bit-for-bit identical. The Hugo layout's <h1>{{ .Title }}</h1>
# renders the heading from frontmatter, so we do NOT prepend a `# Glossary`
# heading to the body — that would render as a duplicate.
write_glossary() {
  local out="$1"
  {
    printf -- '---\ntitle: "Glossary"\ndraft: false\n---\n\n'
    jq -r 'to_entries | sort_by(.key) | .[] |
      "## \(.key)\n\n\(.value.definition)\n"' <<< "$db"
  } > "$out"
}

write_glossary "$OUT"
if [ -d "$ROOT/site/content" ]; then
  write_glossary "$ROOT/site/content/glossary.md"
fi

# Conflicts (terms with non-empty .alternates).
conflicts=$(jq -c '[to_entries[] | select(.value.alternates | length > 0) |
  {term: .key, definitions: ([{def: .value.definition, source: .value.source}]
                              + .value.alternates)}]' <<< "$db")

count=$(jq 'length' <<< "$db")
jq -nc --argjson c "$conflicts" --argjson n "$count" \
  '{ok: true, term_count: $n, conflicts: $c}'
