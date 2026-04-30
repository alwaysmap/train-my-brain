#!/usr/bin/env bash
# check-deps.sh — Verify every TMB v0.4 runtime dependency, offer to install
# any that are missing.
#
# Required:
#   - hugo (extended) >= 0.120 — site generation, archetypes, layouts.
#   - yq                       — read/patch nested YAML in briefs, frontmatter,
#                                research.yaml. Single static Go binary.
#   - jq                       — JSON munging in the determinism scripts.
#   - curl                     — URL reachability checks.
#
# Behavior:
#   1. Lists what's present and what's missing.
#   2. macOS + brew (unprivileged):
#        Offers to run `brew install <missing>` interactively.
#   3. Linux + snap (privileged via sudo): prints copy-paste commands.
#   4. Linux + apt (privileged via sudo): prints copy-paste commands.
#   5. Any other env: prints upstream download URLs.
#
# We do not auto-elevate (no `sudo` from inside the script). Users who don't
# have brew get a one-line block they can copy.
#
# Exits 0 only when all four are present at acceptable versions.
# Exits 1 if anything is missing or stale.
#
# Skills call this at the start of any pipeline. /tmb:create runs it as Phase 0.

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
  [ -t 0 ] || return 1
  printf '%s [y/N] ' "$q"
  read -r ans || return 1
  case "$ans" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

os=""
case "$(uname -s)" in
  Darwin) os="macos" ;;
  Linux)  os="linux" ;;
esac

echo "TMB dependency check"
echo "────────────────────"

missing=()

# ── hugo ──────────────────────────────────────────────────────
if command -v hugo >/dev/null 2>&1; then
  hv=$(hugo version 2>/dev/null | head -1 | sed -E 's/^hugo v([0-9.]+).*$/\1/')
  if ver_ge "$hv" "$MIN_HUGO"; then
    echo "✓ hugo $hv"
  else
    echo "✗ hugo $hv (need >= $MIN_HUGO)"
    missing+=("hugo")
  fi
else
  echo "✗ hugo not found (need >= $MIN_HUGO, suggested $SUGGESTED_HUGO)"
  missing+=("hugo")
fi

# ── yq, jq, curl ──────────────────────────────────────────────
for tool in yq jq curl; do
  if command -v "$tool" >/dev/null 2>&1; then
    v=$("$tool" --version 2>&1 | head -1)
    echo "✓ $tool ($v)"
  else
    echo "✗ $tool not found"
    missing+=("$tool")
  fi
done

# ── Offer install ─────────────────────────────────────────────
if [ ${#missing[@]} -eq 0 ]; then
  echo
  echo "All TMB dependencies satisfied."
  exit 0
fi

echo
echo "Missing: ${missing[*]}"
echo

if [ "$os" = "macos" ]; then
  if command -v brew >/dev/null 2>&1; then
    cmd="brew install ${missing[*]}"
    echo "macOS — Homebrew available."
    echo "  $cmd"
    echo
    if prompt_yn "Install now?"; then
      eval "$cmd"
      echo
      echo "Re-run: bash scripts/check-deps.sh"
      exit 0
    fi
    echo "Skipped install. Run the command above when ready."
  else
    echo "macOS — Homebrew not detected. Install brew first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo
    echo "Then:"
    echo "  brew install ${missing[*]}"
  fi
elif [ "$os" = "linux" ]; then
  echo "Linux — copy-paste install (we don't auto-elevate sudo):"
  echo
  if command -v snap >/dev/null 2>&1; then
    for m in "${missing[@]}"; do
      case "$m" in
        hugo) echo "  sudo snap install hugo --classic" ;;
        yq)   echo "  sudo snap install yq" ;;
        jq)   echo "  sudo apt-get install -y jq" ;;
        curl) echo "  sudo apt-get install -y curl" ;;
      esac
    done
  elif command -v apt-get >/dev/null 2>&1; then
    apt_pkgs=()
    for m in "${missing[@]}"; do
      case "$m" in
        hugo) echo "  # apt's hugo is often stale; prefer the upstream binary:"
              echo "  curl -L -o /tmp/hugo.deb https://github.com/gohugoio/hugo/releases/download/v${SUGGESTED_HUGO}/hugo_extended_${SUGGESTED_HUGO}_linux-amd64.deb"
              echo "  sudo dpkg -i /tmp/hugo.deb" ;;
        yq)   echo "  sudo wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
              echo "  sudo chmod +x /usr/local/bin/yq" ;;
        *)    apt_pkgs+=("$m") ;;
      esac
    done
    [ ${#apt_pkgs[@]} -gt 0 ] && echo "  sudo apt-get install -y ${apt_pkgs[*]}"
  elif command -v dnf >/dev/null 2>&1; then
    echo "  sudo dnf install -y ${missing[*]}"
  else
    echo "  No known package manager. Install each from upstream:"
    for m in "${missing[@]}"; do
      case "$m" in
        hugo) echo "  hugo: https://github.com/gohugoio/hugo/releases" ;;
        yq)   echo "  yq:   https://github.com/mikefarah/yq#install" ;;
        jq)   echo "  jq:   https://jqlang.github.io/jq/download/" ;;
        curl) echo "  curl: usually preinstalled; check your distro" ;;
      esac
    done
  fi
else
  echo "Install each from upstream:"
  for m in "${missing[@]}"; do
    case "$m" in
      hugo) echo "  hugo: https://github.com/gohugoio/hugo/releases" ;;
      yq)   echo "  yq:   https://github.com/mikefarah/yq#install" ;;
      jq)   echo "  jq:   https://jqlang.github.io/jq/download/" ;;
      curl) echo "  curl: usually preinstalled; check your distro" ;;
    esac
  done
fi

exit 1
