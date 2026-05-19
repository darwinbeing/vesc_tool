# VESC Tool — Qt5 → Qt6 Port Design

**Date:** 2026-05-19
**Status:** Approved design — ready for implementation planning

## Goal

Port VESC Tool from Qt5 to Qt 6.8 LTS, and migrate the build system from
qmake to CMake. All five existing platforms must build and run after the
port: macOS, Linux, Windows, Android, iOS.

## Constraints & Decisions

- **Target framework:** Qt 6.8 LTS.
- **Build system:** migrate qmake → CMake (Qt's first-class system).
- **Gamepad:** QtGamepad was removed in Qt6 with no official replacement.
  Decision: **drop gamepad support entirely** (remove, do not replace).
- **Scope:** port only. No feature changes, no refactoring beyond what the
  port requires.
- **Branch:** all work on a new `qt6-port` branch cut from a clean `master`.
  The untracked `.orig`/`.rej` files in the working tree are left untouched.
- **Build edition:** only the default `build_neutral` edition is
  smoke-tested. Other editions (`platinum`/`gold`/`silver`/`bronze`/`free`/
  `original`) are confirmed to *configure* in CMake but not exhaustively
  tested.

## Approach

Build-system migration first, then framework bump. This decouples the two
large variables so a failure can be attributed to one or the other.

### Phasing

| Phase | Goal | Verification |
|---|---|---|
| 1 | qmake → CMake, **still Qt5** | macOS build produces a working `VESC Tool.app`, behavior identical to current qmake build |
| 2 | Bump to Qt 6.8, fix C++ + shared QML | macOS Qt6 build runs; core flows work (connect, config, QML pages render, no QML console errors) |
| 3 | Linux + Windows | Both desktop builds green on Qt6 |
| 4 | Android + iOS | Both mobile builds green on Qt6 |

Each phase ends in a verifiable build.

## Phase 1 — CMake migration (still Qt5)

The 11 `.pri` includes and `vesc_tool.pro` become CMake.

- Top-level `CMakeLists.txt`: `qt_add_executable`; version vars
  (`VT_VERSION`, `VT_INTRO_VERSION`, `VT_CONFIG_VERSION`,
  `VT_IS_TEST_VERSION`, `VT_GIT_COMMIT`) as `target_compile_definitions`;
  the `build_*` edition options; platform blocks (macOS bundle/Info.plist,
  iOS, Android, Windows).
- Vendored libraries (`lzokay`, `heatshrink`, `maddy`, `minimp3`,
  `QCodeEditor`, `qmarkdowntextedit`, `display_tool`, `esp32`) and the
  `pages/`, `widgets/`, `mobile/`, `map/` source trees are added directly
  to the single executable, mirroring the current flat `.pri` structure.
  No new library boundaries are introduced in Phase 1.
- Resources: `res*.qrc`, conditional `res/firmwares/res_fw.qrc`
  (gated by `exclude_fw`), and edition `res_*.qrc` via `qt_add_resources`.
- `*.ui` → `CMAKE_AUTOUIC`; MOC → `CMAKE_AUTOMOC`; RCC → `CMAKE_AUTORCC`.
- The qmake `manifest.input → manifest.output` substitution
  (`android/AndroidManifest.xml.in` → `AndroidManifest.xml`) becomes
  `configure_file`.
- The `.pro`/`.pri` files remain in the repo through Phase 1 as reference,
  then are deleted once the CMake build is confirmed equivalent.
- Build scripts (`build_macos_*`, `build_ios.sh`, `build_qt.sh`,
  `build_win4CI.ps1`) are updated to invoke CMake instead of qmake.

## Phase 2 — Qt6 framework port (C++ + shared QML)

Starts with installing Qt 6.8 (macOS).

### C++ migration

- `QRegExp` → `QRegularExpression` in the 6 affected files. Semantics
  differ (anchoring, `.exactMatch()` → explicit `^...$`); each call site is
  reviewed individually, not blindly substituted.
- **Gamepad removal:** drop `QT += gamepad` / `HAS_GAMEPAD`; remove gamepad
  members, slots, and UI from `mainwindow.h/cpp` and `preferences.h/cpp`,
  and remove gamepad controls from the corresponding `.ui` file(s).
- `gui-private` in `utility.h`: inspect the private API used; replace with
  public Qt6 API where possible, otherwise retain `Gui` private with a
  comment explaining why.
- Compiler-surfaced breaks fixed as they appear: `Qt::SplitBehavior` /
  `QString::SkipEmptyParts`, `QList`/`QVector` unification, `QHash`
  iteration, `qAsConst`, removed `QtConcurrent` overloads, `endl`/`flush`
  namespacing.
- `qmlRegisterType` / `setContextProperty` registrations reviewed for Qt6
  (explicit registration still works; `QML_ELEMENT` not required).

### QML migration (shared QML)

- `QtGraphicalEffects` → `import Qt5Compat.GraphicalEffects` (8 files;
  mechanical). Add the `Qt6::Core5Compat` dependency.
- `Qt.labs.settings` → `import QtCore` / `Settings`.
- `QtQuick.Dialogs 1.x` → Qt6 `QtQuick.Dialogs` (6 files). `FileDialog`/
  `MessageDialog` API changed (`folder`, `selectedFile`, signal names);
  reviewed per-file.
- `QtQuick.Controls 1.x` + `Controls.Styles 1.4` (5 files:
  `res/qml/Examples/RtDataSetup.qml`, `mobile/DirectoryPicker.qml`,
  `mobile/RtDataSetup.qml`, `mobile/FilePicker.qml`,
  `mobile/CustomGaugeV2.qml`) → rewritten with Controls 2 equivalents
  (Qt6 `TableView`/`TreeView`, `ScrollView`, etc.).
- `QtQuick.Extras` gauges (`mobile/CustomGauge.qml`,
  `mobile/CustomGaugeV2.qml`) → reimplemented as custom `Canvas`/`Shape`
  gauges; `CircularGauge` has no Qt6 equivalent. Reimplemented faithfully
  against screenshots of current behavior.
- Versioned imports (`QtQuick 2.x`, etc.) left as-is where Qt6 still
  accepts them; only failing imports are touched.

### High-risk QML

- `mobile/Vesc3DView.qml` (`Qt3D` / `QtQuick.Scene3D`) → ported to Qt6
  Qt3D. `Scene3D` still exists in Qt6 but is quirky. Time-boxed; fallback
  is `QtQuick3D` or a static placeholder if Qt6 Qt3D misbehaves.

## Phase 3 — Linux + Windows

Build on Qt 6.8 for both desktop platforms; fix platform-specific breakage
surfaced by their compilers and toolchains.

## Phase 4 — Android + iOS

- **Android JNI:** `androidextras` calls in `vescinterface.cpp/h` and
  `utility.cpp` migrate to `QJniObject` / `QJniEnvironment` (now in
  `QtCore`). API is close but namespaced differently. The foreground-service
  Java glue (`android/src/com/vedder/vesc/VForegroundService.java`) is
  unchanged.
- Mobile-specific QML reviewed and built; iOS build verified.

## Verification

VESC Tool is a GUI app with no unit-test suite, so verification is
build + smoke test.

- Each phase ends with a clean build of its target platform(s) and a manual
  smoke test: launch the app, connect to a VESC (or the built-in
  dummy/simulation if no hardware is available), open the main config
  pages, confirm QML pages render without console errors, and exercise one
  realtime-data view.
- Phase 1 additionally diffs behavior against the current Qt5/qmake build
  to confirm the CMake migration changed nothing.
- QML runtime errors do not fail the build, so each phase explicitly
  inspects the app's console output for `QML` warnings/errors.

## Risks

- **`Vesc3DView.qml` (Qt3D):** highest risk. Mitigation: time-boxed;
  fallback to `QtQuick3D` or a static placeholder.
- **`QtQuick.Extras` gauges:** custom reimplementation is non-trivial and
  the gauges are user-visible. Mitigation: reimplement against screenshots
  of current behavior.
- **Android JNI:** needs a device/emulator to verify the foreground service.
- **No Qt6 installed:** Phase 2 begins with installing Qt 6.8; per-platform
  SDKs installed as later phases need them.

## Out of Scope

- No feature changes; no refactoring beyond what the port requires.
- No cleanup of the stray `.orig`/`.rej` files in the working tree.
- Gamepad support is removed, not replaced.
- Editions other than `build_neutral` are not exhaustively tested.
