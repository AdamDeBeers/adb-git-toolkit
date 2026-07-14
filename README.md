# ADB Git Toolkit

Professional Git toolkit for Klipper-based 3D printers.

ADB Git Toolkit (ADB GT) is an open-source toolkit that simplifies Git and GitHub workflows for Klipper-based 3D printers.

## Vision

ADB Git Toolkit aims to make Git and GitHub integration effortless for Klipper users, with clean shell scripts, simple installation, and seamless Mainsail integration.

## Features

- GitHub Backup
- Push to GitHub
- Repository Status
- Git History
- Git Diff
- Safe Pull
- Repository Health check
- Configuration Restore
- Automatic updates
- One-command installer
- Mainsail integration

## Installation

```bash
git clone https://github.com/<your-org>/adb-git-toolkit.git
cd adb-git-toolkit
./install.sh
```

This clones the toolkit into `~/.local/share/adb-git-toolkit` (tracking the same Git remote you cloned from) and links the `adb-git-toolkit` command into `~/.local/bin`. If that directory isn't already on your `PATH`, the installer prints the line to add to your shell profile. Because the install is a Git checkout, the toolkit's "Check for Updates" menu option can pull new releases in place.

To remove it again:

```bash
./uninstall.sh
```

## Usage

Run the command from inside the Git repository you want to manage (e.g. your Klipper config repo):

```bash
adb-git-toolkit
```

This opens an interactive menu for repository status, history, diffs, backups, pushing to GitHub, safe pulling, repository health checks, configuration restore, and checking for toolkit updates.

## Roadmap

[x] GitHub Backup
[x] Push to GitHub
[x] Repository Status
[x] Installer
[x] Git History
[x] Git Diff
[x] Configuration Restore
[x] Automatic updates
[ ] Mainsail integration

## Project Status

🚧 Early development (v0.1.1-dev)

## Project Structure

```text
docs/            Documentation
examples/        Example configurations
klipper/         Klipper macros and config
scripts/         Core shell scripts
install.sh       Installer
uninstall.sh     Uninstaller
```