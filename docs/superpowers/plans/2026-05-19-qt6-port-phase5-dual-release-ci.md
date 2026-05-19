# Phase 5 — Qt5+Qt6 Dual-Release CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the fork's release pipeline so a single release publishes both Qt5 and Qt6 binaries for all five platforms (macOS x86_64 / arm64 / universal, Linux, Windows, Android, iOS).

**Architecture:** All new work lives on the **`ci` branch** (where the existing `createRelease.yml` + per-platform Qt5 workflows live). For each platform a new `<platform>-qt6.yml` is added that mirrors the framing of its Qt5 sibling but checks out `qt6-port`, installs Qt 6.8.3, builds with CMake (recipes proven by `qt6-port/.github/workflows/build.yml`), and uploads an artifact with a `-qt6` suffix. `createRelease.yml` is extended to invoke the new jobs alongside the existing Qt5 ones. **No application source code is touched.**

**Tech Stack:** GitHub Actions YAML, Qt 6.8.3, CMake, `jurplel/install-qt-action`, `svenstaro/upload-release-action`.

**Verification model:** A task is done when its CI job goes green via `workflow_dispatch`. The earlier Phase-3/4 CI run [26129925963](https://github.com/darwinbeing/vesc_tool/actions/runs/26129925963) is the proof that the underlying Qt6 build works on each platform; Phase 5 just wraps that build into a release-publishing flow.

**Sources to copy/adapt:**
- Qt5 release-flow scaffolding: `origin/ci:.github/workflows/<platform>.yml`
- Qt6 build recipes: `origin/qt6-port:.github/workflows/build.yml`

**Branch logistics:** all editing happens on a `ci` worktree (set up in Task 1). The plan + spec docs live on `qt6-port` (for continuity with the rest of the port docs); the executable workflow YAML lives on `ci`.

**Prereq:** `gh` CLI authenticated; SSH push to `origin` works.

---

## Task 1: Set up a `ci` worktree

**Files:** none (workspace setup)

- [ ] **Step 1: Add a worktree for `ci`**

```bash
cd /Users/litao/Developer/vesc_tool
git fetch origin ci
git worktree add ../vesc_tool-ci -B ci origin/ci
ls ../vesc_tool-ci/.github/workflows/
```
Expected: the listing shows `createRelease.yml`, `mac.yml`, `linux.yml`, `win.yml`, `android.yml`, `ios.yml`, etc.

- [ ] **Step 2: Read the existing Qt5 release-flow scaffolding once for reference**

```bash
cat ../vesc_tool-ci/.github/workflows/createRelease.yml
cat ../vesc_tool-ci/.github/workflows/mac.yml
cat ../vesc_tool-ci/.github/workflows/linux.yml
cat ../vesc_tool-ci/.github/workflows/win.yml
cat ../vesc_tool-ci/.github/workflows/android.yml
cat ../vesc_tool-ci/.github/workflows/ios.yml
```
Note the common pattern: `Version2Ref` → `Clone Repository` (`actions/checkout@v4` at `${{ env.VT_REF }}`) → `Checkout Workflow Scripts` → `Setup` (`generate_release_notes.sh`) → toolchain install → Qt install → FW artifact download (`darwinbeing/bldc` `firmware.yml`) → `Overlay Build Scripts` → `Apply Patch` → `Configure And Compile` → `Upload Release` (`svenstaro/upload-release-action`).

- [ ] **Step 3: No commit** — this task changes no files.

---

## Common shape of a Qt6 platform workflow

Every `<platform>-qt6.yml` follows this skeleton. Tasks 2–7 adapt it per platform; only the toolchain install, the configure/build commands, the packaging command, and the artifact name change.

```yaml
name: <Platform>-qt6

on:
  workflow_dispatch:
    inputs:
      vt_ver:
        description: "VESC Tool branch/tag"
        required: true
        default: "qt6-port"
        type: string
      fw_ver:
        description: "Firmware Version"
        required: true
        default: "master"
        type: string
      release_notes:
        description: "Release Notes"
        required: false
        default: ""
        type: string
      prerelease:
        description: "Release as Prerelease"
        required: true
        default: true
        type: boolean

permissions:
  contents: write

jobs:
  build:
    runs-on: <runner>
    steps:
      - name: Clone Repository
        uses: actions/checkout@v4
        with:
          ref: ${{ inputs.vt_ver }}      # qt6-port; no Version2Ref mapping needed
          fetch-depth: 0
          fetch-tags: true
      - name: Checkout Workflow Scripts
        uses: actions/checkout@v4
        with:
          ref: ${{ github.sha }}
          path: .workflow-src
      - name: Setup
        env:
          ACTIONS_ALLOW_UNSECURE_COMMANDS: 'true'
          CUSTOM_RELEASE_NOTES: ${{ inputs.release_notes }}
        id: GetVersion
        run: |
          # The Qt6 branch removed vesc_tool.pro; read VT_VERSION from CMakeLists.txt.
          VT_VERSION=$(grep -m1 'set(VT_VERSION' CMakeLists.txt | sed 's/.*set(VT_VERSION //; s/).*//')
          echo "VERSION=${VT_VERSION}" >> $GITHUB_OUTPUT
          echo "PACKAGE_VERSION=${VT_VERSION}" >> $GITHUB_ENV
          export VT_VERSION
          export PRERELEASE="${{ inputs.prerelease }}"
          bash .workflow-src/.github/scripts/generate_release_notes.sh
        shell: bash
      # ----- toolchain + Qt 6.8.3 install (per-platform) -----
      # ----- FW artifact download (same as Qt5 jobs) -----
      - name: Create TMP Dir
        id: mktemp
        run: echo "FW_TMP_DIR=$(mktemp -d)" >> $GITHUB_ENV
        shell: bash
      - name: Download FW Artifact
        uses: dawidd6/action-download-artifact@v3
        with:
          name: firmware-${{ inputs.fw_ver }}
          path: ${{ env.FW_TMP_DIR }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          repo: darwinbeing/bldc
          workflow: firmware.yml
          workflow_conclusion: success
          search_artifacts: true
      # No "Overlay Build Scripts" or "Apply Patch" steps — qt6-port is self-contained.
      # ----- configure + build (per-platform CMake recipe) -----
      # ----- package (per-platform tool: macdeployqt / linuxdeploy / windeployqt / androiddeployqt / xcodebuild archive) -----
      - name: Upload Release
        uses: svenstaro/upload-release-action@v2
        with:
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          file: <packaged-artifact-path>
          asset_name: <Disambiguated name ending in -qt6.<ext>>
          tag: ${{ steps.GetVersion.outputs.VERSION }}
          release_name: Release ${{ steps.GetVersion.outputs.VERSION }}
          overwrite: true
          prerelease: ${{ inputs.prerelease }}
```

Differences per platform are noted in each task's "Per-platform body" block.

---

## Task 2: `linux-qt6.yml`

**Files:**
- Create: `.github/workflows/linux-qt6.yml` (on `ci`)

- [ ] **Step 1: Write the file in the `ci` worktree**

Use the common shape above with this per-platform body:

```yaml
    runs-on: ubuntu-22.04
    steps:
      # ... common pre-build steps from skeleton ...
      - name: Install Linux build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential ninja-build \
            libgl1-mesa-dev libxkbcommon-dev libxkbcommon-x11-dev \
            libbluetooth-dev '^libxcb.*-dev' libx11-xcb-dev \
            libglu1-mesa-dev libxrender-dev libxi-dev libfuse2
      - name: Install Qt 6.8.3
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: linux
          target: desktop
          arch: linux_gcc_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
          cache: 'true'
          cache-key-prefix: install-qt-action-qt6
      # ... FW artifact download from skeleton ...
      - name: Configure
        run: cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
      - name: Build
        run: cmake --build build --parallel
      - name: Package AppImage
        run: |
          # Stage files into AppDir
          mkdir -p AppDir/usr/bin
          cp "build/vesc_tool_${PACKAGE_VERSION}" AppDir/usr/bin/vesc_tool || \
            cp build/vesc_tool AppDir/usr/bin/vesc_tool
          # Provide a minimal .desktop + icon
          mkdir -p AppDir/usr/share/applications AppDir/usr/share/icons/hicolor/256x256/apps
          cp .workflow-src/.github/scripts/vesc_tool.desktop AppDir/usr/share/applications/ 2>/dev/null || \
            printf '[Desktop Entry]\nName=VESC Tool\nExec=vesc_tool\nType=Application\nIcon=vesc_tool\nCategories=Utility;\n' > AppDir/usr/share/applications/vesc_tool.desktop
          # Run linuxdeploy with the Qt plugin
          curl -fLs -o linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
          curl -fLs -o linuxdeploy-plugin-qt https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
          chmod +x linuxdeploy linuxdeploy-plugin-qt
          ./linuxdeploy --appdir AppDir --plugin qt --output appimage
          mv VESC*AppImage "vesc_tool-${PACKAGE_VERSION}-qt6.AppImage" || \
            mv *AppImage "vesc_tool-${PACKAGE_VERSION}-qt6.AppImage"
      - name: Upload Release
        uses: svenstaro/upload-release-action@v2
        with:
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          file: vesc_tool-${{ steps.GetVersion.outputs.VERSION }}-qt6.AppImage
          asset_name: vesc_tool-${{ steps.GetVersion.outputs.VERSION }}-qt6.AppImage
          tag: ${{ steps.GetVersion.outputs.VERSION }}
          release_name: Release ${{ steps.GetVersion.outputs.VERSION }}
          overwrite: true
          prerelease: ${{ inputs.prerelease }}
```

- [ ] **Step 2: Validate YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/linux-qt6.yml'))" && echo OK
```

- [ ] **Step 3: Commit on `ci`**

```bash
cd /Users/litao/Developer/vesc_tool-ci
git add .github/workflows/linux-qt6.yml
git commit -m "CI: add Linux Qt6 release workflow

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 4: Trigger and verify green**

```bash
git push
gh workflow run linux-qt6.yml -f vt_ver=qt6-port -f fw_ver=master -f prerelease=true
sleep 5
gh run list --workflow=linux-qt6.yml --limit 1
gh run watch <run-id>
```
If it fails, read `gh run view <run-id> --log-failed`, fix the YAML or packaging step, recommit, re-trigger. Iterate until green. Repeat until the `linux-qt6` workflow run is green.

---

## Task 3: `mac-qt6.yml` (x86_64)

**Files:**
- Create: `.github/workflows/mac-qt6.yml` (on `ci`)

- [ ] **Step 1: Write the file**

Use the common shape with this per-platform body:

```yaml
    runs-on: macos-15
    steps:
      # ... common pre-build steps ...
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable
      - name: Install Qt 6.8.3 (macOS desktop)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: mac
          target: desktop
          arch: clang_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
          cache: 'true'
          cache-key-prefix: install-qt-action-qt6
      # ... FW artifact download ...
      - name: Configure
        run: >
          cmake -S . -B build
          -DCMAKE_BUILD_TYPE=Release
          -DCMAKE_OSX_ARCHITECTURES=x86_64
      - name: Build
        run: cmake --build build --parallel
      - name: Package DMG
        run: |
          "$Qt6_DIR/bin/macdeployqt" "build/VESC Tool.app" -qmldir=mobile -dmg
          mv "build/VESC Tool.dmg" "VESC_Tool-${PACKAGE_VERSION}-mac-qt6.dmg"
      - name: Upload Release
        uses: svenstaro/upload-release-action@v2
        with:
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          file: VESC_Tool-${{ steps.GetVersion.outputs.VERSION }}-mac-qt6.dmg
          asset_name: VESC_Tool-${{ steps.GetVersion.outputs.VERSION }}-mac-qt6.dmg
          tag: ${{ steps.GetVersion.outputs.VERSION }}
          release_name: Release ${{ steps.GetVersion.outputs.VERSION }}
          overwrite: true
          prerelease: ${{ inputs.prerelease }}
```

- [ ] **Step 2: YAML validity**
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/mac-qt6.yml'))" && echo OK
```

- [ ] **Step 3: Commit on `ci`**
```bash
git add .github/workflows/mac-qt6.yml
git commit -m "CI: add macOS x86_64 Qt6 release workflow

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 4: Trigger and verify green** (same pattern as Task 2 Step 4 but `gh workflow run mac-qt6.yml ...`).

---

## Task 4: `mac-arm64-qt6.yml` and `mac-universal-qt6.yml`

**Files:**
- Create: `.github/workflows/mac-arm64-qt6.yml`
- Create: `.github/workflows/mac-universal-qt6.yml`

Both copy the structure of `mac-qt6.yml` from Task 3, differing only in:
- **`mac-arm64-qt6.yml`**: `-DCMAKE_OSX_ARCHITECTURES=arm64`; artifact name `*-mac-arm64-qt6.dmg`. Runs on `macos-15` (arm64 hardware).
- **`mac-universal-qt6.yml`**: `-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"`; artifact name `*-mac-universal-qt6.dmg`. Same runner.

> Important: Qt 6.8.3 mac arch from `install-qt-action` is `clang_64` and supports universal output via the `-DCMAKE_OSX_ARCHITECTURES` flag. If a universal build fails because the Qt frameworks themselves are single-arch, fall back to `lipo`-merging two single-arch builds — but try the simple `CMAKE_OSX_ARCHITECTURES` approach first.

- [ ] **Step 1: Create both files**

(Copy `mac-qt6.yml` to each, change the three places noted above.)

- [ ] **Step 2: Validate YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/mac-arm64-qt6.yml'))" && \
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/mac-universal-qt6.yml'))" && echo OK
```

- [ ] **Step 3: Commit on `ci`**
```bash
git add .github/workflows/mac-arm64-qt6.yml .github/workflows/mac-universal-qt6.yml
git commit -m "CI: add macOS arm64 + universal Qt6 release workflows

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 4: Trigger and verify both green** — one `gh workflow run` per workflow. Iterate until both green. If the universal build is impractical, document the failure and fall back to a `lipo` merge of two single-arch outputs.

---

## Task 5: `win-qt6.yml` (MSVC)

**Files:**
- Create: `.github/workflows/win-qt6.yml` (on `ci`)

- [ ] **Step 1: Write the file**

Per-platform body:

```yaml
    runs-on: windows-2022
    steps:
      # ... common pre-build steps ...
      - name: Install Qt 6.8.3 (Windows MSVC)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: windows
          target: desktop
          arch: win64_msvc2022_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
          cache: 'true'
          cache-key-prefix: install-qt-action-qt6
      - name: Enable MSVC environment
        uses: ilammy/msvc-dev-cmd@v1
      # ... FW artifact download ...
      - name: Configure
        run: cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
      - name: Build
        run: cmake --build build --parallel
      - name: Package (windeployqt + zip)
        shell: pwsh
        run: |
          $stage = "VESC_Tool-$env:PACKAGE_VERSION-qt6"
          New-Item -ItemType Directory -Path $stage | Out-Null
          Copy-Item build\vesc_tool*.exe (Join-Path $stage "VESC_Tool.exe")
          & "$env:Qt6_DIR\bin\windeployqt.exe" --qmldir mobile (Join-Path $stage "VESC_Tool.exe")
          Compress-Archive -Path "$stage\*" -DestinationPath "$stage.zip"
      - name: Upload Release
        uses: svenstaro/upload-release-action@v2
        with:
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          file: VESC_Tool-${{ steps.GetVersion.outputs.VERSION }}-qt6.zip
          asset_name: VESC_Tool-${{ steps.GetVersion.outputs.VERSION }}-qt6.zip
          tag: ${{ steps.GetVersion.outputs.VERSION }}
          release_name: Release ${{ steps.GetVersion.outputs.VERSION }}
          overwrite: true
          prerelease: ${{ inputs.prerelease }}
```

> Ship a `.zip` (executable + windeployqt dependencies). If the upstream Qt5 pipeline ships an NSIS installer instead, follow its lead and add an NSIS step using the same `.nsi` script the Qt5 win.yml uses (locate it in `.workflow-src/.github/scripts/`).

- [ ] **Step 2: YAML validity, Step 3: Commit, Step 4: Trigger + iterate** — same pattern as Tasks 2–4.

---

## Task 6: `android-qt6.yml`

**Files:**
- Create: `.github/workflows/android-qt6.yml` (on `ci`)

Adapts the Phase 4 verification CI's `android` job into a release-publishing flow.

- [ ] **Step 1: Write the file**

Per-platform body:

```yaml
    runs-on: ubuntu-22.04
    steps:
      # ... common pre-build steps ...
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - name: Install Android NDK 26.1.10909125 (Qt 6.8 requirement)
        run: |
          set -e
          yes | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null
          "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" \
            "ndk;26.1.10909125" "platforms;android-34" "build-tools;34.0.0"
          echo "ANDROID_NDK_ROOT=$ANDROID_SDK_ROOT/ndk/26.1.10909125" >> "$GITHUB_ENV"
      - name: Install Qt 6.8.3 (host linux desktop)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: linux
          target: desktop
          arch: linux_gcc_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
          cache: 'true'
          cache-key-prefix: install-qt-action-qt6
      - name: Capture host Qt path
        run: echo "QT_HOST_PATH=$QT_ROOT_DIR" >> "$GITHUB_ENV"
      - name: Install Qt 6.8.3 (Android arm64)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: linux
          target: android
          arch: android_arm64_v8a
          modules: qt5compat qtconnectivity qtpositioning qt3d qtquick3d qtshadertools qtimageformats
          cache: 'true'
          cache-key-prefix: install-qt-action-qt6-android
      # ... FW artifact download ...
      - name: Configure
        run: >
          cmake -S . -B build
          -DCMAKE_TOOLCHAIN_FILE=$QT_ROOT_DIR/lib/cmake/Qt6/qt.toolchain.cmake
          -DQT_HOST_PATH=$QT_HOST_PATH
          -DCMAKE_BUILD_TYPE=Release
          -DANDROID_ABI=arm64-v8a
          -DANDROID_PLATFORM=android-23
          -DANDROID_SDK_ROOT=$ANDROID_SDK_ROOT
          -DANDROID_NDK=$ANDROID_NDK_ROOT
      - name: Build (parallelism capped to avoid OOM)
        run: cmake --build build --parallel 2
      - name: Locate APK and rename
        run: |
          APK=$(find build -path '*/android-build/*' -name '*.apk' | head -1)
          test -n "$APK"
          cp "$APK" "VESC_Tool-${PACKAGE_VERSION}-android-qt6.apk"
      - name: Upload Release
        uses: svenstaro/upload-release-action@v2
        with:
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          file: VESC_Tool-${{ steps.GetVersion.outputs.VERSION }}-android-qt6.apk
          asset_name: VESC_Tool-${{ steps.GetVersion.outputs.VERSION }}-android-qt6.apk
          tag: ${{ steps.GetVersion.outputs.VERSION }}
          release_name: Release ${{ steps.GetVersion.outputs.VERSION }}
          overwrite: true
          prerelease: ${{ inputs.prerelease }}
```

> The APK is **unsigned** (matches the current Phase 4 build). If the existing Qt5 Android workflow signs the APK with a fork keystore, add the equivalent signing step here using the same secret/keystore as that workflow.

- [ ] **Step 2: YAML validity, Step 3: Commit, Step 4: Trigger + iterate**.

---

## Task 7: `ios-qt6.yml`

**Files:**
- Create: `.github/workflows/ios-qt6.yml` (on `ci`)

Adapts the Phase 4 iOS verification CI into a release-publishing flow.

- [ ] **Step 1: Write the file**

Per-platform body:

```yaml
    runs-on: macos-15
    steps:
      # ... common pre-build steps ...
      - name: Select Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable
      - name: Install Qt 6.8.3 (host macOS desktop)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: mac
          target: desktop
          arch: clang_64
          modules: qt5compat qtconnectivity qtserialport qtpositioning qt3d qtquick3d qtshadertools qtimageformats
          cache: 'true'
          cache-key-prefix: install-qt-action-qt6
      - name: Capture host Qt path
        run: echo "QT_HOST_PATH=$QT_ROOT_DIR" >> "$GITHUB_ENV"
      - name: Install Qt 6.8.3 (iOS)
        uses: jurplel/install-qt-action@v4
        with:
          version: 6.8.3
          host: mac
          target: ios
          arch: ios
          modules: qt5compat qtconnectivity qtpositioning qt3d qtquick3d qtshadertools qtimageformats
          cache: 'true'
          cache-key-prefix: install-qt-action-qt6-ios
      # ... FW artifact download ...
      - name: Configure
        run: >
          cmake -S . -B build -G Xcode
          -DCMAKE_TOOLCHAIN_FILE=$QT_ROOT_DIR/lib/cmake/Qt6/qt.toolchain.cmake
          -DQT_HOST_PATH=$QT_HOST_PATH
          -DCMAKE_BUILD_TYPE=Release
      - name: Build (unsigned simulator, matches Phase 4 bar)
        run: >
          cmake --build build --config Release --
          -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO
      - name: Package .app -> .zip
        run: |
          APP="build/Release-iphonesimulator/VESC Tool.app"
          test -d "$APP"
          ditto -c -k --sequesterRsrc --keepParent "$APP" \
            "VESC_Tool-${PACKAGE_VERSION}-ios-simulator-qt6.zip"
      - name: Upload Release
        uses: svenstaro/upload-release-action@v2
        with:
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          file: VESC_Tool-${{ steps.GetVersion.outputs.VERSION }}-ios-simulator-qt6.zip
          asset_name: VESC_Tool-${{ steps.GetVersion.outputs.VERSION }}-ios-simulator-qt6.zip
          tag: ${{ steps.GetVersion.outputs.VERSION }}
          release_name: Release ${{ steps.GetVersion.outputs.VERSION }}
          overwrite: true
          prerelease: ${{ inputs.prerelease }}
```

> The iOS artifact is an **unsigned simulator build**, matching the spec. A device-installable IPA needs proper code signing + provisioning, which is intentionally out of scope.

- [ ] **Step 2: YAML validity, Step 3: Commit, Step 4: Trigger + iterate**.

---

## Task 8: Extend `createRelease.yml` to invoke the Qt6 jobs

**Files:**
- Modify: `.github/workflows/createRelease.yml` (on `ci`)

- [ ] **Step 1: Identify how Qt5 jobs are currently invoked**

Read `createRelease.yml` and find where each Qt5 platform workflow is dispatched (likely via `workflows/<name>` step calls or a `workflow_run` chain at the bottom of `createRelease.yml`, or via `gh workflow run` inside a `run:` step). Reproduce the same pattern for the seven new `*-qt6.yml` workflows. Pass the same `vt_ver`/`fw_ver`/`release_notes`/`prerelease` inputs, except `vt_ver` is hard-coded to `qt6-port` (or pass through if the orchestrator accepts a separate Qt6 ref).

- [ ] **Step 2: Add the seven Qt6 invocations alongside the Qt5 ones.**

Keep the Qt5 invocations unchanged.

- [ ] **Step 3: YAML validity**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/createRelease.yml'))" && echo OK
```

- [ ] **Step 4: Commit and trigger an end-to-end release dispatch**

```bash
git add .github/workflows/createRelease.yml
git commit -m "CI: orchestrate Qt5 + Qt6 dual release

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
gh workflow run createRelease.yml -f vt_ver=master -f fw_ver=master -f prerelease=true
gh run watch <run-id>
```

- [ ] **Step 5: Verify both sets of artifacts on the resulting GitHub Release**

```bash
gh release view <version> --json assets --jq '.assets[].name'
```
Expected: the Release contains the Qt5 artifacts (current names) AND the Qt6 artifacts (with `-qt6` in the name) for every platform that succeeded.

---

## Task 9: Verification note

**Files:**
- Create: `docs/superpowers/plans/2026-05-19-phase5-verification.md` (on `qt6-port`, alongside the rest of the port docs)

- [ ] **Step 1: Write the verification note**

Record: the run IDs / URLs of each Qt6 workflow's first green run, the end-to-end `createRelease.yml` dispatch result and the resulting Release's asset list, any per-platform packaging choices made (e.g. Windows zip vs NSIS), any platforms where the artifact required a fallback approach, and any items intentionally out of scope (e.g. iOS device signing).

- [ ] **Step 2: Commit and push the note on `qt6-port`**

```bash
cd /Users/litao/Developer/vesc_tool
git add docs/superpowers/plans/2026-05-19-phase5-verification.md
git commit -m "Phase 5: verify Qt5+Qt6 dual-release CI

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
git push
```

---

## Phase 5 Done — Definition of Done

- [ ] All seven `*-qt6.yml` workflows have at least one green run on `ci`.
- [ ] `createRelease.yml` invokes the seven new Qt6 workflows alongside the existing Qt5 ones.
- [ ] An end-to-end `createRelease.yml` dispatch produces a single GitHub Release containing both Qt5 and Qt6 artifacts (with disambiguated names) for every platform.
- [ ] No Qt5 workflow has been touched in a way that regresses the existing pipeline.
- [ ] No application source code has been modified.

**Next:** the only remaining deferred item is re-adding gamepad support via SDL2 (a separate piece of work).
