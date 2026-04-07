#!/usr/bin/env bash

set -euo pipefail

: "${VT_VERSION:?VT_VERSION is required}"
: "${VT_REF:?VT_REF is required}"
: "${PRERELEASE:?PRERELEASE is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

CUSTOM_RELEASE_NOTES="${CUSTOM_RELEASE_NOTES:-}"

write_output() {
  {
    echo "RELEASE_NOTES<<EOF"
    printf '%s\n' "$1"
    echo "EOF"
  } >> "${GITHUB_OUTPUT}"
}

collect_changes() {
  local range="$1"
  git log "${range}" --pretty=format:'%s (%h)' --no-merges --invert-grep --grep='has signed the CLA' || true
}

if [ -n "${CUSTOM_RELEASE_NOTES}" ]; then
  write_output "${CUSTOM_RELEASE_NOTES}"
  exit 0
fi

CURRENT_TAG=""
PREVIOUS_TAG=""
TARGET_REF="${VT_REF}"
TARGET_REV="${VT_REF}"

if ! git rev-parse -q --verify "${TARGET_REV}^{commit}" >/dev/null; then
  TARGET_REV="HEAD"
fi

if git rev-parse -q --verify "refs/tags/${VT_VERSION}" >/dev/null; then
  CURRENT_TAG="${VT_VERSION}"
fi

PREVIOUS_TAG=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+$' | grep -Fxv "${VT_VERSION}" | head -n 1 || true)

if [ "${PRERELEASE}" = "true" ]; then
  TITLE="**VESC Tool Nightly Build ${VT_VERSION}**"
  if [ -n "${CURRENT_TAG}" ]; then
    RANGE="${CURRENT_TAG}..${TARGET_REV}"
    DISPLAY_RANGE="${CURRENT_TAG}..${TARGET_REF}"
  else
    RANGE="${TARGET_REV}"
    DISPLAY_RANGE="${TARGET_REF}"
  fi
else
  TITLE="**VESC Tool Release Build ${VT_VERSION}**"
  if [ -n "${PREVIOUS_TAG}" ] && [ -n "${CURRENT_TAG}" ]; then
    RANGE="${PREVIOUS_TAG}..${CURRENT_TAG}"
    DISPLAY_RANGE="${PREVIOUS_TAG}..${CURRENT_TAG}"
  elif [ -n "${PREVIOUS_TAG}" ]; then
    RANGE="${PREVIOUS_TAG}..${TARGET_REV}"
    DISPLAY_RANGE="${PREVIOUS_TAG}..${TARGET_REF}"
  elif [ -n "${CURRENT_TAG}" ]; then
    RANGE="${CURRENT_TAG}"
    DISPLAY_RANGE="${CURRENT_TAG}"
  else
    RANGE="${TARGET_REV}"
    DISPLAY_RANGE="${TARGET_REF}"
  fi
fi

RAW_CHANGES="$(collect_changes "${RANGE}")"
if [ -z "${RAW_CHANGES}" ] && [ "${PRERELEASE}" = "true" ] && [ -n "${PREVIOUS_TAG}" ]; then
  RANGE="${PREVIOUS_TAG}..${TARGET_REV}"
  DISPLAY_RANGE="${PREVIOUS_TAG}..${TARGET_REF}"
  RAW_CHANGES="$(collect_changes "${RANGE}")"
fi

FEATURES=""
FIXES=""
IMPROVEMENTS=""
BUILD_CI=""
OTHER=""
LOW_SIGNAL=""

while IFS= read -r entry; do
  [ -z "${entry}" ] && continue
  lower="$(printf '%s' "${entry}" | tr '[:upper:]' '[:lower:]')"

  if printf '%s\n' "${lower}" | grep -Eiq '^(added keyword|minor .*tweak|small .*tweak|dialog tweaks?|cleanup:|typo correction|renamed |rearranged |binding list improvement$|switched back |simplified .* again$|put preferred devices on top|no text wrapping|use double spinbox|delete )'; then
    LOW_SIGNAL="${LOW_SIGNAL}- ${entry}"$'\n'
    continue
  fi

  if printf '%s\n' "${lower}" | grep -Eiq '\b(fix|fixed|bug|issue|correct|resolve|resolved|warning|crash|regression|leak|broken)\b'; then
    FIXES="${FIXES}- ${entry}"$'\n'
  elif printf '%s\n' "${lower}" | grep -Eiq '\b(ci|build|workflow|release|packag|android|ios|macos|linux|windows|qt|xcode|deploy|artifact|sign)\b'; then
    BUILD_CI="${BUILD_CI}- ${entry}"$'\n'
  elif printf '%s\n' "${lower}" | grep -Eiq '\b(improv|improved|tweak|cleanup|refactor|simplify|layout|ui|keyboard|polish)\b'; then
    IMPROVEMENTS="${IMPROVEMENTS}- ${entry}"$'\n'
  elif printf '%s\n' "${lower}" | grep -Eiq '\b(add|added|new|support|enable|example|show|download|editor|sensor|config|firmware|mode)\b'; then
    FEATURES="${FEATURES}- ${entry}"$'\n'
  else
    OTHER="${OTHER}- ${entry}"$'\n'
  fi
done < <(printf '%s\n' "${RAW_CHANGES}")

NOTES="${TITLE}"

append_section() {
  local header="$1"
  local content="$2"
  [ -z "${content}" ] && return 0
  NOTES="${NOTES}"$'\n\n'"### ${header}"$'\n'"${content%$'\n'}"
}

append_section "New Features" "${FEATURES}"
append_section "Fixes" "${FIXES}"
append_section "Improvements" "${IMPROVEMENTS}"
append_section "Build & CI" "${BUILD_CI}"

if [ -z "${FEATURES}${FIXES}${IMPROVEMENTS}${BUILD_CI}" ]; then
  if [ -n "${OTHER}" ]; then
    append_section "Other Changes" "${OTHER}"
  elif [ -n "${LOW_SIGNAL}" ]; then
    append_section "Other Changes" "${LOW_SIGNAL}"
  else
    NOTES="${NOTES}"$'\n\n'"- No commit summary available"
  fi
fi

NOTES="${NOTES}"$'\n\n'"_Range: ${DISPLAY_RANGE}_"
NOTES="${NOTES}"$'\n'"_Generated from commit subjects_"

write_output "${NOTES}"
