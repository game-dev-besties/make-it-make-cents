#!/usr/bin/env bash
# Builds the web export and serves it locally so you can playtest in a browser
# without touching Vercel. Reuses the project's Web export preset.
#
#   ./scripts/play-web.sh             # build + serve on :8000
#   ./scripts/play-web.sh 8011        # build + serve on a custom port
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-.bin/Godot.app/Contents/MacOS/Godot}"
if ! [ -x "$GODOT" ]; then
  echo "Godot not found at $GODOT — run ./scripts/setup-godot.sh (or set GODOT_BIN)" >&2
  exit 1
fi

# Web export templates must be installed once. Auto-install if missing.
./scripts/install-web-templates.sh
echo "Building web export…"
GODOT_BIN="$GODOT" ./scripts/build-web.sh

PORT="${1:-8000}"
echo
echo "Serving on http://localhost:$PORT  (Ctrl+C to stop)"
exec python3 -m http.server "$PORT" --directory build/web
