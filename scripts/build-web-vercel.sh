#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

repo_root="$(pwd -P)"
godot_version="4.7.1"
godot_release="${godot_version}-stable"
template_version="${godot_version}.stable"
cache_base="${VERCEL_CACHE_DIR:-${repo_root}/.vercel/cache}"

case "${cache_base}" in
  /*) ;;
  *) cache_base="${repo_root}/${cache_base#./}" ;;
esac

cache_root="${cache_base}/godot/${godot_version}"
godot_binary="${cache_root}/godot"
cached_template_dir="${cache_root}/templates"
template_dir="${HOME}/.local/share/godot/export_templates/${template_version}"
binary_url="https://github.com/godotengine/godot-builds/releases/download/${godot_release}/Godot_v${godot_version}-stable_linux.x86_64.zip"
template_url="https://github.com/godotengine/godot-builds/releases/download/${godot_release}/Godot_v${godot_version}-stable_export_templates.tpz"
binary_sha512="4ccdab7a48eeccbe8819a2fc1f6262f8d72065d98601bcb3743fcbd7ebd39f373758a788ee3293a05ec5b2c48538266c437404312e372225cd2df273945a2de9"
template_sha512="afcc83d8d3d298038f19c58744a0d660fa75dd4baa33cb55d1011bb2565a2a8c2381728924564cb909e37c205a23f21b521b23bd057993afd43ae4da0b2f9d47"

verify_sha512() {
  local file="$1"
  local expected="$2"
  local actual

  if command -v sha512sum >/dev/null 2>&1; then
    actual="$(sha512sum "${file}" | awk '{print $1}')"
  else
    actual="$(shasum -a 512 "${file}" | awk '{print $1}')"
  fi

  if [ "${actual}" != "${expected}" ]; then
    echo "SHA-512 mismatch for ${file}" >&2
    exit 1
  fi
}

download() {
  curl --fail --location --retry 3 --retry-all-errors --output "$2" "$1"
}

install_godot() {
  [ -x "${godot_binary}" ] && return

  local temporary_dir binary_archive extracted_binary
  temporary_dir="$(mktemp -d)"
  binary_archive="${temporary_dir}/godot.zip"
  extracted_binary="${cache_root}/Godot_v${godot_version}-stable_linux.x86_64"

  echo "Downloading Godot ${godot_version}..."
  download "${binary_url}" "${binary_archive}"
  verify_sha512 "${binary_archive}" "${binary_sha512}"
  mkdir -p "${cache_root}"
  unzip -q -j "${binary_archive}" 'Godot_v*-stable_linux.x86_64' -d "${cache_root}"
  mv "${extracted_binary}" "${godot_binary}"
  chmod +x "${godot_binary}"
  rm -rf "${temporary_dir}"
}

install_templates() {
  if [ ! -f "${cached_template_dir}/web_nothreads_debug.zip" ] ||
    [ ! -f "${cached_template_dir}/web_nothreads_release.zip" ]; then
    local temporary_dir template_archive extract_dir debug_entry release_entry
    local debug_file release_file
    temporary_dir="$(mktemp -d)"
    template_archive="${temporary_dir}/templates.tpz"
    extract_dir="${temporary_dir}/templates"

    echo "Downloading Godot ${godot_version} Web export templates..."
    download "${template_url}" "${template_archive}"
    verify_sha512 "${template_archive}" "${template_sha512}"
    debug_entry="$(unzip -Z1 "${template_archive}" | awk '$0 ~ /(^|\/)web_nothreads_debug\.zip$/ { print; exit }')"
    release_entry="$(unzip -Z1 "${template_archive}" | awk '$0 ~ /(^|\/)web_nothreads_release\.zip$/ { print; exit }')"

    if [ -z "${debug_entry}" ] || [ -z "${release_entry}" ]; then
      echo "Could not find Web export templates in ${template_archive}" >&2
      exit 1
    fi

    mkdir -p "${extract_dir}"
    unzip -q "${template_archive}" "${debug_entry}" "${release_entry}" -d "${extract_dir}"
    debug_file="$(find "${extract_dir}" -type f -name 'web_nothreads_debug.zip' -print -quit)"
    release_file="$(find "${extract_dir}" -type f -name 'web_nothreads_release.zip' -print -quit)"

    if [ -z "${debug_file}" ] || [ -z "${release_file}" ]; then
      echo "Web export templates were not extracted from ${template_archive}" >&2
      exit 1
    fi

    mkdir -p "${cached_template_dir}"
    cp "${debug_file}" "${cached_template_dir}/web_nothreads_debug.zip"
    cp "${release_file}" "${cached_template_dir}/web_nothreads_release.zip"
    rm -rf "${temporary_dir}"
  fi

  mkdir -p "${template_dir}"
  cp "${cached_template_dir}"/*.zip "${template_dir}/"
}

mkdir -p "${cache_root}" "${cached_template_dir}"
install_godot
install_templates
GODOT_BIN="${godot_binary}" ./scripts/build-web.sh
mkdir -p .vercel/output/static
cp -a build/web/. .vercel/output/static/
cp vercel-output-config.json .vercel/output/config.json
