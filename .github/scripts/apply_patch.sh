#!/usr/bin/env bash

set -euo pipefail

: "${VT_VER:?VT_VER is required}"
: "${PACKAGE_VERSION:?PACKAGE_VERSION is required}"

PATCH_ROOT="${PATCH_ROOT:-.workflow-src/patches}"

if [[ "${VT_VER}" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
  PATCH_VERSION="${VT_VER}"
elif [[ "${VT_VER}" == "master" ]]; then
  PATCH_VERSION="master"
else
  PATCH_VERSION="${PACKAGE_VERSION}"
fi

PATCH_FILE="${PATCH_ROOT}/${PATCH_VERSION}/vesc_tool.patch"

if [[ ! -f "${PATCH_FILE}" ]]; then
  echo "Patch file not found: ${PATCH_FILE}" >&2
  exit 1
fi

echo "Applying patch: ${PATCH_FILE}"

if git apply --check "${PATCH_FILE}"; then
  git apply "${PATCH_FILE}"
elif git apply --3way --check "${PATCH_FILE}"; then
  git apply --3way "${PATCH_FILE}"
elif git apply --ignore-space-change --ignore-whitespace --check "${PATCH_FILE}"; then
  git apply --ignore-space-change --ignore-whitespace "${PATCH_FILE}"
elif git apply --3way --ignore-space-change --ignore-whitespace --check "${PATCH_FILE}"; then
  git apply --3way --ignore-space-change --ignore-whitespace "${PATCH_FILE}"
else
  echo "Failed to apply patch with direct, 3-way, and whitespace-tolerant modes: ${PATCH_FILE}" >&2
  exit 1
fi
