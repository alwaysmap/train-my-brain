#!/usr/bin/env bash
# check-urls.sh — Reachability check against every reading-list URL.
#
# Walks every briefs/*.yaml and checks .reading.primary.url and
# .reading.secondary.url with `curl -I`. 2xx is healthy. Non-2xx,
# timeouts, and connection errors are reported (but not fatal — URL
# decay is normal and shouldn't block a build).
#
# Output: JSON to stdout
#   { ok: bool,
#     results: [ { brief, field, url, status } ... ],
#     unhealthy: [ { brief, field, url, status } ... ] }
#
# Exit:
#   0 if every URL returned 2xx
#   1 if any URL was unhealthy
#   2 on usage/setup error

set -euo pipefail

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  echo '{"ok":false,"error":"usage: check-urls.sh <curriculum_root>"}' >&2
  exit 2
fi
if ! command -v yq >/dev/null 2>&1; then
  echo '{"ok":false,"error":"yq not found"}' >&2; exit 2
fi
if ! command -v curl >/dev/null 2>&1; then
  echo '{"ok":false,"error":"curl not found"}' >&2; exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo '{"ok":false,"error":"jq not found"}' >&2; exit 2
fi

BRIEFS_DIR="$ROOT/briefs"
if [ ! -d "$BRIEFS_DIR" ]; then
  echo "{\"ok\":false,\"error\":\"$BRIEFS_DIR does not exist\"}" >&2; exit 2
fi

results="[]"
unhealthy="[]"
shopt -s nullglob
for b in "$BRIEFS_DIR"/*.yaml; do
  name=$(basename "$b")
  for field in reading.primary.url reading.secondary.url; do
    url=$(yq ".${field}" "$b")
    [ -z "$url" ] || [ "$url" = "null" ] && continue
    code=$(curl -I -sSL --max-time 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    entry=$(jq -nc --arg b "$name" --arg f "$field" --arg u "$url" --arg s "$code" \
            '{brief: $b, field: $f, url: $u, status: $s}')
    results=$(jq -c --argjson e "$entry" '. + [$e]' <<< "$results")
    case "$code" in
      2*) ;;
      *) unhealthy=$(jq -c --argjson e "$entry" '. + [$e]' <<< "$unhealthy") ;;
    esac
  done
done

if [ "$(jq 'length' <<< "$unhealthy")" -eq 0 ]; then
  jq -nc --argjson r "$results" '{ok: true, results: $r, unhealthy: []}'
  exit 0
fi
jq -nc --argjson r "$results" --argjson u "$unhealthy" \
  '{ok: false, results: $r, unhealthy: $u}'
exit 1
