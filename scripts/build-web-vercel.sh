#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

readonly GODOT_VERSION="4.7.1"
readonly GODOT_RELEASE="${GODOT_VERSION}-stable"
readonly CACHE_ROOT="${VERCEL_CACHE_DIR:-.vercel/cache}/godot/${GODOT_VERSION}"
readonly GODOT_BIN="${CACHE_ROOT}/godot"
readonly TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

download() {
  curl --fail --location --retry 3 --retry-all-errors --output "$2" "$1"
}

install_godot() {
  [ -x "${GODOT_BIN}" ] && return
  local archive
  archive="${CACHE_ROOT}/godot.zip"
  mkdir -p "${CACHE_ROOT}"
  download "https://github.com/godotengine/godot-builds/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" "${archive}"
  unzip -q -j "${archive}" 'Godot_v*-stable_linux.x86_64' -d "${CACHE_ROOT}"
  mv "${CACHE_ROOT}/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "${GODOT_BIN}"
  chmod +x "${GODOT_BIN}"
}

install_templates() {
  [ -f "${TEMPLATE_DIR}/web_nothreads_release.zip" ] && return
  local archive extract_dir
  archive="${CACHE_ROOT}/templates.tpz"
  extract_dir="${CACHE_ROOT}/templates"
  download "https://github.com/godotengine/godot-builds/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" "${archive}"
  rm -rf "${extract_dir}"
  unzip -q "${archive}" -d "${extract_dir}"
  mkdir -p "${TEMPLATE_DIR}"
  find "${extract_dir}" -type f -name 'web_nothreads_*.zip' -exec cp {} "${TEMPLATE_DIR}/" \;
}

install_godot
install_templates
GODOT_BIN="${GODOT_BIN}" ./scripts/build-web.sh
mkdir -p .vercel/output/static
cp -a build/web/. .vercel/output/static/
cp vercel-output-config.json .vercel/output/config.json
