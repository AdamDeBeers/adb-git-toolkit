# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased] - v0.1.2-dev

### Added

- Push to GitHub now prompts you to choose which remote to push to when more than one is configured, instead of always using the first one.
- Switch Branch menu action: lists local branches and checks out the one you pick, refusing to run on a dirty working tree.
- Quick Stash menu action: stashes uncommitted changes (including untracked files) on a dirty tree, or offers to pop the most recent stash on a clean one.
- `tests/adb-git-toolkit.bats` test suite covering guard clauses (dirty tree, no remote, detached HEAD, no commits, etc.), `[Y/n]` confirmation parsing, and the Create Backup secrets-warning heuristic. Wired into CI via `.github/workflows/tests.yml`.
- Create Backup now warns and requires typing `commit secrets` to proceed if any changed/untracked file looks like it may contain secrets (`secrets.cfg`, `.env*`, `*.pem`, `*.key`, `id_rsa*`, or filenames containing `password`/`credential`/`token`).
- Mainsail integration via Moonraker's `update_manager` (`klipper/moonraker-update.cfg`), so the toolkit shows up in Mainsail's Update Manager panel with update status and an Update button.
- Automatic updates: a "Check for Updates" menu action that fetches and fast-forward merges the installed toolkit, refusing to update if the install has local changes.
- Configuration Restore menu action to check out tracked files from a chosen previous commit, requiring a typed `restore` confirmation before overwriting the working tree.
- Push to GitHub menu action, including first-push upstream setup and a check for uncommitted changes before pushing.
- `install.sh` / `uninstall.sh`: install the toolkit as an `adb-git-toolkit` command in `~/.local/bin`, cloning it (rather than copying) so it can be tracked and updated in place.
- Git Diff, Create Backup (commit), Safe Pull, and About menu actions.
- Repository Health check (branch, remote, upstream, and remote-reachability status).
- Initial project structure: interactive Bash menu (`scripts/adb-git-toolkit.sh`) with Repository Status, Git Log/History, and Remote Information.

### Changed

- Renamed menu labels for consistency ("Git Status" → "Repository Status", "Recent Commits" → "Git Log / History", "Remote URL" → "Remote Information").
- Switched `git status`/`git log`/`git diff` calls to `--no-pager` so output doesn't hang waiting for a pager.

### Fixed

- Create Backup, Push to GitHub, and Check for Updates confirmation prompts now correctly cancel on `no`/`No` as well as `n`/`N` (previously only a bare `n`/`N` matched, so typing "no" was silently treated as confirmation).
