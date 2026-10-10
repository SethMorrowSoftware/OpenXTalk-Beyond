<#
.SYNOPSIS
    Captures the files that install-vs-components.ps1 adds to Visual Studio,
    so that CI can cache them, and unpacks them again.

.DESCRIPTION
    Adding the MSVC v141 toolset with the Visual Studio installer takes about
    five minutes in each Windows build job. build-windows.yml caches what the
    installer adds instead, in one 7-Zip archive with full paths, under a key
    that holds the runner image's name and version: a new image, with a new
    Visual Studio, never gets files captured on an older one.

    -List writes every file under the folders the installer changes (the
    Visual Studio folder, Visual Studio's Shared folder, the old MSBuild
    folder and Windows Kits\10) with its size and time of last write, one
    tab-separated line each. Run it before the installer.

    -Pack lists the same folders again, after the installer, and writes the
    files that are new or changed since the -List file into the archive. The
    installer's own records (ProgramData\Microsoft\VisualStudio\Packages) are
    left out: an installation restored from the archive does not show the
    added components to the installer, so that, if anything is missing,
    install-vs-components.ps1 still runs the installer, which then adds them
    in full.

    -Unpack extracts the archive to the paths it holds and deletes it. If
    7-Zip fails, it removes the v141 tools folder again, so that
    install-vs-components.ps1 finds the toolset missing and installs it.

.PARAMETER List
    File to write the list of files to.

.PARAMETER Pack
    The -List file written before the installer ran.

.PARAMETER Unpack
    Archive to extract.

.PARAMETER Archive
    Archive that -Pack writes.

.PARAMETER InstallPath
    Visual Studio folder. Default: the newest installation vswhere reports.
#>
[CmdletBinding(DefaultParameterSetName = 'List')]
param(
    [Parameter(Mandatory, ParameterSetName = 'List')]
    [string]$List,
    [Parameter(Mandatory, ParameterSetName = 'Pack')]
    [string]$Pack,
    [Parameter(Mandatory, ParameterSetName = 'Pack')]
    [string]$Archive,
    [Parameter(Mandatory, ParameterSetName = 'Unpack')]
    [string]$Unpack,
    [string]$InstallPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-VisualStudioPath {
    if ($InstallPath) { return $InstallPath.TrimEnd('\') }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $path = & $vswhere -products * -latest -property installationPath -nologo
    if ($LASTEXITCODE -ne 0 -or -not $path) { throw 'vswhere found no Visual Studio installation' }
    return ([string]@($path)[0]).Trim().TrimEnd('\')
}

# Every file under the folders the installer changes, as "path<TAB>size<TAB>ticks"
function Get-FileLines {
    $roots = @(
        (Get-VisualStudioPath),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Shared'),
        (Join-Path ${env:ProgramFiles(x86)} 'MSBuild'),
        (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10')
    )
    $options = [System.IO.EnumerationOptions]::new()
    $options.RecurseSubdirectories = $true
    $options.IgnoreInaccessible = $true
    # Hidden and system files too, but not what a link points to
    $options.AttributesToSkip = [System.IO.FileAttributes]::ReparsePoint
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($file in [System.IO.DirectoryInfo]::new($root).EnumerateFiles('*', $options)) {
            $lines.Add("$($file.FullName)`t$($file.Length)`t$($file.LastWriteTimeUtc.Ticks)")
        }
    }
    return , $lines
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
$sevenZip = Get-Command 7z -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$sevenZip = if ($sevenZip) { $sevenZip.Source } else { Join-Path $env:ProgramFiles '7-Zip\7z.exe' }

switch ($PSCmdlet.ParameterSetName) {
    'List' {
        $started = Get-Date
        $lines = Get-FileLines
        [System.IO.File]::WriteAllLines($List, $lines, $utf8)
        Write-Host "Listed $($lines.Count) files in $([int]((Get-Date) - $started).TotalSeconds) s"
    }

    'Pack' {
        $before = [System.Collections.Generic.HashSet[string]]::new(
            [string[]][System.IO.File]::ReadAllLines($Pack, $utf8), [System.StringComparer]::OrdinalIgnoreCase)
        $changed = [System.Collections.Generic.List[string]]::new()
        $bytes = [long]0
        foreach ($line in (Get-FileLines)) {
            if ($before.Contains($line)) { continue }
            $fields = $line.Split("`t")
            $changed.Add($fields[0])
            $bytes += [long]$fields[1]
        }
        if ($changed.Count -eq 0) { throw 'The installer changed no files' }
        Write-Host "$($changed.Count) files new or changed, $([math]::Round($bytes / 1MB)) MB"
        $listFile = "$Archive.txt"
        [System.IO.File]::WriteAllLines($listFile, $changed, $utf8)
        if (Test-Path -LiteralPath $Archive) { Remove-Item -LiteralPath $Archive }
        # -spf: full paths, with the drive; -mx=1: fast, as the files are
        # mostly compressed .lib and .pdb data
        & $sevenZip a -spf -mx=1 -scsUTF-8 -bd -y $Archive "@$listFile" | Select-Object -Last 5 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "7z a exited with code $LASTEXITCODE" }
        Remove-Item -LiteralPath $listFile
        Write-Host "Archive: $Archive, $([math]::Round((Get-Item -LiteralPath $Archive).Length / 1MB)) MB"
    }

    'Unpack' {
        $started = Get-Date
        & $sevenZip x -spf -aoa -bd -y $Unpack | Select-Object -Last 5 | ForEach-Object { Write-Host $_ }
        $code = $LASTEXITCODE
        Remove-Item -LiteralPath $Unpack -ErrorAction SilentlyContinue
        if ($code -ne 0) {
            Write-Host "::warning::7z x exited with code $code; the v141 toolset will be installed instead"
            $msvc = Join-Path (Get-VisualStudioPath) 'VC\Tools\MSVC'
            Get-ChildItem -LiteralPath $msvc -Directory -Filter '14.16.*' -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force
            exit 0
        }
        Write-Host "Unpacked in $([int]((Get-Date) - $started).TotalSeconds) s"
    }
}
