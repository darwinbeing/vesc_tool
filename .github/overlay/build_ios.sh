#!/bin/bash

# hdiutil attach -nomount ram://4096000
# diskutil erasevolume HFS+ "RAMDisk" /dev/disk2

PROJECT_NAME="VESC Tool"
SCHEME_NAME="VESC Tool"
TARGET="VESC Tool"
DEV_PROFILE_NAME="anyapp"

# if [ ! -d /Volumes/RAMDisk ] ; then
#     echo 'RAM Disk not found'
#     echo 'Only used for App Store builds. It will not work on your computer.'
#     exit 1
# fi
#-- Set to my local installation
QMAKE=$HOME/Qt5.15.2/5.15.2/ios/bin/qmake
export PATH=$HOME/Qt5.15.2/5.15.2/ios/bin:$PATH
export LD_LIBRARY_PATH=$HOME/Qt5.15.2/5.15.2/ios/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$HOME/Qt5.15.2/5.15.2/ios/lib/pkgconfig:$PKG_CONFIG_PATH
export QML_IMPORT_PATH=$HOME/Qt5.15.2/5.15.2/ios/qml/:$QML_IMPORT_PATH
export QML2_IMPORT_PATH=$HOME/Qt5.15.2/5.15.2/ios/qml/:$QML2_IMPORT_PATH
export QT_PLUGIN_PATH=$HOME/Qt5.15.2/5.15.2/ios/plugins/:$QT_PLUGIN_PATH

#-- Using Travis variables as this will eventually live there
# SHADOW_BUILD_DIR=/Volumes/RAMDisk/build-vesc_tool-iOS-Release
# SHADOW_BUILD_DIR=build-vesc_tool-iOS-Release
TRAVIS_BUILD_DIR=$HOME/Developer/vesc_tool
SHADOW_BUILD_DIR=${TRAVIS_BUILD_DIR}/build-vesc_tool-iOS-Release

export QML_IMPORT_PATH=${TRAVIS_BUILD_DIR}/mobile/:$QML_IMPORT_PATH
export QML2_IMPORT_PATH=${TRAVIS_BUILD_DIR}/mobile/:$QML2_IMPORT_PATH

#-- Build it

rm -rf ${SHADOW_BUILD_DIR}/*
mkdir -p ${TRAVIS_BUILD_DIR}/build/ios
rm -rf ${TRAVIS_BUILD_DIR}/build/ios/*

mkdir -p ${SHADOW_BUILD_DIR} &&
cd ${SHADOW_BUILD_DIR} &&
#-- Create project only (build using Xcode)
${QMAKE} -r ${TRAVIS_BUILD_DIR}/vesc_tool.pro "CONFIG += iphoneos device release release_ios build_mobile" -spec macx-ios-clang
sed -i .bak 's/com.yourcompany.${PRODUCT_NAME:rfc1034identifier}/com.vedder.vesc/' "${SHADOW_BUILD_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj"

# make -f vesc_tool.xcodeproj/qt_preprocess.mak
xcodebuild -configuration Release -target "Qt Preprocess" -sdk iphoneos -arch arm64 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild -configuration Release -target "${TARGET}" install -sdk iphoneos -arch arm64 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# xcodebuild -configuration Release -xcconfig "${TRAVIS_BUILD_DIR}/ios/${PROJECT_NAME}_appstore.xcconfig" -allowProvisioningUpdates
# xcodebuild archive 	-project "${PROJECT_NAME}.xcodeproj" \
#                    	-xcconfig "${TRAVIS_BUILD_DIR}/ios/${PROJECT_NAME}_appstore.xcconfig" \
#                    	-scheme "${SCHEME_NAME}" \
#                    	-destination generic/platform=iOS \
#                    	-archivePath "${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.xcarchive" \
# 			-allowProvisioningUpdates

# xcodebuild -exportArchive -archivePath "${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.xcarchive" \
#                           -exportPath "${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.ipa" \
# 			  -exportOptionsPlist "${TRAVIS_BUILD_DIR}/ios/Info.plist" \
# 			  -allowProvisioningUpdates

# mv ${SHADOW_BUILD_DIR}/Release-iphoneos/vesc_tool.app ${TRAVIS_BUILD_DIR}/build/ios/vesc_tool_mobile.app
# rm -rf ${SHADOW_BUILD_DIR}/*
# rm -rf ${TRAVIS_BUILD_DIR}/build/ios/obj

# ${QMAKE} -r ${TRAVIS_BUILD_DIR}/vesc_tool.pro CONFIG+=WarningsAsErrorsOn CONFIG-=debug_and_release CONFIG+=release CONFIG+=ForAppStore "CONFIG += release_ios"
# sed -i .bak 's/com.yourcompany.${PRODUCT_NAME:rfc1034identifier}/com.vedder.vesc/' ${SHADOW_BUILD_DIR}/vesc_tool.xcodeproj/project.pbxproj
# xcodebuild -configuration Release -xcconfig ${TRAVIS_BUILD_DIR}/ios/vesc_tool_appstore.xcconfig -allowProvisioningUpdates
# xcodebuild archive 	-project ${PROJECT_NAME}.xcodeproj \
#                    	-xcconfig ${TRAVIS_BUILD_DIR}/ios/vesc_tool_appstore.xcconfig \
#                    	-scheme ${SCHEME_NAME} \
#                    	-destination generic/platform=iOS \
#                    	-archivePath ${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.xcarchive

# xcodebuild -exportArchive -archivePath ${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.xcarchive \
#                           -exportPath ${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.ipa \
#                           -exportProvisioningProfile ${DEV_PROFILE_NAME}

# mv ${SHADOW_BUILD_DIR}/Release-iphoneos/vesc_tool.app ${TRAVIS_BUILD_DIR}/build/ios/vesc_tool_full.app
# rm -rf ${SHADOW_BUILD_DIR}/*
# rm -rf ${TRAVIS_BUILD_DIR}/build/ios/obj

# cd ${TRAVIS_BUILD_DIR}/build/ios
# zip -r vesc_tool-iOS.zip vesc_tool_mobile.app vesc_tool_full.app
# rm -rf vesc_tool_mobile.app
# rm -rf vesc_tool_full.app
