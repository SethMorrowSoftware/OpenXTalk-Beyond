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
# exiting, hence the timeout.
$base = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
$workDir = Join-Path $base ('oxt-contrast-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
$outFile = Join-Path $workDir 'stdout.txt'
$errFile = Join-Path $workDir 'stderr.txt'

$saved = @{ Root = $env:OXT_CHECK_ROOT; Update = $env:OXT_CONTRAST_UPDATE }
$env:OXT_CHECK_ROOT = $Root
$env:OXT_CONTRAST_UPDATE = $(if ($UpdateBaseline) { '1' } else { '' })

$output = @()
$stderr = @()
$exitCode = $null
$timedOut = $false
$timer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $process = Start-Process -FilePath $Engine -ArgumentList @('-ui', ('"{0}"' -f $checkScript)) `
        -WorkingDirectory $workDir -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
        -NoNewWindow -PassThru
    # Read the handle now: without it, ExitCode is empty after the process
    # has exited (a known Start-Process -PassThru quirk).
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $timedOut = $true
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $null = $process.WaitForExit(30000)
    }
    else {
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    }
    $output = @(Read-Lines $outFile | Where-Object { $_ -ne '' })
    $stderr = @(Read-Lines $errFile | Where-Object { $_ -ne '' })
}
finally {
    $env:OXT_CHECK_ROOT = $saved.Root
    $env:OXT_CONTRAST_UPDATE = $saved.Update
}
$elapsed = $timer.Elapsed.TotalSeconds

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

# --- Log, step outputs and job summary ---
if ($LogFile) {
    $logDir = Split-Path -Parent $LogFile
    if ($logDir) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $log = @("Layout: $Root", "Engine: $Engine", '') + @($output) + @('', 'stderr:') + @($stderr) + @('', "Result: $result")
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
    [System.IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, ($md -join "`n") + "`n", $utf8)
}

Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host ("IDE contrast check: {0} ({1:N1} s)." -f $result, $elapsed)
if ($passed) { exit 0 }
exit 1
