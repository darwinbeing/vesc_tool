# Qt6 Port — Phase 4 Verification (Android + iOS)

**Date:** 2026-05-19
**Branch:** `qt6-port`

## Result

Phase 4 is complete. VESC Tool builds for **Android (arm64-v8a)** and **iOS** with
Qt 6.8.3 + CMake, verified by GitHub Actions CI. **All five platforms are now
green on the same run.**

- **Final green CI run:** [26129925963](https://github.com/darwinbeing/vesc_tool/actions/runs/26129925963)
  - `linux` ✅ (6m07s)
  - `windows` ✅ (7m43s)
  - `android` ✅ (7m44s)
  - `ios` ✅ (10m46s)
- Both Android and iOS were **built locally on macOS first** (Qt 6.8.3 + Android SDK/NDK
  r26b + Xcode 16) before the final CI push — a much faster iteration loop than
  push→CI→fix cycles for getting the first build through.

## What was done

- **Task 1** — `CMakeLists.txt` Android block: `USE_MOBILE`, `configure_file` for
  `android/AndroidManifest.xml.in` (qmake `$$VAR` tokens converted to CMake `@VAR@`,
  `androiddeployqt` `%%...%%` tokens preserved), `QT_ANDROID_*` properties, and
  `HAS_SERIALPORT` excluded on Android/iOS to match the original `.pro`.
- **Task 2** — JNI migration: `QAndroidJniObject`/`QAndroidJniEnvironment` →
  `QJniObject`/`QJniEnvironment`; `QtAndroid::androidActivity()` →
  `QNativeInterface::QAndroidApplication::context()`; `QtAndroid::runOnAndroidThread()`
  → `runOnAndroidMainThread()`; `QtAndroid::checkPermission`/`requestPermissionsSync`
  → `QtAndroidPrivate::checkPermission`/`requestPermission` with `.result()` for the
  existing synchronous flow. **Compiled correctly first try** on real Android —
  flagged concerns about enum scoping / return type did not materialize.
- **Task 3** — iOS block: `USE_MOBILE` + `QT_NO_PRINTER`, bundle/Info.plist,
  storyboard, asset catalog, `ios/src/setIosParameters.{h,mm}` source guarded with
  `if(IOS)`.
- **Task 4** — CI workflow `android` + `ios` jobs added.
- **Task 4 follow-up** — explicit toolchain setup (per a useful user catch): NDK
  `26.1.10909125` via `sdkmanager` on Android (Qt 6.8 requirement; runner default not
  guaranteed), `maxim-lobanov/setup-xcode` on iOS; both jobs use a `QT_HOST_PATH`
  capture pattern so the second `install-qt-action` call doesn't overwrite the host
  Qt's path.
- **Task 5/6** — local-first builds + CI confirmation.

## Fixes from local + CI iteration

Both local builds passed with surprisingly few fixes — Tasks 1–3 got most of it
right first time.

- **`systemcommandexecutor.h` excluded on iOS** — Phase 1's CMake added it
  unconditionally; the original `.pro` had `unix: !ios: HEADERS += ...`. The header
  uses `QProcess`, which is unavailable on iOS. Gated with `if(NOT IOS)`.
- **`ANDROID_NDK_ROOT` env var** required for local Android configure — Qt's CMake
  macros look up `find_package(GLESv2)` against the NDK sysroot through the env var,
  not just the CMake variable. (CI already exported it via `$GITHUB_ENV`.)
- **CI Android parallelism cap** — the GitHub `ubuntu-22.04` runner (16 GB) OOMed
  during `qrc_res.cpp` compilation under unlimited `--parallel`. Capped to
  `--parallel 2`. Local Android build was fine with more RAM available.

## Verification scope

This is **build-only** verification: the Android APK and iOS .app build, link, and
package cleanly with no errors. **Runtime behavior on a real device has NOT been
verified**, in particular:

- The Android foreground service (`VForegroundService.java`).
- The Android JNI permission flow (Bluetooth scan/connect/location) — the
  `QtAndroidPrivate` API was a translation from the Qt5 `QtAndroid` API; the
  semantic equivalence has been reasoned about but not run on hardware.
- iOS app launch and `setIosParameters` behavior.

These should be checked on devices before any release.

## Notes for later

- The CI workflow uses `actions/checkout@v4`, `ilammy/msvc-dev-cmd@v1`, etc., which
  GitHub flags for Node 20 deprecation (Node 24 forced in June 2026). Bump action
  versions in a future maintenance pass.
- Local Android builds need `ANDROID_NDK_ROOT`/`ANDROID_SDK_ROOT`/`ANDROID_HOME`
  exported in the developer's shell; the CI workflow handles this.
- Re-adding gamepad support via SDL2 remains the one deferred item from the spec
  (separate scoped work).

**This completes the VESC Tool Qt5 → Qt6 + qmake→CMake port.** All five platforms
(macOS, Linux, Windows, Android, iOS) build on Qt 6.8.3.
