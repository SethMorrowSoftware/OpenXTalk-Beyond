<#
.SYNOPSIS
    Installs the 64-bit Python 2.7.18 that the Windows build runs config.py
    and gyp with, to C:\Python27.

.DESCRIPTION
    The build needs Python 2.7 at C:\Python27\python.exe (build-windows.ps1).
    It used to come only from Chocolatey's community feed (choco install
    python2), and on 25 Nov 2026 that feed answered 503 and 504 for an hour,
    which failed every Windows build on main twice.

    This script takes it first from nuget.org instead: the Python Software
    Foundation's own python2 package (2.7.18, "64-bit Python 2.7 for use in
    build scenarios"), the same release Chocolatey installs, pinned by its
    SHA-256 so that a changed file is refused. The package holds a complete
    Python under tools\, which is copied to the target folder; nothing is
    installed into Windows and PATH is not changed, as before.

    If that fails (the download, the checksum, or the interpreter will not
    run on the runner), Chocolatey is tried as before, twice. Whatever put
    it there, the interpreter must answer to a 2.7 version, or the step
    fails.

    A Python 2.7 already at the target is kept.

.PARAMETER Target
    Folder to install to. Default: C:\Python27.

.PARAMETER NoChocolatey
    Do not fall back to Chocolatey (to test the nuget.org path alone).
#>
param(
    [string]$Target = 'C:\Python27',
    [switch]$NoChocolatey
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

# Python 2.7 has no releases after 2.7.18, so this pin never has to move.
$NuGetUrl = 'https://api.nuget.org/v3-flatcontainer/python2/2.7.18/python2.2.7.18.nupkg'
$NuGetSha256 = 'c8df5bd4c103f37a946e94f942a5625cdd84665ee160bbcc57af93857c892e22'

$python = Join-Path $Target 'python.exe'

function Get-Python27Version {
    # The version python.exe at the target reports, or $null when it is
    # missing, does not run or is not 2.7.
    if (-not (Test-Path -LiteralPath $python)) { return $null }
    try {
        $v = & $python -c "import sys; sys.stdout.write('%d.%d.%d' % sys.version_info[:3])" 2>&1
    }
    catch {
        Write-Host "$python did not run: $_"
        return $null
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$python exited with code $LASTEXITCODE`: $v"
        return $null
    }
    if (-not "$v".StartsWith('2.7')) {
        Write-Host "$python reports version '$v', expected 2.7"
        return $null
    }
    return "$v"
}

function Install-FromNuGet {
    $work = Join-Path ([IO.Path]::GetTempPath()) ('python27-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    try {
        $package = Join-Path $work 'python2.zip'
        # curl.exe ships with Windows; --retry-all-errors also retries a
        # reset connection, as everywhere else in CI (test_curl_retries.py).
        & curl.exe -fsSL --retry 5 --retry-all-errors --retry-delay 10 -o $package $NuGetUrl
        if ($LASTEXITCODE -ne 0) { throw "curl exited with code $LASTEXITCODE downloading $NuGetUrl" }
        $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $package).Hash.ToLowerInvariant()
        if ($sha -ne $NuGetSha256) { throw "python2 package SHA-256 is $sha, expected $NuGetSha256" }
        $unpacked = Join-Path $work 'unpacked'
        # .NET's own unzip: the package holds [Content_Types].xml, a name
        # Expand-Archive has read as a wildcard in older versions.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($package, $unpacked)
        $tools = Join-Path $unpacked 'tools'
        if (-not (Test-Path -LiteralPath (Join-Path $tools 'python.exe'))) { throw 'the python2 package has no tools\python.exe' }
        if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force }
        Move-Item -LiteralPath $tools -Destination $Target
    }
    finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-FromChocolatey {
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        # Do not request a specific Chocolatey package revision: older
        # mirrors can expose the final Python release under a different one.
        choco install python2 -y --no-progress
        Write-Host "choco exited with code $LASTEXITCODE (attempt $attempt)"
        if (Get-Python27Version) { return }
        if ($attempt -lt 2) { Start-Sleep -Seconds 10 }
    }
}

$version = Get-Python27Version
if ($version) {
    Write-Host "Python $version already at $python"
    exit 0
}

try {
    Install-FromNuGet
    $version = Get-Python27Version
    if ($version) { Write-Host "Python $version at $python (from nuget.org)" }
}
catch {
    Write-Host "Python 2.7 from nuget.org failed: $_"
}

if (-not $version) {
    if ($NoChocolatey) { throw "Python 2.7 was not installed at $Target (Chocolatey not tried)" }
    # Leave nothing half-copied for the MSI to install over.
    if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host 'Trying Chocolatey'
    Install-FromChocolatey
    $version = Get-Python27Version
    if (-not $version) { throw "$python was not installed" }
    Write-Host "Python $version at $python (from Chocolatey)"
}
