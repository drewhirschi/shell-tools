# fw — "find worktree": fuzzy-jump to any git worktree rooted under ~/work.
# Scans for every checkout/linked worktree (each has a .git file or dir),
# shows branch + last commit + dirty count + ahead/behind in an fzf picker
# with a live git-status/diff preview, then just cd's there. No Claude launch.
#   fw          pick a worktree and cd into it
#   fw <query>  same, with fzf pre-filtered by <query>
fw() {
  local root="${FW_ROOT:-$HOME/work}"
  [ -d "$root" ] || { echo "fw: $root not found" >&2; return 1; }

  local rows sel path
  rows=$(
    find "$root" -maxdepth 5 -name .git \( -type d -o -type f \) -prune 2>/dev/null \
    | while read -r gitpath; do
        local wt="${gitpath%/.git}"
        git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue

        local branch rel dirty ab
        branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null \
                 || git -C "$wt" rev-parse --short HEAD 2>/dev/null)
        rel="${wt#$root/}"

        local n
        n=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l)
        [ "$n" -gt 0 ] && dirty="●$n" || dirty="✓"

        # ahead/behind vs upstream if set, else the repo's default branch
        local base
        base=$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
        if [ -z "$base" ]; then
          base=$(git -C "$wt" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
          [ -z "$base" ] && for b in main master; do
            git -C "$wt" rev-parse --verify -q "$b" >/dev/null 2>&1 && { base="$b"; break; }
          done
        fi
        ab=""
        if [ -n "$base" ] && git -C "$wt" rev-parse --verify -q "$base" >/dev/null 2>&1; then
          local a bh
          read -r bh a < <(git -C "$wt" rev-list --left-right --count "$base...HEAD" 2>/dev/null)
          [ "${a:-0}" -gt 0 ] && ab+="↑$a"
          [ "${bh:-0}" -gt 0 ] && ab+="↓$bh"
        fi

        local last
        last=$(git -C "$wt" log -1 --format='%cr · %s' 2>/dev/null)
        printf '%-40s %-22s %-5s %-8s %s\t%s\n' "$rel" "$branch" "$dirty" "$ab" "$last" "$wt"
      done
  )

  [ -z "$rows" ] && { echo "fw: no git worktrees under $root" >&2; return 1; }

  sel=$(printf '%s\n' "$rows" | fzf \
    --query="${1:-}" \
    --delimiter='\t' --with-nth=1 --ansi \
    --height=80% --reverse --border \
    --preview='git -C {2} -c color.ui=always status -sb; echo; \
               git -C {2} -c color.ui=always log -8 --oneline --decorate 2>/dev/null; echo; \
               git -C {2} -c color.ui=always diff --stat 2>/dev/null' \
    --preview-window='right,55%')

  [ -z "$sel" ] && return 0
  path="${sel##*$'\t'}"
  cd "$path" && echo "→ $path"
}
