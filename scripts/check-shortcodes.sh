#!/usr/bin/env bash
# check-shortcodes.sh — Catch Hugo shortcode forms that render as raw text.
#
# The escaped form `{{</* shortcode */>}}` is meant for tutorials that show
# shortcode syntax literally. In normal module body content, it renders as
# raw `{{< shortcode >}}` text instead of invoking the shortcode — which
# looks like a build failure to readers.
#
# This script scans every site/content/modules/**/*.md (body only) for the
# escaped form and reports any hits as substantive flags. Hits inside fenced
# code blocks (```) are ignored — those are legitimate documentation.
#
# Output: JSON
#   { ok: bool,
#     hits: [ { path, line, snippet } ... ],
#     pages_scanned: int }
#
# Exit 0 on no hits; 1 on any hit; 2 on setup error.

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: check-shortcodes.sh <root>"}' >&2; exit 2; }

MODULES_DIR="$ROOT/site/content/modules"
[ -d "$MODULES_DIR" ] || { echo '{"ok":true,"hits":[],"pages_scanned":0}'; exit 0; }

HITS_FILE=$(mktemp); trap 'rm -f "$HITS_FILE"' EXIT

scanned=0
shopt -s globstar nullglob
for page in "$MODULES_DIR"/**/*.md; do
  scanned=$((scanned + 1))
  awk -v p="$page" '
    BEGIN { in_fence = 0 }
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    # match {{</* anywhere in the line
    /\{\{<\/\*/ {
      printf "%s\t%d\t%s\n", p, NR, $0
    }
  ' "$page" >> "$HITS_FILE" || true
done

hits_json="[]"
if [ -s "$HITS_FILE" ]; then
  hits_json=$(jq -Rsc --arg root "$ROOT/" '
    split("\n") | map(select(length > 0)) | map(split("\t")) |
    map({
      path:    (.[0] | sub($root; "")),
      line:    (.[1] | tonumber),
      snippet: (.[2] | .[0:200])
    })
  ' < "$HITS_FILE")
fi

count=$(jq 'length' <<< "$hits_json")
if [ "$count" -eq 0 ]; then
  jq -nc --argjson p "$scanned" '{ok: true, hits: [], pages_scanned: $p}'
  exit 0
else
  jq -nc --argjson h "$hits_json" --argjson p "$scanned" \
    '{ok: false, hits: $h, pages_scanned: $p}'
  exit 1
fi
