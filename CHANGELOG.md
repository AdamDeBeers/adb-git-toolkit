# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Fixed

- `install.sh`, `uninstall.sh`, and `scripts/adb-git-toolkit.sh` are now tracked as executable in git (they were `100644`, non-executable). This was the cause of two real bugs found during hardware testing: `./install.sh` failing with `Permission denied` on a fresh clone, and Moonraker's `update_manager` permanently flagging the installed copy as "dirty" (since `install.sh`'s own `chmod +x` on the installed checkout created an uncommitted mode diff every time).
- README installation command had a broken clone URL (missing the GitHub username entirely: `github.com/adb-git-toolkit.git`) from a prior fix that dropped it; corrected to `github.com/AdamDeBeers/adb-git-toolkit.git`.

## [v0.3.0] - 2026-07-14

### Added

- Non-interactive CLI mode: `adb-git-toolkit <action>` (e.g. `status`, `backup`, `push`, `health`) runs one action and exits, plus `--help`/`--version`. Running with no arguments still opens the interactive menu as before. The final "Press Enter to continue" pause is now skipped automatically whenever stdin isn't a real terminal, so scripted/cron invocations never hang.
- `[OK]`/`[WARN]` tags and `ERROR:` messages throughout the toolkit are now colored green/yellow/red when connected to a real terminal, honoring `NO_COLOR` and staying plain text when output isn't a TTY (e.g. piped or logged).
- Create Backup now shows a full diff of tracked changes (not just filenames) before asking for the commit message. Configuration Restore shows a diff preview of exactly what a restore would change before requiring the typed `restore` confirmation.
- Setup Repo Files menu action: detects a missing `.gitignore`/`.gitattributes` in the current repo and offers to copy in the toolkit's starter versions (`examples/gitignore.klipper`, `examples/gitattributes.klipper`) from its own installation. Only fills in what's actually missing, never overwrites.
- Create Backup now also warns and requires typing `commit large files` to proceed if any changed/untracked file is 5 MB or larger (catches accidental `klippy.log`/firmware `.bin` commits that bloat repo size permanently).

## [v0.2.0] - 2026-07-14

### Added

- `examples/gitattributes.klipper`: a starting-point `.gitattributes` normalizing line endings for Klipper config repos edited across Pi/Windows/Mac.
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

- Repository Status now runs a single combined `git status --short --branch` instead of two separate `git status` invocations.
- Menu numbering padded for alignment (single-digit entries get a leading space).
- Renamed menu labels for consistency ("Git Status" → "Repository Status", "Recent Commits" → "Git Log / History", "Remote URL" → "Remote Information").
- Switched `git status`/`git log`/`git diff` calls to `--no-pager` so output doesn't hang waiting for a pager.

### Fixed

- Create Backup, Push to GitHub, and Check for Updates confirmation prompts now correctly cancel on `no`/`No` as well as `n`/`N` (previously only a bare `n`/`N` matched, so typing "no" was silently treated as confirmation).
