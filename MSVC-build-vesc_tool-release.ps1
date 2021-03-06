#-----------------------------------------------------------------------------
#
#  Copyright (c) 2019, LI Tao
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
#  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
#  THE POSSIBILITY OF SUCH DAMAGE.
#
#-----------------------------------------------------------------------------

<#
 .SYNOPSIS

  Build a static version of Qt for Windows.

 .DESCRIPTION

  This scripts downloads Qt source code, compiles and installs a static version
  of Qt. It assumes that a prebuilt Qt / MSVC environment is already installed,
  typically in C:\Qt. This prebuilt environment uses shared libraries. It is
  supposed to remain the main development environment for Qt. This script adds
  a static version of the Qt libraries in order to allow the construction of
  standalone and self-sufficient executable.

  This script is typically run from the Windows Explorer.

  Requirements:
  - Windows 10
  - Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  - vs2019 C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional
  - Qt C:\Qt\Qt5.12.3
  - 7-zip.
  - Open PowerShell Run "powershell.exe .\MSVC-build-vesc_tool-release.ps1"
 .PARAMETER QtRoot

  Qt root. By default, C:\Qt

 .PARAMETER QtVersion

  The Qt version. By default, this script tries to extract the version number
  from the Qt source file name.

 .PARAMETER QtToolsDir

  The Qt tools path. By default, $QtRoot\Tools.

 .PARAMETER NumJobs

  The number of jobs to run jom.exe with. Use your # CPU cores or higher. Default 8.

 .PARAMETER MSVC

  Imports command prompt environment for this MSVC.  Default 2012

 .PARAMETER Arch

  Set to x64 to compile with MSVC 64-bit.  Default: x64

 .PARAMETER NoPause

  Do not wait for the user to press <enter> at end of execution. By default,
  execute a "pause" instruction at the end of execution, which is useful
  when the script was run from Windows Explorer.
#>

[CmdletBinding()]
param(
    $QtVersion = "5.12.7",
    $QtRoot = "C:\Qt",
    $QtToolsDir = "$QtRoot\Qt$QtVersion\Tools",
    $QtCreatorDir = "$QtToolsDir\QtCreator",
    $NumJobs = 8,
    $MSVC = 2017,
    $Arch = "x64",
    [switch]$NoPause = $true
)

# PowerShell execution policy.
Set-StrictMode -Version 3

#Import-Module Pscx

#-----------------------------------------------------------------------------
# Main code
#-----------------------------------------------------------------------------

function Main
{
    Write-Output "Building vesc tool Qt version:   $QtVersion"

    # Qt installation directory.
    $QtDir = "$QtRoot\Qt$QtVersion\$QtVersion"
    # Initialize Visual Studio environment

    $VTVer = Select-String -Path vesc_tool.pro -Pattern 'VT_VERSION\s=\s(.*)' | %{$_.Matches.Groups[1].value}
    $BuildName = ""

    if ($Arch -eq "x86") {
        $BuildName = "msvc${MSVC}"
    }
    elseif ($Arch -eq "x64") {
        $BuildName = "msvc${MSVC}_64"
    }
    else {
        Exit-Script "Not a valid Arch flag. Options: x86, amd64"
    }

    # Set-VsVars $MSVC $Arch
    Set-VsVars 2019 $Arch

    Write-Output "Build                  : $BuildName"

    $VTInstallDir = "build\win"
    Write-Output "Install Location       : $VTInstallDir"
    Write-Output "VESC Tool Version      : $VTVer"

    # Set a clean path.
    $env:Path = "$QtDir\$BuildName\bin;$QtToolsDir\QtCreator\bin;$env:Path"

    # Force English locale to avoid weird effects of tools localization.
    $env:LANG = "en"

    Remove-Item -Force -Recurse $VTInstallDir\* -ErrorAction Ignore

    # Build-VESCTool original
    Build-VESCTool platinum
    # Build-VESCTool gold
    # Build-VESCTool silver
    # Build-VESCTool bronze
    # Build-VESCTool free

    Exit-Script
}

#-----------------------------------------------------------------------------
# A function to exit this script. The Message parameter is used on error.
#-----------------------------------------------------------------------------

function Exit-Script ([string]$Message = "")
{
    $Code = 0
    if ($Message -ne "") {
        Write-Output "ERROR: $Message"
        $Code = 1
    }
    if (-not $NoPause) {
        pause
    }
    exit $Code
}

#-----------------------------------------------------------------------------
# Silently create a directory.
#-----------------------------------------------------------------------------

function Create-Directory ([string]$Directory)
{
    [void] (New-Item -Path $Directory -ItemType "directory" -Force)
}

#-----------------------------------------------------------------------------
# Download a file if not yet present.
# Warning: If file is present but incomplete, do not download it again.
#-----------------------------------------------------------------------------

function Download-File ([string]$Url, [string]$OutputFile)
{
    $FileName = Split-Path $Url -Leaf
    if (-not (Test-Path $OutputFile)) {
        # Local file not present, start download.
        Write-Output "Downloading $Url ..."
        try {
            $webclient = New-Object System.Net.WebClient
            $webclient.DownloadFile($Url, $OutputFile)
        }
        catch {
            # Display exception.
            $_
            # Delete partial file, if any.
            if (Test-Path $OutputFile) {
                Remove-Item -Force $OutputFile
            }
            # Abort
            Exit-Script "Error downloading $FileName"
        }
        # Check that the file is present.
        if (-not (Test-Path $OutputFile)) {
            Exit-Script "Error downloading $FileName"
        }
    }
}

#-----------------------------------------------------------------------------
# Get path name of 7zip, abort if not found.
#-----------------------------------------------------------------------------

function Get-7zip
{
    $Exe = "C:\Program Files\7-Zip\7z.exe"
    if (-not (Test-Path $Exe)) {
        $Exe = "C:\Program Files (x86)\7-Zip\7z.exe"
    }
    if (-not (Test-Path $Exe)) {
        Exit-Script "7-zip not found, install it first, see http://www.7-zip.org/"
    }
    $Exe
}

#-----------------------------------------------------------------------------
# Expand an archive file if not yet done.
#-----------------------------------------------------------------------------

function Expand-Archive ([string]$ZipFile, [string]$OutDir, [string]$CheckFile)
{
    # Check presence of expected expanded file or directory.
    if (-not (Test-Path $CheckFile)) {
        Write-Output "Expanding $ZipFile ..."
        & (Get-7zip) x $ZipFile "-o$OutDir" | Select-String -Pattern "^Extracting " -CaseSensitive -NotMatch
        if (-not (Test-Path $CheckFile)) {
            Exit-Script "Error expanding $ZipFile, $OutDir\$CheckFile not found"
        }
    }
}

function Get-Batchfile ($file, $params)
{
    $cmd = "`"$file`" $params & set"
    cmd /c $cmd | Foreach-Object {
        $p, $v = $_.split('=')
        Set-Item -path env:$p -value $v
    }
}


function Set-VsVars($vsYear, $arch)
{
    $vstools = ""

    switch ($vsYear)
    {
        2015 { $vstools = "$env:VS140COMNTOOLS\..\..\vc\vcvarsall.bat" }
        2017 { $vstools = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvarsall.bat" }
        2019 { $vstools = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvarsall.bat" }
    }

    #$batchFile = [System.IO.Path]::Combine($vstools, "vsvars32.bat")

    if (-not (Test-Path $vstools)) {
        Exit-Script "Visual Studio environment could not be found."
    }

    Get-Batchfile -file $vstools -params $arch


    Write-Host -ForegroundColor 'Yellow' "VsVars has been loaded from: $vstools ($arch)"
}

function Build-VESCTool ([string]$type)
{
    # qmake -config release -tp vc "CONFIG+=release_win build_$type" -o $VTInstallDir\vesc_tool.vcxproj

    qmake -config release "CONFIG+=release_win build_$type"
    jom clean
    jom -j $NumJobs

    # msbuild $VTInstallDir\vesc_tool.vcxproj /Zm:1000 /t:Build /p:Configuration=Release
    Remove-Item -Path $VTInstallDir\obj -Force -Recurse -ErrorAction Ignore

    Push-Location $VTInstallDir
    $DeployDir="vesc_tool_" + $type + "-win"
    $ZipFile=$DeployDir + ".zip"
    # Create-Directory $DeployDir

    $VTApp = "vesc_tool_" + ${VTVer} + ".exe"
    windeployqt $VTApp -qmldir=. --dir $DeployDir
    Move-Item $VTApp $DeployDir
    Compress-Archive $DeployDir -DestinationPath $ZipFile

    Remove-Item * -Exclude *.zip -Recurse -ErrorAction Ignore
    # Remove-Item * -Include *.exe, *.dll -Exclude *.zip -Recurse -ErrorAction Ignore
    Pop-Location
}

#-----------------------------------------------------------------------------
# Execute main code.
#-----------------------------------------------------------------------------

. Main
