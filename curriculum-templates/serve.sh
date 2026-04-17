#!/usr/bin/env bash
# serve.sh — start the local Hugo site.
# Usage: ./serve.sh [--port N]   (default port 1313)
#
# Writes its PID to .hugo.pid so ./stop.sh can find it.
# Prints the URL once the server is up. Ctrl+C to stop (or use ./stop.sh).

set -euo pipefail

CURRICULUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=1313

while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    *) echo "serve.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if ! command -v hugo >/dev/null 2>&1; then
  echo "serve.sh: hugo is not installed." >&2
  echo "Install it: https://github.com/gohugoio/hugo/releases/tag/v0.160.1" >&2
  echo "Or on macOS:  brew install hugo" >&2
  echo "Or on Windows: winget install Hugo.Hugo.Extended" >&2
  exit 1
fi

if [ ! -d "$CURRICULUM_ROOT/site" ]; then
  echo "serve.sh: no site/ directory found at $CURRICULUM_ROOT" >&2
  exit 1
fi

PID_FILE="$CURRICULUM_ROOT/.hugo.pid"
if [ -f "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE")"
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "serve.sh: a server is already running (pid $OLD_PID). Use ./stop.sh first, or pass --port to run a second one." >&2
    exit 1
  fi
  # Stale pidfile — clean it up.
  rm -f "$PID_FILE"
fi

cleanup() {
  rm -f "$PID_FILE"
}
trap cleanup EXIT INT TERM

echo "serve.sh: starting hugo server -D --port $PORT from $CURRICULUM_ROOT/site"
cd "$CURRICULUM_ROOT/site"

# Run hugo server in the foreground; write our PID so stop.sh can find us.
echo $$ > "$PID_FILE"
exec hugo server -D --port "$PORT" --bind 127.0.0.1
