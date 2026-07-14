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

  # Build a "library" copy of the script with the trailing CLI dispatch
  # block removed (everything from the "# --- CLI dispatch" marker to EOF),
  # so sourcing it only defines functions/vars and doesn't try to interpret
  # this harness's own $1/$# as an action name.
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/adb-git-toolkit.sh"
  LIB="$BATS_TEST_TMPDIR/lib.sh"
  sed '/^# --- CLI dispatch/,$d' "$SCRIPT" > "$LIB"

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

# Strips ANSI color escape codes (git --color always emits them, even when
# not attached to a TTY) so diff-preview assertions can match plain text.
strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*m//g'
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

@test "create_backup warns and cancels on a file at or above the size threshold" {
  # LARGE_FILE_THRESHOLD_BYTES is 5 MiB; write a 6 MiB file.
  dd if=/dev/zero of="$REPO_DIR/klippy.log" bs=1M count=6 status=none
  run_fn create_backup $'\n'
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"klippy.log"* ]]
  [[ "$output" == *"Backup cancelled"* ]]
  [ "$(commit_count)" -eq 0 ]
}

@test "create_backup proceeds past large-file warning with commit large files override" {
  dd if=/dev/zero of="$REPO_DIR/klippy.log" bs=1M count=6 status=none
  run_fn create_backup $'commit large files\n\ny\n'
  [[ "$output" == *"Backup created successfully"* ]]
  [ "$(commit_count)" -eq 1 ]
}

@test "create_backup does not warn about files under the size threshold" {
  dd if=/dev/zero of="$REPO_DIR/printer.cfg" bs=1M count=1 status=none
  run_fn create_backup $'\ny\n'
  [[ "$output" != *"WARNING"* ]]
  [ "$(commit_count)" -eq 1 ]
}

@test "create_backup shows a diff preview of tracked changes" {
  echo "line one" > "$REPO_DIR/printer.cfg"
  git -C "$REPO_DIR" add printer.cfg
  git -C "$REPO_DIR" commit -qm "add printer.cfg"
  echo "line two" >> "$REPO_DIR/printer.cfg"
  run_fn create_backup $'\ny\n'
  clean_output="$(strip_ansi <<< "$output")"
  [[ "$clean_output" == *"Diff of tracked changes"* ]]
  [[ "$clean_output" == *"+line two"* ]]
  [ "$(commit_count)" -eq 2 ]
}

@test "create_backup does not show a diff section for untracked-only changes" {
  echo "brand new file" > "$REPO_DIR/newfile.cfg"
  run_fn create_backup $'\ny\n'
  [[ "$output" != *"Diff of tracked changes"* ]]
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

@test "restore_configuration shows a diff preview before the typed confirmation" {
  echo "v1" > "$REPO_DIR/file.txt"
  git -C "$REPO_DIR" add file.txt
  git -C "$REPO_DIR" commit -qm "v1"
  echo "v2" > "$REPO_DIR/file.txt"
  git -C "$REPO_DIR" add file.txt
  git -C "$REPO_DIR" commit -qm "v2"

  run_fn restore_configuration $'2\nnotrestore\n'
  clean_output="$(strip_ansi <<< "$output")"
  [[ "$clean_output" == *"Preview of what this restore would change"* ]]
  [[ "$clean_output" == *"-v2"* ]]
  [[ "$clean_output" == *"+v1"* ]]
  [[ "$clean_output" == *"Restore cancelled"* ]]
}

# --- setup_repo_files -----------------------------------------------------

# Builds a fake toolkit install directory ($1) containing the example
# files, and echoes it so the caller can pass it as HOME to the test.
make_fake_toolkit_home() {
  local fake_home="$1"
  local examples_dir="$fake_home/.local/share/adb-git-toolkit/examples"
  mkdir -p "$examples_dir"
  echo "*.log" > "$examples_dir/gitignore.klipper"
  echo "* text=auto eol=lf" > "$examples_dir/gitattributes.klipper"
}

@test "setup_repo_files reports nothing to do when both files already exist" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  touch "$REPO_DIR/.gitignore" "$REPO_DIR/.gitattributes"
  run_fn setup_repo_files $'\n'
  [[ "$output" == *"already has both"* ]]
}

@test "setup_repo_files errors when toolkit examples are not installed" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  local fake_home="$BATS_TEST_TMPDIR/empty-home"
  mkdir -p "$fake_home"
  run bash -c "cd '$REPO_DIR' && HOME='$fake_home' source '$LIB' && printf '\n' | setup_repo_files"
  [[ "$output" == *"example files not found"* ]]
}

@test "setup_repo_files copies both missing files when confirmed" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  local fake_home="$BATS_TEST_TMPDIR/toolkit-home"
  make_fake_toolkit_home "$fake_home"
  run bash -c "cd '$REPO_DIR' && HOME='$fake_home' source '$LIB' && printf 'y\n' | setup_repo_files"
  [[ "$output" == *"Added .gitignore"* ]]
  [[ "$output" == *"Added .gitattributes"* ]]
  [ -f "$REPO_DIR/.gitignore" ]
  [ -f "$REPO_DIR/.gitattributes" ]
}

@test "setup_repo_files cancels when confirm is no" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  local fake_home="$BATS_TEST_TMPDIR/toolkit-home"
  make_fake_toolkit_home "$fake_home"
  run bash -c "cd '$REPO_DIR' && HOME='$fake_home' source '$LIB' && printf 'no\n' | setup_repo_files"
  [[ "$output" == *"Setup cancelled"* ]]
  [ ! -f "$REPO_DIR/.gitignore" ]
  [ ! -f "$REPO_DIR/.gitattributes" ]
}

@test "setup_repo_files only copies the file that is actually missing" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  echo "existing" > "$REPO_DIR/.gitignore"
  local fake_home="$BATS_TEST_TMPDIR/toolkit-home"
  make_fake_toolkit_home "$fake_home"
  run bash -c "cd '$REPO_DIR' && HOME='$fake_home' source '$LIB' && printf 'y\n' | setup_repo_files"
  [[ "$output" != *"Added .gitignore"* ]]
  [[ "$output" == *"Added .gitattributes"* ]]
  [ "$(cat "$REPO_DIR/.gitignore")" = "existing" ]
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

# --- CLI dispatch (uses the real, unstripped $SCRIPT) -----------------------

@test "CLI dispatch: --help prints usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"status"* ]]
}

@test "CLI dispatch: --version prints app name and version and exits 0" {
  run bash "$SCRIPT" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADB Git Toolkit"* ]]
}

@test "CLI dispatch: unknown action prints an error and exits 1" {
  run bash "$SCRIPT" bogus-action
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown action: bogus-action"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "CLI dispatch: status action runs and exits without hanging" {
  git -C "$REPO_DIR" commit --allow-empty -qm init
  run bash -c "cd '$REPO_DIR' && bash '$SCRIPT' status"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Repository Status"* ]]
}

@test "CLI dispatch: status action errors cleanly outside a git repository" {
  local outside="$BATS_TEST_TMPDIR/not-a-repo-cli"
  mkdir -p "$outside"
  run bash -c "cd '$outside' && bash '$SCRIPT' status"
  [[ "$output" == *"This is not a Git repository"* ]]
}

@test "CLI dispatch: no arguments still opens the interactive menu (backward compatible)" {
  # Note: read -rp only prints its prompt text when stdin is a real TTY, so
  # "Choose option:" itself never shows up in piped output -- assert on the
  # menu body (echoed unconditionally) instead.
  git -C "$REPO_DIR" commit --allow-empty -qm init
  run bash -c "cd '$REPO_DIR' && printf '0\n' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1) Repository Status"* ]]
  [[ "$output" == *"14) About"* ]]
}
