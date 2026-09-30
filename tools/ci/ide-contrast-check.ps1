<#
.SYNOPSIS
    Checks the contrast of the IDE's colour pairs (revIDEColor) in the light
    and the dark appearance against WCAG minimums and a baseline of known
    failures.

.DESCRIPTION
    Runs tools/ci/ide-contrast-check.livecodescript with the development
    engine, without a user interface (-ui), over an installed layout such as
    dist/stage/OXT-Beyond-<ver> written by tools/oxt/package.py. The script
    loads the IDE libraries that revIDEColor needs, forces the light and then
    the dark appearance through revIDEIsDark()'s test override and evaluates
    every pair of tools/ci/ide-contrast-pairs.txt (foreground tag,
    background tag, minimum ratio).

    The script itself compares the failing pairs with
    tools/ci/ide-contrast-baseline.txt and sets its exit code; this wrapper
    only runs it, prints its output and, under GitHub Actions, adds
    annotations, a job summary and the step outputs "pairs", "failed",
    "new" and "fixed". The check fails when a pair fails that is not in the
    baseline, when a tag gives no colour, or when the engine did not finish.
    Baseline entries that pass now are reported as warnings.

    With -UpdateBaseline the baseline is rewritten with the pairs that fail
    now.

    The same engine then checks that the patches of tools/oxt/ide-stack-patches
    are applied to the layout's binary IDE stacks
    (tools/oxt/ide-stack-patch.livecodescript with OXT_PATCH_CHECK=1, which
    never saves). tools/ci/check_ide_stacks.py sees script patches in the
    stack files' bytes without an engine, but not property patches (colours
    and other properties are stored in binary form), so this is where those
    are checked. A patch that is not applied fails the check.

    Last, the engine runs tools/ci/ide-appearance-check.livecodescript on the
    layout: the first-install appearance preferences, and revIDEIsDark and
    revIDEApplyAppearance on this engine (with or without the engine's
    appearance properties). A failed check fails the step.

    The check also fails when it did not check the dark appearance (a
    layout without revIDEIsDark()), unless the environment variable
    OXT_CONTRAST_LIGHT_ONLY is 1 (the engine inherits it).

    Written to run under Windows PowerShell 5.1 and PowerShell 7.

.PARAMETER Root
    The installed layout to check (the folder with Toolset). Default: the
    single OXT-Beyond-* folder in <RepoRoot>\dist\stage.

.PARAMETER Engine
    The development engine to run. Default: <Root>\OXT-Beyond.exe, or
    <RepoRoot>\win-x86_64-bin\LiveCode-Community.exe when the layout has no
    engine.

.PARAMETER RepoRoot
    Repository root. Default: two levels up from this script.

.PARAMETER UpdateBaseline
    Rewrite tools\ci\ide-contrast-baseline.txt with the failing pairs.

.PARAMETER LogFile
    Optional file to write the engine's output to.

.PARAMETER TimeoutSeconds
    How long to wait for the engine. Default: 180.
#>
[CmdletBinding()]
param(
    [string]$Root,
    [string]$Engine,
    [string]$RepoRoot,
    [switch]$UpdateBaseline,
    [string]$LogFile,
    [ValidateRange(30, 3600)]
    [int]$TimeoutSeconds = 180
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$utf8 = New-Object System.Text.UTF8Encoding($false)
$checkScript = Join-Path $PSScriptRoot 'ide-contrast-check.livecodescript'
if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '..\..' }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath.TrimEnd('\')

# --- Layout and engine ---
if (-not $Root) {
    $stage = Join-Path $RepoRoot 'dist\stage'
    $candidates = @()
    if (Test-Path -LiteralPath $stage -PathType Container) {
        $candidates = @(Get-ChildItem -LiteralPath $stage -Directory -Filter 'OXT-Beyond-*')
    }
    if ($candidates.Count -ne 1) { throw "Pass -Root: expected one OXT-Beyond-* folder in $stage, found $($candidates.Count)" }
    $Root = $candidates[0].FullName
}
if (-not (Test-Path -LiteralPath (Join-Path $Root 'Toolset') -PathType Container)) {
    throw "Not an installed layout (no Toolset folder): $Root"
}
$Root = (Resolve-Path -LiteralPath $Root).ProviderPath.TrimEnd('\')

if (-not $Engine) {
    $Engine = Join-Path $Root 'OXT-Beyond.exe'
    if (-not (Test-Path -LiteralPath $Engine -PathType Leaf)) {
        $Engine = Join-Path $RepoRoot 'win-x86_64-bin\LiveCode-Community.exe'
    }
}
if (-not (Test-Path -LiteralPath $Engine -PathType Leaf)) { throw "Engine not found: $Engine" }
$Engine = (Resolve-Path -LiteralPath $Engine).ProviderPath

Write-Host "Layout   : $Root"
Write-Host "Engine   : $Engine"
Write-Host "Checker  : $checkScript"
Write-Host ''

# Reads a text file as UTF-8 lines without line endings
function Read-Lines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $text = [System.IO.File]::ReadAllText($Path, $utf8)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return @($text -split "`r?`n")
}

# --- Run the engine without a user interface ---
# As in ide-compile-check.ps1: a GUI-subsystem program, so start it with
# redirected output and wait for it explicitly, in an empty temporary
# folder. A script that does not compile makes the engine wait instead of
# exiting, hence the timeout. $Environment holds the variables to set for
# the run; the previous values are restored.
$base = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
$workDir = Join-Path $base ('oxt-contrast-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

function Invoke-Headless([string]$Script, [hashtable]$Environment, [string]$Name) {
    $outFile = Join-Path $workDir "$Name-stdout.txt"
    $errFile = Join-Path $workDir "$Name-stderr.txt"
    $saved = @{}
    foreach ($key in $Environment.Keys) {
        $saved[$key] = [Environment]::GetEnvironmentVariable($key)
        [Environment]::SetEnvironmentVariable($key, $Environment[$key])
    }
    $run = [pscustomobject]@{ Output = @(); Stderr = @(); ExitCode = $null; TimedOut = $false; Elapsed = 0 }
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $process = Start-Process -FilePath $Engine -ArgumentList @('-ui', ('"{0}"' -f $Script)) `
            -WorkingDirectory $workDir -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
            -NoNewWindow -PassThru
        # Read the handle now: without it, ExitCode is empty after the process
        # has exited (a known Start-Process -PassThru quirk).
        $null = $process.Handle
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $run.TimedOut = $true
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $null = $process.WaitForExit(30000)
        }
        else {
            $process.WaitForExit()
            $run.ExitCode = $process.ExitCode
        }
        $run.Output = @(Read-Lines $outFile | Where-Object { $_ -ne '' })
        $run.Stderr = @(Read-Lines $errFile | Where-Object { $_ -ne '' })
    }
    finally {
        foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key]) }
    }
    $run.Elapsed = $timer.Elapsed.TotalSeconds
    return $run
}

$contrastRun = Invoke-Headless $checkScript @{
    OXT_CHECK_ROOT = $Root
    OXT_CONTRAST_UPDATE = $(if ($UpdateBaseline) { '1' } else { '' })
} 'contrast'
$output = $contrastRun.Output
$stderr = $contrastRun.Stderr
$exitCode = $contrastRun.ExitCode
$timedOut = $contrastRun.TimedOut
$elapsed = $contrastRun.Elapsed

$output | ForEach-Object { Write-Host $_ }
if ($stderr.Count -gt 0) {
    Write-Host ''
    Write-Host 'Engine stderr:'
    $stderr | ForEach-Object { Write-Host "  $_" }
}

# --- Result ---
$summaryLine = $output | Where-Object { $_ -match '^SUMMARY ' } | Select-Object -Last 1
$counts = @{}
if ($summaryLine) {
    foreach ($m in [regex]::Matches($summaryLine, '(\w+)=([^ ]+)')) { $counts[$m.Groups[1].Value] = $m.Groups[2].Value }
}
# PAIR <appearance> | <fg> on <bg> | <ratio> | min <min> | <colours> | <status>
$pairs = @()
foreach ($line in $output) {
    if ($line -notmatch '^PAIR ') { continue }
    $f = @($line.Substring(5) -split ' \| ')
    if ($f.Count -lt 6) { continue }
    $pairs += [pscustomobject]@{ Mode = $f[0]; Pair = $f[1]; Ratio = $f[2]; Min = $f[3] -replace '^min ', ''; Colours = $f[4]; Status = $f[5] }
}
$newPairs = @($pairs | Where-Object { $_.Status -eq 'NEW' -or $_.Status -eq 'ERROR' })
$fixed = @($output | Where-Object { $_ -like 'FIXED *' } | ForEach-Object { $_.Substring(6) })
$fatal = $output | Where-Object { $_ -like 'FATAL *' } | Select-Object -First 1

$problem = $null
if ($timedOut) { $problem = "The engine did not finish within $TimeoutSeconds seconds" }
elseif ($fatal) { $problem = "The contrast check could not run: $($fatal.Substring(6))" }
elseif (-not $summaryLine -or ($exitCode -ne 0 -and $exitCode -ne 1)) {
    $problem = "The contrast check did not complete (exit code $exitCode$(if (-not $summaryLine) { ', no SUMMARY line' }))"
}
elseif ($env:OXT_CONTRAST_LIGHT_ONLY -ne '1' -and @("$($counts['modes'])" -split ',') -notcontains 'dark') {
    # The script stops when it cannot check the dark appearance; this is a
    # second guard, so that a green step always means the dark colours were
    # checked (OXT_CONTRAST_LIGHT_ONLY=1 is for measuring an older layout)
    $problem = "The contrast check did not check the dark appearance (modes=$($counts['modes']))"
}
$passed = (-not $problem) -and ($exitCode -eq 0)
$result = if ($problem) { $problem }
          elseif ($UpdateBaseline -and $exitCode -ne 0) { "baseline NOT rewritten: $($counts['errors']) pair(s) could not be evaluated" }
          elseif ($UpdateBaseline) { "baseline rewritten with $($counts['failed']) failing pair(s)" }
          elseif ($passed) { "passed: $($counts['failed']) failing pair(s), all in the baseline" }
          else { "FAILED: $($newPairs.Count) failing pair(s) not in the baseline" }

if ($env:GITHUB_ACTIONS -eq 'true') {
    $n = 0
    foreach ($p in $newPairs) {
        if ($n -ge 20) { break }
        Write-Host ("::error title=IDE contrast check::{0} | {1}: {2} (minimum {3}) {4}" -f $p.Mode, $p.Pair, $p.Ratio, $p.Min, $p.Colours)
        $n++
    }
    $n = 0
    foreach ($e in $fixed) {
        if ($n -ge 10) { break }
        Write-Host "::warning title=IDE contrast check::Passes now, remove it from tools/ci/ide-contrast-baseline.txt: $e"
        $n++
    }
    if ($problem) { Write-Host "::error title=IDE contrast check::$problem" }
}

# --- More headless checks with the same engine and layout ---
# Each prints a SUMMARY line and exits with 0 when it passed; lines that
# start with a word in its $Problems pattern are reported as errors.
$extraChecks = @(
    [pscustomobject]@{
        Title = 'IDE stack patches'
        Script = Join-Path $RepoRoot 'tools\oxt\ide-stack-patch.livecodescript'
        Environment = @{ OXT_PATCH_ROOT = $Root; OXT_PATCH_CHECK = '1'; OXT_PATCH_DIR = '' }
        Problems = '^(PATCH .*\| (FAILED|NOT APPLIED)|FILE .*\| FAILED|FATAL )'
        Name = 'patches'
    }
    [pscustomobject]@{
        Title = 'IDE appearance'
        Script = Join-Path $PSScriptRoot 'ide-appearance-check.livecodescript'
        Environment = @{ OXT_CHECK_ROOT = $Root }
        Problems = '^(CHECK .*\| FAILED|FATAL )'
        Name = 'appearance'
    }
)
$extraResults = @()
foreach ($check in $extraChecks) {
    Write-Host ''
    Write-Host "--- $($check.Title) ($($check.Script))"
    $run = Invoke-Headless $check.Script $check.Environment $check.Name
    $run.Output | ForEach-Object { Write-Host $_ }
    if ($run.Stderr.Count -gt 0) {
        Write-Host 'Engine stderr:'
        $run.Stderr | ForEach-Object { Write-Host "  $_" }
    }
    $problems = @($run.Output | Where-Object { $_ -match $check.Problems })
    $checkSummary = $run.Output | Where-Object { $_ -match '^SUMMARY ' } | Select-Object -Last 1
    $checkResult = if ($run.TimedOut) { "the engine did not finish within $TimeoutSeconds seconds" }
                   elseif (-not $checkSummary) { "did not complete (exit code $($run.ExitCode), no SUMMARY line)" }
                   elseif ($run.ExitCode -ne 0) { "FAILED: $($checkSummary.Substring(8))" }
                   else { "passed: $($checkSummary.Substring(8))" }
    $checkPassed = (-not $run.TimedOut) -and $checkSummary -and ($run.ExitCode -eq 0)
    if (-not $checkPassed) { $passed = $false }
    if ($env:GITHUB_ACTIONS -eq 'true') {
        foreach ($line in ($problems | Select-Object -First 20)) { Write-Host "::error title=$($check.Title)::$line" }
        if (-not $checkPassed -and $problems.Count -eq 0) { Write-Host "::error title=$($check.Title)::$checkResult" }
    }
    Write-Host "$($check.Title): $checkResult"
    $extraResults += [pscustomobject]@{ Title = $check.Title; Result = $checkResult; Passed = $checkPassed; Run = $run; Problems = $problems }
}

# --- Log, step outputs and job summary ---
if ($LogFile) {
    $logDir = Split-Path -Parent $LogFile
    if ($logDir) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $log = @("Layout: $Root", "Engine: $Engine", '') + @($output) + @('', 'stderr:') + @($stderr) + @('', "Result: $result")
    foreach ($r in $extraResults) {
        $log += @('', "--- $($r.Title)") + @($r.Run.Output) + @('', 'stderr:') + @($r.Run.Stderr) + @('', "Result: $($r.Result)")
    }
    [System.IO.File]::WriteAllText($LogFile, ($log -join "`r`n") + "`r`n", $utf8)
}
if ($env:GITHUB_OUTPUT -and $summaryLine) {
    [System.IO.File]::AppendAllText($env:GITHUB_OUTPUT,
        "pairs=$($counts['pairs'])`nfailed=$($counts['failed'])`nnew=$($counts['new'])`nfixed=$($counts['fixed'])`n", $utf8)
}
if ($env:GITHUB_STEP_SUMMARY) {
    $md = @('### IDE contrast check', '')
    if ($summaryLine) {
        $md += ('{0} pair(s) in {1} ({2:N0} s): {3} below their minimum, {4} of them in the baseline, {5} new; {6} baseline entr{7} pass{8} now.' -f
            $counts['pairs'], ($counts['modes'] -replace ',', ' and '), $elapsed, $counts['failed'], $counts['known'], $counts['new'],
            $counts['fixed'], $(if ($counts['fixed'] -eq '1') { 'y' } else { 'ies' }), $(if ($counts['fixed'] -eq '1') { 'es' } else { '' }))
    }
    $md += @('', "Result: **$result**", '')
    if ($pairs.Count -gt 0) {
        $md += @('<details><summary>All pairs</summary>', '', '| Appearance | Foreground on background | Ratio | Minimum | Colours | Status |', '| --- | --- | ---: | ---: | --- | --- |')
        foreach ($p in $pairs) {
            $status = if ($p.Status -eq 'pass') { 'pass' } else { "**$($p.Status)**" }
            $md += "| $($p.Mode) | $($p.Pair) | $($p.Ratio) | $($p.Min) | $($p.Colours) | $status |"
        }
        $md += @('', '</details>', '')
    }
    if ($fixed.Count -gt 0) {
        $md += @('Passing now (remove from `tools/ci/ide-contrast-baseline.txt`):', '', '```text')
        $md += $fixed
        $md += @('```', '')
    }
    foreach ($r in $extraResults) {
        $md += @("#### $($r.Title)", '', "Result: **$($r.Result)**", '')
        if ($r.Problems.Count -gt 0) {
            $md += @('```text') + @($r.Problems | Select-Object -First 50) + @('```', '')
        }
    }
    [System.IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, ($md -join "`n") + "`n", $utf8)
}

Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host ("IDE contrast check: {0} ({1:N1} s)." -f $result, $elapsed)
foreach ($r in $extraResults) { Write-Host ("{0}: {1} ({2:N1} s)." -f $r.Title, $r.Result, $r.Run.Elapsed) }
if ($passed) { exit 0 }
exit 1
