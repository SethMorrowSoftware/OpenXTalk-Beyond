# OXT-Beyond

[![Build (Windows)](https://github.com/SethMorrowSoftware/winoxt/actions/workflows/build-windows.yml/badge.svg)](https://github.com/SethMorrowSoftware/winoxt/actions/workflows/build-windows.yml)

OXT-Beyond is a free, open source development environment for Windows in
which you build programs with an English-like scripting language in the
HyperCard/HyperTalk tradition ("xTalk"). You lay out stacks of cards with
buttons, fields and other controls, and write scripts that respond to
what the user does.

OXT-Beyond continues **OpenXTalk Lite**. OpenXTalk Lite was started by
**Terry Little** (TerryL) in September 2023 as a debranded LiveCode
Community 9.6.3, and was built and maintained by **Tom Perry**
(tperry2x) from version 0.91 (September 2023) to version 1.15 (June
2026), for macOS, Linux and Windows, with contributions from **Paul
McClernan** (OpenXTalkPaul) and other members of the
[OpenXTalk community](https://www.openxtalk.org). In August and
September 2026 Tom said that 1.15 is as far as he will take OpenXTalk
Lite on the LiveCode 9 engine, that his new OXTL7 (built on a LiveCode 7
engine) is meant to replace it, and that anyone may carry 1.15 on as
their own fork. OXT-Beyond is that continuation, on the 9.x engine,
starting with version 0.0.1. [HISTORY.md](HISTORY.md) tells the whole
story, version by version.

Like OpenXTalk Lite, OXT-Beyond is based on **LiveCode Community**, the
GPLv3 edition of LiveCode by LiveCode Ltd and its contributors. The
upstream LiveCode Community repositories have had no changes since July
2021 and are now archived (read-only).

This repository, **winoxt**, holds all of it: the engine source
(LiveCode Community 9.7 plus Tom Perry's 9.7.1-OXT engine work), the
OpenXTalk Lite 1.15 IDE with its history, and the scripts that build,
package and test OXT-Beyond for Windows. It is maintained by
[SethMorrowSoftware](https://github.com/SethMorrowSoftware).

## Status

OXT-Beyond 0.0.1 is the first release of a young project. Please read
this before you download it.

- **64-bit Windows only.** OXT-Beyond is built for Windows x86-64. There
  are no OXT-Beyond builds for 32-bit Windows, macOS or Linux. The code
  for those platforms is still in the tree, unmaintained.
- **Standalones for other platforms use prebuilt runtimes.** Only the
  Windows x86-64 engine, externals and tools are built from this
  repository. The standalone runtimes for 32-bit Windows, Linux and
  Android, and the time zone library code for the other platforms, are
  OpenXTalk Lite 1.15's files, unchanged: stock LiveCode 9.6.3 builds and
  files as Tom Perry shipped them, among them his 9.7.1-OXT Linux engine.
  They are published separately as a release asset
  (`oxt-runtimes-1.15.zip`) and added when OXT-Beyond is packaged. There
  are no macOS or iOS runtimes. The automatic tests do not build
  standalones.
- **Old third-party libraries.** The build uses the libraries LiveCode
  Community last shipped: OpenSSL 1.1.1g, curl 7.51.0, ICU 58.2 and CEF
  74 (Chromium 74). They are end of life and have known
  vulnerabilities. Upgrading them is planned. See [SECURITY.md](SECURITY.md).
- **Not code-signed.** Windows SmartScreen may warn about the installer
  and the program. Check downloads against `SHA256SUMS`.
- **The installer is new.** The Inno Setup installer first ships with
  0.0.1. CI installs and uninstalls it on every build, but it has had
  little use on real computers yet.
- **Branding is not finished.** The text parts of the IDE (window title,
  About text, menus and dialogs built by scripts) say OXT-Beyond, but
  some windows, dialogs and guides stored in binary stacks still say
  "OpenXTalk Lite"; they will be changed in a later release. The files in
  the build output folder are still named after LiveCode
  (`LiveCode-Community.exe`); packages and the installer rename the
  development engine to `OXT-Beyond.exe`.
- **Some OpenXTalk Lite files are not included.** OpenXTalk Lite shipped
  the mergExt externals (`Ext/`: blur, mergJSON, mergMarkdown,
  mergMicrophone), Apple's Human Interface Guidelines PDF and
  `animationEngine6.zip`. OXT-Beyond does not redistribute them; see
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#files-openxtalk-lite-shipped-that-oxt-beyond-does-not).
- **Mostly separate settings.** OXT-Beyond keeps its preferences, caches
  and logs in its own folders (`%APPDATA%\OXT-Beyond`,
  `%LOCALAPPDATA%\OXT-Beyond`) and does not copy LiveCode's or OpenXTalk
  Lite's settings: the first start uses default preferences. A few
  things are still shared with OpenXTalk Lite or LiveCode: dictionary
  favourites and notes, custom script editor colours, recent-stack
  thumbnails and the engine's licence file (see
  [Where OXT-Beyond keeps your files](#where-oxt-beyond-keeps-your-files)).
- **Tested automatically, but only in part.** Every CI build checks that
  the programs and libraries exist and are genuine x86-64 PE images with
  the expected versions, runs a headless smoke test of the engine in the
  portable zip and in an installed copy (the script engine, Unicode,
  OpenSSL, SQLite 3.51.1 through revDB, revXML and revZip), compiles
  every script of the IDE and compares the errors with a list of known
  ones, and installs and uninstalls the installer (see
  [BUILDING.md](BUILDING.md#7-run-check-and-package-the-result)). The
  IDE's windows are not tested automatically.
- **Mac and Linux parts of the IDE.** Tom Perry's IDE also contains
  parts for macOS and Linux only (for example the macOS ARM standalone
  builder). They are shipped as they were and are not maintained for
  Windows.
- **Legacy build toolchain.** Building needs the Visual Studio 2017 C++
  toolset (v141, installed through Visual Studio 2022), Python 2.7 and
  Cygwin. See [BUILDING.md](BUILDING.md).

## Download

Releases are published on the
[Releases page](https://github.com/SethMorrowSoftware/winoxt/releases).
Each release has:

| File | What it is |
| --- | --- |
| `OXT-Beyond-<version>-win-x86_64-setup.exe` | The installer. Use this unless you have a reason not to. |
| `OXT-Beyond-<version>-win-x86_64-portable.zip` | The same program folder without an installer. |
| `OXT-Beyond-<version>-win-x86_64-binaries.zip` | Only the built engine, externals and tools (`win-x86_64-bin`, without debug symbols) and the licence files, for use with a source checkout. |
| `OXT-Beyond-<version>-win-x86_64-symbols.zip` | Debug symbols (`.pdb`), for developers. |
| `SHA256SUMS` | SHA-256 checksums of the files above. |

Releases whose tags do not start with `v`, such as `prebuilts-v1` and
`runtimes-1.15`, are not programs. They hold files that the build and
the packager download: the prebuilt third-party libraries and the
standalone runtimes for other platforms.

**Latest development build.** Every successful run of the build workflow
uploads the same files as an artifact. Open the
[Build (Windows) workflow](https://github.com/SethMorrowSoftware/winoxt/actions/workflows/build-windows.yml),
pick a successful run and download `OXT-Beyond-win-x86_64` under
*Artifacts*. You need to be signed in to GitHub to download artifacts,
and they are deleted after 30 days. These builds pass the automatic
checks, but nobody has tried them by hand.

## Quick start

To check a download, compare its SHA-256 with the line for it in
`SHA256SUMS`, for example:

```bat
certutil -hashfile OXT-Beyond-0.0.1-win-x86_64-setup.exe SHA256
```

### With the installer

1. Run `OXT-Beyond-<version>-win-x86_64-setup.exe`.
2. Choose whether to install for all users (into `C:\Program Files\OXT-Beyond`;
   this needs administrator rights) or only for you (into
   `%LOCALAPPDATA%\Programs\OXT-Beyond`; no administrator rights needed).
3. Accept the licence (the GNU GPL version 3) and pick the options: a
   desktop shortcut, and whether `.oxtstack` and `.oxtscript` files should
   open with OXT-Beyond. OXT-Beyond does not take over `.livecode`,
   `.rev` or `.livecodescript` files: the installer does not associate
   them, and the IDE does not offer to (OpenXTalk Lite's "File
   Associations" dialog is not shown on Windows).
4. Start OXT-Beyond from the Start menu.

To remove it, use *Settings > Apps* or "Uninstall OXT-Beyond" in the
Start menu. The uninstaller removes the program but keeps your
preferences. Installing a newer version over an older one replaces it.

The installer is made with Inno Setup and accepts its usual
[command-line options](https://jrsoftware.org/ishelp/index.php?topic=setupcmdline),
for example `/CURRENTUSER /VERYSILENT` for a silent install for the
current user.

### Portable

1. Extract `OXT-Beyond-<version>-win-x86_64-portable.zip` somewhere you
   can write to, such as your Documents folder (not `C:\Program Files`):
   the dictionary writes its index files into the program folder. You
   get one folder, `OXT-Beyond-<version>`.
2. Run `OXT-Beyond.exe` inside that folder.

Keep the folders inside `OXT-Beyond-<version>` together; the program
finds the IDE, externals and runtimes by their places next to
`OXT-Beyond.exe`. The portable copy does not associate any file types
with itself; open stacks from the IDE, or with *Open with* in
Explorer.

### Where OXT-Beyond keeps your files

| What | Where |
| --- | --- |
| Preferences (`oxt-beyond7.rev`) | `%APPDATA%\OXT-Beyond\Preferences` |
| Cache, crash logs, documentation cache and IDE logs | `%LOCALAPPDATA%\OXT-Beyond\` (`Cache`, `Crash Logs`, `Documentation Cache`, `Logs`) |
| Script copies for an external script editor (if you turn that option on) | `%LOCALAPPDATA%\OXT-Beyond\Cache\IDEScriptEdits` |
| Your own extensions and plugins | `Documents\OXT-Beyond extensions`, unless you choose another folder in Preferences |

Installed and portable copies of OXT-Beyond on the same computer share
these folders. LiveCode (`%APPDATA%\RunRev`) and OpenXTalk Lite
(`%APPDATA%\xtalk`) keep their preferences elsewhere, so OXT-Beyond can
be installed next to them.

Some files are still kept in the same places as OpenXTalk Lite or
LiveCode, because binary stacks or the engine, which this release does
not change, read or write them there:

| What | Where | Shared with |
| --- | --- | --- |
| Dictionary favourites and notes | `%APPDATA%\xtalk\xTalkDictionary` | OpenXTalk Lite |
| Custom script editor colours | `%APPDATA%\xtalk\Preferences\customScriptColours.dat` | OpenXTalk Lite |
| Thumbnails of recent stacks | `Documents\OXTRecentStacks` | OpenXTalk Lite |
| The engine's Community licence file, written by the engine when it starts | `%APPDATA%\RunRev\Licenses\livecode-community-9_7_1-OXT-25923.lclk` | LiveCode's folder; OpenXTalk Lite 1.15 writes the same file (same engine version) |

A change made in one of these programs, such as a dictionary favourite,
shows up in the others. Moving them to OXT-Beyond's own folders is
planned (see [Known limitations and plans](#known-limitations-and-plans)).

### Updates

*Help > Check for Updates* asks GitHub for the latest OXT-Beyond release.
If it is newer than yours, OXT-Beyond shows an excerpt of its release
notes and a button that opens the release page in your browser; you
download and install the new version yourself. OXT-Beyond never
downloads or installs anything by itself and never asks for
administrator rights to update. An automatic check (at most once a day)
can be turned on in *Preferences > Automatic Updates*; it is off by
default. See [SECURITY.md](SECURITY.md#updates).

## What is in it

### The IDE

The IDE is OpenXTalk Lite 1.15's, with its history back to Terry Little's
first release (see [HISTORY.md](HISTORY.md)). Compared with the
LiveCode Community 9.6.3 IDE it started from, it has, among other
things:

- light and dark appearance (with the engine's Windows dark mode), dark
  icon sets for the tools palette, an orange accent colour, more script
  editor colour schemes and customisable script editor colours;
- a draggable menubar, a tools palette in sections (with more shapes,
  rebuilt paint tools and an optional eight-column layout) and many new
  keyboard shortcuts;
- `.oxtstack` and `.oxtscript` as the default file types (the
  `.livecode` and `.livecodescript` types still open);
- a stack-based dictionary with a plain-text export, favourites and
  notes, *Help > Dictionary Online*, the "All Guides" stack, Terry
  Little's User Guide and Data Grid Guide (PDF), lessons, examples and
  demo stacks (*Help > Demos*);
- the Quick Dictionary, Report Builder and App Browser plugins, Axwald's
  Message Watcher, a Card Navigator, *Edit > Replicate*, optional
  alignment guides while dragging objects, and tool snippets (sample
  scripts for new objects);
- preferences to switch off the data grid, the Player tool and the
  browser widget, a prompt to name new stacks, a gallery of recent
  stacks, lock/unlock of all objects and a "remove effects" command;
- the Calendar and Pie Chart widgets.

OXT-Beyond 0.0.1 adds:

- the OXT-Beyond name, About text and credits, splash screen and icon
  (adapted from Tom Perry's OpenXTalk Lite icon);
- its own preference, cache, log and extension folders (see above);
- an update check against this repository's GitHub Releases that only
  notifies (OpenXTalk Lite's own updater, which downloaded files from
  Tom Perry's servers and installed them with administrator rights, is
  no longer used);
- a Windows installer and a portable zip in the installed layout, with
  the standalone runtimes for other platforms.

### The engine

The engine is the LiveCode Community **9.7 development tree** (the
upstream `develop` branch as it was left in July 2021, version
9.7.0-dp-1), not the 9.6.3 release, plus Tom Perry's OpenXTalk Lite
engine changes for Windows (commit `38d5712b2`):

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
- **Version 9.7.1-OXT**, build 25923 (see the `version` file). The
  engine version is separate from the OXT-Beyond product version in
  `ide/.version`.

Changes made in this repository to build it: the `thirdparty` and `ide`
submodules are ordinary folders in the repository, the prebuilt
libraries that LiveCode's server no longer provides are mirrored in the
[`prebuilts-v1` release](https://github.com/SethMorrowSoftware/winoxt/releases/tag/prebuilts-v1),
the build scripts were updated for Visual Studio 2022 with the v141
toolset, and a GitHub Actions workflow builds, packages and tests it.

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
To make the installed layout, the zips and the installer, see
[Package](BUILDING.md#package) and [Installer](BUILDING.md#installer)
(they need Python 3 and Inno Setup 6).

## Repository layout

| Path | What it is |
| --- | --- |
| `engine/` | The engine: IDE ("development"), standalone, server and installer engines. |
| `libfoundation/`, `libgraphics/`, `libscript/`, `libcore/`, `libbrowser/`, `libexternal*/` | Libraries the engine is built from. |
| `rev*/` | Externals: database access (`revdb`), XML, zip, speech, PDF printing, browser and others. |
| `toolchain/` | The LiveCode Builder compiler (`lc-compile`) and runner (`lc-run`). |
| `extensions/` | Widgets and libraries written in LiveCode Builder, and script libraries. |
| `ide/` | The IDE: OpenXTalk Lite 1.15's IDE, with its history from Terry Little's .91 onwards (see [HISTORY.md](HISTORY.md)), and OXT-Beyond's changes. `ide/Extensions/` holds the extensions the IDE ships but this repository does not build. |
| `ide-support/` | Eleven IDE libraries kept in the engine repository (the standalone builder and others); they are installed into `Toolset/libraries`. |
| `docs/` | Dictionary, guides and release note fragments from LiveCode Community; development notes in `docs/development/`. |
| `thirdparty/` | Third-party library sources, vendored from `livecode/livecode-thirdparty`. |
| `prebuilt/` | Scripts that fetch the prebuilt third-party libraries (from the `prebuilts-v1` release), their versions and checksums. |
| `config/`, `gyp/`, `config.py`, `make.cmd` | Build configuration: gyp generates the Visual Studio projects. |
| `tools/oxt/` | Python tools that map an installed OpenXTalk Lite folder to the repository and back (`layout.py`), stage OXT-Beyond's installed layout (`package.py`) and fetch the external assets listed in `external-assets.json`. See [tools/oxt/README.md](tools/oxt/README.md). |
| `Installer/oxt-beyond/` | The Inno Setup script of the installer, the scripts that make its images, and the icon's source art. |
| `tools/ci/` | PowerShell scripts used by CI to install components, build, check, package, smoke-test, compile-check the IDE and build and test the installer. |
| `.github/workflows/` | The GitHub Actions workflow (`build-windows.yml`). |
| `Installer/package.txt`, `builder/` | LiveCode's packaging manifest (the packager follows its Windows rules) and LiveCode's installer builder (not used). |
| `tests/`, `engine/exec-tests/` and others | Upstream test suites. |

For a compatibility-first proposal to make the engine easier to test and
change, see the [engine stabilization and modernization plan](docs/development/engine-modernization-plan.md).

## Known limitations and plans

Known limitations, in rough order of importance:

1. Old third-party libraries with known vulnerabilities (OpenSSL 1.1.1g,
   curl 7.51.0, CEF/Chromium 74, ICU 58.2 and several older libraries in
   `thirdparty/`). Plan: rebuild the prebuilt libraries from newer
   sources.
2. The standalone runtimes for 32-bit Windows, Linux and Android are
   prebuilt binaries from OpenXTalk Lite 1.15, not built from this
   repository, and building standalones is not tested automatically.
3. The binaries are not code-signed.
4. "OpenXTalk Lite" still appears inside binary stacks, and the build
   output files are named after LiveCode. Plan: change the binary stacks
   one at a time, in reviewable commits, and rename the engine files.
5. Legacy toolchain (v141, Python 2.7, Cygwin). Plan: move to the current
   Visual Studio toolset and Python 3.
6. The mergExt externals are not included.
7. It has not been confirmed that Tom Perry and the other OpenXTalk Lite
   contributors offer their changes with LiveCode's permission to combine
   the code with OpenSSL and ATL (see
   [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md)).
8. Dictionary favourites and notes, custom script editor colours and
   recent-stack thumbnails are shared with OpenXTalk Lite, and the
   engine writes its licence file into LiveCode's `RunRev` folder (see
   [Where OXT-Beyond keeps your files](#where-oxt-beyond-keeps-your-files)).
   Plan: move them to OXT-Beyond's folders when the binary stacks are
   changed, and in the engine.
9. In an install for all users, a few things that save stacks inside
   the program folder fail for standard users, because Setup keeps
   stacks and scripts there read-only: the Report Builder plugin saving
   itself when it closes, *Plugin Settings* changes to the plugins that
   come with OXT-Beyond, and edits to the built-in image libraries. Install for the current user only,
   or use the portable zip, if you need them. Plan: keep that state in
   the user's own folders.

Also planned: extensions from the xTalk Suite repositories, taken from
their own repositories at pinned versions in the same way as the
runtimes (see [External assets](BUILDING.md#external-assets)).

Issues and pull requests for any of these are welcome.

## Getting help and reporting problems

- **Bugs and feature requests:**
  [GitHub issues](https://github.com/SethMorrowSoftware/winoxt/issues).
  There are forms for bugs, build problems and feature requests.
- **Security problems:** report them privately, as described in
  [SECURITY.md](SECURITY.md).
- **Questions and discussion about xTalk and OpenXTalk in general:** the
  [OpenXTalk forums](https://openxtalk.org/forum/).

Please report problems with OXT-Beyond here, not to Terry Little, Tom
Perry or LiveCode Ltd.

## Contributing

Contributions are welcome. There is no contributor licence agreement;
contributions are accepted under the same licence as the project. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## Credits

- **Terry Little** (TerryL) started OpenXTalk Lite in September 2023:
  the debranding of LiveCode Community 9.6.3, the App Browser, Quick
  Dictionary and Report Builder plugins, the User Guide and Data Grid
  Guide PDFs, lessons, examples and demo stacks, and IDE changes up to
  1.15.
- **Tom Perry** (tperry2x) built and maintained OpenXTalk Lite from 0.91
  to 1.15: most of the IDE changes, the packaged releases for macOS,
  Linux and Windows, and the 9.7.1-OXT engine work this repository is
  built on (for Windows: dark mode, `_internal respring`, the
  colourisation speed-ups, OneCore voices, Windows 11 detection and the
  SQLite update). The OXT-Beyond icon is adapted from his OpenXTalk Lite
  icon.
- **Paul McClernan** (OpenXTalkPaul) contributed `.oxtstack` support, the
  dark-mode hook, the alignment guides integration, the macOS Native
  Tools library and lessons.
- Other people credited in OpenXTalk Lite's history and code: Richmond
  (richmond62), Axwald (Message Watcher, App Browser fixes), Neville,
  overclockedmind, micmac, mwieder, MaxV (whose MaxDictionary is the
  basis of Quick Dictionary) and the FerrusLogic team (DevGuides).
- **SethMorrowSoftware** maintains OXT-Beyond.
- **LiveCode Ltd and the LiveCode Community contributors** wrote LiveCode
  Community, on which all of this is based
  ([livecode/livecode](https://github.com/livecode/livecode),
  [livecode/livecode-ide](https://github.com/livecode/livecode-ide),
  [livecode/livecode-thirdparty](https://github.com/livecode/livecode-thirdparty)).
- **The OpenXTalk community** at [openxtalk.org](https://www.openxtalk.org)
  keeps xTalk development going. OpenXTalk Lite's downloads and release
  notes are in Tom Perry's
  [downloads post](https://openxtalk.org/forum/viewtopic.php?t=590).
- The authors of the third-party libraries listed in
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Licence

OXT-Beyond is free software, licensed under the GNU General Public
License version 3 ([LICENSE](LICENSE)). The LiveCode Community code it
is based on also carries LiveCode Ltd's additional permission to combine
it with OpenSSL and Microsoft ATL, and contributions made under
[CONTRIBUTING.md](CONTRIBUTING.md) are offered with the same
permission. Whether Tom Perry's engine and IDE changes and the other
OpenXTalk Lite contributors' changes carry that permission has not been
confirmed yet; see [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md).

Some parts have their own terms. In particular, Tom Perry's OXT Lite
functions plugin (`community.openxtalk.plugin.oxtlite`) carries a
condition that it must not be used in any LiveCode product or in a fork
bearing the LiveCode product name. Third-party components keep their
own licences. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

The LiveCode Community engine, libraries and IDE are, unless otherwise
noted, Copyright © 2003-2019 LiveCode Ltd. Later changes are copyright
their authors.

## Trademarks

LiveCode is a trademark of LiveCode Ltd. This project is not affiliated
with, sponsored by or endorsed by LiveCode Ltd. The LiveCode name still
appears in some file names and parts of the programs only because they
have not been renamed yet.

OXT-Beyond is an independent continuation of OpenXTalk Lite. It is not
an official release of the OpenXTalk project at openxtalk.org or of
OpenXTalk Lite.
