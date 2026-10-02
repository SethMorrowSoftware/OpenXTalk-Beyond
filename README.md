# OXT-Beyond

[![Build (Windows)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-windows.yml/badge.svg)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-windows.yml)
[![Build (macOS)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-macos.yml/badge.svg)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-macos.yml)
[![Build (Linux)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-linux.yml/badge.svg)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-linux.yml)

OXT-Beyond is a free, open source development environment for Windows,
macOS and Linux in which you build programs with an English-like
scripting language in the HyperCard/HyperTalk tradition ("xTalk"). You
lay out stacks of cards with buttons, fields and other controls, and
write scripts that respond to what the user does.

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
starting with version 0.0.1. [HISTORY.md](HISTORY.md) tells the story
up to OXT-Beyond 0.0.1, version by version; the notes of each release
since are on the
[Releases page](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases).

Like OpenXTalk Lite, OXT-Beyond is based on **LiveCode Community**, the
GPLv3 edition of LiveCode by LiveCode Ltd and its contributors. The
upstream LiveCode Community repositories have had no changes since July
2021 and are now archived (read-only).

This repository, **OpenXTalk-Beyond** (called winoxt until October
2026), holds all of it: the engine source (LiveCode Community 9.7 plus
Tom Perry's 9.7.1-OXT engine work), the OpenXTalk Lite 1.15 IDE with
its history, and the scripts that build, package and test OXT-Beyond
for Windows, macOS and Linux. It is maintained by
[SethMorrowSoftware](https://github.com/SethMorrowSoftware). GitHub
forwards the old name's addresses, so existing clones and links keep
working; `git remote set-url origin
https://github.com/SethMorrowSoftware/OpenXTalk-Beyond.git` points a
clone at the new one.

## Status

OXT-Beyond 0.2.0 is an early release of a young project, for Windows,
macOS and Linux. 0.2.1-rc.1, the first release candidate of 0.2.1, is a
pre-release for testing (see what 0.2.1 adds, under
[The IDE](#the-ide)). Please read this before you download either.

- **Windows, macOS and Linux.** From 0.1.0 on, every release has
  packages for 64-bit Windows, for macOS (one universal app for Apple
  Silicon and Intel Macs, see [macOS](#macos)) and for 64-bit x86 Linux
  (see [Linux](#linux-x86-64)), made and tested together from one tag
  (0.0.1 and 0.0.2 were for Windows only). Linux arm64 is built in CI
  but not packaged. There are no builds for 32-bit Windows.
- **Standalones for other platforms use prebuilt runtimes.** Each
  package's engine, externals and tools, and the standalone runtime for
  its own platform, are built from this repository: Windows x86-64,
  macOS (Apple Silicon and Intel) and Linux x86-64. The standalone
  runtimes for 32-bit Windows, 32-bit Linux and Android (and, in the
  Windows and macOS packages, 64-bit Linux), and the time zone library
  code for the other platforms, are OpenXTalk Lite 1.15's files,
  unchanged: stock LiveCode 9.6.3 builds and files as Tom Perry shipped
  them, among them his 9.7.1-OXT Linux engine. They are published
  separately as a release asset (`oxt-runtimes-1.15.zip`) and added when
  OXT-Beyond is packaged. Only the Windows package has the Windows
  x86-64 runtime, and only the macOS package the macOS runtimes. There
  are no iOS runtimes. Of the automatic tests, only the macOS ones build
  a standalone (a Mac one).
- **Old third-party libraries.** The build uses the libraries LiveCode
  Community last shipped: OpenSSL 1.1.1 (1.1.1g on Windows, 1.1.1w on
  Linux and macOS), curl 7.51.0, ICU 58.2 and CEF
  74 (Chromium 74). They are end of life and have known
  vulnerabilities. Upgrading them is planned. See [SECURITY.md](SECURITY.md).
- **Not code-signed or notarized.** On Windows, SmartScreen may warn
  about the installer and the program. The macOS app is signed ad hoc,
  not with an Apple Developer ID, and not notarized, so macOS blocks it
  until you allow it once (see [macOS](#macos)). Check downloads against
  `SHA256SUMS`.
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
- **Tested automatically, but only in part.** Every Windows CI build
  checks that the programs and libraries exist and are genuine x86-64 PE
  images with the expected versions, runs a headless smoke test of the
  engine in the portable zip and in an installed copy (the script engine,
  Unicode, OpenSSL, SQLite 3.51.1 through revDB, revXML and revZip), compiles
  every script of the IDE and compares the errors with a list of known
  ones, and installs and uninstalls the installer (see
  [BUILDING.md](BUILDING.md#7-run-check-and-package-the-result)). The
  macOS and Linux packages get the same smoke test (with every bundled
  xTalk Suite extension) and IDE compile check on their own systems,
  from the disk image on an Apple Silicon and an Intel Mac and from the
  extracted tarball on Ubuntu 24.04, plus a signature check and one Mac
  standalone built and run (macOS), and library checks and the install
  scripts (Linux). Every build on all three platforms also runs the
  engine tests that LiveCode Community keeps in `tests/` (about 1,150:
  LiveCode Script, LiveCode Builder, the LiveCode Builder compiler and
  the script parser)
  and compares the failures with a list of known ones (see
  [BUILDING.md](BUILDING.md#engine-tests)). On Windows, CI also lints the
  IDE sources, checks the contrast of the IDE's colours in the light and
  dark appearance, and renders test stacks in the light and dark
  appearance on a dark and a light Windows; on macOS it checks the
  appearance on a dark and a light Mac (see
  [Continuous integration](BUILDING.md#9-continuous-integration)). The
  IDE's windows are not tested automatically, and the macOS and Linux
  packages have not been tried by hand yet.
- **Mac and Linux parts of the IDE.** Tom Perry's IDE also contains
  parts for macOS and Linux only. They are shipped as they were; apart
  from the IDE compile check they are not tested automatically.
- **Legacy build toolchain.** Building on Windows needs the Visual
  Studio 2017 C++ toolset (v141, installed through Visual Studio 2022),
  Python 2.7 and Cygwin; the Linux build runs in an Ubuntu 20.04
  container and the macOS build uses Xcode 16.4, both with Python 2.7.
  See [BUILDING.md](BUILDING.md).

## Download

Releases are published on the
[Releases page](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases).
From 0.1.0 on, each release has these files for all three platforms
(0.0.1 and 0.0.2 have the Windows files only); `<version>` is the
version, for example `0.1.0`:

| Platform | File | What it is |
| --- | --- | --- |
| Windows 10 or later, 64-bit (x64) | `OXT-Beyond-<version>-win-x86_64-setup.exe` | The installer. Use this unless you have a reason not to. |
| | `OXT-Beyond-<version>-win-x86_64-portable.zip` | The same program folder without an installer. |
| | `OXT-Beyond-<version>-win-x86_64-binaries.zip` | Only the built engine, externals and tools (`win-x86_64-bin`, without debug symbols) and the licence files, for use with a source checkout. |
| | `OXT-Beyond-<version>-win-x86_64-symbols.zip` | Debug symbols (`.pdb`), for developers. |
| macOS 11 or later on Apple Silicon, 10.13 or later on Intel | `OXT-Beyond-<version>-mac-universal.dmg` | A disk image with `OXT-Beyond.app`, one app for Apple Silicon and Intel Macs, to drag to Applications (see [macOS](#macos)). |
| | `OXT-Beyond-<version>-mac-universal.zip` | The same app, for scripted installs. |
| | `OXT-Beyond-<version>-mac-universal-binaries.tar.xz` | Only the built engine, externals and tools (`Release/`, both architectures joined), without debug symbols and the build's own tools, and the licence files. |
| | `OXT-Beyond-<version>-mac-universal-symbols.zip` | Debug symbols (`.dSYM`), for developers. |
| Linux x86-64 with glibc 2.31 or later | `OXT-Beyond-<version>-linux-x86_64.tar.xz` | The program folder, with a launcher and `install.sh` for a per-user install (see [Linux](#linux-x86-64)). |
| | `OXT-Beyond-<version>-linux-x86_64-binaries.tar.xz` | Only the built engine, externals and tools (`linux-x86_64-bin`), without debug symbols and the build's own tools, and the licence files. |
| | `OXT-Beyond-<version>-linux-x86_64-symbols.tar.xz` | Debug symbols (`.dbg`), for developers. |
| All | `OXT-Beyond-<version>-xtalk-sources.zip` | Every file of the bundled xTalk Suite extensions as the release took it from their repositories, so that it can be rebuilt without them. |
| All | `SHA256SUMS` | SHA-256 checksums of all the files above. |

Some bundled xTalk Suite extensions need a newer system than the IDE:
macOS 15 on a Mac, and on Linux glibc 2.33 (SodiumXT) or glibc 2.38 and
OpenSSL 3 (DataChannelXT); see [macOS](#macos) and
[Linux](#linux-x86-64). The release notes list each platform's
requirements too.

Releases whose tags do not start with `v`, such as `prebuilts-v1` and
`runtimes-1.15`, are not programs. They hold files that the build and
the packager download: the prebuilt third-party libraries and the
standalone runtimes for other platforms.

**Latest development build.** Every successful run of a build workflow
uploads the same files as an artifact: open the workflow, pick a
successful run and download the artifact under *Artifacts*.

| Platform | Workflow | Artifact |
| --- | --- | --- |
| Windows | [Build (Windows)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-windows.yml) | `OXT-Beyond-win-x86_64` |
| macOS | [Build (macOS)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-macos.yml) | `OXT-Beyond-mac-universal` |
| Linux | [Build (Linux)](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-linux.yml) | `OXT-Beyond-linux-x86_64` |

You need to be signed in to GitHub to download artifacts, and they are
deleted after 30 days. These builds pass the automatic checks, but
nobody has tried them by hand. They have no xTalk sources zip, and
their build number is the time they were built.

## Quick start

On Windows, use the installer or the portable zip (below). For macOS and
Linux, see [macOS](#macos) and [Linux](#linux-x86-64).

To check a download, compare its SHA-256 with the line for it in
`SHA256SUMS`. On Windows, in Command Prompt, for example:

```bat
certutil -hashfile OXT-Beyond-<version>-win-x86_64-setup.exe SHA256
```

On macOS, in Terminal, compare the output of

```sh
shasum -a 256 OXT-Beyond-<version>-mac-universal.dmg
```

with its line. On Linux, in the folder with the download and
`SHA256SUMS`, this checks every file of the list that is there:

```sh
sha256sum -c SHA256SUMS --ignore-missing
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

### macOS

OXT-Beyond for macOS is one universal app, `OXT-Beyond.app`, for Apple
Silicon and Intel Macs, in `OXT-Beyond-<version>-mac-universal.dmg` (a
disk image) and `OXT-Beyond-<version>-mac-universal.zip` (the same app,
for scripted installs). Releases carry them from 0.1.0 on (see
[Download](#download)); the latest development build is the artifact
`OXT-Beyond-mac-universal` of a successful run of the
[Build (macOS) workflow](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-macos.yml).

**Requirements.** The IDE runs on macOS 10.13 High Sierra or later on an
Intel Mac and macOS 11 Big Sur or later on Apple Silicon. The bundled
xTalk Suite extensions (SodiumXT, TorrentXT, enetxt, DataChannelXT,
Box2Dxt and CoinXT, whose native libraries are built for macOS 15) need
macOS 15 Sequoia or later: on older macOS the IDE starts, but those
extensions do not load.

**Install.**

1. Check the download if you like: in Terminal, compare the output of
   `shasum -a 256 OXT-Beyond-<version>-mac-universal.dmg` with the line
   for that file in `SHA256SUMS`.
2. Open `OXT-Beyond-<version>-mac-universal.dmg` and drag
   **OXT-Beyond** onto the **Applications** folder next to it. Eject the
   disk image. (From the zip: double-click it, or run
   `ditto -x -k OXT-Beyond-<version>-mac-universal.zip /Applications`.)
3. Start OXT-Beyond from Applications. The first time, macOS blocks it.

**Opening it for the first time (Gatekeeper).** OXT-Beyond is signed
*ad hoc*: it is not signed with an Apple Developer ID and not notarized
by Apple, so macOS will not open a downloaded copy until you allow it.
You do this once. On macOS 15 Sequoia and later:

1. Double-click OXT-Beyond. macOS says that it was not opened, because
   Apple could not verify it is free of malware. Click **Done** (not
   *Move to Trash*).
2. Open **System Settings > Privacy & Security** and scroll down to
   *Security*. Next to "OXT-Beyond was blocked to protect your Mac",
   click **Open Anyway**.
3. Confirm with **Open Anyway** and your password (or Touch ID).

macOS 15 no longer offers *Open* when you Control-click the app, so use
these steps (on macOS 13 and 14, Control-click the app in Finder, choose
*Open* and then *Open* again; on macOS 12 and earlier, the button is in
*System Preferences > Security & Privacy > General*). Or, in Terminal,
remove the quarantine flag that the browser set on the download:

```sh
xattr -dr com.apple.quarantine /Applications/OXT-Beyond.app
```

The same command helps if macOS says the app "is damaged and can't be
opened": that is how some macOS versions report an app that is not
notarized. After this, OXT-Beyond opens like any other app. It opens
`.oxtstack` and `.oxtscript` files; LiveCode's `.livecode`, `.rev` and
`.livecodescript` files it opens too, but it does not take them over from
an installed LiveCode.

To remove OXT-Beyond, move `OXT-Beyond.app` to the Trash.

**Limitations on macOS** (besides those
[for every platform](#known-limitations-and-plans)):

- The app is ad hoc signed and not notarized, hence the steps above.
  Developer ID signing and notarization are planned.
- The IDE still writes a few files into its own program folder (the
  dictionary's index files), which on macOS is inside `OXT-Beyond.app`,
  after the app was signed. Moving them to your user folders is planned.
- Mac standalones: the standalone builder's Intel target builds x86_64
  apps; its Apple Silicon target (*MacOS-IntelArmUniversal* in the
  standalone settings) builds arm64-only apps and needs macOS 14 Sonoma
  or later on the Mac that builds them. Universal standalones are
  planned. Standalones run on macOS 10.13 or later (Intel) and 11 or
  later (Apple Silicon); one that includes an xTalk Suite extension needs
  macOS 15.
- The macOS package does not include the Visual C++ runtime DLLs that
  the Windows packages put next to enetxt and Box2Dxt: a Windows
  standalone built on a Mac with either of them needs the Visual C++
  Redistributable on the PC it runs on. It has no Windows x86-64
  standalone runtime either.
- The macOS packages are built and tested automatically (on macOS 15, on
  both an Apple Silicon and an Intel runner) but have not been tried by
  hand yet.

### Linux (x86-64)

The Linux package is `OXT-Beyond-<version>-linux-x86_64.tar.xz`.
Releases carry it from 0.1.0 on (see [Download](#download)). It is also
built and tested by every run of the
[Build (Linux) workflow](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/actions/workflows/build-linux.yml)
(artifact `OXT-Beyond-linux-x86_64`, with the binaries and symbols
tarballs and `SHA256SUMS`). Check it with
`sha256sum -c SHA256SUMS --ignore-missing`.

What it needs:

- **64-bit x86 Linux with glibc 2.31 or newer** (Ubuntu 20.04, Debian 11,
  Fedora 32 or later) and an X11 desktop; on Wayland it runs through
  XWayland, which the usual desktops start by themselves. The IDE uses
  GTK 2, as LiveCode and OpenXTalk Lite did: on Debian and Ubuntu
  `sudo apt install libgtk2.0-0` (`libgtk2.0-0t64` on Ubuntu 24.04 and
  Debian 13), on Fedora `sudo dnf install gtk2`. The launcher checks for
  every library the engine needs and names the missing ones with their
  packages, instead of the engine ending without a word.
- **The browser widget and revBrowser** (CEF 74) also need NSS, ALSA and a
  few more X11 libraries (the `browser` lines of `linux/libraries.txt` in
  the package). Without them the launcher turns the browser off
  (`LIVECODE_USE_CEF=0`), says which ones are missing, and the IDE shows
  the dictionary and other web pages in your web browser instead.
- **Some bundled xTalk extensions need a newer system than the IDE.**
  SodiumXT needs glibc 2.33 (Ubuntu 21.04, Debian 12, Fedora 34 or
  later); DataChannelXT needs glibc 2.38 and OpenSSL 3 (Ubuntu 24.04,
  Debian 13, Fedora 39 or later). On an older system these extensions do
  not load; the IDE and the other extensions work.

To run it where you extract it:

```sh
tar -xJf OXT-Beyond-<version>-linux-x86_64.tar.xz
cd OXT-Beyond-<version>
./oxt-beyond
```

Extract it onto a Linux file system (ext4, Btrfs, XFS and so on, not
FAT, exFAT or a Windows drive): the tarball holds Unix file modes,
symbolic links and hard links. Keep it out of folders named `_build` or
ending in `-bin`, which make the engine look for a source checkout above
it. `oxt-beyond` is the launcher; `OXT-Beyond` is the engine itself,
which starts without the library check. `OXT_BEYOND_SKIP_LIBRARY_CHECK=1`
skips the check.

To install it for yourself, with a menu entry (under Development),
icons, the `.oxtstack` and `.oxtscript` file types and the command
`oxt-beyond`:

```sh
./install.sh
```

It copies the folder to `~/.local/share/oxt-beyond` (or
`$XDG_DATA_HOME/oxt-beyond`), links `~/.local/bin/oxt-beyond` to the
launcher, and needs no administrator rights; it refuses to run as root
or with `sudo`. The extracted folder can be deleted afterwards. Running
a newer package's `install.sh` replaces the installed copy.
`~/.local/share/oxt-beyond/uninstall.sh` removes exactly what
`install.sh` added (it keeps a list in the installed folder). Like the
Windows installer, it leaves `.livecode`, `.livecodescript` and `.rev`
files alone, and OpenXTalk Lite's Linux "file associations" dialog is
not shown. Your preferences, caches and logs are in `~/.oxt-beyond`;
uninstalling keeps them.

The Linux package does not include the Visual C++ runtime DLLs that the
Windows packages put next to enetxt and Box2Dxt: a Windows standalone
built on Linux with either of them needs the Visual C++ Redistributable
on the PC it runs on.

### Where OXT-Beyond keeps your files

On Windows:

| What | Where |
| --- | --- |
| Preferences (`oxt-beyond7.rev`) | `%APPDATA%\OXT-Beyond\Preferences` |
| Cache, crash logs, documentation cache and IDE logs | `%LOCALAPPDATA%\OXT-Beyond\` (`Cache`, `Crash Logs`, `Documentation Cache`, `Logs`) |
| Script copies for an external script editor (if you turn that option on) | `%LOCALAPPDATA%\OXT-Beyond\Cache\IDEScriptEdits` |
| Your own extensions and plugins | `Documents\OXT-Beyond extensions`, unless you choose another folder in Preferences |

On macOS:

- Preferences: `~/Library/Preferences/OXT-Beyond`
- Cache, crash logs and documentation cache:
  `~/Library/Application Support/OXT-Beyond/` (`Cache`, `Crash Logs`,
  `Documentation Cache`); the script copies for an external script
  editor are in `Cache/IDEScriptEdits`
- IDE logs: `~/Library/Logs/OXT-Beyond/`
- Your own extensions and plugins: `~/Documents/OXT-Beyond extensions`,
  unless you choose another folder in Preferences

On Linux:

- Preferences, cache, crash logs, documentation cache and IDE logs:
  `~/.oxt-beyond/` (`preferences`, `cache`, `crashlogs`,
  `documentationcache`, `logs`); the script copies for an external
  script editor are in `cache/IDEScriptEdits`
- Your own extensions and plugins: `~/OXT-Beyond_extensions`, unless you
  choose another folder in Preferences

Installed and portable copies of OXT-Beyond on the same computer share
these folders. LiveCode and OpenXTalk Lite keep their preferences
elsewhere (on Windows `%APPDATA%\RunRev` and `%APPDATA%\xtalk`), so
OXT-Beyond can be installed next to them.

Some files are still kept in the same places as OpenXTalk Lite or
LiveCode, because binary stacks or the engine, which this release does
not change, read or write them there. The table gives the Windows
locations; macOS and Linux use their own equivalents:

| What | Where | Shared with |
| --- | --- | --- |
| Dictionary favourites and notes | `%APPDATA%\xtalk\xTalkDictionary` | OpenXTalk Lite |
| Custom script editor colours | `%APPDATA%\xtalk\Preferences\customScriptColours.dat`; the dark appearance's in `customScriptColours-dark.dat` next to it, once you customize them | OpenXTalk Lite (the light appearance's file) |
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

OXT-Beyond 0.0.2 adds:

- the [xTalk Suite extensions](#xtalk-suite-extensions), built in and
  taken from their own repositories at pinned versions;
- a fix so that an extension you install yourself is loaded instead of
  a built-in copy of the same extension (which copy won used to be
  random);
- from Tom Perry's macOS work: guards against a crash when a menu sends
  a key press to a closed stack and against recursive menu bar updates,
  and "semibold" as a text style name (the same as "demibold");
- behind the scenes, the same engine building for Linux and macOS in
  CI, on the way to packages for those platforms.

OXT-Beyond 0.1.0 adds:

- packages for macOS and Linux, made and tested together with the
  Windows ones from one tag: one universal `OXT-Beyond.app` for Apple
  Silicon and Intel Macs (a disk image and a zip, signed ad hoc, see
  [macOS](#macos)) and a portable Linux x86-64 package with a launcher
  and a per-user install script (see [Linux](#linux-x86-64));
- readable text in the Windows dark mode: disabled labels (toolbar,
  buttons, checkboxes, radio buttons, tabs) are drawn once in a flat
  grey instead of an engraved double image, scrollbars are dark and
  follow a switch between light and dark, and the IDE's lists, Extension
  Manager, Tools palette and toolbar icons have dark colours, partly
  adapted from HyperXTalk (see [Credits](#credits));
- two light mode colours restored that OpenXTalk Lite 1.15 had changed
  by mistake (white text on selected list rows and on coloured badges);
- a fix for a crash of the Linux engine when it opens a stack whose
  text font is "(System)" without a display.

OXT-Beyond 0.2.0 adds:

- stacks that stay readable in the dark appearance: where a stack sets
  some colours but not others (a white field with no text colour, say, or
  a checkbox on a light card), the unset colours now fit the ones the
  author set, so a stack designed light looks as designed, and only a
  stack that sets no colours at all is drawn dark;
- the engine properties `appAppearance` (the application's appearance:
  "light", the default, "dark" or "system") and `stackAppearance` (one
  stack's), with their `effective` forms, in the dictionary. Standalones
  are light unless they set the `appAppearance`; standalones built with
  OpenXTalk Lite 1.14 or later or OXT-Beyond 0.1.0 followed the dark mode
  of Windows and macOS, and on Windows do so again after
  `set the appAppearance to "system"` (on macOS every stack is drawn light
  in this version, whatever the property says);
- the Windows native controls drawn dark in the dark appearance
  (checkboxes, radio buttons, tabs, field and group frames, sliders,
  progress bars, option menus and combo boxes), dark title bars per
  window, and the light appearance whenever a High Contrast theme is on;
- printing always in the light appearance, and a fix for a crash when a
  snapshot of the screen was taken on Windows;
- about 40 fixes from HyperXTalk (see
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#code-adapted-from-hyperxtalk)),
  among them painted images kept when the card changes, no crash exporting
  a widget, script editor hangs on "/*" and on binary data in a tree
  view, the macOS backdrop and custom cursors, Linux dialog leaks and
  typing lag, localized Desktop and Documents folders on Linux, File >
  Open with a missing folder, file dates after 2038, and `pop` with
  nothing pushed;

and in the IDE:

- a light IDE on every system, dark ones included, with the appearance
  as a choice: *View > Appearance* (and *Preferences > Appearance*) sets
  the IDE's appearance (**Light**, the default; **Dark**; **Follow the
  System**) and, separately, that of your own stacks (**Light, like a
  standalone**, the default; **Dark**; **Follow the System**; **Same as
  the IDE**). A change shows at once in every palette. The choices need
  the engine's new appearance properties. Dark mode is for Windows in this
  version: on Linux the appearance follows the GTK theme, and on macOS
  OXT-Beyond is light for now, so there the items are shown but disabled;
- your stacks looking in the IDE as they will in a standalone. A
  standalone is light unless its stack asks for the system's appearance,
  with one line in its `startup` or `preOpenStack` handler:
  `set the appAppearance to "system"` (or `"dark"`);
- the menubar as a standard window on a new install (and in a profile
  that has no setting yet); a profile that already stores the docked
  menubar keeps it, and *Preferences > Appearance > Show the toolbar as a
  standard Window* switches it;
- a dark script editor (One Dark Pro by default, adapted from HyperXTalk,
  with Tom Perry's schemes still in the menu; the editor keeps separate
  light and dark colours in *Preferences > Script Editor*, the custom
  scheme's included, and a dark scheme and background chosen in an
  earlier version become the dark appearance's too, while the light
  appearance keeps them), and a
  readable Inspector, Message Box, error dialog, Find and Replace,
  Standalone Application Settings, Menu Builder and dictionary code
  examples in the dark appearance;
- light mode fixes for colours OpenXTalk Lite 1.15 saved into the
  Extension Manager, Extension Builder, Search, the icon chooser and the
  warning shown before opening a stack with scripts, and blue links in
  About, the User Guides and the dictionary instead of OpenXTalk Lite's
  yellow (a profile that still has the yellow default gets the blue one;
  a colour you chose yourself stays);
- *View > Show IDE Stacks In Lists* in one click (from HyperXTalk).

OXT-Beyond 0.2.1 (its first release candidate is 0.2.1-rc.1) adds:

- LiveCode Community's engine test suites, about 1,150 tests of LiveCode
  Script, LiveCode Builder, the LiveCode Builder compiler and the script
  parser, on every build of all three platforms, compared with lists of
  known failures (see [BUILDING.md](BUILDING.md#engine-tests));
- fixes for engine bugs that those tests and the compiler's warnings
  found. On Windows: creating a player in a stack that has no window (for
  example without a user interface, `-ui`) no longer crashes; output
  redirected to a file or a pipe (`standalone.exe > log.txt`, or `shell()`
  from another program) reaches it again; without a user interface,
  `accept connections` listens again and `wait` no longer keeps a
  processor busy; dates before 1970 convert; file paths that a script
  puts on the clipboard are native; the `playLoudness` of a player and
  the player properties that the Windows player cannot get (the duration
  and current time of a file it cannot play, for example) no longer
  return random values; and the `fontNames` no longer fail for no
  reason;
- on Linux and macOS, `~` is `$HOME`, and on Linux `~user/folder`
  resolves; on Linux the last second of 1969 converts, and file lists on
  the clipboard and in drag and drop keep names with spaces and "+"; on
  macOS, Java support finds Java 9 and later, and on Apple Silicon an
  Objective-C exception in a method that LiveCode Builder calls is an LCB
  error again instead of ending the program;
- on every platform: text compares by codepoint however the engine holds
  it (on Windows and macOS, `sort ... text` and `<` on text with chars
  such as the euro sign or curly quotes depended on how the string had
  been made); a pressed button's hilite follows the pointer again
  instead of flickering; exporting a widget whose kind is not loaded no
  longer crashes; LiveCode Builder's base conversion no longer crashes
  for a base below 2; and the `constraints` of a player (QTVR, which no
  current player supports) are zeros instead of random numbers;
- one change in behaviour: `baseConvert` (and LiveCode Builder's
  `converted from base`) of a number above 4,294,967,295 is an error
  instead of a wrong, wrapped-around result.

### xTalk Suite extensions

OXT-Beyond ships the extensions of the
[xTalk Suite](https://github.com/SethMorrowSoftware/xtalk-suite) built
in, in the program's `Extensions` folder. They are taken from their own
repositories at pinned commits when OXT-Beyond is packaged (see
[BUILDING.md](BUILDING.md#xtalk-suite-extensions)):

| Extension | What it is | Repository |
| --- | --- | --- |
| `org.openxtalk.library.sodium` | SodiumXT: modern cryptography through libsodium (authenticated encryption, Argon2id, X25519, ed25519, BLAKE2b, random bytes) | [SodiumXT](https://github.com/SethMorrowSoftware/SodiumXT) |
| `org.openxtalk.library.torrent`, `torrentHelpers` | TorrentXT: BitTorrent and the DHT through libtorrent, and its script helpers | [TorrentXT](https://github.com/SethMorrowSoftware/TorrentXT) |
| `org.openxtalk.library.enet`, `enetHelpers` | enetxt: reliable UDP networking through ENet, and its script helpers | [enetxt](https://github.com/SethMorrowSoftware/enetxt) |
| `org.openxtalk.library.datachannel`, `dataChannelHelpers` | DataChannelXT: WebRTC data channels through libdatachannel, and its script helpers | [dataChannelXT](https://github.com/SethMorrowSoftware/dataChannelXT) |
| `org.openxtalk.box2dxt`, `box2dxt-kit` | Box2Dxt: 2D physics through Box2D, and the Box2Dxt Kit | [Box2Dxt](https://github.com/SethMorrowSoftware/Box2Dxt) |
| `org.openxtalk.library.coin`, `coinxt` | CoinXT: Bitcoin and Ethereum cryptography (hashes, keys, addresses, HD wallets, transactions) | [CoinXT](https://github.com/SethMorrowSoftware/CoinXT) |
| `onionxt`, `onion-httpd` | OnionXT: Tor transport and onion services, and a small HTTP server on top of it (LiveCode Script) | [OnionXT](https://github.com/SethMorrowSoftware/OnionXT) |
| `nostrxt`, `nostr-relay` | NostrXT: the Nostr protocol and a relay client (LiveCode Script) | [NostrXT](https://github.com/SethMorrowSoftware/NostrXT) |

- The IDE loads them when it starts, like its other built-in
  extensions; the *Extension Manager* lists them and can unload them or
  stop them loading. The script libraries are put into the message path
  when they load, so `start using stack "coinxt"` and the like, which
  the members' documentation mentions, are not needed in the IDE. They
  do no harm, because a stack name finds the built-in copy.
- The script libraries keep the stack names the members document
  (`coinxt`, `nostrxt`, `nostr-relay`, `onionxt`, `onion-httpd`,
  `box2dxt-kit`, `torrentHelpers`, `enetHelpers`, `dataChannelHelpers`),
  and only one stack of a given name can be in memory. While the
  built-in library is loaded, opening your own copy of the same file by
  its path, or loading it with
  `start using stack "<folder>/datachannel-helpers.livecodescript"`,
  makes the IDE ask what to do with the stack "already open". *Cancel*
  keeps the built-in copy in use; *Save* also writes the built-in copy
  back into the `Extensions` folder. In the IDE, load these libraries by
  name. To use your own copy instead, first unload the built-in one in
  the *Extension Manager* (and turn off "Load on startup" if it should
  stay unloaded).
- If you install your own copy of one of them (an `.lce` through the
  *Extension Manager*), the IDE loads your copy instead of the built-in
  one. For the LCB libraries this happens at once. For a script library
  it happens after you restart the IDE: until then the IDE asks about
  the stack "already open" (choose *Cancel*), and the built-in copy
  stays in use.
- For standalones, the standalone builder, when it searches for the
  inclusions a stack needs, adds an LCB library whose handlers your
  scripts use, together with its native library for the target platform.
  The extensions have native libraries for Windows x86-64 and x86, Linux
  x86-64 and x86, and macOS, but none for Android. The standalone builder
  never adds the script libraries by itself: tick them in *Standalone
  Settings*, with the LCB libraries they need (for example `coinxt` with
  `org.openxtalk.library.coin`).
- Their documentation is in their repositories (`docs/`); the Dictionary
  does not have it.
- Their licences (MIT, and those of the libraries built into them) are
  in each extension's `licenses` folder and in
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#xtalk-suite-extensions).

### The engine

The engine is the LiveCode Community **9.7 development tree** (the
upstream `develop` branch as it was left in July 2021, version
9.7.0-dp-1), not the 9.6.3 release, plus Tom Perry's OpenXTalk Lite
engine changes for Windows (commit `38d5712b2`):

- **Windows dark mode.** Dark window title bars, dark system colours
  that update when the theme changes (with a `systemAppearanceChanged`
  message and a redraw of open stacks), and dark-mode aware checkmarks
  and cascade arrows. OXT-Beyond makes it a choice (below).
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

**Light by default, dark mode by choice.** The engine draws in the light
appearance unless a script chooses otherwise, on every platform and in
standalones too: `the appAppearance` is `"light"` by default, `"dark"`,
or `"system"` to follow Windows or macOS, and `the stackAppearance of
<stack>` sets it for one stack (empty inherits). The IDE uses them for
its Light, Dark and Follow the System preferences. Where a stack is drawn
dark, the engine fits each object's unset colours to the colours its
author set around it, so a stack designed light (a white field with no
text colour, a checkbox on a light card) still looks as designed, and a
stack that sets no colours goes dark; the light appearance is drawn
exactly as before. `the systemAppearance` still reports the operating
system's setting. See
[docs/notes/feature-appearance.md](docs/notes/feature-appearance.md).

Standalones built with OpenXTalk Lite 1.14 or later, or with OXT-Beyond
0.1.0 or earlier, followed the dark mode of Windows (and of macOS). Built
again with this version they are light, unless the mainstack's startup
or preOpenStack handler opts in with one line:
`set the appAppearance to "system"`.

Changes made in this repository to build it: the `thirdparty` and `ide`
submodules are ordinary folders in the repository, the prebuilt
libraries that LiveCode's server no longer provides are mirrored in the
[`prebuilts-v1` release](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases/tag/prebuilts-v1),
the build scripts were updated for Visual Studio 2022 with the v141
toolset, and GitHub Actions workflows build, package and test it for
Windows, macOS and Linux.

## Building from source

See [BUILDING.md](BUILDING.md). In short: install Visual Studio 2022 with
the v141 toolset, Python 2.7, Strawberry Perl, Git and Cygwin, then

```bat
git clone --recurse-submodules https://github.com/SethMorrowSoftware/OpenXTalk-Beyond.git C:\src\OpenXTalk-Beyond
cd /d C:\src\OpenXTalk-Beyond
set PATH=C:\Python27;%PATH%
C:\Python27\python.exe config.py --platform win-x86_64
cd build-win-x86_64
cmd /c ..\make.cmd
```

and run `win-x86_64-bin\LiveCode-Community.exe` from the repository.
To make the installed layout, the zips and the installer, see
[Package](BUILDING.md#package) and [Installer](BUILDING.md#installer)
(they need Python 3 and Inno Setup 6).

Linux and macOS are built by their CI workflows: BUILDING.md describes
their steps in [Building on Linux](BUILDING.md#12-building-on-linux) and
[Building on macOS](BUILDING.md#13-building-on-macos), and how a
release is made from a tag in
[Making a release](BUILDING.md#10-making-a-release).

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
| `prebuilt/` | Scripts that fetch the prebuilt third-party libraries for Windows (from the `prebuilts-v1` release) and build them from source on Linux and macOS, with their versions and checksums. |
| `config/`, `gyp/`, `config.py`, `make.cmd` | Build configuration: gyp generates the Visual Studio projects. |
| `tools/oxt/` | Python tools that map an installed OpenXTalk Lite folder to the repository and back (`layout.py`), stage OXT-Beyond's installed layout (`package.py`), fetch the external assets listed in `external-assets.json`, and pin, fetch and build the xTalk Suite extensions listed in `xtalk-extensions.json` (`xtalk_extensions.py`). See [tools/oxt/README.md](tools/oxt/README.md). |
| `Installer/oxt-beyond/` | The Inno Setup script of the installer, the scripts that make its images, and the icon's source art. |
| `tools/ci/` | PowerShell and Python scripts used by CI to install components, build, check, package, smoke-test, compile-check the IDE, run the engine tests of `tests/` (and trace a Windows crash), build and test the installer, join and sign the macOS app, test the Linux package, and assemble a release and its notes. |
| `.github/workflows/` | The GitHub Actions workflows: `build-windows.yml`, `build-macos.yml` and `build-linux.yml` build, package and test each platform on every push to `main` and every pull request into it; `release.yml` builds all three from a `v` tag and publishes the release. |
| `Installer/package.txt`, `builder/` | LiveCode's packaging manifest (the packager follows its rules for Windows, Linux and macOS) and LiveCode's installer builder (not used). |
| `tests/`, `engine/exec-tests/` and others | Upstream test suites; CI runs those of `tests/` (see [Engine tests](BUILDING.md#engine-tests)). |

For a compatibility-first proposal to make the engine easier to test and
change, see the [engine stabilization and modernization plan](docs/development/engine-modernization-plan.md).

## Known limitations and plans

Known limitations, in rough order of importance:

1. Old third-party libraries with known vulnerabilities (OpenSSL 1.1.1,
   curl 7.51.0, CEF/Chromium 74, ICU 58.2 and several older libraries in
   `thirdparty/`). Plan: rebuild the prebuilt libraries from newer
   sources.
2. The standalone runtimes for 32-bit Windows, 32-bit Linux and Android
   (and the 64-bit Linux one in the Windows and macOS packages) are
   prebuilt binaries from OpenXTalk Lite 1.15, not built from this
   repository; the macOS and Linux packages have no Windows x86-64
   runtime yet. Building standalones is tested automatically only for
   macOS.
3. The Windows binaries are not code-signed, and the macOS app is signed
   ad hoc, not with an Apple Developer ID, and not notarized. Plan:
   Developer ID signing and notarization for macOS.
4. "OpenXTalk Lite" still appears inside binary stacks, and the build
   output files are named after LiveCode. Plan: change the binary stacks
   a few at a time with the stack patches of `tools/oxt/ide-stack-patches`
   (see [BUILDING.md](BUILDING.md#11-working-on-the-ide)), and rename the
   engine files.
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
9. The dark appearance has limits. A transparent label or checkbox with
   a dark text colour of its own, on a card with no colour, stays dark on
   the dark card. On Linux the native controls are drawn by the GTK
   theme, so every stack follows it and the appearance properties change
   nothing there; a light-designed stack under a dark GTK theme can still
   show white text on white. On macOS every stack is drawn light for
   now, whatever the appearance properties say, because the classic
   native controls stay light. Plans: a fixed light palette for the
   Linux theme's light-designed objects, and Tom Perry's AppKit-drawn
   macOS controls.
10. In an install for all users, a few things that save stacks inside
   the program folder fail for standard users, because Setup keeps
   stacks and scripts there read-only: the Report Builder plugin saving
   itself when it closes, *Plugin Settings* changes to the plugins that
   come with OXT-Beyond, and edits to the built-in image libraries. Install for the current user only,
   or use the portable zip, if you need them. Plan: keep that state in
   the user's own folders.

Done since 0.0.1: the extensions of the xTalk Suite are built in, taken
from their own repositories at pinned commits (see
[xTalk Suite extensions](#xtalk-suite-extensions) and
[BUILDING.md](BUILDING.md#xtalk-suite-extensions)). Their limitations:
the native libraries are the members' prebuilt binaries, which
OXT-Beyond checks but does not build; the Dictionary does not have
their documentation; the standalone builder does not add the script
libraries by itself; and enetxt and Box2Dxt need the Visual C++ runtime,
whose DLLs the Windows packages ship next to them (the Linux and macOS
packages do not yet).

Issues and pull requests for any of these are welcome.

## Getting help and reporting problems

- **Bugs and feature requests:**
  [GitHub issues](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/issues).
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
- **HyperXTalk** ([emily-elizabeth/HyperXTalk](https://github.com/emily-elizabeth/HyperXTalk)),
  Emily-Elizabeth Howard's GPL-3.0 fork of the same LiveCode Community
  code, with docmeth02, Mark Wieder, Brian Milby, Paul McClernan, BerndN
  and other contributors. OXT-Beyond's dark colour table for the IDE
  (`revIDEColor`) is adapted from docmeth02's; code taken from HyperXTalk
  names the HyperXTalk commit and its author in the commit message.
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
