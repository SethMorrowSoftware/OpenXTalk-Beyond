# CEF upgrade spike (Windows): the Windows half of cef_spike_linux.sh.
#
# A measuring tool, not part of the build; it changes nothing a build reads.
# Picks the newest stable windows64 CEF (or $env:CEF_VERSION), downloads its
# minimal distribution (SHA-1 from the index) and today's CEF 74 one (SHA-1
# from prebuilt/cef-sha1sums), compares what build-libraries-windows.ps1
# would package, and compiles the libcef_dll wrapper and libbrowser's four
# Windows CEF sources with MSVC (the runner's Visual Studio 2022, v143) at
# each /std in $Stds. The release build uses the v141 toolset, which has no
# /std:c++20 (only /std:c++14, /std:c++17 and /std:c++latest), so a row that
# needs c++20 means a toolset move too.
#
# Output: $Out\report.md (also appended to $env:GITHUB_STEP_SUMMARY), logs
# under $Out\logs.

param(
    [string]$Work = "$PSScriptRoot\..\..\..\.cef-spike",
    [string[]]$Stds = @('c++17', 'c++20')
)
$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
New-Item -ItemType Directory -Force "$Work\dl", "$Work\out\logs", "$Work\obj" | Out-Null
$Work = (Resolve-Path $Work).Path
$Out = "$Work\out"
$Report = "$Out\report.md"
Set-Content $Report ''
function Say([string]$s) { Write-Host $s; Add-Content $Report $s }
function MiB([long]$b) { '{0:N1} MiB' -f ($b / 1MB) }

# Visual Studio's developer environment (cl.exe on PATH)
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
Import-Module "$vs\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
$clVer = (& cl 2>&1 | Select-Object -First 1)

Say '# CEF upgrade spike (Windows x64)'
Say ''
Say "Compiler: $clVer"
Say ''

$idx = Invoke-RestMethod 'https://cef-builds.spotifycdn.com/index.json'
function Pick($plat, $want) {
    foreach ($v in $idx.$plat.versions) {
        if ($want) { if ($v.cef_version -eq $want) { return $v } }
        elseif ($v.channel -eq 'stable') { return $v }
    }
}
$new = Pick 'windows64' $env:CEF_VERSION
$newMin = $new.files | Where-Object type -eq 'minimal'
$oldName = "cef_binary_$(Get-Content $Repo\prebuilt\versions\cef)+$(Get-Content $Repo\prebuilt\versions\cef_buildrevision)+chromium-$(Get-Content $Repo\prebuilt\versions\cefchromium)_windows64_minimal.tar.bz2"
$oldSha = ((Get-Content "$Repo\prebuilt\cef-sha1sums" | Where-Object { $_ -notmatch '^#' -and ($_ -split '\s+')[1] -eq $oldName }) -split '\s+')[0]
Say "Newest stable windows64: **$($new.cef_version)**"
Say ''

function Fetch($name, $sha) {
    $file = "$Work\dl\$name"
    if (-not (Test-Path $file)) {
        Invoke-WebRequest -Uri ("https://cef-builds.spotifycdn.com/" + [uri]::EscapeDataString($name)) -OutFile $file
    }
    if ((Get-FileHash -Algorithm SHA1 $file).Hash.ToLower() -ne $sha.ToLower()) { throw "SHA-1 mismatch for $name" }
    # Git for Windows' tar reads .tar.bz2
    Push-Location "$Work\dl"; & "$env:ProgramFiles\Git\usr\bin\tar.exe" -xjf $name; Pop-Location
    return "$Work\dl\$($name -replace '\.tar\.bz2$', '')"
}
$newDir = Fetch $newMin.name $newMin.sha1
$oldDir = Fetch $oldName $oldSha

function Shipped($d) { ((Get-ChildItem -Recurse -File "$d\Release", "$d\Resources" | Measure-Object Length -Sum).Sum) }
function Names($d) {
    @(Get-ChildItem -Recurse -File "$d\Release", "$d\Resources" | ForEach-Object { $_.Name } | Where-Object { $_ -notlike '*.pak' -or $_ -notmatch '^[a-z]{2,3}(-[A-Za-z0-9]+)?\.pak$' } | Sort-Object -Unique)
}
Say '## Binaries (Release + Resources, what build-libraries-windows.ps1 packages)'
Say ''
Say "| | CEF 74 (today) | $($new.cef_version) |"
Say '|---|---|---|'
Say "| total | $(MiB (Shipped $oldDir)) | $(MiB (Shipped $newDir)) |"
Say "| libcef.dll | $(MiB (Get-Item "$oldDir\Release\libcef.dll").Length) | $(MiB (Get-Item "$newDir\Release\libcef.dll").Length) |"
Say ''
$o = Names $oldDir; $n = Names $newDir
Say "Only in $($new.cef_version) (prebuilt/libcef.gyp copies by name): $((Compare-Object $o $n | Where-Object SideIndicator -eq '=>' | ForEach-Object InputObject) -join ', ')"
Say ''
Say "Gone in $($new.cef_version) (prebuilt/libcef.gyp still names them): $((Compare-Object $o $n | Where-Object SideIndicator -eq '<=' | ForEach-Object InputObject) -join ', ')"
Say ''

# The libcef_dll wrapper and libbrowser's Windows CEF sources
$lbSrcs = 'libbrowser_cef.cpp', 'libbrowser_cef_win.cpp', 'libbrowser_cefprocess.cpp', 'libbrowser_cefprocess_win.cpp'
function CompileSet($std, $hdr, $tag) {
    $obj = "$Work\obj\$tag"
    New-Item -ItemType Directory -Force $obj | Out-Null
    $common = @('/nologo', '/c', '/EHsc', '/MT', '/w', '/DNDEBUG', '/DWIN32', '/D_WINDOWS', '/DNOMINMAX', '/DUNICODE', '/D_UNICODE', "/std:$std")
    $wrapper = @(Get-ChildItem -Recurse -File "$hdr\libcef_dll" -Filter *.cc)
    # cl compiles many files per call; /MP spreads them over the processors
    Push-Location $hdr
    & cl @common /MP /DWRAPPING_CEF_SHARED /I. "/Fo$obj\\" @($wrapper | ForEach-Object FullName) *> "$Out\logs\$tag-wrapper.log"
    Pop-Location
    $made = @(Get-ChildItem "$obj\*.obj" -ErrorAction SilentlyContinue).Count
    $lfail = @()
    Remove-Item "$Out\logs\$tag-libbrowser.log" -ErrorAction SilentlyContinue
    foreach ($f in $lbSrcs) {
        & cl @common /DUSING_CEF_SHARED=1 "/I$Repo\libbrowser\include" "/I$Repo\libbrowser\src" "/I$Repo\libcore\include" "/I$Repo\libfoundation\include" "/I$hdr" "$Repo\libbrowser\src\$f" "/Fo$obj\lb_$f.obj" *>> "$Out\logs\$tag-libbrowser.log"
        if ($LASTEXITCODE -ne 0) { $lfail += $f }
    }
    $errs = @(Select-String -Path "$Out\logs\$tag-libbrowser.log" -Pattern 'error C' | ForEach-Object { $_.Line -replace [regex]::Escape($Repo), '' } | Sort-Object -Unique)
    [pscustomobject]@{ WrapperFail = $wrapper.Count - $made; WrapperAll = $wrapper.Count; LbFail = ($(if ($lfail) { $lfail -join ' ' } else { 'none' })); Errs = $errs }
}
Say '## Compile (MSVC)'
Say ''
Say '| Standard | Headers | wrapper .cc failing | libbrowser sources failing | distinct errors (libbrowser) |'
Say '|---|---|---|---|---|'
$r = CompileSet 'c++14' "$Repo\thirdparty\libcef" 'base-c++14'
Say "| c++14 | CEF 74 (today) | $($r.WrapperFail) of $($r.WrapperAll) | $($r.LbFail) | $($r.Errs.Count) |"
$scr = "$Work\libcef-win"
if (Test-Path $scr) { Remove-Item -Recurse -Force $scr }
New-Item -ItemType Directory $scr | Out-Null
Copy-Item -Recurse "$newDir\include", "$newDir\libcef_dll" $scr
$details = @()
foreach ($std in $Stds) {
    $r = CompileSet $std $scr "new-$std"
    Say "| $std | $($new.cef_version) | $($r.WrapperFail) of $($r.WrapperAll) | $($r.LbFail) | $($r.Errs.Count) |"
    $first = @(Select-String -Path "$Out\logs\new-$std-wrapper.log" -Pattern 'error' | Select-Object -First 10 | ForEach-Object Line)
    $details += "<details><summary>new-$std errors (wrapper, then libbrowser)</summary>`n`n``````n$($first -join "`n")`n---`n$(($r.Errs | Select-Object -First 80) -join "`n")`n```````n</details>`n"
}
Say ''
foreach ($d in $details) { Say $d }

if ($env:GITHUB_STEP_SUMMARY) { Get-Content $Report | Add-Content $env:GITHUB_STEP_SUMMARY }
