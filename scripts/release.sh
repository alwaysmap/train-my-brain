#!/usr/bin/env bash
# release.sh — Tag a release and push to trigger GitHub Actions.
#
# Usage: bash scripts/release.sh <version>
#   e.g. bash scripts/release.sh 0.4.0
#
# This will:
#   1. Update version in .claude-plugin/plugin.json
#   2. Commit the version bump
#   3. Create git tag v<version>
#   4. Push HEAD to origin/main and the tag
#
# GitHub Actions then builds train-my-brain.zip, creates a GitHub Release,
# and dispatches plugin-released to alwaysmap/alwaysmap-marketplace, which
# updates marketplace.json automatically.

set -euo pipefail

VERSION="${1:-}"
[ -z "$VERSION" ] && { echo "Usage: bash scripts/release.sh <version>" >&2; exit 1; }
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Invalid version: \"$VERSION\" (expected X.Y.Z)" >&2; exit 1; }

command -v jq  >/dev/null || { echo "release.sh: jq not found"  >&2; exit 1; }
command -v git >/dev/null || { echo "release.sh: git not found" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
TAG="v$VERSION"

# Working tree must be clean.
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
  echo "Working tree is dirty. Commit or stash changes first." >&2
  git -C "$ROOT" status --short >&2
  exit 1
fi

# Tag must not exist.
if git -C "$ROOT" rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists." >&2
  exit 1
fi

# Bump version (or skip if plugin.json is already at target).
CURRENT=$(jq -r '.version' "$PLUGIN_JSON")
if [ "$CURRENT" = "$VERSION" ]; then
  echo "plugin.json already at $VERSION — skipping bump commit, tagging current HEAD."
else
  jq --arg v "$VERSION" '.version = $v' "$PLUGIN_JSON" > "$PLUGIN_JSON.tmp"
  mv "$PLUGIN_JSON.tmp" "$PLUGIN_JSON"
  echo "Updated .claude-plugin/plugin.json: $CURRENT → $VERSION"
  git -C "$ROOT" add .claude-plugin/plugin.json
  git -C "$ROOT" commit -m "Release $TAG"
fi

git -C "$ROOT" tag "$TAG"
git -C "$ROOT" push origin HEAD:main "$TAG"

echo
echo "Released $TAG — GitHub Actions will build, publish, and update the marketplace."
