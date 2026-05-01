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

# Build a JSON object:
#   { term: { definition, source, references: [{label, url}], alternates: [{def, source}] } }
# Every entry MUST end up with at least one reference — the reviewer
# flags missing links as a finding. Rendered glossary.md emits the
# references as a "Learn more" list per term.
db='{}'

add_term() {
  local term="$1" def="$2" source="$3" refs_json="$4"
  term_norm=$(printf '%s' "$term" | normalize)
  def_norm=$(printf '%s' "$def" | normalize)
  [ -z "$term_norm" ] && return
  [ -z "$def_norm" ] && return
  [ -z "$refs_json" ] && refs_json='[]'
  current=$(jq -r --arg t "$term_norm" '.[$t].definition // ""' <<< "$db")
  if [ -z "$current" ]; then
    db=$(jq -c --arg t "$term_norm" --arg d "$def" --arg s "$source" --argjson r "$refs_json" \
      '.[$t] = {definition: $d, source: $s, references: $r, alternates: []}' <<< "$db")
  else
    cur_norm=$(printf '%s' "$current" | normalize)
    if [ "$cur_norm" != "$def_norm" ]; then
      db=$(jq -c --arg t "$term_norm" --arg d "$def" --arg s "$source" \
        '.[$t].alternates += [{definition: $d, source: $s}]' <<< "$db")
    fi
    # Even on a duplicate definition, accumulate references — later
    # mentions may surface additional links the canonical entry missed.
    if [ "$refs_json" != "[]" ]; then
      db=$(jq -c --arg t "$term_norm" --argjson r "$refs_json" \
        '.[$t].references = ((.[$t].references // []) + $r | unique_by(.url))' <<< "$db")
    fi
  fi
}

# Extract glossary references for one term from a YAML file. Outputs
# a compact JSON array `[{"label":..., "url":...}, ...]` on stdout, or
# `[]` if the term has no references field. Uses yq → JSON → jq because
# the system yq doesn't support `--arg` for inline string variables.
extract_refs() {
  local file="$1" term="$2"
  yq -o=json '.glossary // []' "$file" 2>/dev/null \
    | jq -c --arg t "$term" \
        '[.[]? | select(.term == $t) | .references[]? | {label, url}]' \
    2>/dev/null || echo '[]'
}

extract_spine_refs() {
  local fm="$1" term="$2"
  printf '%s' "$fm" | yq -o=json '.glossary_seed // []' - 2>/dev/null \
    | jq -c --arg t "$term" \
        '[.[]? | select(.term == $t) | .references[]? | {label, url}]' \
    2>/dev/null || echo '[]'
}

extract_new_terms_refs() {
  local file="$1" term="$2"
  yq -o=json '. // []' "$file" 2>/dev/null \
    | jq -c --arg t "$term" \
        '[.[]? | select(.term == $t) | .references[]? | {label, url}]' \
    2>/dev/null || echo '[]'
}

# 1. research.yaml (highest priority — written first, others append).
if [ -f "$RESEARCH" ]; then
  while IFS=$'\t' read -r term def; do
    [ -z "$term" ] && continue
    refs=$(extract_refs "$RESEARCH" "$term")
    add_term "$term" "$def" "research.yaml" "$refs"
  done < <(yq -r '.glossary[]? | [.term, .definition] | @tsv' "$RESEARCH" 2>/dev/null || true)
fi

# 2. spine glossary_seed (extracted from frontmatter).
if [ -f "$SPINE" ]; then
  spine_fm=$(awk '/^---/{c++; next} c==1' "$SPINE")
  while IFS=$'\t' read -r term def; do
    [ -z "$term" ] && continue
    refs=$(extract_spine_refs "$spine_fm" "$term")
    add_term "$term" "$def" "spine" "$refs"
  done < <(printf '%s' "$spine_fm" | yq -r '.glossary_seed[]? | [.term, .definition] | @tsv' - 2>/dev/null || true)
fi

# 3. per-module new_terms.yaml.
if [ -d "$MODULES_DIR" ]; then
  shopt -s nullglob
  for nt in "$MODULES_DIR"/*/new_terms.yaml; do
    slug=$(basename "$(dirname "$nt")")
    while IFS=$'\t' read -r term def; do
      [ -z "$term" ] && continue
      refs=$(extract_new_terms_refs "$nt" "$term")
      add_term "$term" "$def" "$slug" "$refs"
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
      "## \(.key)\n\n\(.value.definition)\n" +
      ( if (.value.references // []) | length > 0
        then "\n**Learn more:**\n\n" +
             ((.value.references | map("- [\(.label)](\(.url))")) | join("\n")) + "\n"
        else ""
        end )' <<< "$db"
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

# Terms with zero references — every glossary entry must carry at
# least one external "Learn more" link. Reviewer flags these.
missing_refs=$(jq -c '[to_entries[] | select((.value.references // []) | length == 0) |
  {term: .key, source: .value.source}]' <<< "$db")

count=$(jq 'length' <<< "$db")
jq -nc --argjson c "$conflicts" --argjson m "$missing_refs" --argjson n "$count" \
  '{ok: true, term_count: $n, conflicts: $c, missing_references: $m}'
