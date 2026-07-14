# Troubleshooting

## `adb-git-toolkit: command not found` after installing

`~/.local/bin` (where `install.sh` links the command) isn't on your `PATH`. The installer prints the exact line to add to your shell profile when this happens:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add it to `~/.bashrc` (or `~/.zshrc`) and restart your shell, or run the script directly: `~/.local/share/adb-git-toolkit/scripts/adb-git-toolkit.sh`.

## `ERROR: This is not a Git repository.`

You ran `adb-git-toolkit` outside a Git repository. `cd` into the repository you want to manage (e.g. your Klipper config directory) first.

## Push to GitHub says `ERROR: No remote configured.`

The repository you're pushing from has no `origin`. Add one before pushing:

```bash
git remote add origin <url>
```

## An action refuses to run because of "uncommitted changes"

**Push to GitHub**, **Safe Pull**, and **Configuration Restore** all refuse to run against a dirty working tree, to avoid silently discarding or conflicting with your edits. Use **Create Backup** to commit your changes first, or discard them manually (`git checkout -- .`) if you don't need them.

## Check for Updates says the install "is not a Git checkout"

`install.sh` only clones the toolkit (enabling updates) when it can find a Git `origin` remote at install time. If it fell back to a plain file copy — because you ran it from a repo without a remote — reinstall from a proper clone of the toolkit's GitHub repo to enable automatic updates.

## Check for Updates says "No upstream configured"

The toolkit's installed copy isn't tracking a remote branch. This shouldn't happen with a fresh clone; if you see it, check `git -C ~/.local/share/adb-git-toolkit branch -vv` and re-run `install.sh` to reinstall a clean checkout.

## On Windows, the installed command doesn't behave like a symlink

Git Bash on Windows without symlink privileges makes `ln -s` silently copy the file instead of creating a real symlink. The installed `adb-git-toolkit` command still works, but it won't automatically reflect changes to the source script — re-run `install.sh` to refresh it. This doesn't affect Linux installs (the toolkit's intended target platform), where `ln -s` creates a real symlink.
