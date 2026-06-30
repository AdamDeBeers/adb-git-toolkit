#!/usr/bin/env bash

set -u

APP_NAME="ADB Git Toolkit"

pause() {
  echo
  read -rp "Press Enter to continue..."
}

header() {
  clear
  echo "======================================"
  echo "        $APP_NAME"
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

main_menu() {
  while true; do
    header
    echo "1) Git status"
    echo "2) Recent commits"
    echo "3) Remote URL"
    echo "4) Safe pull"
    echo "0) Exit"
    echo
    read -rp "Choose option: " choice

    case "$choice" in
      1) show_status ;;
      2) show_log ;;
      3) show_remote ;;
      4) safe_pull ;;
      0) clear; exit 0 ;;
      *) echo "Invalid option"; pause ;;
    esac
  done
}

main_menu