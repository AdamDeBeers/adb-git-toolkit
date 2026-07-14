#!/usr/bin/env bash

set -u

APP_NAME="ADB Git Toolkit"
APP_VERSION="v0.1.1-dev"

pause() {
  echo
  read -rp "Press Enter to continue..."
}

header() {
  clear
  echo "======================================"
  echo "        $APP_NAME $APP_VERSION"
  echo "======================================"
  echo
}

require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: This is not a Git repository."
    pause
    return 1
  fi
}

show_status() {
  header
  echo "[ Repository Status ]"
  echo
  require_git_repo || return

  git --no-pager status --short
  echo
  git status --branch --short

  pause
}

show_log() {
  header
  echo "[ Git Log / History ]"
  echo
  require_git_repo || return

  git --no-pager log --oneline --decorate -10

  pause
}

show_remote() {
  header
  echo "[ Remote Information ]"
  echo
  require_git_repo || return

  git remote -v

  pause
}

show_diff() {
  header
  echo "[ Git Diff ]"
  echo

  require_git_repo || return

  if [[ -z "$(git status --porcelain)" ]]; then
    echo "Working tree is clean."
  else
    git --no-pager diff --color
  fi

  pause
}

create_backup() {
  header
  echo "[ Create Backup ]"
  echo

  require_git_repo || return

  if [[ -z "$(git status --porcelain)" ]]; then
    echo "No changes detected."
    echo
    echo "Nothing to commit."
    pause
    return
  fi

  echo "Modified files:"
  echo
  git --no-pager status --short

  echo
  echo "--------------------------------------"
  echo
  echo "Backup name"
  echo "(Press Enter for automatic name)"
  echo

  read -rp "> " backup_name

  if [[ -z "$backup_name" ]]; then
    backup_name="Backup $(date '+%Y-%m-%d %H:%M')"
  fi

  echo
  echo "Backup summary"
  echo "--------------------------------------"
  echo
  echo "Backup name:"
  echo "$backup_name"
  echo
  echo "Files:"
  git --no-pager status --short
  echo

  read -rp "Continue? [Y/n]: " confirm

  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo
    echo "Backup cancelled."
    pause
    return
  fi

  echo
  echo "Adding files..."
  git add .

  echo "Creating backup..."
  if git commit -m "$backup_name"; then
    echo
    echo "Backup created successfully."
    echo
    git --no-pager log -1 --oneline
  else
    echo
    echo "ERROR: Backup failed."
  fi

  pause
}

safe_pull() {
  header
  echo "[ Safe Pull ]"
  echo
  require_git_repo || return

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Local changes detected."
    echo "Commit, stash, or clean them before pulling."
    echo
    git --no-pager status --short
    pause
    return
  fi

  git pull
  pause
}

push_to_github() {
  header
  echo "[ Push to GitHub ]"
  echo

  require_git_repo || return

  remote_name="$(git remote | head -n 1)"

  if [[ -z "$remote_name" ]]; then
    echo "ERROR: No remote configured."
    echo "Add one with: git remote add origin <url>"
    pause
    return
  fi

  branch_name="$(git branch --show-current)"

  if [[ -z "$branch_name" ]]; then
    echo "ERROR: Not on a branch (detached HEAD)."
    pause
    return
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Uncommitted changes detected:"
    echo
    git --no-pager status --short
    echo
    echo "Create a backup (commit) first, then push."
    pause
    return
  fi

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  echo "Remote : $remote_name"
  echo "Branch : $branch_name"
  echo

  read -rp "Push to '$remote_name/$branch_name'? [Y/n]: " confirm

  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo
    echo "Push cancelled."
    pause
    return
  fi

  echo

  if [[ -z "$upstream" ]]; then
    echo "No upstream set. Pushing with 'git push -u $remote_name $branch_name'..."
    if git push -u "$remote_name" "$branch_name"; then
      echo
      echo "Push successful. Upstream configured."
    else
      echo
      echo "ERROR: Push failed."
    fi
  else
    echo "Pushing..."
    if git push; then
      echo
      echo "Push successful."
    else
      echo
      echo "ERROR: Push failed. You may need to pull first."
    fi
  fi

  pause
}

repository_health() {
  header
  echo "[ Repository Health ]"
  echo

  require_git_repo || return

  repo_name="$(basename "$(git rev-parse --show-toplevel)")"
  branch_name="$(git branch --show-current)"
  remote_name="$(git remote | head -n 1)"
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  last_commit="$(git log -1 --pretty=format:'%h %s' 2>/dev/null || echo 'No commits yet')"

  echo "Repository : $repo_name"
  echo "Branch     : ${branch_name:-DETACHED}"
  echo "Remote     : ${remote_name:-none}"
  echo "Upstream   : ${upstream:-not configured}"
  echo "Last commit: $last_commit"
  echo

  if [[ -z "$(git status --porcelain)" ]]; then
    echo "[OK] Working tree clean"
  else
    echo "[WARN] Local changes detected"
    git --no-pager status --short
  fi

  echo

  if [[ -n "$upstream" ]]; then
    echo "[OK] Upstream configured"
  else
    echo "[WARN] No upstream configured"
  fi

  if [[ -n "$remote_name" ]]; then
    if git ls-remote "$remote_name" >/dev/null 2>&1; then
      echo "[OK] Remote reachable"
    else
      echo "[WARN] Remote not reachable"
    fi
  else
    echo "[WARN] No remote configured"
  fi

  if git symbolic-ref -q HEAD >/dev/null; then
    echo "[OK] Detached HEAD: No"
  else
    echo "[WARN] Detached HEAD: Yes"
  fi

  pause
}

restore_configuration() {
  header
  echo "[ Configuration Restore ]"
  echo

  require_git_repo || return

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Uncommitted changes detected."
    echo "Commit or discard them first, so a restore doesn't destroy work."
    echo
    git --no-pager status --short
    pause
    return
  fi

  mapfile -t commits < <(git log --oneline -10)

  if [[ ${#commits[@]} -eq 0 ]]; then
    echo "No commits found."
    pause
    return
  fi

  echo "Recent commits:"
  echo
  local i=1
  for line in "${commits[@]}"; do
    echo "$i) $line"
    i=$((i + 1))
  done

  echo
  read -rp "Restore files from which commit? (number, 0 to cancel): " selection

  if [[ -z "$selection" || "$selection" == "0" ]]; then
    echo
    echo "Restore cancelled."
    pause
    return
  fi

  if ! [[ "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > ${#commits[@]} )); then
    echo
    echo "Invalid selection."
    pause
    return
  fi

  selected_line="${commits[$((selection - 1))]}"
  selected_hash="${selected_line%% *}"

  echo
  echo "Selected commit:"
  echo "$selected_line"
  echo
  echo "This overwrites all tracked files in the working tree with their"
  echo "contents from this commit. Commit history is not changed."
  echo

  read -rp "Type 'restore' to confirm: " confirm

  if [[ "$confirm" != "restore" ]]; then
    echo
    echo "Restore cancelled."
    pause
    return
  fi

  echo
  echo "Restoring files from $selected_hash..."

  if git checkout "$selected_hash" -- .; then
    echo
    echo "Files restored from commit $selected_hash."
    echo "Review with Git Diff, then use Create Backup to commit the restore."
  else
    echo
    echo "ERROR: Restore failed."
  fi

  pause
}

main_menu() {
  while true; do
    header
    echo "1) Repository Status"
    echo "2) Git Log / History"
    echo "3) Remote Information"
    echo "4) Git Diff"
    echo "5) Create Backup"
    echo "6) Push to GitHub"
    echo "7) Safe Pull"
    echo "8) Repository Health"
    echo "9) Configuration Restore"
    echo "10) About"
    echo "0) Exit"
    echo
    read -rp "Choose option: " choice

    case "$choice" in
      1) show_status ;;
      2) show_log ;;
      3) show_remote ;;
      4) show_diff ;;
      5) create_backup ;;
      6) push_to_github ;;
      7) safe_pull ;;
      8) repository_health ;;
      9) restore_configuration ;;
      10)
        header
        echo "ADB Git Toolkit"
        echo "Version : $APP_VERSION"
        echo
        echo "Open-source Git toolkit for Klipper & Voron."
        echo
        pause
        ;;
      0)
        clear
        exit 0
        ;;
      *)
        echo "Invalid option"
        pause
        ;;
    esac
  done
}

main_menu