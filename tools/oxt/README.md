# OXT layout and packaging tools

These tools need only Python 3 (standard library) and run on Windows and
Linux.

| tool | purpose |
|---|---|
| `layout.py` | maps an installed OpenXTalk Lite (or stock LiveCode 9.x) Windows program folder to this repository's layout and back: imports an OXT Lite IDE into `ide/` and `ide-support/` and checks an import |
| `package.py` | stages the installed layout of OXT-Beyond from the repository, a build and the external assets (see [Packaging](#packaging-packagepy)) |
| `fetch_assets.py` | downloads, caches and verifies the external assets listed in `external-assets.json` (see [External assets](#external-assets)) |
| `xtalk_extensions.py` | pins, fetches and builds the xTalk Suite extensions listed in `xtalk-extensions.json` (see [xTalk Suite extensions](#xtalk-suite-extensions-xtalk_extensionspy)) |
| `make_runtimes_asset.py` | builds the `oxt-runtimes-<version>.zip` asset from an installed OXT Lite (see [The runtimes asset](#the-runtimes-asset)) |

## layout.py

`layout.py` maps an installed OpenXTalk Lite (or stock LiveCode 9.x) Windows
program folder to this repository's layout and back. It is how the IDE of an
OpenXTalk Lite release is imported into `ide/` and `ide-support/`, and how an
import is checked.

```
python tools/oxt/layout.py classify <installed-root> [--out FILE] [--from-list FILE]
python tools/oxt/layout.py import   <installed-root> <repo-root> [--dry-run] [--log FILE]
python tools/oxt/layout.py assemble <repo-root> <out-dir> [--eol keep|lf|crlf] [--force]
python tools/oxt/layout.py verify   <installed-root> <repo-root> [--upstream] [--keep-temp]
```

* `classify` prints one TSV line per installed file: class, installed path,
  repository path, size and the reason (usually the `Installer/package.txt`
  line that puts the file there). `--from-list` classifies a list of paths
  instead of a folder (for example the file list of an archive). Exit status
  1 if a path matches no rule.
* `import` makes the managed repository files (see below) mirror the install:
  it copies new and changed files, deletes managed files the install does not
  have and prints added / modified / deleted / unchanged counts per area.
  `--dry-run` only reports; `--log` writes every action as TSV. It refuses to
  run while any installed path is unclassified or two mirrored copies of a
  file differ.
* `assemble` writes the class (a) part of the installed layout from the
  repository.
* `verify` assembles into a temporary folder and compares the result with the
  install's class (a) files. Exit status 1 on any difference.

Text files (extensions in `TEXT_EXTENSIONS`) are compared with line endings
normalised, because git stores them with LF and may check them out with CRLF;
all other files are compared byte for byte. `import` copies the installed
bytes unchanged and git normalises text files when they are added.

### Classes

| class | meaning | in git |
|---|---|---|
| `ide` (a) | IDE content, mapped to a repository path | yes |
| `build` (b) | produced by building or packaging this repository | no |
| `external` (c) | files for other platforms and third-party collections that this repository's Windows build does not produce | no; `package.py` adds them from the release assets in `external-assets.json`, except `Ext/` |
| `junk` (d) | not part of the product | no |
| `excluded` (e) | shipped by OXT Lite but not redistributed by this project because of its licence (`NOT_REDISTRIBUTABLE` in `layout.py`) | no; `import` removes them |
| `xtalk` (f) | the xTalk Suite extensions: `Extensions/<folder>/**` for every folder in `xtalk-extensions.json`, and `Extensions/XTALK-EXTENSIONS.txt` | no; `package.py` builds them with `xtalk_extensions.py` from their repositories at pinned commits; `import` never copies them into `ide/Extensions` |
| `unknown` | no rule matches: add a rule | - |

Excluded for licence reasons (not in the repository, its history or its
packages):

- `Documentation/linked_files/apple-human-interface-guidelines-2005.pdf`:
  Apple Inc. copyright, no licence to redistribute.
- `Documentation/linked_files/animationEngine6.zip`: a third-party library
  with no licence in the release.

### Mapping

All rules are in `RULES` in `layout.py`; the first matching rule wins. They
follow `Installer/package.txt` as run by `builder/tools_builder.livecodescript`
and `builder/package_compiler.livecodescript` (Windows: `TargetFolder`,
`SupportFolder` and `ToolsFolder` are all the install root).

| installed path | class | repository path | package.txt |
|---|---|---|---|
| `Toolset/libraries/` + the 11 ide-support scripts (revdeploylibrary{android,emscripten,ios}, revdocsparser, revhtml5urllibrary, revliburl, revsaveas{,android,emscripten,ios}standalone, revsblibrary) | ide | `ide-support/<name>` | Toolset: `stack`/`file ide-support:...` |
| `Toolset/palettes/dictionary/api.sqlite` | junk | | zero-byte file nothing refers to |
| `Toolset/**` | ide | `ide/Toolset/**` | Toolset: `rfolder ide:Toolset` |
| `Plugins/**` | ide | `ide/Plugins/**` | Plugins |
| `Resources/Mobile Examples/**` | ide | `ide/Resources/Mobile Examples/**` | Mobile.MacOSX (macOS only) |
| `Resources/Sample Icons/**` | unknown | | never installed there |
| `Resources/**` | ide | `ide/Resources/**` | Resources |
| `Documentation/**` | ide | `ide/Documentation/**` | Documentation (see below) |
| `Runtime/Windows/{x86-64,x86-32}/Support/Sample Icons/*` | ide | `ide/Resources/Sample Icons/*` | Runtime.Windows: `file ide:Resources/Sample Icons/*` |
| `.version`, `.buildnumber`, `about.dat`, `about.txt`, `License Agreement.txt`, `Open Source Licenses.txt`, `OpenXTalk-lite_1024.ico`, `OXT-Beyond.ico`, `Release Notes.pdf` | ide | `ide/<name>` | Misc (`about.txt`, licences); the rest are OpenXTalk Lite or OXT-Beyond additions |
| `Extensions/<folder>/**` for a folder in `xtalk-extensions.json`, `Extensions/XTALK-EXTENSIONS.txt` | xtalk | | not in package.txt: the bundled xTalk Suite extensions (before the next rule) |
| `Extensions/<id>/**` for an id not built here | ide | `ide/Extensions/<id>/**` | new folder, see below |
| `Extensions/<one of the 42 com.livecode.* ids>/**` | build | | Extensions: `packaged_extensions` built from `extensions/` |
| `Extensions/com.livecode.library.timezone/code/x86_64-win32/**` | build | | TimeZone (win-x86_64) |
| `Extensions/com.livecode.library.timezone/code/**` (other platforms) | external | | TimeZone (other platform builds) |
| `Extensions/com.livecode.library.timezone/resources/**` | external | | TimeZone: the zoneinfo data, compiled by `zic` only in macOS and Linux builds (`tz.gyp` target `tzdata`); upstream takes the whole extension from the macOS build |
| `*.exe`, `revpdfprinter.dll`, `revsecurity.dll` (root) | build | | Engine.Windows; `.setup.exe` is the Uninstaller |
| `edition.txt` | build | | Toolset: `emit variable TargetEdition` |
| `Externals/**`, `Toolchain/**` | build | | Externals, Databases, Externals.CEF.Windows, Mobile.Windows, Toolchain.Windows |
| `Runtime/Windows/x86-64/**` | build | | Runtime.Windows x86-64 |
| `Runtime/**` (Windows x86-32, Linux, Android, Emscripten, macOS, iOS) | external | | Runtime.* for other platforms |
| `Ext/**` | external | | Ext: mergExt collection downloaded by the builder |
| `*.lnk`, `test.db`, names starting with `.` below the root | junk | | |

Notes on the choices:

* **Toolset.** The packager generates nothing under `Toolset/`: in the stock
  9.6.3 package every one of the 988 Toolset files comes from `ide/Toolset`
  (977) or `ide-support` (11). Files that exist in OpenXTalk Lite's Toolset but
  not in the stock `ide/Toolset` are OpenXTalk Lite additions.
* **Documentation.** Upstream installs a selection of `ide/Documentation` plus
  `repo:docs/guides`, docs builder output (`html_viewer/resources/data/**`,
  `guides/Release Notes.md`) and a generated PDF. OpenXTalk Lite replaced this
  with its own tree (dictionary stack `oxt_dictionary.oxtstack`, its own
  `api.sqlite`, plain-text exports, PDFs, debranded guides, `linked_files`), so
  the whole installed `Documentation/` maps to `ide/Documentation/` and is
  tracked. Several guides are debranded copies of files under `docs/`
  (`docs/development`, `docs/specs`, `docs/guides`); they are kept as shipped.
* **ide/Extensions/** holds extensions the IDE ships but this repository does
  not build (their `.lcb` sources are included; the compiled `module.2.lcm`
  and `.lci` files are shipped as they are). In the repository layout the IDE
  loads extensions only from `<build>/packaged_extensions`
  (`revEnvironmentExtensionsPaths` in `Toolset/home.livecodescript`), so
  packaging has to place these in `Extensions/`.
* **Root files.** The IDE reads `.version`, `.buildnumber` and `about.dat` from
  the folder above `Toolset/` (`revmenubar.livecodescript`), which is `ide/`
  in the repository layout. `edition.txt` is written by the packager and stays
  ignored. OpenXTalk Lite 1.07 and earlier ship their own `Release Notes.pdf`
  (upstream generates one).
* **Sample Icons** are installed twice (x86-64 and x86-32 runtime folders);
  both copies must be identical, and `assemble` writes both.
* **Junk.** `OpenXTalk Lite.lnk` is a shortcut left by the install script; in
  1.15 it points at the 1.07 file name `OpenXTalk Lite.exe` (the 1.15 engine is
  `OpenXTalk-Lite.exe`) and contains a machine name and user SID. `test.db` and
  `Toolset/palettes/dictionary/api.sqlite` are zero-byte SQLite files; no
  script refers to the latter (the IDE and the Quick Dictionary plugin use
  `Documentation/html_viewer/resources/data/api/api.sqlite`).

### Managed files

`import` and `assemble` work on the managed set only: the files under
`ide/Toolset`, `ide/Plugins`, `ide/Resources`, `ide/Documentation`,
`ide/Extensions`, the root files listed above and the 11 `ide-support`
scripts, except

* names starting with `.` inside those folders (upstream packaging skips
  them), and
* `ide/Resources/Mobile Examples` (installed on macOS only; a Windows install
  says nothing about them).

Everything else (`ide/.gitignore`, `ide/.gitattributes`, `ide/README.md`,
`ide/tests`, `ide/notes`, `ide/examples`, the release-notes PDFs at the root of
`ide/`, the other `ide-support` files, `docs/`, engine sources) is never
written or deleted. Ignored files that happen to be in a managed folder (for
example docs builder output in `ide/Documentation/html_viewer/resources/data`)
are treated like any other file there.

### Stock LiveCode packages (`verify --upstream`)

A stock LiveCode install differs from `ide/` in ways that are expected:
`Release Notes.pdf`, `Documentation/guides/**` from `repo:docs/guides` and the
docs builder, `Documentation/html_viewer/resources/data/**` (docs builder
output) and `Documentation/pdf/**` exist in the install only, and
`Plugins/livecodeTestInterface.livecode`, `Documentation/Docs Helper.livecode`,
`Documentation/dictionary/**` and `Documentation/specs/**` are in `ide/` but not
packaged. `--upstream` accepts exactly these (`UPSTREAM_DIFFERENCES`) as
long as they are missing on one side; any content difference still fails.

### Git

* Case-only renames: `import` reports paths whose letter case changes. With
  `core.ignorecase` (the Windows default) git does not see such a rename by
  itself; record it with `git rm --cached -q -- <old>` and `git add -- <new>`.
* Empty folders cannot be stored in git. `verify` lists empty folders of the
  install (1.15 has two, under
  `Documentation/html_viewer/resources/data/api/exports/{builder,datagrid}/plugins`).
* `ide/.gitignore` un-ignores the shipped files that its general rules (and
  `*.xz` in the top-level `.gitignore`) would hide: the dictionary database and
  data scripts, `Documentation/linked_files/*.zip`, `Resources/MacOs/*.zip` and
  the Linux theme archive.
* The longest managed path is 142 characters; a checkout in a deep
  folder on Windows may need `core.longpaths`.

### OpenXTalk Lite 1.15 import

Source: `openxtalk-lite-1.15-win-noinstaller.7z` (`.version` 1.15,
`.buildnumber` 202605052228), 7,211 files. `classify` at the time of the
import: 5,898 ide, 966 build (406.3 MB), 342 external (452.6 MB), 3 junk and
2 excluded (8.1 MB, see above). Since the timezone zoneinfo data (474 files)
became class external, the counts are 5,898 ide, 492 build (405.8 MB), 816
external (453.1 MB), 3 junk and 2 excluded. The 5,898 ide files are 5,896
repository files (the two Sample Icons are installed twice). The counts in
the table below were taken before the two excluded files were removed from
the import.

| area | added | modified | deleted | unchanged |
|---|---:|---:|---:|---:|
| ide (root files) | 4 | 1 | 1 | 1 |
| ide-support | 0 | 5 | 0 | 6 |
| ide/Documentation | 3,789 | 50 | 8 | 405 |
| ide/Extensions | 24 | 0 | 0 | 0 |
| ide/Plugins | 3 | 0 | 9 | 0 |
| ide/Resources | 16 | 0 | 14 | 155 |
| ide/Toolset | 553 | 337 | 91 | 549 |
| total | 4,389 | 393 | 123 | 1,116 |

Four of the Documentation deletions and two of its modifications were ignored,
locally generated docs builder files, not tracked files. `verify` of 1.15
against the repository passes (5,900 identical; 5,898 with the rules as they
are now, which leave out the two excluded files); so does `verify` of a copy
staged into a scratch git index and checked out again with `core.autocrlf`
true and false. `verify --upstream` of the stock LiveCode Community 9.6.3
Windows package (rebuilt from the payload in its `.setup.exe`) against the
original `ide/` and `ide-support/` passes: 1,624 identical, 35 expected
differences.

## Packaging (`package.py`)

```
python tools/oxt/package.py --repo <repo> --bin <repo>/win-x86_64-bin --out <stage-parent>
    [--build-number N] [--assets-cache DIR] [--no-external-assets] [--offline]
    [--no-xtalk-extensions] [--vc-redist DIR] [--xtalk-cache DIR] [--xtalk-manifest FILE]
    [--eol lf|crlf|keep] [--summary-json FILE]
    [--compare <installed folder or classify TSV> [--report FILE]]
```

writes the installed program folder to `<stage-parent>/OXT-Beyond-<version>/`
(`<version>` is `ide/.version`; an existing folder of that name is replaced).
`tools/ci/package-windows.ps1` runs it into `dist/stage` and zips the result
as the portable package; the installer is built from the same folder. Nothing
is written when the plan has a problem (a missing build output, two sources
for one path, an asset that fails its checksum). Exit status: 0 success, 1
unexplained differences from `--compare`, 2 errors.

The folder is put together from:

* **IDE**: `layout.py` assemble (all class `ide` paths, including the Sample
  Icons in both `Runtime/Windows/<arch>/Support`). Text files are written with
  LF line endings (`--eol lf`, the default), as git stores them and as OXT Lite
  1.15 shipped nearly all of them, so the result does not depend on
  `core.autocrlf`. `.buildnumber` is replaced by the build number:
  `--build-number`, else `OXT_BUILD_NUMBER`, else the UTC time as
  `YYYYMMDDHHMM`; `ide/.buildnumber` is a placeholder.
* **Build outputs**, placed as `Installer/package.txt` places them for Windows
  x86-64 Community with `TargetFolder`, `SupportFolder` and `ToolsFolder` all
  the install root:

  | build output (`win-x86_64-bin/`) | installed path | package.txt |
  |---|---|---|
  | `LiveCode-Community.exe` | `OXT-Beyond.exe` | Engine.Windows (`as [[ProductName]].exe`) |
  | `revpdfprinter.dll`, `revsecurity.dll` | root | Engine.Windows |
  | `revspeech.dll`, `revxml.dll`, `revbrowser.dll`, `revzip.dll`, `revdb.dll` | `Externals/` | Externals.Windows, Databases.Windows |
  | `dbmysql.dll`, `dbodbc.dll`, `dbpostgresql.dll`, `dbsqlite.dll` | `Externals/Database Drivers/` | Databases.Windows |
  | `libbrowser-cefprocess.exe`, `revbrowser-cefprocess.exe` (build root) | `Externals/CEF/` | Externals.CEF.Windows |
  | `Externals/CEF/`: `libcef.dll`, `d3dcompiler_47.dll`, `libEGL.dll`, `libGLESv2.dll`, `chrome_elf.dll`, the `.pak`, `.dat` and `.bin` files, `swiftshader/*`, `locales/**` | `Externals/CEF/` | Externals.CEF.Windows |
  | `revandroid.dll` | `Externals/` | Mobile.Windows |
  | `lc-compile.exe`, `lc-run.exe`, `lc-compile-ffi-java.exe`, `modules/**` | `Toolchain/`, `Toolchain/modules/` | Toolchain.Windows |
  | `standalone-community.exe` | `Runtime/Windows/x86-64/Standalone` (no extension) | Runtime.Windows |
  | `w32-manifest-template*.xml` (3) | `Runtime/Windows/x86-64/` | Runtime.Windows |
  | `revpdfprinter.dll`, `revsecurity.dll` | `Runtime/Windows/x86-64/Support/` | Runtime.Windows |
  | the Externals rows above (without `revandroid.dll`) | `Runtime/Windows/x86-64/Externals/...` | Runtime x86-64: `include Externals` |
  | `packaged_extensions/<id>/**` for the 42 ids in `REPO_BUILT_EXTENSIONS` | `Extensions/<id>/**` | Extensions, TimeZone |

* **Generated files**: `edition.txt` (`community`, no line break);
  `Externals.txt` (`Speech,revspeech.dll`, `XML,revxml.dll`,
  `Browser,revbrowser.dll`, `Revolution Zip,revzip.dll`, `Database,revdb.dll`)
  and `Database Drivers/Database Drivers.txt` (`MySQL,dbmysql.dll`,
  `ODBC,dbodbc.dll`, `PostgreSQL,dbpostgresql.dll`, `SqLite,dbsqlite.dll`),
  CRLF line endings, in both `Externals/` and
  `Runtime/Windows/x86-64/Externals/`; all five generated build files are
  byte-identical to OXT Lite 1.15's. The empty folders
  `Documentation/html_viewer/resources/data/api/exports/{builder,datagrid}/plugins`.
* **Licence files**: `LICENSE`, `LICENSE-EXCEPTION.md` and
  `THIRD-PARTY-NOTICES.md` from the repository root, with CRLF line endings.
* **External assets** from `external-assets.json` (`--no-external-assets`
  leaves them out).
* **xTalk Suite extensions** from `xtalk-extensions.json`: `package.py`
  runs `xtalk_extensions.build` with the `--bin` build's `lc-compile` and
  `modules/lci` into a temporary folder and stages every file under
  `Extensions/` byte for byte (origin `xtalk`), plus
  `Extensions/XTALK-EXTENSIONS.txt`. `--vc-redist` is passed through (the
  Visual C++ runtime DLLs for enetxt and Box2Dxt); without it packaging
  warns. The cache is `--xtalk-cache`, else `OXT_XTALK_CACHE`, else the
  `xtalk` folder of the asset cache; `--offline` applies to it too.
  `--no-xtalk-extensions` leaves them out. The summary (and
  `--summary-json`: `xtalk_extensions`, `vc_redist_version`,
  `vc_runtime_files`, `xtalk_missing_runtime`) lists them.

Build outputs that are not installed (every run lists them): `*.pdb` (they go
into the symbols zip), `installer.exe` (OXT-Beyond uses Inno Setup),
`server-*` (package.txt installs no server engine),
`Externals/CEF/devtools_resources.pak` (not in package.txt), the second copies
of the two CEF helper executables in `Externals/CEF/` (package.txt takes the
identical copies at the build root), and `packaged_extensions/` for
`com.livecode.library.canvas` and `com.livecode.library.ini` (not in
package.txt; neither LiveCode 9.6.3 nor OXT Lite 1.15 ships them). Build
outputs that no rule covers are listed with a warning.

### Checking a package against OpenXTalk Lite 1.15

`--compare` checks the staged folder against a reference install or a
`layout.py classify` TSV (also a part of one, such as its `build` rows).
Every `ide`, `build` and `external` path of the reference must be staged,
with the engine under its new name, unless `INTENDED_MISSING` gives a reason;
every staged path of the classes the reference lists must be in it unless it
is an intended addition. With a folder, external asset files must be
byte-identical to the reference and empty folders must match. IDE changes
since the reference are listed but are not errors. `--report` writes the
status of every path as TSV.

Intended differences from OXT Lite 1.15:

| path | why |
|---|---|
| `OpenXTalk-Lite.exe` | staged as `OXT-Beyond.exe` |
| `Ext/**` (46 files) | the mergExt collection is not redistributed (licence unclear) |
| `Toolchain/modules/lci/` `com.livecode.library.native.android.barcode`, `...barcodesupport`, `com.livecode.library.native.speech`, `com.livecode.library.securekey`, `com.livecode.widget.native.android.barcodescanner`, `com.livecode.widget.native.map`, `com.livecode.widget.pdf`, `com.livecode.widget.pdf.pdfium`, `com.livecode.widget.signature` (`.lci`) | interfaces of LiveCode commercial-edition modules. OXT Lite 1.15's `Toolchain/` is the stock LiveCode 9.6.3 one (all 78 files identical), which has them; the modules are not in this repository and the IDE does not use them |
| `Toolchain/modules/lci/com.livecode.commercial.license.lci` | also from stock 9.6.3; this repository compiles `engine/src/license.lcb` into lc-compile (`engine_syntax_only_lcb_files`) and writes no `.lci` for it |
| the 3 junk and 2 excluded files | see [Classes](#classes) |
| `LICENSE`, `LICENSE-EXCEPTION.md`, `THIRD-PARTY-NOTICES.md` | added: OXT-Beyond's licence files |
| `PROVENANCE-oxt-runtimes-1.15.md` | added: provenance of the runtimes asset |
| `Extensions/<xTalk folders>/**`, `Extensions/XTALK-EXTENSIONS.txt` | added: the xTalk Suite extensions (class `xtalk`); against a reference that has them they are compared like build outputs, and `--no-xtalk-extensions` makes them intended differences |

Result with the CI build of this repository
(`OpenXTalkLite-9.7.1-OXT-win-x86_64-binaries.zip`), the runtimes asset and
the IDE as it was when this was written, compared with the 1.15 install:
`COMPARE PASSED`. All 5,898 `ide` paths are staged (7 of them already changed
and 2 files added by the OXT-Beyond branding and updater work); of the 492
`build` paths, 482 are staged (320 byte-identical to 1.15, 157 rebuilt, 5
generated and identical) and 10 are intended differences; all 770
redistributed `external` paths are staged and byte-identical; the 7 empty
folders match. Against the 966 class `build` rows of the 1.15 import (taken
before the zoneinfo data became external): 956 staged, 10 intended
differences.

## External assets

`external-assets.json` lists archives that packaging adds to the installed
layout: files this repository does not build, kept out of git and published
as GitHub Release assets. Now these are the other-platform runtimes from OXT
Lite 1.15. (The xTalk Suite extensions are not assets: see
[below](#xtalk-suite-extensions-xtalk_extensionspy).)

```json
{
  "assets": [
    {
      "id": "oxt-runtimes-1.15",
      "url": "https://github.com/SethMorrowSoftware/winoxt/releases/download/runtimes-1.15/oxt-runtimes-1.15.zip",
      "sha256": "<64 lowercase hex digits>",
      "size": 199237317,
      "kind": "zip",
      "strip": 1,
      "dest": "",
      "rename": { "PROVENANCE.md": "PROVENANCE-oxt-runtimes-1.15.md" },
      "description": "...", "licence": "...", "source": "..."
    }
  ]
}
```

* `url` must be HTTPS; `size` and `sha256` pin the archive.
* `kind` is `zip` (the only kind so far). `strip` removes that many leading
  folders from every member; the rest is placed under `dest` (relative to the
  installed root; `""` is the root). `rename` (optional) maps a member path,
  after `strip`, to another path under `dest`. Directory entries become
  folders, so empty folders are kept. Absolute paths, `..`, drive letters and
  names Windows cannot store are rejected; two members may not map to the
  same path, and a path claimed both by an asset and by the IDE or the build
  is an error.
* `description`, `licence` and `source` are for people.

The cache folder is `--assets-cache`, else `OXT_ASSETS_CACHE`, else
`prebuilt/fetched-assets` (ignored by git). An archive whose file name (the
last part of the URL) is in the cache with the right size and SHA-256 is used
as it is, so an asset can be tested before it is published by pointing
`--assets-cache` at the folder that holds it. Otherwise it is downloaded over
HTTPS (redirects are followed, only to HTTPS URLs) to `<name>.part`, with up
to 4 attempts for network errors, HTTP 408/425/429/5xx and cut-off
transfers, and moved into place once size and SHA-256 match. A complete
download that does not match, and any other HTTP error, is fatal. `--offline`
never downloads.

```
python tools/oxt/fetch_assets.py [--manifest FILE] [--assets-cache DIR] [--id ID] [--offline] [--list]
```

fetches and verifies the assets without packaging (for example to fill a CI
cache).

## xTalk Suite extensions (`xtalk_extensions.py`)

```
python tools/oxt/xtalk_extensions.py [--manifest FILE] pin   [--member NAME] [--ref REF [--allow-off-branch]]
                                     [--cache DIR | --no-cache]
python tools/oxt/xtalk_extensions.py [--manifest FILE] fetch [--cache DIR] [--offline] [--platforms LIST] [--member NAME]
python tools/oxt/xtalk_extensions.py [--manifest FILE] build --bin DIR --out DIR [--vc-redist DIR]
                                     [--cache DIR] [--offline] [--platforms LIST] [--summary-json FILE]
python tools/oxt/xtalk_extensions.py [--manifest FILE] export --out FILE.zip [--cache DIR] [--offline]
python tools/oxt/xtalk_extensions.py [--manifest FILE] list
```

`xtalk-extensions.json` pins the eight xTalk Suite member repositories
(`SethMorrowSoftware/<repository>`) at commits and lists, per member, the
files taken (with the SHA-256 and size of each Git blob, and the DLLs each
Windows library imports) and the extensions made from them (kind `lcb` or
`lcs`, id, folder, main file, the smoke test's probe and expected value,
and for script libraries the stack name, title, author and `requires`).
BUILDING.md describes the fields
([xTalk Suite extensions](../../BUILDING.md#xtalk-suite-extensions)).
Nothing of the members is kept in this repository.

* `pin` resolves the commit of each member (or `--member`; `--ref` a
  branch, tag or commit, default the head of the default branch) with
  `git ls-remote` or the GitHub API. A `--ref` commit must be on the
  member's default branch (one call of the GitHub compare API,
  `compare/<commit>...HEAD`, status `ahead` or `identical`): a SHA-1
  always, because `raw.githubusercontent.com` serves every commit of the
  repository's fork network, including forks and unmerged pull requests;
  a branch or tag named with `--ref` unless `--allow-off-branch`, because
  its commit disappears when the branch is deleted. It downloads every
  listed file from
  `https://raw.githubusercontent.com/<repository>/<commit>/<path>` and
  rewrites the manifest (commit, version from `version_from`, `sha256`,
  `size`, `imports`) without changing its order or layout. It checks the
  libraries against the member's `src/code/MANIFEST.sha256` (and that
  file lists no library the manifest does not take), that each LCB source
  still declares the extension's module id and that each script library's
  `script` line, if any, names its stack. It also stores the downloads in
  the cache. Files with a `repository` and `commit` of their own
  (OpenSSL's licence text) keep their commit.
* `fetch` puts every pinned file into the cache
  (`<cache>/<repository>/<commit>/<path>`; `--cache`, else
  `OXT_XTALK_CACHE`, else the `xtalk` folder of the asset cache
  (`OXT_ASSETS_CACHE`, default `prebuilt/fetched-assets/xtalk`), the
  same folder `package.py` uses) and verifies
  size and SHA-256; a file that does not match is deleted. Downloads go
  through `fetch_assets.fetch` (HTTPS only, retries with backoff).
  `--platforms` limits the native libraries to some platform ids.
* `build` fetches, then writes one folder per extension into `--out` and
  `XTALK-EXTENSIONS.txt` (the extensions with their commits, and the
  Visual C++ runtime DLLs bundled or missing):

  | kind | folder | contents |
  |---|---|---|
  | `lcb` | the module id | `<name>.lcb`, `module.lcm` and `manifest.xml` from `lc-compile --modulepath <bin>/modules/lci --interface <temp>/<id>.lci --manifest manifest.xml --output module.lcm <name>.lcb` (run in the folder, no `-Werror`), `code/<platform-id>/<library>` for every platform id, `licenses/` |
  | `lcs` | the stack name | `<stack>.livecodescript` (the pinned file with `script "<stack>"` added as line 1 if it has no such line, and an `extensionInitialize` / `extensionFinalize` pair appended), `manifest.xml` written from the JSON, `licenses/` |

  With `--vc-redist` (Visual Studio's `VC\Redist\MSVC\<version>`), every
  DLL a library in `code/x86_64-win32` or `code/x86-win32` imports that
  is neither a Windows system DLL nor in the folder is copied from the
  redistributable into the folder, and the copies must export what the
  library imports from them (which catches a redistributable that lacks a
  function, not every older one). The build warns when a copy's file
  version (from its `VS_VERSION_INFO`) is older than the MSVC linker
  version of the library that imports it, and `XTALK-EXTENSIONS.txt`
  records each copy's SHA-256 and file version. Without `--vc-redist`
  the build warns and lists the libraries concerned. The build fails if `modules/lci` changed while it
  ran, if a library's imports differ from the manifest's, or if
  `lc-compile` fails. Folders listed in an earlier
  `XTALK-EXTENSIONS.txt` of `--out` and the folders of the current
  manifest are replaced; nothing else in `--out` is touched. The output is
  the same for the same pins and `lc-compile`.
* `export` fetches, then writes every pinned file (all members and
  platforms) into a zip in the cache layout `<repository>/<commit>/<path>`,
  with a copy of the manifest (LF line endings) and a `README.txt`.
  Entries are sorted and dated 1980-01-01, so the same pins give the same
  zip. Tag builds publish it with the release
  (`OXT-Beyond-<ver>-xtalk-sources.zip`, `package-windows.ps1
  -XtalkSourcesZip`), so that a release can be rebuilt with the extracted
  folder as the cache (`--cache DIR --offline`) if a member repository
  loses a pinned commit.
* `list` prints the members, their extensions and probes, and the
  libraries that need DLLs other than Windows system DLLs.

Exit status 0 on success, 1 on any error.

## The runtimes asset

```
python tools/oxt/make_runtimes_asset.py "<OXT Lite 1.15 install>" --out DIR
    [--stock-setup "<LiveCode Community 9.6.3 install>\.setup.exe"]
    [--source-archive openxtalk-lite-1.15-win-noinstaller.7z] [--update-manifest]
```

builds `oxt-runtimes-1.15.zip` from the 1.15 install: every class `external`
file under `Runtime/Windows/x86-32/`, `Runtime/Linux/`, `Runtime/Android/`
and `Extensions/com.livecode.library.timezone/{code,resources}/` (not `Ext/`),
unchanged, under one top folder `oxt-runtimes-1.15/`, with the empty folders
of those trees and a generated `PROVENANCE.md`. PROVENANCE.md lists every
file with its size, SHA-256 and date and, with `--stock-setup`, whether it is
byte-identical to the file that the stock LiveCode Community 9.6.3 Windows
installer installs at the same path (read from the package payload of an
installed copy's `.setup.exe`, which is only read). It also gives the engine
version strings found in each `Standalone` and where the corresponding source
is. The zip is reproducible (sorted entries; the files' dates, in UTC).
`--update-manifest` writes its size and SHA-256 into `external-assets.json`.

| folder | files | same as stock 9.6.3 | notes |
|---|---:|---:|---|
| `Runtime/Windows/x86-32` | 86 | 86 | engine `9.6.3` |
| `Runtime/Linux/x86-32` | 104 | 10 | `Standalone` (`9.6.3-rc-3`, dated 2026-05-31) and the two `.txt` lists differ; `lib/` has 91 shared library files of other projects |
| `Runtime/Linux/x86-64` | 45 | 0 | `Standalone` reports `9.7.1-OXT` (dated 2026-05-31); both `Support` libraries differ; `lib/` has 42 shared library files of other projects; no externals |
| `Runtime/Android` | 38 | 31 | the four `Standalone` engines (`9.6.3-rc-3`), `Classes`, `Manifest.xml` and arm64 `DbMysql` differ |
| timezone `code/` (all but x86_64-win32) | 23 | 17 | the macOS and iOS simulator `tz.dylib` differ |
| timezone `resources/zoneinfo` | 474 | 474 | |

770 files, 449,955,398 bytes; the zip is 199,237,317 bytes. In the packaged
program its provenance file is `PROVENANCE-oxt-runtimes-1.15.md`.

Publishing (maintainer, after review): create the release `runtimes-1.15`
as a pre-release and upload `oxt-runtimes-1.15.zip` and its
`PROVENANCE.md` to it, with the same command as in
[BUILDING.md](../../BUILDING.md#external-assets):

```
gh release create runtimes-1.15 oxt-runtimes-1.15.zip PROVENANCE.md --prerelease \
    --title "Standalone runtimes from OpenXTalk Lite 1.15" \
    --notes "Prebuilt files used by tools/oxt/package.py. See PROVENANCE.md (also inside the zip)."
```

A pre-release never becomes the repository's latest release: the IDE's
update check reads `releases/latest`, which has to stay an OXT-Beyond
release. Until the asset is published, packaging fails at the download
(HTTP 404) unless the assets are left out (`--no-external-assets`,
`package-windows.ps1 -NoExternalAssets`, or in CI the workflow input
`no_external_assets` or the repository variable `OXT_NO_EXTERNAL_ASSETS=1`)
or a cache that holds the zip is given.
