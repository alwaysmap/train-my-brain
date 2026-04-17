#!/usr/bin/env bash
# check-hugo.sh — detect Hugo (extended) >= 0.120, offer a platform install if missing.
#
# Exit codes:
#   0  — Hugo available at acceptable version
#   1  — Hugo missing or too old and user declined install (or install failed)
#   2  — Hugo missing and no known package manager; user pointed to release URL
#
# Invoked by every TMB orchestrator before it does real work.

set -euo pipefail

MIN_VERSION="0.120.0"
SUGGESTED_VERSION="0.160.1"
RELEASE_URL="https://github.com/gohugoio/hugo/releases/tag/v${SUGGESTED_VERSION}"

ver_ge() {
  # Returns 0 if $1 >= $2 by dotted-integer comparison (ignores prerelease tags).
  local a b
  a=$(echo "$1" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  b=$(echo "$2" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  [ "$a" -ge "$b" ]
}

detect_installed() {
  if command -v hugo >/dev/null 2>&1; then
    hugo version 2>/dev/null | head -1 | sed -E 's/^hugo v([0-9.]+).*$/\1/'
  fi
}

prompt_yn() {
  local q="$1" ans
  printf '%s [y/N] ' "$q"
  read -r ans || ans="n"
  case "$ans" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

suggest_install() {
  local os pkg
  os=$(detect_os)

  if [ "$os" = "macos" ]; then
    if command -v brew >/dev/null 2>&1; then
      echo "Package manager: brew"
      if prompt_yn "Install hugo-extended via 'brew install hugo'?"; then
        brew install hugo && return 0
        echo "check-hugo.sh: brew install failed." >&2
        return 1
      fi
      return 1
    fi
    echo "check-hugo.sh: Homebrew not detected. Install it from https://brew.sh, or install Hugo manually:"
    echo "  $RELEASE_URL"
    return 2
  fi

  if [ "$os" = "linux" ]; then
    if command -v snap >/dev/null 2>&1; then
      echo "Package manager: snap"
      if prompt_yn "Install hugo via 'sudo snap install hugo --classic'?"; then
        sudo snap install hugo --classic && return 0
        echo "check-hugo.sh: snap install failed." >&2
        return 1
      fi
      return 1
    fi
    if command -v apt-get >/dev/null 2>&1; then
      echo "Package manager: apt"
      echo "Note: the apt hugo package is often outdated. Prefer downloading from $RELEASE_URL."
      if prompt_yn "Try 'sudo apt-get install hugo' anyway?"; then
        sudo apt-get install -y hugo && return 0
        echo "check-hugo.sh: apt install failed." >&2
        return 1
      fi
      return 1
    fi
    if command -v dnf >/dev/null 2>&1; then
      echo "Package manager: dnf"
      if prompt_yn "Install hugo via 'sudo dnf install hugo'?"; then
        sudo dnf install -y hugo && return 0
        echo "check-hugo.sh: dnf install failed." >&2
        return 1
      fi
      return 1
    fi
    echo "check-hugo.sh: no known package manager (snap/apt/dnf). Install Hugo manually:"
    echo "  $RELEASE_URL"
    return 2
  fi

  echo "check-hugo.sh: unknown OS ($(uname -s)). Install Hugo manually:"
  echo "  $RELEASE_URL"
  return 2
}

# ── Main flow ─────────────────────────────────────────────────
INSTALLED=$(detect_installed || true)

if [ -z "$INSTALLED" ]; then
  echo "check-hugo.sh: Hugo is not installed."
  echo "TMB needs Hugo >= $MIN_VERSION (extended edition preferred; suggested: $SUGGESTED_VERSION)."
  suggest_install
  status=$?
  if [ "$status" -eq 0 ]; then
    # Verify post-install
    INSTALLED=$(detect_installed || true)
    if [ -z "$INSTALLED" ]; then
      echo "check-hugo.sh: install seemed to succeed but hugo is still not on PATH." >&2
      exit 1
    fi
    echo "check-hugo.sh: hugo $INSTALLED installed."
    exit 0
  fi
  exit "$status"
fi

if ver_ge "$INSTALLED" "$MIN_VERSION"; then
  echo "check-hugo.sh: hugo $INSTALLED detected (>= $MIN_VERSION)."
  exit 0
fi

echo "check-hugo.sh: hugo $INSTALLED is older than the required $MIN_VERSION."
if prompt_yn "Attempt an upgrade via the system package manager?"; then
  suggest_install
  status=$?
  if [ "$status" -eq 0 ]; then
    INSTALLED=$(detect_installed || true)
    if ver_ge "${INSTALLED:-0.0.0}" "$MIN_VERSION"; then
      echo "check-hugo.sh: hugo $INSTALLED installed."
      exit 0
    fi
    echo "check-hugo.sh: upgrade attempted but version is still $INSTALLED." >&2
    exit 1
  fi
  exit "$status"
fi
echo "check-hugo.sh: upgrade declined. See $RELEASE_URL for manual install."
exit 1
