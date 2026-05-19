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

# qt_add_executable was introduced in Qt6; provide a shim for Qt5 builds.
if(QT_VERSION_MAJOR EQUAL 5 AND NOT COMMAND qt_add_executable)
    macro(qt_add_executable name)
        add_executable(${name} ${ARGN})
    endmacro()
endif()

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

# --- Resources ---
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

# --- macOS app bundle configuration ---
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

# Subdirectory source contributions (added in later tasks):
add_subdirectory(pages)
add_subdirectory(widgets)
add_subdirectory(mobile)
add_subdirectory(map)
add_subdirectory(lzokay)
add_subdirectory(heatshrink)
add_subdirectory(QCodeEditor)
add_subdirectory(esp32)
add_subdirectory(display_tool)
add_subdirectory(qmarkdowntextedit)
add_subdirectory(maddy)
add_subdirectory(minimp3)
