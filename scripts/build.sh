#!/usr/bin/env bash
# build.sh — Package the plugin into train-my-brain.zip.
#
# If a git tag (v*) is checked out, syncs the version into plugin.json
# before building. Otherwise uses whatever version is already in the file.
#
# Usage: bash scripts/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$ROOT/train-my-brain.zip"
PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"

command -v jq >/dev/null   || { echo "build.sh: jq not found" >&2; exit 1; }
command -v zip >/dev/null  || { echo "build.sh: zip not found" >&2; exit 1; }

# ── Sync version from git tag (if exact-match) ───────────────
TAG_VERSION=""
if git -C "$ROOT" describe --tags --exact-match HEAD >/dev/null 2>&1; then
  TAG=$(git -C "$ROOT" describe --tags --exact-match HEAD 2>/dev/null)
  TAG_VERSION="${TAG#v}"
fi

if [ -n "$TAG_VERSION" ]; then
  CURRENT=$(jq -r '.version' "$PLUGIN_JSON")
  if [ "$CURRENT" != "$TAG_VERSION" ]; then
    jq --arg v "$TAG_VERSION" '.version = $v' "$PLUGIN_JSON" > "$PLUGIN_JSON.tmp" && \
      mv "$PLUGIN_JSON.tmp" "$PLUGIN_JSON"
    echo "Synced .claude-plugin/plugin.json: $CURRENT → $TAG_VERSION"
  fi
fi

VERSION=$(jq -r '.version' "$PLUGIN_JSON")
[ -z "$TAG_VERSION" ] && echo "No git tag on HEAD — using version $VERSION from plugin.json"

# ── Build zip ────────────────────────────────────────────────
[ -f "$OUT" ] && { rm -f "$OUT"; echo "Removed existing train-my-brain.zip"; }

cd "$ROOT"
zip -r "$OUT" \
  .claude-plugin/plugin.json \
  skills/ \
  agents/ \
  commands/ \
  references/ \
  scripts/ \
  curriculum-templates/ \
  README.md \
  LICENSE \
  CHANGELOG.md \
  -x "*/.DS_Store" \
  -x "scripts/build.sh" \
  -x "scripts/release.sh" >/dev/null

KB=$(awk "BEGIN {printf \"%.1f\", $(stat -f%z "$OUT" 2>/dev/null || stat -c%s "$OUT") / 1024}")
echo "Built: train-my-brain.zip v$VERSION (${KB} KB)"
