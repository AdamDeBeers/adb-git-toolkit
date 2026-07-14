# Menu Reference

Detailed behavior of each `adb-git-toolkit` menu option. All actions except **About** require you to be inside a Git repository — the toolkit checks this first and shows an error if you're not.

## 1) Repository Status

Runs `git status --short --branch`. Read-only.

## 2) Git Log / History

Shows the last 10 commits (`git log --oneline --decorate -10`). Read-only.

## 3) Remote Information

Shows configured remotes (`git remote -v`). Read-only.

## 4) Git Diff

Shows unstaged/staged changes (`git diff --color`), or "Working tree is clean." if there are none. Read-only.

## 5) Create Backup

Stages **all** changes (`git add .`) and commits them. Prompts for a commit message, defaulting to `Backup <date> <time>` if left blank, and asks for confirmation before committing. Does nothing if the working tree is already clean.

Before staging, it scans changed/untracked filenames against a best-effort pattern for likely secrets (`secrets.cfg`, `moonraker-secrets.cfg`, `.env*`, `*.pem`, `*.key`, `id_rsa*`, and anything with `password`, `credential`, or `token` in the name). If any match, it warns and requires typing `commit secrets` to proceed — a plain Enter cancels. This is a heuristic, not a security guarantee; the real fix is adding sensitive files to `.gitignore` (see [examples/gitignore.klipper](../examples/gitignore.klipper)).

## 6) Push to GitHub

Pushes the current branch to a configured remote. If only one remote is configured, it's used automatically; if there's more than one, you're shown a numbered list (with URLs) and asked which to push to. Refuses to run if there's no remote, no branch (detached HEAD), or uncommitted changes — commit with **Create Backup** first. On the first push for a branch, it sets the upstream (`git push -u`); afterwards it's a plain `git push`.

## 7) Safe Pull

Runs `git pull`, but only if the working tree is clean. If there are local changes, it lists them and stops instead of risking a conflicted merge.

## 8) Switch Branch

Lists local branches (marking the current one) and checks out the one you pick by number. Refuses to run if the working tree has uncommitted changes — commit them with **Create Backup** or set them aside with **Quick Stash** first. Picking the branch you're already on, or entering `0`, cancels without doing anything.

## 9) Quick Stash

A single action that does one of two things depending on the working tree:
- If there are uncommitted changes, it offers to stash them (`git stash push -u`, which includes untracked files) after showing what would be stashed.
- If the working tree is clean and a stash exists, it offers to pop the most recent one (`git stash pop`).
- If the working tree is clean and there's nothing stashed, it says so and does nothing.

## 10) Repository Health

A read-only summary: repository name, current branch, remote name, upstream tracking branch, last commit, working-tree cleanliness, whether upstream is configured, whether the remote is reachable (`git ls-remote`), and whether `HEAD` is detached.

## 11) Configuration Restore

Lets you pick one of the last 10 commits and checks out **all tracked files** from that commit into the working tree (`git checkout <commit> -- .`). This does not rewrite history — it only changes working-tree file contents, staged and ready to review.

Safety rails:
- Refuses to run if the working tree already has uncommitted changes (commit or discard them first).
- Requires typing the word `restore` to confirm — a plain Enter does not proceed.

After restoring, use **Git Diff** to review what changed, then **Create Backup** to commit the restore if you want to keep it.

## 12) Check for Updates

Unlike the other actions, this operates on the **toolkit's own installation** (`~/.local/share/adb-git-toolkit`), not the repository you're currently in. It only works if the toolkit was installed via `install.sh` from a repo with a Git remote (see the main [README](../README.md#installation)).

It fetches from the toolkit's remote, compares the local commit against the upstream one, and:
- reports "up to date" if they match;
- otherwise lists the new commits and asks for confirmation before fast-forwarding (`git merge --ff-only`).

It refuses to update if the installed copy has local changes, and reports a clear error if the install isn't a Git checkout or has no upstream configured.

## 13) About

Prints the toolkit name and version. Read-only.

## 0) Exit

Quits the menu.
