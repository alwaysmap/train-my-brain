#!/usr/bin/env bash
# stop.sh — stop a hugo server started by ./serve.sh.
# Reads the PID from .hugo.pid and kills the process.

set -euo pipefail

CURRICULUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$CURRICULUM_ROOT/.hugo.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "stop.sh: no running server (no .hugo.pid found)."
  exit 0
fi

PID="$(cat "$PID_FILE")"
if ! kill -0 "$PID" 2>/dev/null; then
  echo "stop.sh: pidfile pointed to $PID but no such process is running. Cleaning up."
  rm -f "$PID_FILE"
  exit 0
fi

echo "stop.sh: stopping hugo server (pid $PID)"
kill "$PID"
# Give it a moment, then SIGKILL if still alive.
sleep 0.5
if kill -0 "$PID" 2>/dev/null; then
  echo "stop.sh: process didn't exit on SIGTERM; sending SIGKILL"
  kill -9 "$PID" || true
fi
rm -f "$PID_FILE"
echo "stop.sh: stopped."
