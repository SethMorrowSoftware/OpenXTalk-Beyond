<#
.SYNOPSIS
    Runs player-check.livecodescript in a built OXT-Beyond and prints the result.

.DESCRIPTION
    The engine crashes creating a player in -ui (headless) mode, with either
    player backend, so the check runs in the IDE: OXT-Beyond's windows appear
    while it runs. The stack writes PASS/FAIL/INFO lines to a log file and a
    final SUMMARY line; this script waits for that line and then closes
    OXT-Beyond.

.EXAMPLE
    .\run-player-check.ps1 -ProgramDir C:\path\to\OXT-Beyond-0.2.0 -Media C:\path\to\video.mp4
    Add -Backend directshow to run the same checks against the old player.
#>
param(
    [Parameter(Mandatory = $true)][string] $ProgramDir,
    [Parameter(Mandatory = $true)][string] $Media,
    [string] $Backend = '',
    [int] $TimeoutSeconds = 180
)

$engine = Join-Path $ProgramDir 'OXT-Beyond.exe'
$script = Join-Path $PSScriptRoot 'player-check.livecodescript'
$log = Join-Path ([System.IO.Path]::GetTempPath()) 'oxt-player-check.log'
Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue

$env:OXT_PLAYER_FILE = (Resolve-Path $Media).Path
$env:OXT_PLAYER_LOG = $log
$env:OXT_PLAYER_BACKEND = $Backend

$process = Start-Process -FilePath $engine -ArgumentList @(('"{0}"' -f $script)) -WorkingDirectory $ProgramDir -PassThru
$null = $process.Handle

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$done = $false
while (-not $done -and (Get-Date) -lt $deadline -and -not $process.HasExited) {
    Start-Sleep -Milliseconds 500
    if (Test-Path -LiteralPath $log) {
        $done = [bool](Select-String -LiteralPath $log -Pattern '^SUMMARY ' -Quiet)
    }
}

if (-not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
}
if (Test-Path -LiteralPath $log) {
    Get-Content -LiteralPath $log
}
if (-not $done) {
    if ($process.HasExited) {
        Write-Host "OXT-Beyond exited before the check finished (exit code $($process.ExitCode))"
    }
    else {
        Write-Host "The check did not finish within $TimeoutSeconds seconds"
    }
    exit 1
}
