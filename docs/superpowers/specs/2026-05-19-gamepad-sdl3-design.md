# Gamepad Support via SDL3 — Design

**Date:** 2026-05-19
**Status:** Approved design
**Branch:** code on `qt6-port`; desktop CI install steps on `ci`

## Goal

Restore VESC Tool's gamepad control feature (removed in the Qt6 port because
Qt6 dropped QtGamepad) using **SDL3** as the backend. Faithful restore of the
original desktop behavior — no redesign.

## Constraints & Decisions

- **Backend:** SDL3 (`SDL_Gamepad` API).
- **Platforms:** desktop only — macOS, Linux, Windows. Matches the original
  (`HAS_GAMEPAD = !ios && !android`) and the UI architecture: the gamepad UI is
  part of the desktop QWidgets `Preferences` dialog; the mobile (`USE_MOBILE`)
  QML UI has no gamepad screen and is unchanged.
- **Scope:** faithful restore of the original Preferences "Gamepad" tab and the
  axis→command control loop.
- **Full fidelity (updated 2026-05-19):** the original per-axis "configure"
  buttons (`jsConf1–4`) and "reset config" button are **restored**, including
  their behavior. The original used `QGamepadManager::configureAxis()` (click,
  then move a physical control to bind it to a logical axis). SDL3 has no such
  call, so the SDL3 backend implements equivalent **axis remapping** itself: a
  logical→physical axis override map applied by the axis getters,
  `startConfigureAxis(k)` (snapshot raw axes, then the poll loop binds the next
  deflected raw joystick axis), and `resetConfiguration()` (clear the map).
  Bindings persist in settings. The whole Gamepad tab is restored 1:1.

## Architecture

```
SDL3 gamepad subsystem
        │  (poll axes, enumerate/open devices, connect events)
        ▼
Gamepad backend  (NEW: gamepad.h/.cpp, QObject)
        │  axisLeftX/Y(), axisRightX/Y()  [normalized -1..1], device list, isConnected()
        ▼
Preferences "Gamepad" tab  (restored timerSlot control loop, 100 ms)
        │  selected axis → calibrate (min/max, invert, bidirectional) → control type
        ▼
mVesc->commands()->setCurrent / setCurrentBrake / setDutyCycle / setRpm / setPos
        ▲
MainWindow actionGamepadControl  (toggles mUseGamepadControl on/off)
```

### Components

- **NEW `gamepad.h` / `gamepad.cpp`** — a focused `QObject` wrapping SDL3:
  - `init()` — `SDL_InitSubSystem(SDL_INIT_GAMEPAD)`.
  - `connectedGamepads()` / `gamepadName(id)` — enumerate via
    `SDL_GetGamepads` for the device list.
  - `open(id)` / `close()` — `SDL_OpenGamepad`.
  - `axisLeftX/Y()`, `axisRightX/Y()` — read `SDL_GetGamepadAxis` and normalize
    the int16 range to −1.0..1.0 (matching the old `QGamepad::axisLeftX()` etc.).
  - `isConnected()` — track via SDL connect/disconnect events.
  - A `QTimer` (or pump in the existing 100 ms Preferences timer) calls
    `SDL_UpdateGamepads` so values are fresh.
  This is the only new code. Its interface mirrors the methods the old
  `timerSlot` already called, so the control logic returns unchanged.

- **`preferences.h` / `preferences.cpp`** — restore (from git, commit
  `4570bc1~1`): the `mGamepad`/`mUseGamepadControl` members (typed to the new
  backend), `setUseGamepadControl()`, `isUsingGamepadControl()`, the scan/
  connect/list slots, the settings persistence (`js_*`), and the `timerSlot`
  axis→command mapping. Replace `QGamepad`/`QGamepadManager` calls with the new
  backend. Drop the `jsConf1–4`/reset-config slots.

- **`preferences.ui`** — restore the "Gamepad" tab and its widgets (axis bars
  `jsAxis1–4Bar`, `jsListBox`, `jsScanButton`, `jsConnectButton`,
  `jsControlTypeBox`, `jseAxisBox`, `jsMinBox`/`jsMaxBox`, `jsErpm*`,
  `jsCurrent*`, `jsInvertedBox`, `jsBidirectionalBox`, `jsDisp`), **minus** the
  `jsConf1–4Button` and `jsResetConfigButton` widgets.

- **`mainwindow.h` / `.cpp` / `.ui`** — restore `on_actionGamepadControl_triggered`
  and the `actionGamepadControl` action + controller icon.

## Build integration

- **`CMakeLists.txt`:**
  - `find_package(SDL3 REQUIRED)` and link `SDL3::SDL3` — guarded to desktop
    only (`if(NOT ANDROID AND NOT IOS)`).
  - Re-add `HAS_GAMEPAD` to `target_compile_definitions` on desktop only (same
    guard). All restored gamepad code stays under `#ifdef HAS_GAMEPAD`.
  - Bundle the SDL3 runtime into the app package: SDL3 is not a Qt library, so
    `macdeployqt`/`windeployqt` won't copy it — the desktop packaging steps copy
    the SDL3 dylib/dll/.so into the bundle and fix rpaths as needed.

## CI integration (Phase 5 desktop release workflows on `ci`)

The three desktop `*-qt6.yml` workflows (`linux-qt6`, `mac-*-qt6`, `win-qt6`)
get an SDL3 install step before Configure:
- **Linux:** install SDL3 (apt if available on ubuntu-22.04, else build/fetch a
  release) so `find_package(SDL3)` resolves; ensure the AppImage bundles it.
- **macOS:** `brew install sdl3`; macdeployqt step copies the SDL3 dylib into the
  `.app` and fixes the install name.
- **Windows:** fetch the SDL3 MSVC release (or vcpkg); copy `SDL3.dll` next to
  the exe before zipping.
Mobile workflows (`android-qt6`, `ios-qt6`) are untouched. The non-CI Qt5
upstream pipeline is untouched (Qt5 still has QtGamepad).

## Error handling

- No gamepad connected when enabling control → the existing "No recognized
  gamepad is connected" message dialog (restored).
- SDL3 init failure → log and disable the feature gracefully (tab shows no
  devices); never crash.

## Verification

No unit-test suite (consistent with the project). Bar:
- Desktop builds compile/link with SDL3 and the CI desktop jobs stay green with
  SDL3 bundled into each artifact.
- Manual smoke test (human): plug in a gamepad → the axis bars move → toggling
  "Gamepad Control" sends the expected command to a connected VESC.

## Out of scope

- Mobile (Android/iOS) gamepad support — would require a brand-new QML screen.
- Button mappings, multiple simultaneous axes, deadzone tuning — possible future
  improvements, not part of this faithful restore.
- The Qt5 upstream pipeline (still uses QtGamepad; not ours to change).
