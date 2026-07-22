#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

godot_version="4.7.1"
godot_version_tag="${godot_version}-stable"
cache_root="${VERCEL_CACHE_DIR:-.vercel/cache}/godot/${godot_version}"
godot_binary="${cache_root}/godot"
godot_data_dir="${cache_root}/user-data"
template_dir="${godot_data_dir}/godot/export_templates/${godot_version_tag}"
binary_url="https://github.com/godotengine/godot-builds/releases/download/${godot_version_tag}/Godot_v${godot_version}-stable_linux.x86_64.zip"
template_url="https://github.com/godotengine/godot-builds/releases/download/${godot_version_tag}/Godot_v${godot_version}-stable_export_templates.tpz"
binary_sha512="4ccdab7a48eeccbe8819a2fc1f6262f8d72065d98601bcb3743fcbd7ebd39f373758a788ee3293a05ec5b2c48538266c437404312e372225cd2df273945a2de9"
template_sha512="afcc83d8d3d298038f19c58744a0d660fa75dd4baa33cb55d1011bb2565a2a8c2381728924564cb909e37c205a23f21b521b23bd057993afd43ae4da0b2f9d47"

mkdir -p "${cache_root}" "${template_dir}"

verify_sha512() {
    local file="$1"
    local expected="$2"
    local actual

    if command -v sha512sum >/dev/null 2>&1; then
        actual="$(sha512sum "${file}" | awk '{print $1}')"
    else
        actual="$(shasum -a 512 "${file}" | awk '{print $1}')"
    fi

    [[ "${actual}" == "${expected}" ]] || {
        echo "SHA-512 mismatch for ${file}" >&2
        exit 1
    }
}

download() {
    curl --fail --location --retry 3 --retry-all-errors --output "$2" "$1"
}

if [[ ! -x "${godot_binary}" ]]; then
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "${temporary_dir}"' EXIT
    binary_archive="${temporary_dir}/godot.zip"

    echo "Downloading Godot ${godot_version}..."
    download "${binary_url}" "${binary_archive}"
    verify_sha512 "${binary_archive}" "${binary_sha512}"
    unzip -q -j "${binary_archive}" 'Godot_v*-stable_linux.x86_64' -d "${cache_root}"
    mv "${cache_root}/Godot_v${godot_version}-stable_linux.x86_64" "${godot_binary}"
    chmod +x "${godot_binary}"
fi

if [[ ! -f "${template_dir}/web_nothreads_debug.zip" || ! -f "${template_dir}/web_nothreads_release.zip" ]]; then
    temporary_dir="$(mktemp -d)"
    trap 'rm -rf "${temporary_dir}"' EXIT
    template_archive="${temporary_dir}/export_templates.tpz"

    echo "Downloading Godot ${godot_version} Web export templates..."
    download "${template_url}" "${template_archive}"
    verify_sha512 "${template_archive}" "${template_sha512}"
    debug_template_entry="$(unzip -Z1 "${template_archive}" | awk '$0 ~ /(^|\/)web_nothreads_debug\.zip$/ { print; exit }')"
    release_template_entry="$(unzip -Z1 "${template_archive}" | awk '$0 ~ /(^|\/)web_nothreads_release\.zip$/ { print; exit }')"

    [[ -n "${debug_template_entry}" && -n "${release_template_entry}" ]] || {
        echo "Could not find the Web export templates in ${template_archive}" >&2
        exit 1
    }

    unzip -q -j "${template_archive}" "${debug_template_entry}" "${release_template_entry}" -d "${template_dir}"
fi

XDG_DATA_HOME="${godot_data_dir}" GODOT_BIN="${godot_binary}" ./scripts/build-web.sh

rm -rf .vercel/output
mkdir -p .vercel/output/static
cp -a build/web/. .vercel/output/static/
cp vercel-output-config.json .vercel/output/config.json
