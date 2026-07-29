<#
.SYNOPSIS
    Builds World Keeper for Windows and packages it into an installer.

.DESCRIPTION
    Four steps, in order:

      1. `flutter build windows --release`
      2. Stage the Visual C++ runtime DLLs beside the executable, so the app runs on a
         machine that has never had Visual Studio or a redistributable installed.
      3. Read the version out of pubspec.yaml -- one source of truth, rather than a number
         in the installer script that drifts from the one in the About dialog.
      4. Compile installer\windows\world_keeper.iss with Inno Setup.

    The installer lands in `installer\out\`.

.PARAMETER SkipBuild
    Package whatever is already in build\windows\x64\runner\Release. Useful when
    iterating on the installer itself; wrong for anything you intend to hand out.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File installer\windows\build.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# This file is saved as UTF-8 *with* a BOM and is deliberately pure ASCII. Windows
# PowerShell 5.1 -- which is what `powershell -File` runs -- decodes a BOM-less script
# using the ANSI code page, and PowerShell's tokenizer accepts the smart quotes at 0x91
# to 0x94 as real string delimiters. So a UTF-8 em dash inside a double-quoted string
# arrives as three bytes, the last of which is a closing quote, and the string ends in
# the middle of a word. Everything after it shifts by one string, and the failure lands
# somewhere unrelated: what this cost the first time was "the variable '$pubspec' cannot
# be retrieved because it has not been set", pointing at a Write-Host line.

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$releaseDir = Join-Path $projectDir 'build\windows\x64\runner\Release'
$outDir = Join-Path $projectDir 'installer\out'

Write-Host "World Keeper -- Windows installer" -ForegroundColor Cyan
Write-Host "  project: $projectDir"

# ---------------------------------------------------------------- version

# Deliberately a narrow regex rather than a YAML parse: `version:` is the only top-level
# key that can match at column 0, and this script should not need a dependency.
$pubspec = Get-Content (Join-Path $projectDir 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?\s*$') {
    throw "Could not read `version:` from pubspec.yaml."
}
$appVersion = $Matches[1]
Write-Host "  version: $appVersion"

# ---------------------------------------------------------------- build

if ($SkipBuild) {
    Write-Host "  build:   skipped (-SkipBuild)" -ForegroundColor Yellow
    if (-not (Test-Path (Join-Path $releaseDir 'world_keeper.exe'))) {
        throw "-SkipBuild was passed but $releaseDir has no world_keeper.exe in it."
    }
} else {
    Write-Host "`n[1/4] flutter build windows --release" -ForegroundColor Cyan
    Push-Location $projectDir
    try {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)." }
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------- vc runtime

# Flutter's Windows embedder is compiled against the Visual C++ runtime and the build
# does not copy it. On a developer machine the app starts anyway, because Visual Studio
# put the DLLs in System32 -- so this is invisible until someone else runs it and gets
# "VCRUNTIME140_1.dll was not found" with no other clue.
#
# Microsoft permits app-local deployment of exactly these, which avoids making the user
# install a redistributable first.
Write-Host "`n[2/4] staging the Visual C++ runtime" -ForegroundColor Cyan

$crtNames = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'

$crtDir = $null
if (Test-Path $vswhere) {
    $vsRoot = & $vswhere -latest -products * -property installationPath
    if ($vsRoot) {
        $versionFile = Join-Path $vsRoot 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt'
        if (Test-Path $versionFile) {
            $redistVersion = (Get-Content $versionFile -Raw).Trim()
            # The toolset directory is named after the *compiler* major version (VC143,
            # VC145, ...), which does not match the redist version number, so glob for it
            # rather than trying to derive the name.
            $candidate = Get-ChildItem (Join-Path $vsRoot "VC\Redist\MSVC\$redistVersion\x64") `
                -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue |
                Select-Object -Last 1
            if ($candidate) { $crtDir = $candidate.FullName }
        }
    }
}

if ($crtDir) {
    foreach ($name in $crtNames) {
        $source = Join-Path $crtDir $name
        if (Test-Path $source) {
            Copy-Item $source -Destination $releaseDir -Force
            Write-Host "  + $name"
        } else {
            Write-Warning "  $name not found in $crtDir"
        }
    }
} else {
    # Not fatal -- a machine that already has the redistributable installed will run the
    # result fine -- but the installer built here is then only safe to give to machines
    # that do, which is not something to discover from a support email.
    Write-Warning @"
  Could not locate the Visual C++ redistributable DLLs.
  The installer will still build, but the app will fail to start on any machine without
  the VC++ 2015-2022 x64 redistributable already installed. Install the "Desktop
  development with C++" workload (which Flutter's Windows toolchain needs anyway) and
  re-run this script before distributing the result.
"@
}

# ---------------------------------------------------------------- inno setup

Write-Host "`n[3/4] locating Inno Setup" -ForegroundColor Cyan

# Deliberately no `?.` or other PowerShell 7 syntax anywhere in this script: the
# documented invocation is `powershell -File ...`, which on Windows is 5.1, and a parse
# error there fails before the first line runs.
$isccCommand = Get-Command 'iscc.exe' -ErrorAction SilentlyContinue
$iscc = if ($isccCommand) { $isccCommand.Source } else { $null }

# Inno Setup does not put itself on PATH, and where it lands depends on how it was
# installed: winget's default is a per-user install under LOCALAPPDATA, the interactive
# installer's is Program Files (x86), and the GitHub Windows runner images ship it
# preinstalled somewhere else again. Ask the uninstall key first, since that is written
# by every one of those, and fall back to the well-known paths.
if (-not $iscc) {
    $registryKeys = @(
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1'
    )
    foreach ($key in $registryKeys) {
        $location = (Get-ItemProperty -Path $key -Name 'InstallLocation' -ErrorAction SilentlyContinue).InstallLocation
        if ($location) {
            $candidate = Join-Path $location 'ISCC.exe'
            if (Test-Path $candidate) { $iscc = $candidate; break }
        }
    }
}
if (-not $iscc) {
    foreach ($guess in @(
            (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
            (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'))) {
        if (Test-Path $guess) { $iscc = $guess; break }
    }
}
if (-not $iscc) {
    throw @"
Inno Setup 6 is not installed (no ISCC.exe on PATH or in Program Files).

    winget install --id JRSoftware.InnoSetup --silent

Everything up to this point succeeded: the built app is in
$releaseDir
and can be run or zipped as-is.
"@
}
Write-Host "  $iscc"

Write-Host "`n[4/4] compiling the installer" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

& $iscc `
    "/DAppVersion=$appVersion" `
    "/DProjectDir=$projectDir" `
    (Join-Path $PSScriptRoot 'world_keeper.iss')

if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)." }

$installer = Join-Path $outDir "WorldKeeper-$appVersion-windows-x64-setup.exe"
$size = [math]::Round((Get-Item $installer).Length / 1MB, 1)

Write-Host "`nDone: $installer ($size MB)" -ForegroundColor Green
Write-Host @"

It is not code-signed, so Windows will show "Windows protected your PC" on first run and
the user has to click More info -> Run anyway. Signing needs a certificate; nothing in
this script can substitute for one.
"@ -ForegroundColor DarkGray
