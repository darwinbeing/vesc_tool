# Qt6 Port — Phase 2 Verification Note

**Date:** 2026-05-19
**Branch:** `qt6-port`
**Qt:** 6.8.3 LTS (`/Users/litao/Qt/6.8.3/macos`)
**Platform:** macOS (Apple clang 16), CMake build.

This note records Task 11 of the Phase 2 plan
(`2026-05-19-qt6-port-phase2-framework.md`): a clean build, an app-launch
run, and the QML error sweep.

## 1. Clean build result

```
rm -rf build/macos
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="/Users/litao/Qt/6.8.3/macos" -DCMAKE_BUILD_TYPE=Debug
cmake --build build/macos --parallel
```

- Configure: `Configuring done` / `Generating done`, `find_package(QT NAMES Qt6 Qt5)`
  resolves to Qt6.
- Build: **`[100%] Built target vesc_tool`** — no compile or link errors.
- Output bundle produced: `build/macos/VESC Tool.app`
  (`Contents/MacOS/VESC Tool`, ~35 MB).
- The build emits Qt6 deprecation warnings only (`QVariant::canConvert`,
  `qAsConst`, etc.). `qAsConst` warnings are intentionally left per the plan.

## 2. What was exercised

The app was launched directly from the binary (so QML diagnostics print to
the terminal) for ~25 s and the console swept:

```
( "build/macos/VESC Tool.app/Contents/MacOS/VESC Tool" 2>&1 & APP=$!; sleep 25; kill $APP ) | tee /tmp/vt-qt6-run.log
```

App startup loads `mobile/main.qml` and a large fraction of its imported
components, so the launch flow alone surfaces most QML import/type errors.
Components confirmed to load without QML errors at startup include the
mobile main window, `ConnectScreen.qml`, the Setup Wizard pages
(`SetupWizardFoc/IMU/Input/Intro`), `Profiles.qml`, and the migrated
modules from Tasks 5–9 (Qt5Compat.GraphicalEffects, QtCore Settings,
QtQuick.Dialogs, Controls 2, the reimplemented Canvas gauges).

**Coverage limitation:** this was a startup-load sweep only. The agent
cannot click through the GUI, so deeper interactive flows (opening
dialogs, navigating every page, the file/directory pickers, live realtime
gauges, the 3D view rendering) were **not** exercised. See the human
smoke-test checklist below.

## 3. QML errors found and fixed

The QML runtime sweep produced **no QML errors** — no
`module ... is not installed`, `... is not a type`, `Cannot assign...`,
`ReferenceError`, or property/type errors from this codebase's `.qml`
files. Tasks 5–10 fully covered the QML module migration.

The sweep did, however, surface four real **Qt5→Qt6 C++ regressions**
that print to the same console (Qt `QObject::connect` runtime failures —
silently dead at runtime, not compile errors, so Task 3 did not catch
them). These were fixed faithfully:

| File | Problem | Fix |
|------|---------|-----|
| `vescinterface.cpp:145` | `QSerialPort::error(SerialPortError)` signal removed in Qt6 | Renamed to `errorOccurred(SerialPortError)` |
| `vescinterface.cpp:171` | `QTcpSocket`/`QAbstractSocket::error(SocketError)` signal removed in Qt6 | Renamed to `errorOccurred(SocketError)` |
| `vescinterface.cpp:178` | `QUdpSocket`/`QAbstractSocket::error(SocketError)` signal removed in Qt6 | Renamed to `errorOccurred(SocketError)` |
| `esp32/esp32flash.cpp:40` | `QSerialPort::error(SerialPortError)` signal removed in Qt6 | Renamed to `errorOccurred(SerialPortError)` |
| `widgets/mrichtextedit.cpp:202` | `QComboBox::activated(QString)` overload removed in Qt6 | Switched to new-style connect on `QComboBox::textActivated` → `MRichTextEdit::textSize` |

Without these fixes, serial/TCP/UDP/ESP32 error handling and the rich-text
font-size combo would never fire their slots. The renamed signals carry
identical arguments, so behavior is preserved.

After the fixes, a rebuild (`[100%] Built target vesc_tool`) and re-run
showed **zero** `No such signal` messages and **zero** QML errors.

## 4. Remaining known issues (warnings only — not errors)

All remaining console output is benign and was intentionally not chased,
per the Task 11 scope:

- **Binding-loop warnings** in `SetupWizardFoc.qml` (TabBar/TabButton
  `width`/`implicitWidth`, lines 641/659) and `Dialog`
  `implicitHeight` binding loops in `ConnectScreen.qml`,
  `SetupWizardFoc.qml`, `Profiles.qml`. Pre-existing layout warnings,
  not errors.
- **`QML Connections` deprecation** at `SetupWizardIMU.qml:89` —
  implicitly-defined `onFoo` handler; deprecation notice, still works.
- `QFSFileEngine::open: No file name specified` and
  `Param group "gpd" not found` — from absent hardware / unloaded
  config, not QML errors.
- macOS `IMKClient`/`IMKInputSession` input-method log lines — OS noise.

### Vesc3DView.qml is legacy (Task 10 finding)

`mobile/Vesc3DView.qml` is **unreferenced legacy code** — nothing in the
QML tree instantiates it. The live 3D view is the C++ path
(`Vesc3dItem` / `QOpenGLWidget`, see `widgets/vesc3dview.cpp` /
`mobile/vesc3ditem.cpp`). Task 10 ported `Vesc3DView.qml`'s imports to
the Qt6 unversioned form for completeness, but the file is not loaded at
runtime, so the QML sweep cannot and does not exercise it. No 3D QML
errors can appear from this file in normal use.

## 5. Interactive smoke test — for the human

The agent verified the build and the startup-load QML sweep only. A
human should run `build/macos/VESC Tool.app` and click through to
confirm behavior matches Qt5 (minus gamepad, which is removed):

- [ ] Main window opens; page list / sidebar navigation works.
- [ ] **Preferences** dialog opens and all tabs render (confirm the
      Gamepad tab is gone and nothing broke around its removal).
- [ ] Several QML-backed pages render (motor/app config pages, Lisp,
      Packages, FW Update).
- [ ] **Realtime gauges** (`CustomGauge` / `CustomGaugeV2`, reimplemented
      with Canvas in Task 9) display correctly — range, ticks, needle,
      value text — when connected to a VESC.
- [ ] **File and directory pickers** (`FilePicker.qml`,
      `DirectoryPicker.qml`) open and select files/folders
      (Qt6 `QtQuick.Dialogs` API, Task 7/8).
- [ ] **Dialogs** migrated in Task 7 (`FileDialog`, `MessageDialog` in
      ConfigPage*, FwUpdate, Lisp, Packages) accept/reject correctly.
- [ ] The **3D view** renders (C++ `Vesc3dItem` path) on a connected
      VESC.
- [ ] Connecting over **serial / TCP / UDP** works, and a deliberate
      connection error surfaces a user-visible error (exercises the
      `errorOccurred` connect fixes from this task).
- [ ] The **rich-text editor** font-size combo changes text size
      (exercises the `textActivated` connect fix).

## Definition of Done status

- [x] VESC Tool builds on Qt 6.8.3 with CMake → running `VESC Tool.app`.
- [x] No `QRegExp` / removed Qt5 API remains; build is error-free
      (warning-tolerant).
- [x] Gamepad support fully removed (build flag, code, UI).
- [x] Migrated QML modules render with no QML console errors in the
      startup-load sweep.
- [ ] Human interactive smoke test — pending (checklist above).
