#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

usage() {
  cat <<'EOF'
Usage:
  ./scripts/build-itch.sh
  ./scripts/build-itch.sh --push itch-user/game-slug:html

Builds the Godot Web export and creates:
  build/legendary-disco-web.zip

With --push, also uploads build/web through itch.io's butler CLI.
The itch.io project page must already exist and butler must be logged in.
EOF
}

push_target=""
case "$#" in
  0)
    ;;
  2)
    if [ "$1" != "--push" ]; then
      usage >&2
      exit 2
    fi
    push_target="$2"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ -n "${push_target}" ] &&
  [[ ! "${push_target}" =~ ^[a-z0-9_-]+/[a-z0-9_-]+:[a-z0-9_-]+$ ]]; then
  echo "Invalid itch target '${push_target}'." >&2
  echo "Expected lowercase itch-user/game-slug:channel." >&2
  exit 2
fi

for required_command in zip unzip; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "${required_command} is required to package the itch.io build." >&2
    exit 1
  fi
done

./scripts/build-web.sh

web_dir="$(pwd -P)/build/web"
archive_path="$(pwd -P)/build/legendary-disco-web.zip"
if [ ! -f "${web_dir}/index.html" ]; then
  echo "The Web export did not produce build/web/index.html." >&2
  exit 1
fi

package_dir="$(mktemp -d "$(pwd -P)/build/.itch-package.XXXXXX")"
trap 'rm -rf -- "${package_dir}"' EXIT
temporary_archive="${package_dir}/legendary-disco-web.zip"

(
  cd "${web_dir}"
  shopt -s nullglob dotglob
  web_entries=(*)
  if [ "${#web_entries[@]}" -eq 0 ]; then
    echo "The Web export directory is empty." >&2
    exit 1
  fi
  zip -q -r "${temporary_archive}" "${web_entries[@]}" \
    -x '*.DS_Store' \
    -x '__MACOSX/*'
)

unzip -tq "${temporary_archive}" >/dev/null
archive_listing="$(unzip -Z1 "${temporary_archive}")"
if ! grep -Fxq 'index.html' <<<"${archive_listing}"; then
	echo "The itch.io archive must contain index.html at its root." >&2
	exit 1
fi
mv -f -- "${temporary_archive}" "${archive_path}"

echo "Created ${archive_path}"

if [ -z "${push_target}" ]; then
  exit 0
fi
if ! command -v butler >/dev/null 2>&1; then
  echo "butler was not found. Install it and run 'butler login' first." >&2
  exit 1
fi

butler push "${web_dir}" "${push_target}"
