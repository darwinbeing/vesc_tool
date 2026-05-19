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
