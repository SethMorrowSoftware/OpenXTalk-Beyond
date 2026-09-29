# History

OXT-Beyond is the latest link in a chain: LiveCode Community, then
OpenXTalk Lite, then OXT-Beyond. This file describes that chain, lists
the OpenXTalk Lite releases, explains how their history was
reconstructed in this repository's Git history, and says what
OXT-Beyond changed on top.

Dates are those of the releases or builds as their authors published
them. Build numbers are OpenXTalk Lite's own (`YYYYMMDDHHMM`, the time
of the build, apparently UK time). Where a date is only approximate, it
says so. The sources are Tom Perry's release notes (in his
[downloads post](https://openxtalk.org/forum/viewtopic.php?t=590) and
the `release notes.txt` file next to the 1.15 downloads), the
update-history notes that ship in the IDE
(`ide/Toolset/palettes/updates/updatehistory/`), the OpenXTalk forum
threads, and the files themselves.

## LiveCode Community and OpenXTalk

LiveCode Community was the GPLv3 edition of LiveCode by LiveCode Ltd,
which grew out of Revolution and MetaCard and whose language continues
the HyperTalk tradition of HyperCard. OpenXTalk Lite started from its
9.6.3 release (2021). The upstream repositories
([livecode/livecode](https://github.com/livecode/livecode),
[livecode/livecode-ide](https://github.com/livecode/livecode-ide) and
[livecode/livecode-thirdparty](https://github.com/livecode/livecode-thirdparty))
have had no changes since July 2021 and are archived. The `develop`
branch of the engine had moved on to 9.7.0-dp-1.

The [OpenXTalk community](https://www.openxtalk.org) formed to keep a
free and open xTalk available; Paul McClernan's OpenXTalk DPE ("Don't
Panic Edition") is its larger edition. Some OpenXTalk Lite files (the
debranded guides and the dictionary database, dated 2022) appear to
come from that earlier OpenXTalk debranding work.

## OpenXTalk Lite

OpenXTalk Lite was started by **Terry Little** (TerryL). In August 2023
he asked for testers of a copy of LiveCode Community 9.6.3 with minimal
changes apart from debranding, based on his own 32-bit Windows copy. On
1 September 2023 he released it as OpenXTalk Lite ".9": an "IDE hack"
that turned an installed LiveCode Community 9.6.3 into OpenXTalk Lite by
swapping files, in twelve steps
([announcement](https://openxtalk.org/forum/viewtopic.php?t=517)).

**Tom Perry** (tperry2x) started contributing the next day and posted
packaged macOS and Linux builds on 4 September 2023. Terry Little
released his last package, ".91", on 16 September and handed the
project on two days later. From then on Tom made the releases, for
macOS, Linux and Windows, up to 1.15 in June 2026. Terry Little went on
contributing IDE changes until 1.15 (in May 2025 he also posted a
manual update for 1.12), and **Paul
McClernan** (OpenXTalkPaul) and other forum members contributed code,
lessons, ideas and bug reports.

Tom published builds on tsites.co.uk (2023), then in a Dropbox folder
(0.94 to 0.99) and from early 2024 in a MEGA folder, which now holds
only 1.15. The IDE also had an updater (re-enabled in 0.95): it
downloaded IDE-only update packages from Tom's update server
(tsites.co.uk, and openxtalk.net from 1.14) and installed them with
administrator rights. Update packages survive for 1.0 to 1.10 and for
1.14. Tom published the source of his 9.7.1-OXT engine as archives on
[openxtalk.net](https://www.openxtalk.net/OXT-lite-source/index.php)
(Windows, June 2026; macOS, June 2026; Linux, September 2026).

### Versions

"In Git" is the commit in this repository that holds the IDE of that
version (see [How the history was reconstructed](#how-the-history-was-reconstructed)).

| Version | Date | Build | In Git | Headline changes |
| --- | --- | --- | --- | --- |
| .9 | 1 Sep 2023 | | (lost) | Terry Little's "IDE hack" for an installed LiveCode Community 9.6.3: debranded guides, About, preferences, menus and dictionary database; App Browser, Quick Dictionary and Report Builder plugins; Pie Chart widget; tutorial stacks; improved Menu Builder and Answer/Ask dialogs. |
| 0.9 | 4 Sep 2023 | | | Tom Perry's first packaged builds, for macOS and Linux. On 16 September he rebuilt them on LiveCode Community 9.6.1 to be able to build 32-bit Mac standalones. |
| .91 | 16 Sep 2023 | | `2197b3457` | Terry Little's last package ("LCC Hack Lite .91"). |
| 0.91 | 25-27 Sep 2023 | | `6a960a633` | macOS, Linux and the first Windows x64 build (a 7z archive, no installer). Open and save `.oxtstack` files (Paul McClernan's method); OXT icon in the program; new splash screen, toolbar and tool icons; Start Center, standalone builder and preferences debranded. |
| 0.92 | 3-6 Oct 2023 | | `7e1a2cdf4` | Back on a 9.6.3 base while keeping 32-bit and 64-bit Mac standalones. Version read from `about.dat`; installs into "OpenXTalk" folders; `.oxtstack` file associations. |
| 0.93 | Nov 2023 (approx.) | | `b0f56df4c` | Draggable menubar; alignment guides while dragging objects (FerrusLogic's DevGuides, integrated by Paul McClernan); first IDE dark-mode theming; user extensions folder renamed "xTalk extensions". |
| 0.94 | 22-23 Nov 2023 | | `122ae3663` | Theming removed again (inconsistent across platforms); tool snippets (sample scripts for new objects); preferences moved from `RunRev` to an `xtalk` folder; option to disable the Player tool; `tSystemVersion` globals; more script editor colour schemes. First version with Tom's release notes file. |
| 0.95 | 26-27 Nov 2023 | | `d9c64584d` | Online updates re-enabled; layout guides optional; menubar placement option for multiple displays. |
| 0.96 | Dec 2023 | | `2d1d66648` | A stack-based dictionary replaces the web-based one; OXT icon in Answer and Ask dialogs, and custom alert icons (an image named `appicon.png`); grid setting remembered; Object menu shortcuts; first "All Guides" stack. A 32-bit Linux build. |
| 0.97 | 31 Dec 2023 | | `5b6760cb9` | *Help > Check for updates*; shortcuts for the Object Inspector, Project Browser and App Browser; Report Builder fixes. |
| 0.98 | 13 Jan 2024 | | `cb602686f` | "All Guides" continued; splash screen shows the loading status; text size and alignment shortcuts. |
| 0.99 | 24 Jan 2024 | | `1d15e3bc4` | Much faster start-up; the tools palette follows light and dark mode, with dark icon sets; Terry Little's User Guide and Data Grid Guide PDFs; other editions' skins removed. |
| 1.0 | 26 Jan 2024 | 202401261849 | `8b6504ea3` | Inspector and message box focus fixes; dark mode for the project browser and dictionary; new About stack; Terry Little's lessons. The Linux engine is now Tom's build of LiveCode 9.7.0-dp-1, without the registration screen. |
| 1.01 | Feb 2024 | | `d1e616b6c` | revMenubar crash fix; dictionary line height. |
| 1.02 | Mar 2024 | | `e20a86f08` | Message box could be invisible; *Save As* defaults to the OpenXTalk format again. |
| 1.03 | Mar-Apr 2024 | | `fe2170633` | Colourised cursors and a counting-hand busy cursor; reversed dark-mode detection; a build without CEF. |
| 1.04 | 4-5 May 2024 | | `741921aec` | Paint and graphics tools largely rebuilt; tools palette in sections; options for the browser widget, data grids and hand or arrow cursor; accent colour changes from purple to orange; new application icon; the Windows installer checks for administrator rights and for an existing install. |
| 1.05 | 1 Jun 2024 | | `db3bda7ed` | Tools palette configuration; Quick Dictionary fixes (with Terry Little); extra vector shapes. |
| 1.06 | 12-13 Jul 2024 | | `5b7e3e0e6` | Middle-click toggles the browse and pointer tools; option to keep a stack's own colours; Linux file associations; "Code" renamed "Script". |
| 1.07 | 1-2 Aug 2024 | 202408010800 | `aa088927e` | Dictionary as a stack with a plain-text export; new toolbar icons; option to leave third-party stacks unthemed; "Debug Properties" preference. |
| 1.08 | 28 Sep 2024 (beta 28 Aug) | | `e603e3d94` | Scrollable Release Notes stack; the updater uses curl; Radius paint tool restored; glossary links in the dictionary; timer on the standalone-built alert. |
| 1.09 | Nov 2024 | 202411172019 | `08be5de55` | The Windows engine moves to Tom's build of 9.7.0-dp-1; Android standalone setup instructions, and the "Choose JDK" button always shown; the updater restarts the IDE; ten recent fonts in the font menu; IDE menus use `if` instead of `switch` to avoid an engine memory leak. |
| 1.10 | 5 Jan 2025 | 202501050752 | `4832873bf`, updates to 202503151609 in `951f2748b` | Axwald's Message Watcher; Card Navigator; *Edit > Replicate*; prompt to name new stacks; initial external script editing. Tom called it the last version with a largely untouched engine. |
| 1.11 | May 2025 | 202505291100 | (in `523b3b208`) | Terry Little's IDE changes, packaged by Tom: *Help > Forums*, Place/Remove Group, keyboard shortcut changes, `destroyStack` true by default, the Calendar and Pie Chart widgets, a newer dictionary database for Quick Dictionary. |
| 1.12 | 29 May - 6 Jun 2025 | 202506060909 | (in `523b3b208`) | Terry Little's manual update (29 May), then Tom's builds for all platforms (6 Jun); fixes a recursion error in the preferences. |
| 1.13 | Sep 2025 | 202509131308 | (in `523b3b208`) | Dark-mode fixes for macOS dialogs and controls; the dictionary shows the parameters section. A "Mod Engine v2" Mac build uses Tom's first own macOS engine (compiled 18 Sep 2025). |
| 1.14 | 18 Jan 2026 | 202601171326 | update package 202602121011 in `d76cfe6d0`; the rest in `523b3b208` | Engine 9.7.1-OXT on all platforms: native dark mode on macOS and Windows, Windows 11 detection, revSpeech voices, GTK3 Linux build, native ARM Mac build. Documentation tab removed from the script editor; *Help > Demos* (Terry Little's demo stacks) and *Dictionary Online*. 10 Feb 2026: SQLite 3.51.1 in the engines. 12-14 Feb 2026: update package with a light/dark splash screen and restart after updating. |
| 1.15 | 5 Jun 2026 (re-uploaded 7 Jun) | 202605052228 | `523b3b208` | Faster script editor on Windows (engine); customisable script editor colours; recent stacks as a thumbnail gallery; lock/unlock all objects and remove effects; widget icons follow light and dark mode; WebKitGTK and GStreamer on Linux; Intel Macs build ARM standalones. Windows builds as 7z archives without an installer, plus a smaller "debloat" variant without CEF. Tom Perry's last OpenXTalk Lite release. |

Notes on the table:

- The forum and the release notes disagree on 1.11: the forum
  announces it on 5 May 2025, the release notes give build
  202505291100. Both are shown.
- Versions before 1.0 have no build number in any surviving index; the
  update server's index starts at 1.0.
- The dates of 0.93 to 0.99 and 1.01 to 1.03 are those of the newest
  change that went into the reconstruction; the public release dates
  are not known exactly.
- The update server's index labels each update package with the
  version it updates, so the 1.07 packages, for example, carry the
  changes that Tom's release notes list under 1.08. The table follows
  the release notes.

### Engines

| Platform | Engine |
| --- | --- |
| Windows | Until 1.08, the stock LiveCode Community 9.6.3 program with OpenXTalk Lite's icon and version information patched in. Tom compiled 9.7 for Windows in April 2024 but went back to 9.6.3 because it was slow. From 1.09, his own build of 9.7.0-dp-1 (64-bit only); from 1.14, 9.7.1-OXT. |
| Linux | From 1.0, Tom's build of 9.7.0-dp-1; from 1.14, 9.7.1-OXT (GTK3, plus a legacy GTK2 build). |
| macOS | Until 1.13, LiveCode's 9.6.3 engine with a small binary patch for a crash on macOS Sonoma (written by another forum member who is also called Tom), and a 9.6.1 universal engine for 32-bit standalones. From September 2025 Tom Perry's own compile; from 1.14 9.7.1-OXT, with a native ARM build. |

The Windows engine changes of 9.7.1-OXT are in this repository as
commit `38d5712b2` ("OpenXTalk Lite Windows engine work by Tom Perry"),
imported from Tom's working copy. The same 41 files changed in his June
2026 Windows source archive. Of the files whose sizes were checked,
`respring.cpp`, `sqlite3.c` and `version` have the same size in both,
and `w32theme.cpp` does not (68,699 bytes in the archive, 66,570 in
the repository), possibly because of line endings. The contents were
not compared.

### After 1.15: OXTL7

Tom stepped back from OpenXTalk Lite several times: in August 2024, in
January 2025, and in May 2025, when he said he was no longer working on
it. He came back in September 2025 to compile the engines for macOS,
Linux and Windows, which produced 1.13, 1.14 and 1.15. In March 2026 he
said he would eventually look for a new maintainer.

In July 2026 he rebuilt LiveCode Community 7.1.4 as a 64-bit engine
(versioned 7.4.1), and in September 2026 he announced **OXTL7**
("OpenXTalk Lite 7"), a new IDE on that engine, which he intends to
replace OpenXTalk Lite. In August and September 2026 he said that 1.15
is as far as he will take the LiveCode 9 engine, and that nothing stops
others from continuing their own fork of 1.15 on it
([thread](https://openxtalk.org/forum/viewtopic.php?t=2149)). His other
xTalk work, such as the browser-based Webtalk, is separate from
OpenXTalk Lite.

OXT-Beyond is such a continuation of 1.15 on the 9.x engine. It is not
OXTL7, and it is not an official OpenXTalk or OpenXTalk Lite release.

## OXT-Beyond

This repository (winoxt) was started in September 2026 to build
LiveCode Community for 64-bit Windows with Tom Perry's engine work,
using GitHub Actions: the `thirdparty` and `ide` submodules became
ordinary folders, the prebuilt libraries LiveCode's server no longer
serves were mirrored in the `prebuilts-v1` release, and the build was
made to work with Visual Studio 2022 and the v141 toolset (pull
requests #1 to #3). At that point `ide/` still held the stock LiveCode
Community IDE (upstream `livecode-ide` commit `ccc733a1`, identical to
what LiveCode Community 9.6.3 installs).

The OpenXTalk Lite IDE history was then imported on top of it, and
OXT-Beyond 0.0.1 was made from the result.

### How the history was reconstructed

OpenXTalk Lite was never kept in a version control system that
survives, and its IDE exists only as installed files. The IDE's history
was therefore rebuilt from what is still available:

1. Terry Little's .91 package (`LCC Hack.zip`), found in Tom Perry's
   2024 upload to GitHub
   ([tperry2x-uk/OpenXTalk-Lite](https://github.com/tperry2x-uk/OpenXTalk-Lite),
   folder `Tests/OXT original hack`);
2. Tom's "OpenXTalk Lite dev" MEGA folder: nineteen "changes" archives
   (`oxt-changes-part-01` to `part-19`, 0.9x to 1.10) with his dated
   change folders;
3. Tom's update server (tsites.co.uk): the update packages for 1.0 to
   1.10 and 1.14, each with its file list and `whatsnew.txt`;
4. a complete installed OpenXTalk Lite 1.07 (build 202408010800);
5. the complete OpenXTalk Lite 1.15 for Windows
   (`openxtalk-lite-1.15-win-noinstaller.7z`, build 202605052228) from
   Tom's MEGA folder.

The history is 24 commits, listed in the table above: one for each
version from .91 to 1.10, a second 1.10 commit for its later update
packages, one for 1.14 and one for 1.15. Each commit's author is the
person who made that version, Terry Little for .91 and Tom Perry for
the others, without an e-mail address; the author date is the build
time of that version or of its newest change; the committer is this
repository's maintainer. The commit
messages summarise Tom's release notes, name the sources used and
credit the other people involved. Before them, commit `254cb8d39` makes
`ide/.gitignore` track every file that OpenXTalk Lite ships; after
them, commit `446a720c9` adds the import tool,
[`tools/oxt/layout.py`](tools/oxt/README.md), that mapped the installed
files to `ide/` and `ide-support/`.

How exact the commits are:

- **1.07 and 1.15 are exact.** Their IDE files equal those of the
  complete installs, apart from the two files left out for licence
  reasons (below); `layout.py verify` passes for 1.15 against the
  repository.
- **All other commits are best-effort reconstructions.** Each file takes
  the newest version found in the sources up to that release; files not
  in the sources keep their previous content; files are removed only
  where the sources show a removal. Commits between .91 and 1.06 come
  from the change archives (and, from 1.0, the update packages); 1.08,
  1.09, 1.10 and 1.14 are the previous state plus the update packages,
  because no complete release of those versions survives.

Known gaps:

- Terry Little's original .9 (1 September 2023) is lost. The history
  starts with his .91 package; the drawing library script (built from
  `extensions/` here), a macOS `Info.plist` and his optional "Personal
  Hacks" are not included.
- Tom's changes from before 25 September 2023, including his 0.9 builds
  for macOS and Linux, are folded into the 0.91 commit (his own
  update-history notes label them 0.92).
- No IDE files of 1.11, 1.12 or 1.13, or of the 1.14 builds
  202510191510 and 202601171326, survive in any source that was found.
  Their changes arrive in the 1.15 commit, and the 1.14 commit holds only
  the February 2026 update package. The testing-only update package
  202411111643 is no longer on the server.
- Some platform-specific material in the change archives, such as the
  Linux-only files in the 1.04 archive, is not included.
- Two files that OpenXTalk Lite shipped are left out of every commit for
  licence reasons: Apple's Human Interface Guidelines PDF and
  `animationEngine6.zip` (see
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#files-openxtalk-lite-shipped-that-oxt-beyond-does-not)).
- Program files (the engines, externals, CEF, toolchain, runtimes and
  mergExt) are not in the history. The Windows x86-64 ones are built
  from source; the runtimes for other platforms are a release asset (see
  [BUILDING.md](BUILDING.md#external-assets)).

Binary files (stacks, images, PDFs, the dictionary database) are stored
byte for byte as they were shipped. Text files are stored with LF line
endings. Tom's dated comments in the scripts, such as `(tperry 28-6-24)`,
are kept; they are the record of his changes inside the code.

To see the history of one IDE file:

```bat
git log --follow --format="%h %ad %an %s" --date=short -- ide/Toolset/home.livecodescript
```

### What OXT-Beyond 0.0.1 changed

On top of the OpenXTalk Lite 1.15 IDE and the 9.7.1-OXT engine:

- **Name and version.** The product is called OXT-Beyond, version 0.0.1
  (`ide/.version`). The build number in `ide/.buildnumber` is a
  placeholder; packaging writes the real one. The engine version
  (9.7.1-OXT, build 25923) is unchanged.
- **Branding.** `about.dat` (the About text, with credits to Terry Little,
  Tom Perry and the OpenXTalk contributors), the window title and the
  splash screen say OXT-Beyond. The icon is adapted from Tom Perry's
  OpenXTalk Lite icon, with "Lite" replaced by "Beyond". Binary stacks
  were not re-saved, so text inside them still says OpenXTalk Lite in
  places.
- **Separate settings.** Preferences, caches, logs, external script
  editor copies and the user extensions folder are OXT-Beyond's own, not
  LiveCode's `RunRev` or OpenXTalk Lite's `xtalk` folders. Dictionary
  favourites and notes, custom script editor colours and recent-stack
  thumbnails are still shared with OpenXTalk Lite, and the engine still
  writes its licence file into `RunRev`, because binary stacks and the
  engine were not changed (see the
  [README](README.md#where-oxt-beyond-keeps-your-files)).
- **File associations.** The installer associates `.oxtstack` and
  `.oxtscript` with OXT-Beyond. OpenXTalk Lite's "File Associations"
  dialog, which registered `.oxtstack`, `.rev`, `.livecode` and
  `.livecodescript` for the current user, is no longer shown on
  Windows.
- **Updates.** A new script library,
  `ide/Toolset/libraries/oxtbeyondupdater.livecodescript`, asks this
  repository's GitHub Releases for the latest version and only notifies;
  the automatic check is off by default. OpenXTalk Lite's updater stack,
  which downloaded files from Tom's servers and installed them with
  administrator rights, is no longer opened by the IDE.
- **Packaging.** [`tools/oxt/package.py`](tools/oxt/package.py) stages
  the same installed layout as OpenXTalk Lite 1.15, with the development
  engine as `OXT-Beyond.exe`, the build outputs of this repository, and
  the standalone runtimes for other platforms from a release asset. A
  new Inno Setup installer installs it for all users or for one user.
- **Not redistributed.** The mergExt externals, Apple's Human Interface
  Guidelines PDF and `animationEngine6.zip`.
- **Checks.** CI compiles every IDE script against a baseline of known
  errors, smoke-tests the portable zip and an installed copy, and
  installs and uninstalls the installer.

Changes to the IDE scripts are marked with `-- OXT-Beyond:` comments.
