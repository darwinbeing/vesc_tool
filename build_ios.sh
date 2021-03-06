#!/bin/bash

# hdiutil attach -nomount ram://2048000
# diskutil erasevolume HFS+ "RAMDisk" /dev/disk2

PROJECT_NAME=vesc_tool
SCHEME_NAME=vesc_tool
DEV_PROFILE_NAME="anyapp"

if [ ! -d /Volumes/RAMDisk ] ; then
    echo 'RAM Disk not found'
    echo 'Only used for App Store builds. It will not work on your computer.'
    exit 1
fi
#-- Set to my local installation
QMAKE=$HOME/Qt5.12.7/5.12.7/ios/bin/qmake
export PATH=$HOME/Qt5.12.7/5.12.7/ios/bin:$PATH
#-- Using Travis variables as this will eventually live there
SHADOW_BUILD_DIR=/Volumes/RAMDisk/build-vesc_tool-iOS-Release
TRAVIS_BUILD_DIR=$HOME/Developer/vesc_tool
#-- Build it

mkdir -p ${TRAVIS_BUILD_DIR}/build/ios
rm -rf ${TRAVIS_BUILD_DIR}/build/ios/*

mkdir -p ${SHADOW_BUILD_DIR} &&
cd ${SHADOW_BUILD_DIR} &&
#-- Create project only (build using Xcode)
${QMAKE} -r ${TRAVIS_BUILD_DIR}/vesc_tool.pro CONFIG+=WarningsAsErrorsOn CONFIG-=debug_and_release CONFIG+=release CONFIG+=ForAppStore "CONFIG += release_ios build_mobile"
sed -i .bak 's/com.yourcompany.${PRODUCT_NAME:rfc1034identifier}/com.vedder.vesc/' ${SHADOW_BUILD_DIR}/vesc_tool.xcodeproj/project.pbxproj
xcodebuild -configuration Release -xcconfig ${TRAVIS_BUILD_DIR}/ios/vesc_tool_appstore.xcconfig -allowProvisioningUpdates
xcodebuild archive 	-project ${PROJECT_NAME}.xcodeproj \
                   	-xcconfig ${TRAVIS_BUILD_DIR}/ios/vesc_tool_appstore.xcconfig \
                   	-scheme ${SCHEME_NAME} \
                   	-destination generic/platform=iOS \
                   	-archivePath ${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.xcarchive \
			-allowProvisioningUpdates

xcodebuild -exportArchive -archivePath ${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.xcarchive \
                          -exportPath ${TRAVIS_BUILD_DIR}/build/ios/${PROJECT_NAME}.ipa \
			  -exportOptionsPlist ${TRAVIS_BUILD_DIR}/ios/APPStoreExportOptions.plist \
			  -allowProvisioningUpdates

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
