# Qt6 Port — Phase 3: Linux + Windows Builds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make VESC Tool build on **Linux** and **Windows (MSVC)** with Qt 6.8 + CMake, verified by a new GitHub Actions CI workflow.

**Architecture:** The macOS Qt6/CMake build works (Phases 1–2). Phase 3 makes the `CMakeLists.txt` platform-aware (the feature defines and platform blocks are currently macOS-shaped), adds a GitHub Actions workflow that builds Linux + Windows jobs on Qt 6.8.3, then iterates on the compiler errors each platform's CI run reports until both jobs are green.

**Tech Stack:** Qt 6.8.3, CMake ≥ 3.21, GitHub Actions, Linux (gcc), Windows (MSVC), C++.

**Verification model:** This is a macOS development machine — Linux/Windows cannot be built locally. **Verification is GitHub Actions CI: a task is done when its CI job is green.** Tasks 3–4 are discovery-driven: push, read the CI failure logs with `gh run view --log-failed`, fix, push again, repeat.

**Branch:** continue on `qt6-port`. Phase 3 **pushes `qt6-port` to `origin`** (`github.com:darwinbeing/vesc_tool`) — this is required for CI and is implied by choosing CI verification. GitHub Actions must be enabled on the repo.

**Prereq:** the `gh` CLI must be authenticated (`gh auth status`). If not, the implementer stops and asks the human to run `gh auth login`.

---

## Task 1: Make CMakeLists.txt platform-aware

**Files:**
- Modify: `CMakeLists.txt`

The Phase 1/2 `CMakeLists.txt` defines `HAS_BLUETOOTH`/`HAS_POS`/`HAS_SERIALPORT` unconditionally and has only a macOS bundle block. The original `vesc_tool.pro` gated `HAS_POS` to non-Windows and set `_USE_MATH_DEFINES` on Windows.

- [ ] **Step 1: Make the feature defines platform-conditional**

In `CMakeLists.txt`, in the `target_compile_definitions(vesc_tool PRIVATE ...)` block, keep `HAS_BLUETOOTH` and `HAS_SERIALPORT` unconditional (all desktop platforms), and **remove the `HAS_POS` line** from that block. After the block, add:
```cmake
# Positioning is not used on Windows (matches the original vesc_tool.pro: !win32).
if(NOT WIN32)
    target_compile_definitions(vesc_tool PRIVATE HAS_POS)
endif()
```

- [ ] **Step 2: Add Windows compile settings**

After the conditional above, add a Windows block (mirrors `vesc_tool.pro`'s `win32: DEFINES += _USE_MATH_DEFINES`, plus `NOMINMAX` to stop `<windows.h>` clobbering `std::min`/`std::max`):
```cmake
if(WIN32)
    target_compile_definitions(vesc_tool PRIVATE _USE_MATH_DEFINES NOMINMAX)
    set_target_properties(vesc_tool PROPERTIES WIN32_EXECUTABLE ON)
endif()
```
`WIN32_EXECUTABLE ON` makes it a GUI-subsystem app (no console window). (`qt_add_executable` usually sets this already; setting it explicitly is harmless and clear.)

- [ ] **Step 3: Re-verify the macOS build still configures and builds**

The platform conditionals must not regress macOS. Run:
```bash
cd /Users/litao/Developer/vesc_tool
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="/Users/litao/Qt/6.8.3/macos" -DCMAKE_BUILD_TYPE=Debug
cmake --build build/macos --parallel
```
Expected: `[100%] Built target vesc_tool`. On macOS, `NOT WIN32` is true so `HAS_POS` is still defined — no behavior change.

- [ ] **Step 4: Commit**

```bash
git add CMakeLists.txt
git commit -m "CMake: make feature defines and platform settings cross-platform

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Add the GitHub Actions CI workflow

**Files:**
- Create: `.github/workflows/build.yml`

A workflow with two jobs — Linux and Windows — each installing Qt 6.8.3 and building with CMake.

- [ ] **Step 1: Create `.github/workflows/build.yml`**

```yaml
name: Build

on:
  push:
    branches: [qt6-port, master]
  pull_request:
  workflow_dispatch:

jobs:
  linux:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - name: Install Linux build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential ninja-build \
            libgl1-mesa-dev libxkbcommon-dev libxkbcommon-x11-dev \
            libbluetooth-dev '^libxcb.*-dev' libx11-xcb-dev \
            libglu1-mesa-dev libxrender-dev libxi-dev
      - name: Install Qt 6.8.3
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: linux
          target: desktop
          arch: linux_gcc_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
      - name: Configure
        run: cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
      - name: Build
        run: cmake --build build --parallel

  windows:
    runs-on: windows-2022
    steps:
      - uses: actions/checkout@v4
      - name: Install Qt 6.8.3
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: windows
          target: desktop
          arch: win64_msvc2022_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
      - name: Enable MSVC environment
        uses: ilammy/msvc-dev-cmd@v1
      - name: Configure
        run: cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
      - name: Build
        run: cmake --build build --parallel
```

- [ ] **Step 2: Confirm `gh` is authenticated**

```bash
gh auth status
```
If not authenticated, STOP and ask the human to run `gh auth login`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/build.yml
git commit -m "CI: add GitHub Actions Linux + Windows build workflow

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Get the Linux CI job green

**Files:** discovery-driven — whatever the Linux build flags (`CMakeLists.txt` files and/or `.cpp`/`.h` source).

- [ ] **Step 1: Push the branch and trigger CI**

```bash
cd /Users/litao/Developer/vesc_tool
git push -u origin qt6-port
```
The push triggers the workflow. Get the run id:
```bash
gh run list --branch qt6-port --workflow build.yml --limit 1
```

- [ ] **Step 2: Watch the Linux job**

```bash
gh run watch <run-id>
```
When it finishes, if the `linux` job failed, read its failure log:
```bash
gh run view <run-id> --log-failed
```

- [ ] **Step 3: Fix the Linux build errors**

Linux uses gcc, which differs from macOS clang. Expect breaks such as: missing `#include`s that clang allowed transitively (e.g. `<cstdint>`, `<memory>`, `<algorithm>`), stricter template diagnostics, `char`-signedness assumptions, X11/`Bluetooth` headers. Fix each in the relevant source or `CMakeLists.txt`, keeping changes minimal and behavior-preserving. If a fix is platform-specific, guard it (`#if defined(Q_OS_LINUX)` / CMake `if(UNIX AND NOT APPLE)`), but most missing-include fixes are universal and need no guard.

- [ ] **Step 4: Commit and re-push, iterate**

```bash
git add -A
git commit -m "Qt6: fix Linux build errors

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```
Repeat Steps 2–4 until the `linux` CI job is green. (The `windows` job may still be failing — that is Task 4.)

- [ ] **Step 5: Confirm**

`gh run view <run-id>` shows the `linux` job ✅. Do not proceed to Task 4 until Linux is green.

---

## Task 4: Get the Windows (MSVC) CI job green

**Files:** discovery-driven — whatever the Windows build flags.

- [ ] **Step 1: Read the Windows job failure log**

For the latest run:
```bash
gh run list --branch qt6-port --workflow build.yml --limit 1
gh run view <run-id> --log-failed
```

- [ ] **Step 2: Fix the Windows/MSVC build errors**

MSVC is the strictest of the three compilers — expect the most breaks. Common categories and fixes:
- **`min`/`max` macros** from `<windows.h>` — already mitigated by `NOMINMAX` (Task 1); if a site still breaks, wrap the call: `(std::min)(a, b)`.
- **Missing includes** MSVC requires that gcc/clang allowed transitively.
- **`M_PI` and friends** — covered by `_USE_MATH_DEFINES` (Task 1); ensure `<cmath>` is included where used.
- **`ssize_t`**, POSIX-only functions, `__attribute__`, `#include <unistd.h>` — guard with `#ifdef Q_OS_WIN` / provide MSVC equivalents.
- **Narrowing conversions / `4-byte` warnings escalated to errors**, `and`/`or` keyword usage, anonymous struct extensions.
- **`/bigobj`** — if MSVC reports "too many sections", add to `CMakeLists.txt`: `if(MSVC) target_compile_options(vesc_tool PRIVATE /bigobj) endif()`.
- **Path/encoding**: source files with non-ASCII content may need `/utf-8` — `if(MSVC) target_compile_options(vesc_tool PRIVATE /utf-8) endif()`.
Keep each fix minimal; guard genuinely Windows-specific changes with `#ifdef Q_OS_WIN` or CMake `if(MSVC)` / `if(WIN32)` so Linux/macOS are unaffected.

- [ ] **Step 3: Commit and re-push, iterate**

```bash
git add -A
git commit -m "Qt6: fix Windows MSVC build errors

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```
Repeat Steps 1–3 until the `windows` CI job is green.

- [ ] **Step 4: Confirm both jobs green**

`gh run view <run-id>` shows **both** `linux` and `windows` jobs ✅.

---

## Task 5: Verification note

**Files:**
- Create: `docs/superpowers/plans/2026-05-19-phase3-verification.md`

- [ ] **Step 1: Write the verification note**

Record: the final green CI run id/URL, the categories of Linux and Windows fixes made, anything platform-specific worth noting for Phase 4, and that macOS still builds (Task 1 Step 3 confirmed it; the workflow does not run a macOS job — note whether one should be added later).

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-05-19-phase3-verification.md
git commit -m "Phase 3: verify Linux + Windows CI builds

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase 3 Done — Definition of Done

- [ ] The GitHub Actions `build.yml` workflow exists and both the `linux` and `windows` jobs are green on `qt6-port`.
- [ ] `CMakeLists.txt` is platform-aware (feature defines and Windows settings conditional); the macOS build is unaffected.
- [ ] All build fixes are minimal and, where platform-specific, guarded so no platform regresses.

**Next:** Phase 4 (Android + iOS) gets its own plan — it includes the `androidextras` → `QJniObject` migration.
