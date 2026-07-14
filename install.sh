#!/usr/bin/env bash
#
# Installer for ADB Git Toolkit

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$REPO_ROOT/scripts/adb-git-toolkit.sh"

INSTALL_DIR="$HOME/.local/share/adb-git-toolkit"
BIN_DIR="$HOME/.local/bin"
COMMAND_NAME="adb-git-toolkit"

if [[ ! -f "$SOURCE_SCRIPT" ]]; then
  echo "ERROR: Cannot find $SOURCE_SCRIPT"
  echo "Run this installer from inside a cloned ADB Git Toolkit repository."
  exit 1
fi

echo "Installing ADB Git Toolkit..."
echo

mkdir -p "$INSTALL_DIR"
cp "$SOURCE_SCRIPT" "$INSTALL_DIR/adb-git-toolkit.sh"
chmod +x "$INSTALL_DIR/adb-git-toolkit.sh"

mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/adb-git-toolkit.sh" "$BIN_DIR/$COMMAND_NAME"
chmod +x "$BIN_DIR/$COMMAND_NAME"

echo "Installed to: $INSTALL_DIR"
echo "Command:      $BIN_DIR/$COMMAND_NAME"
echo

case ":$PATH:" in
  *":$BIN_DIR:"*)
    echo "Installation complete. Run '$COMMAND_NAME' from inside a Git repository to start."
    ;;
  *)
    echo "NOTE: $BIN_DIR is not on your PATH."
    echo "Add this line to your shell profile (~/.bashrc or ~/.zshrc):"
    echo
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo
    echo "Then restart your shell, or run it directly: $INSTALL_DIR/adb-git-toolkit.sh"
    ;;
esac
