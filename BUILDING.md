# Building OpenXTalk Lite for Windows

This guide builds OpenXTalk Lite for 64-bit Windows (x86_64) from source,
using the same tools and commands as the project's CI build. It is the
only supported build at the moment. The upstream LiveCode instructions
for other platforms are still in `docs/development/`, but they are not
maintained for this project.

The build needs a legacy toolchain: the Visual Studio 2017 C++ compiler
(toolset v141, installed as an optional part of Visual Studio 2022),
Python 2.7 and Cygwin. That is what the engine's build files and the
prebuilt third-party libraries were made for. Moving to current tools
is planned but has not been done yet.

What you get at the end is a `win-x86_64-bin` folder with the engines,
externals and tools, and an IDE you can run straight from your clone.
The files are still named after LiveCode (`LiveCode-Community.exe`);
rebranding is planned.

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

Allow several gigabytes of disk space. On an existing tree the clone
(files and Git history) took about 0.8 GB, the downloaded prebuilt
archives 0.3 GB, the unpacked prebuilt libraries 1.5 GB, the build
folder 3.5 GB and `win-x86_64-bin` 0.5 GB.

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
| `Microsoft.VisualStudio.Component.Windows11SDK.22621` | Windows SDK 10.0.22621.0 |

Another Windows 10 or 11 SDK can be used instead; see `WINSDK_VERSION`
in [section 5](#5-build). (As noted above, no complete build with a
Windows 10/11 SDK has been confirmed yet.)

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
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621
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
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621 ^
  --passive --norestart
```

You can also tick the same items in the Visual Studio Installer under
*Modify > Individual components*: "MSVC v143 - VS 2022 C++ x64/x86 build
tools (Latest)", "MSVC v141 - VS 2017 C++ x64/x86 build tools (v14.16)",
"C++ ATL for v141 build tools (x86 & x64)", "C++ MFC for v141 build
tools (x86 & x64)" and "Windows 11 SDK (10.0.22621.0)". The CI build uses
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
  ordinary folders in this repository, not submodules.
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
| `WINSDK_VERSION` | the SDK that `vcvarsall.bat` selected | Windows SDK version passed to MSBuild as `/p:WindowsTargetPlatformVersion`, for example `10.0.22621.0`. |
| `MSBUILD_EXTRA_ARGS` | empty | Extra arguments added to the end of the MSBuild command line, for example `/v:minimal`. |

For example, a Debug build against a particular SDK:

```bat
set BUILDTYPE=Debug
set WINSDK_VERSION=10.0.22621.0
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
| `OpenSSL-1.1.1g-...-PIC` | OpenSSL 1.1.1g |
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
complete checkout. The first launch takes longer because the IDE builds
its dictionary; it writes that into `ide\Documentation\html_viewer\resources\data`,
which is ignored by Git.

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

### Package

```bat
powershell -ExecutionPolicy Bypass -File tools\ci\package-windows.ps1
```

[`tools/ci/package-windows.ps1`](tools/ci/package-windows.ps1) writes to
`dist\` (`<ver>` is `BUILD_SHORT_VERSION` from the `version` file):

| File | Contents |
| --- | --- |
| `OpenXTalkLite-<ver>-win-x86_64-ide.zip` | A runnable IDE: one folder `OpenXTalkLite-<ver>-win-x86_64\` with `win-x86_64-bin` (without `.pdb` files), `ide`, `ide-support`, `extensions\script-libraries`, `docs`, the `*.lcb` sources the dictionary needs, the two Windows icons that "Save as Standalone" uses (`engine\rsrc\standalone.ico` and `document.ico`), the licence files and `README-FIRST.txt`. |
| `OpenXTalkLite-<ver>-win-x86_64-binaries.zip` | `win-x86_64-bin` without `.pdb` files, plus `LICENSE`, `LICENSE-EXCEPTION.md` and `THIRD-PARTY-NOTICES.md`. |
| `OpenXTalkLite-<ver>-win-x86_64-symbols.zip` | The `.pdb` debug symbols. |
| `SHA256SUMS` | Checksums of the three zips. |

The Windows installer (made upstream by the `builder/` scripts) is not
built yet.

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
`set WINSDK_VERSION=10.0.22621.0`. The installed versions are the folder
names in `C:\Program Files (x86)\Windows Kits\10\Include`.

**Compile errors in Windows SDK headers.** The only earlier build of
this code known to work (Tom Perry's) compiled against the Windows 8.1
SDK, so a newer SDK may expose problems that have not been seen before.
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
("Build (Windows)") builds OpenXTalk Lite on GitHub's `windows-2022`
runners. It runs on every push and pull request to `main`, on tags that
start with `v`, and when started by hand from the Actions tab.

It follows this guide: it adds the v141 components to the runner's
Visual Studio 2022 with `tools/ci/install-vs-components.ps1`, installs
Python 2.7 and Cygwin, fetches only the release prebuilt archives
(`PREBUILT_WIN32_SUBPLATFORMS=v141_static_release`, with
`PREBUILT_STRICT=1`, and cached between runs), configures and builds
Release x64 with `tools/ci/build-windows.ps1` and Windows SDK
10.0.22621.0, checks the result with `tools/ci/verify-build.ps1` and
packages it with `tools/ci/package-windows.ps1`. It uploads two
artifacts:

- `OpenXTalkLite-win-x86_64`: when the build succeeds, the contents of `dist\`, kept for 30 days;
- `build-logs`: `msbuild.log` and the installer logs, kept for 14 days
  and uploaded even when the build fails.

Downloading artifacts requires a GitHub account. Public downloads are
Releases.

At the time of writing the workflow has not completed a run yet; see the
[Actions tab](https://github.com/SethMorrowSoftware/winoxt/actions/workflows/build-windows.yml)
for its current state.

## 10. Making a release

Releases are built by CI from a tag.

1. Update the `version` file in the repository root. Increase
   `BUILD_REVISION`, and set `BUILD_MAJOR_VERSION`,
   `BUILD_MINOR_VERSION`, `BUILD_POINT_VERSION`, `BUILD_SHORT_VERSION`
   (used in file names, for example `9.7.1-OXT`) and
   `BUILD_LONG_VERSION` to match.
2. Merge that change into `main` through a pull request and wait for the
   build to pass.
3. Tag the merged commit with `v` followed by `BUILD_SHORT_VERSION`, and
   push the tag:

   ```bat
   git checkout main
   git pull
   git tag -a v9.7.1-OXT -m "OpenXTalk Lite 9.7.1-OXT"
   git push origin v9.7.1-OXT
   ```

4. The workflow builds the tag and a release job publishes the files
   from `dist\` (the three zips and `SHA256SUMS`) to a GitHub Release with
   generated release notes. Tags containing `-alpha`, `-beta`, `-rc`,
   `-dp` or `-pre` become pre-releases. The job warns if the tag does not
   match `BUILD_SHORT_VERSION`. Edit the notes afterwards if needed: say
   what changed and repeat the known limitations from the README.

GitHub also attaches source code archives of the tagged commit to the
release. They include `ide/` and `thirdparty/`, which are part of this
repository.

If only the release job fails (for example a network problem), re-run
it from the Actions tab; it replaces the files of an existing release.
If the build itself fails, fix the problem on `main` and tag a new
version rather than moving an existing tag.
