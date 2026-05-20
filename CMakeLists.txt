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
    Core Gui Widgets Network Qml Quick QuickControls2 QuickWidgets Svg
    Bluetooth Positioning Core5Compat)

# SerialPort and PrintSupport are desktop-only (no Android/iOS Qt packages).
if(NOT ANDROID AND NOT IOS)
    find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS PrintSupport SerialPort)
endif()

# Gamepad support via SDL3 — desktop only (matches original !android !ios).
if(NOT ANDROID AND NOT IOS)
    find_package(SDL3 CONFIG REQUIRED)
endif()

# QOpenGLWidget moved to the OpenGLWidgets module in Qt6.
if(QT_VERSION_MAJOR EQUAL 6)
    find_package(Qt6 REQUIRED COMPONENTS OpenGL OpenGLWidgets)
endif()

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
    datatypes.h
    mainwindow.ui
    boardsetupwindow.ui
    parametereditor.ui
    preferences.ui
)

# --- Build-feature macros (desktop; mirrors vesc_tool.pro DEFINES) ---
target_compile_definitions(vesc_tool PRIVATE
    VT_VERSION=${VT_VERSION}
    VT_INTRO_VERSION=${VT_INTRO_VERSION}
    VT_CONFIG_VERSION=${VT_CONFIG_VERSION}
    VT_IS_TEST_VERSION=${VT_IS_TEST_VERSION}
    VT_GIT_COMMIT=${VT_GIT_COMMIT}
    HAS_BLUETOOTH
    VER_NEUTRAL
)

# Serial port is desktop-only (not Android/iOS).
if(NOT ANDROID AND NOT IOS)
    target_compile_definitions(vesc_tool PRIVATE HAS_SERIALPORT)
endif()

# Gamepad support is desktop-only.
if(NOT ANDROID AND NOT IOS)
    target_compile_definitions(vesc_tool PRIVATE HAS_GAMEPAD)
endif()

# Positioning is not used on Windows (matches the original vesc_tool.pro: !win32).
if(NOT WIN32)
    target_compile_definitions(vesc_tool PRIVATE HAS_POS)
endif()

if(WIN32)
    target_compile_definitions(vesc_tool PRIVATE _USE_MATH_DEFINES NOMINMAX)
    set_target_properties(vesc_tool PROPERTIES WIN32_EXECUTABLE ON)
endif()

if(ANDROID)
    # Mobile QML GUI
    target_compile_definitions(vesc_tool PRIVATE USE_MOBILE QT_NO_PRINTER)

    # Generate AndroidManifest.xml from the .in template.
    # The .in file uses @VAR@ CMake tokens for version substitution; %%...%% tokens
    # are androiddeployqt placeholders that configure_file leaves intact.
    set(VT_ANDROID_VERSION 207)
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/android/AndroidManifest.xml.in
        ${CMAKE_CURRENT_SOURCE_DIR}/android/AndroidManifest.xml
        @ONLY)

    set_target_properties(vesc_tool PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/android
        QT_ANDROID_VERSION_NAME ${VT_VERSION}
        QT_ANDROID_VERSION_CODE 207
        QT_ANDROID_TARGET_SDK_VERSION 34
        QT_ANDROID_MIN_SDK_VERSION 28)
endif()

# systemcommandexecutor.h uses QProcess, which is unavailable on iOS.
# Matches the original vesc_tool.pro: unix: !ios: HEADERS += systemcommandexecutor.h
if(NOT IOS)
    target_sources(vesc_tool PRIVATE systemcommandexecutor.h)
endif()

# SDL3 Gamepad backend — desktop only.
if(NOT ANDROID AND NOT IOS)
    target_sources(vesc_tool PRIVATE gamepad.cpp gamepad.h)
endif()

if(IOS)
    # Objective-C++ source only compiled on iOS.
    target_sources(vesc_tool PRIVATE
        ios/src/setIosParameters.h
        ios/src/setIosParameters.mm)

    target_compile_definitions(vesc_tool PRIVATE USE_MOBILE QT_NO_PRINTER)

    set_target_properties(vesc_tool PROPERTIES
        MACOSX_BUNDLE ON
        OUTPUT_NAME "VESC Tool"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
        QT_IOS_LAUNCH_SCREEN "${CMAKE_CURRENT_SOURCE_DIR}/ios/MyLaunchScreen.storyboard")

    # Asset catalog (app icon).
    target_sources(vesc_tool PRIVATE ios/Images.xcassets)
    set_source_files_properties(ios/Images.xcassets PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)
endif()

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
    Qt${QT_VERSION_MAJOR}::Bluetooth
    Qt${QT_VERSION_MAJOR}::Positioning
    Qt${QT_VERSION_MAJOR}::Core5Compat
    Qt${QT_VERSION_MAJOR}::Qml
)

# SerialPort and PrintSupport are desktop-only.
if(NOT ANDROID AND NOT IOS)
    target_link_libraries(vesc_tool PRIVATE
        Qt${QT_VERSION_MAJOR}::PrintSupport
        Qt${QT_VERSION_MAJOR}::SerialPort
    )
endif()

# SDL3 gamepad is desktop-only.
if(NOT ANDROID AND NOT IOS)
    target_link_libraries(vesc_tool PRIVATE SDL3::SDL3)
endif()

if(QT_VERSION_MAJOR EQUAL 6)
    target_link_libraries(vesc_tool PRIVATE
        Qt6::OpenGL
        Qt6::OpenGLWidgets
    )
endif()

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
