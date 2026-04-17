#!/usr/bin/env bash
# build.sh — build the Hugo site for static deployment.
# Usage: ./build.sh
# Output: site/public/

set -euo pipefail

CURRICULUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v hugo >/dev/null 2>&1; then
  echo "build.sh: hugo is not installed." >&2
  echo "Install it: https://github.com/gohugoio/hugo/releases/tag/v0.160.1" >&2
  exit 1
fi

if [ ! -d "$CURRICULUM_ROOT/site" ]; then
  echo "build.sh: no site/ directory found at $CURRICULUM_ROOT" >&2
  exit 1
fi

cd "$CURRICULUM_ROOT/site"
echo "build.sh: running hugo --minify"
hugo --minify

echo "build.sh: site/public/ is current."
