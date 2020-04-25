#-------------------------------------------------
#
# Project created by QtCreator 2016-08-12T21:55:19
#
#-------------------------------------------------

# Version
VT_VERSION = 1.4
VT_INTRO_VERSION = 1

DEFINES += VT_VERSION=$$VT_VERSION
DEFINES += VT_INTRO_VERSION=$$VT_INTRO_VERSION

#QMAKE_EXTRA_TARGETS += qml_scenes
# Options
CONFIG += static
CONFIG += build_original
#CONFIG += build_platinum
#CONFIG += build_gold
#CONFIG += build_silver
# CONFIG += build_bronze
#CONFIG += build_free

CONFIG += c++11


# Bluetooth available
DEFINES += HAS_BLUETOOTH

# Build mobile GUI
#CONFIG += build_mobile

CONFIG += qtquickcompiler

QT       += core gui
QT       += widgets
QT       += printsupport
QT       += network
QT       += quick
QT       += quickcontrols2
QT       += charts qml

#QT       += positioning

ios {
    CONFIG  += iOSBuild
    CONFIG  -= bitcode
    DEFINES += __ios__
    DEFINES += NO_SERIAL_LINK
    QMAKE_IOS_DEPLOYMENT_TARGET = 11.0
    QMAKE_APPLE_TARGETED_DEVICE_FAMILY = 1,2 # Universal
    QMAKE_LFLAGS += -Wl,-no_pie
}

iOSBuild {
    #-- Info.plist (need an "official" one for the App Store)
    ForAppStore {
        message(App Store Build)
        #-- Create official, versioned Info.plist
        APP_STORE = $$system(cd $${PWD} && $${PWD}/tools/update_ios_version.sh $${PWD}/ios/iOSForAppStore-Info-Source.plist $${PWD}/ios/iOSForAppStore-Info.plist)
        APP_ERROR = $$find(APP_STORE, "Error")
        count(APP_ERROR, 1) {
            error("Error building .plist file. 'ForAppStore' builds are only possible through the official build system.")
        }
        QT               += qml-private
        QMAKE_INFO_PLIST  = $${PWD}/ios/iOSForAppStore-Info.plist
        OTHER_FILES      += $${PWD}/ios/iOSForAppStore-Info.plist
    } else {
        QMAKE_INFO_PLIST  = $${PWD}/ios/iOS-Info.plist
        OTHER_FILES      += $${PWD}/ios/iOS-Info.plist
    }

    QMAKE_ASSET_CATALOGS += ios/Images.xcassets
    BUNDLE.files          = ios/FBLaunchScreen.xib $$QMAKE_INFO_PLIST
    QMAKE_BUNDLE_DATA    += BUNDLE
}

android || ios {
    # Android and iOS don't unclude these
} else {
    # Serial port available
    DEFINES += HAS_SERIALPORT
    DEFINES += HAS_CANBUS
}

contains(DEFINES, HAS_BLUETOOTH) {
    QT       += bluetooth
}

contains(DEFINES, HAS_SERIALPORT) {
    QT       += serialport
}

android: QT += androidextras

# android: TARGET = FOCBOX_UI
# !android: TARGET = FOCBOX_UI_$$VT_VERSION

android || ios || unix:!macx {
    TARGET = FOCBOX_UI
} else {
    TARGET = FOCBOX_UI_$$VT_VERSION
}

TEMPLATE = app

release_win {
    DESTDIR = build/win
    OBJECTS_DIR = build/win/obj
    MOC_DIR = build/win/obj
    RCC_DIR = build/win/obj
    UI_DIR = build/win/obj
}

release_lin {
    # http://micro.nicholaswilson.me.uk/post/31855915892/rules-of-static-linking-libstdc-libc-libgcc
    # http://insanecoding.blogspot.se/2012/07/creating-portable-linux-binaries.html
    QMAKE_LFLAGS += -static-libstdc++ -static-libgcc
    DESTDIR = build/lin
    OBJECTS_DIR = build/lin/obj
    MOC_DIR = build/lin/obj
    RCC_DIR = build/lin/obj
    UI_DIR = build/lin/obj
}

release_macos {
    # brew install qt
    DESTDIR = build/macos
    OBJECTS_DIR = build/macos/obj
    MOC_DIR = build/macos/obj
    RCC_DIR = build/macos/obj
    UI_DIR = build/macos/obj
}

release_android {
    DESTDIR = build/android
    OBJECTS_DIR = build/android/obj
    MOC_DIR = build/android/obj
    RCC_DIR = build/android/obj
    UI_DIR = build/android/obj
}

release_ios {
    DESTDIR = build/ios
    OBJECTS_DIR = build/ios/obj
    MOC_DIR = build/ios/obj
    RCC_DIR = build/ios/obj
    UI_DIR = build/ios/obj
}

build_mobile {
    DEFINES += USE_MOBILE
}

SOURCES += main.cpp\
        mainwindow.cpp \
    packet.cpp \
    vbytearray.cpp \
    commands.cpp \
    configparams.cpp \
    configparam.cpp \
    vescinterface.cpp \
    parametereditor.cpp \
    digitalfiltering.cpp \
    setupwizardapp.cpp \
    setupwizardmotor.cpp \
    startupwizard.cpp \
    utility.cpp

HEADERS  += mainwindow.h \
    packet.h \
    vbytearray.h \
    commands.h \
    datatypes.h \
    configparams.h \
    configparam.h \
    vescinterface.h \
    parametereditor.h \
    digitalfiltering.h \
    setupwizardapp.h \
    setupwizardmotor.h \
    startupwizard.h \
    utility.h

FORMS    += mainwindow.ui \
    parametereditor.ui \
    mainwindow.ui \
    parametereditor.ui

contains(DEFINES, HAS_BLUETOOTH) {
    SOURCES += bleuart.cpp
    HEADERS += bleuart.h
}

include(pages/pages.pri)
include(widgets/widgets.pri)
include(mobile/mobile.pri)

RESOURCES += res.qrc

build_original {
    RESOURCES += res_original.qrc \
    res_fw_original.qrc
    DEFINES += VER_ORIGINAL
} else:build_platinum {
    RESOURCES += res_platinum.qrc
    res_fw.qrc
    DEFINES += VER_PLATINUM
} else:build_gold {
    RESOURCES += res_gold.qrc \
    res_fw.qrc
    DEFINES += VER_GOLD
} else:build_silver {
    RESOURCES += res_silver.qrc \
    res_fw.qrc
    DEFINES += VER_SILVER
} else:build_bronze {
    RESOURCES += res_bronze.qrc \
    res_fw.qrc
    DEFINES += VER_BRONZE
} else:build_free {
    RESOURCES += res_free.qrc \
    res_fw.qrc
    DEFINES += VER_FREE
} else {
    RESOURCES += res_neutral.qrc \
    res_fw.qrc
    DEFINES += VER_NEUTRAL
}

DISTFILES += \
    android/AndroidManifest.xml \
    android/gradle/wrapper/gradle-wrapper.jar \
    android/gradlew \
    android/res/values/libs.xml \
    android/build.gradle \
    android/gradle/wrapper/gradle-wrapper.properties \
    res/success.png

ANDROID_PACKAGE_SOURCE_DIR = $$PWD/android

#INSTALLS        = target
#target.files    = FOCBOX_UI_0.6
#target.path     = /home/pi
