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
  echo "[ Git Status ]"
  echo
  require_git_repo || return

  git status --short
  echo
  git status --branch --short

  pause
}

show_log() {
  header
  echo "[ Recent Commits ]"
  echo
  require_git_repo || return

  git log --oneline --decorate -10

  pause
}

show_remote() {
  header
  echo "[ Git Remote ]"
  echo
  require_git_repo || return

  git remote -v

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
    git status --short
    pause
    return
  fi

  git pull
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
    git status --short
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

main_menu() {
  while true; do
    header
    echo "1) Git status"
    echo "2) Recent commits"
    echo "3) Remote URL"
    echo "4) Safe pull"
    echo "5) Repository health"
    echo "0) Exit"
    echo
    read -rp "Choose option: " choice

    case "$choice" in
      1) show_status ;;
      2) show_log ;;
      3) show_remote ;;
      4) safe_pull ;;
      5) repository_health ;;
      0) clear; exit 0 ;;
      *) echo "Invalid option"; pause ;;
    esac
  done
}

main_menu