<#
.SYNOPSIS
    Renders controls and scenario stacks with the native Windows theme, in
    the light and the dark appearance, with Windows in dark and in light
    mode, and with the engine of the reference release, and checks and
    compares the pixels.

.DESCRIPTION
    The runs (see -Runs), each with its own Windows setting and appAppearance:

      A  Windows dark,  appAppearance "system"  the dark appearance
      C  Windows dark,  the default             a fresh install: light
      B  Windows light, appAppearance "system"  the light appearance
      D  Windows light, appAppearance "dark"    the dark appearance, forced
      R  Windows light, the engine of the reference release (-BaselineRoot),
         which has no appAppearance: the light appearance as it was

    For each run:

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
       ide folder instead). OXT_RENDER_APPEARANCE tells the script what to
       set the appAppearance to before it creates anything. The script
       creates invisible stacks and exports their controls as PNG files with
       "export snapshot" (off screen; no window is shown). The engine is
       stopped if it does not finish within -TimeoutSeconds.
    3. Runs tools/ci/render_check.py on the PNG files (not for R): disabled
       labels drawn once, flat, in the disabled grey; scrollbar tracks dark
       in the dark appearance and light in the light one; the appearance the
       engine reports; and the appearance scenarios (the owner's light
       design kept in every run, a stack with no colours dark in the dark
       appearance, and so on). Its --self-test runs first.

    Then it compares the runs' images (render_check.py --compare):

      C = B  every image: a dark Windows with the default appAppearance
             draws exactly as a light one
      R = B  every image R has: the light appearance draws exactly as the
             reference release did
      D = A  every image: the forced dark appearance on a light Windows
             draws exactly as the dark appearance on a dark Windows
      A = B  the owner's colours (s1-*) and a field with its fill, text and
             border colours of its own (s5, a plain border: the theme's
             frame is a native part, dark in a dark run): the same in the
             dark and the light appearance; and the paint tools' colours
             (INFO penColor, brushColor)
      S8     a copy of s2 with the stackAppearance "dark", in B and C, draws
             as s2 in A; one with "light", in A, draws as s2 in B

    The registry value is put back as it was afterwards (removed if it did not
    exist). Because this changes the user's Windows appearance and starts the
    engine with a user interface, it refuses to run outside GitHub Actions
    unless -AllowSystemChanges is given. Never run it on a PC where OXT-Beyond
    or LiveCode is open: the development engine hands its command line to a
    running instance (engine/src/w32relaunch.cpp).

    The PNG files, render.txt and the engine's output of each run are left
    in -OutDir\<run> (uploaded by the workflow as the "render-test"
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

.PARAMETER BaselineRoot
    A folder with the installed layout of the reference release (its
    OXT-Beyond.exe, at most two folders down), for run R. Without it, R is
    left out.

.PARAMETER RepoRoot
    Repository root. Default: two levels up from this script.

.PARAMETER OutDir
    Folder for the results. Default: <RUNNER_TEMP or the temporary
    folder>\render-test. It is emptied first.

.PARAMETER Runs
    The runs, in order. Default: A, C, B, D, R (the Windows setting changes
    twice).

.PARAMETER Python
    Python 3 interpreter. Default: the first of "py -3", python3 and python
    that is Python 3.8 or later.

.PARAMETER LogFile
    Optional file to write the engine output and the check results to.

.PARAMETER TimeoutSeconds
    How long to wait for the engine in each run. Default: 180.

.PARAMETER AllowSystemChanges
    Run outside GitHub Actions, switching this PC's Windows appearance for
    the duration of the test.
#>
[CmdletBinding()]
param(
    [string]$Root,
    [string]$Engine,
    [string]$BaselineRoot,
    [string]$RepoRoot,
    [string]$OutDir,
    [ValidateSet('A', 'B', 'C', 'D', 'R')]
    [string[]]$Runs = @('A', 'C', 'B', 'D', 'R'),
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

# The runs: the Windows setting, what the script sets the appAppearance to
# (empty: the engine's default), the appearance stacks that set none are
# drawn in (render_check.py --mode), and whether it runs the reference
# release's engine
$runTable = [ordered]@{
    'A' = @{ Windows = 'dark'; Appearance = 'system'; Mode = 'dark'; Baseline = $false;
             Title = 'Windows dark, appAppearance "system"' }
    'C' = @{ Windows = 'dark'; Appearance = ''; Mode = 'light'; Baseline = $false;
             Title = 'Windows dark, the default appAppearance' }
    'B' = @{ Windows = 'light'; Appearance = 'system'; Mode = 'light'; Baseline = $false;
             Title = 'Windows light, appAppearance "system"' }
    'D' = @{ Windows = 'light'; Appearance = 'dark'; Mode = 'dark'; Baseline = $false;
             Title = 'Windows light, appAppearance "dark"' }
    'R' = @{ Windows = 'light'; Appearance = ''; Mode = 'light'; Baseline = $true;
             Title = 'Windows light, the reference release''s engine' }
}

# The engine must be in an installed layout: the environment stack looks for
# the repository's ide folder instead of REV_TOOLS_PATH when the engine is
# inside one of these folders
function Assert-InstalledLayout([string]$Exe) {
    foreach ($folder in @('build-win-x86_64', 'win-x86_64-bin', 'win-bin', '_build')) {
        if (@($Exe.Split('\') | Where-Object { $_ -eq $folder }).Count -gt 0) {
            throw "The engine $Exe is inside a $folder folder, where it would open the repository's IDE; use an installed layout such as dist\stage\OXT-Beyond-<ver>"
        }
    }
}

# --- Layout and engines ---
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
Assert-InstalledLayout $Engine

$baselineEngine = $null
if ($BaselineRoot) {
    if (-not (Test-Path -LiteralPath $BaselineRoot -PathType Container)) { throw "BaselineRoot not found: $BaselineRoot" }
    $found = @(Get-ChildItem -LiteralPath $BaselineRoot -Recurse -Depth 2 -Filter 'OXT-Beyond.exe' -File -ErrorAction SilentlyContinue)
    if ($found.Count -lt 1) { throw "No OXT-Beyond.exe in $BaselineRoot (or two folders down)" }
    $baselineEngine = $found[0].FullName
    Assert-InstalledLayout $baselineEngine
}
if (-not $baselineEngine) {
    $Runs = @($Runs | Where-Object { $_ -ne 'R' })
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
Write-Host "Reference  : $(if ($baselineEngine) { $baselineEngine } else { 'none (run R left out)' })"
Write-Host "Script     : $renderScript"
Write-Host "Checker    : $checker"
Write-Host "Python     : $((@($py.Exe) + @($py.Pre)) -join ' ') ($($py.Version))"
Write-Host "Results    : $OutDir"
Write-Host "Runs       : $($Runs -join ', ')"
Write-Host ''

$log = New-Object System.Collections.Generic.List[string]
$problems = New-Object System.Collections.Generic.List[string]
# check name -> run -> PASS/FAIL, in the order the checks first appear
$results = [ordered]@{}
# comparison -> @{ Passed; Failed }
$comparisons = [ordered]@{}
$failLines = New-Object System.Collections.Generic.List[string]

# Collects the PASS and FAIL lines of render_check.py
function Add-CheckLines([string[]]$Lines, [string]$Comparison) {
    foreach ($line in $Lines) {
        if ($line -match '^(PASS|FAIL) (\S+) ([^:]+):') {
            if ($Comparison) {
                if (-not $comparisons.Contains($Comparison)) { $comparisons[$Comparison] = @{ Passed = 0; Failed = 0 } }
                if ($Matches[1] -eq 'PASS') { $comparisons[$Comparison].Passed++ } else { $comparisons[$Comparison].Failed++ }
            }
            else {
                $name = $Matches[3]
                if (-not $results.Contains($name)) { $results[$name] = @{} }
                $results[$name][$Matches[2]] = $Matches[1]
            }
            if ($Matches[1] -eq 'FAIL') { $failLines.Add($(if ($Comparison) { "[$Comparison] $line" } else { $line })) }
        }
    }
}

# The analyser checks itself first on synthetic images
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
$savedAppearance = $env:OXT_RENDER_APPEARANCE
$completed = New-Object System.Collections.Generic.List[string]
$timer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    foreach ($run in $Runs) {
        $def = $runTable[$run]
        $exe = if ($def.Baseline) { $baselineEngine } else { $Engine }
        Write-Host ''
        Write-Host "=== Run $run`: $($def.Title) ==="
        $runDir = Join-Path $OutDir $run
        New-Item -ItemType Directory -Force -Path $runDir | Out-Null
        $toolsDir = Join-Path $OutDir ('tools-' + $run)
        New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
        Copy-Item -LiteralPath $renderScript -Destination (Join-Path $toolsDir 'Startup.rev') -Force

        $lightValue = if ($def.Windows -eq 'dark') { 0 } else { 1 }
        Set-AppsUseLightTheme $lightValue
        Write-Host "AppsUseLightTheme = $lightValue, OXT_RENDER_APPEARANCE = '$($def.Appearance)', engine $exe"

        # LiveCode paths use forward slashes
        $env:REV_TOOLS_PATH = $toolsDir.Replace('\', '/')
        $env:OXT_RENDER_OUT = $runDir.Replace('\', '/')
        $env:OXT_RENDER_APPEARANCE = $def.Appearance
        $outFile = Join-Path $runDir 'engine-stdout.txt'
        $errFile = Join-Path $runDir 'engine-stderr.txt'
        $exitCode = $null
        # The engine is a GUI-subsystem program, so start it with redirected
        # output and wait for it explicitly. No arguments: the environment
        # stack opens Startup.rev from REV_TOOLS_PATH.
        $process = Start-Process -FilePath $exe -WorkingDirectory $toolsDir `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
        # Read the handle now: without it, ExitCode is empty after the process
        # has exited (a known Start-Process -PassThru quirk).
        $null = $process.Handle
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $null = $process.WaitForExit(30000)
            # A run that wrote all its images and then did not quit is still
            # measured; only report the hang
            $manifest = Join-Path $runDir 'render.txt'
            $complete = (Test-Path -LiteralPath $manifest) -and
                (@(Get-Content -LiteralPath $manifest | Where-Object { $_ -eq "INFO`tdone`ttrue" }).Count -gt 0)
            $message = "run $run`: the engine did not finish within $TimeoutSeconds seconds and was stopped"
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
            try { $_.Path -eq $exe } catch { $false }
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
        $log.Add("=== Run $run ($($def.Title)): engine exit code $exitCode")
        $log.AddRange([string[]]$engineOutput)
        if ($engineErrors.Count -gt 0) { $log.Add('stderr:'); $log.AddRange([string[]]$engineErrors) }
        if ($null -ne $exitCode -and $exitCode -ne 0) {
            $problems.Add("run $run`: the render script exited with code $exitCode (2: a script error, listed as ERROR in render.txt; 3: an uncaught error; another code: the engine crashed)")
        }
        if (-not (Test-Path -LiteralPath (Join-Path $runDir 'render.txt'))) {
            $problems.Add("run $run`: the engine wrote no render.txt. If engine-stdout.txt is empty, the engine did not open Startup.rev from REV_TOOLS_PATH (engine/src/environment/stackbehavior.livecodescript), for example because it opened the IDE instead")
        }
        else {
            $completed.Add($run)
        }

        # --- Measure (the reference release is only compared) ---
        if (-not $def.Baseline) {
            $check = Invoke-Checker @('--mode', $def.Mode, '--system', $def.Windows, '--label', $run, '--dir', $runDir)
            $check.Lines | ForEach-Object { Write-Host $_ }
            $log.AddRange([string[]]$check.Lines)
            Add-CheckLines $check.Lines ''
            if (-not ($check.Lines | Where-Object { $_ -match '^SUMMARY ' })) {
                $problems.Add("run $run`: render_check.py did not finish (exit code $($check.Code))")
            }
        }
        Remove-Item -LiteralPath $toolsDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    $env:REV_TOOLS_PATH = $savedToolsPath
    $env:OXT_RENDER_OUT = $savedOut
    $env:OXT_RENDER_APPEARANCE = $savedAppearance
    if ($null -eq $original) {
        Remove-ItemProperty -LiteralPath $personalize -Name $valueName -ErrorAction SilentlyContinue
        Write-Host "AppsUseLightTheme removed again"
    }
    else {
        New-ItemProperty -LiteralPath $personalize -Name $valueName -PropertyType DWord -Value $original -Force | Out-Null
        Write-Host "AppsUseLightTheme restored to $original"
    }
}

# --- Compare the runs ---
# Each: a title, the two runs, and render_check.py's selection arguments
$comparisonTable = @(
    @{ Title = 'C = B'; A = 'C'; B = 'B'; Args = @() },
    @{ Title = 'R = B'; A = 'R'; B = 'B'; Args = @() },
    @{ Title = 'D = A'; A = 'D'; B = 'A'; Args = @() },
    @{ Title = 'A = B (s1, s5)'; A = 'A'; B = 'B'; Args = @('--only', 's1-*', '--only', 's5*', '--info', 'penColor', '--info', 'brushColor') },
    @{ Title = 'S8 dark in B = s2 in A'; A = 'B'; B = 'A'; Args = @('--only', 's8-dark-*', '--rename', 's8-dark-=s2-') },
    @{ Title = 'S8 dark in C = s2 in A'; A = 'C'; B = 'A'; Args = @('--only', 's8-dark-*', '--rename', 's8-dark-=s2-') },
    @{ Title = 'S8 light in A = s2 in B'; A = 'A'; B = 'B'; Args = @('--only', 's8-light-*', '--rename', 's8-light-=s2-') }
)
foreach ($comparison in $comparisonTable) {
    if (-not ($completed.Contains($comparison.A) -and $completed.Contains($comparison.B))) { continue }
    Write-Host ''
    Write-Host "=== Compare $($comparison.Title) ==="
    $arguments = @('--compare', (Join-Path $OutDir $comparison.A), (Join-Path $OutDir $comparison.B), '--label', ($comparison.A + '=' + $comparison.B)) + $comparison.Args
    $compared = Invoke-Checker $arguments
    $compared.Lines | ForEach-Object { Write-Host $_ }
    $log.Add('')
    $log.Add("=== Compare $($comparison.Title)")
    $log.AddRange([string[]]$compared.Lines)
    Add-CheckLines $compared.Lines $comparison.Title
    if (-not ($compared.Lines | Where-Object { $_ -match '^SUMMARY ' })) {
        $problems.Add("compare $($comparison.Title): render_check.py did not finish (exit code $($compared.Code))")
    }
}
$elapsed = $timer.Elapsed.TotalSeconds

$failed = $failLines.Count + $problems.Count
$passed = 0
foreach ($name in $results.Keys) { foreach ($m in $results[$name].Keys) { if ($results[$name][$m] -eq 'PASS') { $passed++ } } }
foreach ($c in $comparisons.Keys) { $passed += $comparisons[$c].Passed }

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
    $all = @("Engine: $Engine", "Reference: $baselineEngine", "Results: $OutDir", '') + @($log) + @('', "Result: $result") + @($problems | ForEach-Object { "PROBLEM $_" })
    [System.IO.File]::WriteAllText($LogFile, ($all -join "`r`n") + "`r`n", $utf8)
}
if ($env:GITHUB_STEP_SUMMARY) {
    $checkedRuns = @($Runs | Where-Object { -not $runTable[$_].Baseline })
    $md = @('### Render test (light and dark appearance)', '',
            ('Controls and appearance scenarios drawn by `{0}` with the native Windows theme, measured and compared by `tools/ci/render_check.py` ({1:N0} s). Result: **{2}**. The images are in the `render-test` artifact.' -f (Split-Path -Leaf $Engine), $elapsed, $result),
            '')
    foreach ($run in $Runs) { $md += "- **$run**: $($runTable[$run].Title)" }
    $md += ''
    $md += @(('| Check | ' + ($checkedRuns -join ' | ') + ' |'), ('| --- |' + (' --- |' * $checkedRuns.Count)))
    foreach ($name in $results.Keys) {
        $cells = foreach ($m in $checkedRuns) {
            if ($results[$name].ContainsKey($m)) { if ($results[$name][$m] -eq 'PASS') { 'pass' } else { '**FAIL**' } } else { '-' }
        }
        $md += "| $name | $($cells -join ' | ') |"
    }
    if ($comparisons.Count -gt 0) {
        $md += @('', '| Comparison | Images and values that match | Differ |', '| --- | --- | --- |')
        foreach ($c in $comparisons.Keys) {
            $md += "| $c | $($comparisons[$c].Passed) | $(if ($comparisons[$c].Failed) { '**' + $comparisons[$c].Failed + '**' } else { '0' }) |"
        }
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
