# Qt6 Port — Phase 3 Verification (Linux + Windows)

**Date:** 2026-05-19
**Branch:** `qt6-port`

## Result

Phase 3 is complete. VESC Tool builds on **Linux (gcc)** and **Windows (MSVC)** with
Qt 6.8.3 + CMake, verified by GitHub Actions CI.

- **Final green CI run:** [26122008360](https://github.com/darwinbeing/vesc_tool/actions/runs/26122008360)
  - `linux` job ✅ (~6 min)
  - `windows` job ✅ (~8 min)
- macOS build was re-verified locally after the Task 1 CMake changes (`[100%] Built target vesc_tool`).

## What was done

- **Task 1** — `CMakeLists.txt` made platform-aware: `HAS_POS` gated to `if(NOT WIN32)`
  (matches the original `vesc_tool.pro`'s `!win32`); Windows block adds
  `_USE_MATH_DEFINES`, `NOMINMAX`, and `WIN32_EXECUTABLE ON`.
- **Task 2** — added `.github/workflows/build.yml`: a `linux` job (ubuntu-22.04, gcc)
  and a `windows` job (windows-2022, MSVC), each installing Qt 6.8.3 via
  `jurplel/install-qt-action` and building with CMake + Ninja.
- **Task 3** — Linux job green (2 push→CI rounds).
- **Task 4** — Windows job green (2 push→CI rounds).

## Linux fixes

- `bleuart.cpp` — `QLowEnergyController::createCentral(QBluetoothAddress, ...)` no longer
  exists in Qt6; the non-macOS branch now builds a `QBluetoothDeviceInfo` first, mirroring
  the macOS branch. (This break could not surface on macOS, which compiles the other branch.)

No missing-include fixes were needed — gcc accepted what clang did for this codebase.

## Windows / MSVC fixes

- **Packed structs** — GCC's `__attribute__((packed))` is not understood by MSVC. Added
  `esp32/packed_struct.h` with portable macros: `PACKED` (attribute on GCC/Clang, empty on
  MSVC) and `PACKED_STRUCT_BEGIN`/`PACKED_STRUCT_END` (`#pragma pack(push,1)`/`pop` on MSVC,
  empty elsewhere). Applied across `protocol.h` (and, for consistency, `serial_comm_prv.h`,
  `sip.h`, `protocol_spi.c`). Wire layout is byte-identical on all three compilers; packed
  enums are never used as struct members (members use fixed-width `uintN_t`).
- **Designated initializers** in `ESP_LOADER_CONNECT_DEFAULT()` — converted to positional
  initializers (MSVC rejects C++ designated initializers below C++20; Qt6 builds at C++17).
- **Weak symbols** — GCC's `__attribute__((weak))` fallback for `loader_port_debug_print()`
  guarded with `#if !defined(_MSC_VER)`; the port layer always supplies the strong definition.

All Windows fixes are `_MSC_VER`-guarded, so gcc/clang behavior is unchanged — the Linux
job stayed green throughout Task 4.

## Notes for later

- The CI workflow has **no macOS job** — macOS is verified locally during development.
  A macOS CI job is worth adding in a future maintenance pass for full coverage.
- GitHub Actions emits Node-version deprecation warnings for `actions/checkout@v4` and
  `ilammy/msvc-dev-cmd@v1` — informational only; bump the action versions when convenient.
- Qt6 deprecation warnings (`AA_UseHighDpiPixmaps`, `AA_EnableHighDpiScaling`, `qAsConst`)
  remain across all platforms — non-fatal, intentionally left.

**Next:** Phase 4 (Android + iOS), including the `androidextras` → `QJniObject` migration.
