#!/usr/bin/env bash
set -euo pipefail

# make sure this always runs in the repo root so we can make the build folder properly
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

mkdir -p build/web

# Fall back to the local macOS binary if GODOT_BIN isn't set and `godot` isn't on PATH.
if [ -z "${GODOT_BIN:-}" ] && ! command -v godot >/dev/null 2>&1; then
  if [ -x ".bin/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT_BIN=".bin/Godot.app/Contents/MacOS/Godot"
  else
    echo "ERROR: godot not found. Set GODOT_BIN or run ./scripts/setup-godot.sh" >&2
    exit 1
  fi
fi

"${GODOT_BIN:-godot}" --headless --path . --export-release "Web" build/web/index.html
