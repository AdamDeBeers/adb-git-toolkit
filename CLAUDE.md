# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ADB Git Toolkit (ADB GT) is an open-source Git/GitHub workflow toolkit for Klipper-based 3D printers (Voron and similar), with Mainsail integration via Moonraker's update_manager. The project is in early development (v0.1.2-dev), MIT licensed.

The toolkit is a single interactive Bash script: `scripts/adb-git-toolkit.sh`. It presents a numbered menu (`main_menu`) driving one function per action: repository status, log/history, remote info, diff, create backup (commit), push to GitHub, safe pull, switch branch, quick stash, repository health, configuration restore, check for updates, and about. There is no build step or package manager. Verification is done both by exercising the menu against real (throwaway) Git repos and by the `tests/adb-git-toolkit.bats` suite (see below).

## CI

`.github/workflows/shellcheck.yml` runs ShellCheck (via `ludeeus/action-shellcheck`) over the whole repo on push to `main` and on pull requests. Run `shellcheck install.sh uninstall.sh scripts/adb-git-toolkit.sh` locally before pushing shell changes — e.g. the `@{u}` upstream-ref syntax needs to stay single-quoted (`'@{u}'`), or ShellCheck flags it as SC1083.

`.github/workflows/tests.yml` installs `bats` and runs `tests/adb-git-toolkit.bats` on push to `main` and on pull requests. Run `bats tests/` locally before pushing changes to `scripts/adb-git-toolkit.sh` — the tests source the script's functions (with the trailing `main_menu` call stripped) into a throwaway git repo and drive each menu function by piping canned input to it, the same way the interactive menu receives input. They cover the guard clauses (dirty tree, no remote, detached HEAD, etc.), the `[Y/n]` confirmation parsing, and the secrets-warning heuristic in `create_backup`. When adding a new menu action or changing an existing one's confirmation/guard logic, add or update a corresponding test.

## Running the toolkit

```bash
bash scripts/adb-git-toolkit.sh
```

The script is meant to run from inside the target Git repository (e.g., a Klipper config repo) — most menu actions call `require_git_repo` and bail out with an error message if run outside one.

## Installation architecture

`install.sh` clones this repo (via its `origin` remote) into `~/.local/share/adb-git-toolkit` and symlinks `scripts/adb-git-toolkit.sh` as the `adb-git-toolkit` command in `~/.local/bin`. If run again, it fast-forwards the existing install with `git pull` instead of re-cloning. If no `origin` remote is found, it falls back to a plain file copy (no auto-update support in that case). `uninstall.sh` removes both the install directory and the command symlink.

This is deliberate: the installed copy at `~/.local/share/adb-git-toolkit` is a real Git checkout so it can be fast-forwarded in place — both by the toolkit's own "Check for Updates" menu action and by Moonraker's update_manager (see below). Don't change `install.sh` to copy files without preserving this git-clone behavior; it would silently break both update paths.

## Architecture / conventions

- **Single-file menu app**: `scripts/adb-git-toolkit.sh` uses `set -u` and a `header()`/`pause()` pattern for consistent screen redraws between menu actions. Every action function starts with `header`, calls `require_git_repo` (except pure display actions where relevant), does its work, and ends with `pause`.
- **New menu actions**: add a new function following the existing pattern (`header` → guard → work → `pause`), then wire it into the `case` statement inside `main_menu` — remember to renumber the trailing `About` entry (currently `13`) if you insert before it.
- **No abstraction layer over git**: functions shell out directly to `git` (e.g., `git --no-pager status --short`, `git --no-pager diff --color`). Keep this direct style — don't introduce a wrapper/library layer for a script this size.
- **Destructive actions require typed confirmation, not just Enter**: `restore_configuration()` requires the user to type the word `restore` (not just accept a `[Y/n]` default) before overwriting working-tree files, since it can discard local edits. Follow this pattern for any future action that overwrites files or history.
- `check_for_updates()` operates on `TOOLKIT_ROOT` (`$HOME/.local/share/adb-git-toolkit`, matching `install.sh`'s `INSTALL_DIR`) — i.e. the *installed* copy, not necessarily the script currently executing. It fetches, compares local `HEAD` against `@{u}`, and only ever fast-forward merges (`git merge --ff-only`) after confirming the install has no local changes.
- `docs/usage.md` documents the exact behavior of every menu action (guards, confirmations, what's read-only vs. destructive) — update it alongside any change to `main_menu`'s actions. `docs/troubleshooting.md` covers concrete error messages users hit and their fixes.
- `examples/` holds a starting-point `.gitignore` for Klipper config repos and an example `moonraker.conf` excerpt showing the update_manager include in context.
- `klipper/moonraker-update.cfg` registers the toolkit with Moonraker's `update_manager` (`type: git_repo`, pointing at `TOOLKIT_ROOT`, `install_script: install.sh`) so Mainsail's Update Manager panel can show and apply updates too. Keep its `path`/`origin` in sync with `install.sh`'s `INSTALL_DIR` and this repo's GitHub URL if either changes.

## Windows dev-environment note

On Windows/Git Bash without symlink privileges, `ln -s` silently falls back to copying the file instead of creating a real symlink. `TOOLKIT_ROOT`/`check_for_updates()` deliberately avoid resolving the running script's own path (e.g. via `readlink -f "$0"`) for this reason — that approach breaks silently when the installed command isn't a real symlink. Don't reintroduce self-path resolution without accounting for this.
