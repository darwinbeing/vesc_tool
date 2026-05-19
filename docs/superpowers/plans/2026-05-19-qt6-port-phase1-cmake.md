# Qt6 Port — Phase 1: qmake → CMake Migration (still Qt5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the qmake build (`vesc_tool.pro` + 11 `.pri` files) of VESC Tool with an equivalent CMake build, still compiling against Qt5, producing a working macOS `VESC Tool.app` identical in behavior to the current build.

**Architecture:** A single top-level `CMakeLists.txt` defines one executable target via `qt_add_executable`. Each former `.pri` becomes a subdirectory `CMakeLists.txt` pulled in with `add_subdirectory`, contributing its sources to the executable via `target_sources` — mirroring the current flat structure with no new library boundaries. The `CMakeLists.txt` is written Qt-version-agnostic from the start (`find_package(QT NAMES Qt6 Qt5)` + versionless `qt_*` commands) so Phase 2 is mostly an SDK swap. This phase keeps every Qt5 feature, including Gamepad — gamepad removal belongs to Phase 2.

**Tech Stack:** CMake ≥ 3.21, Qt 5.15 (versionless `qt_*` commands require 5.15), C++11, macOS/clang.

**Verification model:** This is a build-system migration with no unit-test suite. The "test" for each task is a CMake configure and/or build command with a defined expected outcome. Intermediate tasks (before the executable has all its sources) verify that `cmake` *configures* without error; the full link/build is verified in Task 9.

**Prerequisite — locate Qt5:** Before Task 1, find the Qt5 installation and note its prefix (the directory containing `lib/cmake/Qt5`). If Qt5 is not installed, install Qt 5.15.2 (Qt online installer or `aqtinstall`) before proceeding. Export it for every `cmake` invocation in this plan:
```bash
export CMAKE_PREFIX_PATH="/path/to/Qt/5.15.2/clang_64"
```
If the installed Qt5 is older than 5.15, stop and report — versionless `qt_*` commands are unavailable and this plan's CMake code must be adjusted to `qt5_*` macros.

---

## Task 1: Create branch and top-level CMakeLists.txt skeleton

**Files:**
- Create: `CMakeLists.txt`

- [ ] **Step 1: Create the port branch from a clean master**

```bash
git checkout master
git checkout -b qt6-port
git status   # the untracked .orig/.rej files remain untracked — do not touch them
```

- [ ] **Step 2: Write the top-level `CMakeLists.txt`**

Create `CMakeLists.txt` with this content. It declares the project, finds Qt version-agnostically, sets the auto-tools, declares the executable with only the root-level sources/headers/forms, and defines the build-feature macros for a macOS desktop build.

```cmake
cmake_minimum_required(VERSION 3.21)

# --- Version (mirrors vesc_tool.pro) ---
set(VT_VERSION 7.00)
set(VT_INTRO_VERSION 1)
set(VT_CONFIG_VERSION 4)
set(VT_IS_TEST_VERSION 0)
execute_process(
    COMMAND git rev-parse --short=8 HEAD
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE VT_GIT_COMMIT
    OUTPUT_STRIP_TRAILING_WHITESPACE)

project(vesc_tool VERSION 7.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# --- Qt (version-agnostic: prefers Qt6 if present, falls back to Qt5) ---
find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS
    Core Gui Widgets Network Quick QuickControls2 QuickWidgets Svg
    PrintSupport SerialPort Bluetooth Positioning Gamepad)

# --- Executable: root-level sources only for now; subdirs add the rest ---
qt_add_executable(vesc_tool
    main.cpp
    bleuartdummy.cpp
    codeloader.cpp
    mainwindow.cpp
    boardsetupwindow.cpp
    packet.cpp
    preferences.cpp
    tcphub.cpp
    udpserversimple.cpp
    vbytearray.cpp
    commands.cpp
    configparams.cpp
    configparam.cpp
    vescinterface.cpp
    parametereditor.cpp
    digitalfiltering.cpp
    setupwizardapp.cpp
    setupwizardmotor.cpp
    startupwizard.cpp
    utility.cpp
    tcpserversimple.cpp
    hexfile.cpp
    bleuart.cpp
    systemcommandexecutor.h
    mainwindow.ui
    boardsetupwindow.ui
    parametereditor.ui
    preferences.ui
)

# --- Build-feature macros (macOS desktop; mirrors vesc_tool.pro DEFINES) ---
target_compile_definitions(vesc_tool PRIVATE
    VT_VERSION=${VT_VERSION}
    VT_INTRO_VERSION=${VT_INTRO_VERSION}
    VT_CONFIG_VERSION=${VT_CONFIG_VERSION}
    VT_IS_TEST_VERSION=${VT_IS_TEST_VERSION}
    VT_GIT_COMMIT=${VT_GIT_COMMIT}
    HAS_BLUETOOTH
    HAS_POS
    HAS_SERIALPORT
    HAS_GAMEPAD
    VER_NEUTRAL
)

target_link_libraries(vesc_tool PRIVATE
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::GuiPrivate
    Qt${QT_VERSION_MAJOR}::Widgets
    Qt${QT_VERSION_MAJOR}::Network
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::QuickControls2
    Qt${QT_VERSION_MAJOR}::QuickWidgets
    Qt${QT_VERSION_MAJOR}::Svg
    Qt${QT_VERSION_MAJOR}::PrintSupport
    Qt${QT_VERSION_MAJOR}::SerialPort
    Qt${QT_VERSION_MAJOR}::Bluetooth
    Qt${QT_VERSION_MAJOR}::Positioning
    Qt${QT_VERSION_MAJOR}::Gamepad
)

# Subdirectory source contributions (added in later tasks):
# add_subdirectory(pages)
# add_subdirectory(widgets)
# add_subdirectory(mobile)
# add_subdirectory(map)
# add_subdirectory(lzokay)
# add_subdirectory(heatshrink)
# add_subdirectory(QCodeEditor)
# add_subdirectory(esp32)
# add_subdirectory(display_tool)
# add_subdirectory(qmarkdowntextedit)
# add_subdirectory(maddy)
# add_subdirectory(minimp3)
```

- [ ] **Step 3: Verify CMake configures**

Run:
```bash
cmake -S . -B build-cmake -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"
```
Expected: configuration completes with `-- Configuring done` and `-- Generating done`. It is expected that a *build* would fail to link at this point (subdir sources missing) — do not build yet.

- [ ] **Step 4: Commit**

```bash
git add CMakeLists.txt
git commit -m "Add CMake skeleton for vesc_tool (Qt-version-agnostic)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: pages/ subdirectory CMakeLists

**Files:**
- Create: `pages/CMakeLists.txt`
- Modify: `CMakeLists.txt` (uncomment `add_subdirectory(pages)`)

- [ ] **Step 1: Create `pages/CMakeLists.txt`**

This contributes the `pages/` sources, headers, and `.ui` forms to the `vesc_tool` target. Use the file lists from `pages/pages.pri` verbatim. `target_sources` with `CMAKE_CURRENT_SOURCE_DIR`-relative paths:

```cmake
target_sources(vesc_tool PRIVATE
    pageapppas.cpp pageapppas.h pageapppas.ui
    pagebms.cpp pagebms.h pagebms.ui
    pagecananalyzer.cpp pagecananalyzer.h pagecananalyzer.ui
    pageconnection.cpp pageconnection.h pageconnection.ui
    pagecustomconfig.cpp pagecustomconfig.h pagecustomconfig.ui
    pagedisplaytool.cpp pagedisplaytool.h pagedisplaytool.ui
    pageespprog.cpp pageespprog.h pageespprog.ui
    pagelisp.cpp pagelisp.h pagelisp.ui
    pagemotor.cpp pagemotor.h pagemotor.ui
    pagedebugprint.cpp pagedebugprint.h pagedebugprint.ui
    pagebldc.cpp pagebldc.h pagebldc.ui
    pageappgeneral.cpp pageappgeneral.h pageappgeneral.ui
    pagedc.cpp pagedc.h pagedc.ui
    pagefoc.cpp pagefoc.h pagefoc.ui
    pagecontrollers.cpp pagecontrollers.h pagecontrollers.ui
    pageappppm.cpp pageappppm.h pageappppm.ui
    pageappadc.cpp pageappadc.h pageappadc.ui
    pageappuart.cpp pageappuart.h pageappuart.ui
    pageappnunchuk.cpp pageappnunchuk.h pageappnunchuk.ui
    pageappnrf.cpp pageappnrf.h pageappnrf.ui
    pagemotorcomparison.cpp pagemotorcomparison.h pagemotorcomparison.ui
    pagescripting.cpp pagescripting.h pagescripting.ui
    pageterminal.cpp pageterminal.h pageterminal.ui
    pagefirmware.cpp pagefirmware.h pagefirmware.ui
    pagertdata.cpp pagertdata.h pagertdata.ui
    pagesampleddata.cpp pagesampleddata.h pagesampleddata.ui
    pagevescpackage.cpp pagevescpackage.h pagevescpackage.ui
    pagewelcome.cpp pagewelcome.h pagewelcome.ui
    pagemotorsettings.cpp pagemotorsettings.h pagemotorsettings.ui
    pageappsettings.cpp pageappsettings.h pageappsettings.ui
    pagedataanalysis.cpp pagedataanalysis.h pagedataanalysis.ui
    pagemotorinfo.cpp pagemotorinfo.h pagemotorinfo.ui
    pagesetupcalculators.cpp pagesetupcalculators.h pagesetupcalculators.ui
    pagegpd.cpp pagegpd.h pagegpd.ui
    pageexperiments.cpp pageexperiments.h pageexperiments.ui
    pageimu.cpp pageimu.h pageimu.ui
    pageswdprog.cpp pageswdprog.h pageswdprog.ui
    pageappimu.cpp pageappimu.h pageappimu.ui
    pageloganalysis.cpp pageloganalysis.h pageloganalysis.ui
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

> Note: AUTOUIC requires the directory holding a `.ui` file to be in the include path so the generated `ui_*.h` is found. The `target_include_directories` line above handles that for `pages/`.

- [ ] **Step 2: Enable the subdirectory in the top-level `CMakeLists.txt`**

Replace the comment line `# add_subdirectory(pages)` with `add_subdirectory(pages)`.

- [ ] **Step 3: Verify CMake configures**

Run:
```bash
cmake -S . -B build-cmake -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"
```
Expected: `-- Configuring done` / `-- Generating done`, no errors.

- [ ] **Step 4: Commit**

```bash
git add pages/CMakeLists.txt CMakeLists.txt
git commit -m "CMake: add pages/ sources

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: widgets/ subdirectory CMakeLists

**Files:**
- Create: `widgets/CMakeLists.txt`
- Modify: `CMakeLists.txt` (uncomment `add_subdirectory(widgets)`)

- [ ] **Step 1: Create `widgets/CMakeLists.txt`**

File lists taken verbatim from `widgets/widgets.pri`. Note `vesc3dview.*` is included here (unchanged in Phase 1):

```cmake
target_sources(vesc_tool PRIVATE
    batttempplot.cpp batttempplot.h
    canlistitem.cpp canlistitem.h
    experimentplot.cpp experimentplot.h experimentplot.ui
    parameditbitfield.cpp parameditbitfield.h parameditbitfield.ui
    parameditbool.cpp parameditbool.h parameditbool.ui
    parameditdouble.cpp parameditdouble.h parameditdouble.ui
    parameditenum.cpp parameditenum.h parameditenum.ui
    parameditint.cpp parameditint.h parameditint.ui
    displaybar.cpp displaybar.h
    displaypercentage.cpp displaypercentage.h
    helpdialog.cpp helpdialog.h helpdialog.ui
    mrichtextedit.cpp mrichtextedit.h mrichtextedit.ui
    mtextedit.cpp mtextedit.h
    pagelistitem.cpp pagelistitem.h
    paramtable.cpp paramtable.h
    qcustomplot.cpp qcustomplot.h
    detectbldc.cpp detectbldc.h detectbldc.ui
    batterycalculator.cpp batterycalculator.h batterycalculator.ui
    detectfoc.cpp detectfoc.h detectfoc.ui
    detectfocencoder.cpp detectfocencoder.h detectfocencoder.ui
    detectfochall.cpp detectfochall.h detectfochall.ui
    ppmmap.cpp ppmmap.h ppmmap.ui
    adcmap.cpp adcmap.h adcmap.ui
    rtdatatext.cpp rtdatatext.h
    nrfpair.cpp nrfpair.h nrfpair.ui
    scripteditor.cpp scripteditor.h scripteditor.ui
    vtextbrowser.cpp vtextbrowser.h
    imagewidget.cpp imagewidget.h
    parameditstring.cpp parameditstring.h parameditstring.ui
    paramdialog.cpp paramdialog.h paramdialog.ui
    aspectimglabel.cpp aspectimglabel.h
    historylineedit.cpp historylineedit.h
    detectallfocdialog.cpp detectallfocdialog.h detectallfocdialog.ui
    dirsetup.cpp dirsetup.h dirsetup.ui
    vesc3dview.cpp vesc3dview.h
    superslider.cpp superslider.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

- [ ] **Step 2: Enable the subdirectory**

In the top-level `CMakeLists.txt`, replace `# add_subdirectory(widgets)` with `add_subdirectory(widgets)`.

- [ ] **Step 3: Verify CMake configures**

Run:
```bash
cmake -S . -B build-cmake -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"
```
Expected: configures cleanly.

- [ ] **Step 4: Commit**

```bash
git add widgets/CMakeLists.txt CMakeLists.txt
git commit -m "CMake: add widgets/ sources

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: mobile/ and map/ subdirectory CMakeLists

**Files:**
- Create: `mobile/CMakeLists.txt`
- Create: `map/CMakeLists.txt`
- Modify: `CMakeLists.txt`

- [ ] **Step 1: Create `mobile/CMakeLists.txt`**

From `mobile/mobile.pri`. The `qml.qrc` resource is wired in Task 7, not here:

```cmake
target_sources(vesc_tool PRIVATE
    logreader.cpp logreader.h
    logwriter.cpp logwriter.h
    qmlui.cpp qmlui.h
    fwhelper.cpp fwhelper.h
    vesc3ditem.cpp vesc3ditem.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

- [ ] **Step 2: Create `map/CMakeLists.txt`**

From `map/map.pri`:

```cmake
target_sources(vesc_tool PRIVATE
    carinfo.cpp carinfo.h
    copterinfo.cpp copterinfo.h
    locpoint.cpp locpoint.h
    mapwidget.cpp mapwidget.h
    osmclient.cpp osmclient.h
    osmtile.cpp osmtile.h
    perspectivepixmap.cpp perspectivepixmap.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

- [ ] **Step 3: Enable both subdirectories**

In the top-level `CMakeLists.txt`, replace `# add_subdirectory(mobile)` with `add_subdirectory(mobile)` and `# add_subdirectory(map)` with `add_subdirectory(map)`.

- [ ] **Step 4: Verify CMake configures**

```bash
cmake -S . -B build-cmake -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"
```
Expected: configures cleanly.

- [ ] **Step 5: Commit**

```bash
git add mobile/CMakeLists.txt map/CMakeLists.txt CMakeLists.txt
git commit -m "CMake: add mobile/ and map/ sources

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Vendored library subdirectory CMakeLists files

**Files:**
- Create: `lzokay/CMakeLists.txt`, `heatshrink/CMakeLists.txt`, `esp32/CMakeLists.txt`, `minimp3/CMakeLists.txt`, `maddy/CMakeLists.txt`, `QCodeEditor/CMakeLists.txt`, `display_tool/CMakeLists.txt`, `qmarkdowntextedit/CMakeLists.txt`
- Modify: `CMakeLists.txt`

All vendored code is added directly to the `vesc_tool` target (no separate library targets), matching the spec's "no new library boundaries" decision.

- [ ] **Step 1: Create `lzokay/CMakeLists.txt`**

```cmake
target_sources(vesc_tool PRIVATE lzokay.cpp lzokay.hpp)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

- [ ] **Step 2: Create `heatshrink/CMakeLists.txt`**

```cmake
target_sources(vesc_tool PRIVATE
    heatshrink_decoder.c heatshrink_encoder.c heatshrinkif.cpp
    heatshrink_common.h heatshrink_config.h heatshrink_decoder.h
    heatshrink_encoder.h heatshrinkif.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

- [ ] **Step 3: Create `esp32/CMakeLists.txt`**

```cmake
target_sources(vesc_tool PRIVATE
    esp32flash.cpp esp_loader.c esp_targets.c md5_hash.c
    protocol_uart.c protocol_serial.c esp_stubs.c slip.c
    esp32flash.h esp_loader.h esp_targets.h md5_hash.h
    serial_comm_prv.h esp_loader_io.h protocol.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

> Note: the working tree contains `esp32/esp_loader.h.orig` — ignore it; only `esp_loader.h` is a source.

- [ ] **Step 4: Create `minimp3/CMakeLists.txt`**

```cmake
target_sources(vesc_tool PRIVATE qminimp3.cpp minimp3.h minimp3_ex.h qminimp3.h)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

- [ ] **Step 5: Create `maddy/CMakeLists.txt`**

`maddy` is header-only (`maddy/maddy.pri` lists only `HEADERS`). The headers live in `maddy/` but are `#include`d as `<maddy/...>` or `"..."` — provide the directory on the include path. Inspect one `#include "maddy/parser.h"` site in the codebase first; if includes use the `maddy/` prefix, add the *parent* directory:

```cmake
# maddy is header-only; expose its headers on the include path.
target_include_directories(vesc_tool PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..)
```

- [ ] **Step 6: Create `QCodeEditor/CMakeLists.txt`**

From `QCodeEditor/qcodeeditor.pri`. Headers are under `include/internal/`, sources under `src/internal/`, and `INCLUDEPATH += include`:

```cmake
target_sources(vesc_tool PRIVATE
    src/internal/LispHighlighter.cpp
    src/internal/QCodeEditor.cpp
    src/internal/QCXXHighlighter.cpp
    src/internal/QFramedTextAttribute.cpp
    src/internal/QGLSLCompleter.cpp
    src/internal/QGLSLHighlighter.cpp
    src/internal/QJSONHighlighter.cpp
    src/internal/QLanguage.cpp
    src/internal/QLineNumberArea.cpp
    src/internal/QLispCompleter.cpp
    src/internal/QLuaCompleter.cpp
    src/internal/QLuaHighlighter.cpp
    src/internal/QPythonCompleter.cpp
    src/internal/QPythonHighlighter.cpp
    src/internal/QStyleSyntaxHighlighter.cpp
    src/internal/QSyntaxStyle.cpp
    src/internal/QXMLHighlighter.cpp
    src/internal/QmlHighlighter.cpp
    src/internal/QVescCompleter.cpp
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
```

> The `qcodeeditor_resources.qrc` resource is wired in Task 7.

- [ ] **Step 7: Create `display_tool/CMakeLists.txt`**

From `display_tool/display_tool.pri`:

```cmake
target_sources(vesc_tool PRIVATE
    dispeditor.cpp dispeditor.h dispeditor.ui
    displayedit.cpp displayedit.h
    imagewidgetdisp.cpp imagewidgetdisp.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

- [ ] **Step 8: Create `qmarkdowntextedit/CMakeLists.txt`**

From `qmarkdowntextedit/qmarkdowntextedit-headers.pri` and `-sources.pri`. The `media.qrc` resource is wired in Task 7:

```cmake
target_sources(vesc_tool PRIVATE
    markdownhighlighter.cpp markdownhighlighter.h
    qmarkdowntextedit.cpp qmarkdowntextedit.h
    qownlanguagedata.cpp qownlanguagedata.h
    qplaintexteditsearchwidget.cpp qplaintexteditsearchwidget.h
    qplaintexteditsearchwidget.ui
    linenumberarea.h
)
target_include_directories(vesc_tool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
```

- [ ] **Step 9: Enable all eight subdirectories**

In the top-level `CMakeLists.txt`, uncomment the remaining `add_subdirectory` lines: `lzokay`, `heatshrink`, `QCodeEditor`, `esp32`, `display_tool`, `qmarkdowntextedit`, `maddy`, `minimp3`.

- [ ] **Step 10: Verify CMake configures**

```bash
cmake -S . -B build-cmake -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"
```
Expected: configures cleanly. All executable sources are now declared; the next task adds resources, after which a full build is attempted.

- [ ] **Step 11: Commit**

```bash
git add lzokay/CMakeLists.txt heatshrink/CMakeLists.txt esp32/CMakeLists.txt \
        minimp3/CMakeLists.txt maddy/CMakeLists.txt QCodeEditor/CMakeLists.txt \
        display_tool/CMakeLists.txt qmarkdowntextedit/CMakeLists.txt CMakeLists.txt
git commit -m "CMake: add vendored library sources

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Wire up resources (.qrc)

**Files:**
- Modify: `CMakeLists.txt`
- Modify: `pages/CMakeLists.txt`, `mobile/CMakeLists.txt`, `QCodeEditor/CMakeLists.txt`, `qmarkdowntextedit/CMakeLists.txt` (each adds its own `.qrc`)

With `CMAKE_AUTORCC ON`, a `.qrc` file listed in `target_sources` is compiled automatically. Add each `.qrc` to the target alongside the subdirectory that owns it.

- [ ] **Step 1: Add top-level resources**

In the top-level `CMakeLists.txt`, after the `qt_add_executable` block, add an edition-aware resource section. The default edition is `VER_NEUTRAL` → `res_neutral.qrc` (per `vesc_tool.pro`). The firmware resource is conditional on an `exclude_fw` option (the `.pro` sets `CONFIG += exclude_fw`, so it defaults ON):

```cmake
option(VT_EXCLUDE_FW "Exclude built-in firmwares" ON)

target_sources(vesc_tool PRIVATE
    res.qrc
    res_custom_module.qrc
    res_lisp.qrc
    res_qml.qrc
    res/config/res_config.qrc
    res_fw_bms.qrc
    res_neutral.qrc
)

if(NOT VT_EXCLUDE_FW)
    target_sources(vesc_tool PRIVATE res/firmwares/res_fw.qrc)
endif()
```

> Note: `res/firmwares/res_fw.qrc` currently shows as an untracked file in `git status`. Confirm it exists before enabling `VT_EXCLUDE_FW=OFF`; with the default `ON` it is not referenced.

- [ ] **Step 2: Add `pages/` resource — none**

`pages/pages.pri` declares no `RESOURCES`. No change to `pages/CMakeLists.txt`.

- [ ] **Step 3: Add `mobile/` resource**

In `mobile/CMakeLists.txt`, append to the existing `target_sources` call:
```cmake
target_sources(vesc_tool PRIVATE qml.qrc)
```

- [ ] **Step 4: Add `QCodeEditor/` resource**

In `QCodeEditor/CMakeLists.txt`, append:
```cmake
target_sources(vesc_tool PRIVATE resources/qcodeeditor_resources.qrc)
```

- [ ] **Step 5: Add `qmarkdowntextedit/` resource**

In `qmarkdowntextedit/CMakeLists.txt`, append:
```cmake
target_sources(vesc_tool PRIVATE media.qrc)
```

- [ ] **Step 6: Verify CMake configures**

```bash
cmake -S . -B build-cmake -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"
```
Expected: configures cleanly.

- [ ] **Step 7: Commit**

```bash
git add CMakeLists.txt mobile/CMakeLists.txt QCodeEditor/CMakeLists.txt qmarkdowntextedit/CMakeLists.txt
git commit -m "CMake: wire up qrc resources

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: macOS bundle configuration

**Files:**
- Modify: `CMakeLists.txt`

- [ ] **Step 1: Add the macOS app-bundle block**

In the top-level `CMakeLists.txt`, after the resources section, add (mirrors the `macx` block of `vesc_tool.pro` — bundle, icon `macos/appIcon.icns`, custom `macos/Info.plist`):

```cmake
if(APPLE AND NOT IOS)
    set(MACOSX_BUNDLE_ICON_FILE appIcon.icns)
    set(app_icon "${CMAKE_CURRENT_SOURCE_DIR}/macos/appIcon.icns")
    set_source_files_properties(${app_icon} PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources")
    target_sources(vesc_tool PRIVATE ${app_icon})

    set_target_properties(vesc_tool PROPERTIES
        MACOSX_BUNDLE ON
        OUTPUT_NAME "VESC Tool"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/macos/Info.plist")
endif()
```

> The `.pro` sets `TARGET = "VESC Tool"` for `macx`; `OUTPUT_NAME` reproduces that. Non-bundle desktop targets used `vesc_tool_$$VT_VERSION` — desktop Linux/Windows naming is a Phase 3 concern; leave the default `vesc_tool` here.

- [ ] **Step 2: Verify CMake configures**

```bash
cmake -S . -B build-cmake -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"
```
Expected: configures cleanly. `IOS` is undefined on a desktop generator, so the `NOT IOS` guard passes.

- [ ] **Step 3: Commit**

```bash
git add CMakeLists.txt
git commit -m "CMake: macOS app bundle configuration

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Update the macOS build script

**Files:**
- Read first: `build_macos_universal`, `build_macos_arm64` (untracked scripts in the repo root)
- Create or Modify: a CMake-based macOS build script

- [ ] **Step 1: Inspect the existing build scripts**

Run:
```bash
file build_macos_universal build_macos_arm64
cat build_macos_arm64 2>/dev/null | head -40
```
Determine how they currently invoke qmake and which build (`build_macos`, arch flags) they pass.

- [ ] **Step 2: Write the CMake equivalent**

Create `build_macos_cmake.sh` that configures and builds via CMake. Universal-binary support comes from `CMAKE_OSX_ARCHITECTURES`:

```bash
#!/bin/bash
set -e
QT_PREFIX="${QT_PREFIX:-$CMAKE_PREFIX_PATH}"
if [ -z "$QT_PREFIX" ]; then
    echo "Set QT_PREFIX or CMAKE_PREFIX_PATH to the Qt install (clang_64) dir"
    exit 1
fi
cmake -S . -B build/macos \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"
cmake --build build/macos --parallel
echo "Built: build/macos/VESC Tool.app"
```

```bash
chmod +x build_macos_cmake.sh
```

> Note: leave the old `build_macos_*` scripts in place for now; they are removed together with the `.pro`/`.pri` files in Task 10 only after the CMake build is confirmed working.

- [ ] **Step 3: Commit**

```bash
git add build_macos_cmake.sh
git commit -m "CMake: add macOS CMake build script

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Full macOS build and behavior verification

**Files:** none (verification task)

- [ ] **Step 1: Build the app with CMake**

Run:
```bash
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH" -DCMAKE_BUILD_TYPE=Release
cmake --build build/macos --parallel 2>&1 | tee /tmp/vt-cmake-build.log
```
Expected: build finishes with `[100%] Built target vesc_tool` and produces `build/macos/VESC Tool.app`.

If the build fails, fix the cause in the relevant `CMakeLists.txt` (a missing source, a missing Qt component, an include path), re-run, and amend the related task's commit or add a fixup commit. Common expected fixes:
- A missing include directory for a header included without a path prefix → add `target_include_directories`.
- AUTOUIC failing to find a `.ui` → ensure that subdirectory's `target_include_directories` line is present.
Do **not** modify any `.cpp`/`.h` source in Phase 1 — if a source genuinely needs a code change to compile under Qt5, that indicates a pre-existing breakage; stop and report it.

- [ ] **Step 2: Launch and smoke-test the CMake-built app**

Run:
```bash
open "build/macos/VESC Tool.app"
```
Verify manually:
- The app launches without crashing.
- The main window renders; the left-side page list populates.
- Open Preferences — the dialog opens.
- Open a QML-backed page (e.g. the RT Data / mobile view) — it renders with no QML errors printed to the console (check `Console.app` or run the binary directly: `"build/macos/VESC Tool.app/Contents/MacOS/VESC Tool"` and watch stdout/stderr).
- If hardware is unavailable, confirm the connection page and the simulated/dummy data path behave as before.

- [ ] **Step 3: Behavior diff against the qmake build**

Build the current qmake build for comparison (if a Qt5 `qmake` is available):
```bash
mkdir -p /tmp/vt-qmake && cd /tmp/vt-qmake
qmake "$OLDPWD/vesc_tool.pro" CONFIG+=release && make -j
```
Launch that build and confirm the CMake-built app matches it: same pages, same Preferences contents, same QML rendering. Note any difference. Expected: no observable behavior difference. If `qmake` is unavailable, rely on Step 2's smoke test and note that the qmake baseline could not be built.

- [ ] **Step 4: Commit verification notes**

Append a short verification record to the plan file's checklist (or a `docs/superpowers/plans/2026-05-19-phase1-verification.md` note) stating: build succeeded, smoke test result, behavior-diff result. Commit:
```bash
git add -A
git commit -m "Phase 1: verify macOS CMake build matches qmake build

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: Remove the qmake build files

**Files:**
- Delete: `vesc_tool.pro`, `pages/pages.pri`, `widgets/widgets.pri`, `mobile/mobile.pri`, `map/map.pri`, `lzokay/lzokay.pri`, `heatshrink/heatshrink.pri`, `QCodeEditor/qcodeeditor.pri`, `esp32/esp32.pri`, `display_tool/display_tool.pri`, `qmarkdowntextedit/qmarkdowntextedit.pri`, `qmarkdowntextedit/qmarkdowntextedit-headers.pri`, `qmarkdowntextedit/qmarkdowntextedit-sources.pri`, `maddy/maddy.pri`, `minimp3/minimp3.pri`
- Delete: old macOS qmake build scripts (`build_macos_universal`, `build_macos_arm64`) — confirm with the user before deleting these, since they are untracked and may be personal scripts

- [ ] **Step 1: Confirm Task 9 passed**

Do not proceed unless Task 9's build + smoke test succeeded. The `.pro`/`.pri` files are the reference of last resort; they are removed only once CMake is proven equivalent.

- [ ] **Step 2: Delete the qmake project files**

```bash
git rm vesc_tool.pro \
    pages/pages.pri widgets/widgets.pri mobile/mobile.pri map/map.pri \
    lzokay/lzokay.pri heatshrink/heatshrink.pri QCodeEditor/qcodeeditor.pri \
    esp32/esp32.pri display_tool/display_tool.pri \
    qmarkdowntextedit/qmarkdowntextedit.pri \
    qmarkdowntextedit/qmarkdowntextedit-headers.pri \
    qmarkdowntextedit/qmarkdowntextedit-sources.pri \
    maddy/maddy.pri minimp3/minimp3.pri
```

> Leave the untracked `vesc_tool.pro.orig` / `vesc_tool.pro.rej` files alone — they are not tracked and out of scope.

- [ ] **Step 3: Re-verify the build still works after removal**

```bash
rm -rf build/macos
cmake -S . -B build/macos -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH" -DCMAKE_BUILD_TYPE=Release
cmake --build build/macos --parallel
```
Expected: builds successfully — confirms nothing implicitly depended on the `.pro`/`.pri` files.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Remove qmake project files (replaced by CMake)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase 1 Done — Definition of Done

- [ ] `cmake --build` produces a working `build/macos/VESC Tool.app`.
- [ ] The CMake-built app passes the smoke test and matches the qmake build's behavior.
- [ ] All `.pro`/`.pri` files are removed; the repo builds from CMake alone.
- [ ] The `CMakeLists.txt` is Qt-version-agnostic (`find_package(QT NAMES Qt6 Qt5 ...)`), ready for the Phase 2 SDK swap.

**Next:** Phase 2 (Qt6 framework port) gets its own plan, written after Phase 1 is merged/verified — its tasks depend on the actual compiler and QML-runtime errors that surface once `find_package` resolves to Qt 6.8.
