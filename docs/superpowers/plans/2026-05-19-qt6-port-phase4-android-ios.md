# Qt6 Port — Phase 4: Android + iOS Builds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make VESC Tool build for **Android** and **iOS** with Qt 6.8 + CMake, verified by GitHub Actions CI. Build-only — on-device runtime verification is deferred.

**Architecture:** macOS/Linux/Windows builds work (Phases 1–3). Phase 4 adds Android and iOS CMake support to `CMakeLists.txt`, migrates the Qt5 `androidextras` JNI code to Qt6's `QJniObject`/`QJniEnvironment` (now in QtCore), and adds `android` + `ios` jobs to the CI workflow, then iterates on CI failures until both are green.

**Tech Stack:** Qt 6.8.3, CMake ≥ 3.21, GitHub Actions, Android (NDK, `androiddeployqt`), iOS (Xcode), C++/JNI.

**Verification model:** macOS-only dev machine — Android/iOS builds are verified entirely via GitHub Actions CI (a task is done when its CI job is green). Build-only: the Android JNI foreground-service *runtime* behavior is checked on a real device later, out of Phase 4 scope.

**Branch:** continue on `qt6-port` (already pushed to `origin`).

**Reference:** the original qmake `vesc_tool.pro` (with its `android {}` and `ios {}` blocks) was deleted in Phase 1 but remains in git history. View it with:
```bash
git show c59524b~1:vesc_tool.pro
```
Use it as the source of truth for Android/iOS build settings, version codes, plist paths, and the manifest substitution.

---

## Task 1: CMake Android support

**Files:**
- Modify: `CMakeLists.txt`

The `android/` directory already holds `AndroidManifest.xml.in`, `build.gradle`, `gradle/`, `gradlew`, `res/`, and `src/com/vedder/vesc/*.java`. The qmake build did a `manifest.input → manifest.output` substitution and set `ANDROID_PACKAGE_SOURCE_DIR`.

- [ ] **Step 1: Read the original Android qmake settings**

```bash
git show c59524b~1:vesc_tool.pro | sed -n '/android:/,/ANDROID_PACKAGE_SOURCE_DIR/p'
```
Note the version codes (`VT_ANDROID_VERSION_*`), `ANDROID_TARGET_ARCH`/`ANDROID_ABIS`, and the `manifest.input`/`manifest.output` substitution (`android/AndroidManifest.xml.in` → `android/AndroidManifest.xml`).

- [ ] **Step 2: Add an Android block to `CMakeLists.txt`**

After the existing Windows block, add:
```cmake
if(ANDROID)
    # Mobile QML GUI
    target_compile_definitions(vesc_tool PRIVATE USE_MOBILE)

    # Generate AndroidManifest.xml from the .in template (qmake did this via QMAKE_SUBSTITUTES).
    # If the .in template uses qmake $${VAR} placeholders, configure_file with @ONLY will not
    # expand them — inspect android/AndroidManifest.xml.in first; if it has no CMake @VAR@
    # placeholders, simply copy it to android/AndroidManifest.xml.
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/android/AndroidManifest.xml.in
        ${CMAKE_CURRENT_SOURCE_DIR}/android/AndroidManifest.xml
        @ONLY)

    set_target_properties(vesc_tool PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/android
        QT_ANDROID_VERSION_NAME ${VT_VERSION}
        QT_ANDROID_VERSION_CODE 207
        QT_ANDROID_TARGET_SDK_VERSION 34
        QT_ANDROID_MIN_SDK_VERSION 23)
endif()
```
> Inspect `android/AndroidManifest.xml.in` before finalizing Step 2 — if it contains qmake `$${...}` tokens (e.g. for version), they must be turned into CMake `@VAR@` tokens for `configure_file` to fill them, or the manifest must be the plain `AndroidManifest.xml` already. Adjust accordingly. Use version code `207` (the arm64 value from the qmake file) unless the `.pro` history says otherwise.

- [ ] **Step 3: Make `HAS_SERIALPORT` exclude Android**

The original `.pro` enabled `HAS_SERIALPORT` only for `!android !ios`. Currently `HAS_SERIALPORT` is unconditional in `target_compile_definitions`. Remove it from the unconditional block and add, near the other feature-define conditionals:
```cmake
# Serial port is desktop-only (not Android/iOS).
if(NOT ANDROID AND NOT IOS)
    target_compile_definitions(vesc_tool PRIVATE HAS_SERIALPORT)
endif()
```
Confirm against the `.pro` history that Bluetooth/Positioning stay enabled on Android (they do — VESC Tool connects over BLE on mobile).

- [ ] **Step 4: Re-verify the macOS build**

```bash
cd /Users/litao/Developer/vesc_tool
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="/Users/litao/Qt/6.8.3/macos" -DCMAKE_BUILD_TYPE=Debug
cmake --build build/macos --parallel
```
Expected: `[100%] Built target vesc_tool`. On macOS `ANDROID`/`IOS` are false, so `HAS_SERIALPORT` is still defined and the Android block is skipped — no regression.

- [ ] **Step 5: Commit**

```bash
git add CMakeLists.txt android/AndroidManifest.xml.in
git commit -m "CMake: add Android build support

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Migrate androidextras to Qt6 QJniObject

**Files:**
- Modify: `vescinterface.h`, `vescinterface.cpp`, `utility.cpp`

Qt6 removed the `androidextras` module; JNI moved into QtCore. This code is all inside `#if defined(Q_OS_ANDROID)` guards (verify), so it does not affect desktop builds — but it must compile for the Android CI job.

- [ ] **Step 1: Update the includes**

In `vescinterface.h` and `utility.cpp`, replace the Qt5 androidextras includes:
- `#include <QtAndroid>` → `#include <QtCore/private/qandroidextras_p.h>` *if* `QtAndroidPrivate` APIs are needed, otherwise remove it.
- `#include <QAndroidJniObject>` → `#include <QJniObject>`
- `#include <QAndroidJniEnvironment>` → `#include <QJniEnvironment>`

- [ ] **Step 2: Rename the JNI types**

Across `vescinterface.h`/`vescinterface.cpp`/`utility.cpp`:
- `QAndroidJniObject` → `QJniObject` (member `mWakeLock` in `vescinterface.h:453`, and all uses)
- `QAndroidJniEnvironment` → `QJniEnvironment`
The `QJniObject` method API (`callStaticMethod`, `callStaticObjectMethod`, `getStaticField`, `getStaticObjectField`, `fromString`, `callObjectMethod`, `.object()`) is the same as `QAndroidJniObject` — only the class name changes.

- [ ] **Step 3: Replace `QtAndroid::androidActivity()`**

`QtAndroid::androidActivity()` (used in `utility.cpp` ~353, 382, 387, 1610, 1620, 1630, 2569+ and `vescinterface.cpp`) → Qt6:
```cpp
QJniObject activity = QNativeInterface::QAndroidApplication::context();
```
`QNativeInterface::QAndroidApplication::context()` returns the Activity as a `QJniObject`. Add `#include <QCoreApplication>` if needed. (For the `vescinterface.cpp:115` `callStaticObjectMethod` that fetches the activity, use the same `context()`.)

- [ ] **Step 4: Replace `QtAndroid::runOnAndroidThread`**

`utility.cpp:353` `QtAndroid::runOnAndroidThread([on]{ ... })` → Qt6:
```cpp
QNativeInterface::QAndroidApplication::runOnAndroidMainThread([on]{ ... });
```
This returns a `QFuture<QVariant>`; the existing code ignores the return, which is fine.

- [ ] **Step 5: Replace the permission API**

`utility.cpp` ~293–337 uses `QtAndroid::checkPermission` / `QtAndroid::requestPermissionsSync` / `QtAndroid::PermissionResult` (synchronous). Qt6 removed these. Use `QtAndroidPrivate` (from `<QtCore/private/qandroidextras_p.h>`), which still offers a synchronous-style flow:
```cpp
using QtAndroidPrivate::PermissionResult;
auto result = QtAndroidPrivate::checkPermission(QStringLiteral("android.permission.BLUETOOTH_SCAN")).result();
if (result == PermissionResult::Denied) {
    result = QtAndroidPrivate::requestPermission(QStringLiteral("android.permission.BLUETOOTH_SCAN")).result();
}
```
`QtAndroidPrivate::checkPermission`/`requestPermission` return `QFuture<PermissionResult>`; `.result()` blocks for the synchronous behavior the existing code expects. Apply this to all three permission sites (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`). If `QtAndroidPrivate` proves unavailable, fall back to the public `QPermission` API (`QCoreApplication::checkPermission` / `requestPermission` with `QBluetoothPermission`/`QLocationPermission`) — but that is async-only and a larger change; prefer `QtAndroidPrivate` first.

- [ ] **Step 6: Note — no local build possible**

This is Android-only code; it cannot be compiled on macOS. It is verified by the Android CI job in Task 5. After making the changes, re-verify the macOS build still links (it should be untouched — the code is `Q_OS_ANDROID`-guarded):
```bash
cmake --build build/macos --parallel
```

- [ ] **Step 7: Commit**

```bash
git add vescinterface.h vescinterface.cpp utility.cpp
git commit -m "Qt6: migrate androidextras JNI to QJniObject

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: CMake iOS support

**Files:**
- Modify: `CMakeLists.txt`

The `ios/` directory holds `Info.plist`, `Images.xcassets`, `MyLaunchScreen.storyboard`, `LaunchImage.png`, `iTunesArtwork*`, and `src/setIosParameters.{h,mm}`.

- [ ] **Step 1: Read the original iOS qmake settings**

```bash
git show c59524b~1:vesc_tool.pro | sed -n '/^ios {/,/^}/p'
```
Note: `QMAKE_INFO_PLIST = ios/Info.plist`, the `ios/src/setIosParameters.{h,mm}` sources, `QMAKE_ASSET_CATALOGS`, the launch screen, `CONFIG += build_mobile` (→ `USE_MOBILE`), and `DEFINES += QT_NO_PRINTER`.

- [ ] **Step 2: Add the iOS sources unconditionally-guarded**

`ios/src/setIosParameters.mm` is an Objective-C++ file only compiled on iOS. Add to `CMakeLists.txt` (near the other `target_sources`, or in the iOS block):
```cmake
if(IOS)
    target_sources(vesc_tool PRIVATE
        ios/src/setIosParameters.h
        ios/src/setIosParameters.mm)
endif()
```

- [ ] **Step 3: Add the iOS configuration block**

After the Android block, add:
```cmake
if(IOS)
    target_compile_definitions(vesc_tool PRIVATE USE_MOBILE QT_NO_PRINTER)

    set_target_properties(vesc_tool PROPERTIES
        MACOSX_BUNDLE ON
        OUTPUT_NAME "VESC Tool"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
        QT_IOS_LAUNCH_SCREEN "${CMAKE_CURRENT_SOURCE_DIR}/ios/MyLaunchScreen.storyboard")

    # Asset catalog (app icon)
    target_sources(vesc_tool PRIVATE ios/Images.xcassets)
    set_source_files_properties(ios/Images.xcassets PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)
endif()
```
> `QT_NO_PRINTER` is defined for iOS — note that the iOS build must also NOT link `Qt6::PrintSupport`. If the build fails because PrintSupport is unavailable on iOS, make the `PrintSupport` component and link conditional (`if(NOT IOS)`), and guard `#include`s of print headers with `#ifndef QT_NO_PRINTER` (the codebase already uses `QT_NO_PRINTER` — check). Handle this in Task 6 if CI surfaces it.

- [ ] **Step 4: Re-verify the macOS build**

```bash
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="/Users/litao/Qt/6.8.3/macos" -DCMAKE_BUILD_TYPE=Debug
cmake --build build/macos --parallel
```
Expected: `[100%] Built target vesc_tool` — `IOS` is false on a desktop macOS build, so the iOS block is skipped.

- [ ] **Step 5: Commit**

```bash
git add CMakeLists.txt
git commit -m "CMake: add iOS build support

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Add Android + iOS CI jobs

**Files:**
- Modify: `.github/workflows/build.yml`

- [ ] **Step 1: Add an `android` job**

Append to the `jobs:` map in `.github/workflows/build.yml`:
```yaml
  android:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - name: Install Qt 6.8.3 (host - linux)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: linux
          target: desktop
          arch: linux_gcc_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
      - name: Install Qt 6.8.3 (Android)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: linux
          target: android
          arch: android_arm64_v8a
          modules: qt5compat qtconnectivity qtpositioning qt3d qtquick3d qtshadertools qtimageformats
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - name: Configure
        run: >
          cmake -S . -B build
          -DCMAKE_TOOLCHAIN_FILE=$Qt6_DIR_ANDROID/lib/cmake/Qt6/qt.toolchain.cmake
          -DQT_HOST_PATH=$Qt6_DIR
          -DCMAKE_BUILD_TYPE=Release
          -DANDROID_ABI=arm64-v8a
      - name: Build
        run: cmake --build build --parallel
```
> The exact env var names for the host vs Android Qt prefixes depend on how `install-qt-action` exports them — it sets `Qt6_DIR` for the most-recent install. Two installs need disambiguation: either give each step an `id` and use its outputs, or install the Android Qt second and use `QT_HOST_PATH` pointing at the desktop install dir. Adjust in Task 5 once the real CI log shows the actual paths.

- [ ] **Step 2: Add an `ios` job**

```yaml
  ios:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Install Qt 6.8.3 (host - macOS)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: mac
          target: desktop
          arch: clang_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
      - name: Install Qt 6.8.3 (iOS)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: mac
          target: ios
          arch: ios
          modules: qt5compat qtconnectivity qtpositioning qt3d qtquick3d qtshadertools qtimageformats
      - name: Configure
        run: >
          cmake -S . -B build -G Xcode
          -DCMAKE_TOOLCHAIN_FILE=$Qt6_DIR_IOS/lib/cmake/Qt6/qt.toolchain.cmake
          -DQT_HOST_PATH=$Qt6_DIR
          -DCMAKE_BUILD_TYPE=Release
      - name: Build
        run: >
          cmake --build build --config Release --
          -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
```
> Same prefix-disambiguation caveat as the android job. The iOS build is unsigned for the simulator SDK — "does it compile/link" is the Phase 4 bar. Adjust paths in Task 6 from the real CI log.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/build.yml
git commit -m "CI: add Android + iOS build jobs

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Get the Android CI job green

**Files:** discovery-driven.

- [ ] **Step 1: Push and read the Android job**

```bash
git push
gh run list --branch qt6-port --workflow build.yml --limit 1
gh run watch <run-id>
gh run view <run-id> --log-failed
```

- [ ] **Step 2: Fix Android build errors, iterate**

Likely categories: the two-Qt-install path/env disambiguation in the workflow (fix `build.yml`); `androiddeployqt` / gradle config; remaining JNI API mismatches from Task 2 that only the Android compiler catches; `QT_ANDROID_*` property issues; missing modules. Fix in the relevant file (`build.yml`, `CMakeLists.txt`, or source), commit (`Qt6: fix Android build errors` + co-author trailer), `git push`, and re-check. Repeat until the `android` job is green.
- Keep the desktop jobs (`linux`/`windows`/macOS) green — Android-specific fixes must stay guarded.
- If CI fails for an infrastructure reason (runner image, action bug) rather than a code error, report BLOCKED with the log excerpt.

- [ ] **Step 3: Confirm** the `android` CI job is green.

---

## Task 6: Get the iOS CI job green

**Files:** discovery-driven.

- [ ] **Step 1: Read the iOS job failure log**

```bash
gh run list --branch qt6-port --workflow build.yml --limit 1
gh run view <run-id> --log-failed
```

- [ ] **Step 2: Fix iOS build errors, iterate**

Likely categories: workflow Qt-prefix disambiguation; the `PrintSupport`-on-iOS issue (make `PrintSupport` link and its `#include`s conditional / `QT_NO_PRINTER`-guarded — see Task 3 Step 3); `ios/src/setIosParameters.mm` Objective-C++ API drift; asset catalog / launch screen / Info.plist issues; missing Qt modules on iOS. Fix, commit (`Qt6: fix iOS build errors` + co-author trailer), `git push`, re-check. Repeat until the `ios` job is green.
- Keep all other jobs green.

- [ ] **Step 3: Confirm** the `ios` CI job is green, and that `linux`, `windows`, `android` are all still green on the same run.

---

## Task 7: Verification note

**Files:**
- Create: `docs/superpowers/plans/2026-05-19-phase4-verification.md`

- [ ] **Step 1: Write the verification note**

Record: the final CI run id/URL with all four jobs (`linux`, `windows`, `android`, `ios`) green; the categories of Android and iOS fixes; the `androidextras`→`QJniObject` migration summary (and the permission-API approach used); and — explicitly — that this is **build-only** verification: the Android JNI foreground-service runtime behavior has NOT been verified on a device and should be checked on real hardware.

- [ ] **Step 2: Commit and push**

```bash
git add docs/superpowers/plans/2026-05-19-phase4-verification.md
git commit -m "Phase 4: verify Android + iOS CI builds

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase 4 Done — Definition of Done

- [ ] The CI workflow's `linux`, `windows`, `android`, and `ios` jobs are all green on `qt6-port`.
- [ ] `androidextras` is fully replaced by Qt6 `QJniObject`/`QJniEnvironment`/`QtAndroidPrivate`.
- [ ] `CMakeLists.txt` builds all five platforms; desktop builds are not regressed.
- [ ] The verification note records that Android JNI runtime behavior is build-verified only and needs a later on-device check.

**This completes the Qt5 → Qt6 port** (all five platforms build on Qt 6.8). Remaining deferred item, tracked separately: re-adding gamepad support via SDL2, if desired.
