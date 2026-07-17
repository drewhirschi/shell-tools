#!/usr/bin/env bash
# shell-tools installer. Idempotent: safe to re-run on any machine.
#
#   ./install.sh
#
# Adds one `source` line to ~/.bashrc pointing at this checkout. Updating is
# then just `git pull` — no reinstall, because .bashrc points at the repo
# rather than holding a copy.
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOADER="$REPO_DIR/shell-tools.sh"
RC="${1:-$HOME/.bashrc}"
MARKER="# shell-tools"

[ -r "$LOADER" ] || { echo "install: loader not found at $LOADER" >&2; exit 1; }

if [ ! -e "$RC" ]; then
  echo "install: $RC does not exist; creating it" >&2
  touch "$RC"
fi

if grep -qF "$MARKER" "$RC"; then
  echo "✓ already installed in $RC (nothing to do)"
else
  cp -- "$RC" "$RC.pre-shell-tools.$(date +%Y%m%d%H%M%S)"
  printf '\n%s\n%s\n' "$MARKER" "source \"$LOADER\"" >>"$RC"
  echo "✓ installed — added source line to $RC (backup alongside it)"
fi

# Report missing dependencies rather than failing: the tools that need them
# are only a subset, and a missing fzf shouldn't block the install.
missing=()
for dep in git fzf; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "⚠ missing dependencies: ${missing[*]}"
  echo "  fw needs both. Install with your package manager, e.g.:"
  echo "    pacman -S ${missing[*]}     # arch"
  echo "    brew install ${missing[*]}  # macos"
fi

echo
echo "Open a new shell, or run:  source \"$LOADER\""
