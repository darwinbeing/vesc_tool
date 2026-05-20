# SDL3 Gamepad Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore VESC Tool's desktop gamepad control feature on the Qt6 codebase using SDL3 instead of the removed QtGamepad.

**Architecture:** A new focused `Gamepad` QObject wraps SDL3's gamepad API with an interface mirroring the old `QGamepad`/`QGamepadManager` calls. The original Preferences "Gamepad" tab, its 100 ms axis→command control loop, and the MainWindow toggle are restored from git (commit `4570bc1~1`), repointed at the new backend, minus the per-axis configure/reset buttons (no SDL3 equivalent). Desktop-only (`HAS_GAMEPAD` = `!ANDROID && !IOS`).

**Tech Stack:** SDL3 (`SDL_Gamepad` API), Qt 6.8.3, CMake, C++.

**Verification model:** No unit tests (GUI + hardware feature). The "test" per task is a successful macOS build (`cmake --build build/macos`); the final bar is the desktop CI jobs staying green with SDL3 linked/bundled, plus a human smoke test with a real gamepad.

**Branches:** code on `qt6-port` (main worktree `/Users/litao/Developer/vesc_tool`); the CI workflow changes (Task 7) on `ci` (worktree `/Users/litao/Developer/vesc_tool-ci`).

**Restore reference:** the original code is at git commit `4570bc1~1` (the commit before "Drop gamepad support"). View any original file with `git show 4570bc1~1:<path>`.

**macOS build command (used throughout):**
```bash
cd /Users/litao/Developer/vesc_tool
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="/Users/litao/Qt/6.8.3/macos" -DCMAKE_BUILD_TYPE=Debug
cmake --build build/macos --parallel
```

---

## Task 1: Install SDL3 and wire it into CMake (desktop-only)

**Files:**
- Modify: `CMakeLists.txt`

- [ ] **Step 1: Install SDL3 locally (macOS)**

```bash
brew install sdl3
brew --prefix sdl3   # note the prefix; provides SDL3Config.cmake under lib/cmake/SDL3
```

- [ ] **Step 2: Add SDL3 find_package + HAS_GAMEPAD (desktop only) to `CMakeLists.txt`**

After the existing `find_package(Qt... )` blocks, add:
```cmake
# Gamepad support via SDL3 — desktop only (matches original !android !ios).
if(NOT ANDROID AND NOT IOS)
    find_package(SDL3 CONFIG REQUIRED)
endif()
```
In the `target_compile_definitions(vesc_tool PRIVATE ...)` area, add a desktop-only `HAS_GAMEPAD` define alongside the existing `HAS_SERIALPORT` guard:
```cmake
if(NOT ANDROID AND NOT IOS)
    target_compile_definitions(vesc_tool PRIVATE HAS_GAMEPAD)
endif()
```
In `target_link_libraries`, add SDL3 under a desktop guard near the end of the file:
```cmake
if(NOT ANDROID AND NOT IOS)
    target_link_libraries(vesc_tool PRIVATE SDL3::SDL3)
endif()
```

- [ ] **Step 3: Configure + build (no gamepad code yet — HAS_GAMEPAD guards nothing)**

Run the macOS build command. If `find_package(SDL3)` fails, pass the brew prefix:
`-DCMAKE_PREFIX_PATH="/Users/litao/Qt/6.8.3/macos;$(brew --prefix sdl3)"`.
Expected: `[100%] Built target vesc_tool` (defining `HAS_GAMEPAD` with no guarded code yet is a no-op).

- [ ] **Step 4: Commit**

```bash
git add CMakeLists.txt
git commit -m "CMake: find + link SDL3, re-add HAS_GAMEPAD (desktop only)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Create the SDL3 Gamepad backend

**Files:**
- Create: `gamepad.h`
- Create: `gamepad.cpp`
- Modify: `CMakeLists.txt`

- [ ] **Step 1: Create `gamepad.h`**

```cpp
#ifndef GAMEPAD_H
#define GAMEPAD_H

#include <QObject>
#include <QString>
#include <QList>

struct SDL_Gamepad;

// SDL3-backed gamepad, interface-compatible with the subset of QGamepad/
// QGamepadManager that VESC Tool used. Axis getters return -1.0..1.0.
class Gamepad : public QObject
{
    Q_OBJECT
public:
    explicit Gamepad(int deviceId, QObject *parent = nullptr);
    ~Gamepad() override;

    double axisLeftX();
    double axisLeftY();
    double axisRightX();
    double axisRightY();

    bool isConnected();
    QString name();
    int deviceId() const { return mDeviceId; }

    // Enumeration (replaces QGamepadManager::connectedGamepads / gamepadName).
    static QList<int> connectedGamepads();
    static QString gamepadName(int deviceId);

private:
    static void ensureInit();
    double axis(int sdlAxis);

    SDL_Gamepad *mPad = nullptr;
    int mDeviceId = -1;
};

#endif // GAMEPAD_H
```

- [ ] **Step 2: Create `gamepad.cpp`**

```cpp
#include "gamepad.h"
#include <SDL3/SDL.h>

void Gamepad::ensureInit()
{
    if (!SDL_WasInit(SDL_INIT_GAMEPAD)) {
        SDL_InitSubSystem(SDL_INIT_GAMEPAD);
    }
}

Gamepad::Gamepad(int deviceId, QObject *parent)
    : QObject(parent), mDeviceId(deviceId)
{
    ensureInit();
    mPad = SDL_OpenGamepad(static_cast<SDL_JoystickID>(deviceId));
}

Gamepad::~Gamepad()
{
    if (mPad) {
        SDL_CloseGamepad(mPad);
        mPad = nullptr;
    }
}

double Gamepad::axis(int sdlAxis)
{
    if (!mPad) {
        return 0.0;
    }
    SDL_UpdateGamepads();
    Sint16 v = SDL_GetGamepadAxis(mPad, static_cast<SDL_GamepadAxis>(sdlAxis));
    return static_cast<double>(v) / 32767.0;
}

double Gamepad::axisLeftX()  { return axis(SDL_GAMEPAD_AXIS_LEFTX); }
double Gamepad::axisLeftY()  { return axis(SDL_GAMEPAD_AXIS_LEFTY); }
double Gamepad::axisRightX() { return axis(SDL_GAMEPAD_AXIS_RIGHTX); }
double Gamepad::axisRightY() { return axis(SDL_GAMEPAD_AXIS_RIGHTY); }

bool Gamepad::isConnected()
{
    return mPad && SDL_GamepadConnected(mPad);
}

QString Gamepad::name()
{
    if (!mPad) {
        return QString();
    }
    const char *n = SDL_GetGamepadName(mPad);
    return n ? QString::fromUtf8(n) : QString();
}

QList<int> Gamepad::connectedGamepads()
{
    ensureInit();
    QList<int> ids;
    int count = 0;
    SDL_JoystickID *list = SDL_GetGamepads(&count);
    if (list) {
        for (int i = 0; i < count; ++i) {
            ids.append(static_cast<int>(list[i]));
        }
        SDL_free(list);
    }
    return ids;
}

QString Gamepad::gamepadName(int deviceId)
{
    ensureInit();
    const char *n = SDL_GetGamepadNameForID(static_cast<SDL_JoystickID>(deviceId));
    return n ? QString::fromUtf8(n) : QString();
}
```

- [ ] **Step 3: Add the sources to `CMakeLists.txt` (desktop only)**

Near the iOS/serialport conditionals, add:
```cmake
if(NOT ANDROID AND NOT IOS)
    target_sources(vesc_tool PRIVATE gamepad.cpp gamepad.h)
endif()
```

- [ ] **Step 4: Build to verify the backend compiles**

Run the macOS build command. Expected: `[100%] Built target vesc_tool` (the class compiles and links against SDL3, even though nothing calls it yet).

- [ ] **Step 5: Commit**

```bash
git add gamepad.h gamepad.cpp CMakeLists.txt
git commit -m "Add SDL3 Gamepad backend (interface mirrors old QGamepad usage)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Restore the Preferences "Gamepad" tab UI

**Files:**
- Modify: `preferences.ui`

- [ ] **Step 1: Extract the original Gamepad tab**

View the original UI's gamepad tab markup:
```bash
git show 4570bc1~1:preferences.ui > /tmp/preferences-old.ui
```
In `/tmp/preferences-old.ui`, locate the `<widget class="QWidget" name="tab_2">` whose tab title `<attribute name="title"><string>Gamepad</string></attribute>` — that whole `tab_2` block is the Gamepad tab.

- [ ] **Step 2: Re-insert the tab into the current `preferences.ui`**

In the current `preferences.ui`, find the `QTabWidget` that holds the other preference tabs (the same parent the old `tab_2` lived under). Insert the `tab_2` block back as a child, in its original position.

- [ ] **Step 3: Remove the configure/reset widgets**

From the re-inserted tab, delete the widgets that have no SDL3 equivalent: `jsConf1Button`, `jsConf2Button`, `jsConf3Button`, `jsConf4Button`, and `jsResetConfigButton` (and any layout item/spacer that only existed to position them). Keep everything else: `jsAxis1Bar`–`jsAxis4Bar`, `jsListBox`, `jsScanButton`, `jsConnectButton`, `jsControlTypeBox`, `jseAxisBox`, `jsMinBox`, `jsMaxBox`, `jsErpmMinBox`, `jsErpmMaxBox`, `jsCurrentMinBox`, `jsCurrentMaxBox`, `jsInvertedBox`, `jsBidirectionalBox`, `jsConfigOkBox`, `jsDisp`.

- [ ] **Step 4: Validate the .ui is well-formed XML**

```bash
python3 -c "import xml.etree.ElementTree as ET; ET.parse('preferences.ui'); print('valid XML')"
```
Expected: `valid XML`.

- [ ] **Step 5: Build (AUTOUIC regenerates ui_preferences.h)**

Run the macOS build command. Expected: builds cleanly — the new widgets exist in the generated `ui_preferences.h` but nothing references them yet.

- [ ] **Step 6: Commit**

```bash
git add preferences.ui
git commit -m "Restore Gamepad tab in Preferences UI (minus axis-configure buttons)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Restore the Preferences gamepad logic on the SDL3 backend

**Files:**
- Modify: `preferences.h`
- Modify: `preferences.cpp`

The original code is at `4570bc1~1:preferences.h` / `4570bc1~1:preferences.cpp`. Restore it, replacing `#include <QtGamepad/QGamepad>` with `#include "gamepad.h"`, the `QGamepad *` member type with `Gamepad *`, and `QGamepadManager::instance()->connectedGamepads()/gamepadName()` with `Gamepad::connectedGamepads()/gamepadName()`. Drop the `jsConf*`/reset slots.

- [ ] **Step 1: Restore the header declarations in `preferences.h`**

Inside the class, under an `#ifdef HAS_GAMEPAD` include:
```cpp
#ifdef HAS_GAMEPAD
#include "gamepad.h"
#endif
```
Restore the public methods:
```cpp
    void setUseGamepadControl(bool useControl);
    bool isUsingGamepadControl();
```
Restore the private slots (NOT the reset/config ones):
```cpp
    void on_jsScanButton_clicked();
    void on_jsConnectButton_clicked();
```
Restore the private members:
```cpp
#ifdef HAS_GAMEPAD
    Gamepad *mGamepad;
    bool mUseGamepadControl;
#endif
```

- [ ] **Step 2: Restore the constructor init + settings-load + scan-on-start**

In `preferences.cpp` constructor, restore (from `4570bc1~1`) the `#ifdef HAS_GAMEPAD` init (`mGamepad = nullptr; mUseGamepadControl = false;`) and the `js_*` settings-load block including the scan-on-start that opens the saved gamepad by name — replacing `QGamepadManager::instance()->connectedGamepads()` with `Gamepad::connectedGamepads()`, `QGamepadManager::instance()->gamepadName(g)` with `Gamepad::gamepadName(g)`, and `new QGamepad(g, this)` with `new Gamepad(g, this)`. Do NOT restore the `jsConf1–4Button`/`jsResetConfigButton` `connect(...)` lines or their icon-setting lines.

- [ ] **Step 3: Restore `setUseGamepadControl` / `isUsingGamepadControl`**

Restore both methods verbatim from `4570bc1~1:preferences.cpp` (they are already backend-agnostic — they only touch `mGamepad`/`mUseGamepadControl` and `mVesc->emitMessageDialog`).

- [ ] **Step 4: Restore the `timerSlot` control loop**

Restore the `#ifdef HAS_GAMEPAD` block inside `Preferences::timerSlot()` verbatim from `4570bc1~1:preferences.cpp` (axis bars + axis→`setCurrent`/`setCurrentBrake`/`setDutyCycle`/`setRpm`/`setPos` mapping + the `jsDisp` display + the disconnect cleanup). It calls `mGamepad->axisLeftX()` etc., which the `Gamepad` backend provides unchanged.

- [ ] **Step 5: Restore `on_jsScanButton_clicked` and `on_jsConnectButton_clicked`**

```cpp
void Preferences::on_jsScanButton_clicked()
{
#ifdef HAS_GAMEPAD
    ui->jsListBox->clear();
    auto gamepads = Gamepad::connectedGamepads();
    for (auto g: gamepads) {
        ui->jsListBox->addItem(Gamepad::gamepadName(g), g);
    }
#endif
}
void Preferences::on_jsConnectButton_clicked()
{
#ifdef HAS_GAMEPAD
    QVariant item = ui->jsListBox->currentData();
    if (item.isValid()) {
        if (mGamepad) {
            mGamepad->deleteLater();
        }
        mGamepad = new Gamepad(item.toInt(), this);
    }
#endif
}
```
Do NOT add `on_jsResetConfigButton_clicked`.

- [ ] **Step 6: Restore the `js_*` persistence in `saveSettingsChanged`**

Restore the `#ifdef HAS_GAMEPAD` block in `saveSettingsChanged()` verbatim from `4570bc1~1` (it saves `js_is_configured`, `js_is_inverted`, …, `js_range_max`, and `js_name` from `mGamepad->name()`).

- [ ] **Step 7: Build**

Run the macOS build command. Expected: `[100%] Built target vesc_tool`. If the compiler reports an unresolved `ui->jsResetConfigButton` or `ui->jsConf*Button`, you left a reference to a removed widget — delete it.

- [ ] **Step 8: Commit**

```bash
git add preferences.h preferences.cpp
git commit -m "Restore Preferences gamepad control logic on SDL3 backend

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Restore the MainWindow "Gamepad Control" action

**Files:**
- Modify: `mainwindow.h`
- Modify: `mainwindow.cpp`
- Modify: `mainwindow.ui`

- [ ] **Step 1: Restore the slot declaration in `mainwindow.h`**

Add back (in the private slots section, near the other `on_action*` slots):
```cpp
    void on_actionGamepadControl_triggered(bool checked);
```

- [ ] **Step 2: Restore the slot body + icon in `mainwindow.cpp`**

Add the slot definition (verbatim from `4570bc1~1:mainwindow.cpp`):
```cpp
void MainWindow::on_actionGamepadControl_triggered(bool checked)
{
    mPreferences->setUseGamepadControl(checked);

    if (!mPreferences->isUsingGamepadControl()) {
        ui->actionGamepadControl->setChecked(false);
    }
}
```
And restore the icon line in the constructor (near the other `setIcon` calls):
```cpp
    ui->actionGamepadControl->setIcon(Utility::getIcon("icons/Controller-96.png"));
```

- [ ] **Step 3: Restore the action in `mainwindow.ui`**

From `git show 4570bc1~1:mainwindow.ui`, restore the `<action name="actionGamepadControl">` definition block and its `<addaction name="actionGamepadControl"/>` reference (in the same toolbar/menu it lived in). Validate XML:
```bash
python3 -c "import xml.etree.ElementTree as ET; ET.parse('mainwindow.ui'); print('valid XML')"
```

- [ ] **Step 4: Build and launch**

Run the macOS build command, then:
```bash
open "build/macos/VESC Tool.app"
```
Expected: builds; app launches; the "Gamepad Control" action is present (toolbar/menu) and Preferences shows the Gamepad tab again.

- [ ] **Step 5: Commit**

```bash
git add mainwindow.h mainwindow.cpp mainwindow.ui
git commit -m "Restore Gamepad Control action in MainWindow

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Bundle SDL3 into the local macOS app (and document desktop bundling)

**Files:**
- Modify: `build_macos_cmake.sh`

- [ ] **Step 1: Add an SDL3-bundling step to `build_macos_cmake.sh`**

After the `cmake --build` line, before any packaging, copy the SDL3 dylib into the bundle and fix its install name so the app finds it without a system SDL3:
```bash
APP="build/macos/VESC Tool.app"
SDL3_DYLIB=$(brew --prefix sdl3)/lib/libSDL3.0.dylib
if [ -f "$SDL3_DYLIB" ]; then
    mkdir -p "$APP/Contents/Frameworks"
    cp -L "$SDL3_DYLIB" "$APP/Contents/Frameworks/libSDL3.0.dylib"
    install_name_tool -change "$SDL3_DYLIB" "@executable_path/../Frameworks/libSDL3.0.dylib" \
        "$APP/Contents/MacOS/VESC Tool" 2>/dev/null || true
fi
```
(The exact dylib soname may be `libSDL3.0.dylib`; confirm with `ls $(brew --prefix sdl3)/lib/libSDL3*.dylib`.)

- [ ] **Step 2: Commit**

```bash
git add build_macos_cmake.sh
git commit -m "build: bundle SDL3 dylib into the macOS app

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Add SDL3 to the desktop Qt6 CI release workflows

**Files (on the `ci` worktree `/Users/litao/Developer/vesc_tool-ci`):**
- Modify: `.github/workflows/linux-qt6.yml`
- Modify: `.github/workflows/mac-qt6.yml`, `mac-arm64-qt6.yml`, `mac-universal-qt6.yml`
- Modify: `.github/workflows/win-qt6.yml`

Each gets an SDL3 install step before "Configure", and (mac/win) an SDL3 bundle step before upload. Work in the `ci` worktree; commit + push there; trigger each workflow with `gh workflow run <name> -f vt_ver=qt6-port -f fw_ver=master -f prerelease=true` and iterate to green.

- [ ] **Step 1: Linux — install SDL3 dev**

In `linux-qt6.yml`, add to the existing apt step (or a new step before Configure):
```yaml
      - name: Install SDL3
        run: |
          set -e
          # ubuntu-22.04 has no libsdl3 package; build a pinned release.
          SDL3_VER=3.2.10
          curl -fLs -o /tmp/sdl3.tar.gz https://github.com/libsdl-org/SDL/releases/download/release-${SDL3_VER}/SDL3-${SDL3_VER}.tar.gz
          tar -xzf /tmp/sdl3.tar.gz -C /tmp
          cmake -S /tmp/SDL3-${SDL3_VER} -B /tmp/sdl3-build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
          cmake --build /tmp/sdl3-build --parallel
          sudo cmake --install /tmp/sdl3-build
          sudo ldconfig
```
`find_package(SDL3)` then resolves; `linuxdeploy --plugin qt` bundles the `libSDL3.so` automatically (it's a direct dependency of the binary). Verify in the run that `libSDL3` appears inside the AppImage; if not, copy it into `AppDir/usr/lib` before the linuxdeploy step.

- [ ] **Step 2: macOS (all 3 mac-*-qt6.yml) — install + bundle SDL3**

Add before "Configure":
```yaml
      - name: Install SDL3
        run: brew install sdl3
```
And update the "Package DMG" step to bundle the dylib before `macdeployqt` runs (macdeployqt then signs/relocates it):
```yaml
      - name: Package DMG
        run: |
          APP="build/VESC Tool.app"
          mkdir -p "$APP/Contents/Frameworks"
          SDL3_DYLIB=$(ls $(brew --prefix sdl3)/lib/libSDL3.*.dylib | head -1)
          cp -L "$SDL3_DYLIB" "$APP/Contents/Frameworks/"
          install_name_tool -change "$SDL3_DYLIB" "@executable_path/../Frameworks/$(basename "$SDL3_DYLIB")" "$APP/Contents/MacOS/VESC Tool"
          "$QT_ROOT_DIR/bin/macdeployqt" "$APP" -qmldir=mobile -dmg
          mv "build/VESC Tool.dmg" "VESC_Tool-${PACKAGE_VERSION}-<archsuffix>-qt6.dmg"
```
(Keep each file's existing `<archsuffix>` — `mac-x86_64`, `mac-arm64`, `mac-universal`.)

- [ ] **Step 3: Windows — install + bundle SDL3**

In `win-qt6.yml`, before "Configure":
```yaml
      - name: Install SDL3 (vcpkg)
        shell: pwsh
        run: |
          vcpkg install sdl3:x64-windows
          echo "CMAKE_PREFIX_PATH=$env:VCPKG_INSTALLATION_ROOT\installed\x64-windows" >> $env:GITHUB_ENV
```
In the "Package" step, copy `SDL3.dll` into the staging dir before zipping:
```powershell
          Copy-Item "$env:VCPKG_INSTALLATION_ROOT\installed\x64-windows\bin\SDL3.dll" $stage
```
(If vcpkg's SDL3 port lags, fall back to the SDL3 MSVC release zip from github.com/libsdl-org/SDL/releases and point `CMAKE_PREFIX_PATH` at it.)

- [ ] **Step 4: Push, trigger each desktop workflow, iterate to green**

```bash
cd /Users/litao/Developer/vesc_tool-ci
git add .github/workflows/linux-qt6.yml .github/workflows/mac-qt6.yml \
        .github/workflows/mac-arm64-qt6.yml .github/workflows/mac-universal-qt6.yml \
        .github/workflows/win-qt6.yml
git commit -m "CI: install + bundle SDL3 in desktop Qt6 release workflows

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```
Then trigger each (`gh workflow run linux-qt6.yml ...`, etc.), watch with `gh run watch`, read `gh run view <id> --log-failed` on failure, fix, repeat until all 5 desktop Qt6 workflows are green and their artifacts still upload. Mobile workflows are untouched.

---

## Task 8: Verification note

**Files:**
- Create: `docs/superpowers/plans/2026-05-19-gamepad-sdl3-verification.md` (on `qt6-port`)

- [ ] **Step 1: Write the note**

Record: the local macOS build result; whether a physical gamepad was smoke-tested (axis bars move, control sends commands) or left for the human; the final green desktop CI run IDs with SDL3 bundled; the exact SDL3 versions used per platform; and that the per-axis configure/reset buttons were intentionally dropped.

- [ ] **Step 2: Commit and push**

```bash
cd /Users/litao/Developer/vesc_tool
git add docs/superpowers/plans/2026-05-19-gamepad-sdl3-verification.md
git commit -m "Gamepad: verification note

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Done — Definition of Done

- [ ] The Gamepad tab is back in desktop Preferences (minus the axis-configure buttons), and the "Gamepad Control" action is back in the MainWindow.
- [ ] A connected gamepad's axes drive the selected VESC command (Current/Duty/ERPM/Position) when control is enabled (human smoke test).
- [ ] macOS/Linux/Windows builds link SDL3 and bundle its runtime; the 5 desktop Qt6 CI workflows are green; mobile workflows unchanged.
- [ ] No mobile or Qt5-upstream changes.

**This restores the one deferred item from the Qt6 port.** Gamepad is back on desktop via SDL3.
