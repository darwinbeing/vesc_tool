# Phase 5 — Qt5 + Qt6 Dual-Release CI Design

**Date:** 2026-05-19
**Status:** Approved design

## Goal

Extend the existing fork-side release pipeline (on the `ci` branch) so that a
single release publishes **both Qt5 and Qt6 binaries** for all five platforms:
macOS (x86_64, arm64, universal), Linux, Windows, Android, iOS.

## Constraints & Decisions

- **Approach:** two-branches, both in the release. Qt5 builds from `master`
  (existing pipeline, unchanged). Qt6 builds from `qt6-port`. **No attempt to
  make a single source compile under both Qts** — that was explicitly rejected
  as too expensive.
- **Where the work lives:** all new workflow files go on the `ci` branch (where
  the existing `createRelease.yml` and per-platform Qt5 workflows live). The
  `qt6-port` per-push verification CI (`build.yml`) is unchanged.
- **Platforms:** all five. The earlier Qt6 verification CI proved each builds.
- **Qt6 source:** the `qt6-port` branch directly. The existing Qt5 flow uses
  `release_X_Y` tags + a fork patch overlay; Qt6 needs no patch overlay because
  the fork branch already carries the port.
- **Build system per platform:** Qt5 jobs use **qmake**; Qt6 jobs use **CMake**.
- **Artifact naming:** Qt5 artifacts keep their current names; Qt6 artifacts add
  a `-qt6` suffix before the extension, e.g.
  - `VESC_Tool-7.00-mac.dmg` (Qt5) / `VESC_Tool-7.00-mac-qt6.dmg`
  - `VESC_Tool-7.00.exe` (Qt5) / `VESC_Tool-7.00-qt6.exe`
  - `vesc_tool_7.00.AppImage` (Qt5) / `vesc_tool_7.00-qt6.AppImage`
  - etc.
- **Firmware payload:** shared. Both Qt5 and Qt6 jobs consume the same
  `firmware-${{ inputs.fw_ver }}` artifact (built once upstream of these jobs).
- **Orchestration:** `createRelease.yml` extended to invoke the new
  `*-qt6.yml` jobs alongside the existing Qt5 ones. Both publish to the same
  GitHub Release.

## Per-platform Qt6 workflows (new, on `ci` branch)

For each platform, add a `<platform>-qt6.yml` that mirrors the structure of its
Qt5 sibling but:

1. Checks out **`qt6-port`** as the VT source (no patch overlay).
2. Installs **Qt 6.8.3** via `jurplel/install-qt-action@v4` with the modules the
   Qt6 verification CI used: `qt5compat qtconnectivity qtserialport
   qtpositioning qt3d qtquick3d qtshadertools qtimageformats` (omit
   `qtserialport` on Android/iOS).
3. Installs the toolchain pieces:
   - Android: NDK `26.1.10909125` via `sdkmanager`, JDK 17.
   - iOS: `maxim-lobanov/setup-xcode@v1` `latest-stable`.
   - Windows: `ilammy/msvc-dev-cmd@v1` (MSVC 2022).
4. Configures + builds with **CMake** (not qmake). Use the exact configure
   recipes proven green in `qt6-port/.github/workflows/build.yml`. Android caps
   parallelism to 2 to avoid the 16 GB runner OOM.
5. Packages the platform artifact with the standard tooling (`macdeployqt`,
   `windeployqt`, `linuxdeploy`/AppImage, `androiddeployqt`, `xcodebuild
   archive`).
6. Uploads to the same GitHub Release as the Qt5 binaries, with a `-qt6` suffix
   in the artifact name.

New files (7):

- `.github/workflows/mac-qt6.yml`
- `.github/workflows/mac-arm64-qt6.yml`
- `.github/workflows/mac-universal-qt6.yml`
- `.github/workflows/linux-qt6.yml`
- `.github/workflows/win-qt6.yml`
- `.github/workflows/android-qt6.yml`
- `.github/workflows/ios-qt6.yml`

## Orchestrator change

In `createRelease.yml` on `ci`, add invocations of the seven new workflows
alongside the existing Qt5 ones, in the same release flow. Both sets share the
same firmware artifact and target the same GitHub Release.

## Verification

The Qt6 jobs are verified the same way Phases 3–4 were: a CI run is the test.
For Phase 5, the bar is:

- The seven new `*-qt6.yml` jobs each go green on their first manual run.
- Running `createRelease.yml` (workflow_dispatch) produces a GitHub Release
  containing both Qt5 and Qt6 artifacts for every platform, with disambiguated
  names.

No Qt5 job should be touched in a way that regresses the existing pipeline.

## Out of Scope

- No application source changes (Qt6 port stays on `qt6-port`, Qt5 stays on
  upstream-derived branches).
- No attempt to compile the Qt6-port codebase under Qt 5.15 — explicitly out.
- macOS code signing / notarization for either Qt5 or Qt6 builds (matches the
  current state of the Qt5 pipeline).
- iOS Distribution signing — the iOS Qt6 build will be **unsigned simulator**
  by default, mirroring the Phase 4 verification (publishing a runnable signed
  iOS artifact is a separate concern outside this scope).
- The deferred SDL2-gamepad work.
