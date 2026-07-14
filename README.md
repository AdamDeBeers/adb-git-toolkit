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
- Switch Branch
- Quick Stash
- Repository Health check
- Configuration Restore
- Setup Repo Files (starter .gitignore/.gitattributes)
- Non-interactive CLI mode for scripting/automation
- Automatic updates
- One-command installer
- Mainsail integration

## Installation

```bash
git clone https://github.com/AdamDeBeers/adb-git-toolkit.git
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

This opens an interactive menu for repository status, history, diffs, backups, pushing to GitHub, safe pulling, repository health checks, configuration restore, and checking for toolkit updates. See [docs/usage.md](docs/usage.md) for a detailed breakdown of what each menu option does, and [docs/troubleshooting.md](docs/troubleshooting.md) if something isn't behaving as expected.

## Mainsail Integration

`klipper/moonraker-update.cfg` registers ADB Git Toolkit with Moonraker's `update_manager`, so it shows up in Mainsail under **Machine > Update Manager** with its current commit and an Update button.

To enable it:

1. Install the toolkit with `./install.sh` (this makes `~/.local/share/adb-git-toolkit` a Git checkout Moonraker can track).
2. Copy `klipper/moonraker-update.cfg` into your Moonraker config directory (e.g. `~/printer_data/config/`).
3. Add this line to `moonraker.conf`:

   ```ini
   [include moonraker-update.cfg]
   ```

   See [examples/moonraker.conf.example](examples/moonraker.conf.example) for this in context alongside other `[update_manager]` clients.

4. Restart Moonraker.

## Examples

- [examples/gitignore.klipper](examples/gitignore.klipper) — a starting-point `.gitignore` for a Klipper config repo (backup files, logs, secrets).
- [examples/gitattributes.klipper](examples/gitattributes.klipper) — a starting-point `.gitattributes` for a Klipper config repo, normalizing line endings for configs edited across Pi/Windows/Mac.
- [examples/moonraker.conf.example](examples/moonraker.conf.example) — where the Mainsail Integration include line fits in a real `moonraker.conf`.

## Roadmap

[x] GitHub Backup
[x] Push to GitHub
[x] Repository Status
[x] Installer
[x] Git History
[x] Git Diff
[x] Configuration Restore
[x] Automatic updates
[x] Mainsail integration

## Project Status

🚧 Early development (v0.3.0)

## Project Structure

```text
docs/            Documentation (usage reference, troubleshooting)
examples/        Example configurations (.gitignore, moonraker.conf)
klipper/         Klipper macros and config (Moonraker update_manager entry)
scripts/         Core shell scripts
install.sh       Installer
uninstall.sh     Uninstaller
```

## License

[MIT](LICENSE)
