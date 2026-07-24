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
godot_bin="${GODOT_BIN:-godot}"
export_output=""
if ! export_output="$(
  "${godot_bin}" --headless --path . --export-release "Web" build/web/index.html 2>&1
)"; then
  printf '%s\n' "${export_output}"
  exit 1
fi
printf '%s\n' "${export_output}"
if grep -Eq 'SCRIPT ERROR:|Failed to load script|Parse Error:|GDScript::reload:|<GDScript Error>' <<<"${export_output}"; then
  echo "Godot reported a script compilation failure despite exiting successfully." >&2
  exit 1
fi
