# CI Release Layered Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the monolithic per-version `vesc_tool.patch` into a never-conflicting overlay layer plus a minimal source patch, and add a PR gate that validates patches before release.

**Architecture:** CI-specific build scripts move into `.github/overlay/` in the `ci` branch and are copied into the checked-out upstream tree at build time (overlay layer). The patch keeps only genuine source modifications (patch layer). A new workflow runs `git apply --check` for every version on every PR (validation layer).

**Tech Stack:** GitHub Actions, Bash, PowerShell, `git apply`.

**Scope:** Phase 1 only — `master` version path is fully reworked; other versions' patches are left as-is and surfaced as broken by the new validation workflow. Phase 2 (reusable workflow / matrix consolidation) is out of scope for this plan.

**Working branch:** `ci`. All commits land on `ci`.

---

### Task 1: Extract overlay build scripts from the patched master tree

The 7 build scripts the current patch creates or modifies become standalone, fully-owned files under `.github/overlay/`. They are extracted from the *result* of applying the (already-fixed) `patches/master/vesc_tool.patch` to a clean `master`, so they exactly reflect today's intended behavior.

**Files:**
- Create: `.github/overlay/build_lin4CI`
- Create: `.github/overlay/build_macos4CI`
- Create: `.github/overlay/build_win4CI.ps1`
- Create: `.github/overlay/build_macos_arm64`
- Create: `.github/overlay/build_macos_universal`
- Create: `.github/overlay/build_android_macOS`
- Create: `.github/overlay/build_ios.sh`

- [ ] **Step 1: Create a clean master worktree and apply the current patch**

```bash
cd /Users/litao/Developer/vesc_tool
git worktree add /tmp/vt_overlay master
git -C /tmp/vt_overlay clean -qfd
git -C /tmp/vt_overlay apply /Users/litao/Developer/vesc_tool/patches/master/vesc_tool.patch
```

Expected: no output (patch applies cleanly — it was fixed in commit 864d64b).

- [ ] **Step 2: Copy the build scripts into the overlay directory**

```bash
cd /Users/litao/Developer/vesc_tool
mkdir -p .github/overlay
cp /tmp/vt_overlay/build_lin            .github/overlay/build_lin4CI
cp /tmp/vt_overlay/build_macos          .github/overlay/build_macos4CI
cp /tmp/vt_overlay/build_win4CI.ps1     .github/overlay/build_win4CI.ps1
cp /tmp/vt_overlay/build_macos_arm64    .github/overlay/build_macos_arm64
cp /tmp/vt_overlay/build_macos_universal .github/overlay/build_macos_universal
cp /tmp/vt_overlay/build_android_macOS  .github/overlay/build_android_macOS
cp /tmp/vt_overlay/build_ios.sh         .github/overlay/build_ios.sh
chmod +x .github/overlay/build_lin4CI .github/overlay/build_macos4CI \
         .github/overlay/build_macos_arm64 .github/overlay/build_macos_universal \
         .github/overlay/build_android_macOS .github/overlay/build_ios.sh
```

- [ ] **Step 3: Verify all 7 files exist and are non-empty**

Run: `ls -la .github/overlay/ && wc -l .github/overlay/*`
Expected: 7 files listed, each with a non-zero line count.

- [ ] **Step 4: Commit**

```bash
git add .github/overlay/
git commit -m "$(printf 'Add CI build scripts as overlay layer\n\nCo-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>')"
```

---

### Task 2: Slim `patches/master/vesc_tool.patch` to source-only changes

Remove every build-script hunk (5 created files + 2 modified scripts) so the patch contains only genuine source modifications. Regenerated deterministically from the patched worktree.

**Files:**
- Modify: `patches/master/vesc_tool.patch`

- [ ] **Step 1: In the patched worktree, revert the modified build scripts and delete the created ones**

```bash
git -C /tmp/vt_overlay checkout -- build_lin build_macos
rm /tmp/vt_overlay/build_android_macOS /tmp/vt_overlay/build_ios.sh \
   /tmp/vt_overlay/build_macos_arm64 /tmp/vt_overlay/build_macos_universal \
   /tmp/vt_overlay/build_win4CI.ps1
```

Expected: no output. The worktree now holds only the 11 source-file modifications.

- [ ] **Step 2: Regenerate the patch from the remaining diff**

```bash
git -C /tmp/vt_overlay diff > /Users/litao/Developer/vesc_tool/patches/master/vesc_tool.patch
```

- [ ] **Step 3: Verify the slimmed patch contains no build-script hunks**

Run: `grep -c '^diff --git' patches/master/vesc_tool.patch && grep -E '^diff --git.*(build_|\.ps1)' patches/master/vesc_tool.patch || echo "NO BUILD HUNKS"`
Expected: count is `11`, followed by `NO BUILD HUNKS`.

- [ ] **Step 4: Verify the slimmed patch applies cleanly on clean master**

```bash
git worktree add /tmp/vt_verify master
git -C /tmp/vt_verify clean -qfd
git -C /tmp/vt_verify apply --check --verbose /Users/litao/Developer/vesc_tool/patches/master/vesc_tool.patch
```

Expected: each hunk reports `Checking patch ...` / `Hunk #N succeeded`, no `error:` lines.

- [ ] **Step 5: Clean up worktrees**

```bash
git worktree remove /tmp/vt_overlay --force
git worktree remove /tmp/vt_verify --force
```

- [ ] **Step 6: Commit**

```bash
git add patches/master/vesc_tool.patch
git commit -m "$(printf 'Slim master patch to source-only changes\n\nBuild scripts now live in .github/overlay/ and are copied in at\nbuild time instead of being created/modified by the patch.\n\nCo-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>')"
```

---

### Task 3: Create the overlay copy scripts

Two scripts copy `.github/overlay/*` from the `.workflow-src` checkout into the build tree — one for Bash runners, one for the Windows PowerShell runner.

**Files:**
- Create: `.github/scripts/overlay_files.sh`
- Create: `.github/scripts/overlay_files.ps1`

- [ ] **Step 1: Write `.github/scripts/overlay_files.sh`**

```bash
#!/usr/bin/env bash

set -euo pipefail

OVERLAY_DIR="${OVERLAY_DIR:-.workflow-src/.github/overlay}"

if [[ ! -d "${OVERLAY_DIR}" ]]; then
  echo "Overlay directory not found: ${OVERLAY_DIR}" >&2
  exit 1
fi

echo "Overlaying CI build scripts from ${OVERLAY_DIR}"

for f in "${OVERLAY_DIR}"/*; do
  name="$(basename "${f}")"
  cp -v "${f}" "./${name}"
  case "${name}" in
    *.ps1) ;;
    *) chmod +x "./${name}" ;;
  esac
done
```

- [ ] **Step 2: Write `.github/scripts/overlay_files.ps1`**

```powershell
$ErrorActionPreference = "Stop"

$OverlayDir = if ($env:OVERLAY_DIR) { $env:OVERLAY_DIR } else { ".workflow-src/.github/overlay" }

if (-not (Test-Path $OverlayDir)) {
    throw "Overlay directory not found: $OverlayDir"
}

Write-Host "Overlaying CI build scripts from $OverlayDir"

Get-ChildItem -Path $OverlayDir -File | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path "." $_.Name) -Force
    Write-Host "  copied $($_.Name)"
}
```

- [ ] **Step 3: Verify the bash script works locally**

```bash
git worktree add /tmp/vt_ov_test master
git -C /tmp/vt_ov_test clean -qfd
mkdir -p /tmp/vt_ov_test/.workflow-src/.github
cp -r .github/overlay /tmp/vt_ov_test/.workflow-src/.github/overlay
( cd /tmp/vt_ov_test && bash /Users/litao/Developer/vesc_tool/.github/scripts/overlay_files.sh )
ls -la /tmp/vt_ov_test/build_lin4CI /tmp/vt_ov_test/build_win4CI.ps1
git worktree remove /tmp/vt_ov_test --force
```

Expected: `overlay_files.sh` prints `copied`/`cp` lines; `build_lin4CI` exists and is executable (`-rwxr-xr-x`), `build_win4CI.ps1` exists.

- [ ] **Step 4: Commit**

```bash
git add .github/scripts/overlay_files.sh .github/scripts/overlay_files.ps1
git commit -m "$(printf 'Add overlay copy scripts for bash and PowerShell runners\n\nCo-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>')"
```

---

### Task 4: Wire the Overlay step into the platform workflows

Every workflow gains an `Overlay Build Scripts` step immediately before `Apply Patch`. `linux.yml` switches `./build_lin` → `./build_lin4CI` and drops `continue-on-error`. `mac.yml` switches `./build_macos` → `./build_macos4CI`.

**Files:**
- Modify: `.github/workflows/linux.yml`
- Modify: `.github/workflows/mac.yml`
- Modify: `.github/workflows/mac-arm64.yml`
- Modify: `.github/workflows/mac-universal.yml`
- Modify: `.github/workflows/win.yml`
- Modify: `.github/workflows/android.yml`
- Modify: `.github/workflows/android2.yml`
- Modify: `.github/workflows/ios.yml`

- [ ] **Step 1: Add the Overlay step to every bash-based workflow**

In each of `linux.yml`, `mac.yml`, `mac-arm64.yml`, `mac-universal.yml`, `android.yml`, `android2.yml`, `ios.yml`, insert this step directly **before** the existing `- name: Apply Patch` step (match its indentation — steps are indented 6 spaces):

```yaml
      - name: Overlay Build Scripts
        run: |
          bash .workflow-src/.github/scripts/overlay_files.sh
        shell: bash
```

- [ ] **Step 2: Add the Overlay step to `win.yml`**

In `win.yml`, insert directly **before** the `- name: Apply Patch` step:

```yaml
      - name: Overlay Build Scripts
        run: |
          .\.workflow-src\.github\scripts\overlay_files.ps1
        shell: pwsh
```

- [ ] **Step 3: Switch `linux.yml` to `build_lin4CI` and remove `continue-on-error`**

In `.github/workflows/linux.yml`, find the `Configure And Compile` step. Change:

```yaml
      - name: Configure And Compile
        continue-on-error: true
        run: |
            mkdir -p res/firmwares
            cp -rv ${{ env.FW_TMP_DIR }}/* res/firmwares/
            ./build_lin
```

to:

```yaml
      - name: Configure And Compile
        run: |
            mkdir -p res/firmwares
            cp -rv ${{ env.FW_TMP_DIR }}/* res/firmwares/
            ./build_lin4CI
```

- [ ] **Step 4: Switch `mac.yml` to `build_macos4CI`**

In `.github/workflows/mac.yml`, find the `./build_macos` invocation inside the `Configure And Compile` step and change it to `./build_macos4CI`. If that step also carries `continue-on-error: true`, remove that line.

- [ ] **Step 5: Verify no workflow still calls a removed/renamed script and YAML is valid**

```bash
grep -rnE '\./build_lin\b|\./build_macos\b' .github/workflows/ || echo "NO STALE BUILD CALLS"
python3 -c "import sys,glob,yaml; [yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.yml')]; print('YAML OK')"
```

Expected: `NO STALE BUILD CALLS` then `YAML OK`. (If `yaml` is missing, run `pip3 install pyyaml` first.)

- [ ] **Step 6: Verify every workflow has an Overlay step before Apply Patch**

```bash
for f in linux mac mac-arm64 mac-universal win android android2 ios; do
  o=$(grep -n 'Overlay Build Scripts' .github/workflows/$f.yml | cut -d: -f1)
  a=$(grep -n 'name: Apply Patch' .github/workflows/$f.yml | cut -d: -f1)
  if [[ -n "$o" && -n "$a" && "$o" -lt "$a" ]]; then echo "$f OK ($o<$a)"; else echo "$f FAIL (overlay=$o apply=$a)"; fi
done
```

Expected: all 8 workflows print `OK`.

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/
git commit -m "$(printf 'Overlay CI build scripts in workflows; drop continue-on-error\n\nWorkflows now copy build scripts from .github/overlay/ before\napplying the patch. linux/mac use the standalone build_lin4CI /\nbuild_macos4CI scripts. continue-on-error removed so a failed\npatch or build hard-fails instead of releasing unpatched code.\n\nCo-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>')"
```

---

### Task 5: Add the patch-validation workflow

A workflow that, on every PR/push touching `patches/**`, checks out each upstream branch and runs `git apply --check` against its patch. After Phase 1, `master` passes and the other 5 versions fail — which is the intended signal.

**Files:**
- Create: `.github/workflows/validate-patches.yml`

- [ ] **Step 1: Write `.github/workflows/validate-patches.yml`**

```yaml
name: Validate Patches

on:
  pull_request:
    paths:
      - 'patches/**'
  push:
    branches:
      - ci
    paths:
      - 'patches/**'
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-22.04
    strategy:
      fail-fast: false
      matrix:
        version: ["master", "3.01", "6.00", "6.02", "6.05", "6.06"]
    steps:
      - name: Checkout CI repo
        uses: actions/checkout@v4
        with:
          path: ci-repo

      - name: Resolve upstream ref
        id: ref
        run: |
          v="${{ matrix.version }}"
          if [[ "$v" == "master" ]]; then
            echo "REF=master" >> "$GITHUB_OUTPUT"
          else
            echo "REF=release_${v/./_}" >> "$GITHUB_OUTPUT"
          fi
        shell: bash

      - name: Checkout upstream source
        uses: actions/checkout@v4
        with:
          ref: ${{ steps.ref.outputs.REF }}
          path: src

      - name: git apply --check
        run: |
          patch="ci-repo/patches/${{ matrix.version }}/vesc_tool.patch"
          if [[ ! -f "$patch" ]]; then
            echo "Patch not found: $patch" >&2
            exit 1
          fi
          cd src
          git apply --check --verbose "../$patch"
        shell: bash
```

- [ ] **Step 2: Verify the workflow YAML is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/validate-patches.yml')); print('YAML OK')"
```

Expected: `YAML OK`.

- [ ] **Step 3: Verify the ref-resolution logic locally**

```bash
for v in master 3.01 6.00 6.02 6.05 6.06; do
  if [[ "$v" == "master" ]]; then ref="master"; else ref="release_${v/./_}"; fi
  echo "$v -> $ref"
done
```

Expected: `master -> master`, `3.01 -> release_3_01`, `6.00 -> release_6_00`, `6.02 -> release_6_02`, `6.05 -> release_6_05`, `6.06 -> release_6_06`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/validate-patches.yml
git commit -m "$(printf 'Add validate-patches workflow as a pre-release gate\n\nRuns git apply --check for every version patch against its\nupstream branch on every PR touching patches/. fail-fast is off\nso each version reports independently.\n\nCo-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>')"
```

---

### Task 6: Push and report

- [ ] **Step 1: Push the branch**

```bash
git push origin ci
```

- [ ] **Step 2: Report what remains for the user**

Summarize: Phase 1 complete. `master` build path uses overlay + slimmed patch. The `Validate Patches` workflow will show `master` green and `3.01/6.00/6.02/6.05/6.06` red — those are the known-broken versions to fix later (or to clean up the inconsistent `release_6_05`/`release_6_06` branches). Phase 2 (reusable workflow consolidation) is not done and can be planned separately.

---

## Notes for the implementer

- The `master` patch was already fixed in commit `864d64b`; Task 1/2 build on that fixed patch — do not re-fix it.
- `git apply` accepts plain `git diff` output (Task 2 Step 2), so the regenerated patch needs no `format-patch` header.
- Only `linux.yml` and `mac.yml` called the *modified* upstream scripts (`build_lin`, `build_macos`); the others already called *created* scripts (`build_macos_arm64`, `build_macos_universal`, `build_win4CI.ps1`) or `qmake` directly — those just need the Overlay step so the created scripts are present.
- Do not touch `patches/3.01|6.00|6.02|6.05|6.06/` — out of scope for Phase 1.
