#!/usr/bin/env bash
# check-ai-prose.sh — Regex-based AI-prose detector against module pages.
#
# Scans every site/content/modules/*/_index.md (body only, frontmatter excluded)
# for opener clichés, fake enthusiasm, vague value claims, and consulting-speak.
#
# Output: JSON
#   { ok: bool, hits: [ { module, line, pattern, match } ... ] }
#
# Exit 0 on no hits; 1 on any hit; 2 on setup error.
#
# Patterns are intentionally false-positive-prone — every hit goes into review.md
# as a substantive flag for the human to triage, not auto-rewritten.

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: check-ai-prose.sh <root>"}' >&2; exit 2; }
command -v jq >/dev/null || { echo '{"ok":false,"error":"jq not found"}' >&2; exit 2; }

MODULES_DIR="$ROOT/site/content/modules"
[ -d "$MODULES_DIR" ] || { echo "{\"ok\":false,\"error\":\"$MODULES_DIR missing\"}" >&2; exit 2; }

# (regex, label) pairs.
PATTERNS=(
  "^[[:space:]]*In this (module|section|chapter|part),? we('ll| will)? (explore|discuss|learn|cover|dive)|opener-cliche"
  "\\b(exciting|powerful|game-changing|seamlessly|leveraging|utilize|harness)\\b|fake-enthusiasm"
  "\\b(paradigm shift|best-in-class|synergy|holistic approach)\\b|consulting-speak"
  "\\b(This will help you better understand|This is crucial for|Let's dive (in|into))\\b|vague-value"
)

hits="[]"
shopt -s nullglob

for page in "$MODULES_DIR"/*/_index.md; do
  slug=$(basename "$(dirname "$page")")
  body=$(awk 'BEGIN{c=0} /^---/{c++; next} c>=2' "$page")
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    for entry in "${PATTERNS[@]}"; do
      pattern="${entry%|*}"
      label="${entry##*|}"
      if printf '%s' "$line" | grep -Eqi "$pattern"; then
        match=$(printf '%s' "$line" | grep -Eoi "$pattern" | head -1 || true)
        hits=$(jq -c --arg m "$slug" --arg p "$label" --arg mt "$match" --arg ln "$line" \
          '. + [{module: $m, line: $ln, pattern: $p, match: $mt}]' <<< "$hits")
      fi
    done
  done <<< "$body"
done

if [ "$(jq 'length' <<< "$hits")" -eq 0 ]; then
  jq -nc '{ok: true, hits: []}'
else
  jq -nc --argjson h "$hits" '{ok: false, hits: $h}'
fi
# Always exit 0 — AI-prose hits are review.md flags for human triage, never
# pipeline failures. Use the JSON `ok` field to branch.
exit 0
