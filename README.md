# shell-tools

Shell functions I want on every machine, kept in git so `git pull` is the update.

## Install

```bash
git clone https://github.com/drewhirschi/shell-tools ~/work/shell-tools
~/work/shell-tools/install.sh
```

The installer appends one `source` line to `~/.bashrc`. It's idempotent, backs up
`.bashrc` before touching it, and takes an alternate rc file as `$1` if you need one.

The repo can live anywhere — the loader resolves its own path. `~/work/shell-tools`
is just the default.

## Update

```bash
cd ~/work/shell-tools && git pull
```

That's the whole story. `.bashrc` points at this checkout instead of holding a copy,
so a pull is live in every new shell. Nothing to reinstall.

## Why functions, not scripts on `$PATH`

`fw` ends by `cd`-ing you somewhere. A script runs in its own process, so its `cd`
dies with it and your shell never moves. Only a function sourced into your current
shell can change your directory — which is why this repo ships a loader rather than
a `bin/` directory.

## Tools

### `fw` — find worktree

Fuzzy-jump to any git worktree under `~/work`.

```
fw           # pick from all worktrees
fw resume    # same, fzf pre-filtered by "resume"
```

Each row shows the relative path, branch (or short SHA when detached), a dirty
count (`●3` / `✓`), ahead/behind vs upstream (`↑2↓1`), and the last commit. The
preview pane runs live `git status -sb`, the last 8 commits, and a `diff --stat`.
Enter cds you there; Esc leaves you put.

It finds **linked worktrees**, not just clones: `git worktree add` writes `.git` as
a *file* containing a `gitdir:` pointer, not a directory, so the scan matches both.

**Config**

| Variable  | Default   | Meaning                    |
|-----------|-----------|----------------------------|
| `FW_ROOT` | `~/work`  | Directory tree to scan     |

Set it in `.bashrc` **before** the `source` line if a machine keeps code elsewhere:

```bash
export FW_ROOT="$HOME/src"
```

**Limits**

- Scans `-maxdepth 5` from `FW_ROOT`; a worktree nested deeper is invisible.
- Costs ~5 `git` calls per worktree, all at startup of the picker. Fine at dozens,
  noticeable at hundreds.

**Requires** `git`, `fzf`.

## Adding a tool

Drop `functions/<name>.sh` in, defining a function of the same name. The loader
picks up anything matching `functions/*.sh` — no registration step. Keep it to
things that genuinely need to be functions (changing the shell's own state);
anything else is better off as a real script on `$PATH`.
