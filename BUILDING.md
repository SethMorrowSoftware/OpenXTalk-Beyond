# Building OXT-Beyond

This guide builds OXT-Beyond for 64-bit Windows (x86_64) from source,
packages it and makes its installer, using the same tools and commands
as the project's CI build. OXT-Beyond is also built, packaged and
released for macOS (one universal app for Apple Silicon and Intel) and
Linux x86-64, by their CI workflows; [Building on Linux](#12-building-on-linux)
and [Building on macOS](#13-building-on-macos) describe what those
workflows do, and [Making a release](#10-making-a-release) how one tag
releases all three. The upstream LiveCode instructions for other
platforms are still in `docs/development/`, but they are not maintained
for this project.

The engine build needs a legacy toolchain: the Visual Studio 2017 C++
compiler (toolset v141, installed as an optional part of Visual Studio
2022), Python 2.7 and Cygwin. That is what the engine's build files and
the prebuilt third-party libraries were made for. Moving to current
tools is planned but has not been done yet. Packaging needs Python 3,
and the installer needs Inno Setup 6.

What you get from the build is a `win-x86_64-bin` folder with the
engines, externals and tools, and an IDE you can run straight from your
clone. The files in it are still named after LiveCode
(`LiveCode-Community.exe`). Packaging turns them, the IDE and the
standalone runtimes for other platforms into OXT-Beyond's installed
layout, with the development engine renamed `OXT-Beyond.exe`, and from
that the portable zip and the installer.

Contents:

1. [Quick reference](#1-quick-reference)
2. [Install the tools](#2-install-the-tools)
3. [Get the source](#3-get-the-source)
4. [Configure](#4-configure)
5. [Build](#5-build)
6. [Prebuilt libraries](#6-prebuilt-libraries)
7. [Run, check and package the result](#7-run-check-and-package-the-result)
8. [Troubleshooting](#8-troubleshooting)
9. [Continuous integration](#9-continuous-integration)
10. [Making a release](#10-making-a-release)
11. [Working on the IDE](#11-working-on-the-ide)
12. [Building on Linux](#12-building-on-linux)
13. [Building on macOS](#13-building-on-macos)

## 1. Quick reference

Once the tools in section 2 are installed, a build is (in `cmd.exe`):

```bat
git clone --recurse-submodules https://github.com/SethMorrowSoftware/winoxt.git C:\src\winoxt
cd /d C:\src\winoxt
set PATH=C:\Python27;%PATH%
C:\Python27\python.exe config.py --platform win-x86_64
cd build-win-x86_64
cmd /c ..\make.cmd
cd ..
win-x86_64-bin\LiveCode-Community.exe
```

and, to make the packages and the installer (section 7; this needs
Python 3 and Inno Setup 6):

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\package-windows.ps1
powershell -ExecutionPolicy Bypass -File tools\ci\build-installer.ps1
```

Allow several gigabytes of disk space. On an existing tree the clone
(files and Git history) took about 0.8 GB, the downloaded prebuilt
archives 0.3 GB, the unpacked prebuilt libraries 1.5 GB, the build
folder 3.5 GB and `win-x86_64-bin` 0.5 GB. Packaging needs about 1 GB
more for `dist\stage`, 0.2 GB for the downloaded runtimes and about
0.6 GB for the zips, plus the installer.

A first build compiles everything, one project at a time, and takes a
long while. Later builds only rebuild what changed.

## 2. Install the tools

| Tool | Version | Where |
| --- | --- | --- |
| Visual Studio 2022 (Build Tools or any edition) | with the v141 toolset, ATL, MFC and a Windows 10/11 SDK | default location |
| Python | 2.7.18, 64-bit | `C:\Python27` |
| Strawberry Perl | any recent 64-bit release | default location, on `PATH` |
| Git for Windows | any recent release | default location |
| Cygwin | 64-bit, with flex, bison and a few other packages | `C:\cygwin64`, **not** on `PATH` |
| Python 3 (for packaging) | 3.6 or later | any; found as `py -3`, `python3` or `python` |
| Inno Setup (for the installer) | 6.3 or later | default location |

You do not need the Microsoft Speech SDK 5.1 that the old upstream
instructions mention, or the QuickTime SDK that `config.py` looks for.
The old instructions also asked for the Windows 8.1 SDK, and the only
earlier build of this code that is known to work (Tom Perry's) did
compile against the Windows 8.1 SDK headers. This guide and CI use a
Windows 10/11 SDK instead; a complete build with one has not been
confirmed yet. If you get compile errors in Windows SDK headers, see
[Troubleshooting](#8-troubleshooting).

### 2.1 Visual Studio 2022 with the v141 toolset

The generated projects use the VS 2017 C++ toolset (`v141`), and the
prebuilt libraries were compiled with it. Visual Studio 2022 can install
it as an optional component. You need these components:

| Component ID | What it is |
| --- | --- |
| `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` | current MSVC x64/x86 build tools (brings MSBuild and `vcvarsall.bat`) |
| `Microsoft.VisualStudio.Component.VC.v141.x86.x64` | MSVC v141 (VS 2017) x64/x86 build tools, version 14.16 |
| `Microsoft.VisualStudio.Component.VC.v141.ATL` | ATL for v141 (the engine and revBrowser use ATL) |
| `Microsoft.VisualStudio.Component.VC.v141.MFC` | MFC for v141 (revBrowser's resource file includes `afxres.h`) |
| `Microsoft.VisualStudio.Component.Windows10SDK.17763` | Windows SDK 10.0.17763.0 |

Another Windows 10 or 11 SDK can be used instead; see `WINSDK_VERSION`
in [section 5](#5-build). (As noted above, no complete build with a
Windows 10/11 SDK has been confirmed yet.) SDK 10.0.17763.0 is selected
because it supports the VS 2017-era v141 compiler and is much closer to
the generated projects' original 10.0.14393.0 target than current SDKs.

**New install of the Build Tools.** Download
[`vs_BuildTools.exe`](https://aka.ms/vs/17/release/vs_BuildTools.exe)
and run, from a command prompt in the download folder:

```bat
vs_BuildTools.exe --passive --wait --norestart ^
  --add Microsoft.VisualStudio.Workload.VCTools ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.VC.v141.x86.x64 ^
  --add Microsoft.VisualStudio.Component.VC.v141.ATL ^
  --add Microsoft.VisualStudio.Component.VC.v141.MFC ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.17763
```

**Existing Visual Studio 2022.** Add the components to it. Change
`--installPath` to your installation (for example
`C:\Program Files\Microsoft Visual Studio\2022\Community`):

```bat
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify ^
  --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --add Microsoft.VisualStudio.Component.VC.v141.x86.x64 ^
  --add Microsoft.VisualStudio.Component.VC.v141.ATL ^
  --add Microsoft.VisualStudio.Component.VC.v141.MFC ^
  --add Microsoft.VisualStudio.Component.Windows10SDK.17763 ^
  --passive --norestart
```

You can also tick the same items in the Visual Studio Installer under
*Modify > Individual components*: "MSVC v143 - VS 2022 C++ x64/x86 build
tools (Latest)", "MSVC v141 - VS 2017 C++ x64/x86 build tools (v14.16)",
"C++ ATL for v141 build tools (x86 & x64)", "C++ MFC for v141 build
tools (x86 & x64)" and "Windows 10 SDK (10.0.17763.0)". The CI build uses
[`tools/ci/install-vs-components.ps1`](tools/ci/install-vs-components.ps1),
which you can also run from an elevated PowerShell prompt; add
`-VerifyOnly` to check an installation without changing it.

Microsoft documents the component IDs in
[Visual Studio Build Tools component directory](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022)
and the installer options in
[Use command-line parameters to install Visual Studio](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022).

### 2.2 Python 2.7

`config.py` and the bundled copy of gyp only run on Python 2. Install
Python 2.7.18 (64-bit) into `C:\Python27`. It is end of life, but
python.org still hosts the installer:
[python-2.7.18.amd64.msi](https://www.python.org/ftp/python/2.7.18/python-2.7.18.amd64.msi)
([release page](https://www.python.org/downloads/release/python-2718/)).

```bat
msiexec /i python-2.7.18.amd64.msi /qb ALLUSERS=1 TARGETDIR=C:\Python27
```

You do not have to add it to your system `PATH` (which could upset other
Python software): run `config.py` with `C:\Python27\python.exe`, as
shown in [section 4](#4-configure). Python 3 can stay installed.

### 2.3 Strawberry Perl

Several build steps run `perl` through `cmd.exe` and need a native
Windows Perl. Install [Strawberry Perl](https://strawberryperl.com/)
(64-bit); its installer adds it to `PATH`. Check in a new command
prompt:

```bat
perl -e "print $^O"
```

This must print `MSWin32`. If it prints `cygwin` or `msys`, another Perl
(for example the one inside Git for Windows or Cygwin) comes first on
`PATH`; move Strawberry Perl ahead of it.

### 2.4 Git for Windows

Install [Git for Windows](https://gitforwindows.org/). Keep the default
choices, in particular:

- "Git from the command line and also from 3rd-party software" for
  `PATH`. Do not choose the option that also puts Git's Unix tools on
  `PATH`: Git's `usr\bin` contains its own `bash.exe`, `cygpath.exe` and
  `perl.exe`, which can be picked up instead of Cygwin's and Strawberry's.
- "Checkout Windows-style, commit Unix-style line endings"
  (`core.autocrlf=true`). This is the setup the existing builds used. See
  [line endings](#line-endings) below.

The build calls `git` while configuring, so Git has to be on `PATH`.

### 2.5 Cygwin

Several build steps (fetching the prebuilt libraries, flex and bison for
the LiveCode Builder compiler, the time zone data) run as shell commands
through `util\invoke-unix.bat`, which needs Cygwin. Install the 64-bit
Cygwin into `C:\cygwin64` and do **not** add it to `PATH`.

Download [setup-x86_64.exe](https://cygwin.com/setup-x86_64.exe) and run:

```bat
setup-x86_64.exe -q -n -R C:\cygwin64 -l C:\cygwin64\packages ^
  -s https://mirrors.kernel.org/sourceware/cygwin/ ^
  -P flex,bison,m4,gawk,sed,grep,curl,tar,bzip2
```

`-q` runs unattended, `-n` skips the shortcuts, `-R` sets the install
folder, `-l` the package download folder, `-s` the download mirror (any
mirror from [cygwin.com/mirrors.html](https://cygwin.com/mirrors.html)
will do) and `-P` lists the extra packages. `bash`, `coreutils` and the
rest of the base system are always installed. See the
[Cygwin FAQ](https://cygwin.com/faq/faq.html#faq.setup.cli) for all
options. To add packages later, run the same command again.

`util\invoke-unix.bat` looks for Cygwin in this order: the folder in the
`CYGPATH` environment variable (the Cygwin root, for example
`set CYGPATH=D:\cygwin64`), then `C:\cygwin64`, then `C:\cygwin`, and
only then a `cygpath.exe` found on `PATH`. The Cygwin path must not
contain spaces.

Check:

```bat
C:\cygwin64\bin\flex.exe --version
C:\cygwin64\bin\bison.exe --version
```

### 2.6 Python 3 (for packaging)

The packaging tools in `tools/oxt/` are Python 3 scripts that use only
the standard library. Install a current Python 3 from
[python.org](https://www.python.org/downloads/windows/) (the installer's
`py` launcher is enough). It does not replace Python 2.7, which
`config.py` still needs: `tools\ci\package-windows.ps1` looks for
`py -3`, then `python3`, then a `python` that is Python 3.6 or later, or
uses the interpreter you give it with `-Python`. Packaging downloads the
[xTalk Suite extensions](#xtalk-suite-extensions) from `github.com` and
`raw.githubusercontent.com` unless they are in its cache.

### 2.7 Inno Setup 6 (for the installer)

The installer is compiled with Inno Setup 6.3 or later. Install it from
[jrsoftware.org](https://jrsoftware.org/isdl.php) into its default
folder, or with Chocolatey (`choco install innosetup`).
`tools\ci\build-installer.ps1` finds `ISCC.exe` there; if it cannot
find it, it tries to install Inno Setup with Chocolatey itself (see
[Installer](#installer)).

## 3. Get the source

Clone with Git, into a path **without spaces**:

```bat
git clone --recurse-submodules https://github.com/SethMorrowSoftware/winoxt.git C:\src\winoxt
```

- A "Download ZIP" of the repository will not configure: configuring
  runs `git rev-parse HEAD` to embed the source revision in the engine.
- The only submodule is `libcpptest/googletest`, used by the C++ unit
  tests. If you cloned without `--recurse-submodules`, run
  `git submodule update --init`.
- `ide/` (the IDE) and `thirdparty/` (third-party library sources) are
  ordinary folders in this repository, not submodules. `ide/` holds the
  OpenXTalk Lite 1.15 IDE with its history (see [HISTORY.md](HISTORY.md)).
- The longest path in `ide/` is 142 characters. If you clone into a deep
  folder and Git reports "Filename too long", enable long paths
  (`git config --global core.longpaths true`) or use a shorter folder.
- Paths with spaces break `util\invoke-unix.bat`, which passes the
  current folder to Cygwin unquoted.

## 4. Configure

Configuring runs gyp, which writes Visual Studio project files into
`build-win-x86_64\livecode\` (the solution is `livecode.sln`). In
`cmd.exe`:

```bat
cd /d C:\src\winoxt
set PATH=C:\Python27;%PATH%
C:\Python27\python.exe config.py --platform win-x86_64
```

The `set PATH` line only affects this command prompt. It makes `python`
mean Python 2.7 here, which is also how CI runs the build (one build
step runs `python`). Keep using the same prompt for the build.

Double-clicking `configure.bat` does the same thing interactively and
waits for a key press at the end. It uses `C:\Python27\python.exe` if it
exists; set `PYTHON` to use a Python 2.7 installed somewhere else. If
`PYTHON` is set but is not Python 2 (other tools, such as node-gyp, use
the same variable for Python 3), `configure.bat` uses
`C:\Python27\python.exe` instead, or stops with an error if that does
not exist.

Notes:

- The solution file says "Visual Studio 2015". That is expected: this
  old copy of gyp only knows project formats up to 2015. The projects
  themselves use the v141 toolset and build with Visual Studio 2022's
  MSBuild.
- Configuring also writes `debug_syms_inputs.txt` in the repository
  root (a list of the built programs, used by the debug-symbol build
  steps). The
  file came in with Tom Perry's changes and is tracked by Git. It
  normally comes out unchanged; if Git shows it as modified after
  configuring, restore it with `git checkout -- debug_syms_inputs.txt`
  rather than committing the change with unrelated work.
- Run `config.py` again after pulling changes to any `*.gyp` or
  `*.gypi` file. Never edit the generated files under
  `build-win-x86_64` by hand; they are overwritten.

## 5. Build

From the same command prompt:

```bat
cd build-win-x86_64
cmd /c ..\make.cmd
```

`make.cmd` finds Visual Studio, sets up the compiler environment with
`vcvarsall.bat x64`, and runs MSBuild on `livecode\livecode.sln` with
the `default` target. It ends with `exit`, which would close your
command prompt, so run it through `cmd /c` as shown.

MSBuild runs one project at a time (`/m:1`) and writes a full log to
`build-win-x86_64\msbuild.log`. When something fails, search that file
for `error`.

`make.cmd` reads these environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `BUILDTYPE` | `Release` | `Release` or `Debug`. |
| `BUILD_PLATFORM` | `win-x86_64` | Only `win-x86_64` works; no 32-bit prebuilt libraries are available (LiveCode's server no longer serves them, and the `prebuilts-v1` mirror has only x86_64). |
| `VSINSTALLDIR` | found with `vswhere` | Visual Studio folder to use. Without it, `make.cmd` picks the newest installation that has the v141 toolset component, then a Visual Studio 2017 installation with the C++ build tools, then the newest installation of any version with the C++ build tools. |
| `WINSDK_VERSION` | the SDK that `vcvarsall.bat` selected | Windows SDK version passed to MSBuild as `/p:WindowsTargetPlatformVersion`, for example `10.0.17763.0`. |
| `MSBUILD_EXTRA_ARGS` | empty | Extra arguments added to the end of the MSBuild command line, for example `/v:minimal`. |

For example, a Debug build against a particular SDK:

```bat
set BUILDTYPE=Debug
set WINSDK_VERSION=10.0.17763.0
cmd /c ..\make.cmd
```

`make.cmd` takes an optional MSBuild target as its first argument:

- no argument: the `default` target, which builds everything and copies
  the results into `win-x86_64-bin`;
- `check`: builds and runs the C++ unit tests (Google Test). This has not
  been tried on this fork yet.

The intermediate files go to `build-win-x86_64\livecode\Release` (or
`Debug`). The finished files are copied to `win-x86_64-bin` in the
repository root, whichever build type you choose, so a Debug build
replaces the Release files there.

[`tools/ci/build-windows.ps1`](tools/ci/build-windows.ps1) runs the
configure and build steps with a checked tool setup (Python 2.7 first on
`PATH`, a native Perl, Cygwin through `CYGPATH`, and no other
`cygpath.exe` on `PATH`). CI uses it, and you can too:

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\build-windows.ps1
```

**Visual Studio IDE.** You can open `build-win-x86_64\livecode\livecode.sln`
in Visual Studio 2022 to read and debug the code. Building from inside
Visual Studio is not set up: the generated projects do not name a
Windows SDK, so the v141 toolset looks for the Windows 8.1 SDK and is
expected to fail with MSB8036. `make.cmd` passes the SDK version on the
command line, so build with it.

## 6. Prebuilt libraries

The engine links a set of third-party libraries that are not compiled
during the normal build. They come as prebuilt archives:

| Archive | Contents |
| --- | --- |
| `CEF-74.1.19-...-gb62bacf` | Chromium Embedded Framework 74 (Chromium 74.0.3729.157), for the browser widget and revBrowser |
| `OpenSSL-<version>-...-PIC` | OpenSSL: `prebuilt/versions/openssl` (1.1.1w) on Linux and macOS; `prebuilt/versions/openssl_win32` (1.1.1g, the published Windows prebuilts) on Windows |
| `Curl-7.51.0-...-PIC` | libcurl 7.51.0 (server engine) |
| `ICU-58.2-...-1-PIC` | ICU 58.2 |
| `Thirdparty-e5e050573c...-PIC` | static libraries built from `thirdparty/` (cairo, libffi, giflib, libjpeg, libpng, zlib, libzip, PCRE, Skia, libxml2, libxslt, MySQL Connector/C, libpq, SQLite) |

Each comes in a `v141_static_release` and a `v141_static_debug` variant,
for x86_64 only. LiveCode Ltd's build servers produced them, and
LiveCode's download server no longer serves them. They are mirrored,
unchanged, as assets of this repository's
[`prebuilts-v1` release](https://github.com/SethMorrowSoftware/winoxt/releases/tag/prebuilts-v1).

SQLite is the exception: the `Thirdparty` archive still holds an older
SQLite (3.34.0), so the Windows build compiles `dbsqlite.dll` against
the SQLite 3.51.1 source in `thirdparty/libsqlite` instead.

### Automatic download

You normally do nothing: the first build runs
`prebuilt/fetch-libraries.sh` (through `util\invoke-unix.bat` and Cygwin),
which

1. downloads the archives into `prebuilt\fetched`, both the debug and the
   release variants;
2. checks each one against [`prebuilt/SHA256SUMS`](prebuilt/SHA256SUMS);
3. unpacks them into `prebuilt\unpacked`.

Later builds reuse what is there. Both folders are ignored by Git.

To fetch without building, run the script with Cygwin's bash:

```bat
C:\cygwin64\bin\bash.exe -lc "cd /cygdrive/c/src/winoxt/prebuilt && ./fetch-libraries.sh win32 x86_64"
```

### Settings

`fetch-libraries.sh` reads these optional environment variables. Set
them in the command prompt before running `make.cmd`; they are passed
through to the script.

| Variable | Meaning |
| --- | --- |
| `PREBUILT_URL` | Where to download from. Default: `https://github.com/SethMorrowSoftware/winoxt/releases/download/prebuilts-v1`. |
| `PREBUILT_LOCAL_DIR` | A folder that already holds the `.tar.bz2` files. They are copied from there instead of downloaded. A Windows path such as `C:\prebuilts` is fine. |
| `PREBUILT_CACHE_DIR` | Download into this folder instead of `prebuilt\fetched`. |
| `PREBUILT_WIN32_LIBS` | Which libraries to fetch, for example `OpenSSL Curl`. Default: all five. |
| `PREBUILT_WIN32_SUBPLATFORMS` | Which variants to fetch. Default: `v141_static_debug v141_static_release`. CI uses `v141_static_release`, which skips about 165 MB of debug downloads. |
| `PREBUILT_SKIP_VERIFY=1` | Do not check the SHA-256 sums. Only for testing new archives. |
| `PREBUILT_STRICT=1` | Fail if an archive has no entry in `prebuilt/SHA256SUMS` (by default that is only a warning). |

**Debug builds need the debug archives.** The default fetches both
variants, so this only matters if you set
`PREBUILT_WIN32_SUBPLATFORMS=v141_static_release`.

### Offline use

On a machine with internet access, download the `.tar.bz2` files you
need from the
[`prebuilts-v1` release](https://github.com/SethMorrowSoftware/winoxt/releases/tag/prebuilts-v1)
(and `SHA256SUMS` if you want to check them yourself). Copy them to the
build machine, then:

```bat
set PREBUILT_LOCAL_DIR=C:\prebuilts
cmd /c ..\make.cmd
```

### Changing the prebuilt libraries

The archives are identified by the versions in `prebuilt/versions/` and
checked against `prebuilt/SHA256SUMS`. To publish new ones (for example
newer OpenSSL or CEF builds), create a new release tag holding the
archives and their checksums, update `prebuilt/versions/`,
`prebuilt/SHA256SUMS` and the default `PREBUILT_URL`, and never replace
the assets of an existing release. The scripts that built the archives
upstream (`prebuilt/build-libs.bat`, `prebuilt/scripts/build-*.bat`) are
unchanged from LiveCode and still expect VS 2017; bringing them up to
date is future work.

## 7. Run, check and package the result

### Run the IDE from your clone

```bat
cd /d C:\src\winoxt
win-x86_64-bin\LiveCode-Community.exe
```

The development engine sees that it is running from a folder called
`win-x86_64-bin` and loads the IDE from the `ide` folder next to it. It
also uses `ide-support\`, `extensions\script-libraries\`, `docs\` and the
`*.lcb` files in `engine\src` and `libscript\src`, so run it from a
complete checkout. This is the *development layout*; see
[Development and installed layouts](#development-and-installed-layouts)
for how it differs from an installed OXT-Beyond.

The menubar window's title shows "OXT-Beyond" and the version in
`ide/.version`; the build number (*Preferences > Automatic Updates*) is
the placeholder `0` from `ide/.buildnumber`. The IDE uses the same
preference, cache and log folders as an installed OXT-Beyond
(`%APPDATA%\OXT-Beyond`, `%LOCALAPPDATA%\OXT-Beyond`).

Running the IDE from your clone can change files in it. The dictionary
deletes and rewrites its index files
(`ide/Documentation/html_viewer/resources/data/api/exports/*/index.txt`,
tracked by Git) each time it opens, and the IDE writes
`ide/environment_log.txt` (ignored). If you switch the dictionary to
LiveCode's HTML dictionary in the preferences, the IDE in this layout
may also regenerate the dictionary data in
`ide/Documentation/html_viewer/resources/data` from `docs/`, replacing
tracked files. Check `git status` before you commit, and restore what
you did not mean to change with `git checkout -- <path>`.

### Check the build

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\verify-build.ps1
```

[`tools/ci/verify-build.ps1`](tools/ci/verify-build.ps1) checks that the
expected files exist, that `dbsqlite.dll` contains the `SQLITE_SOURCE_ID`
from `thirdparty/libsqlite/include/sqlite3.h` (SQLite 3.51.1), and that
`LiveCode-Community.exe` contains the version from the `version` file.
The same checks by hand:

```bat
findstr /M /C:"9.7.1-OXT" win-x86_64-bin\LiveCode-Community.exe
findstr /M /C:"2025-11-28 17:28:25" win-x86_64-bin\dbsqlite.dll
```

Each command prints the file name if the text is found.

### Smoke test

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\smoke-test.ps1
```

[`tools/ci/smoke-test.ps1`](tools/ci/smoke-test.ps1) starts the
development engine without a user interface (`-ui`) and runs
[`tools/ci/smoke-test.livecodescript`](tools/ci/smoke-test.livecodescript).
It checks the script engine, Unicode handling (ICU), encryption (OpenSSL,
through `revsecurity.dll`), SQLite through revDB (the version must match
`thirdparty/libsqlite/include/sqlite3.h`; FTS5 and JSON must work and
R*Tree must be compiled in), revXML and revZip. In an installed layout
with the [xTalk Suite extensions](#xtalk-suite-extensions) it also loads
each of them as the IDE does and calls it (see there). It prints one
line per check and exits with the number of failed checks.

Without options it tests `win-x86_64-bin\LiveCode-Community.exe`. It can
also test the other layouts:

| Option | What is tested |
| --- | --- |
| `-Package dist\OXT-Beyond-<ver>-win-x86_64-portable.zip` | The zip is extracted to a temporary folder and its layout detected: the portable zip is an installed layout, so `OXT-Beyond.exe` in it is tested, with the externals in `Externals` and the database drivers in `Externals\Database Drivers`. A zip with a `win-x86_64-bin` folder is tested as a development layout. |
| `-InstallDir <folder>` | An installed OXT-Beyond, for example `-InstallDir "C:\Program Files\OXT-Beyond"`. |
| `-Exe <file name>` | An engine with another file name. |
| `-LogFile <file>` | Also writes the engine's output to a file. |

The smoke test does not open the IDE's windows; to check those, start
the IDE normally.

On Linux and macOS (and on Windows too) the same test runs through
[`tools/ci/run_livecode_check.py`](tools/ci/run_livecode_check.py) with
Python 3:

```sh
python3 tools/ci/run_livecode_check.py smoke --bin linux-x86_64-bin
python3 tools/ci/run_livecode_check.py smoke --install <staged OXT-Beyond-<ver> folder>
python3 tools/ci/run_livecode_check.py smoke --package OXT-Beyond-<ver>-linux-x86_64.tar.xz
```

It passes what differs between platforms to the script (the processor,
the externals' suffix `.dll`/`.so`/`.bundle`, and the code folders the
IDE maps for LCB libraries) and takes the extension libraries'
dependencies from
[`tools/ci/check_native_deps.py`](tools/ci/check_native_deps.py), which
reads ELF, Mach-O and PE files itself (no readelf, otool or dumpbin): a
library that needs something that is neither a system library nor next
to it (on Linux: next to it with a run path of `$ORIGIN` itself, not
`$ORIGIN/lib`; on macOS: `@loader_path`, and a `.bundle` or `.framework`
folder is checked through its Mach-O) fails. `--package` extracts to a neutral temporary folder,
keeping modes and symbolic links; an installed layout in a folder named
`_build` or `*-bin` is refused, because the engine would run the IDE of
the checkout (repository mode). No X display is needed: `-ui` starts no
user interface.

### Package

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\package-windows.ps1
```

[`tools/ci/package-windows.ps1`](tools/ci/package-windows.ps1) needs
Python 3 (section 2.6). It runs
[`tools/oxt/package.py`](tools/oxt/package.py), which writes the
*installed layout*, the program folder that the portable zip contains
and the installer installs, to `dist\stage\OXT-Beyond-<ver>\`. Then it
writes to `dist\` (`<ver>` is the content of `ide/.version`, for example
`0.0.1`):

| File | Contents |
| --- | --- |
| `OXT-Beyond-<ver>-win-x86_64-portable.zip` | The staged program folder, under one top folder `OXT-Beyond-<ver>\`. |
| `OXT-Beyond-<ver>-win-x86_64-binaries.zip` | `win-x86_64-bin` without `.pdb` files, plus `LICENSE`, `LICENSE-EXCEPTION.md` and `THIRD-PARTY-NOTICES.md`. Extracting it into the root of a source checkout gives the same layout as a build. |
| `OXT-Beyond-<ver>-win-x86_64-symbols.zip` | The `.pdb` debug symbols, under `win-x86_64-bin\`. |
| `OXT-Beyond-<ver>-xtalk-sources.zip` | Only with `-XtalkSourcesZip` (CI sets it for release builds): every file the [xTalk Suite extensions](#xtalk-suite-extensions) pin, as packaging took them, with the manifest. |
| `SHA256SUMS` | Checksums of the zips. [`build-installer.ps1`](#installer) rewrites it when it adds the installer. |

Options: `-BuildNumber <n>`, `-AssetsCache <folder>`,
`-NoExternalAssets`, `-NoXtalkExtensions`, `-XtalkCache <folder>`,
`-XtalkSourcesZip`, `-VcRedist <folder>` (see
[xTalk Suite extensions](#xtalk-suite-extensions)), `-OutDir <folder>` (default `dist`),
`-StageParent <folder>` (default `<OutDir>\stage`), `-BinDir <folder>`,
`-Python <path>` and `-CompressionLevel Optimal|Fastest|NoCompression`.
Existing files of the same names are replaced; other files in `dist`
are left alone.

`package.py` puts the staged folder together from:

- **the IDE**, assembled by `tools/oxt/layout.py` from `ide/Toolset`,
  `ide/Plugins`, `ide/Resources`, `ide/Documentation`, `ide/Extensions`,
  the files at the root of `ide/` (`about.dat`, `.version`, the licence
  texts and so on) and the eleven `ide-support` libraries, with LF line
  endings in text files whatever Git's `core.autocrlf` is;
- **the build output**, at the paths that
  [`Installer/package.txt`](Installer/package.txt) gives them on Windows
  x86-64: `OXT-Beyond.exe` (the development engine
  `LiveCode-Community.exe`, renamed), `revsecurity.dll` and
  `revpdfprinter.dll` at the root; `Externals\` (with `Externals.txt`),
  `Externals\Database Drivers\` (with `Database Drivers.txt`) and
  `Externals\CEF\`; `Toolchain\` with `lc-compile`, `lc-run`,
  `lc-compile-ffi-java` and the modules; `Runtime\Windows\x86-64\` with
  the standalone engine, its externals, support files and manifest
  templates; and `Extensions\` with the build's `packaged_extensions`
  and the extensions in `ide/Extensions`;
- **generated files**: `edition.txt` ("community"), `.buildnumber`, and
  two empty dictionary folders
  (`Documentation\html_viewer\resources\data\api\exports\{builder,datagrid}\plugins`)
  that Git cannot store;
- **the licence files** `LICENSE`, `LICENSE-EXCEPTION.md` and
  `THIRD-PARTY-NOTICES.md`, at the root;
- **the external assets**, see [below](#external-assets);
- **the xTalk Suite extensions** in `Extensions\`, fetched from their
  repositories at pinned commits and built with this build's
  `lc-compile`, see [below](#xtalk-suite-extensions).

Some build outputs are deliberately not installed: the `.pdb` files,
LiveCode's own installer engine (`installer.exe`), the server engine and
its externals, and the `canvas` and `ini` library extensions, which
`Installer/package.txt` does not list.

The build number written into the packaged `.buildnumber` is
`-BuildNumber` (`--build-number` for `package.py`), else the environment
variable `OXT_BUILD_NUMBER`, else the current UTC time as
`YYYYMMDDHHMM`. `ide/.buildnumber` in the repository is only a
placeholder (`0`).

You can also run `package.py` directly:

```bat
python tools\oxt\package.py --repo . --bin win-x86_64-bin --out dist\stage
```

It takes `--build-number N`, `--assets-cache DIR`,
`--no-external-assets`, `--no-xtalk-extensions`, `--vc-redist DIR`,
`--xtalk-cache DIR`, `--offline` (use cached assets and extension files
only), `--eol lf|crlf|keep`, `--summary-json FILE` and the comparison
options below.

**Comparing with OpenXTalk Lite 1.15.** The staged layout is meant to
contain every file of OpenXTalk Lite 1.15 that is not part of the IDE,
at the same path, apart from intended differences. To check:

```bat
python tools\oxt\package.py --repo . --bin win-x86_64-bin --out %TEMP%\oxtb-stage --compare "C:\path\to\OpenXTalk Lite" --report compare.tsv
```

`--compare` takes the extracted `openxtalk-lite-1.15-win-noinstaller.7z`
folder, or a TSV path list written by `layout.py classify`. It fails if
a file of 1.15 that is not part of the IDE is missing without a reason,
if a staged file that is not part of the IDE is not in 1.15 and is not
an intended addition, or if a file from an external asset is not
byte-identical to 1.15's. IDE changes since 1.15 are listed but are not
errors. The intended differences are:

- `OpenXTalk-Lite.exe` is staged as `OXT-Beyond.exe`;
- `Ext\` (the mergExt externals) is not included (see
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#files-openxtalk-lite-shipped-that-oxt-beyond-does-not));
- ten `.lci` files in `Toolchain\modules\lci` are missing: interfaces of
  LiveCode commercial-edition modules that this repository does not
  have, and `com.livecode.commercial.license.lci`, which this build does
  not write;
- files `layout.py` classes "excluded" (Apple's Human Interface
  Guidelines PDF, `animationEngine6.zip`) or "junk"
  (`OpenXTalk Lite.lnk`, `test.db`, an empty
  `Toolset\palettes\dictionary\api.sqlite`) are not staged;
- the licence files, `PROVENANCE-oxt-runtimes-1.15.md` and the xTalk
  Suite extensions (with `Extensions\XTALK-EXTENSIONS.txt`) are added.

Build outputs are staged as this repository builds them, so some of
them differ from Tom Perry's binaries in 1.15 even where the paths
match; the report marks them "rebuilt".

### Linux package

The Linux x86-64 package is made on Linux (or in WSL, under a Linux path
such as `/tmp`, never `/mnt/c`: the tree needs Unix modes and links)
from the two tarballs the Linux workflow uploads,
`OXT-Beyond-linux-x86_64-bin.tar.xz` and
`OXT-Beyond-linux-x86_64-symbols.tar.xz` (see
[tools/oxt/README.md](tools/oxt/README.md) for the layout):

```sh
python3 tools/oxt/package.py --platform linux-x86_64 \
    --bin-tar OXT-Beyond-linux-x86_64-bin.tar.xz --out /tmp/stage --summary-json /tmp/stage.json
python3 tools/oxt/package_dist.py --summary /tmp/stage.json \
    --bin-tar OXT-Beyond-linux-x86_64-bin.tar.xz \
    --symbols-tar OXT-Beyond-linux-x86_64-symbols.tar.xz --out dist
```

This writes `OXT-Beyond-<ver>-linux-x86_64.tar.xz` (the program folder
`OXT-Beyond-<ver>`), `-binaries.tar.xz` (`linux-x86_64-bin` without the
`.dbg` files, plus the licence files), `-symbols.tar.xz` (the `.dbg`
files) and `SHA256SUMS`. Besides the engine (`OXT-Beyond`) and the IDE,
the folder has the launcher `oxt-beyond`, `install.sh`, `uninstall.sh`
and `linux/` (desktop entry, MIME types, icons and the library list the
launcher checks), from
[`Installer/linux`](Installer/linux). Test it extracted to a folder
whose path has no `_build` or `*-bin` in it:

```sh
python3 tools/ci/run_livecode_check.py smoke --package dist/OXT-Beyond-<ver>-linux-x86_64.tar.xz
python3 tools/ci/run_livecode_check.py compile --install <folder>/OXT-Beyond-<ver> --engine <folder>/OXT-Beyond-<ver>/oxt-beyond
python3 tools/ci/check_linux_libraries.py --root <folder>/OXT-Beyond-<ver> --repo .
python3 tools/ci/test_linux_package.py --root <folder>/OXT-Beyond-<ver>
```

`check_linux_libraries.py` runs `ldd` over every x86-64 ELF file and
checks that `Installer/linux/libraries.txt` names every system library
the package needs; run it where that list's packages are installed.
`test_linux_package.py` tests the launcher with a stand-in engine and
runs `install.sh` and `uninstall.sh` in scratch home folders (it never
touches your own). The Linux workflow's "Package linux-x86_64" job does
all of this on `ubuntu-24.04` (see [Continuous integration](#9-continuous-integration)).

### macOS app

The universal macOS app is made on a Mac (the job "Package
mac-universal" uses `macos-15`) from the two builds the macOS workflow
uploads, `OXT-Beyond-mac-arm64-bin.tar.xz` and
`OXT-Beyond-mac-x86_64-bin.tar.xz`, each with its `-symbols.tar.xz`
extracted over it (all four unpack as `Release/`, so each architecture
goes into a folder of its own). Keep every path free of folders named
`_build` or `*-bin`, which put the engine into repository mode. The
steps, as the job runs them (see
[tools/oxt/README.md](tools/oxt/README.md#universal-build-signing-and-disk-image-macos)):

```sh
python3 tools/ci/merge_universal.py --arm64 A/Release --x86_64 X/Release --out U/Release --report merge-report.tsv
python3 tools/ci/sign_mac_app.py U/Release
python3 tools/oxt/package.py --platform mac-universal --bin U/Release --out /tmp/stage --summary-json /tmp/stage.json
python3 tools/ci/sign_mac_app.py /tmp/stage/OXT-Beyond-<ver>/OXT-Beyond.app
python3 tools/ci/merge_universal.py --check /tmp/stage/OXT-Beyond-<ver>/OXT-Beyond.app
python3 tools/oxt/package_dist.py --summary /tmp/stage.json --bin U/Release --out dist --dmg
```

This joins the two builds with `lipo`, signs the result ad hoc, stages
`OXT-Beyond.app` (the engine in `Contents/MacOS`, everything else in
`Contents/Tools`), signs the app from the inside out, checks that every
Mach-O file of macOS code in it holds arm64 and x86_64, and writes
`OXT-Beyond-<ver>-mac-universal.dmg`, `-mac-universal.zip`,
`-mac-universal-binaries.tar.xz`, `-mac-universal-symbols.zip` and
`SHA256SUMS`. The test jobs install the app from the disk image into a
neutral folder on an Apple Silicon and an Intel runner and run:

```sh
codesign --verify --deep --strict --verbose=2 <folder>/OXT-Beyond.app
python3 tools/ci/run_livecode_check.py smoke --install <folder> --platform mac-universal
python3 tools/ci/check_native_deps.py --root <folder>/OXT-Beyond.app/Contents/Tools --platform mac --max-macos 15.0
python3 tools/ci/run_livecode_check.py compile --install <folder> --platform mac-universal
python3 tools/ci/standalone_check.py --install <folder> --platform mac-universal
```

`standalone_check.py` builds a Mac standalone from the packaged runtime
with the engine's deploy command, signs it as the IDE does and runs it.

### External assets

External assets are files that the packages include but that this
repository neither builds nor keeps in Git, such as the standalone
runtimes for other platforms. They are listed in
[`tools/oxt/external-assets.json`](tools/oxt/external-assets.json). Each
asset is one zip archive with a fixed URL, size and SHA-256:

| Field | Meaning |
| --- | --- |
| `id` | A unique name, used in messages and reports. |
| `url` | HTTPS URL of the archive. |
| `sha256`, `size` | SHA-256 (lowercase hex) and size in bytes of the archive. |
| `kind` | `zip` (the only kind so far). |
| `strip` | Number of leading path components removed from every member of the archive. |
| `dest` | Folder, relative to the installed root, that the remaining paths go into (`""` for the root). |
| `rename` | Optional: members that go somewhere else, as `{"<path after strip>": "<path relative to dest>"}`. |
| `description`, `licence`, `source` | Text for people and reports. |

Today there is one asset, `oxt-runtimes-1.15`: the Windows x86-32, Linux
and Android runtimes and the time zone library code for other platforms
from OpenXTalk Lite 1.15, unchanged, with a `PROVENANCE.md` (installed as
`PROVENANCE-oxt-runtimes-1.15.md`). It is published as the file
`oxt-runtimes-1.15.zip` of this repository's release `runtimes-1.15`.
Until that release exists, packaging with external assets fails; use
`-NoExternalAssets` in the meantime (in CI, the `no_external_assets`
input or the `OXT_NO_EXTERNAL_ASSETS` variable; see
[Continuous integration](#9-continuous-integration)).

**Download cache.** The archives are downloaded into the folder given
with `-AssetsCache` (`--assets-cache`), else the environment variable
`OXT_ASSETS_CACHE`, else `prebuilt\fetched-assets` in the repository
(ignored by Git). An archive in the cache is used when its size and
SHA-256 match the manifest; otherwise it is downloaded again over HTTPS
(redirects followed, transient errors retried) to a temporary name and
moved into place once it has been verified. A download whose size or
SHA-256 does not match the manifest is an error and is not retried.
[`tools/oxt/fetch_assets.py`](tools/oxt/fetch_assets.py) does the same
without packaging:

```bat
python tools\oxt\fetch_assets.py --list
python tools\oxt\fetch_assets.py
```

It also takes `--assets-cache DIR`, `--offline` and `--id ID`. To
package on a computer without internet access, copy the archive (with
its file name from the URL) into the cache folder; with `--offline`,
`package.py` makes sure nothing is downloaded.
`-NoExternalAssets` (`--no-external-assets`) leaves the assets out
altogether; the IDE then offers no standalone targets for other
platforms.

**Making the runtimes asset.**
[`tools/oxt/make_runtimes_asset.py`](tools/oxt/make_runtimes_asset.py)
builds it from an extracted OpenXTalk Lite release, taking only files
that `layout.py` classes "external" (not `Ext\`):

```bat
python tools\oxt\make_runtimes_asset.py "C:\path\to\OpenXTalk Lite" --out C:\tmp\oxt-asset --source-archive openxtalk-lite-1.15-win-noinstaller.7z --update-manifest
```

It writes `oxt-runtimes-<version>.zip` and a copy of its `PROVENANCE.md`
to the `--out` folder. With `--stock-setup <file>` (the `.setup.exe` of
LiveCode Community 9.6.3 for Windows) `PROVENANCE.md` also says which
files are identical to LiveCode's. The zip is reproducible (sorted
entries, file dates from the files), so the same folder and options
give the same SHA-256. `--update-manifest` writes the size and SHA-256
into `tools/oxt/external-assets.json`; commit that change.

**Publishing an asset** is a manual step for a maintainer. Create a
release with a tag that does not start with `v` and attach the files;
`PROVENANCE.md` is too long for release notes, so attach it as a file:

```bat
gh release create runtimes-1.15 C:\tmp\oxt-asset\oxt-runtimes-1.15.zip C:\tmp\oxt-asset\PROVENANCE.md --prerelease --title "Standalone runtimes from OpenXTalk Lite 1.15" --notes "Prebuilt files used by tools/oxt/package.py. See PROVENANCE.md (also inside the zip)."
```

`--prerelease` keeps the release from becoming the repository's latest
release, because GitHub never treats a pre-release as the latest
release. OXT-Beyond's update check reads the latest release first; it
skips releases whose tag is not a version, but people browsing the
Releases page would see an asset release marked latest. Never replace
the file of a published asset: the manifest pins its SHA-256, and
packages made earlier must stay reproducible. To change
an asset, publish it under a new tag and add or update the manifest
entry.

**Adding an asset**: add an entry with the URL of the release archive,
its size and SHA-256, `strip` and `dest`, and its description, licence
and source; add the component to
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md); and check the staged
result. Extensions from the xTalk Suite are not assets; they have their
own manifest, described next.

### xTalk Suite extensions

OXT-Beyond ships the extensions of the
[xTalk Suite](https://github.com/SethMorrowSoftware/xtalk-suite) built
in (the [README](README.md#xtalk-suite-extensions) lists them): six LiveCode
Builder libraries with native code and nine LiveCode Script libraries.
They are neither kept in this repository nor copied into it.
[`tools/oxt/xtalk-extensions.json`](tools/oxt/xtalk-extensions.json)
pins each member repository (`SethMorrowSoftware/<repository>`) at a
commit and lists the exact files taken from it, each with the SHA-256
and size of its Git blob, and
[`tools/oxt/xtalk_extensions.py`](tools/oxt/xtalk_extensions.py) fetches
and builds them. `package.py` runs it with the build it packages, so a
package always has the pinned versions, compiled by its own
`lc-compile`.

| Field | Meaning |
| --- | --- |
| `name`, `repository`, `commit` | The member, its `owner/repository` on GitHub and the full commit SHA-1. |
| `version`, `version_from` | The member's version, and where `pin` reads it: a file and a regular expression (the `.lcb` metadata, or a version constant of a script library). |
| `files` | Every file taken: its `path` in the repository, its `role` (`source`; `library` for the native libraries in `src/code/<platform-id>/`, all five platform ids; `code-manifest` for the member's `MANIFEST.sha256`; `licence`), the `sha256` and `size` of its Git blob and, for Windows libraries, `imports`, the DLLs it imports. A licence file may have a `name` to use in `licenses/`, `"extract": "leading-comment"` (only the comment at the top of the file is shipped: the RHash notice in SodiumXT's `sha3.c`, the trezor-crypto notices in CoinXT's `address.c` and `hasher.c`), or a `repository` and `commit` of its own (OpenSSL's licence text, for the two members that link OpenSSL). |
| `extensions` | What is made from the files: `kind` (`lcb` or `lcs`), `id`, `folder` in `Extensions\`, the `main` file, `probe` and `expect` (an expression and a regular expression its value must match, for the smoke test) and, for script libraries, `stack`, `title`, `author` and `requires`. |
| `vc_runtime` (top level) | The Visual C++ runtime DLLs bundled with the libraries that need them (see below): `redist`, the redistributable folder they were pinned from, `file_version`, the DLLs' file version, and `files`, the `sha256` and `size` of each DLL per Windows platform id. |

Line endings matter: the SHA-256 values are those of the files as Git
stores them (LF), which is what `raw.githubusercontent.com` serves. A
clone with `core.autocrlf=true` has other bytes in its working copy.

**What is built.** For each LCB library, `Extensions\<id>\` with the
`.lcb` source, `module.lcm` and `manifest.xml` from `lc-compile`,
`code\<platform-id>\<library>` for Windows x86-64 and x86, Linux x86-64
and x86 and macOS (the IDE maps the one for its platform into
`revLibraryMapping`, and the standalone builder copies the one for the
target into a standalone), and `licenses\`. `lc-compile` runs in that
folder with relative paths, because `module.lcm` embeds the source path
as given; writes the module interface into a temporary folder
(`--interface`), never into `modules\lci` (which the build checks is
unchanged); and runs without `-Werror`, because Box2Dxt's module id
`org.openxtalk.box2dxt` has a digit in a namespace component, which is a
warning. For each script library, `Extensions\<stack>\` with
`<stack>.livecodescript`, `manifest.xml` and `licenses\`. The script is
the pinned file with a `script "<stack>"` first line where it has none
(OnionXT's two files and the Box2Dxt Kit, whose line numbers are then
one more than in their repositories) and an `extensionInitialize` /
`extensionFinalize` pair appended at the end: the IDE loads a script
library by sending it `extensionInitialize`, and without that handler it
would sit in memory without being in the message path. The stack name,
the file name and the folder are the same and contain no dots, because
the IDE loads a script library under the part of its file name before
the first dot. The stack names are the ones the members document, not
reverse-DNS ids such as `org.openxtalk.library.coinxt`: a script
library's extension id is its stack name, a standalone loads it under
that name, and the members' code and documentation use
`start using stack "coinxt"` and so on. The cost is that a user's own
copy of one of these files, opened by its path while the built-in copy
is loaded, clashes with it: the engine keeps one stack per name and
sends `reloadStack`, and the IDE's handler then asks what to do. For an
`.lce` installed during the session, the built-in stack stays in memory
after it is unloaded, so the user's copy takes over only after a
restart. The README tells users this. `manifest.xml` is written from
the JSON; `requires` makes the IDE load a script library after the
libraries it needs.
`Extensions\XTALK-EXTENSIONS.txt` lists every extension with its
repository and commit. The same pins (including `vc_runtime`) and
`lc-compile` give the same files.

**The Visual C++ runtime.** `enetxt.dll` imports `MSVCP140.dll`,
`VCRUNTIME140.dll` and (x86-64) `VCRUNTIME140_1.dll`, and
`box2dxt.dll` imports `VCRUNTIME140.dll`: these two members build with
the dynamic runtime. OXT-Beyond's engine links the runtime statically
and does not install it, and a PC without the Visual C++ Redistributable
does not have these DLLs. So the build copies every DLL that a library
in `code\x86_64-win32` or `code\x86-win32` imports and that is neither a
Windows system DLL nor already in that folder from Visual Studio's
redistributable folder (`VC\Redist\MSVC\<version>`, the one with
`x64\Microsoft.VC14x.CRT` and `x86\Microsoft.VC14x.CRT`) into the
folder, next to the library. The engine loads extension libraries with
`LOAD_WITH_ALTERED_SEARCH_PATH`, so Windows looks for their DLLs there
first, and the standalone builder copies them into a standalone's
`Externals` folder with the library. They are Microsoft's Distributable
Code, so the build also writes `licenses\Microsoft-Visual-C++-Runtime.txt`
into those extensions: the DLLs, the Microsoft licence terms they are
under (with links) and what those terms ask of anyone who distributes
them further, for example in a standalone (see
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#microsoft-components)).
The build also checks that the
copies export every function the library imports from them. That
catches a redistributable that lacks a function, not every older one.
It warns when a copy's file version is older than the MSVC linker that
built the library, because Microsoft supports only a runtime at least as
new as the newest toolset used. That is the case now: `enetxt.dll` and
`box2dxt.dll` are linked with MSVC 14.51, while Visual Studio 2022 (the
CI image) ships runtime 14.44. Microsoft does not support that
combination, although both libraries load and pass the smoke test with
it. `XTALK-EXTENSIONS.txt` records each copy with its SHA-256 and file
version, and the redistributable folder it came from.

The runtime DLLs are pinned like everything else: `vc_runtime` in
`xtalk-extensions.json` lists the SHA-256 and size of each DLL per
platform (now Visual Studio 2022 17.14's redistributable folder
`14.44.35112`, file version 14.44.35211.0, which the windows-2022 CI
image has), and packaging verifies every copy against it. A copy from
another redistributable stops the build with both hashes and the pinned
file version; otherwise the same commit would package different DLLs on
another machine, or after the CI image moves to a newer Visual Studio.
`--allow-unpinned-vc-runtime` (`-AllowUnpinnedVcRuntime` for
`package-windows.ps1`) only warns instead, and the stamp then says the
runtime is not the pinned one; it is for trying out another
redistributable, never for a release (CI does not set it). To move to
another redistributable, pin it and commit the result:

```bat
python tools\oxt\xtalk_extensions.py pin-vc-runtime --vc-redist "%VCToolsRedistDir%."
```

It hashes, for every Windows platform id of the manifest, the DLLs the
libraries' recorded `imports` need from that folder (and what those DLLs
import in turn), and rewrites `redist`, `file_version` and `files`,
keeping the block's comment, which you update if it names the old
folder. So a new runner image with a newer Visual Studio takes one
command and a commit.

`package-windows.ps1` takes the folder from `-VcRedist` as given.
Otherwise it collects `VCToolsRedistDir` (set in a Visual Studio
developer prompt) and the redistributable folders of every Visual Studio
with the C++ tools that `vswhere` finds (newest first, each one's
default folder first) and takes the first that has the pinned DLLs, so
that a machine with several Visual Studio installs packages the pinned
runtime rather than the newest; if none has them, the first folder, and
packaging then stops with the mismatch. For `package.py` and
`xtalk_extensions.py` the folder is `--vc-redist`. Without it, packaging
warns and lists the libraries that cannot load on a PC without the
redistributable, and the checks below fail.

**Checks.** [`tools/ci/check-extension-imports.ps1`](tools/ci/check-extension-imports.ps1)
`-Root <installed layout>` reads the import tables of every DLL in
`Extensions\*\code\*-win32` and fails if one imports a DLL that is
neither a Windows system DLL (KERNEL32, USER32, ADVAPI32, WS2_32, WINMM,
CRYPT32, bcrypt, IPHLPAPI, MSWSOCK, msvcrt, api-ms-win-crt-*) nor next to
it; loading the libraries on a computer that has Visual Studio proves
nothing. The [smoke test](#smoke-test) maps each LCB library's
`code\x86_64-win32` files in `revLibraryMapping` as the IDE does, loads
its `module.lcm`, checks the result and evaluates its probe
(`sxVersion()`, `btLastError()`, `enLibraryVersion()`,
`dcLibraryVersion()`, `b2Version()` = 4, `cxKeccak256Len()` = 32); starts
each script library with `start using` after the ones it requires,
evaluates its probe (`cxHexEncode(numToByte(0))` = `00`, `b2kVersion()`
= 4, `oxVersion()`, `nxVersion()`, `nxrVersion()` and so on) and checks
that `extensionInitialize` and `extensionFinalize` put it into the back
scripts and take it out; and fails for a library whose imports the check
above would reject. The [IDE compile check](#ide-compile-check)
compiles the script libraries with the rest of `Extensions`.

**Cache and offline use.** The files are downloaded from
`https://raw.githubusercontent.com/<repository>/<commit>/<path>` into
the folder given with `--xtalk-cache`, else `OXT_XTALK_CACHE`, else the
`xtalk` folder of the asset cache (`prebuilt\fetched-assets\xtalk` by
default), as `<repository>\<commit>\<path>`. A cached file is used when
its size and SHA-256 match the manifest and deleted when they do not;
downloads go through `fetch_assets.py` (HTTPS only, transient errors
retried, verified before they are moved into place). The native
libraries are also checked against the member's `MANIFEST.sha256`.
`--offline` never downloads; with a filled cache, packaging works without
internet access. CI caches the folder, keyed on the manifest.

**Keeping the pinned files with a release.** The pins are commits of the
members' branches, fetched live, so rebuilding an old release depends on
the member repositories keeping those commits (a rewritten history, or a
renamed or private repository, would break it). Release builds
therefore also publish `OXT-Beyond-<ver>-xtalk-sources.zip` with the
release, listed in its `SHA256SUMS` (the Windows job writes it, once for
all platforms, since every platform takes the same pinned files): every pinned file, in the cache layout
`<repository>\<commit>\<path>`, with a copy of `xtalk-extensions.json`.
`xtalk_extensions.py export` writes it (sorted entries and fixed dates,
so the same pins give the same zip), and `package-windows.ps1
-XtalkSourcesZip` runs that. To rebuild an old tag, extract that
release's zip into an empty folder and use the folder as the cache:
`-XtalkCache <folder>` for `package-windows.ps1`, `--xtalk-cache <folder>
--offline` for `package.py`, `--cache <folder> --offline` for
`xtalk_extensions.py`. The files are still checked against the manifest.
As with external assets, never delete or replace this file of a
published release.

```bat
python tools\oxt\xtalk_extensions.py list
python tools\oxt\xtalk_extensions.py fetch
python tools\oxt\xtalk_extensions.py build --bin win-x86_64-bin --out %TEMP%\xtalk --vc-redist "%VCToolsRedistDir%."
python tools\oxt\xtalk_extensions.py export --out %TEMP%\xtalk-sources.zip
```

`VCToolsRedistDir` ends in a backslash, and cmd would pass `\"` on as a
literal quote (the rest of the line then ends up in the same argument).
The trailing `.` prevents that, and the path still resolves to the same
folder.

`fetch` also takes `--cache DIR`, `--offline`, `--member NAME` and
`--platforms x86_64-win32,x86-win32`; `build` takes `--cache`,
`--offline`, `--platforms` and `--summary-json FILE`, and replaces only
the folders it made before; `export` takes `--cache` and `--offline`.

**Taking newer versions.** The pins change only when a maintainer runs
`pin` and commits the result:

```bat
python tools\oxt\xtalk_extensions.py pin
python tools\oxt\xtalk_extensions.py pin --member CoinXT
python tools\oxt\xtalk_extensions.py pin --member Box2Dxt --ref <branch, tag or commit of the default branch>
```

`pin` resolves the commit (the head of the default branch unless
`--ref` is given; with `git ls-remote`, else the GitHub API). A commit
given with `--ref` must be on the member's default branch, which `pin`
checks with one call of the GitHub compare API. For a SHA-1 this is not
negotiable: `raw.githubusercontent.com` serves the commits of every fork
and unmerged pull request under the member's name, and a SHA-1 alone
does not show whose commit it is. A branch or tag named with `--ref`
whose commit is not on the default branch is refused as well, because
the packages fetch the pinned files live and such a commit disappears
when its branch is deleted; `--allow-off-branch` pins it anyway. Then
`pin` downloads every listed file at that commit, and rewrites the
manifest with the commit, the version, each file's SHA-256 and size and
the Windows libraries' imports, keeping its order and layout. It stops if a
library's hash differs from the member's `MANIFEST.sha256`, if that file
lists a library the manifest does not take (a new platform, for
example: add it to `files`), or if an LCB source declares another module
id or a script library another stack name than its extension entry.
Then review the diff (a changed `imports` list means a library needs
another DLL; if it is a Visual C++ runtime DLL, also run
`pin-vc-runtime`, or packaging stops at the unpinned copy), package and
run the smoke test, update
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#xtalk-suite-extensions)
if the components or licences changed, and commit. A new file or
extension is added to the manifest by hand, then `pin` fills in its
hashes.

**Leaving them out.** `-NoXtalkExtensions` (or the environment variable
`NO_XTALK_EXTENSIONS=1`) for `package-windows.ps1`,
`--no-xtalk-extensions` for `package.py`, and in CI the workflow input
`no_xtalk_extensions` or the repository variable
`OXT_NO_XTALK_EXTENSIONS=1` (release builds always include them).

### IDE compile check

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\ide-compile-check.ps1 -Root dist\stage\OXT-Beyond-<ver>
```

[`tools/ci/ide-compile-check.ps1`](tools/ci/ide-compile-check.ps1) runs
[`tools/ci/ide-compile-check.livecodescript`](tools/ci/ide-compile-check.livecodescript)
with the engine of that layout, without a user interface. It compiles
every script-only stack (`*.livecodescript`, `*.oxtscript`) under
`Toolset`, `Plugins` and `Extensions`, and every object script (stacks,
cards, groups and controls) of the binary stacks (`*.livecode`, `*.rev`,
`*.oxtstack`) under `Toolset` and `Plugins`; the script-only stacks
include the script libraries of the
[xTalk Suite extensions](#xtalk-suite-extensions). Stacks are loaded
with messages locked; they are never opened or saved. Each error is one
line:

```text
<file> | <object> | line <n> | <message>
```

Errors listed in
[`tools/ci/ide-compile-baseline.txt`](tools/ci/ide-compile-baseline.txt)
are known, pre-existing errors. The check fails (exit code 1) when there
is an error that is not in the baseline, or when the engine does not
finish; baseline entries that no longer occur are reported as warnings.
Today the baseline has one entry: a button script in the macOS ARM
standalone builder (`mac-arm-deploy.oxtstack`) that uses
`_internal build MacARM`, which only Tom Perry's macOS ARM engine
understands.

Options: `-Root` (default: the single `OXT-Beyond-*` folder in
`dist\stage`), `-Engine` (default: the layout's `OXT-Beyond.exe`, or
`win-x86_64-bin\LiveCode-Community.exe` for a layout without an engine),
`-LogFile`, `-TimeoutSeconds`. To rewrite the baseline from the current
errors, add `-UpdateBaseline` (and `-BaselineSource "<description>"`);
review the result before committing it.

On Linux and macOS, `tools/ci/run_livecode_check.py compile` does the
same with the same baseline (`--install <layout>`, `--package <file>`,
`--root <folder> --engine <file>`, `--update-baseline`). With
`--repo-layout --bin <build output>` it checks the source checkout before
anything is packaged: the Toolset, Plugins and Extensions that
`tools/oxt/layout.py` assembles from `ide/` and `ide-support/`, plus the
build's packaged extensions, are written to a temporary folder with their
installed paths (so the error records match the baseline's) and checked
with the build's development engine. The Linux and macOS workflows run
it after every build.

A file that crashes the engine is recorded as
`<file> | (file) | line 0 | the engine crashed while checking it`, and the
rest is checked in a second run. Errors that occur on one platform only
are listed in `tools/ci/ide-compile-baseline-<windows|linux|mac>.txt`
next to the shared baseline, which the Python check adds on that
platform (`--update-baseline` leaves them out of the shared file). The
Linux file has no entries at present: it listed
`Plugins/Quick Dictionary.livecode` while the Linux engine crashed on a
stack whose `textFont` is `(System)` without a user interface (the GTK
theme gives that font no family there; the engine now falls back to its
default family).

### Installer

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\build-installer.ps1
```

[`tools/ci/build-installer.ps1`](tools/ci/build-installer.ps1) compiles
[`Installer/oxt-beyond/oxt-beyond.iss`](Installer/oxt-beyond/oxt-beyond.iss)
with Inno Setup 6.3 or later over the staged layout (default
`dist\stage\OXT-Beyond-<ver>`) into
`dist\OXT-Beyond-<ver>-win-x86_64-setup.exe`, then rewrites
`dist\SHA256SUMS` over all files in `dist`. It looks for `ISCC.exe` in
`-Iscc`, the usual Inno Setup 6 folders, Inno Setup's uninstall
registration and `PATH`; if it finds none, it runs
`choco install innosetup -y --no-progress` (which needs Chocolatey and
administrator rights), unless you pass `-NoInstall`. The wizard images
are made from the icon art by
[`Installer/oxt-beyond/make-wizard-images.ps1`](Installer/oxt-beyond/make-wizard-images.ps1)
in a temporary folder (`-NoWizardImages` uses Inno Setup's own). Other
options: `-Stage`, `-OutDir`, `-Version`, `-BuildNumber` and `-LogFile`.
The `.iss` script can also be compiled on its own in the Inno Setup
IDE; it then reads the version from `ide/.version` and expects the stage
in `dist\stage`.

What the installer does:

- It has a fixed `AppId`, so a newer version replaces an installed one.
  Before installing over an older version it deletes the `Toolset`,
  `Extensions`, `Externals`, `Toolchain` and `Runtime` folders, so no
  file that the new version no longer ships is left behind.
- It installs for all users into `C:\Program Files\OXT-Beyond` (with
  administrator rights) or, if chosen on its first page or with
  `/CURRENTUSER`, for the current user into
  `%LOCALAPPDATA%\Programs\OXT-Beyond`.
- It shows `LICENSE` as the licence page, adds a Start menu shortcut
  and, optionally, a desktop shortcut, and optionally associates
  `.oxtstack` and `.oxtscript` files with `OXT-Beyond.exe "%1"` (program
  IDs `OXTBeyond.Stack` and `OXTBeyond.Script`; `.livecode` is left
  alone). The IDE no longer shows OpenXTalk Lite's own "File
  Associations" dialog on Windows (`ide/Toolset/home.livecodescript`),
  so it does not register `.rev`, `.livecode` or `.livecodescript`
  either.
- The IDE writes to some data files inside the program folder at run
  time. In an install for all users, the Users group gets Modify
  permission on these data files: the dictionary's
  `Documentation\html_viewer\resources\data\api\exports` folder, and
  `Toolset\palettes\updates\whatsnew.txt` and `updatehistory\*.txt`
  (opened with `open file`, which opens a file for reading and
  writing). No folder or file with stacks, scripts or programs is made
  writable, so the few places where the IDE saves stacks inside the
  program folder fail for standard users in an install for all users:
  the Report Builder plugin saving itself when it closes, *Plugin
  Settings* changes to the plugins that come with OXT-Beyond, and edits
  to the built-in image libraries (see the README's
  [known limitations](README.md#known-limitations-and-plans)). An
  install for the current user, or the portable zip, does not have this
  problem.
- The uninstaller removes the program files, shortcuts and file
  associations, but not the preferences, caches and logs in
  `%APPDATA%\OXT-Beyond` and `%LOCALAPPDATA%\OXT-Beyond`.
- Setup always writes a log to `%TEMP%`.

### Test the installer

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\test-installer.ps1 -Setup dist\OXT-Beyond-<ver>-win-x86_64-setup.exe
```

[`tools/ci/test-installer.ps1`](tools/ci/test-installer.ps1) installs
the setup program silently for the current user into a new temporary
folder (`/CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=...`,
with the desktop shortcut), checks the exit code, the key files, that
every staged file was installed with the same size, `.version`, the
uninstall registration, the shortcuts, the file associations and the
Modify permissions, runs the smoke test on the installed
`OXT-Beyond.exe`, then uninstalls silently and checks that everything
was removed. It refuses to run if OXT-Beyond is already installed for
your user, and it leaves the file associations out if `.oxtstack` or
`.oxtscript` already open with another program. It changes your user
account while it runs (registry, Start menu, desktop), so a test
computer or virtual machine is a good place for it. Options:
`-InstallDir`, `-Stage`, `-LogDir`, `-TimeoutSeconds` and
`-SkipSmokeTest`.

### Development and installed layouts

| | Development layout (your clone) | Installed layout (`dist\stage`, portable zip, installer) |
| --- | --- | --- |
| Engine | `win-x86_64-bin\LiveCode-Community.exe` | `OXT-Beyond.exe` at the root |
| IDE | `ide\` and `ide-support\`, where they are in the repository | `Toolset\`, `Plugins\`, `Resources\`, `Documentation\` |
| Externals and database drivers | `win-x86_64-bin\` | `Externals\`, `Externals\Database Drivers\`, `Externals\CEF\` |
| Extensions | only the build's (`win-x86_64-bin\packaged_extensions`) | `Extensions\`: the build's, those in `ide/Extensions` (OXT Lite functions, DevGuides alignment guides, Calendar, Pie Chart, macOS Native Tools) and the [xTalk Suite extensions](#xtalk-suite-extensions) |
| Standalone runtimes | the build's Windows x86-64 engine | `Runtime\Windows\x86-64\` from the build, and the other platforms from the runtimes asset |
| Version and build number | `ide\.version`, `ide\.buildnumber` (`0`) | `.version`, `.buildnumber` (the real build number) at the root |
| `revEnvironmentIsInstalled()` | false | true |
| Used for | working on the engine and the IDE | what users run; what CI tests |

Tom Perry's IDE was made for, and tested in, the installed layout, and
the IDE has code paths for each layout, so check IDE changes in both. To
run the installed layout without installing it, start
`dist\stage\OXT-Beyond-<ver>\OXT-Beyond.exe`; but make your changes in
the repository, not in `dist\stage`, which the next packaging run
replaces.

## 8. Troubleshooting

Look in `build-win-x86_64\msbuild.log` for the first `error` line; the
lines before it usually show which step failed.

**"Cannot locate a Cygwin installation".** Install Cygwin into
`C:\cygwin64` (section 2.5), or set `CYGPATH` to its root folder.

**flex, bison or `/usr/bin/...` "No such file or directory".** The
shell steps ran in the wrong bash. When Cygwin is not in `CYGPATH`,
`C:\cygwin64` or `C:\cygwin`, `invoke-unix.bat` falls back to the first
`cygpath.exe` on `PATH`, which is often Git for Windows' `usr\bin`, and
Git's bash has no flex or bison. Install Cygwin as described, and keep
Git's `usr\bin`, MSYS2 and Cygwin itself off `PATH`.

**Messages from WSL (Windows Subsystem for Linux) instead of Cygwin.** A
plain `bash` typed in `cmd.exe` usually starts
`C:\Windows\System32\bash.exe`, the WSL launcher, not Cygwin. When you
run shell commands by hand (such as the manual fetch in section 6), call
Cygwin's bash by its full path, `C:\cygwin64\bin\bash.exe`.

**Python errors while configuring**, such as
`SyntaxError: Missing parentheses in call to 'print'` or a syntax error
at `except OSError, e:`. That is Python 3 running Python 2 code. Run
`C:\Python27\python.exe config.py ...` (or set `PYTHON` for
`configure.bat`).

**MSB8036: "The Windows SDK version 8.1 was not found"** (or another
version). The projects do not name an SDK, so `make.cmd` passes one.
Set `WINSDK_VERSION` to an installed SDK and build again, for example
`set WINSDK_VERSION=10.0.17763.0`. The installed versions are the folder
names in `C:\Program Files (x86)\Windows Kits\10\Include`.

**Compile errors in Windows SDK headers.** The only earlier build of
this code known to work (Tom Perry's) compiled against the Windows 8.1
SDK. SDK 10.0.22621.0 fails with C2059/C2238 in `winnt.h` while compiling
`kernel-installer` with v141, which is why CI selects 10.0.17763.0. A
newer SDK may expose other problems that have not been seen before.
As a fallback, install the Windows 8.1 SDK (the Visual Studio 2022
installer does not offer it; Microsoft's
[Windows SDK archive](https://learn.microsoft.com/en-us/windows/apps/windows-sdk/downloads-archive)
does), then `set WINSDK_VERSION=8.1` and build again. Please also report
the error in an issue.

**MSB8020: "The build tools for v141 cannot be found".** The v141
toolset is not installed in the Visual Studio that `make.cmd` picked.
Add the components from section 2.1, or point `VSINSTALLDIR` at the
installation that has them.

**`atlbase.h` or `afxres.h` not found.** The v141 ATL or MFC component
is missing (section 2.1).

**The build fails in a folder with spaces in its name.** Move or clone
the repository to a path without spaces, such as `C:\src\winoxt`.

**Downloading the prebuilt libraries fails**, or reports a SHA-256
mismatch. A mismatching file is deleted, so running the build again
retries the download. Behind a proxy or firewall, download the archives
some other way and use `PREBUILT_LOCAL_DIR` (section 6).

**LNK1104: cannot open file `libcef.lib`, `libeay32.lib` and so on.**
The prebuilt libraries are not unpacked for the configuration you are
building. Check that `prebuilt\unpacked\<Library>\x86_64-win32-v141_static_release`
(or `_debug` for a Debug build) exists. If in doubt, delete
`prebuilt\unpacked` and build again; the archives in `prebuilt\fetched`
are unpacked again.

**LNK2038: mismatch detected for 'RuntimeLibrary'.** A Debug build found
a Release library, or the other way round, usually because a library was
copied into `prebuilt\unpacked` by hand. Delete `prebuilt\unpacked` and
build again.

**The command prompt closes when the build finishes.** Run
`cmd /c ..\make.cmd` rather than `..\make.cmd`.

**Packaging fails to download `oxt-runtimes-1.15.zip`** (HTTP 404). The
`runtimes-1.15` release has not been published (or your fork does not
have it). Package with `-NoExternalAssets`, or copy the file into the
cache folder, where it is used without downloading when its size and
SHA-256 match (see [External assets](#external-assets)). In CI, start
the workflow by hand with `no_external_assets`, or set the repository
variable `OXT_NO_EXTERNAL_ASSETS` to `1` until the release exists.

**An external asset's size or SHA-256 does not match** ("expected ..."
in the message). The downloaded file is not the one the manifest pins,
and packaging stops. A cached copy that does
not match is downloaded again automatically; a fresh download that
does not match means the published file has changed or the download was
tampered with. Report it; do not update the manifest to match a file
you have not checked.

**`package-windows.ps1` finds no Python 3.** Install Python 3 (section
2.6) or pass `-Python C:\path\to\python.exe`. Python 2.7 is not enough
for packaging.

**`build-installer.ps1` cannot find `ISCC.exe`.** Install Inno Setup 6.3
or later (section 2.7) or pass `-Iscc C:\path\to\ISCC.exe`. The automatic
Chocolatey install needs Chocolatey and an elevated prompt.

**`test-installer.ps1` refuses to run.** OXT-Beyond is installed for
your user. Uninstall it first, or run the test in another account or on
a test computer.

### Line endings

With Git for Windows' default `core.autocrlf=true`, text files are
checked out with Windows (CRLF) line endings. This is the configuration
the existing builds used. Whatever your setting, `.gitattributes` forces
Unix (LF) line endings for the files that bash reads, such as `*.sh`,
`*.inc`, `prebuilt/versions/*` and `prebuilt/SHA256SUMS`, and Windows
(CRLF) line endings for `*.bat` and `*.cmd` files, which `cmd.exe` can
misread otherwise.

If bash reports `$'\r': command not found`, a shell script has CRLF line
endings, usually because it was edited with a Windows editor or the tree
did not come from `git clone`. Restore it with
`git checkout -- <file>`, and save shell scripts with LF line endings.
Do not change `core.autocrlf` in an existing clone; if you want a
different setting, make a fresh clone.

## 9. Continuous integration

The workflow [`.github/workflows/build-windows.yml`](.github/workflows/build-windows.yml)
("Build (Windows)") builds OXT-Beyond on GitHub's `windows-2022`
runners. It runs on every push and pull request to `main` and when
started by hand from the Actions tab; for a release,
[`release.yml`](#10-making-a-release) calls it (not on tags of its own).

It follows this guide:

1. It reads the product version from `ide/.version` (a tag build fails
   straight away if the tag is not `v` followed by that version) and
   sets `OXT_BUILD_NUMBER` to the UTC time at which the job started
   (`YYYYMMDDHHMM`), so every file of the run has the same build number;
   in a release, to the build number `release.yml` gives all three
   platforms.
2. It adds the v141 components to the runner's Visual Studio 2022 with
   `tools/ci/install-vs-components.ps1`, installs Python 2.7 and Cygwin,
   and fetches only the release prebuilt archives
   (`PREBUILT_WIN32_SUBPLATFORMS=v141_static_release`, with
   `PREBUILT_STRICT=1`, cached between runs).
3. It configures and builds Release x64 with `tools/ci/build-windows.ps1`
   and Windows SDK 10.0.17763.0, and checks the result with
   `tools/ci/verify-build.ps1`.
4. It packages with `tools/ci/package-windows.ps1`: the installed layout
   in `dist\stage\OXT-Beyond-<ver>` and the portable, binaries and
   symbols zips. The external assets' archives are cached from
   `prebuilt\fetched-assets\*.zip` between runs, keyed on the manifest. They
   are left out (`-NoExternalAssets`, with a warning in the run) when
   the workflow is started by hand with the input `no_external_assets`,
   or when the repository variable `OXT_NO_EXTERNAL_ASSETS` is `1`, for
   example while a new asset is not published yet. Release builds (the
   runs `release.yml` calls, its dry runs included) always include them.
   The files of the
   [xTalk Suite extensions](#xtalk-suite-extensions) are cached in
   `prebuilt\fetched-assets\xtalk`, keyed on their manifest; they are
   left out with the input `no_xtalk_extensions` or the variable
   `OXT_NO_XTALK_EXTENSIONS`, except in release builds, which also write
   `OXT-Beyond-<ver>-xtalk-sources.zip` (see
   [xTalk Suite extensions](#xtalk-suite-extensions)), the one copy of it
   that a release carries for all platforms. `package-windows.ps1`
   finds the runner's Visual C++ redistributable folder with `vswhere`
   and bundles the runtime DLLs that enetxt and Box2Dxt need;
   `tools/ci/check-extension-imports.ps1` then checks that every Windows
   DLL under `Extensions` finds its imports.
5. It runs the [smoke test](#smoke-test) on the portable zip (including
   the xTalk Suite extensions), the
   [IDE compile check](#ide-compile-check) on the staged layout, builds
   the [installer](#installer) and [tests it](#test-the-installer):
   install for the current user, smoke test of the installed program,
   uninstall.

It uploads two artifacts:

- `OXT-Beyond-win-x86_64`: when every step succeeds, the files in
  `dist\` (the installer, the three zips, in release builds the xTalk
  sources zip, and `SHA256SUMS`; not the staged folder), kept for 30
  days;
- `build-logs-win-x86_64`: `msbuild.log` and the logs of packaging, the
  smoke test, the IDE compile check and building and testing the
  installer, kept for 14 days and uploaded even when the build fails.

When a step fails, a "Failure diagnostics" table in the job summary
shows which step it was. Downloading artifacts requires a GitHub
account. Public downloads are Releases.

The badges at the top of the [README](README.md) and the
[Actions tab](https://github.com/SethMorrowSoftware/winoxt/actions)
show the state of the latest runs.

The Linux workflow ([`.github/workflows/build-linux.yml`](.github/workflows/build-linux.yml),
"Build (Linux)") builds x86-64 and arm64 in an Ubuntu 20.04 container
(see [Building on Linux](#12-building-on-linux)). Its job "Package
linux-x86_64" then makes and tests the [Linux package](#linux-package)
on `ubuntu-24.04` and uploads it as the artifact
`OXT-Beyond-linux-x86_64`; the header of the workflow file lists its
steps. It takes the same `no_external_assets` and `no_xtalk_extensions`
inputs and repository variables as the Windows workflow.

The macOS workflow ([`.github/workflows/build-macos.yml`](.github/workflows/build-macos.yml),
"Build (macOS)") builds arm64 on `macos-15` and x86_64 on
`macos-15-intel` (see [Building on macOS](#13-building-on-macos)). Its
job "Package mac-universal" joins the two into one universal
[macOS app](#macos-app), signed ad hoc, and uploads it as the artifact
`OXT-Beyond-mac-universal`; "Test mac-universal (arm64)" and "(x86_64)"
then install it from the disk image on each architecture and test it.
The repository variables `OXT_NO_EXTERNAL_ASSETS` and
`OXT_NO_XTALK_EXTENSIONS` work there too.

The Linux and macOS builds also upload their build outputs, without the
build's own tools (GENTLE among them, which may not be redistributed;
see `tools/ci/list_build_tools.py`), as `OXT-Beyond-<platform>-<arch>-bin`
and their debug symbols as `-symbols` (30 days); their logs are kept for
14 days. The checks of all three workflows are required for pull
requests into `main`: "Build win-x86_64", "Build linux-x86_64", "Build
linux-arm64", "Package linux-x86_64", "Build mac-arm64", "Build
mac-x86_64", "Package mac-universal", "Test mac-universal (arm64)" and
"Test mac-universal (x86_64)".

## 10. Making a release

Releases are built by CI from a tag: the workflow
[`.github/workflows/release.yml`](.github/workflows/release.yml)
("Release") builds, packages and tests Windows, macOS and Linux from the
tagged commit and publishes one GitHub Release with the files of all
three. The product version is the content of `ide/.version` (for
example `0.1.0`); the tag is `v` followed by it (`v0.1.0`). The engine
version in the `version` file (9.7.1-OXT, build 25923) is separate:
change it only when the engine changes, and then also check
`tools/ci/verify-build.ps1` and the smoke test, which compare against
it.

1. Make sure the external assets in `tools/oxt/external-assets.json`
   are published (see [External assets](#external-assets)); packaging
   fails without them. Decide whether the xTalk Suite extensions should
   move to newer commits of their repositories; if so, pin them (see
   [xTalk Suite extensions](#xtalk-suite-extensions)) and merge that
   first.
2. Set `ide/.version` to the new version, for example `0.1.0`, or
   `0.1.0-beta.1` for a pre-release. Update the README's status and
   limitations if they changed. Leave `ide/.buildnumber` at `0`.
3. Merge that change into `main` through a pull request and wait for the
   checks of all three build workflows to pass.
4. Do a [dry run](#dry-run) on `main` and look at its release files and
   notes (recommended; it takes as long as a release).
5. Tag the merged commit and push the tag:

   ```bat
   git checkout main
   git pull
   git tag -a v0.1.0 -m "OXT-Beyond 0.1.0"
   git push origin v0.1.0
   ```

6. The tag starts `release.yml`:
   - **Prepare the release** checks `ide/.version` and that the tag is
     `v` followed by it exactly (a tag that is not stops the run before
     anything is built), stops if a release of the tag is published
     already, and chooses one build number (the UTC time,
     `YYYYMMDDHHMM`) for every platform.
   - **Windows**, **Linux** and **macOS** run `build-windows.yml`,
     `build-linux.yml` and `build-macos.yml` as reusable workflows, with
     every build, package and test job they run for a pull request (the
     jobs show as "Windows / Build win-x86_64" and so on), as release
     builds: the external assets and xTalk Suite extensions are always
     included, and the Windows job writes the xTalk sources zip.
   - **Publish GitHub Release** runs only when every one of those jobs
     passed. It downloads the three package artifacts
     (`OXT-Beyond-win-x86_64`, `OXT-Beyond-mac-universal`,
     `OXT-Beyond-linux-x86_64`), checks each against its own
     `SHA256SUMS` and against the release's list of files
     ([`tools/ci/release_assets.py`](tools/ci/release_assets.py)), and
     writes one `SHA256SUMS` over all of them. It writes the notes
     ([`tools/ci/release_notes.py`](tools/ci/release_notes.py)), creates
     the release "OXT-Beyond <version>" as a **draft** with those notes
     followed by GitHub's generated list of changes, uploads every file,
     checks what GitHub now holds (names, sizes and SHA-256), and only
     then **publishes** the draft.

   A version with a pre-release part (anything after a `-`, such as
   `0.1.0-beta.1` or `0.1.0-rc.1`) becomes a pre-release; the update
   check orders versions and offers pre-releases the same way. The
   release's files:

   | Platform | Files (`OXT-Beyond-<version>-...`) |
   | --- | --- |
   | Windows x86-64 | `win-x86_64-setup.exe`, `win-x86_64-portable.zip`, `win-x86_64-binaries.zip`, `win-x86_64-symbols.zip` |
   | macOS universal | `mac-universal.dmg`, `mac-universal.zip`, `mac-universal-binaries.tar.xz`, `mac-universal-symbols.zip` |
   | Linux x86-64 | `linux-x86_64.tar.xz`, `linux-x86_64-binaries.tar.xz`, `linux-x86_64-symbols.tar.xz` |
   | All | `xtalk-sources.zip`, and `SHA256SUMS` |

   Edit the notes afterwards if needed: say what changed and repeat the
   known limitations from the README, below the opening lines. Keep the
   first twelve lines as they are, or as short and platform-neutral:
   the IDE's update check shows every user those lines (at most 700
   characters, as plain text).
7. Check that GitHub shows the new release as the latest one, for
   example with
   `gh api repos/SethMorrowSoftware/winoxt/releases/latest --jq .tag_name`.
   OXT-Beyond's update check reads that release (and the list of
   releases, if it is not an OXT-Beyond version or the user runs a
   pre-release). If another release is
   marked latest, fix it with `gh release edit v0.1.0 --latest`.
   Pre-releases are never "latest"; the update check offers them only to
   people who already run a pre-release.

GitHub also attaches source code archives of the tagged commit to the
release. They include `ide/` and `thirdparty/`, which are part of this
repository. The runtimes asset has its own release and names its
sources in its `PROVENANCE.md`.

### Dry run

A dry run does everything a release does except the calls that create
it: it builds, packages and tests the three platforms, assembles and
checks the release files, writes the notes, and uploads the files as
the artifact `release-dry-run` (30 days); the notes, and the lines the
update check would show, are in the summary of its last job. It creates
no release, no draft and no tag. Start it on the Actions tab (*Release*,
*Run workflow*, pick the branch, usually `main`, and leave *Dry run*
ticked), or with the GitHub CLI:

```bat
gh workflow run release.yml --ref main -f dry-run=true
```

The files are named after `ide/.version` of that branch. A run started
by hand without *Dry run* must be started on the tag `v<version>` (it
then publishes as a push of the tag does); on a branch it stops at once.

### When a release run fails

Nothing is published until every platform's files are uploaded and
checked, so a failure (a build, a test, a check, an upload) leaves at
most a **draft** release: only people with write access to the
repository see drafts, and the update check ignores them. The version is
not burned.

- **A passing problem** (a runner, the network, a flaky test): open the
  run and choose *Re-run failed jobs*. The publish job then reuses the
  draft of the tag, if there is one: its title and notes stay as they
  are (edit them on the Releases page if you like), the files are
  uploaded again, and it is published when everything is in. The draft
  must still name the run's commit: an edit of its notes must keep the
  line `Made by the "Release" workflow ... from commit <sha>`. A draft
  made from another commit (left by a run before the tag was moved) is
  refused, not published: delete it and re-run the job.
- **A problem in the code:** delete the draft, if there is one (on the
  Releases page; a new run's publish job refuses a draft of the old
  commit rather than publish its notes), fix the problem on `main`
  through a pull request, and release the fixed commit. Since nothing
  was published, you may delete the tag and tag the fixed commit with
  the same version (`git tag -d v0.1.0` and
  `git push origin :refs/tags/v0.1.0`, then steps 5 and 6), or tag a
  new version. Before you delete and push the tag again, cancel the old
  tag's run if it is still running (or let it finish), and never re-run
  that old run afterwards: it still builds the old commit, and its
  publish job refuses a tag that no longer points at the commit it
  built.

A release that is published is final: `release.yml` never changes or
replaces it (prepare and publish both stop with an error for a tag that
has one), and its tag must never be moved or deleted. Fix a problem in a
published release with a new version.

## 11. Working on the IDE

The IDE is in `ide/` (and eleven libraries in `ide-support/`). Run it
from your clone to work on it (section 7), and read
[CONTRIBUTING.md](CONTRIBUTING.md#changing-the-ide) before you change
it.

**Script-only stacks** (`*.livecodescript`) are text. Edit them in the
IDE's script editor or any text editor, keep the file's style, mark
changes to inherited scripts with `-- OXT-Beyond:` comments, and run the
[IDE compile check](#ide-compile-check). Prefer script-only stacks for
new code.

**Binary stacks** (`*.livecode`, `*.rev`, `*.oxtstack`) are stored in Git
byte for byte, as OpenXTalk Lite shipped them; Git cannot show what
changed inside them. To keep their history reviewable:

- open them with the IDE built from this repository, running from your
  clone, so that the stack is loaded from `ide/` and saved back there by
  the engine this project ships;
- change only the stack you mean to change, and do not save the others
  (saving rewrites the whole file, and can change its format version and
  the paths stored in it);
- commit each stack change on its own and describe in the commit message
  which objects, properties or scripts changed and why;
- run the IDE compile check, which also compiles the object scripts
  inside binary stacks, and try the change in the installed layout
  (`dist\stage\OXT-Beyond-<ver>\OXT-Beyond.exe`) as well.

The "OpenXTalk Lite" text still inside some binary stacks is meant to be
changed this way, a few stacks at a time.

**Importing IDE files** from an installed OpenXTalk Lite (or LiveCode)
folder is done with [`tools/oxt/layout.py`](tools/oxt/README.md):
`classify` shows where each installed file belongs, `import` makes the
IDE files in `ide/` and `ide-support/` mirror the installed ones, and
`verify` checks the result. [HISTORY.md](HISTORY.md) describes how the
OpenXTalk Lite history was imported with it, and
[CONTRIBUTING.md](CONTRIBUTING.md#importing-from-other-projects) the
rules for new imports.

## 12. Building on Linux

The Linux engine is built by the workflow
[`.github/workflows/build-linux.yml`](.github/workflows/build-linux.yml)
in an `ubuntu:20.04` container, for x86_64 on `ubuntu-24.04` runners and
for arm64 on `ubuntu-24.04-arm`. Ubuntu 20.04 is the newest Ubuntu that
still ships Python 2.7, which gyp and `config.py` need, and its glibc
2.31 is the oldest the binaries need. These are the workflow's steps,
written for x86_64 (use `arm64` instead of `x86_64` for the other
build); they have been run in that container only, not on other
distributions or with other compilers.

1. **Tools** (as root in the container):

   ```sh
   apt-get update
   apt-get install -y --no-install-recommends \
     build-essential gcc g++ make perl bison flex gawk pkg-config \
     python2 python-is-python2 python3 openjdk-11-jdk-headless \
     git curl ca-certificates bzip2 xz-utils zip unzip file binutils \
     libx11-dev libxext-dev libxrender-dev libxft-dev libxinerama-dev \
     libxv-dev libxcursor-dev libfreetype6-dev libfontconfig1-dev \
     libexpat1-dev libgtk2.0-dev libpopt-dev liblcms2-dev
   ```

2. **Prebuilt libraries.** LiveCode's download server no longer serves
   the Linux ones, so they are built from the pinned sources in
   `prebuilt/versions` (the workflow keeps the result in the Actions
   cache): OpenSSL, curl, ICU and CEF (x86_64 only), then the Thirdparty
   set from `thirdparty/`:

   ```sh
   export MODE=release BUILDTYPE=Release PREBUILT_MAKE_JOBS="$(nproc)"
   cd prebuilt
   PREBUILT_BUILD_LIBS="openssl curl icu cef" ./build-libraries.sh linux x86_64
   ./package-libs.sh linux x86_64
   PREBUILT_LOCAL_DIR="$PWD/packaged" PREBUILT_SKIP_VERIFY=1 PREBUILT_LINUX_LIBS="OpenSSL Curl ICU CEF" \
     PREBUILT_BUILD_LIBS=thirdparty ./build-libraries.sh linux x86_64
   ./package-libs.sh linux x86_64
   PREBUILT_LOCAL_DIR="$PWD/packaged" PREBUILT_SKIP_VERIFY=1 ./fetch-libraries.sh linux x86_64
   cd ..
   ```

   (`PREBUILT_SKIP_VERIFY=1`: these tarballs were built here, so
   `prebuilt/SHA256SUMS`, which lists published files, has no entries
   for them.)

3. **Configure and build**, with the same `PREBUILT_LOCAL_DIR` and
   `PREBUILT_SKIP_VERIFY` in the environment. The second `make` copies
   the build products into `linux-x86_64-bin`; it runs on its own
   because its input folder is only created while the first one runs:

   ```sh
   export PREBUILT_LOCAL_DIR="$PWD/prebuilt/packaged" PREBUILT_SKIP_VERIFY=1
   make config-linux-x86_64
   make -C build-linux-x86_64/livecode LiveCode-all debug-symbols BUILDTYPE=Release -j"$(nproc)"
   make -C build-linux-x86_64/livecode default BUILDTYPE=Release -j"$(nproc)"
   ```

4. **Check.** The workflow checks that the expected files are in
   `linux-x86_64-bin`, that no ELF file needs more than glibc 2.31 and
   the libstdc++ of that system (`tools/ci/check_elf_floor.py`), that
   the server engine runs a script, and compiles the checkout's IDE with
   the new development engine:

   ```sh
   python3 tools/ci/check_elf_floor.py linux-x86_64-bin --machine x86_64 --exclude '*.dbg' \
     --max GLIBC=2.31 --max GLIBCXX=3.4.28 --max CXXABI=1.3.12 --max GCC=7.0.0
   python3 tools/ci/run_livecode_check.py compile --repo-layout --bin linux-x86_64-bin
   ```

   The development engine, `linux-x86_64-bin/LiveCode-Community`, finds
   the IDE of the clone as the Windows one does (repository mode); CI
   runs it that way only headless, for this check.

5. **Package** the x86_64 build as described in
   [Linux package](#linux-package): the workflow uploads
   `linux-x86_64-bin` as two tarballs (the `.dbg` debug files in the
   second; the build's own tools, GENTLE among them, in neither), and
   the job "Package linux-x86_64" makes the package from them on
   `ubuntu-24.04`, whose glibc and OpenSSL 3 load every bundled xTalk
   extension. Linux arm64 is built and checked, but not packaged.

## 13. Building on macOS

The macOS engine is built by the workflow
[`.github/workflows/build-macos.yml`](.github/workflows/build-macos.yml),
natively for each architecture: arm64 on `macos-15`, x86_64 on
`macos-15-intel`. The steps below are the workflow's, for one
architecture (`ARCH` is `arm64` or `x86_64`, the machine's own); they
have been run on those runners only.

1. **Tools:** Xcode 16.4 (`sudo xcode-select -s /Applications/Xcode_16.4.app`)
   with its macOS SDK; a JDK, for its headers only (`JAVA_SDK` names its
   home folder, which has `include/`); Python 2.7.18 first on `PATH` as
   `python` and `python2` (the workflow builds it with `pyenv install
   2.7.18` and links it into a folder of its own), for gyp and
   `config.py`; and Python 3 (the system's), for the checks and
   packaging.

2. **Prebuilt libraries**, built from the pinned sources as on Linux
   (OpenSSL and ICU, then the Thirdparty set; there is no CEF on macOS,
   where revBrowser and the browser widget use the system's WebKit):

   ```sh
   export ARCH=arm64 TARGET_ARCH=arm64 PREBUILT_MAC_ARCHS=arm64
   export XCODE_TARGET_SDK=macosx XCODE_HOST_SDK=macosx MODE=release BUILDTYPE=Release
   export PREBUILT_MAKE_JOBS="$(sysctl -n hw.ncpu)"
   cd prebuilt
   PREBUILT_BUILD_LIBS="openssl icu" ./build-libraries.sh mac universal
   ./package-libs.sh mac universal
   PREBUILT_LOCAL_DIR="$PWD/packaged" PREBUILT_SKIP_VERIFY=1 PREBUILT_MAC_LIBS="OpenSSL ICU" \
     PREBUILT_BUILD_LIBS=thirdparty ./build-libraries.sh mac universal
   ./package-libs.sh mac universal
   PREBUILT_LOCAL_DIR="$PWD/packaged" PREBUILT_SKIP_VERIFY=1 ./fetch-libraries.sh mac
   cd ..
   ```

   (`PREBUILT_MAC_ARCHS` limits the "universal" libraries to this
   machine's architecture.)

3. **Configure and build**, with `PREBUILT_LOCAL_DIR` and
   `PREBUILT_SKIP_VERIFY` set as above:

   ```sh
   export PREBUILT_LOCAL_DIR="$PWD/prebuilt/packaged" PREBUILT_SKIP_VERIFY=1
   ./config.sh --platform mac
   xcodebuild -project build-mac/livecode/livecode.xcodeproj -configuration Release \
     -target default -jobs "$(sysctl -n hw.ncpu)"
   ```

   The build products are in `_build/mac/Release`, with
   `LiveCode-Community.app` (the development engine) and
   `Standalone-Community.app`.

4. **Check.** The workflow checks the expected files, the architecture
   of the engines and that they link nothing outside the system, that
   every Mach-O file
   records macOS 11.0 (arm64) or 10.13 (x86_64) as its minimum and SDK
   11.0 (`tools/ci/check_macho_floor.py`), that the server engine runs a
   script, and compiles the checkout's IDE with the new development
   engine:

   ```sh
   python3 tools/ci/run_livecode_check.py compile --repo-layout --bin _build/mac/Release
   ```

5. **Package:** the workflow uploads `_build/mac/Release` as two
   tarballs (the `.dSYM` bundles in the second; static libraries and the
   build's own tools, GENTLE among them, in neither), and the job
   "Package mac-universal" joins the two architectures into one
   universal app, as described in [macOS app](#macos-app).
