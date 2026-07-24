#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 was not found; it is required to validate dialogue." >&2
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

godot_bin="${GODOT_BIN:-godot}"

python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/compile_dialogue.py --check
# On a cacheless checkout, the first boot imports Dialogic's custom DTL/DCH
# loaders. The second validates project resources with those loaders active.
"${godot_bin}" --headless --editor --path . --quit
"${godot_bin}" --headless --editor --path . --quit
"${godot_bin}" --headless --path . \
  --script res://ui/phrase_cut/tests/test_phrase_cut_overlay.gd
"${godot_bin}" --headless --path . \
  --script res://tests/integration_runtime_test.gd
