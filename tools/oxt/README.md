# OXT layout tool

`layout.py` maps an installed OpenXTalk Lite (or stock LiveCode 9.x) Windows
program folder to this repository's layout and back. It is how the IDE of an
OpenXTalk Lite release is imported into `ide/` and `ide-support/`, and how an
import is checked. It needs only Python 3 (standard library).

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

## Classes

| class | meaning | in git |
|---|---|---|
| `ide` (a) | IDE content, mapped to a repository path | yes |
| `build` (b) | produced by building or packaging this repository | no |
| `external` (c) | binaries for other platforms and third-party collections this repository does not build | no (to be provided separately, for example as a release asset) |
| `junk` (d) | not part of the product | no |
| `excluded` (e) | shipped by OXT Lite but not redistributed by this project because of its licence (`NOT_REDISTRIBUTABLE` in `layout.py`) | no; `import` removes them |
| `unknown` | no rule matches: add a rule | - |

Excluded for licence reasons (not in the repository, its history or its
packages):

- `Documentation/linked_files/apple-human-interface-guidelines-2005.pdf`:
  Apple Inc. copyright, no licence to redistribute.
- `Documentation/linked_files/animationEngine6.zip`: a third-party library
  with no licence in the release.

## Mapping

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
| `.version`, `.buildnumber`, `about.dat`, `about.txt`, `License Agreement.txt`, `Open Source Licenses.txt`, `OpenXTalk-lite_1024.ico`, `Release Notes.pdf` | ide | `ide/<name>` | Misc (`about.txt`, licences); the rest are OpenXTalk Lite additions |
| `Extensions/<id>/**` for an id not built here | ide | `ide/Extensions/<id>/**` | new folder, see below |
| `Extensions/<one of the 42 com.livecode.* ids>/**` | build | | Extensions: `packaged_extensions` built from `extensions/` |
| `Extensions/com.livecode.library.timezone/code/x86_64-win32/**` | build | | TimeZone (win-x86_64) |
| `Extensions/com.livecode.library.timezone/code/**` (other platforms) | external | | TimeZone (other platform builds) |
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

## Managed files

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

## Stock LiveCode packages (`verify --upstream`)

A stock LiveCode install differs from `ide/` in ways that are expected:
`Release Notes.pdf`, `Documentation/guides/**` from `repo:docs/guides` and the
docs builder, `Documentation/html_viewer/resources/data/**` (docs builder
output) and `Documentation/pdf/**` exist in the install only, and
`Plugins/livecodeTestInterface.livecode`, `Documentation/Docs Helper.livecode`,
`Documentation/dictionary/**` and `Documentation/specs/**` are in `ide/` but not
packaged. `--upstream` accepts exactly these (`UPSTREAM_DIFFERENCES`) as
long as they are missing on one side; any content difference still fails.

## Git

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

## OpenXTalk Lite 1.15 import

Source: `openxtalk-lite-1.15-win-noinstaller.7z` (`.version` 1.15,
`.buildnumber` 202605052228), 7,211 files. `classify`: 5,898 ide, 966 build
(406.3 MB), 342 external (452.6 MB), 3 junk and 2 excluded (8.1 MB, see
above). The 5,898 ide files are 5,896 repository files (the two Sample Icons
are installed twice). The counts in the table below were taken before the
two excluded files were removed from the import.

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
against the repository passes (5,900 identical); so does `verify` of a copy
staged into a scratch git index and checked out again with `core.autocrlf`
true and false. `verify --upstream` of the stock LiveCode Community 9.6.3
Windows package (rebuilt from the payload in its `.setup.exe`) against the
original `ide/` and `ide-support/` passes: 1,624 identical, 35 expected
differences.
