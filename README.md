# OpenXTalk Lite for Windows

[![Build (Windows)](https://github.com/SethMorrowSoftware/winoxt/actions/workflows/build-windows.yml/badge.svg)](https://github.com/SethMorrowSoftware/winoxt/actions/workflows/build-windows.yml)

OpenXTalk Lite is Tom Perry's lightweight edition of OpenXTalk: a free,
open source, cross-platform development environment for building
programs with an English-like scripting language in the
HyperCard/HyperTalk tradition ("xTalk"). You lay out stacks of cards with
buttons, fields and other controls, and write scripts that respond to
what the user does. Tom's releases on the OpenXTalk forums ran on macOS
and Windows; this repository covers Windows only (see below).

It is based on **LiveCode Community**, the GPLv3 edition of LiveCode by
LiveCode Ltd and its contributors. The upstream LiveCode Community
repositories have had no changes since July 2021 and are now archived
(read-only).

This repository, **winoxt**, is the Windows (x86_64) build of OpenXTalk
Lite. It continues the OpenXTalk Lite engine work of **Tom Perry**
(tperry2x on the [OpenXTalk forums](https://openxtalk.org/forum/)) and is
maintained by [SethMorrowSoftware](https://github.com/SethMorrowSoftware).

## Status

This is an early, work-in-progress repository. Please read this before
you download anything.

- **Windows x86_64 only.** There is no 32-bit Windows build (no 32-bit
  prebuilt libraries are available: LiveCode's server no longer serves
  them, and the `prebuilts-v1` mirror has only x86_64), and this
  repository does not build
  for macOS, Linux, Android, iOS or HTML5. The code for those platforms
  is still in the tree, unmaintained.
- **No release yet.** No release has been published. The first releases
  will be a zip file with an IDE you can run without installing; the
  Windows installer is not built yet.
- **Tested automatically, but only lightly.** Every CI build checks that
  the programs and libraries exist, are genuine x86-64 PE images and
  contain the expected project and SQLite versions, and then runs a
  headless smoke test of the engine in the packaged IDE zip: the script
  engine, Unicode (ICU), encryption (OpenSSL), SQLite 3.51.1 through
  revDB, revXML and revZip (see [BUILDING.md](BUILDING.md#smoke-test)).
  The IDE's windows are not tested automatically. A CI-built IDE zip was
  started by hand on Windows 11 and opened normally, in dark mode, and
  built its dictionary, but it has not had wider use yet.
- **Still branded LiveCode.** The programs are still called
  `LiveCode-Community.exe` and so on, and the IDE still shows LiveCode
  names and logos. Rebranding is planned.
- **The IDE is the stock LiveCode Community IDE.** `ide/` is the
  LiveCode Community IDE from the 9.6.3 era (upstream `livecode-ide`
  commit `ccc733a1`, a few commits after 9.6.3), unchanged. Tom
  Perry's OpenXTalk Lite releases on the forum (up to 1.12) shipped their
  own IDE changes; those are not in this repository yet.
- **Old third-party libraries.** The build uses the libraries LiveCode
  Community last shipped: OpenSSL 1.1.1g, curl 7.51.0, ICU 58.2 and CEF
  74 (Chromium 74). They are end of life and have known vulnerabilities.
  Upgrading them is planned. See [SECURITY.md](SECURITY.md).
- **Legacy build toolchain.** Building needs the Visual Studio 2017 C++
  toolset (v141, installed through Visual Studio 2022), Python 2.7 and
  Cygwin. See [BUILDING.md](BUILDING.md).

## Download

Releases will be published on the
[Releases page](https://github.com/SethMorrowSoftware/winoxt/releases).
Each release will have:

- `OpenXTalkLite-<version>-win-x86_64-ide.zip`: the IDE, ready to run;
- `OpenXTalkLite-<version>-win-x86_64-binaries.zip`: just the built
  programs (`win-x86_64-bin`) and the licence files, for use with a
  source checkout;
- `OpenXTalkLite-<version>-win-x86_64-symbols.zip`: debug symbols
  (`.pdb`), for developers;
- `SHA256SUMS`: checksums of the files above.

The `prebuilts-v1` release on that page is not a program. It holds the
third-party libraries that the build downloads.

**Latest development build.** Every successful run of the build
workflow uploads the same files as an artifact. Open the
[Build (Windows) workflow](https://github.com/SethMorrowSoftware/winoxt/actions/workflows/build-windows.yml),
pick a successful run and download `OpenXTalkLite-win-x86_64` under
*Artifacts*. You need to be signed in to GitHub to download artifacts,
and they are deleted after 30 days. These builds are untested.

## Quick start

1. Download `OpenXTalkLite-<version>-win-x86_64-ide.zip`. If you want to
   check it, compare its SHA-256 with `SHA256SUMS`:
   `certutil -hashfile OpenXTalkLite-<version>-win-x86_64-ide.zip SHA256`
2. Extract it somewhere you can write to, such as your Documents folder
   (not `C:\Program Files`): the IDE writes its dictionary into its own
   folder. You get one folder, `OpenXTalkLite-<version>-win-x86_64`.
3. Run `win-x86_64-bin\LiveCode-Community.exe` inside that folder.

The programs are not code-signed, so Windows SmartScreen may warn you
the first time. The first launch also takes longer than later ones,
because the IDE builds its dictionary.

Do not rename, move or split up the folders inside
`OpenXTalkLite-<version>-win-x86_64`, in particular `win-x86_64-bin` and
`ide`. The program finds the IDE by looking for a folder called
`win-x86_64-bin` in its own path and loading the `ide` folder next to it.

Preferences are kept in the same place and file as LiveCode's
(`%APPDATA%\RunRev\Preferences\livecode7.rev`), and the IDE rewrites that
file when it starts. An installed copy of LiveCode Community or of an
earlier OpenXTalk Lite release on the same computer therefore shares
these settings with it.

## What is different from LiveCode Community

The engine is the LiveCode Community **9.7 development tree** (the
upstream `develop` branch as it was left in July 2021, version
9.7.0-dp-1), not the 9.6.3 release, plus Tom Perry's changes from commit
`38d5712b2`:

- **Windows dark mode.** The engine follows the Windows light/dark
  setting: dark window title bars, system colours that update when the
  theme changes (with a `systemAppearanceChanged` message and a redraw of
  open stacks), and dark-mode aware checkmarks and cascade arrows.
- **Windows 11 detection.** The engine reports Windows 11 correctly.
- **`_internal respring`.** A development-engine command that restarts
  the IDE in place: it closes all stacks and reloads the home stack.
- **Faster script editor colourisation.** Colours and styles are set in
  one pass, and comment nesting is cached.
- **OneCore voices.** revSpeech (text to speech) lists the Windows
  OneCore voices.
- **No first-run licence dialog** in the development environment.
- **SQLite 3.51.1** (was 3.34.0) for the SQLite database driver.
- **Version 9.7.1-OXT** (see the `version` file).

Changes made in this repository since then: the `thirdparty` and `ide`
submodules are now ordinary folders in the repository, the prebuilt
libraries that LiveCode's server no longer provides are mirrored in the
[`prebuilts-v1` release](https://github.com/SethMorrowSoftware/winoxt/releases/tag/prebuilts-v1),
the build scripts were updated for Visual Studio 2022 with the v141
toolset, and a GitHub Actions workflow was added to build and package
it.

## Building from source

See [BUILDING.md](BUILDING.md). In short: install Visual Studio 2022 with
the v141 toolset, Python 2.7, Strawberry Perl, Git and Cygwin, then

```bat
git clone --recurse-submodules https://github.com/SethMorrowSoftware/winoxt.git C:\src\winoxt
cd /d C:\src\winoxt
set PATH=C:\Python27;%PATH%
C:\Python27\python.exe config.py --platform win-x86_64
cd build-win-x86_64
cmd /c ..\make.cmd
```

and run `win-x86_64-bin\LiveCode-Community.exe` from the repository.

## Repository layout

| Path | What it is |
| --- | --- |
| `engine/` | The engine: IDE ("development"), standalone, server and installer engines. |
| `libfoundation/`, `libgraphics/`, `libscript/`, `libcore/`, `libbrowser/`, `libexternal*/` | Libraries the engine is built from. |
| `rev*/` | Externals: database access (`revdb`), XML, zip, speech, PDF printing, browser and others. |
| `toolchain/` | The LiveCode Builder compiler (`lc-compile`) and runner (`lc-run`). |
| `extensions/` | Widgets and libraries written in LiveCode Builder, and script libraries. |
| `ide/` | The IDE (LiveCode Community 9.6.3-era), vendored from `livecode/livecode-ide`. |
| `ide-support/` | IDE support scripts kept in the engine repository. |
| `docs/` | Dictionary, guides and release note fragments used by the IDE; development notes in `docs/development/`. |
| `thirdparty/` | Third-party library sources, vendored from `livecode/livecode-thirdparty`. |
| `prebuilt/` | Scripts that fetch the prebuilt third-party libraries (from the `prebuilts-v1` release), their versions and checksums. |
| `config/`, `gyp/`, `config.py`, `make.cmd` | Build configuration: gyp generates the Visual Studio projects. |
| `tools/ci/` | PowerShell scripts used by CI to install components, build, check and package. |
| `.github/workflows/` | The GitHub Actions workflow (`build-windows.yml`). |
| `builder/`, `Installer/` | Upstream installer and packaging scripts; not used for Windows builds yet. |
| `tests/`, `engine/exec-tests/` and others | Upstream test suites. |

For a compatibility-first proposal to make the engine easier to test and
change, see the [engine stabilization and modernization plan](docs/development/engine-modernization-plan.md).

## Known limitations and plans

Known limitations, in rough order of importance:

1. Old third-party libraries with known vulnerabilities (OpenSSL 1.1.1g,
   curl 7.51.0, CEF/Chromium 74, ICU 58.2 and several older libraries in
   `thirdparty/`). Plan: rebuild the prebuilt libraries from newer
   sources.
2. LiveCode names and logos in the programs and the IDE. Plan: rebrand
   as OpenXTalk Lite.
3. No Windows installer; releases are a zip with a runnable IDE. Plan:
   make the `builder/` scripts work on Windows.
4. Legacy toolchain (v141, Python 2.7, Cygwin). Plan: move to the current
   Visual Studio toolset and Python 3.
5. Only x86_64 runtimes are built, so standalone applications can only be
   built for 64-bit Windows. Building standalones has not been tested yet
   with the zip layout.
6. Preferences and other per-user files are shared with LiveCode
   (`%APPDATA%\RunRev`).
7. The IDE changes from Tom Perry's forum releases are not in this
   repository yet.

Issues and pull requests for any of these are welcome.

## Getting help and reporting problems

- **Bugs and feature requests:**
  [GitHub issues](https://github.com/SethMorrowSoftware/winoxt/issues).
  There are forms for bugs, build problems and feature requests.
- **Security problems:** report them privately, as described in
  [SECURITY.md](SECURITY.md).
- **Questions and discussion about xTalk and OpenXTalk in general:** the
  [OpenXTalk forums](https://openxtalk.org/forum/).

Please do not send problems with this project to LiveCode Ltd.

## Contributing

Contributions are welcome. There is no contributor licence agreement;
contributions are accepted under the same licence as the project. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## Credits

- **Tom Perry** (tperry2x) created and maintained OpenXTalk Lite on the
  OpenXTalk forums, and wrote the Windows engine work this repository is
  built on: dark mode, `_internal respring`, the colourisation speed-ups,
  OneCore voices, Windows 11 detection and the SQLite update.
- **SethMorrowSoftware** maintains this repository and continues the
  work.
- **LiveCode Ltd and the LiveCode Community contributors** wrote LiveCode
  Community, on which all of this is based
  ([livecode/livecode](https://github.com/livecode/livecode),
  [livecode/livecode-ide](https://github.com/livecode/livecode-ide),
  [livecode/livecode-thirdparty](https://github.com/livecode/livecode-thirdparty)).
- **The OpenXTalk community** at [openxtalk.org](https://openxtalk.org)
  keeps xTalk development going. Background on OpenXTalk Lite:
  [OpenXTalk Lite Moving Forward](https://openxtalk.org/forum/viewtopic.php?t=1452)
  and
  [Download OXT Lite 1.12 Update](https://openxtalk.org/forum/viewtopic.php?t=1471).
- The authors of the third-party libraries listed in
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Licence

OpenXTalk Lite is free software, licensed under the GNU General Public
License version 3 ([LICENSE](LICENSE)). The LiveCode Community code it
is based on also carries LiveCode Ltd's additional permission to combine
it with OpenSSL and Microsoft ATL, and contributions made under
[CONTRIBUTING.md](CONTRIBUTING.md) are offered with the same
permission. Whether Tom Perry's changes carry that permission has not
been confirmed yet; see [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md).
Third-party components keep their own licences; see
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

The LiveCode Community engine, libraries and IDE are, unless otherwise
noted, Copyright © 2003-2019 LiveCode Ltd. Later changes are copyright
their authors.

## Trademarks

LiveCode is a trademark of LiveCode Ltd. This project is not affiliated
with, sponsored by or endorsed by LiveCode Ltd. The LiveCode name still
appears in the programs only because they have not been rebranded yet.
This project is also not an official release of the OpenXTalk project at
openxtalk.org.
