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

# Bundle SDL3 dylib into the app
APP="build/macos/VESC Tool.app"
SDL3_DYLIB=$(brew --prefix sdl3)/lib/libSDL3.0.dylib
if [ -f "$SDL3_DYLIB" ]; then
    mkdir -p "$APP/Contents/Frameworks"
    cp -L "$SDL3_DYLIB" "$APP/Contents/Frameworks/libSDL3.0.dylib"
    install_name_tool -change "$SDL3_DYLIB" "@executable_path/../Frameworks/libSDL3.0.dylib" \
        "$APP/Contents/MacOS/VESC Tool" 2>/dev/null || true
fi

echo "Built: build/macos/VESC Tool.app"
