# Phase 1 — macOS CMake Build Verification Record

Date: 2026-05-19
Branch: `qt6-port`
Plan: `docs/superpowers/plans/2026-05-19-qt6-port-phase1-cmake.md` — Task 9

## Environment

- Qt 5.15.2, CMake prefix `/Users/litao/Qt5.15.2/5.15.2/clang_64`
- CMake 4.1.2, AppleClang 16.0.0
- macOS (Darwin 24.1.0), build architecture: x86_64
- Configure/build:
  ```
  cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="/Users/litao/Qt5.15.2/5.15.2/clang_64" -DCMAKE_BUILD_TYPE=Release
  cmake --build build/macos --parallel
  ```

## Step 1 — Full build: PASS

The build completed with `[100%] Built target vesc_tool` and produced
`build/macos/VESC Tool.app` (`Contents/MacOS/VESC Tool`, ~22 MB Mach-O x86_64).

Two CMakeLists.txt fixes were required (commit `79a2e08`); no `.cpp`/`.h`/`.ui`/`.qrc`
source files were modified.

- **QCodeEditor headers not moc'd.** The first link failed with missing vtables
  for QCodeEditor `Q_OBJECT` classes (`QLanguage`, `QCXXHighlighter`, etc.).
  AUTOMOC only processes a header listed as a target source or paired with a
  same-named `.cpp` in the same directory. QCodeEditor's headers live in
  `include/internal/*.hpp` while the `.cpp` files live in `src/internal/`, so
  AUTOMOC could not pair them. The original `QCodeEditor/qcodeeditor.pri`
  declared every header in `HEADERS`; the CMake port had dropped them. Fix:
  added the 21 `include/internal/*.hpp` headers to `target_sources` in
  `QCodeEditor/CMakeLists.txt`.

- **`datatypes.h` not moc'd.** After the QCodeEditor fix, the link failed with
  missing `staticMetaObject` symbols for `Q_GADGET` types (`MC_VALUES`,
  `FILE_LIST_ENTRY`, `IO_BOARD_VALUES`, `ENCODER_DETECT_RES`, `GNSS_DATA`, ...).
  These are declared in `datatypes.h`, which has no companion `.cpp`, so AUTOMOC
  never processed it. `datatypes.h` was in the `vesc_tool.pro` `HEADERS` list.
  Fix: added `datatypes.h` to the root `qt_add_executable` sources in the
  top-level `CMakeLists.txt`.

A clean from-scratch rebuild after both fixes succeeded.

## Step 2 — GUI smoke test: PENDING (human)

The interactive GUI smoke test (`open "build/macos/VESC Tool.app"`, verifying
the main window, page list, Preferences dialog, and QML-backed pages) requires
a human operator and has NOT been performed. It is left as a pending manual
action.

As a substitute, the binary was launched directly
(`build/macos/VESC Tool.app/Contents/MacOS/VESC Tool`) for ~12 seconds and its
stdout/stderr was captured. Observations:

- The app started and initialized without crashing.
- Resources loaded: `Loaded config resource`, `Loaded package archive resource`.
- QML panels loaded from the `qrc:/mobile/` and `qrc:/res/qml/` resources.
- **No missing-QML-module, missing-plugin, or fatal QML errors.**
- Benign messages only:
  - QML binding-loop warnings and one deprecated-`onFoo`-syntax notice in the
    bundled `.qml` files (pre-existing QML content, unrelated to the build system).
  - `QFSFileEngine::open: No file name specified` and `Param group "gpd" not
    found.` — benign runtime messages with no hardware connected.
  - macOS `+[IMKClient subclass]` input-method messages — standard OS noise.

## Step 3 — qmake baseline diff: SKIPPED

`qmake` is not installed on this machine, so the qmake reference build could not
be produced and no behavior diff against it was possible. Verification relies on
the Step 2 startup-output check; the full interactive comparison is part of the
pending human smoke test.

## Summary

- Build result: PASS — `build/macos/VESC Tool.app` produced.
- CMakeLists fixes: commit `79a2e08` (QCodeEditor headers + `datatypes.h`).
- Startup console: clean; no QML/plugin errors.
- qmake baseline diff: skipped (qmake unavailable).
- Interactive GUI smoke test: pending human action.
