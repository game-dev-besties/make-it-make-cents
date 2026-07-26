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
export_mode="${GODOT_EXPORT_MODE:-release}"
case "${export_mode}" in
  debug)
    export_flag="--export-debug"
    ;;
  release)
    export_flag="--export-release"
    ;;
  *)
    echo "Unsupported GODOT_EXPORT_MODE '${export_mode}'; use 'debug' or 'release'." >&2
    exit 1
    ;;
esac
editor_output=""
if ! editor_output="$(
  "${godot_bin}" --headless --editor --path . --quit 2>&1
)"; then
  printf '%s\n' "${editor_output}"
  exit 1
fi
printf '%s\n' "${editor_output}"
if grep -Eq 'SCRIPT ERROR:|Failed to load script|Parse Error:|GDScript::reload:|<GDScript Error>' <<<"${editor_output}"; then
  echo "Godot reported a script compilation failure while preparing the export." >&2
  exit 1
fi

echo "Building Godot Web export in ${export_mode} mode..."
export_output=""
if ! export_output="$(
  "${godot_bin}" --headless --path . "${export_flag}" "Web" build/web/index.html 2>&1
)"; then
  printf '%s\n' "${export_output}"
  exit 1
fi
printf '%s\n' "${export_output}"
if grep -Eq 'SCRIPT ERROR:|Failed to load script|Parse Error:|GDScript::reload:|<GDScript Error>' <<<"${export_output}"; then
  echo "Godot reported a script compilation failure despite exiting successfully." >&2
  exit 1
fi

pack_path="$(pwd -P)/build/web/index.pck"
pack_smoke_dir="$(mktemp -d)"
trap 'rm -rf -- "${pack_smoke_dir}"' EXIT
pack_smoke_output=""
if ! pack_smoke_output="$(
  cd "${pack_smoke_dir}"
  "${godot_bin}" --headless --main-pack "${pack_path}" \
    --script res://tests/app_smoke_test.gd 2>&1
)"; then
  printf '%s\n' "${pack_smoke_output}"
  exit 1
fi
printf '%s\n' "${pack_smoke_output}"
if grep -Eq 'SCRIPT ERROR:|Failed to load script|Parse Error:|GDScript::reload:|<GDScript Error>' <<<"${pack_smoke_output}"; then
  echo "The exported package reported a runtime script failure." >&2
  exit 1
fi
