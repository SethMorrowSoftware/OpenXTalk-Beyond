<#
.SYNOPSIS
    Renders disabled labels and scrollbars with the native Windows theme, in
    dark and in light mode, and checks the pixels.

.DESCRIPTION
    For each mode (dark, then light):

    1. Sets HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize
       AppsUseLightTheme to 0 (dark) or 1 (light). The engine reads it when
       it starts (MCScreenDC::getsystemappearance, engine/src/w32dc.cpp).
    2. Starts the development engine WITH a user interface: the native theme
       and the dark and light colours only exist with one. It must not open
       the IDE, so tools/ci/render-test.livecodescript is copied to
       <folder>\Startup.rev and REV_TOOLS_PATH is set to <folder>: the
       engine's environment stack (engine/src/environment) opens the first
       Startup.rev, mchome.mc or Toolset\home.* it finds in its tools folder
       as the home stack. This works for an installed layout (the engine's
       path contains no build-win-x86_64, win-x86_64-bin, win-bin or _build
       folder, which would make the environment stack use the repository's
       ide folder instead). The script creates an invisible stack with a
       disabled push button, checkbox, radio button, graphic and tab, a
       scrollbar and a field with a scrollbar, and exports them as PNG files with
       "export snapshot" (off screen; no window is shown). The engine is
       stopped if it does not finish within -TimeoutSeconds.
    3. Runs tools/ci/render_check.py on the PNG files, which checks that the
       disabled labels are drawn once, flat, in the disabled grey (not
       engraved with a white copy), and that the scrollbar tracks are dark
       in dark mode and light in light mode, with a visible thumb. Its
       --self-test runs first.

    The registry value is put back as it was afterwards (removed if it did not
    exist). Because this changes the user's Windows appearance and starts the
    engine with a user interface, it refuses to run outside GitHub Actions
    unless -AllowSystemChanges is given. Never run it on a PC where OXT-Beyond
    or LiveCode is open: the development engine hands its command line to a
    running instance (engine/src/w32relaunch.cpp).

    The PNG files, render.txt and the engine's output of each mode are left
    in -OutDir\<mode> (uploaded by the workflow as the "render-test"
    artifact). Exits with 0 when every check passed, 1 otherwise. Under
    GitHub Actions it adds a table of the checks to the job summary and an
    error annotation per failed check.

    Written to run under Windows PowerShell 5.1 and PowerShell 7.

.PARAMETER Root
    Installed layout with OXT-Beyond.exe (for example
    dist\stage\OXT-Beyond-<ver>). Default: the single OXT-Beyond-* folder in
    <RepoRoot>\dist\stage.

.PARAMETER Engine
    The development engine to run. Default: <Root>\OXT-Beyond.exe.

.PARAMETER RepoRoot
    Repository root. Default: two levels up from this script.

.PARAMETER OutDir
    Folder for the results. Default: <RUNNER_TEMP or the temporary
    folder>\render-test. It is emptied first.

.PARAMETER Modes
    The modes to test, in order. Default: dark, light.

.PARAMETER Python
    Python 3 interpreter. Default: the first of "py -3", python3 and python
    that is Python 3.8 or later.

.PARAMETER LogFile
    Optional file to write the engine output and the check results to.

.PARAMETER TimeoutSeconds
    How long to wait for the engine in each mode. Default: 180.

.PARAMETER AllowSystemChanges
    Run outside GitHub Actions, switching this PC's Windows appearance for
    the duration of the test.
#>
[CmdletBinding()]
param(
    [string]$Root,
    [string]$Engine,
    [string]$RepoRoot,
    [string]$OutDir,
    [ValidateSet('dark', 'light')]
    [string[]]$Modes = @('dark', 'light'),
    [string]$Python,
    [string]$LogFile,
    [ValidateRange(20, 1800)]
    [int]$TimeoutSeconds = 180,
    [switch]$AllowSystemChanges
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ($env:GITHUB_ACTIONS -ne 'true' -and -not $AllowSystemChanges) {
    throw ('render-test.ps1 switches Windows between dark and light mode (HKCU AppsUseLightTheme) and starts ' +
           'the engine with a user interface. It is meant for CI runners; pass -AllowSystemChanges to run it here, ' +
           'and only when no OXT-Beyond or LiveCode is open.')
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$renderScript = Join-Path $PSScriptRoot 'render-test.livecodescript'
$checker = Join-Path $PSScriptRoot 'render_check.py'
if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '..\..' }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath.TrimEnd('\')

# --- Layout and engine ---
if (-not $Engine) {
    if (-not $Root) {
        $stage = Join-Path $RepoRoot 'dist\stage'
        $candidates = @()
        if (Test-Path -LiteralPath $stage -PathType Container) {
            $candidates = @(Get-ChildItem -LiteralPath $stage -Directory -Filter 'OXT-Beyond-*')
        }
        if ($candidates.Count -ne 1) { throw "Pass -Root or -Engine: expected one OXT-Beyond-* folder in $stage, found $($candidates.Count)" }
        $Root = $candidates[0].FullName
    }
    $Engine = Join-Path $Root 'OXT-Beyond.exe'
}
if (-not (Test-Path -LiteralPath $Engine -PathType Leaf)) { throw "Engine not found: $Engine" }
$Engine = (Resolve-Path -LiteralPath $Engine).ProviderPath
# The environment stack looks for the repository's ide folder instead of
# REV_TOOLS_PATH when the engine is inside one of these folders
foreach ($folder in @('build-win-x86_64', 'win-x86_64-bin', 'win-bin', '_build')) {
    if (@($Engine.Split('\') | Where-Object { $_ -eq $folder }).Count -gt 0) {
        throw "The engine $Engine is inside a $folder folder, where it would open the repository's IDE; use an installed layout such as dist\stage\OXT-Beyond-<ver>"
    }
}

if (-not $OutDir) {
    $base = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
    $OutDir = Join-Path $base 'render-test'
}
if (Test-Path -LiteralPath $OutDir) { Remove-Item -LiteralPath $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).ProviderPath

# --- Python 3 ---
function Find-Python {
    $candidates = @()
    if ($Python) { $candidates += , @($Python) }
    else {
        if (Get-Command py -ErrorAction SilentlyContinue) { $candidates += , @('py', '-3') }
        foreach ($name in @('python3', 'python')) {
            $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd) { $candidates += , @($cmd.Source) }
        }
    }
    foreach ($c in $candidates) {
        $exe = $c[0]
        $pre = @($c | Select-Object -Skip 1)
        $saved = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            # No double quotes in the argument: Windows PowerShell does not
            # escape them for native programs
            $v = & $exe @pre -c 'import sys; print(sys.version_info[0], sys.version_info[1])' 2>$null
            $code = $LASTEXITCODE
        }
        catch { $code = 1 }
        finally { $ErrorActionPreference = $saved }
        if ($code -eq 0 -and "$v".Trim() -match '^3 (\d+)$' -and [int]$Matches[1] -ge 8) {
            return New-Object PSObject -Property @{ Exe = $exe; Pre = $pre; Version = "3.$($Matches[1])" }
        }
    }
    throw 'Python 3.8 or later was not found (tried py -3, python3 and python); pass -Python.'
}
$py = Find-Python

# Runs render_check.py; returns its exit code and its output lines
function Invoke-Checker([string[]]$Arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $savedEncoding = $env:PYTHONIOENCODING
    $env:PYTHONIOENCODING = 'utf-8'
    try {
        $global:LASTEXITCODE = 0
        $argv = @($py.Pre) + @($checker) + @($Arguments)
        $lines = @(& $py.Exe @argv 2>&1 | ForEach-Object { "$_" })
        return New-Object PSObject -Property @{ Code = $LASTEXITCODE; Lines = $lines }
    }
    finally {
        $ErrorActionPreference = $saved
        $env:PYTHONIOENCODING = $savedEncoding
    }
}

Write-Host "Engine     : $Engine"
Write-Host "Script     : $renderScript"
Write-Host "Checker    : $checker"
Write-Host "Python     : $((@($py.Exe) + @($py.Pre)) -join ' ') ($($py.Version))"
Write-Host "Results    : $OutDir"
Write-Host "Modes      : $($Modes -join ', ')"
Write-Host ''

$log = New-Object System.Collections.Generic.List[string]
$problems = New-Object System.Collections.Generic.List[string]
# check name -> mode -> PASS/FAIL, in the order the checks first appear
$results = [ordered]@{}
$failLines = New-Object System.Collections.Generic.List[string]

# The analyser checks itself first on synthetic flat and engraved labels
$selfTest = Invoke-Checker @('--self-test')
$selfTest.Lines | Where-Object { $_ -like '--- self-test:*' -or $_ -like '  *' } | ForEach-Object { Write-Host $_ }
$log.Add('render_check.py --self-test:')
$log.AddRange([string[]]$selfTest.Lines)
if ($selfTest.Code -ne 0) {
    $problems.Add("render_check.py --self-test failed (exit code $($selfTest.Code)): the checks themselves are broken; see the log")
}

# --- The dark/light setting ---
$personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$valueName = 'AppsUseLightTheme'
$original = $null
if (Test-Path -LiteralPath $personalize) {
    $item = Get-ItemProperty -LiteralPath $personalize -Name $valueName -ErrorAction SilentlyContinue
    if ($null -ne $item) { $original = $item.$valueName }
}
Write-Host "AppsUseLightTheme was $(if ($null -eq $original) { 'not set' } else { $original })"

function Set-AppsUseLightTheme([int]$Value) {
    # Only create the key when it is missing: New-Item -Force would replace
    # an existing key with an empty one
    if (-not (Test-Path -LiteralPath $personalize)) { New-Item -Path $personalize -Force | Out-Null }
    New-ItemProperty -LiteralPath $personalize -Name $valueName -PropertyType DWord -Value $Value -Force | Out-Null
    $now = (Get-ItemProperty -LiteralPath $personalize -Name $valueName).$valueName
    if ($now -ne $Value) { throw "Could not set $valueName to $Value (it reads $now)" }
}

$savedToolsPath = $env:REV_TOOLS_PATH
$savedOut = $env:OXT_RENDER_OUT
$timer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    foreach ($mode in $Modes) {
        Write-Host ''
        Write-Host "=== $mode mode ==="
        $modeDir = Join-Path $OutDir $mode
        New-Item -ItemType Directory -Force -Path $modeDir | Out-Null
        $toolsDir = Join-Path $OutDir ('tools-' + $mode)
        New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
        Copy-Item -LiteralPath $renderScript -Destination (Join-Path $toolsDir 'Startup.rev') -Force

        Set-AppsUseLightTheme $(if ($mode -eq 'dark') { 0 } else { 1 })
        Write-Host "AppsUseLightTheme = $(if ($mode -eq 'dark') { 0 } else { 1 })"

        # LiveCode paths use forward slashes
        $env:REV_TOOLS_PATH = $toolsDir.Replace('\', '/')
        $env:OXT_RENDER_OUT = $modeDir.Replace('\', '/')
        $outFile = Join-Path $modeDir 'engine-stdout.txt'
        $errFile = Join-Path $modeDir 'engine-stderr.txt'
        $exitCode = $null
        # The engine is a GUI-subsystem program, so start it with redirected
        # output and wait for it explicitly. No arguments: the environment
        # stack opens Startup.rev from REV_TOOLS_PATH.
        $process = Start-Process -FilePath $Engine -WorkingDirectory $toolsDir `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
        # Read the handle now: without it, ExitCode is empty after the process
        # has exited (a known Start-Process -PassThru quirk).
        $null = $process.Handle
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $null = $process.WaitForExit(30000)
            # A run that wrote all its images and then did not quit is still
            # measured; only report the hang
            $manifest = Join-Path $modeDir 'render.txt'
            $complete = (Test-Path -LiteralPath $manifest) -and
                (@(Get-Content -LiteralPath $manifest | Where-Object { $_ -eq "INFO`tdone`ttrue" }).Count -gt 0)
            $message = "$mode mode: the engine did not finish within $TimeoutSeconds seconds and was stopped"
            if ($complete) {
                Write-Host "WARNING $message, after it had written every image"
                if ($env:GITHUB_ACTIONS -eq 'true') { Write-Host "::warning title=Render test::$message, after it had written every image (it did not quit)" }
            }
            else {
                $problems.Add("$message; see engine-stdout.txt in the render-test artifact for how far it got")
            }
        }
        else {
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        }
        # Anything else started from this engine (there should be nothing)
        Get-Process -ErrorAction SilentlyContinue | Where-Object {
            try { $_.Path -eq $Engine } catch { $false }
        } | ForEach-Object {
            Write-Host "Stopping leftover engine process $($_.Id)"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }

        $engineOutput = @()
        if (Test-Path -LiteralPath $outFile) { $engineOutput = @(Get-Content -LiteralPath $outFile) }
        $engineErrors = @()
        if (Test-Path -LiteralPath $errFile) { $engineErrors = @(Get-Content -LiteralPath $errFile | Where-Object { $_ -ne '' }) }
        Write-Host "Engine exit code: $(if ($null -eq $exitCode) { 'none (stopped)' } else { $exitCode })"
        $engineOutput | ForEach-Object { Write-Host "  $_" }
        if ($engineErrors.Count -gt 0) {
            Write-Host 'Engine stderr:'
            $engineErrors | ForEach-Object { Write-Host "  $_" }
        }
        $log.Add('')
        $log.Add("=== $mode mode: engine exit code $exitCode")
        $log.AddRange([string[]]$engineOutput)
        if ($engineErrors.Count -gt 0) { $log.Add('stderr:'); $log.AddRange([string[]]$engineErrors) }
        if ($null -ne $exitCode -and $exitCode -ne 0) {
            $problems.Add("$mode mode: the render script exited with code $exitCode (2: a script error, listed as ERROR in render.txt; 3: an uncaught error)")
        }
        if (-not (Test-Path -LiteralPath (Join-Path $modeDir 'render.txt'))) {
            $problems.Add("$mode mode: the engine wrote no render.txt. If engine-stdout.txt is empty, the engine did not open Startup.rev from REV_TOOLS_PATH (engine/src/environment/stackbehavior.livecodescript), for example because it opened the IDE instead")
        }

        # --- Measure ---
        $check = Invoke-Checker @('--mode', $mode, '--dir', $modeDir)
        $check.Lines | ForEach-Object { Write-Host $_ }
        $log.AddRange([string[]]$check.Lines)
        foreach ($line in $check.Lines) {
            if ($line -match '^(PASS|FAIL) (dark|light) ([^:]+):') {
                $name = $Matches[3]
                if (-not $results.Contains($name)) { $results[$name] = @{} }
                $results[$name][$Matches[2]] = $Matches[1]
                if ($Matches[1] -eq 'FAIL') { $failLines.Add($line) }
            }
        }
        if (-not ($check.Lines | Where-Object { $_ -match '^SUMMARY ' })) {
            $problems.Add("$mode mode: render_check.py did not finish (exit code $($check.Code))")
        }
        Remove-Item -LiteralPath $toolsDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    $env:REV_TOOLS_PATH = $savedToolsPath
    $env:OXT_RENDER_OUT = $savedOut
    if ($null -eq $original) {
        Remove-ItemProperty -LiteralPath $personalize -Name $valueName -ErrorAction SilentlyContinue
        Write-Host "AppsUseLightTheme removed again"
    }
    else {
        New-ItemProperty -LiteralPath $personalize -Name $valueName -PropertyType DWord -Value $original -Force | Out-Null
        Write-Host "AppsUseLightTheme restored to $original"
    }
}
$elapsed = $timer.Elapsed.TotalSeconds

$failed = $failLines.Count + $problems.Count
$passed = 0
foreach ($name in $results.Keys) { foreach ($m in $results[$name].Keys) { if ($results[$name][$m] -eq 'PASS') { $passed++ } } }

Write-Host ''
foreach ($p in $problems) {
    Write-Host "PROBLEM $p"
    if ($env:GITHUB_ACTIONS -eq 'true') { Write-Host "::error title=Render test::$p" }
}
$n = 0
foreach ($f in $failLines) {
    # Annotations are limited per step; the full list is in the log
    if ($env:GITHUB_ACTIONS -eq 'true' -and $n -lt 20) { Write-Host "::error title=Render test::$f" }
    $n++
}
$result = if ($failed -eq 0) { "passed: $passed checks" } else { "FAILED: $($failLines.Count) check(s) failed$(if ($problems.Count) { ", $($problems.Count) problem(s) running the test" })" }

if ($LogFile) {
    $logDir = Split-Path -Parent $LogFile
    if ($logDir) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $all = @("Engine: $Engine", "Results: $OutDir", '') + @($log) + @('', "Result: $result") + @($problems | ForEach-Object { "PROBLEM $_" })
    [System.IO.File]::WriteAllText($LogFile, ($all -join "`r`n") + "`r`n", $utf8)
}
if ($env:GITHUB_STEP_SUMMARY) {
    $md = @('### Render test (dark and light)', '',
            ('Disabled labels and scrollbars drawn by `{0}` with the native Windows theme, measured by `tools/ci/render_check.py` ({1:N0} s). Result: **{2}**. The images are in the `render-test` artifact.' -f (Split-Path -Leaf $Engine), $elapsed, $result),
            '')
    $md += @(('| Check | ' + ($Modes -join ' | ') + ' |'), ('| --- |' + (' --- |' * $Modes.Count)))
    foreach ($name in $results.Keys) {
        $cells = foreach ($m in $Modes) {
            if ($results[$name].ContainsKey($m)) { if ($results[$name][$m] -eq 'PASS') { 'pass' } else { '**FAIL**' } } else { '-' }
        }
        $md += "| $name | $($cells -join ' | ') |"
    }
    if ($failLines.Count -gt 0 -or $problems.Count -gt 0) {
        $md += @('', '```text')
        $md += @($problems | ForEach-Object { "PROBLEM $_" })
        $md += @($failLines | Select-Object -First 40)
        $md += '```'
    }
    [System.IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, ($md -join "`n") + "`n", $utf8)
}

Write-Host ("Render test: {0} ({1:N1} s)." -f $result, $elapsed)
if ($failed -eq 0) { exit 0 }
exit 1
