#!/usr/bin/env bash
# Local dev loop helper. Runs the headless import (so .import files + .godot
# cache exist — REQUIRED after adding/changed art or scripts, else the game
# breaks at runtime) then optionally launches the project.
#
#   ./scripts/dev.sh            # import only (fast; do this after pulling)
#   ./scripts/dev.sh run        # import then run the project (desktop window)
#   ./scripts/dev.sh editor     # import then open the editor
#   ./scripts/dev.sh check      # import then GDScript type-check all scripts
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-.bin/Godot.app/Contents/MacOS/Godot}"
if ! [ -x "$GODOT" ]; then
  echo "Godot not found at $GODOT — run ./scripts/setup-godot.sh (or set GODOT_BIN)" >&2
  exit 1
fi

# 1. import — regenerates .import files + .godot/ cache. (stdout is noisy; tail it)
echo "Importing project (headless)…"
"$GODOT" --headless --import 2>&1 | tail -3 || true

case "${1:-}" in
  run)
    echo "Running project…"
    exec "$GODOT" --path .
    ;;
  editor)
    echo "Opening editor…"
    exec "$GODOT" --editor --path .
    ;;
  check)
    echo "Type-checking GDScript…"
    exec "$GODOT" --headless --check-only --path . --script res://addons/game/autoloads/GameStats.gd 2>&1 | tail -20
    ;;
  ""|import)
    echo "Done. Project is imported and ready."
    ;;
  *)
    echo "unknown subcommand: $1" >&2; exit 1 ;;
esac
