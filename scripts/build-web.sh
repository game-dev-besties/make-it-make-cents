#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p build/web

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 was not found; it is required to compile dialogue." >&2
  exit 1
fi

if [ -z "${GODOT_BIN:-}" ] && ! command -v godot >/dev/null 2>&1; then
  if [ -x ".bin/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT_BIN=".bin/Godot.app/Contents/MacOS/Godot"
  else
    echo "Godot was not found. Set GODOT_BIN or install Godot 4.7." >&2
    exit 1
  fi
fi

python3 tools/compile_dialogue.py
"${GODOT_BIN:-godot}" --headless --path . --export-release "Web" build/web/index.html
