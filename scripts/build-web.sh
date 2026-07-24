#!/usr/bin/env bash
set -euo pipefail

# make sure this always runs in the repo root so we can make the build folder properly
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

mkdir -p build/web

"${GODOT_BIN:-godot}" --headless --path . --export-release "Web" build/web/index.html
