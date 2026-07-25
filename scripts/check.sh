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

run_godot_checked() {
  local output
  if ! output="$("${godot_bin}" "$@" 2>&1)"; then
    printf '%s\n' "${output}"
    return 1
  fi
  printf '%s\n' "${output}"
  if grep -Eq 'SCRIPT ERROR:|Failed to load script|Parse Error:|GDScript::reload:|<GDScript Error>' <<<"${output}"; then
    echo "Godot reported a script compilation failure despite exiting successfully." >&2
    return 1
  fi
}

python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/compile_dialogue.py --check
# On a cacheless checkout, the first boot imports Dialogic's custom DTL/DCH
# loaders. The second validates project resources with those loaders active.
run_godot_checked --headless --editor --path . --quit
run_godot_checked --headless --editor --path . --quit
run_godot_checked --headless --path . \
  --script res://ui/phrase_cut/tests/test_phrase_cut_overlay.gd
run_godot_checked --headless --path . \
  --script res://tests/responsive_layout_test.gd
run_godot_checked --headless --path . \
  --script res://tests/stage_speaker_bridge_test.gd
run_godot_checked --headless --path . \
  --script res://tests/stage_actor_portrait_test.gd
run_godot_checked --headless --path . \
  --script res://tests/dialogic_feature_test.gd
run_godot_checked --headless --path . \
  --script res://tests/dialogic_content_validation_test.gd
run_godot_checked --headless --path . \
  --script res://tests/stats_schema_test.gd
run_godot_checked --headless --path . \
  --script res://tests/integration_runtime_test.gd
run_godot_checked --headless --path . \
  --script res://tests/app_smoke_test.gd
