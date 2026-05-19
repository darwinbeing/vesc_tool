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
