#!/usr/bin/env bash
# One-time local setup: downloads the macOS Godot binary (gitignored) used by
# the other dev scripts. For other platforms, download Godot 4.7.1 manually and
# set GODOT_BIN to its path.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="4.7.1"
APP=".bin/Godot.app"
BIN="$APP/Contents/MacOS/Godot"

if [ -x "$BIN" ] && "$BIN" --version >/dev/null 2>&1; then
  echo "Godot $VERSION already at $BIN"
  exit 0
fi

OS="$(uname -s)"
case "$OS" in
  Darwin)
    mkdir -p .bin
    url="https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_macos.universal.zip"
    echo "Downloading Godot $VERSION for macOS…"
    tmp="$(mktemp -d)/godot.zip"
    curl -sS -L --retry 3 -o "$tmp" "$url"
    unzip -q -o "$tmp" -d .bin/
    rm -rf "$tmp"
    chmod +x "$BIN"
    echo "Done: $BIN ($("$BIN" --version))"
    ;;
  *)
    echo "Automatic download is macOS-only. On $OS install Godot $VERSION and run:"
    echo "  export GODOT_BIN=/path/to/godot"
    exit 1
    ;;
esac
