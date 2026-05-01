#!/usr/bin/env bash
# check-citations.sh — Footnote citation density check across module concept pages.
#
# Every module concept page (site/content/modules/<slug>/_index.md) must include
# at least 4 inline footnote citations. The footnote pattern is Markdown native:
#   prose...[^cite] more prose
#   [^cite]: As X explains: "..." — Source (year), URL
# We count footnote DEFINITIONS (lines matching `^[\^name]:`) since those are
# what produce verifiable citations the reader can check; bare references
# without definitions don't render as anything useful.
#
# Output: JSON
#   { ok: bool,
#     modules: [ { slug, count } ... ],
#     under_threshold: [ { slug, count } ... ] }
# Threshold: 4 footnotes per module concept page.
#
# Exit 0 always when the script ran (low density is a substantive flag,
# not a fatal pipeline error).

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: check-citations.sh <root>"}' >&2; exit 2; }
command -v jq >/dev/null || { echo '{"ok":false,"error":"jq not found"}' >&2; exit 2; }

THRESHOLD=4
MODULES_DIR="$ROOT/site/content/modules"
[ -d "$MODULES_DIR" ] || { echo '{"ok":true,"modules":[],"under_threshold":[]}'; exit 0; }

modules='[]'
under='[]'

shopt -s nullglob
for d in "$MODULES_DIR"/*/; do
  slug=$(basename "$d")
  page="$d/_index.md"
  [ -f "$page" ] || continue
  # Count footnote DEFINITIONS — lines starting with [^name]: (any non-space, non-]
  # name, then colon). That's the minted citation the reader can act on.
  count=$(grep -cE '^\[\^[^]]+\]:' "$page" || true)
  modules=$(jq -c --arg s "$slug" --argjson n "$count" '. + [{slug: $s, count: $n}]' <<< "$modules")
  if [ "$count" -lt "$THRESHOLD" ]; then
    under=$(jq -c --arg s "$slug" --argjson n "$count" '. + [{slug: $s, count: $n}]' <<< "$under")
  fi
done

ok="true"
[ "$(jq 'length' <<< "$under")" -gt 0 ] && ok="false"

jq -nc --arg ok "$ok" --argjson m "$modules" --argjson u "$under" \
  '{ok: ($ok == "true"), threshold: '"$THRESHOLD"', modules: $m, under_threshold: $u}'
exit 0
