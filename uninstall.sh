#!/usr/bin/env bash
#
# Uninstaller for ADB Git Toolkit

set -u

INSTALL_DIR="$HOME/.local/share/adb-git-toolkit"
BIN_DIR="$HOME/.local/bin"
COMMAND_NAME="adb-git-toolkit"

echo "Uninstalling ADB Git Toolkit..."
echo

removed=0

if [[ -L "$BIN_DIR/$COMMAND_NAME" || -f "$BIN_DIR/$COMMAND_NAME" ]]; then
  rm -f "$BIN_DIR/$COMMAND_NAME"
  echo "Removed command: $BIN_DIR/$COMMAND_NAME"
  removed=1
fi

if [[ -d "$INSTALL_DIR" ]]; then
  rm -rf "$INSTALL_DIR"
  echo "Removed install directory: $INSTALL_DIR"
  removed=1
fi

echo

if [[ "$removed" -eq 1 ]]; then
  echo "ADB Git Toolkit has been uninstalled."
else
  echo "ADB Git Toolkit does not appear to be installed."
fi
