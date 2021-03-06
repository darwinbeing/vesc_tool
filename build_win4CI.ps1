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

  This scripts compiles and installs vesc tool. It assumes that a prebuilt
  Qt / MSVC environment is already installed, typically in C:\Qt. This prebuilt
  environment uses shared libraries.

  This script is typically run from the Windows Explorer.

  Requirements:
  - Windows 10
  - Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  - vs2019 C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional
  - Qt C:\Qt\Qt5.12.3
  - 7-zip.
  - Open PowerShell Run "powershell.exe .\MSVC-build-vesc_tool-release.ps1"
 .PARAMETER NumJobs

  The number of jobs to run jom.exe with. Use your # CPU cores or higher. Default 8.

 .PARAMETER MSVC

  Imports command prompt environment for this MSVC.  Default 2017

 .PARAMETER Arch

  Set to amd64/x64 to compile with MSVC 64-bit.  Default: x64

 .PARAMETER NoPause

  Do not wait for the user to press <enter> at end of execution. By default,
  execute a "pause" instruction at the end of execution, which is useful
  when the script was run from Windows Explorer.
#>

[CmdletBinding()]
param(
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
    # Initialize Visual Studio environment

    $VTVer = Select-String -Path vesc_tool.pro -Pattern 'VT_VERSION\s=\s(.*)' | %{$_.Matches.Groups[1].value}

    Set-VsVars $MSVC $Arch

    $VTInstallDir = "build\win"
    Write-Output "Install Location       : $VTInstallDir"
    Write-Output "VESC Tool Version      : $VTVer"

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
        2017 { $vstools = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" }
        2019 { $vstools = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" }
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
