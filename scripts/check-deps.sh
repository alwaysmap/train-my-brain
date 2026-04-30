#!/usr/bin/env bash
# check-deps.sh — Verify every TMB v0.4 runtime dependency.
#
# Required:
#   - hugo (extended) >= 0.120
#   - yq                (Mike Farah, Go-based)
#   - jq
#   - curl
#
# Behavior:
#   - For each missing tool, prints a clear platform-appropriate install
#     command. On macOS w/ brew, offers to install interactively.
#   - Exits 0 only when all four are present and Hugo is recent enough.
#   - Exits 1 if anything is missing or stale.
#
# Skills should call this once at the start of any pipeline that uses the
# determinism scripts. /tmb:create runs it as Phase 0.

set -euo pipefail

MIN_HUGO="0.120.0"
SUGGESTED_HUGO="0.160.1"

ver_ge() {
  a=$(echo "$1" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  b=$(echo "$2" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  [ "$a" -ge "$b" ]
}

prompt_yn() {
  local q="$1" ans
  if [ ! -t 0 ]; then
    return 1
  fi
  printf '%s [y/N] ' "$q"
  read -r ans || return 1
  case "$ans" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

os=""
case "$(uname -s)" in
  Darwin) os="macos" ;;
  Linux)  os="linux" ;;
esac

missing=()

# ── hugo ──────────────────────────────────────────────────────
if command -v hugo >/dev/null 2>&1; then
  hv=$(hugo version 2>/dev/null | head -1 | sed -E 's/^hugo v([0-9.]+).*$/\1/')
  if ver_ge "$hv" "$MIN_HUGO"; then
    echo "✓ hugo $hv"
  else
    echo "✗ hugo $hv is older than required $MIN_HUGO"
    missing+=("hugo")
  fi
else
  echo "✗ hugo is not installed (need >= $MIN_HUGO, suggested $SUGGESTED_HUGO)"
  missing+=("hugo")
fi

# ── yq, jq, curl ──────────────────────────────────────────────
for tool in yq jq curl; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "✓ $tool $($tool --version 2>&1 | head -1)"
  else
    echo "✗ $tool is not installed"
    missing+=("$tool")
  fi
done

# ── Offer install ─────────────────────────────────────────────
if [ ${#missing[@]} -eq 0 ]; then
  echo "All TMB dependencies satisfied."
  exit 0
fi

echo
echo "Missing dependencies: ${missing[*]}"

if [ "$os" = "macos" ] && command -v brew >/dev/null 2>&1; then
  cmd="brew install ${missing[*]}"
  echo "Suggested: $cmd"
  if prompt_yn "Run it now?"; then
    eval "$cmd"
    echo
    echo "Re-run scripts/check-deps.sh to verify."
    exit 0
  fi
elif [ "$os" = "linux" ]; then
  if command -v snap >/dev/null 2>&1; then
    echo "Suggested (snap):"
    for m in "${missing[@]}"; do
      case "$m" in
        hugo) echo "  sudo snap install hugo --classic" ;;
        yq)   echo "  sudo snap install yq" ;;
        jq)   echo "  sudo apt-get install -y jq    # snap doesn't ship jq cleanly" ;;
        curl) echo "  sudo apt-get install -y curl" ;;
      esac
    done
  elif command -v apt-get >/dev/null 2>&1; then
    echo "Suggested (apt — note: apt's hugo is often stale):"
    echo "  sudo apt-get install -y ${missing[*]}"
  fi
else
  echo "Install each tool from its upstream:"
  echo "  hugo: https://github.com/gohugoio/hugo/releases"
  echo "  yq:   https://github.com/mikefarah/yq#install"
  echo "  jq:   https://jqlang.github.io/jq/download/"
fi

exit 1
