#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p build/web

if [ -z "${GODOT_BIN:-}" ] && ! command -v godot >/dev/null 2>&1; then
  echo "Godot was not found. Set GODOT_BIN or install Godot 4.7." >&2
  exit 1
fi

"${GODOT_BIN:-godot}" --headless --path . --export-release "Web" build/web/index.html
