# SDL3 Gamepad Support — Verification

**Date:** 2026-05-19
**Branches:** code on `qt6-port`; desktop CI changes on `ci`

## Result

Desktop gamepad control is restored on the Qt6 codebase using SDL3. The feature
builds locally on macOS, all five desktop Qt6 release workflows are green with
SDL3 linked + bundled, and mobile / Qt5-upstream are untouched.

## What was done

- **`gamepad.h`/`gamepad.cpp`** (new) — SDL3 (`SDL_Gamepad`) backend, a `QObject`
  whose interface mirrors the old `QGamepad`/`QGamepadManager` calls
  (`axisLeftX/Y`, `axisRightX/Y`, `isConnected`, `name`, static
  `connectedGamepads`/`gamepadName`). Compiled against SDL3 3.4.8 with **no API
  adjustments**.
- **Preferences** — the "Gamepad" tab and the 100 ms axis→command control loop
  (`setCurrent`/`setCurrentBrake`/`setDutyCycle`/`setRpm`/`setPos`) restored from
  git `4570bc1~1`, repointed at the SDL3 backend.
- **MainWindow** — the "Gamepad Control" toggle action restored.
- **CMake** — `find_package(SDL3)`, `SDL3::SDL3` link, and `HAS_GAMEPAD` define,
  all guarded `if(NOT ANDROID AND NOT IOS)`.
- **Packaging** — `build_macos_cmake.sh` bundles `libSDL3.0.dylib` into the
  `.app`; the 5 desktop CI workflows install SDL3 and bundle its runtime.

## Full fidelity (updated)

Initially the per-axis "configure" buttons (`jsConf1–4`) and "reset config"
button were dropped (Qt6 has no `QGamepadManager::configureAxis()`). Per the
user's "this is a port — keep it consistent with the original" directive, they
were **fully restored**: the SDL3 `Gamepad` backend now implements equivalent
axis remapping — a logical→physical axis override map applied by the axis
getters, `startConfigureAxis(k)` (click, then move a control → the next deflected
raw joystick axis binds, matching the old UX), and `resetConfiguration()`.
Bindings persist as `js_axis_map`. The entire original Gamepad tab is restored
1:1. Verified building on all 4 platforms (run 26140928453).

## CI verification (all green)

Desktop Qt6 workflows on `ci`, each installing + bundling SDL3:

| Workflow | SDL3 on the runner | Bundled into artifact |
|---|---|---|
| `linux-qt6` | built from SDL3 3.2.10 source → `/usr/local` | `libSDL3.so` via linuxdeploy |
| `mac-x86_64-qt6` | SDL3 3.2.10 built for x86_64 | `libSDL3.0.dylib` in `Contents/Frameworks` |
| `mac-arm64-qt6` | SDL3 3.2.10 built for arm64 | `libSDL3.*.dylib` in `Contents/Frameworks` |
| `mac-universal-qt6` | SDL3 3.2.10 built universal | `libSDL3.*.dylib` in `Contents/Frameworks` |
| `win-qt6` | SDL3 3.2.10 VC dev release | `SDL3.dll` next to the exe |

(Local dev build used Homebrew SDL3 3.4.8; CI pins 3.2.10 for reproducibility.)

## Verification scope

- Local macOS build links SDL3 and produces a runnable `.app` with the Gamepad
  tab + "Gamepad Control" action present — verified.
- All 5 desktop Qt6 CI workflows green with SDL3 bundled — verified.
- **Runtime control NOT yet verified on hardware** — the human must do the smoke
  test: plug in a gamepad → Preferences ▸ Gamepad ▸ Scan/Connect → axis bars move
  → enable "Gamepad Control" → the selected axis drives the chosen VESC command.

## Out of scope (unchanged)

- Mobile gamepad (would need a new QML screen).
- Button mappings / deadzone / multi-axis (possible future improvements).
- Qt5 upstream pipeline (still uses QtGamepad).

**This restores the one item deferred from the Qt6 port.**
