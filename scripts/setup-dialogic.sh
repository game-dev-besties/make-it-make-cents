#!/usr/bin/env bash
# Dialogic is vendored directly into addons/dialogic (committed), so there's
# nothing to fetch. This script just confirms it's present and the plugin is
# enabled, and reminds you of the next steps. (We vendored rather than
# submodule'd because Godot double-scans symlinked submodules and the symlink
# breaks on Windows; vendoring "just works" on clone.)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f "addons/dialogic/plugin.cfg" ]; then
  echo "ERROR: addons/dialogic/plugin.cfg missing — Dialogic isn't vendored." >&2
  exit 1
fi

if ! grep -q 'addons/dialogic/plugin.cfg' project.godot 2>/dev/null; then
  echo "Dialogic plugin not enabled in project.godot — enabling it requires the editor:"
  echo "  Project ▸ Project Settings ▸ Plugins ▸ enable 'Dialogic'"
  echo "  (or run: .bin/Godot.app/Contents/MacOS/Godot --headless --editor --quit)"
else
  echo "Dialogic is vendored and enabled. ✓"
fi

echo
echo "Generate the runtime assets:"
echo "  python3 tools/gen_game_stats.py       # GameStats autoload from story/stats.yaml"
echo "  python3 tools/compile_scenes.py       # story/scripts/<id>/*.md → generated/timelines/*.dtl"
echo "  ./scripts/dev.sh                     # headless import (generates .import files)"
