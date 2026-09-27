<#
.SYNOPSIS
    Packages a Windows build (win-x86_64-bin) into release zips.

.DESCRIPTION
    Writes to OutDir (default <RepoRoot>\dist):

      OpenXTalkLite-<ver>-win-x86_64-ide.zip
          A runnable IDE in the repository ("development") layout, under one
          top folder OpenXTalkLite-<ver>-win-x86_64\:
            win-x86_64-bin\              build output without *.pdb
            ide\, ide-support\, extensions\script-libraries\, docs\
            engine\src\*.lcb, libscript\src\*.lcb
            engine\rsrc\standalone.ico, engine\rsrc\document.ico
            LICENSE, LICENSE-EXCEPTION.md, THIRD-PARTY-NOTICES.md
            README-FIRST.txt
          The engine finds the IDE by looking for the win-x86_64-bin folder
          in its own path and loading ide\ next to it (guessRepositoryPath in
          engine/src/environment/stackbehavior.livecodescript), so the two
          folders must stay siblings. In this layout the IDE builds its
          dictionary from docs\ and the *.lcb files on first launch. The
          engine\rsrc icons are what "Save as Standalone Application" uses
          for Windows in this layout (ide-support/revsaveasstandalone).

      OpenXTalkLite-<ver>-win-x86_64-binaries.zip
          win-x86_64-bin\ without *.pdb, plus the licence files. Extracting it
          into the root of a source checkout gives the same layout as a build.

      OpenXTalkLite-<ver>-win-x86_64-symbols.zip
          The *.pdb files, under win-x86_64-bin\ with their relative paths.

      SHA256SUMS
          "<sha256>  <file name>" for the three zips (LF line endings).

    The zips are written straight from the source files, so nothing is
    copied into a staging folder and nothing is written outside OutDir. Files
    under ide, ide-support, extensions\script-libraries, docs, engine\src and
    libscript\src are taken from "git ls-files", so ignored and untracked
    files (for example a locally generated dictionary or ide\environment_log.txt)
    are left out. Without git, the folders are copied as they are.

    Written to run under Windows PowerShell 5.1 and PowerShell 7.

.PARAMETER RepoRoot
    Repository root. Default: two levels up from this script.

.PARAMETER OutDir
    Output folder. Default: <RepoRoot>\dist. Existing files with the same
    names are replaced; other files are left alone.

.PARAMETER Version
    Version used in the file names. Default: BUILD_SHORT_VERSION from
    <RepoRoot>\version (for example 9.7.1-OXT).

.PARAMETER BinDir
    Build output folder. Default: <RepoRoot>\win-x86_64-bin.

.PARAMETER SourceRevision
    Commit written into README-FIRST.txt. Default: GITHUB_SHA, else
    "git rev-parse HEAD".

.PARAMETER CompressionLevel
    Optimal (default), Fastest or NoCompression.

.PARAMETER NoGit
    Copy the source folders as they are instead of using "git ls-files".
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutDir,
    [string]$Version,
    [string]$BinDir,
    [string]$SourceRevision,
    [ValidateSet('Optimal', 'Fastest', 'NoCompression')]
    [string]$CompressionLevel = 'Optimal',
    [switch]$NoGit
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ZipFileExtensions lives in System.IO.Compression.FileSystem on .NET
# Framework (Windows PowerShell) and in System.IO.Compression.ZipFile on .NET
# (PowerShell 7)
foreach ($assembly in @('System.IO.Compression', 'System.IO.Compression.FileSystem', 'System.IO.Compression.ZipFile')) {
    try { Add-Type -AssemblyName $assembly -ErrorAction Stop } catch { }
}
if (-not ('System.IO.Compression.ZipFileExtensions' -as [type])) {
    throw 'System.IO.Compression.ZipFileExtensions is not available in this PowerShell.'
}

$Platform = 'win-x86_64'
$BinName = "$Platform-bin"
$ProductFilePrefix = 'OpenXTalkLite'

# Paths (relative to the repository root) that the IDE needs next to
# win-x86_64-bin when it runs in the repository layout
$SourceTrees = @('ide', 'ide-support', 'extensions/script-libraries', 'docs')
$SourceGlobs = @(
    @{ Dir = 'engine/src'; Filter = '*.lcb' },
    @{ Dir = 'libscript/src'; Filter = '*.lcb' }
)
$SourceFiles = @('engine/rsrc/standalone.ico', 'engine/rsrc/document.ico')
$LicenseFiles = @('LICENSE', 'LICENSE-EXCEPTION.md', 'THIRD-PARTY-NOTICES.md')

$utf8 = New-Object System.Text.UTF8Encoding($false)

# --- Arguments ---
if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '..\..' }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath.TrimEnd('\')
if (-not $BinDir) { $BinDir = Join-Path $RepoRoot $BinName }
if (-not (Test-Path -LiteralPath (Join-Path $BinDir 'LiveCode-Community.exe'))) {
    throw "No build found: $BinDir\LiveCode-Community.exe does not exist."
}
$BinDir = (Resolve-Path -LiteralPath $BinDir).ProviderPath.TrimEnd('\')
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot 'dist' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).ProviderPath.TrimEnd('\')

if (-not $Version) {
    $versionFile = Join-Path $RepoRoot 'version'
    $m = Select-String -LiteralPath $versionFile -Pattern '^\s*BUILD_SHORT_VERSION\s*=\s*(\S+)\s*$' | Select-Object -First 1
    if (-not $m) { throw "BUILD_SHORT_VERSION not found in $versionFile" }
    $Version = $m.Matches[0].Groups[1].Value
}
if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    throw "Version '$Version' is not usable in a file name."
}

# Run git in the repository; returns the exit code and the stdout lines
function Invoke-GitQuery([string[]]$Arguments) {
    # Windows PowerShell turns redirected stderr into errors, which 'Stop'
    # would make fatal
    $ErrorActionPreference = 'Continue'
    $out = & git -C $RepoRoot @Arguments 2>$null
    $code = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    return New-Object PSObject -Property @{ Code = $code; Out = @($out) }
}

$useGit = $false
if (-not $NoGit -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $inside = Invoke-GitQuery @('rev-parse', '--is-inside-work-tree')
    $useGit = ($inside.Code -eq 0 -and ($inside.Out -join '').Trim() -eq 'true')
}
if (-not $NoGit -and -not $useGit) {
    Write-Warning "$RepoRoot is not a git checkout (or git is missing); packaging the source folders as they are on disk."
}

if (-not $SourceRevision) {
    if ($env:GITHUB_SHA) {
        $SourceRevision = $env:GITHUB_SHA
    }
    elseif ($useGit) {
        $head = Invoke-GitQuery @('rev-parse', 'HEAD')
        if ($head.Code -eq 0) { $SourceRevision = ($head.Out -join '').Trim() }
    }
}

$PackageRoot = "$ProductFilePrefix-$Version-$Platform"

# The engine decides it is running from a source tree when a folder in its
# path is called build-win-x86_64, win-x86_64-bin, win-bin or _build, checked
# in that order, and takes the folder above the first match as the
# repository. The package's own top folder must not look like one of those,
# or ide\ would be looked for in the wrong place.
if ($PackageRoot -like '*-bin' -or $PackageRoot -like 'build-win-*' -or $PackageRoot -eq 'win-bin' -or $PackageRoot -eq '_build') {
    throw "Package folder name '$PackageRoot' would confuse the IDE's repository detection."
}

$IdeZipName = "$PackageRoot-ide.zip"
$BinZipName = "$PackageRoot-binaries.zip"
$SymZipName = "$PackageRoot-symbols.zip"

Write-Host "Repository : $RepoRoot"
Write-Host "Build      : $BinDir"
Write-Host "Output     : $OutDir"
Write-Host "Version    : $Version"
Write-Host "Revision   : $SourceRevision"
Write-Host "Sources    : $(if ($useGit) { 'git ls-files' } else { 'folders on disk' })"

# --- Helpers ---

function New-Entry([string]$Source, [string]$Name) {
    return New-Object PSObject -Property @{ Source = $Source; Name = $Name }
}

# Files under a folder, as paths relative to it with '/' separators
function Get-RelativeFiles([string]$Dir) {
    $prefixLength = $Dir.TrimEnd('\').Length + 1
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force)) {
        $f.FullName.Substring($prefixLength).Replace('\', '/')
    }
}

# Tracked files under the given repository-relative paths
function Get-GitFiles([string[]]$Paths) {
    # Decode git's output as UTF-8 in case a file name is not ASCII
    $savedEncoding = $null
    try { $savedEncoding = [Console]::OutputEncoding; [Console]::OutputEncoding = $utf8 } catch { }
    try {
        $result = Invoke-GitQuery (@('-c', 'core.quotepath=off', 'ls-files', '-z', '--') + $Paths)
        if ($result.Code -ne 0) { throw "git ls-files failed (exit code $($result.Code)) for: $($Paths -join ', ')" }
    }
    finally {
        if ($savedEncoding) { try { [Console]::OutputEncoding = $savedEncoding } catch { } }
    }
    $separators = [char[]]@([char]0)
    $newlines = [char[]]@([char]13, [char]10)
    return (($result.Out -join "`n").Split($separators, [System.StringSplitOptions]::RemoveEmptyEntries) |
            ForEach-Object { $_.Trim($newlines) } | Where-Object { $_ })
}

function Test-GitMetadataFile([string]$RelPath) {
    $leaf = $RelPath.Substring($RelPath.LastIndexOf('/') + 1)
    return ($leaf -like '.git*')
}

# Repository files for the IDE package, as '/'-separated relative paths
function Get-SourceFileList {
    $list = New-Object System.Collections.Generic.List[string]
    if ($useGit) {
        foreach ($p in (Get-GitFiles $SourceTrees)) { $list.Add($p) }
        foreach ($g in $SourceGlobs) {
            # Only files directly in the folder (git's '*' also crosses '/')
            foreach ($p in (Get-GitFiles @("$($g.Dir)/$($g.Filter)"))) {
                if ($p.Substring(0, $p.LastIndexOf('/')) -eq $g.Dir) { $list.Add($p) }
            }
        }
        foreach ($p in (Get-GitFiles $SourceFiles)) { $list.Add($p) }
    }
    else {
        foreach ($t in $SourceTrees) {
            $dir = Join-Path $RepoRoot ($t.Replace('/', '\'))
            if (-not (Test-Path -LiteralPath $dir)) { throw "Missing folder: $dir" }
            foreach ($rel in (Get-RelativeFiles $dir)) {
                if ($rel -notmatch '(^|/)\.git(/|$)') { $list.Add("$t/$rel") }
            }
        }
        foreach ($g in $SourceGlobs) {
            $dir = Join-Path $RepoRoot ($g.Dir.Replace('/', '\'))
            foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter $g.Filter -File)) {
                $list.Add("$($g.Dir)/$($f.Name)")
            }
        }
        foreach ($p in $SourceFiles) { $list.Add($p) }
    }

    $result = New-Object System.Collections.Generic.List[string]
    $missing = 0
    foreach ($p in $list) {
        if (Test-GitMetadataFile $p) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot ($p.Replace('/', '\'))) -PathType Leaf)) {
            $missing++
            continue
        }
        $result.Add($p)
    }
    if ($missing -gt 0) {
        Write-Warning "$missing tracked file(s) are missing from the working tree and were skipped."
    }
    return $result
}

function Get-ReadmeText {
    $rev = if ($SourceRevision) { $SourceRevision } else { '(unknown)' }
    $lines = @(
        "OpenXTalk Lite $Version for Windows x86-64",
        '',
        'This folder contains the OpenXTalk Lite IDE in the same layout as a',
        'source checkout of https://github.com/SethMorrowSoftware/winoxt, with',
        'the build output already in place.',
        '',
        'To start the IDE, run:',
        '',
        "    $BinName\LiveCode-Community.exe",
        '',
        'Keep the layout as it is:',
        '',
        "- Do not rename or move the $BinName or ide folders. The program finds",
        "  the IDE by looking for the folder named $BinName and then loads the",
        '  ide folder next to it.',
        '- Extract the zip to a folder you can write to, for example one under',
        '  your user profile rather than Program Files. On first launch the',
        '  IDE builds its dictionary from the docs folder and writes it under',
        '  ide\Documentation, so the first start takes longer.',
        '- Do not extract it into a folder whose path already contains a',
        "  folder named build-win-x86_64 or $BinName. The IDE looks for",
        '  those names in its own path and would then look for its files in',
        '  the wrong place.',
        '',
        'Program files, window titles and the IDE still use the LiveCode name.',
        'OpenXTalk Lite is based on LiveCode Community (GPLv3), and renaming',
        'has not been done yet.',
        '',
        'The executables are not code-signed, so Windows SmartScreen may warn',
        'when you run them for the first time.',
        '',
        'Debug symbols (*.pdb) are in the separate',
        "$SymZipName file.",
        '',
        'Licence: GNU General Public License version 3. LICENSE-EXCEPTION.md',
        'describes an additional permission and which parts it covers. See',
        'LICENSE and THIRD-PARTY-NOTICES.md.',
        '',
        'Source code: https://github.com/SethMorrowSoftware/winoxt',
        "Built from commit: $rev"
    )
    return (($lines -join "`r`n") + "`r`n")
}

# Write a zip from a list of entries (Source file -> Name inside the zip)
# and optional text entries (Name -> content)
function Write-Zip([string]$Path, $Entries, [hashtable]$TextEntries) {
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    $level = [System.IO.Compression.CompressionLevel]::$CompressionLevel
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($e in $Entries) {
                [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $e.Source, $e.Name, $level)
            }
            if ($TextEntries) {
                foreach ($name in ($TextEntries.Keys | Sort-Object)) {
                    $entry = $zip.CreateEntry($name, $level)
                    $entry.LastWriteTime = [DateTimeOffset]::Now
                    $writer = New-Object System.IO.StreamWriter($entry.Open(), $utf8)
                    try { $writer.Write([string]$TextEntries[$name]) } finally { $writer.Dispose() }
                }
            }
        }
        finally {
            $zip.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

# --- Collect the build output ---
$binFiles = @(Get-RelativeFiles $BinDir | Sort-Object)
$binNoPdb = New-Object System.Collections.Generic.List[object]
$binPdb = New-Object System.Collections.Generic.List[object]
foreach ($rel in $binFiles) {
    $src = Join-Path $BinDir ($rel.Replace('/', '\'))
    if ($rel -like '*.pdb') {
        $binPdb.Add((New-Entry $src "$BinName/$rel"))
    }
    else {
        $binNoPdb.Add((New-Entry $src "$BinName/$rel"))
    }
}
Write-Host "Build output: $($binNoPdb.Count) files, plus $($binPdb.Count) *.pdb files"
if ($binPdb.Count -eq 0) { Write-Warning "No *.pdb files in $BinDir; the symbols zip will be empty." }

# --- Licence files ---
$licenseEntries = New-Object System.Collections.Generic.List[object]
foreach ($name in $LicenseFiles) {
    $p = Join-Path $RepoRoot $name
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        $licenseEntries.Add((New-Entry $p $name))
    }
    else {
        Write-Warning "$name not found in $RepoRoot; it is not included in the packages."
    }
}

# --- IDE package ---
$ideEntries = New-Object System.Collections.Generic.List[object]
foreach ($e in $binNoPdb) { $ideEntries.Add((New-Entry $e.Source "$PackageRoot/$($e.Name)")) }
$sourceList = @(Get-SourceFileList | Sort-Object)
foreach ($rel in $sourceList) {
    $ideEntries.Add((New-Entry (Join-Path $RepoRoot ($rel.Replace('/', '\'))) "$PackageRoot/$rel"))
}
foreach ($e in $licenseEntries) { $ideEntries.Add((New-Entry $e.Source "$PackageRoot/$($e.Name)")) }
$readmeName = "$PackageRoot/README-FIRST.txt"
Write-Host "Repository files for the IDE package: $($sourceList.Count)"

# Check the layout before writing anything
$names = @{}
foreach ($e in $ideEntries) {
    if ($names.ContainsKey($e.Name)) { throw "Duplicate zip entry: $($e.Name)" }
    $names[$e.Name] = $true
}
foreach ($required in @("$PackageRoot/$BinName/LiveCode-Community.exe",
                        "$PackageRoot/ide/Toolset/home.livecodescript",
                        "$PackageRoot/ide-support/revdocsparser.livecodescript",
                        "$PackageRoot/docs/dictionary")) {
    $found = $names.ContainsKey($required)
    if (-not $found) {
        foreach ($k in $names.Keys) { if ($k.StartsWith("$required/")) { $found = $true; break } }
    }
    if (-not $found) { throw "The IDE package would be missing $required" }
}
foreach ($e in $ideEntries) {
    if ($e.Name -like '*.pdb') { throw "A *.pdb file would go into the IDE package: $($e.Name)" }
}

# --- Write the zips ---
$idePath = Join-Path $OutDir $IdeZipName
$binPath = Join-Path $OutDir $BinZipName
$symPath = Join-Path $OutDir $SymZipName
$sumsPath = Join-Path $OutDir 'SHA256SUMS'
if (Test-Path -LiteralPath $sumsPath) { Remove-Item -LiteralPath $sumsPath -Force }

$timer = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Writing $IdeZipName ..."
Write-Zip $idePath $ideEntries @{ $readmeName = (Get-ReadmeText) }

Write-Host "Writing $BinZipName ..."
$binZipEntries = New-Object System.Collections.Generic.List[object]
foreach ($e in $binNoPdb) { $binZipEntries.Add($e) }
foreach ($e in $licenseEntries) { $binZipEntries.Add($e) }
Write-Zip $binPath $binZipEntries $null

Write-Host "Writing $SymZipName ..."
Write-Zip $symPath $binPdb $null
Write-Host ("Zips written in {0:N0} s" -f $timer.Elapsed.TotalSeconds)

# --- Checksums ---
$results = @()
$sumLines = @()
foreach ($p in @($idePath, $binPath, $symPath)) {
    $item = Get-Item -LiteralPath $p
    $hash = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()
    $sumLines += "$hash  $($item.Name)"
    $count = 0
    $archive = [System.IO.Compression.ZipFile]::OpenRead($p)
    try { $count = $archive.Entries.Count } finally { $archive.Dispose() }
    $results += New-Object PSObject -Property @{ Name = $item.Name; Bytes = $item.Length; Entries = $count; Sha256 = $hash }
}
[System.IO.File]::WriteAllText($sumsPath, (($sumLines -join "`n") + "`n"), $utf8)

Write-Host ''
Write-Host "Packages in ${OutDir}:"
foreach ($r in $results) {
    Write-Host ('  {0,-52} {1,10:N1} MB  {2,6} entries' -f $r.Name, ($r.Bytes / 1MB), $r.Entries)
}
Write-Host '  SHA256SUMS'
foreach ($line in $sumLines) { Write-Host "    $line" }

# --- GitHub Actions outputs and job summary ---
if ($env:GITHUB_OUTPUT) {
    [System.IO.File]::AppendAllText($env:GITHUB_OUTPUT,
        "version=$Version`npackage-root=$PackageRoot`ndist-dir=$OutDir`n", $utf8)
}
if ($env:GITHUB_STEP_SUMMARY) {
    $md = @('### Packages', '', '| File | Size | Entries | SHA-256 |', '| --- | --- | --- | --- |')
    foreach ($r in $results) {
        $md += ('| {0} | {1:N1} MB | {2} | `{3}` |' -f $r.Name, ($r.Bytes / 1MB), $r.Entries, $r.Sha256)
    }
    $md += ''
    [System.IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, ($md -join "`n") + "`n", $utf8)
}
