#!/usr/bin/env bats
#
# Tests for scripts/adb-git-toolkit.sh menu functions.
#
# Each test sources the script functions (with the trailing main_menu
# call stripped so nothing tries to read from a real terminal) into a
# throwaway git repo, then drives the function under test by piping
# canned input to it -- the same way the interactive menu would receive it.

setup() {
  export TERM=dumb

  # Build a "library" copy of the script with the final main_menu
  # invocation removed, so sourcing it only defines functions/vars.
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/adb-git-toolkit.sh"
  LIB="$BATS_TEST_TMPDIR/lib.sh"
  head -n -1 "$SCRIPT" > "$LIB"

  REPO_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO_DIR"
  git -C "$REPO_DIR" init -q
  git -C "$REPO_DIR" config user.email "test@example.com"
  git -C "$REPO_DIR" config user.name "Test User"
}

# Runs a function from the script inside $REPO_DIR, piping $2 as stdin.
# Usage: run_fn "create_backup" $'input line 1\ninput line 2\n'
run_fn() {
  local fn="$1"
  local input="${2:-}"
  run bash -c "cd '$REPO_DIR' && source '$LIB' && printf '%s' \"\$1\" | $fn" _ "$input"
}

commit_count() {
  git -C "$REPO_DIR" log --oneline 2>/dev/null | wc -l | tr -d ' '
}

# --- require_git_repo ---------------------------------------------------

@test "require_git_repo fails outside a git repository" {
  local outside="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$outside"
  run bash -c "cd '$outside' && source '$LIB' && printf '\n' | require_git_repo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"This is not a Git repository"* ]]
}

@test "require_git_repo succeeds inside a git repository" {
  run bash -c "cd '$REPO_DIR' && source '$LIB' && require_git_repo"
  [ "$status" -eq 0 ]
}

# --- show_status (read-only smoke test) ----------------------------------

@test "show_status runs without error inside a repo" {
  run_fn show_status $'\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Repository Status"* ]]
}

# --- create_backup: confirm-prompt regression ----------------------------

@test "create_backup does nothing on a clean tree" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  run_fn create_backup $'\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to commit"* ]]
  [ "$(commit_count)" -eq 1 ]
}

@test "create_backup cancels when confirm is n" {
  echo "hello" > "$REPO_DIR/file.txt"
  run_fn create_backup $'\nn\n'
  [[ "$output" == *"Backup cancelled"* ]]
  [ "$(commit_count)" -eq 0 ]
}

@test "create_backup cancels when confirm is no (regression for the Y/n bug)" {
  echo "hello" > "$REPO_DIR/file.txt"
  run_fn create_backup $'\nno\n'
  [[ "$output" == *"Backup cancelled"* ]]
  [ "$(commit_count)" -eq 0 ]
}

@test "create_backup cancels when confirm is NO (case-insensitive)" {
  echo "hello" > "$REPO_DIR/file.txt"
  run_fn create_backup $'\nNO\n'
  [[ "$output" == *"Backup cancelled"* ]]
  [ "$(commit_count)" -eq 0 ]
}

@test "create_backup commits when confirm is y" {
  echo "hello" > "$REPO_DIR/file.txt"
  run_fn create_backup $'\ny\n'
  [[ "$output" == *"Backup created successfully"* ]]
  [ "$(commit_count)" -eq 1 ]
}

# --- create_backup: secrets warning --------------------------------------

@test "create_backup warns and cancels on a likely secrets file with no override" {
  echo "API_KEY=xyz" > "$REPO_DIR/secrets.cfg"
  run_fn create_backup $'\n'
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"secrets.cfg"* ]]
  [[ "$output" == *"Backup cancelled"* ]]
  [ "$(commit_count)" -eq 0 ]
}

@test "create_backup detects secrets nested in a new untracked directory" {
  mkdir -p "$REPO_DIR/sub"
  echo "x" > "$REPO_DIR/sub/id_rsa"
  run_fn create_backup $'\n'
  [[ "$output" == *"sub/id_rsa"* ]]
  [ "$(commit_count)" -eq 0 ]
}

@test "create_backup proceeds past secrets warning with commit secrets override" {
  echo "API_KEY=xyz" > "$REPO_DIR/secrets.cfg"
  run_fn create_backup $'commit secrets\n\ny\n'
  [[ "$output" == *"Backup created successfully"* ]]
  [ "$(commit_count)" -eq 1 ]
}

@test "create_backup does not warn on ordinary files" {
  echo "printer settings" > "$REPO_DIR/printer.cfg"
  run_fn create_backup $'\ny\n'
  [[ "$output" != *"WARNING"* ]]
  [ "$(commit_count)" -eq 1 ]
}

# --- push_to_github -------------------------------------------------------

@test "push_to_github errors with no remote configured" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  run_fn push_to_github $'\n'
  [[ "$output" == *"No remote configured"* ]]
}

@test "push_to_github refuses with uncommitted changes" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  git -C "$REPO_DIR" remote add origin https://example.invalid/repo.git
  echo "x" > "$REPO_DIR/file.txt"
  run_fn push_to_github $'\n'
  [[ "$output" == *"Uncommitted changes detected"* ]]
}

@test "push_to_github cancels when confirm is no (regression for the Y/n bug)" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  git -C "$REPO_DIR" remote add origin https://example.invalid/repo.git
  run_fn push_to_github $'no\n'
  [[ "$output" == *"Push cancelled"* ]]
}

@test "push_to_github with a single remote does not prompt for a selection" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  git -C "$REPO_DIR" remote add origin https://example.invalid/repo.git
  run_fn push_to_github $'no\n'
  [[ "$output" != *"Multiple remotes configured"* ]]
  [[ "$output" == *"Remote : origin"* ]]
}

@test "push_to_github with multiple remotes prompts and accepts a valid selection" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  # git remote lists remotes alphabetically, so 'backup' sorts before 'origin'.
  git -C "$REPO_DIR" remote add origin https://example.invalid/origin.git
  git -C "$REPO_DIR" remote add backup https://example.invalid/backup.git
  run_fn push_to_github $'1\nno\n'
  [[ "$output" == *"Multiple remotes configured"* ]]
  [[ "$output" == *"Remote : backup"* ]]
}

@test "push_to_github with multiple remotes rejects an invalid selection" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  git -C "$REPO_DIR" remote add origin https://example.invalid/origin.git
  git -C "$REPO_DIR" remote add backup https://example.invalid/backup.git
  run_fn push_to_github $'9\n'
  [[ "$output" == *"Invalid selection"* ]]
}

# --- safe_pull --------------------------------------------------------------

@test "safe_pull refuses to run with local changes" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  echo "x" > "$REPO_DIR/file.txt"
  run_fn safe_pull $'\n'
  [[ "$output" == *"Local changes detected"* ]]
}

# --- restore_configuration --------------------------------------------------

@test "restore_configuration reports no commits found on a brand-new repo" {
  run_fn restore_configuration $'\n'
  [[ "$output" == *"No commits found"* ]]
}

@test "restore_configuration cancels on selection 0" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  run_fn restore_configuration $'0\n'
  [[ "$output" == *"Restore cancelled"* ]]
}

@test "restore_configuration requires the typed word restore to proceed" {
  echo "v1" > "$REPO_DIR/file.txt"
  git -C "$REPO_DIR" add file.txt
  git -C "$REPO_DIR" commit -qm "v1"
  echo "v2" > "$REPO_DIR/file.txt"
  git -C "$REPO_DIR" add file.txt
  git -C "$REPO_DIR" commit -qm "v2"

  run_fn restore_configuration $'1\nyes\n'
  [[ "$output" == *"Restore cancelled"* ]]
  [ "$(cat "$REPO_DIR/file.txt")" = "v2" ]
}

@test "restore_configuration restores file contents when confirmed" {
  echo "v1" > "$REPO_DIR/file.txt"
  git -C "$REPO_DIR" add file.txt
  git -C "$REPO_DIR" commit -qm "v1"
  echo "v2" > "$REPO_DIR/file.txt"
  git -C "$REPO_DIR" add file.txt
  git -C "$REPO_DIR" commit -qm "v2"

  run_fn restore_configuration $'2\nrestore\n'
  [[ "$output" == *"Files restored"* ]]
  [ "$(cat "$REPO_DIR/file.txt")" = "v1" ]
}

# --- check_for_updates -------------------------------------------------------

@test "check_for_updates errors when TOOLKIT_ROOT is not a git checkout" {
  local fake_home="$BATS_TEST_TMPDIR/fake-home"
  mkdir -p "$fake_home"
  run bash -c "cd '$REPO_DIR' && HOME='$fake_home' source '$LIB' && printf '\n' | check_for_updates"
  [[ "$output" == *"is not a Git checkout"* ]]
}

# --- switch_branch -----------------------------------------------------------

@test "switch_branch refuses with uncommitted changes" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  echo "x" > "$REPO_DIR/file.txt"
  run_fn switch_branch $'\n'
  [[ "$output" == *"Uncommitted changes detected"* ]]
}

@test "switch_branch cancels on selection 0" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  git -C "$REPO_DIR" branch other
  run_fn switch_branch $'0\n'
  [[ "$output" == *"Switch cancelled"* ]]
}

@test "switch_branch rejects an invalid selection" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  git -C "$REPO_DIR" branch other
  run_fn switch_branch $'99\n'
  [[ "$output" == *"Invalid selection"* ]]
}

@test "switch_branch checks out the selected branch" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  git -C "$REPO_DIR" branch other
  mapfile -t branches < <(git -C "$REPO_DIR" branch --format='%(refname:short)')
  local idx
  for i in "${!branches[@]}"; do
    if [[ "${branches[$i]}" == "other" ]]; then
      idx=$((i + 1))
    fi
  done
  run_fn switch_branch "$idx"$'\n'
  [[ "$output" == *"Switched to 'other'"* ]]
  [ "$(git -C "$REPO_DIR" branch --show-current)" = "other" ]
}

# --- quick_stash ---------------------------------------------------------------

@test "quick_stash stashes uncommitted changes when confirmed" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  echo "x" > "$REPO_DIR/file.txt"
  run_fn quick_stash $'y\n'
  [[ "$output" == *"Changes stashed"* ]]
  [ -z "$(git -C "$REPO_DIR" status --porcelain)" ]
  [ "$(git -C "$REPO_DIR" stash list | wc -l | tr -d ' ')" -eq 1 ]
}

@test "quick_stash cancels when confirm is no" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  echo "x" > "$REPO_DIR/file.txt"
  run_fn quick_stash $'no\n'
  [[ "$output" == *"Stash cancelled"* ]]
  [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]
}

@test "quick_stash reports nothing to do on a clean tree with no stashes" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  run_fn quick_stash $'\n'
  [[ "$output" == *"no stashes"* ]]
}

@test "quick_stash pops the most recent stash on a clean tree when confirmed" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  echo "x" > "$REPO_DIR/file.txt"
  git -C "$REPO_DIR" stash push -u -m "test stash"

  run_fn quick_stash $'y\n'
  [[ "$output" == *"Stash applied"* ]]
  [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]
}

# --- repository_health (read-only smoke test) --------------------------------

@test "repository_health prints a summary" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  run_fn repository_health $'\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Repository :"* ]]
  [[ "$output" == *"Branch"* ]]
}
