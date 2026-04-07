$ErrorActionPreference = "Stop"

if (-not $env:VT_VER) {
    throw "VT_VER is required"
}

if (-not $env:PACKAGE_VERSION) {
    throw "PACKAGE_VERSION is required"
}

$PatchRoot = if ($env:PATCH_ROOT) { $env:PATCH_ROOT } else { ".workflow-src/patches" }

if ($env:VT_VER -match '^\d+\.\d+$') {
    $PatchVersion = $env:VT_VER
} elseif ($env:VT_VER -eq "master") {
    $PatchVersion = "master"
} else {
    $PatchVersion = $env:PACKAGE_VERSION
}

$PatchFile = Join-Path $PatchRoot "$PatchVersion/vesc_tool.patch"

if (-not (Test-Path $PatchFile)) {
    throw "Patch file not found: $PatchFile"
}

Write-Host "Applying patch: $PatchFile"
git apply --check "$PatchFile"
git apply "$PatchFile"
