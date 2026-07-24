#!/usr/bin/env bash
# Installs the Godot Web export templates (no-threads variant, matching the
# project's Web preset) into Godot's user templates dir, so `play-web.sh` and
# `build-web.sh` work without manually opening the editor.
#
# Reuses the exact .tpz URL + SHA-512 from scripts/build-web-vercel.sh so the
# bits are identical to what Vercel/CI use.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-.bin/Godot.app/Contents/MacOS/Godot}"
VERSION="4.7.1"
TPZ_URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_export_templates.tpz"
TPZ_SHA512="afcc83d8d3d298038f19c58744a0d660fa75dd4baa33cb55d1011bb2565a2a8c2381728924564cb909e37c205a23f21b521b23bd057993afd43ae4da0b2f9d47"

# Godot's per-user templates dir varies by OS.
case "$(uname -s)" in
  Darwin) TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/${VERSION}.stable" ;;
  Linux)  TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${VERSION}.stable" ;;
  *)      TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${VERSION}.stable" ;;
esac

if [ -f "${TEMPLATES_DIR}/web_nothreads_release.zip" ] && [ -f "${TEMPLATES_DIR}/web_nothreads_debug.zip" ]; then
  echo "Web export templates already installed in ${TEMPLATES_DIR}"
  exit 0
fi

echo "Downloading Godot ${VERSION} export templates (.tpz)…"
tmp="$(mktemp -d)"
archive="${tmp}/templates.tpz"
curl -sS -L --retry 3 -o "$archive" "$TPZ_URL"

# verify checksum
if command -v sha512sum >/dev/null 2>&1; then
  actual="$(sha512sum "$archive" | awk '{print $1}')"
else
  actual="$(shasum -a 512 "$archive" | awk '{print $1}')"
fi
[ "$actual" = "$TPZ_SHA512" ] || { echo "SHA-512 mismatch for templates" >&2; exit 1; }

echo "Extracting web (no-threads) templates…"
# .tpz is a zip; the web zips live under templates/ inside it.
mkdir -p "$TEMPLATES_DIR"
unzip -q -o "$archive" 'templates/web_nothreads_debug.zip' 'templates/web_nothreads_release.zip' -d "$tmp"
cp "$tmp/templates/web_nothreads_debug.zip" "$TEMPLATES_DIR/"
cp "$tmp/templates/web_nothreads_release.zip" "$TEMPLATES_DIR/"
rm -rf "$tmp"

echo "Installed web export templates to ${TEMPLATES_DIR}"
