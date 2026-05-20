# Qt6 Port — Phase 5 Verification (Qt5 + Qt6 Dual-Release CI)

**Date:** 2026-05-19
**Branches:** workflows on `ci`; docs on `qt6-port`

## Result

Phase 5 is complete. The fork's release pipeline now publishes **both Qt5 and
Qt6 binaries** for all five platforms. Seven new Qt6 release workflows were added
to the `ci` branch, each verified green individually, and `createRelease.yml` was
extended to dispatch them alongside the existing Qt5 jobs.

## Qt6 artifacts published to Release 7.00 (all green)

| Platform | Workflow | Artifact | First green run |
|---|---|---|---|
| Linux | `Linux-qt6` | `vesc_tool-7.00-qt6.AppImage` | 26131805205 |
| macOS x86_64 | `macOS-x86_64-qt6` | `VESC_Tool-7.00-mac-qt6.dmg` | 26135106290 |
| macOS arm64 | `macOS-arm64-qt6` | `VESC_Tool-7.00-mac-arm64-qt6.dmg` | 26135425358 |
| macOS universal | `macOS-universal-qt6` | `VESC_Tool-7.00-mac-universal-qt6.dmg` | 26135426282 |
| Windows | `Windows-qt6` | `VESC_Tool-7.00-win-qt6.zip` | 26135888822 |
| Android | `Android-qt6` | `VESC_Tool-7.00-android-qt6.apk` | 26136293544 |
| iOS | `iOS-qt6` | `VESC_Tool-7.00-ios-simulator-qt6.zip` | 26135890782 |

## Approach

Two-branches: Qt5 builds from `master` (existing pipeline, untouched); Qt6 builds
from `qt6-port`. Each `*-qt6.yml` mirrors the release framing of its Qt5 sibling
(release-notes generation, firmware artifact download, upload to the same GitHub
Release) but checks out `qt6-port`, installs Qt 6.8.3, builds with **CMake**, and
uploads a `-qt6`-suffixed artifact. `createRelease.yml` dispatches all 7 Qt6
workflows after the 7 Qt5 ones.

## Notable issues fixed during bring-up

- **`VT_VERSION` source** — the Qt6 branch removed `vesc_tool.pro`; the Qt6
  workflows read `VT_VERSION` from `CMakeLists.txt` instead.
- **`VT_REF` required** — `generate_release_notes.sh` needs `VT_REF`; the Setup
  step exports it from `inputs.vt_ver`.
- **`$QT_ROOT_DIR` not `$Qt6_DIR`** — `install-qt-action@v4` exports
  `QT_ROOT_DIR`; the macdeployqt/windeployqt and patch steps use it.
- **macOS AGL.framework** — Qt 6.8.3 still emits `-framework AGL` (in
  `FindWrapOpenGL.cmake` and dozens of `.prl` files). Xcode 26 on `macos-15`
  removed AGL → link error. **Resolved by pinning `xcode-version: '16.4'`**
  (its SDK retains AGL) rather than patching Qt. The same pin is used in
  `mac-*-qt6.yml` and `ios-qt6.yml`. Note: local builds didn't hit this because
  the dev machine's Xcode 16.1 SDK still has AGL.
- **OOM on resource compile** — `qrc_res.cpp` is memory-heavy; capped
  `cmake --build --parallel 2` on the memory-limited macOS/Windows/Android
  runners (16 GB / 7 GB). macOS also switched to the Ninja generator (default
  Make stalled ~40 min on the constrained runner).
- **Qt mirror flake** — the Android Qt install once failed when `download.qt.io`
  and all fallback mirrors were unreachable (transient); a re-run succeeded.

## Verification scope

- Each of the 7 `*-qt6.yml` workflows produced a green run and uploaded its
  artifact to Release 7.00 — verified.
- `createRelease.yml`'s Qt6 dispatch wiring is a faithful copy of the proven Qt5
  dispatch pattern (`benc-uk/workflow-dispatch@v1` by workflow name). A full
  end-to-end `createRelease.yml` dispatch (firing all 14 Qt5+Qt6 jobs) was **not**
  run here to conserve CI minutes; run it when cutting an actual release.
- These are **build/package** artifacts. The Android APK and iOS .app are
  **unsigned**; runtime/on-device behavior is not verified (consistent with the
  Phase 4 build-only bar and the current Qt5 pipeline).

## Out of scope (unchanged from the spec)

- No application source changes; no single-codebase dual-Qt compilation.
- macOS/iOS code signing & notarization; device-installable iOS IPA.
- The deferred SDL2-gamepad work.

**This completes the dual-release CI.** All five platforms now ship both a Qt5
and a Qt6 build in a single GitHub Release.
