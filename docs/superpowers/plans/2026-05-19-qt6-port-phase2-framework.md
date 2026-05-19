# Qt6 Port — Phase 2: Qt6 Framework Port (macOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make VESC Tool build and run on **Qt 6.8 LTS** on macOS, starting from the working Qt5/CMake build produced in Phase 1 (branch `qt6-port`).

**Architecture:** The Phase 1 `CMakeLists.txt` is already Qt-version-agnostic (`find_package(QT NAMES Qt6 Qt5)`). Phase 2 installs Qt 6.8, points CMake at it, and then fixes every Qt5→Qt6 incompatibility the compiler and the QML runtime surface — in C++ (regex, removed modules, private API) and in QML (removed/renamed modules, rewritten Controls-1 UI, reimplemented gauges, Qt3D). Gamepad support is dropped, per the design spec.

**Tech Stack:** Qt 6.8 LTS, CMake ≥ 3.21, C++11, macOS/clang, QML.

**Verification model:** No unit-test suite. The "test" for a C++ task is a successful compile/link; for a QML task it is the app launching and the affected page rendering with no QML errors on the console. Phase 2 is partly **discovery-driven**: Tasks 3 enumerates the regex conversions known up-front, then iterates on whatever else the Qt6 compiler reports. Each task ends in a commit.

**Branch:** continue on `qt6-port` (Phase 1's branch). Do not create a new branch.

**Build prefix:** all `cmake` configures in this plan use the Qt6 prefix:
```bash
export CMAKE_PREFIX_PATH="$HOME/Qt/6.8.<minor>/macos"   # exact path set in Task 1
```

---

## Task 1: Install Qt 6.8 LTS

**Files:** none (environment setup)

- [ ] **Step 1: Install Qt 6.8 with the modules VESC Tool needs**

VESC Tool needs, beyond Qt base (Core/Gui/Widgets/Network/Qml/Quick/QuickControls2/Svg/PrintSupport): `qt5compat` (for `Qt5Compat.GraphicalEffects`), `qtconnectivity` (Bluetooth), `qtserialport`, `qtpositioning`, `qt3d` + `qtquick3d` + `qtshadertools` (for the 3D view), `qtimageformats`.

Install with `aqtinstall` (non-interactive). If `aqt` is not present: `pip3 install -U aqtinstall`. Then:
```bash
aqt list-qt mac desktop --modules 6.8.0 clang_64   # discover exact 6.8.x and module names
aqt install-qt mac desktop 6.8.3 clang_64 \
    -m qt5compat qtconnectivity qtserialport qtpositioning \
       qt3d qtquick3d qtshadertools qtimageformats \
    --outputdir "$HOME/Qt"
```
(Use the latest `6.8.x` that `aqt list-qt` reports. The official Qt online installer is an equivalent alternative if preferred.)

- [ ] **Step 2: Record the prefix path**

Confirm the CMake package dir exists:
```bash
ls "$HOME/Qt/6.8.3/macos/lib/cmake/Qt6"
```
Expected: a directory listing including `Qt6Config.cmake`. Note the full prefix `$HOME/Qt/6.8.3/macos` — every later task uses it as `CMAKE_PREFIX_PATH`.

- [ ] **Step 3: No commit** — this task changes no files.

---

## Task 2: Switch the CMake build to Qt6

**Files:**
- Modify: `CMakeLists.txt`

The Phase 1 `CMakeLists.txt` finds `Gamepad`, links `Qt::Gamepad`, and defines `HAS_GAMEPAD` — none of which exist in Qt6. It also needs `Core5Compat` for the QML `Qt5Compat.GraphicalEffects` module.

- [ ] **Step 1: Drop Gamepad and add Core5Compat in `find_package`**

In `CMakeLists.txt`, in the `find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS ...)` call, **remove** `Gamepad` and **add** `Core5Compat` and `Qml`. The component list becomes:
```cmake
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS
    Core Gui Widgets Network Qml Quick QuickControls2 QuickWidgets Svg
    PrintSupport SerialPort Bluetooth Positioning Core5Compat)
```

- [ ] **Step 2: Remove the `HAS_GAMEPAD` compile definition**

In the `target_compile_definitions(vesc_tool PRIVATE ...)` block, delete the `HAS_GAMEPAD` line. Leave `HAS_BLUETOOTH`, `HAS_POS`, `HAS_SERIALPORT`, `VER_NEUTRAL` and the `VT_*` defines.

- [ ] **Step 3: Update `target_link_libraries`**

Remove the `Qt${QT_VERSION_MAJOR}::Gamepad` line. Add `Qt${QT_VERSION_MAJOR}::Core5Compat` and `Qt${QT_VERSION_MAJOR}::Qml`.

- [ ] **Step 4: Configure against Qt6**

```bash
cd /Users/litao/Developer/vesc_tool
rm -rf build/macos
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="$HOME/Qt/6.8.3/macos" -DCMAKE_BUILD_TYPE=Debug
```
Expected: configuration reaches "Configuring done" / "Generating done". `find_package(QT NAMES Qt6 Qt5)` now resolves to Qt6. If configure fails on a still-missing component, install that module (Task 1 Step 1) and re-run.

- [ ] **Step 5: Commit**

```bash
git add CMakeLists.txt
git commit -m "CMake: target Qt6 — drop Gamepad, add Core5Compat

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Fix C++ compiler breakage under Qt6

**Files (known up-front):**
- Modify: `qmarkdowntextedit/qmarkdowntextedit.cpp:752`
- Modify: `qmarkdowntextedit/qplaintexteditsearchwidget.cpp:320,354`
- Modify: `pages/pagedataanalysis.cpp:50`, `pages/pagemotorsettings.cpp:61`, `pages/pageappsettings.cpp:59`
- Modify: `widgets/mrichtextedit.cpp:675,677`
- Plus: any other files the Qt6 compiler flags (discovery-driven)

`QRegExp` was removed from Qt6 Core. All seven sites must move to `QRegularExpression`. Conversion is **not** mechanical — `QRegExp` was implicitly partial-match and case-sensitive; `QRegularExpression` differs.

- [ ] **Step 1: Convert the `.exactMatch()` site**

`qmarkdowntextedit/qmarkdowntextedit.cpp:752` — `QRegExp(...).exactMatch(text)` becomes an anchored match. Add `#include <QRegularExpression>` if absent. Replace:
```cpp
if (QRegExp(QStringLiteral("[^`]*``")).exactMatch(text)) {
```
with:
```cpp
if (QRegularExpression(QRegularExpression::anchoredPattern(QStringLiteral("[^`]*``")))
        .match(text).hasMatch()) {
```

- [ ] **Step 2: Convert the `QPlainTextEdit::find` sites**

`qmarkdowntextedit/qplaintexteditsearchwidget.cpp:320` and `:354` pass a `QRegExp` to `QPlainTextEdit::find`. Qt6 `find` takes a `QRegularExpression`. Add `#include <QRegularExpression>` if absent. Replace each `QRegExp(text, caseSensitive ? Qt::CaseSensitive : Qt::CaseInsensitive)` with:
```cpp
QRegularExpression(text, caseSensitive ? QRegularExpression::NoPatternOption
                                       : QRegularExpression::CaseInsensitiveOption)
```
Read the surrounding lines first — preserve the rest of each `find(...)` call's arguments unchanged.

- [ ] **Step 3: Convert the three identical `indexIn` sites**

`pages/pagedataanalysis.cpp:50`, `pages/pagemotorsettings.cpp:61`, `pages/pageappsettings.cpp:59` each declare `QRegExp rx("(<img src=)|( width=)")`. Read each file around that line to see how `rx` is used (likely `rx.indexIn(...)` in a loop). Convert to `QRegularExpression` + `QRegularExpressionMatchIterator`/`globalMatch`, preserving behavior. Add `#include <QRegularExpression>`. Because all three sites are identical, apply the same conversion to each; verify each compiles.

- [ ] **Step 4: Convert the `replace` sites**

`widgets/mrichtextedit.cpp:675` and `:677` use `QString::replace(QRegExp, QString)`. Qt6 has `QString::replace(const QRegularExpression&, const QString&)`. The capture-reference syntax changes from QRegExp's `\\1` to QRegularExpression's `\1`. Add `#include <QRegularExpression>`. Convert both calls — wrap the pattern in `QRegularExpression(...)` and change `\\1`/`\\2` in the replacement strings to `\1`/`\2`.

- [ ] **Step 5: Build and iterate on remaining breakage**

```bash
cmake --build build/macos --parallel 2>&1 | tee /tmp/vt-qt6-build.log
```
Fix every compile error. Common Qt5→Qt6 C++ breaks to expect and how to fix them:
- `QString::SkipEmptyParts` / `QString::KeepEmptyParts` → `Qt::SkipEmptyParts` / `Qt::KeepEmptyParts`.
- `qAsConst` → `std::as_const` (or leave; `qAsConst` still exists but is deprecated).
- `QtGui/qpa/qplatformwindow.h` (in `utility.h`) — still available via the `GuiPrivate` target in Qt6; if the build flags it, confirm `Qt6::GuiPrivate` is linked.
- Removed implicit `QString`↔`const char*` conversions, `QVariant` comparison changes, `endl`/`flush` needing `Qt::` prefix in some contexts.
- `QWidget::repaint`/`enterEvent(QEvent*)` signature change → `enterEvent(QEnterEvent*)`.
Make a focused fix for each, keeping changes minimal and faithful. Do **not** change behavior beyond what the API change requires.

- [ ] **Step 6: Build until it links**

Repeat Step 5 until `cmake --build` reports `[100%] Built target vesc_tool` (QML errors are runtime, not build — they come in later tasks).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Qt6: fix C++ compiler breakage (QRegExp, container/string APIs)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Remove dead gamepad code and UI

**Files:**
- Modify: `preferences.h`, `preferences.cpp`, `mainwindow.h`, `mainwindow.cpp`, `preferences.ui`

With `HAS_GAMEPAD` no longer defined (Task 2), the `#ifdef HAS_GAMEPAD` blocks already compile out. This task removes the now-dead code and UI so no stale gamepad surface remains, per the design spec.

- [ ] **Step 1: Remove gamepad code from `preferences.h`/`preferences.cpp`**

In `preferences.h`: remove the `#ifdef HAS_GAMEPAD` include block (`#include <QtGamepad/QGamepad>`), the `mGamepad`/`mUseGamepadControl` members, and — since `setUseGamepadControl`/`isUsingGamepadControl` become meaningless — keep them only if `mainwindow` still calls them; otherwise remove them too (see Step 3). In `preferences.cpp`: remove every `#ifdef HAS_GAMEPAD` block and its contents (lines around 33, 71, 123, 171, 192, 232, 332, 343, 356, 456). Read each block fully before deleting so surrounding non-gamepad code is preserved.

- [ ] **Step 2: Remove the Gamepad tab from `preferences.ui`**

Open `preferences.ui`, find the tab/page whose title string is `Gamepad` (near line 472) and the `jsAxis*Bar` / `jsListBox` widgets it contains, and remove that tab and its widgets. Use Qt Designer or careful XML editing; after editing, confirm the file is still valid XML.

- [ ] **Step 3: Remove the gamepad action from `mainwindow`**

In `mainwindow.h`: remove the `on_actionGamepadControl_triggered(bool)` slot declaration (line ~165). In `mainwindow.cpp`: remove the slot definition (around line 2224) and the `actionGamepadControl` icon line (around line 185). In `mainwindow.ui`: remove the `actionGamepadControl` action and its menu/toolbar references. If Step 1 left `setUseGamepadControl`/`isUsingGamepadControl` and nothing else calls them, remove them from `preferences.h`/`.cpp` now.

- [ ] **Step 4: Build**

```bash
cmake --build build/macos --parallel
```
Expected: `[100%] Built target vesc_tool` — no references to removed gamepad symbols remain.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Drop gamepad support (removed in Qt6)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: QML — migrate QtGraphicalEffects to Qt5Compat

**Files (8):** `res/qml/Examples/RtDataSetup.qml`, `mobile/SetupWizardInput.qml`, `mobile/SetupWizardIMU.qml`, `mobile/CustomGauge.qml`, `mobile/SetupWizardFoc.qml`, `mobile/SetupWizardIntro.qml`, `mobile/RtDataSetup.qml`, `mobile/CustomGaugeV2.qml`

- [ ] **Step 1: Swap the import in all 8 files**

In each file, replace the line `import QtGraphicalEffects <version>` (e.g. `1.0`, `1.12`, `1.15`) with:
```qml
import Qt5Compat.GraphicalEffects
```
(Qt6 modules take no version number.) The element names (`DropShadow`, `RadialGradient`, `LinearGradient`, `ColorOverlay`, etc.) are unchanged in `Qt5Compat.GraphicalEffects`.

- [ ] **Step 2: Verify the module resolves**

A full build still succeeds (QML imports are runtime). To check the import is found, after building run the app (a later task does the full smoke test) — for now confirm the `qt5compat` module is installed: `ls "$HOME/Qt/6.8.3/macos/qml/Qt5Compat/GraphicalEffects"` should list QML files.

- [ ] **Step 3: Commit**

```bash
git add res/qml/Examples/RtDataSetup.qml mobile/SetupWizardInput.qml \
        mobile/SetupWizardIMU.qml mobile/CustomGauge.qml mobile/SetupWizardFoc.qml \
        mobile/SetupWizardIntro.qml mobile/RtDataSetup.qml mobile/CustomGaugeV2.qml
git commit -m "QML: QtGraphicalEffects -> Qt5Compat.GraphicalEffects

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: QML — migrate Qt.labs.settings

**Files (3):** `mobile/Lisp.qml`, `mobile/TcpHubBox.qml`, `mobile/LogBox.qml`

`Qt.labs.settings` moved into the `QtCore` QML module in Qt6 (the `Settings` type).

- [ ] **Step 1: Swap the import in all 3 files**

In each file, replace `import Qt.labs.settings <version>` (often aliased, e.g. `import Qt.labs.settings 1.0 as QSettings`) with:
```qml
import QtCore
```
If a file used an alias (`as QSettings`), keep the alias on the new import (`import QtCore as QSettings`) so existing `QSettings.Settings { ... }` usages still resolve. Read each file to see whether an alias is used and match it exactly.

- [ ] **Step 2: Commit**

```bash
git add mobile/Lisp.qml mobile/TcpHubBox.qml mobile/LogBox.qml
git commit -m "QML: Qt.labs.settings -> QtCore

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: QML — migrate QtQuick.Dialogs

**Files (6):** `mobile/ConfigPageCustom.qml`, `mobile/Lisp.qml`, `mobile/FwUpdate.qml`, `mobile/ConfigPageMotor.qml`, `mobile/ConfigPageApp.qml`, `mobile/Packages.qml`

Qt6 `QtQuick.Dialogs` replaces the Qt5 `QtQuick.Dialogs 1.x` module with a redesigned API: `FileDialog` uses `selectedFile`/`currentFolder` instead of `fileUrl`/`folder`; `MessageDialog` uses `buttons` and a `text`/`informativeText` split; signals changed (`onAccepted` stays, but `onYes`/`onNo` become button-based).

- [ ] **Step 1: Migrate each file**

For each of the 6 files:
1. Replace `import QtQuick.Dialogs 1.x` (and any `as <alias>`) with `import QtQuick.Dialogs`.
2. Read every `FileDialog`/`MessageDialog`/`ColorDialog` block in the file.
3. For `FileDialog`: `folder:` → `currentFolder:`; reading `fileUrl`/`fileUrls` → `selectedFile`/`selectedFiles`; `selectExisting`/`selectMultiple`/`selectFolder` → `fileMode` (`FileDialog.OpenFile` / `FileDialog.OpenFiles` / `FileDialog.SaveFile`).
4. For `MessageDialog`: `text`/`informativeText` are kept; `standardButtons` → `buttons`; `onYes`/`onNo` handlers → handle via `onButtonClicked` / the `StandardButton` the dialog reports, or switch to `onAccepted`/`onRejected` where the dialog is a simple OK/Cancel.
Migrate one file at a time and keep each dialog's behavior identical.

- [ ] **Step 2: Commit**

```bash
git add mobile/ConfigPageCustom.qml mobile/Lisp.qml mobile/FwUpdate.qml \
        mobile/ConfigPageMotor.qml mobile/ConfigPageApp.qml mobile/Packages.qml
git commit -m "QML: migrate QtQuick.Dialogs to the Qt6 API

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: QML — rewrite QtQuick.Controls 1 usage with Controls 2

**Files (5):** `res/qml/Examples/RtDataSetup.qml`, `mobile/DirectoryPicker.qml`, `mobile/RtDataSetup.qml`, `mobile/FilePicker.qml`, `mobile/CustomGaugeV2.qml`

`QtQuick.Controls 1.x` and `QtQuick.Controls.Styles 1.4` were removed in Qt6. Each file mixes Controls 1 (often imported `as OldControls`) with Controls 2.

- [ ] **Step 1: Inventory the Controls-1 types used**

For each of the 5 files, read it and list every type used from the Controls-1 import (commonly `TableView`, `TableViewColumn`, `TreeView`, `ScrollView`, `SplitView`, `Menu`, styled `Button`/`ComboBox`, and `*Style` types from `Controls.Styles`).

- [ ] **Step 2: Rewrite each file with Controls 2 equivalents**

Replace the Controls-1 import with the Qt6 equivalents and rewrite the affected elements:
- Controls-1 `TableView`/`TableViewColumn` → Qt6 `TableView` (from `QtQuick`) with a model + `delegate`, or `HorizontalHeaderView` + `TableView`, depending on what the file displays.
- Controls-1 `ScrollView`/`SplitView` → the Controls 2 versions (`import QtQuick.Controls`).
- `*Style` objects from `QtQuick.Controls.Styles` → Controls 2 styling (inline `background`/`contentItem` delegates, or the Material style already used elsewhere in this codebase).
Rewrite one file at a time. Preserve the visible layout and behavior. Keep the diff focused — do not restyle beyond what removing Controls 1 requires.

- [ ] **Step 3: Commit**

```bash
git add res/qml/Examples/RtDataSetup.qml mobile/DirectoryPicker.qml \
        mobile/RtDataSetup.qml mobile/FilePicker.qml mobile/CustomGaugeV2.qml
git commit -m "QML: replace QtQuick.Controls 1 with Controls 2

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: QML — reimplement the Extras gauges

**Files (2):** `mobile/CustomGauge.qml`, `mobile/CustomGaugeV2.qml`

`QtQuick.Extras` (which provided `CircularGauge`/`Gauge`) was removed in Qt6 with no replacement. Both gauge files must be reimplemented.

- [ ] **Step 1: Capture current behavior**

Before changing anything, study both files: note the gauge range, tick marks, needle, value text, and colors — these are user-facing realtime gauges and must look the same.

- [ ] **Step 2: Reimplement with Canvas/Shapes**

Replace the `QtQuick.Extras` `CircularGauge` with a custom implementation drawn with `Canvas` (or `QtQuick.Shapes` `Shape`/`PathArc`): an arc background, tick marks, a rotating needle bound to the gauge value, and the value label. Keep the same public properties the rest of the QML sets on these gauge components (read the call sites with `grep -rn "CustomGauge" --include='*.qml'`) so callers don't change.

- [ ] **Step 3: Commit**

```bash
git add mobile/CustomGauge.qml mobile/CustomGaugeV2.qml
git commit -m "QML: reimplement Extras gauges with Canvas (Extras removed in Qt6)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: QML — port the Qt3D view

**Files:** `mobile/Vesc3DView.qml` (and check `widgets/vesc3dview.cpp`/`mobile/vesc3ditem.cpp` for C++-side Qt3D/Scene3D usage)

`mobile/Vesc3DView.qml` uses `Qt3D.*` and `QtQuick.Scene3D`. Qt3D still ships in Qt6 but its API and `Scene3D` integration changed and can be unstable.

- [ ] **Step 1: Attempt a direct Qt3D port**

Update the imports (`import Qt3D.Core`, `import Qt3D.Render`, `import Qt3D.Extras`, `import Qt3D.Input`, `import QtQuick.Scene3D` — all unversioned in Qt6). Build and run; check whether the 3D view renders.

- [ ] **Step 2: If Qt3D misbehaves, fall back to QtQuick3D**

If the Qt3D port does not render correctly or crashes, reimplement the view with `QtQuick3D` (`import QtQuick3D`) — a `View3D` with the model loaded as a `Model`. If even that is impractical within reason, replace the 3D view with a static placeholder (a labelled rectangle) and record the limitation in the verification note. Pick exactly one outcome and make it work; do not leave the file half-ported.

- [ ] **Step 3: Commit**

```bash
git add mobile/Vesc3DView.qml
# add any C++ files touched
git commit -m "QML: port Vesc3DView to Qt6 3D

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 11: Full build, run, and QML error sweep

**Files:** verification note only

- [ ] **Step 1: Clean build**

```bash
cd /Users/litao/Developer/vesc_tool
rm -rf build/macos
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="$HOME/Qt/6.8.3/macos" -DCMAKE_BUILD_TYPE=Debug
cmake --build build/macos --parallel
```
Expected: `[100%] Built target vesc_tool`, producing `build/macos/VESC Tool.app`.

- [ ] **Step 2: Launch and sweep the console for QML errors**

Run the binary directly so QML diagnostics go to the terminal:
```bash
"build/macos/VESC Tool.app/Contents/MacOS/VESC Tool" 2>&1 | tee /tmp/vt-qt6-run.log
```
Exercise the app: main window, the page list, Preferences, several QML-backed pages, the realtime gauges, the file/directory pickers, and the 3D view. For every `QML ... error`, `module ... is not installed`, or `is not a type` in the log, go back to the relevant task's files and fix it, then rebuild. Repeat until the swept flows produce no QML errors (pre-existing benign binding-loop warnings excepted — note them, don't chase them).

- [ ] **Step 3: Write the verification note**

Create `docs/superpowers/plans/2026-05-19-phase2-verification.md` recording: build result, which flows were exercised, remaining known issues (e.g. the Qt3D outcome from Task 10), and that the interactive smoke test is for the human. Commit:
```bash
git add docs/superpowers/plans/2026-05-19-phase2-verification.md
git commit -m "Phase 2: verify Qt6 macOS build

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 2 Done — Definition of Done

- [ ] VESC Tool builds on Qt 6.8 with CMake and produces a running `VESC Tool.app` on macOS.
- [ ] No `QRegExp` or other removed Qt5 API remains; the build is warning-tolerant but error-free.
- [ ] Gamepad support is fully removed (build flag, code, and UI).
- [ ] The migrated QML modules (GraphicalEffects, settings, Dialogs, Controls, gauges, 3D) render without QML console errors in the swept flows.
- [ ] The human has run an interactive smoke test and confirmed the app behaves as before (minus gamepad).

**Next:** Phase 3 (Linux + Windows) gets its own plan.
