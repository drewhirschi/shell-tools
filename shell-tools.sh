# shell-tools — loader.
#
# Source this from ~/.bashrc; it sources every functions/*.sh next to it:
#   source ~/work/shell-tools/shell-tools.sh
#
# These are interactive conveniences (they cd, they open fzf), so this is a
# no-op in non-interactive shells — scripts and scp both source .bashrc, and
# an fzf picker firing there would hang them.
case $- in
  *i*) ;;
  *) return ;;
esac

# Resolve this file's own directory so the repo can live anywhere.
#
# `builtin` + silenced stdout, deliberately: a bare `cd` here picks up whatever
# the user aliased it to (zoxide's `zd`, etc.), and those wrappers print the
# directory they land in — which command substitution then captures alongside
# pwd's output, yielding a two-line garbage path. Aliases only expand in
# interactive shells, so the bare version fails *only* in real shells.
# CDPATH is cleared for the same reason: a set CDPATH makes even builtin cd echo.
SHELL_TOOLS_DIR="$(CDPATH= builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && builtin pwd)"
export SHELL_TOOLS_DIR

if [ -z "$SHELL_TOOLS_DIR" ] || [ ! -d "$SHELL_TOOLS_DIR/functions" ]; then
  echo "shell-tools: cannot resolve install dir; not loading" >&2
  return 1
fi

for _st_file in "$SHELL_TOOLS_DIR"/functions/*.sh; do
  [ -r "$_st_file" ] && . "$_st_file"
done
unset _st_file
