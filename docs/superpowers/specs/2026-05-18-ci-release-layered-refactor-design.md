# CI Release Pipeline Layered Refactor — Design

Date: 2026-05-18
Branch: `ci`

## 1. Background

This repository is a fork of `vedderb/vesc_tool` that publishes multi-platform
(Linux / macOS / Windows / Android / iOS) VESC Tool builds with bundled firmware via
GitHub Actions.

Current release flow:

1. The `Version2Ref` step maps the `vt_ver` input to a branch name `VT_REF`
   - `master` → `master`
   - `X.Y` (e.g. `6.06`) → `release_X_Y`
2. Check out that branch's source.
3. Check out the `ci` branch into `.workflow-src` (to obtain the build scripts).
4. `apply_patch.sh` applies `patches/<version>/vesc_tool.patch` onto the source.
5. Download the firmware artifact, compile, and upload the release.

## 2. Problem

`patches/<version>/vesc_tool.patch` is a single monolithic patch that mixes three kinds
of change:

- **Newly created files**: `build_win4CI.ps1`, `build_ios.sh`, `build_macos_arm64`,
  `build_macos_universal`, `build_android_macOS` (5 files, `create mode`).
- **Modifications to upstream build scripts**: `build_lin` (216 lines changed),
  `build_macos` (88 lines changed) — the largest and most conflict-prone part of the patch.
- **Genuine source changes**: esp32 MSVC compatibility, `vesc_tool.pro` `DEFINES`,
  `mainwindow.cpp/.h`, `ios/setIosParameters.h`, `pages/pagecananalyzer.h`,
  `android/build.gradle`, `gradle-wrapper.properties` (few in number, relatively stable).

Whenever upstream drifts, the whole patch fails as a unit. Currently 5 of the 6
version patches fail `git apply --check`.

We also found the release branches are in inconsistent states: `master` and
`release_6_02` are clean upstream; `release_6_05` and `release_6_06` already have the
CI scripts committed into the branch, so the patch re-creates files and reports
`already exists`. The patch nonetheless assumes a clean upstream branch everywhere.

Other problems:
- `apply_patch.sh` only fails after all 4 modes fail, but the `Configure And Compile`
  step is `continue-on-error: true`, so an unpatched version could still be published.
- The 9 platform workflows are highly duplicated (`android.yml` and `android2.yml`
  differ by only 4 lines).

## 3. Decision

**Direction A: release branches become clean upstream-source mirrors; all
customization is delivered through layered overlay.**

Rationale: the upstream repository is not under our control, so fixes cannot be merged
upstream; the fork-branch model ("branch is the product") merely trades patch conflicts
for rebase conflicts, with equal maintenance cost and divergence that is invisible and
hard to review. The layered model separates "files that never conflict" from "a tiny
set of genuine source changes", minimizing the fragile surface.

The CI scripts already committed into `release_6_05` and `release_6_06` need to be
reverted so each release branch returns to a clean upstream state.

## 4. Target Architecture: Three Layers

### Layer 1 — Overlay files (100% ours, never in the patch)

- Location: `.github/overlay/` on the `ci` branch.
- Content: all CI-specific build scripts.
  - The 5 existing created scripts: `build_win4CI.ps1`, `build_ios.sh`,
    `build_macos_arm64`, `build_macos_universal`, `build_android_macOS` (currently
    untracked in the working tree — adopt them as tracked files).
  - New `build_lin4CI`, `build_macos4CI`: freeze the patch's changes to upstream
    `build_lin` / `build_macos` into our own standalone scripts (extracted from the
    post-patch result). The workflows call these instead, so upstream build scripts
    are never touched.
- New `overlay_files.sh` / `overlay_files.ps1`: copy the files under
  `.workflow-src/.github/overlay/` into the checked-out source tree.
- This layer has zero overlap with upstream and never conflicts.

### Layer 2 — Minimal source patch

- Location unchanged: `patches/<version>/vesc_tool.patch`.
- Keeps only genuine source changes: esp32, `vesc_tool.pro`, `mainwindow.cpp/.h`,
  `ios/setIosParameters.h`, `pages/pagecananalyzer.h`, `android/build.gradle`,
  `gradle-wrapper.properties`.
- No created files, no build-script changes — minimal drift surface.
- This effort fully reworks only the `master` patch; other versions' patches are not
  fixed individually here, and are surfaced by the Layer 3 validation workflow.

### Layer 3 — Validation and hard failure

- New `.github/workflows/validate-patches.yml`: on every PR / push to `ci`, for each
  `patches/<version>/`, check out the matching upstream branch and run
  `git apply --check`; any failure fails the job. Caught before release.
- `apply_patch.sh` / `apply_patch.ps1` hard-exit on patch failure (already `exit 1`,
  confirmed kept).
- Remove `continue-on-error: true` from each platform workflow's `Configure And
  Compile` step.

## 5. Implementation Phases

### Phase 1 (core, low risk)

1. Adopt the 5 existing overlay scripts into `.github/overlay/`.
2. Extract `build_lin4CI`, `build_macos4CI` from the master+patch result into
   `.github/overlay/`.
3. Rework `patches/master/vesc_tool.patch`: remove all created-file hunks and the
   `build_lin`/`build_macos` hunks, keeping only genuine source changes; verify
   `git apply --check` passes on a clean `master`.
4. Add `overlay_files.sh` / `.ps1`.
5. Add the Overlay step to the workflows, switch to `build_*4CI`, remove
   `continue-on-error`; get one platform (Linux) working first.
6. Add `validate-patches.yml`.

### Phase 2 (optional, slightly higher risk)

7. Use a reusable workflow (`workflow_call`) + matrix to consolidate the 9 duplicated
   platform workflows, starting with `android.yml` / `android2.yml`.

## 6. Scope and Non-goals

- This effort fully fixes only the `master` version path; cleanup of the other release
  branches (reverting committed scripts, reworking each patch) is handled separately
  after the validation workflow surfaces it, and is not part of this implementation.
- The firmware artifact download logic (`dawidd6/action-download-artifact`) is not
  changed.
- Phase 2 is decided based on how stable Phase 1 turns out.

## 7. Acceptance Criteria

- `git apply --check patches/master/vesc_tool.patch` passes on a clean `master`.
- After the overlay scripts are copied in, the Linux workflow completes
  checkout → overlay → patch → compile.
- `validate-patches.yml` correctly reports the currently broken version patches.
