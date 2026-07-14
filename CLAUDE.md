# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ADB Git Toolkit (ADB GT) is an open-source Git/GitHub workflow toolkit for Klipper-based 3D printers (Voron and similar), intended to integrate with Mainsail. The project is in early development (v0.1.1-dev).

The entire toolkit is currently a single interactive Bash script: `scripts/adb-git-toolkit.sh`. It presents a numbered menu (`main_menu`) driving one function per action (status, log, remote info, diff, backup/commit, safe pull, repository health, about). There is no build step, package manager, or test suite yet — `install.sh` and `uninstall.sh` are empty placeholders not yet implemented.

## Running the toolkit

```bash
bash scripts/adb-git-toolkit.sh
```

The script is meant to run from inside the target Git repository (e.g., a Klipper config repo) — most menu actions call `require_git_repo` and bail out with an error message if run outside one.

## Architecture / conventions

- **Single-file menu app**: `scripts/adb-git-toolkit.sh` uses `set -u` and a `header()`/`pause()` pattern for consistent screen redraws between menu actions. Every action function starts with `header`, calls `require_git_repo` (except pure display actions where relevant), does its work, and ends with `pause`.
- **New menu actions**: add a new function following the existing pattern (`header` → guard → work → `pause`), then wire it into the `case` statement inside `main_menu`.
- **No abstraction layer over git**: functions shell out directly to `git` (e.g., `git --no-pager status --short`, `git --no-pager diff --color`). Keep this direct style — don't introduce a wrapper/library layer for a script this size.
- Empty top-level directories (`docs/`, `examples/`, `klipper/`) are reserved per the structure described in `README.md` (documentation, example configs, Klipper macros/config) but have no content yet.

## Roadmap context (from README)

Implemented: GitHub Backup, Repository Status. Not yet implemented: Installer, Git History, Git Diff, Configuration Restore, Automatic updates — check the README roadmap before assuming a feature exists.
