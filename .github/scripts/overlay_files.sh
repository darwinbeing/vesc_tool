#!/usr/bin/env bash

set -euo pipefail

OVERLAY_DIR="${OVERLAY_DIR:-.workflow-src/.github/overlay}"

if [[ ! -d "${OVERLAY_DIR}" ]]; then
  echo "Overlay directory not found: ${OVERLAY_DIR}" >&2
  exit 1
fi

echo "Overlaying CI build scripts from ${OVERLAY_DIR}"

for f in "${OVERLAY_DIR}"/*; do
  name="$(basename "${f}")"
  cp -v "${f}" "./${name}"
  case "${name}" in
    *.ps1) ;;
    *) chmod +x "./${name}" ;;
  esac
done
