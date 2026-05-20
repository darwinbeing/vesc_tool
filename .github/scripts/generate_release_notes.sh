#!/usr/bin/env bash
#
# Generate GitHub release notes from commit history.
#
# Commits are scored and bucketed (Features / Fixes / Improvements / Build & CI /
# Other) from their subject + diffstat, trivial churn is filtered out, and the
# top entries per bucket are emitted as Markdown.
#
# Contract:
#   in  (env): VT_VERSION, VT_REF, PRERELEASE, GITHUB_OUTPUT   (all required)
#              CUSTOM_RELEASE_NOTES                            (optional override)
#              GITHUB_SERVER_URL, GITHUB_REPOSITORY            (optional, for compare link)
#   out:       RELEASE_NOTES -> $GITHUB_OUTPUT (heredoc-quoted)

set -euo pipefail

: "${VT_VERSION:?VT_VERSION is required}"
: "${VT_REF:?VT_REF is required}"
: "${PRERELEASE:?PRERELEASE is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

CUSTOM_RELEASE_NOTES="${CUSTOM_RELEASE_NOTES:-}"

# Per-bucket entry limits in the rendered notes.
LIMIT_FEATURES=6
LIMIT_FIXES=5
LIMIT_IMPROVEMENTS=4
LIMIT_BUILD=4
LIMIT_OTHER=4
# A commit must score at least this high to be listed (below it is churn).
MIN_SCORE=4

write_output() {
  {
    echo "RELEASE_NOTES<<EOF"
    printf '%s\n' "$1"
    echo "EOF"
  } >> "${GITHUB_OUTPUT}"
}

# Tab-separated "<commit-hash>\t<subject>", newest first, merges and the
# CLA-signature bot commits excluded.
collect_changes() {
  git log "$1" --pretty=format:'%H%x09%s' --no-merges \
    --invert-grep --grep='has signed the CLA' || true
}

append_line() {
  local current="$1" line="$2"
  if [ -n "${current}" ]; then
    printf '%s\n%s\n' "${current}" "${line}"
  else
    printf '%s\n' "${line}"
  fi
}

# Sort score-prefixed lines descending, keep the top N, strip the score column.
select_top_entries() {
  local lines="$1" limit="$2"
  [ -z "${lines}" ] && return 0
  printf '%s\n' "${lines}" | sort -rn | head -n "${limit}" | cut -f2-
}

is_trivial_subject() {
  local lower="$1"

  printf '%s\n' "${lower}" | grep -Eiq \
    '^(fix(e[ds])? typo|typo correction|fix(e[ds])? typo[s]?|fix(e[ds])? conflict[s]?|fix(e[ds])? merge conflict[s]?|fix(e[ds])? broken merge|merge branch |merge pull request |resolved? conflict[s]?|conflict resolution|bump |revert )' \
    && return 0

  printf '%s\n' "${lower}" | grep -Eiq \
    '^(added keyword|minor .*tweak|small .*tweak|dialog tweaks?|renamed |rearranged |binding list improvement$|switched back |simplified .* again$|put preferred devices on top|no text wrapping|use double spinbox|delete )' \
    && return 0

  printf '%s\n' "${lower}" | grep -Eiq \
    '\b(typo|conflict|merge conflict|comment only|formatting only|whitespace only)\b' \
    && return 0

  return 1
}

score_commit() {
  local subject="$1" files_changed="$2" insertions="$3" deletions="$4" category="$5"
  local lower changed_lines score=0

  lower="$(printf '%s' "${subject}" | tr '[:upper:]' '[:lower:]')"
  changed_lines=$((insertions + deletions))

  if printf '%s\n' "${lower}" | grep -Eiq '\b(add|added|new|support|enable|feature|editor|sensor|config|firmware|mode|wizard|logging|package)\b'; then
    score=$((score + 3))
  fi
  if printf '%s\n' "${lower}" | grep -Eiq '\b(fix|fixed|bug|issue|correct|resolve|resolved|warning|crash|regression|leak)\b'; then
    score=$((score + 3))
  fi
  if printf '%s\n' "${lower}" | grep -Eiq '\b(improv|improved|refactor|rewrite|redesign|optimi[sz]e|polish)\b'; then
    score=$((score + 2))
  fi

  if [ "${files_changed}" -ge 8 ]; then
    score=$((score + 3))
  elif [ "${files_changed}" -ge 4 ]; then
    score=$((score + 2))
  elif [ "${files_changed}" -ge 2 ]; then
    score=$((score + 1))
  fi

  if [ "${changed_lines}" -ge 250 ]; then
    score=$((score + 3))
  elif [ "${changed_lines}" -ge 80 ]; then
    score=$((score + 2))
  elif [ "${changed_lines}" -ge 25 ]; then
    score=$((score + 1))
  fi

  case "${category}" in
    features|fixes|improvements) score=$((score + 2)) ;;
    build_ci)                    score=$((score + 1)) ;;
  esac

  if is_trivial_subject "${lower}"; then
    score=$((score - 6))
  fi
  if printf '%s\n' "${lower}" | grep -Eiq '\b(keyword|typo|conflict|whitespace|formatting|comment only)\b'; then
    score=$((score - 4))
  fi

  printf '%s\n' "${score}"
}

categorize_commit() {
  local subject="$1" changed_files="$2" lower
  lower="$(printf '%s' "${subject}" | tr '[:upper:]' '[:lower:]')"

  if printf '%s\n' "${lower}" | grep -Eiq '\b(fix|fixed|bug|issue|correct|resolve|resolved|warning|crash|regression|leak)\b'; then
    printf 'fixes\n'; return 0
  fi
  if printf '%s\n' "${changed_files}" | grep -Eiq '(^|/)\.github/|(^|/)workflows?/|(^|/)scripts?/'; then
    printf 'build_ci\n'; return 0
  fi
  if printf '%s\n' "${lower}" | grep -Eiq '\b(ci|build|workflow|release|packag|qt[[:space:]-]?6|xcode|deploy|artifact|sign)\b'; then
    printf 'build_ci\n'; return 0
  fi
  if printf '%s\n' "${lower}" | grep -Eiq '\b(add|added|new|support|enable|feature|editor|sensor|config|firmware|mode|wizard|logging|package)\b'; then
    printf 'features\n'; return 0
  fi
  if printf '%s\n' "${lower}" | grep -Eiq '\b(improv|improved|refactor|rewrite|redesign|optimi[sz]e|polish|cleanup|simplify|layout|ui|keyboard)\b'; then
    printf 'improvements\n'; return 0
  fi
  printf 'other\n'
}

commit_stats() {
  local commit="$1" stats files insertions deletions
  stats="$(git show --shortstat --format='' "${commit}" | tail -n 1)"
  files="$(printf '%s\n' "${stats}" | sed -nE 's/.* ([0-9]+) files? changed.*/\1/p')"
  insertions="$(printf '%s\n' "${stats}" | sed -nE 's/.* ([0-9]+) insertions?\(\+\).*/\1/p')"
  deletions="$(printf '%s\n' "${stats}" | sed -nE 's/.* ([0-9]+) deletions?\(-\).*/\1/p')"
  printf '%s\t%s\t%s\n' "${files:-0}" "${insertions:-0}" "${deletions:-0}"
}

# Append a score-prefixed entry into the right bucket. Single source of truth
# for the category -> bucket mapping (used by both the scored and fallback pass).
FEATURE_ITEMS=""; FIX_ITEMS=""; IMPROVEMENT_ITEMS=""; BUILD_ITEMS=""; OTHER_ITEMS=""
bucket_add() {
  local category="$1" weighted_entry="$2"
  case "${category}" in
    features)     FEATURE_ITEMS="$(append_line "${FEATURE_ITEMS}" "${weighted_entry}")" ;;
    fixes)        FIX_ITEMS="$(append_line "${FIX_ITEMS}" "${weighted_entry}")" ;;
    improvements) IMPROVEMENT_ITEMS="$(append_line "${IMPROVEMENT_ITEMS}" "${weighted_entry}")" ;;
    build_ci)     BUILD_ITEMS="$(append_line "${BUILD_ITEMS}" "${weighted_entry}")" ;;
    *)            OTHER_ITEMS="$(append_line "${OTHER_ITEMS}" "${weighted_entry}")" ;;
  esac
}

# --- Custom override short-circuits everything ------------------------------
if [ -n "${CUSTOM_RELEASE_NOTES}" ]; then
  write_output "${CUSTOM_RELEASE_NOTES}"
  exit 0
fi

# --- Resolve the commit range to summarize ----------------------------------
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
    RANGE="${CURRENT_TAG}..${TARGET_REV}"; DISPLAY_RANGE="${CURRENT_TAG}..${TARGET_REF}"
  else
    RANGE="${TARGET_REV}"; DISPLAY_RANGE="${TARGET_REF}"
  fi
else
  TITLE="**VESC Tool Release Build ${VT_VERSION}**"
  if [ -n "${PREVIOUS_TAG}" ] && [ -n "${CURRENT_TAG}" ]; then
    RANGE="${PREVIOUS_TAG}..${CURRENT_TAG}"; DISPLAY_RANGE="${PREVIOUS_TAG}..${CURRENT_TAG}"
  elif [ -n "${PREVIOUS_TAG}" ]; then
    RANGE="${PREVIOUS_TAG}..${TARGET_REV}"; DISPLAY_RANGE="${PREVIOUS_TAG}..${TARGET_REF}"
  elif [ -n "${CURRENT_TAG}" ]; then
    RANGE="${CURRENT_TAG}"; DISPLAY_RANGE="${CURRENT_TAG}"
  else
    RANGE="${TARGET_REV}"; DISPLAY_RANGE="${TARGET_REF}"
  fi
fi

RAW_CHANGES="$(collect_changes "${RANGE}")"
if [ -z "${RAW_CHANGES}" ] && [ "${PRERELEASE}" = "true" ] && [ -n "${PREVIOUS_TAG}" ]; then
  RANGE="${PREVIOUS_TAG}..${TARGET_REV}"; DISPLAY_RANGE="${PREVIOUS_TAG}..${TARGET_REF}"
  RAW_CHANGES="$(collect_changes "${RANGE}")"
fi

# --- Score & bucket every commit --------------------------------------------
ALL_SCORED=""
IMPORTANT_COUNT=0
COMMIT_COUNT=0

while IFS=$'\t' read -r commit subject; do
  [ -z "${commit}" ] && continue
  COMMIT_COUNT=$((COMMIT_COUNT + 1))

  short_commit="$(git rev-parse --short "${commit}")"
  stats="$(commit_stats "${commit}")"
  files_changed="$(printf '%s\n' "${stats}" | cut -f1)"
  insertions="$(printf '%s\n' "${stats}" | cut -f2)"
  deletions="$(printf '%s\n' "${stats}" | cut -f3)"
  changed_files="$(git show --name-only --format='' "${commit}")"
  category="$(categorize_commit "${subject}" "${changed_files}")"
  score="$(score_commit "${subject}" "${files_changed}" "${insertions}" "${deletions}" "${category}")"
  entry="- ${subject} (${short_commit})"

  ALL_SCORED="$(append_line "${ALL_SCORED}" "$(printf '%s\t%s\t%s' "${score}" "${category}" "${entry}")")"

  if [ "${score}" -ge "${MIN_SCORE}" ]; then
    IMPORTANT_COUNT=$((IMPORTANT_COUNT + 1))
    bucket_add "${category}" "$(printf '%s\t%s' "${score}" "${entry}")"
  fi
done < <(printf '%s\n' "${RAW_CHANGES}")

# Nothing cleared the bar: fall back to the 3 highest-scoring commits so the
# notes are never empty when there were real changes.
if [ "${IMPORTANT_COUNT}" -eq 0 ] && [ -n "${ALL_SCORED}" ]; then
  while IFS=$'\t' read -r _ category entry; do
    [ -z "${entry}" ] && continue
    bucket_add "${category}" "$(printf '0\t%s' "${entry}")"
    IMPORTANT_COUNT=$((IMPORTANT_COUNT + 1))
    [ "${IMPORTANT_COUNT}" -ge 3 ] && break
  done < <(printf '%s\n' "${ALL_SCORED}" | sort -rn | head -n 3)
fi

FEATURES="$(select_top_entries "${FEATURE_ITEMS}" "${LIMIT_FEATURES}")"
FIXES="$(select_top_entries "${FIX_ITEMS}" "${LIMIT_FIXES}")"
IMPROVEMENTS="$(select_top_entries "${IMPROVEMENT_ITEMS}" "${LIMIT_IMPROVEMENTS}")"
BUILD_CI="$(select_top_entries "${BUILD_ITEMS}" "${LIMIT_BUILD}")"
OTHER="$(select_top_entries "${OTHER_ITEMS}" "${LIMIT_OTHER}")"

# --- Render -----------------------------------------------------------------
CONTRIBUTORS="$(git log "${RANGE}" --no-merges --pretty=format:'%an' 2>/dev/null | sort -u | grep -c . || true)"
CONTRIBUTORS="${CONTRIBUTORS:-0}"

NOTES="${TITLE}"

# Summary line: how much changed, by how many people.
if [ "${COMMIT_COUNT}" -gt 0 ]; then
  commit_word="commits"; [ "${COMMIT_COUNT}" -eq 1 ] && commit_word="commit"
  contrib_word="contributors"; [ "${CONTRIBUTORS}" -eq 1 ] && contrib_word="contributor"
  NOTES="${NOTES}"$'\n\n'"_${COMMIT_COUNT} ${commit_word} from ${CONTRIBUTORS} ${contrib_word}._"
fi

append_section() {
  local header="$1" content="$2"
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
  else
    NOTES="${NOTES}"$'\n\n'"- No significant commit summary available"
  fi
fi

# Full changelog: a clickable compare link on GitHub, plain range otherwise.
if [ -n "${GITHUB_SERVER_URL:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ] && printf '%s' "${DISPLAY_RANGE}" | grep -q '\.\.'; then
  CHANGELOG="[\`${DISPLAY_RANGE}\`](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/compare/${DISPLAY_RANGE})"
else
  CHANGELOG="\`${DISPLAY_RANGE}\`"
fi
NOTES="${NOTES}"$'\n\n'"**Full Changelog:** ${CHANGELOG}"

write_output "${NOTES}"
