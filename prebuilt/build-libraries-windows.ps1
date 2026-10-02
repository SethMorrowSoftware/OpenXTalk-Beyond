<#
.SYNOPSIS
    Builds the Windows prebuilt libraries (OpenSSL, curl, ICU, Thirdparty)
    from source with the MSVC v141 toolset, repackages CEF, and packages them
    for prebuilt/fetch-libraries.sh.

.DESCRIPTION
    The Windows counterpart of prebuilt/build-libraries.sh and package-libs.sh.
    For one architecture and configuration it builds static libraries from
    the source releases pinned in prebuilt/versions and writes

        <OutDir>\<Lib>-<version>-<arch>-win32-v141_static_<mode>[-<rev>].tar.bz2

    each holding one folder <arch>-win32-v141_static_<mode> with lib\ and,
    where the library has them, include\, share\ and bin\. These are the
    archives fetch-libraries.sh copies from PREBUILT_LOCAL_DIR (when it names
    OutDir) and unpacks into prebuilt\unpacked\<Lib>\<arch>-win32-v141_static_<mode>,
    where the engine's build looks for them (prebuilt/*.gyp).

      OpenSSL     perl Configure VC-WIN64A|VC-WIN32 no-shared no-module ...,
                  then nmake: libcrypto.lib and libssl.lib (/MT /Zl), with the
                  legacy provider built in. Needs a native Windows perl
                  (Strawberry Perl) and NASM, or -NoAsm.
      Curl        CMake (NMake Makefiles) with OpenSSL and nothing else, the
                  static C runtime and the protocols the server engine uses:
                  libcurl_a.lib.
      ICU         ICU's own configure and make for Cygwin/MSVC, run by
                  Cygwin's bash with cl (/std:c++17, which ICU 75 and later
                  need): sicudt/in/io/tu/uc.lib, the full data file
                  share\icudt<major>l.dat and the host tools icupkg.exe and
                  pkgdata.exe, which the build uses to cut the data down.
      CEF         Spotify's CEF binary distribution of the version in
                  prebuilt\versions\cef* ("minimal" for release, the standard
                  one, which has Debug\, for debug), checked against its
                  SHA-1 in prebuilt\cef-sha1sums, repackaged as LiveCode's
                  build-cef.bat did: Release\ (or Debug\) and Resources\ in
                  lib\CEF. Nothing is compiled.
      Thirdparty  The libraries of thirdparty\ (zlib, libpng, ..., libpq,
                  MySQL Connector/C, Skia), compiled by the engine's own build
                  files (config.py, msbuild target thirdparty-prebuilts) through
                  tools\ci\build-windows.ps1. libpq and libmysql use OpenSSL's
                  headers, and the build fetches every other archive first,
                  so OpenSSL, Curl, ICU and CEF must be in OutDir before it.

    The compiler is v141 (VS 2017, MSVC 14.16), which the engine is built
    with too: a v141 link cannot take static libraries made by a newer
    compiler. Visual Studio 2022 with the v141 component, as in BUILDING.md,
    has it; vcvarsall.bat is called with -vcvars_ver=14.16 and the Windows SDK
    in WINSDK_VERSION (default: the one vcvarsall picks).

    Sources are downloaded over HTTPS into WorkDir\downloads and kept there.
    The build folders in WorkDir are made afresh each time.

.PARAMETER Libraries
    Which libraries to build, in this order: OpenSSL, Curl, ICU, CEF,
    Thirdparty. Default: all five. Curl needs the OpenSSL archive of the same
    architecture and configuration in OutDir, Thirdparty all four others.

.PARAMETER Arch
    x86_64 (default) or x86.

.PARAMETER Mode
    release (default) or debug.

.PARAMETER OutDir
    Where the archives go. Default: prebuilt\packaged.

.PARAMETER WorkDir
    Downloads and build folders. Default: prebuilt\build\windows (ignored by
    Git, like the other build folders of prebuilt\).

.PARAMETER CygwinRoot
    Cygwin installation (ICU's build, tar and bzip2). Default: %CYGPATH%,
    else C:\cygwin64. It needs make, tar and bzip2 besides the base system.

.PARAMETER VsInstallDir
    Visual Studio folder with the v141 toolset. Default: %VSINSTALLDIR%, else
    the newest one vswhere finds with Microsoft.VisualStudio.Component.VC.v141.x86.x64.

.PARAMETER NoAsm
    Build OpenSSL without assembler (no NASM needed; slower, and its AES no
    longer uses AES-NI). For trying things out only.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File prebuilt\build-libraries-windows.ps1
    powershell -ExecutionPolicy Bypass -File prebuilt\build-libraries-windows.ps1 -Mode debug -Libraries OpenSSL,Curl,ICU
#>
[CmdletBinding()]
param(
    [ValidateSet('OpenSSL', 'Curl', 'ICU', 'CEF', 'Thirdparty')]
    [string[]]$Libraries = @('OpenSSL', 'Curl', 'ICU', 'CEF', 'Thirdparty'),
    [ValidateSet('x86_64', 'x86')]
    [string]$Arch = 'x86_64',
    [ValidateSet('release', 'debug')]
    [string]$Mode = 'release',
    [string]$OutDir,
    [string]$WorkDir,
    [string]$CygwinRoot,
    [string]$VsInstallDir,
    [switch]$NoAsm
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$PrebuiltDir = $PSScriptRoot
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PrebuiltDir '..')).ProviderPath.TrimEnd('\')
if (-not $OutDir) { $OutDir = Join-Path $PrebuiltDir 'packaged' }
if (-not $WorkDir) { $WorkDir = Join-Path $PrebuiltDir 'build\windows' }
if (-not $CygwinRoot) {
    if ($env:CYGPATH) { $CygwinRoot = $env:CYGPATH } else { $CygwinRoot = 'C:\cygwin64' }
}
$CygwinRoot = $CygwinRoot.TrimEnd('\')
New-Item -ItemType Directory -Force -Path $OutDir, $WorkDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).ProviderPath.TrimEnd('\')
$WorkDir = (Resolve-Path -LiteralPath $WorkDir).ProviderPath.TrimEnd('\')
$Downloads = Join-Path $WorkDir 'downloads'
New-Item -ItemType Directory -Force -Path $Downloads | Out-Null

# --- Versions (prebuilt/versions, as scripts/lib_versions.inc reads them) ---
function Read-Version([string]$Name) {
    $path = Join-Path $PrebuiltDir "versions\$Name"
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    return (Get-Content -LiteralPath $path -Raw).Trim()
}
$Versions = @{}
$Revisions = @{}
foreach ($lib in @('OpenSSL', 'Curl', 'ICU', 'CEF', 'Thirdparty')) {
    $Versions[$lib] = Read-Version $lib.ToLowerInvariant()
    $Revisions[$lib] = Read-Version ($lib.ToLowerInvariant() + '_buildrevision')
    if (-not $Versions[$lib]) { throw "prebuilt\versions\$($lib.ToLowerInvariant()) is missing or empty" }
}
$Triple = "$Arch-win32-v141_static_$Mode"

function Get-ArchiveName([string]$Lib) {
    $name = "$Lib-$($Versions[$Lib])-$Triple"
    if ($Revisions[$Lib]) { $name += "-$($Revisions[$Lib])" }
    return "$name.tar.bz2"
}

# --- Running programs ---
function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    Write-Host "> $Exe $($Arguments -join ' ')"
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe exited with code $LASTEXITCODE" }
}

$Bash = Join-Path $CygwinRoot 'bin\bash.exe'
$Cygpath = Join-Path $CygwinRoot 'bin\cygpath.exe'
function ConvertTo-CygPath([string]$Path) {
    $p = & $Cygpath -u $Path
    if ($LASTEXITCODE -ne 0) { throw "cygpath failed for $Path" }
    return $p.Trim()
}

# A bash command line in Cygwin, not a login shell. Its PATH puts the
# compiler's folders first (Cygwin's /usr/bin/link must not shadow MSVC's
# link.exe), then Cygwin's own tools, then the rest of the Windows PATH:
# Unix tools found there (Git's, MSYS2's) behave differently enough to
# break ICU's configure. $script:BashPathPrefix is set once the compiler
# environment is known.
$script:BashPathPrefix = ''
function Invoke-Bash([string]$Command) {
    # (No double quotes: Windows PowerShell 5.1 does not pass them to
    # native programs intact. An assignment does not split $PATH.)
    $full = "export PATH='" + $script:BashPathPrefix + "/usr/bin:/bin:'`$PATH && " + $Command
    Invoke-Native $Bash @('--noprofile', '--norc', '-e', '-o', 'pipefail', '-c', $full)
}

# --- Tools ---
foreach ($tool in @('bash.exe', 'cygpath.exe', 'make.exe', 'tar.exe', 'bzip2.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $CygwinRoot "bin\$tool"))) {
        throw "$CygwinRoot\bin\$tool not found: install Cygwin with make, tar and bzip2 (BUILDING.md), or pass -CygwinRoot"
    }
}

# A native Windows perl (OpenSSL's Configure and nmake files need one; the
# perls of Git and Cygwin are not)
$Perl = $null
foreach ($dir in ($env:PATH -split ';')) {
    $d = $dir.Trim().Trim('"')
    if (-not $d) { continue }
    $candidate = Join-Path $d 'perl.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $os = & $candidate -e 'print $^O' 2>$null
        if ($os -eq 'MSWin32') { $Perl = $candidate; break }
    }
}
if (-not $Perl -and (Test-Path -LiteralPath 'C:\Strawberry\perl\bin\perl.exe')) { $Perl = 'C:\Strawberry\perl\bin\perl.exe' }
if ($Libraries -contains 'OpenSSL' -and -not $Perl) { throw 'No native Windows perl found: install Strawberry Perl' }

$Nasm = $null
if ($Libraries -contains 'OpenSSL' -and -not $NoAsm) {
    $found = Get-Command nasm.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $Nasm = $found.Source }
    foreach ($candidate in @("$env:ProgramFiles\NASM\nasm.exe", "${env:ProgramFiles(x86)}\NASM\nasm.exe")) {
        if (-not $Nasm -and (Test-Path -LiteralPath $candidate)) { $Nasm = $candidate }
    }
    if (-not $Nasm) { throw 'NASM not found: install it (https://www.nasm.us, or choco install nasm), or pass -NoAsm' }
}

# --- The v141 compiler environment ---
if (-not $VsInstallDir) { $VsInstallDir = $env:VSINSTALLDIR }
if (-not $VsInstallDir) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $VsInstallDir = & $vswhere -nologo -latest -products * -requires Microsoft.VisualStudio.Component.VC.v141.x86.x64 -property installationPath
    }
}
if (-not $VsInstallDir) { throw 'No Visual Studio with the v141 toolset found (BUILDING.md, section 2.1); pass -VsInstallDir' }
$vcvarsall = Join-Path $VsInstallDir 'VC\Auxiliary\Build\vcvarsall.bat'
if (-not (Test-Path -LiteralPath $vcvarsall)) { throw "$vcvarsall not found" }
$vcArch = 'x64'
if ($Arch -eq 'x86') { $vcArch = 'x86' }
$vcArgs = $vcArch
if ($env:WINSDK_VERSION) { $vcArgs += " $($env:WINSDK_VERSION)" }
$vcArgs += ' -vcvars_ver=14.16'
Write-Host "> vcvarsall.bat $vcArgs"
$envLines = & cmd.exe /d /c "`"$vcvarsall`" $vcArgs >nul && set"
if ($LASTEXITCODE -ne 0) { throw "vcvarsall.bat $vcArgs failed (is the v141 toolset installed?)" }
foreach ($line in $envLines) {
    if ($line -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2]) }
}
# Cygwin's tools last, after the compiler and the native perl
$pathParts = @()
if ($Perl) { $pathParts += (Split-Path -Parent $Perl) }
if ($Nasm) { $pathParts += (Split-Path -Parent $Nasm) }
$pathParts += $env:PATH
$pathParts += (Join-Path $CygwinRoot 'bin')
$env:PATH = $pathParts -join ';'
$cl = Get-Command cl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $cl -or $cl.Source -notmatch '\\14\.16\.') { throw "cl.exe of MSVC 14.16 (v141) is not first on PATH after vcvarsall (found: $($cl.Source))" }
# For Cygwin's bash (Invoke-Bash): the compiler's folder and the Windows
# SDK's tools (rc, mt) before Cygwin's /usr/bin
foreach ($dir in @((Split-Path -Parent $cl.Source), $env:WindowsSdkVerBinPath)) {
    if ($dir) {
        $sdkDir = $dir.TrimEnd('\')
        if ($dir -eq $env:WindowsSdkVerBinPath) { $sdkDir = Join-Path $sdkDir $vcArch }
        if (Test-Path -LiteralPath $sdkDir) { $script:BashPathPrefix += (ConvertTo-CygPath $sdkDir) + ':' }
    }
}
$cmake = Get-Command cmake.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1

Write-Host "Libraries   : $($Libraries -join ', ') ($Triple)"
Write-Host "Compiler    : $($cl.Source)"
Write-Host "Windows SDK : $env:WindowsSDKVersion"
Write-Host "Perl        : $Perl"
Write-Host "NASM        : $(if ($Nasm) { $Nasm } else { '(none: no-asm)' })"
Write-Host "CMake       : $(if ($cmake) { $cmake.Source } else { '(not found)' })"
Write-Host "Cygwin      : $CygwinRoot"
Write-Host "Out         : $OutDir"

# --- Helpers ---
function Get-Source([string]$Url, [string]$FileName) {
    $path = Join-Path $Downloads $FileName
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "Downloading $Url"
        $part = "$path.part"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $part -UseBasicParsing
        Move-Item -LiteralPath $part -Destination $path -Force
    }
    return $path
}

# Unpack a .tar.gz/.tgz into a new folder and return the one folder in it
function Expand-Source([string]$Archive, [string]$Name) {
    $dest = Join-Path $WorkDir "$Name-src"
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    # Windows' own tar (bsdtar), not Git's or Cygwin's
    Invoke-Native "$env:SystemRoot\System32\tar.exe" @('-xzf', $Archive, '-C', $dest)
    $top = @(Get-ChildItem -LiteralPath $dest -Directory)
    if ($top.Count -ne 1) { throw "$Archive does not hold one top folder" }
    return $top[0].FullName
}

function New-CleanDir([string]$Path) {
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    return (Resolve-Path -LiteralPath $Path).ProviderPath
}

# Write OutDir\<archive> from a staging folder that holds the triple folder
function Write-Archive([string]$Lib, [string]$StageParent) {
    $archive = Join-Path $OutDir (Get-ArchiveName $Lib)
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    $from = ConvertTo-CygPath $StageParent
    $to = ConvertTo-CygPath $archive
    Invoke-Bash "cd '$from' && /usr/bin/tar --create --bzip2 --owner=0 --group=0 --file '$to' '$Triple'"
    Write-Host ("Wrote {0} ({1:N0} bytes)" -f $archive, (Get-Item -LiteralPath $archive).Length)
}

# The installed OpenSSL of this build (headers and libraries), for curl
function Get-OpenSSLInstall {
    $install = Join-Path $WorkDir "openssl-$Triple-install"
    if (-not (Test-Path -LiteralPath (Join-Path $install 'lib\libcrypto.lib'))) {
        # From the archive, when OpenSSL was built by an earlier run
        $archive = Join-Path $OutDir (Get-ArchiveName 'OpenSSL')
        if (-not (Test-Path -LiteralPath $archive)) { throw "Build OpenSSL first: $archive is missing" }
        $tmp = New-CleanDir (Join-Path $WorkDir 'openssl-from-archive')
        Invoke-Bash "cd '$(ConvertTo-CygPath $tmp)' && /usr/bin/tar -xjf '$(ConvertTo-CygPath $archive)'"
        if (Test-Path -LiteralPath $install) { Remove-Item -LiteralPath $install -Recurse -Force }
        Move-Item -LiteralPath (Join-Path $tmp $Triple) -Destination $install
    }
    return $install
}

# --- OpenSSL ---
function Build-OpenSSL {
    $v = $Versions['OpenSSL']
    $tag = "openssl-$v"
    if ($v -like '1.*') { $tag = 'OpenSSL_' + ($v -replace '\.', '_') }
    $src = Expand-Source (Get-Source "https://github.com/openssl/openssl/releases/download/$tag/openssl-$v.tar.gz" "openssl-$v.tar.gz") "openssl-$Triple"
    $install = New-CleanDir (Join-Path $WorkDir "openssl-$Triple-install")
    $target = 'VC-WIN64A'
    if ($Arch -eq 'x86') { $target = 'VC-WIN32' }
    # As build-openssl.sh, but with threads (Windows has them built in) and
    # without no-async. no-shared builds the static libraries with /MT /Zl,
    # so they take the C runtime of whatever links them.
    $config = @('Configure', $target, 'no-shared', 'no-module', 'no-apps', 'no-tests', 'no-docs', 'no-rc5',
                "--prefix=$install", "--openssldir=$install\ssl")
    if ($NoAsm) { $config += 'no-asm' }
    if ($Mode -eq 'debug') { $config += '--debug' }
    Push-Location -LiteralPath $src
    try {
        Invoke-Native $Perl $config
        Invoke-Native 'nmake.exe' @('/nologo')
        Invoke-Native 'nmake.exe' @('/nologo', 'install_sw')
    }
    finally { Pop-Location }

    $stage = New-CleanDir (Join-Path $WorkDir 'stage-openssl')
    $t = Join-Path $stage $Triple
    New-Item -ItemType Directory -Force -Path (Join-Path $t 'lib'), (Join-Path $t 'include') | Out-Null
    Copy-Item -Recurse -LiteralPath (Join-Path $install 'include\openssl') -Destination (Join-Path $t 'include')
    foreach ($lib in @('libcrypto.lib', 'libssl.lib')) {
        Copy-Item -LiteralPath (Join-Path $install "lib\$lib") -Destination (Join-Path $t 'lib')
    }
    $pdb = Join-Path $src 'ossl_static.pdb'
    if (Test-Path -LiteralPath $pdb) { Copy-Item -LiteralPath $pdb -Destination (Join-Path $t 'lib') }
    Write-Archive 'OpenSSL' $stage
}

# --- curl ---
function Build-Curl {
    if (-not $cmake) { throw 'cmake.exe not found on PATH (Visual Studio installs one with the C++ CMake tools)' }
    $v = $Versions['Curl']
    $src = Expand-Source (Get-Source "https://curl.se/download/curl-$v.tar.gz" "curl-$v.tar.gz") "curl-$Triple"
    $openssl = Get-OpenSSLInstall
    $build = New-CleanDir (Join-Path $WorkDir "curl-$Triple-build")
    $install = New-CleanDir (Join-Path $WorkDir "curl-$Triple-install")
    $buildType = 'Release'
    if ($Mode -eq 'debug') { $buildType = 'Debug' }
    $cmakeArgs = @('-S', $src, '-B', $build, '-G', 'NMake Makefiles',
              "-DCMAKE_BUILD_TYPE=$buildType", "-DCMAKE_INSTALL_PREFIX=$install",
              '-DBUILD_SHARED_LIBS=OFF', '-DBUILD_STATIC_LIBS=ON', '-DCURL_STATIC_CRT=ON',
              '-DBUILD_CURL_EXE=OFF', '-DBUILD_TESTING=OFF', '-DBUILD_EXAMPLES=OFF',
              '-DBUILD_LIBCURL_DOCS=OFF', '-DBUILD_MISC_DOCS=OFF', '-DENABLE_CURL_MANUAL=OFF',
              # OpenSSL, this build's, named outright (a runner may have
              # another OpenSSL installed)
              '-DCURL_USE_OPENSSL=ON', '-DCURL_USE_SCHANNEL=OFF', '-DCURL_WINDOWS_SSPI=OFF',
              "-DOPENSSL_ROOT_DIR=$openssl", "-DOPENSSL_INCLUDE_DIR=$openssl\include",
              "-DOPENSSL_CRYPTO_LIBRARY=$openssl\lib\libcrypto.lib", "-DOPENSSL_SSL_LIBRARY=$openssl\lib\libssl.lib",
              '-DOPENSSL_USE_STATIC_LIBS=ON', '-DOPENSSL_MSVC_STATIC_RT=ON',
              # Nothing else (as build-curl.sh)
              '-DUSE_WIN32_IDN=OFF', '-DUSE_LIBIDN2=OFF', '-DCURL_USE_LIBPSL=OFF', '-DCURL_USE_LIBSSH2=OFF',
              '-DCURL_USE_LIBSSH=OFF', '-DCURL_ZLIB=OFF', '-DCURL_BROTLI=OFF', '-DCURL_ZSTD=OFF',
              '-DUSE_NGHTTP2=OFF', '-DENABLE_UNICODE=OFF',
              '-DCURL_DISABLE_LDAP=ON', '-DCURL_DISABLE_LDAPS=ON', '-DCURL_DISABLE_RTSP=ON',
              '-DCURL_DISABLE_DICT=ON', '-DCURL_DISABLE_TELNET=ON', '-DCURL_DISABLE_TFTP=ON',
              '-DCURL_DISABLE_POP3=ON', '-DCURL_DISABLE_IMAP=ON', '-DCURL_DISABLE_SMTP=ON',
              '-DCURL_DISABLE_GOPHER=ON', '-DCURL_DISABLE_MQTT=ON', '-DCURL_DISABLE_SMB=ON',
              '-DCURL_DISABLE_FILE=ON', '-DCURL_DISABLE_COOKIES=ON')
    Invoke-Native $cmake.Source $cmakeArgs
    Invoke-Native $cmake.Source @('--build', $build)
    Invoke-Native $cmake.Source @('--install', $build)

    $stage = New-CleanDir (Join-Path $WorkDir 'stage-curl')
    $t = Join-Path $stage $Triple
    New-Item -ItemType Directory -Force -Path (Join-Path $t 'lib'), (Join-Path $t 'include') | Out-Null
    Copy-Item -Recurse -LiteralPath (Join-Path $install 'include\curl') -Destination (Join-Path $t 'include')
    $built = @(Get-ChildItem -LiteralPath (Join-Path $install 'lib') -Filter 'libcurl*.lib')
    if ($built.Count -ne 1) { throw "Expected one libcurl*.lib in $install\lib, found $($built.Count)" }
    # The name prebuilt/libcurl.gyp links (as curl's old winbuild named it)
    Copy-Item -LiteralPath $built[0].FullName -Destination (Join-Path $t 'lib\libcurl_a.lib')
    Write-Archive 'Curl' $stage
}

# --- ICU ---
function Build-ICU {
    $v = $Versions['ICU']
    $major = ($v -split '\.')[0]
    if ([int]$major -ge 78) {
        $url = "https://github.com/unicode-org/icu/releases/download/release-$v/icu4c-$v-sources.tgz"
    }
    else {
        $url = "https://github.com/unicode-org/icu/releases/download/release-$($v -replace '\.', '-')/icu4c-$($v -replace '\.', '_')-src.tgz"
    }
    $src = Expand-Source (Get-Source $url "icu4c-$v-sources.tgz") "icu-$Triple"
    $build = New-CleanDir (Join-Path $WorkDir "icu-$Triple-build")
    $install = New-CleanDir (Join-Path $WorkDir "icu-$Triple-install")
    $bits = '64'
    if ($Arch -eq 'x86') { $bits = '32' }
    # The options of build-icu.sh, plus the static C runtime, C++17 and -FS
    # (the cl processes of a parallel make share one .pdb). ICU's
    # config/mh-cygwin-msvc adds -utf-8 and -EHsc itself.
    # UCONFIG_NO_MF2: without ICU's MessageFormat 2.0, a technology preview
    # that nothing here uses, whose code relies on C++17's guaranteed copy
    # elision where MSVC 14.16 does not apply it (error C2280 in
    # messageformat2_function_registry.cpp: new Plural(Plural::integer(...))).
    # Not UNISTR_FROM_CHAR_EXPLICIT or UNISTR_FROM_STRING_EXPLICIT, which
    # LiveCode's build-icu.bat passed: ICU makes them explicit for its own
    # libraries anyway, and forcing them on its tools breaks ICU 78's
    # tools/ctestfw (UnicodeString + const char*); build-icu.sh does not
    # pass them either.
    $defines = '-DU_USING_ICU_NAMESPACE=0 -DUCONFIG_NO_MF2=1'
    $crt = '-MT -O2 -Gy'
    $config = "--with-data-packaging=archive --enable-static --disable-shared --disable-samples --disable-tests --disable-extras --with-library-bits=$bits"
    if ($Mode -eq 'debug') {
        $crt = '-MTd -Od'
        $config = "--enable-debug --disable-release $config"
    }
    $cflags = "-Zi -FS $crt $defines"
    $cxxflags = "$cflags -std:c++17"
    $installCyg = ConvertTo-CygPath $install
    # configure by a path relative to the build folder, as LiveCode's
    # build-icu.bat did: the makefiles pass the source folder to cl, which
    # reads a relative path (with / or \) but not a /cygdrive one
    $configure = ([System.IO.Path]::GetRelativePath($build, $src) -replace '\\', '/') + '/source/configure'
    $jobs = [Environment]::ProcessorCount
    # ac_cv_prog_PYTHON set and empty: configure then uses no Python. The
    # source release builds its data from the prebuilt data/in/icudt*.dat,
    # and a Windows Python (which configure would find on PATH) cannot read
    # the Cygwin paths configure passes it.
    Invoke-Bash ("cd '$(ConvertTo-CygPath $build)' && " +
                 "export CC=cl CXX=cl CPP= CPPFLAGS= LDFLAGS= CFLAGS='$cflags' CXXFLAGS='$cxxflags' ac_cv_prog_PYTHON= && " +
                 "'$configure' --prefix='$installCyg' --sbindir='$installCyg/bin' $config && " +
                 "make -j$jobs && make install")

    $stage = New-CleanDir (Join-Path $WorkDir 'stage-icu')
    $t = Join-Path $stage $Triple
    foreach ($d in @('lib', 'include', 'share', 'bin')) { New-Item -ItemType Directory -Force -Path (Join-Path $t $d) | Out-Null }
    Copy-Item -Recurse -LiteralPath (Join-Path $install 'include\unicode') -Destination (Join-Path $t 'include')
    $suffix = ''
    if ($Mode -eq 'debug') { $suffix = 'd' }
    foreach ($lib in @('sicudt', 'sicuin', 'sicuio', 'sicutu', 'sicuuc')) {
        # prebuilt/libicu.gyp links the release names in both configurations
        Copy-Item -LiteralPath (Join-Path $install "lib\$lib$suffix.lib") -Destination (Join-Path $t "lib\$lib.lib")
    }
    $data = @(Get-ChildItem -LiteralPath (Join-Path $install 'share') -Recurse -Filter "icudt$($major)l.dat")
    if ($data.Count -ne 1) { throw "Expected one icudt$($major)l.dat under $install\share, found $($data.Count)" }
    Copy-Item -LiteralPath $data[0].FullName -Destination (Join-Path $t 'share')
    foreach ($tool in @('icupkg.exe', 'pkgdata.exe')) {
        Copy-Item -LiteralPath (Join-Path $install "bin\$tool") -Destination (Join-Path $t 'bin')
    }
    Write-Archive 'ICU' $stage
}

# --- CEF ---
function Build-CEF {
    $v = $Versions['CEF']
    $chromium = Read-Version 'cefchromium'
    $bits = '64'
    if ($Arch -eq 'x86') { $bits = '32' }
    # The minimal distribution has Release\ and Resources\, all that is
    # repackaged, at about half the download; Debug\ is only in the
    # standard one
    $flavour = '_minimal'
    $config = 'Release'
    if ($Mode -eq 'debug') { $flavour = ''; $config = 'Debug' }
    $name = "cef_binary_$v+$($Revisions['CEF'])+chromium-$($chromium)_windows$bits$flavour"
    $file = "$name.tar.bz2"
    $url = 'https://cef-builds.spotifycdn.com/' + ($file -replace '\+', '%2B')

    # The SHA-1 that Spotify publishes for the file (cef-builds.spotifycdn.com/index.json)
    $expected = $null
    foreach ($line in (Get-Content -LiteralPath (Join-Path $PrebuiltDir 'cef-sha1sums'))) {
        if ($line -match '^\s*([0-9a-fA-F]{40})\s+\*?(\S+)\s*$' -and $Matches[2] -eq $file) { $expected = $Matches[1].ToLowerInvariant() }
    }
    if (-not $expected) { throw "$file has no entry in prebuilt\cef-sha1sums" }
    $archive = Get-Source $url $file
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA1).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        Remove-Item -LiteralPath $archive -Force
        throw "SHA-1 of $file is $actual, not $expected (prebuilt\cef-sha1sums); the download was deleted"
    }
    Write-Host "SHA-1 OK: $file"

    $src = New-CleanDir (Join-Path $WorkDir "cef-$Triple-src")
    Invoke-Bash "cd '$(ConvertTo-CygPath $src)' && /usr/bin/tar -xjf '$(ConvertTo-CygPath $archive)'"
    $top = Join-Path $src $name
    foreach ($d in @($config, 'Resources')) {
        if (-not (Test-Path -LiteralPath (Join-Path $top $d))) { throw "$file has no $d folder" }
    }
    $stage = New-CleanDir (Join-Path $WorkDir 'stage-cef')
    $lib = Join-Path $stage "$Triple\lib\CEF"
    New-Item -ItemType Directory -Force -Path $lib | Out-Null
    foreach ($d in @($config, 'Resources')) {
        Copy-Item -Recurse -Path (Join-Path $top "$d\*") -Destination $lib
    }
    Write-Archive 'CEF' $stage
}

# --- Thirdparty ---
function Build-Thirdparty {
    $platform = "win-$Arch"
    $buildType = 'Release'
    if ($Mode -eq 'debug') { $buildType = 'Debug' }
    $openssl = Join-Path $OutDir (Get-ArchiveName 'OpenSSL')
    if (-not (Test-Path -LiteralPath $openssl)) { throw "Build OpenSSL first: $openssl is missing" }
    # libpq and libmysql include OpenSSL's headers, from prebuilt/unpacked,
    # and the thirdparty-prebuilts target does not fetch them first (the
    # engine's build runs fetch-libraries.sh as a step of its own), so the
    # OpenSSL archive built above is unpacked here
    Invoke-Bash ("cd '$(ConvertTo-CygPath $PrebuiltDir)' && " +
                 "PREBUILT_LOCAL_DIR='$(ConvertTo-CygPath $OutDir)' PREBUILT_WIN32_LIBS=OpenSSL " +
                 "PREBUILT_WIN32_SUBPLATFORMS=v141_static_$Mode ./fetch-libraries.sh win32 $Arch")
    $saved = @{}
    $settings = @{
        BUILD_PLATFORM = $platform
        BUILDTYPE = $buildType
        PREBUILT_LOCAL_DIR = $OutDir
        PREBUILT_WIN32_LIBS = 'OpenSSL Curl ICU CEF'
        PREBUILT_WIN32_SUBPLATFORMS = "v141_static_$Mode"
    }
    foreach ($k in $settings.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $settings[$k])
    }
    try {
        & (Join-Path $RepoRoot 'tools\ci\build-windows.ps1') -Stage configure, build -Target thirdparty-prebuilts -CygwinRoot $CygwinRoot
    }
    finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }

    $libDir = Join-Path $RepoRoot "build-$platform\livecode\$($settings.BUILDTYPE)\lib"
    $stage = New-CleanDir (Join-Path $WorkDir 'stage-thirdparty')
    $t = Join-Path $stage $Triple
    New-Item -ItemType Directory -Force -Path (Join-Path $t 'lib') | Out-Null
    # The libraries of build-thirdparty.bat (lib_versions.inc: CORE, NATIVE
    # and DESKTOP for win32, without iODBC, which Windows does not use)
    $names = @('cairo', 'ffi', 'gif', 'jpeg', 'mysql', 'pcre', 'png', 'pq', 'sqlite', 'xml', 'xslt', 'z', 'zip', 'skia')
    foreach ($n in $names) {
        Copy-Item -LiteralPath (Join-Path $libDir "lib$n.lib") -Destination (Join-Path $t 'lib')
    }
    foreach ($f in @(Get-ChildItem -LiteralPath $libDir -Filter 'libskia_opt_*.lib')) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $t 'lib')
    }
    Write-Archive 'Thirdparty' $stage
}

foreach ($lib in @('OpenSSL', 'Curl', 'ICU', 'CEF', 'Thirdparty')) {
    if ($Libraries -contains $lib) {
        Write-Host ''
        Write-Host "=== $lib $($Versions[$lib]) ($Triple) ==="
        & "Build-$lib"
    }
}
