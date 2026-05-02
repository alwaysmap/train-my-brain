#!/usr/bin/env bash
# check-mermaid.sh — Catch Mermaid v11 syntax patterns that throw "Syntax error in text".
#
# Mermaid v11 (the version shipped by mermaid.js's CDN as of 2026) rejects
# several patterns older versions tolerated. This linter scans every
# ```mermaid ... ``` fenced block in the module content tree and reports:
#
#   1. Unicode (e.g. °) inside unquoted node labels  → A[5° taper]
#      Fix: quote the label                          → A["5° taper"]
#   2. Literal \n inside any label                   → A[Hang\n24 hrs]
#      Fix: use <br/> with quotes                    → A["Hang<br/>24 hrs"]
#   3. Apostrophe inside unquoted label              → A[Archer's paradox]
#      Fix: quote the label                          → A["Archer's paradox"]
#   4. Subgraph title with spaces, no bracket form   → subgraph Point end
#      Fix: use bracket form                         → subgraph PointEnd ["Point end"]
#   5. Long flowchart LR chains (>= 7 arrows)        → cramped/illegible at site widths
#      Fix: switch to TD orientation
#
# Output: JSON
#   { ok: bool,
#     hits: [ { path, line, kind, snippet } ... ],
#     pages_scanned: int,
#     blocks_scanned: int }
#
# Exit 0 on no hits; 1 on any hit; 2 on setup error.
#
# Implementation note: uses bash + grep instead of awk's match-into-array
# form (which is GNU-awk-only and absent on macOS BSD awk).

set -uo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: check-mermaid.sh <root>"}' >&2; exit 2; }

MODULES_DIR="$ROOT/site/content/modules"
[ -d "$MODULES_DIR" ] || { echo '{"ok":true,"hits":[],"pages_scanned":0,"blocks_scanned":0}'; exit 0; }

HITS_FILE=$(mktemp); trap 'rm -f "$HITS_FILE"' EXIT

scanned=0; blocks=0
shopt -s globstar nullglob

# Per-page scan: read the file once, track whether we're inside ```mermaid,
# and run the regex checks on every line that's inside a block.
scan_file() {
  local page="$1"
  local in_block=0
  local arrow_count=0
  local orientation=""
  local block_start_line=0
  local lineno=0
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))

    # Block boundaries.
    if [ $in_block -eq 0 ]; then
      if [[ "$line" =~ ^\`\`\`mermaid ]]; then
        in_block=1
        arrow_count=0
        orientation=""
        block_start_line=$lineno
        blocks=$((blocks + 1))
      fi
      continue
    fi

    if [[ "$line" =~ ^\`\`\` ]]; then
      # End of block. Emit LR-cramped flag if applicable.
      if [ "$orientation" = "LR" ] && [ $arrow_count -ge 7 ]; then
        printf '%s\t%d\t%s\tflowchart LR with %d arrows — switch to TD for legibility\n' \
          "$page" "$block_start_line" "lr_too_many" "$arrow_count" >> "$HITS_FILE"
      fi
      in_block=0
      continue
    fi

    # Inside a block: line-level checks.

    # Orientation declaration.
    if [[ "$line" =~ flowchart[[:space:]]+(LR|TD|TB|RL|BT) ]]; then
      orientation="${BASH_REMATCH[1]}"
    fi

    # Count arrows for the LR-cramped heuristic.
    local arrows_on_line=0
    local rest="$line"
    while [[ "$rest" == *"-->"* ]]; do
      arrows_on_line=$((arrows_on_line + 1))
      rest="${rest#*-->}"
    done
    arrow_count=$((arrow_count + arrows_on_line))

    # Heuristic 1: ° inside an unquoted [...] label.
    if [[ "$line" =~ \[[^\"]*°[^\"]*\] ]]; then
      printf '%s\t%d\t%s\t%s\n' "$page" "$lineno" "unquoted_unicode" \
        "${line:0:200}" >> "$HITS_FILE"
    fi

    # Heuristic 2: literal \n inside a label.
    if [[ "$line" =~ \[[^\"]*\\n[^\"]*\] ]] || [[ "$line" =~ \([^\"]*\\n[^\"]*\) ]]; then
      printf '%s\t%d\t%s\t%s\n' "$page" "$lineno" "literal_backslash_n" \
        "${line:0:200}" >> "$HITS_FILE"
    fi

    # Heuristic 3: apostrophe inside unquoted [...] label.
    # Match opening [, then alpha/space content with an apostrophe between letters,
    # closing ] without an intervening ".
    if [[ "$line" =~ \[[A-Za-z0-9\ ]*[A-Za-z]\'[A-Za-z][^\"]*\] ]]; then
      printf '%s\t%d\t%s\t%s\n' "$page" "$lineno" "unquoted_apostrophe" \
        "${line:0:200}" >> "$HITS_FILE"
    fi

    # Heuristic 4: multi-word subgraph title with no bracket / quote form.
    # Match: leading whitespace, "subgraph", whitespace, then >=2 words separated
    # by whitespace, no [ or " on the line.
    if [[ "$line" =~ ^[[:space:]]*subgraph[[:space:]]+[^\[\"]+[[:space:]]+[^\[\"]+$ ]]; then
      printf '%s\t%d\t%s\t%s\n' "$page" "$lineno" "multiword_subgraph" \
        "${line:0:200}" >> "$HITS_FILE"
    fi
  done < "$page"
}

for page in "$MODULES_DIR"/**/*.md; do
  scanned=$((scanned + 1))
  scan_file "$page"
done

hits_json="[]"
if [ -s "$HITS_FILE" ]; then
  hits_json=$(jq -Rsc --arg root "$ROOT/" '
    split("\n") | map(select(length > 0)) | map(split("\t")) |
    map({
      path:    (.[0] | sub($root; "")),
      line:    (.[1] | tonumber),
      kind:    .[2],
      snippet: (.[3] | .[0:200])
    })
  ' < "$HITS_FILE")
fi

count=$(jq 'length' <<< "$hits_json")
if [ "$count" -eq 0 ]; then
  jq -nc --argjson p "$scanned" --argjson b "$blocks" \
    '{ok: true, hits: [], pages_scanned: $p, blocks_scanned: $b}'
  exit 0
else
  jq -nc --argjson h "$hits_json" --argjson p "$scanned" --argjson b "$blocks" \
    '{ok: false, hits: $h, pages_scanned: $p, blocks_scanned: $b}'
  exit 1
fi
