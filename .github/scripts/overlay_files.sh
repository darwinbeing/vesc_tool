#!/usr/bin/env bash

set -euo pipefail

OVERLAY_DIR="${OVERLAY_DIR:-.workflow-src/.github/overlay}"

if [[ ! -d "${OVERLAY_DIR}" ]]; then
  echo "Overlay directory not found: ${OVERLAY_DIR}" >&2
  exit 1
fi

echo "Overlaying CI build scripts from ${OVERLAY_DIR}"

shopt -s nullglob
files=( "${OVERLAY_DIR}"/* )
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No files found in ${OVERLAY_DIR}" >&2
  exit 1
fi

for f in "${files[@]}"; do
  name="$(basename "${f}")"
  cp -v "${f}" "./${name}"
  case "${name}" in
    *.ps1) ;;
    *) chmod +x "./${name}" ;;
  esac
done
