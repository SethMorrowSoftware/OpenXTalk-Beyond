<#
.SYNOPSIS
    Runs the headless smoke test (tools/ci/smoke-test.livecodescript) with a
    built OXT-Beyond development engine.

.DESCRIPTION
    Starts the development engine with -ui (no user interface) and the smoke
    test script, which exercises the script engine, ICU, OpenSSL (through
    revsecurity.dll), SQLite (through revDB and dbsqlite.dll), revXML and
    revZip. The expected version and SQLite version are read from the
    source tree and passed to the script in OXT_EXPECT_VERSION and
    OXT_EXPECT_SQLITE.

    It works with two layouts:

      development  the build output folder (win-x86_64-bin), where the
                   engine (LiveCode-Community.exe), the externals and the
                   database drivers are all in one folder;
      installed    an installed or packaged OXT-Beyond folder, with the
                   engine (OXT-Beyond.exe) and revsecurity.dll at the root,
                   the externals in Externals and the database drivers in
                   Externals\Database Drivers.

    The script is told where the externals and drivers are through
    OXT_EXTERNALS_DIR and OXT_DRIVERS_DIR, so the same checks run in both.

    With -Package, a zip is extracted to a temporary folder first and its
    engine is tested, so the check covers the files users download. The zip
    must have one top folder; its layout is detected: the portable zip made
    by package-windows.ps1 (OXT-Beyond-<ver>\OXT-Beyond.exe) is tested as an
    installed layout, and a zip with a win-x86_64-bin folder under its top
    folder as a development layout. With -InstallDir, an installed folder
    (for example one written by the installer) is tested. Otherwise the
    engine in -BinDir is used.

    Exits with the number of failed checks (0 when everything passed), or 1
    if the engine could not be run or timed out. Under GitHub Actions it
    writes the step outputs "passed" and "failed" and adds a short report to
    the job summary.

.PARAMETER RepoRoot
    Repository root. Default: two levels up from this script.

.PARAMETER BinDir
    Build output folder with LiveCode-Community.exe (development layout).
    Default: <RepoRoot>\win-x86_64-bin. Ignored with -Package.

.PARAMETER Package
    Zip to extract and test: the OXT-Beyond-<ver>-win-x86_64-portable.zip,
    or a zip in the development layout.

.PARAMETER InstallDir
    Installed OXT-Beyond folder to test (the folder with OXT-Beyond.exe).

.PARAMETER Exe
    File name of the engine. Default: OXT-Beyond.exe in an installed layout,
    LiveCode-Community.exe in a development layout.

.PARAMETER LogFile
    Optional file to write the engine's output to.

.PARAMETER TimeoutSeconds
    How long to wait for the engine. Default: 300.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$BinDir,
    [string]$Package,
    [string]$InstallDir,
    [string]$Exe,
    [string]$LogFile,
    [ValidateRange(10, 3600)]
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$script = Join-Path $PSScriptRoot 'smoke-test.livecodescript'

# --- Expected values from the source tree ---
$versionLine = Get-Content -LiteralPath (Join-Path $RepoRoot 'version') | Where-Object { $_ -match '^\s*BUILD_SHORT_VERSION\s*=' } | Select-Object -First 1
if (-not $versionLine) { throw "BUILD_SHORT_VERSION not found in $RepoRoot\version" }
$expectVersion = ($versionLine -split '=', 2)[1].Trim()
$sqliteHeader = Join-Path $RepoRoot 'thirdparty\libsqlite\include\sqlite3.h'
$sqliteLine = Get-Content -LiteralPath $sqliteHeader | Where-Object { $_ -match '^#define\s+SQLITE_VERSION\s+"' } | Select-Object -First 1
if (-not $sqliteLine) { throw "SQLITE_VERSION not found in $sqliteHeader" }
$expectSqlite = [regex]::Match($sqliteLine, '"([^"]+)"').Groups[1].Value

# --- Locate the engine, extracting the package if one was given ---
$DevExe = 'LiveCode-Community.exe'
$InstalledExe = 'OXT-Beyond.exe'
if (@($BinDir, $Package, $InstallDir | Where-Object { $_ }).Count -gt 1) {
    throw 'Pass only one of -BinDir, -Package and -InstallDir.'
}
$extractDir = $null
# What was tested, for the job summary
$source = if ($Package) { Split-Path -Leaf $Package } elseif ($InstallDir) { $InstallDir } elseif ($BinDir) { $BinDir } else { 'win-x86_64-bin' }
if ($Package) {
    $Package = (Resolve-Path -LiteralPath $Package).Path
    # The IDE uses folder names such as win-x86_64-bin and build-win-x86_64
    # in its own path to find its files, so extract to a neutral folder.
    $base = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
    $extractDir = Join-Path $base ('oxt-smoke-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Write-Host "Extracting $Package to $extractDir ..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Package, $extractDir)
        $top = @(Get-ChildItem -LiteralPath $extractDir -Directory)
        if ($top.Count -ne 1) { throw "Expected one top-level folder in $Package, found $($top.Count)" }
        $topDir = $top[0].FullName
        # Detect the layout: win-x86_64-bin\<engine> under the top folder is
        # the development layout, <engine> in the top folder the installed one
        $devName = if ($Exe) { $Exe } else { $DevExe }
        $installedName = if ($Exe) { $Exe } else { $InstalledExe }
        if (Test-Path -LiteralPath (Join-Path $topDir "win-x86_64-bin\$devName") -PathType Leaf) {
            $BinDir = Join-Path $topDir 'win-x86_64-bin'
        }
        elseif (Test-Path -LiteralPath (Join-Path $topDir $installedName) -PathType Leaf) {
            $InstallDir = $topDir
        }
        else {
            throw "Neither $installedName nor win-x86_64-bin\$devName found in the top folder of $Package"
        }
    }
    catch {
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}

if ($InstallDir) {
    $Layout = 'installed'
    $InstallDir = (Resolve-Path -LiteralPath $InstallDir).Path
    if (-not $Exe) { $Exe = $InstalledExe }
    $engineDir = $InstallDir
    $externalsDir = Join-Path $InstallDir 'Externals'
    $driversDir = Join-Path $InstallDir 'Externals\Database Drivers'
}
else {
    $Layout = 'development'
    if (-not $BinDir) { $BinDir = Join-Path $RepoRoot 'win-x86_64-bin' }
    if (-not $Exe) { $Exe = $DevExe }
    $engineDir = $BinDir
    $externalsDir = $BinDir
    $driversDir = $BinDir
}
$engine = Join-Path $engineDir $Exe
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw "Engine not found: $engine" }
foreach ($dir in @($externalsDir, $driversDir)) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { throw "Folder not found: $dir" }
}

Write-Host "Layout          : $Layout"
Write-Host "Engine          : $engine"
Write-Host "Externals       : $externalsDir"
Write-Host "Database drivers: $driversDir"
Write-Host "Smoke test      : $script"
Write-Host "Expected version: $expectVersion"
Write-Host "Expected SQLite : $expectSqlite"
Write-Host ''

# --- Run the engine without a user interface ---
# The engine is a GUI-subsystem program, so start it with redirected output
# and wait for it explicitly; PowerShell would not wait for it otherwise.
$env:OXT_EXPECT_VERSION = $expectVersion
$env:OXT_EXPECT_SQLITE = $expectSqlite
$env:OXT_EXTERNALS_DIR = $externalsDir
$env:OXT_DRIVERS_DIR = $driversDir
$outFile = [System.IO.Path]::GetTempFileName()
$errFile = [System.IO.Path]::GetTempFileName()
$failed = $null
$passed = $null
try {
    $process = Start-Process -FilePath $engine -ArgumentList @('-ui', ('"{0}"' -f $script)) `
        -WorkingDirectory $engineDir -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
        -NoNewWindow -PassThru
    # Read the handle now: without it, ExitCode is empty after the process
    # has exited (a known Start-Process -PassThru quirk).
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "The engine did not finish within $TimeoutSeconds seconds"
    }
    $process.WaitForExit()
    $exitCode = $process.ExitCode

    $output = @(Get-Content -LiteralPath $outFile)
    $errors = @(Get-Content -LiteralPath $errFile | Where-Object { $_ -ne '' })
    $output | ForEach-Object { Write-Host $_ }
    if ($errors.Count -gt 0) {
        Write-Host ''
        Write-Host 'Engine stderr:'
        $errors | ForEach-Object { Write-Host "  $_" }
    }
    if ($LogFile) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogFile) | Out-Null
        Set-Content -LiteralPath $LogFile -Value (@($output) + @('', 'stderr:') + @($errors)) -Encoding utf8
    }

    $summaryLine = $output | Where-Object { $_ -match '^SUMMARY passed=(\d+) failed=(\d+)' } | Select-Object -Last 1
    if ($summaryLine -and $summaryLine -match '^SUMMARY passed=(\d+) failed=(\d+)') {
        $passed = [int]$Matches[1]
        $failed = [int]$Matches[2]
    }
    if ($null -eq $failed) {
        throw "The smoke test did not finish (exit code $exitCode, no SUMMARY line)"
    }
    if ($exitCode -ne $failed) {
        throw "Exit code $exitCode does not match the $failed failed check(s) reported"
    }
}
finally {
    Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue
    if ($extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
    if ($env:GITHUB_OUTPUT -and $null -ne $failed) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "passed=$passed`nfailed=$failed" -Encoding utf8
    }
    if ($env:GITHUB_STEP_SUMMARY) {
        $result = if ($null -eq $failed) { 'did not complete' } elseif ($failed -eq 0) { "all $passed checks passed" } else { "$failed of $($passed + $failed) checks failed" }
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value "### Smoke test ($Layout layout)`n`nHeadless run of ``tools/ci/smoke-test.livecodescript`` with ``$Exe`` from ``$source``: $result.`n" -Encoding utf8
    }
}

Write-Host ''
if ($failed -eq 0) {
    Write-Host "Smoke test passed ($passed checks)."
}
else {
    Write-Host "Smoke test failed: $failed of $($passed + $failed) checks failed."
}
exit $failed
