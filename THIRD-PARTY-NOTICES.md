# Third-party notices

OXT-Beyond is licensed under the GNU General Public License, version 3
([LICENSE](LICENSE)); [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md)
describes an additional permission and which parts it covers. The
OXT-Beyond packages (the installer, the portable zip and the binaries
zip) also contain software and content written by other people under
other terms. This file lists them, with their licence and where the
licence text can be found.

It covers the Windows x86-64 packages and this repository. Versions are
the ones this repository builds or ships today. Paths in the text are
relative to the repository root; "where it ends up" gives the path in
the installed program folder. Links point to the upstream licence text
for the matching version where the text is not in this repository.

This list was put together by reading the build files, the file headers
and the contents of the prebuilt archives and of OpenXTalk Lite 1.15. It
may be incomplete. If you spot something missing or wrong, please open
an issue.

Contents:

- [Prebuilt libraries](#prebuilt-libraries)
- [Libraries built from `thirdparty/`](#libraries-built-from-thirdparty)
- [Third-party code inside LiveCode's own sources](#third-party-code-inside-livecodes-own-sources)
- [The IDE](#the-ide)
- [xTalk Suite extensions](#xtalk-suite-extensions)
- [Standalone runtimes for other platforms](#standalone-runtimes-for-other-platforms)
- [Files OpenXTalk Lite shipped that OXT-Beyond does not](#files-openxtalk-lite-shipped-that-oxt-beyond-does-not)
- [The installer](#the-installer)
- [Microsoft components](#microsoft-components)
- [GENTLE](#gentle)
- [Build-time tools (not shipped)](#build-time-tools-not-shipped)
- [Still to review](#still-to-review)

## Prebuilt libraries

These come from the
[`prebuilts-v1` release](https://github.com/SethMorrowSoftware/winoxt/releases/tag/prebuilts-v1),
which mirrors, unchanged, the archives LiveCode Ltd's build servers
produced. The archives contain no licence files of their own.

| Component | Version | Where it ends up | Licence | Licence text |
| --- | --- | --- | --- | --- |
| Chromium Embedded Framework (CEF) | 74.1.19+gb62bacf | `Externals/CEF/libcef.dll` and resources; used by the browser widget and revBrowser | BSD 3-clause | [`thirdparty/libcef/LICENSE.txt`](thirdparty/libcef/LICENSE.txt), [upstream](https://github.com/chromiumembedded/cef/blob/master/LICENSE.txt) |
| Chromium (inside CEF, including V8 and `chrome_elf.dll`) | 74.0.3729.157 | `Externals/CEF/` (`libcef.dll`, `*.pak`, `icudtl.dat`, `*_blob.bin`, `v8_context_snapshot.bin`) | BSD 3-clause for Chromium's own code; Chromium includes many other components under their own licences (see `third_party/` in the Chromium source for that version) | [Chromium LICENSE](https://github.com/chromium/chromium/blob/74.0.3729.157/LICENSE) |
| ANGLE | as bundled with Chromium 74 | `Externals/CEF/libEGL.dll`, `libGLESv2.dll` | BSD 3-clause | [upstream](https://github.com/google/angle/blob/main/LICENSE) |
| SwiftShader | as bundled with Chromium 74 | `Externals/CEF/swiftshader/` | Apache License 2.0 | [upstream](https://github.com/google/swiftshader/blob/master/LICENSE.txt) |
| Direct3D shader compiler (`d3dcompiler_47.dll`) | as shipped in the CEF binary distribution | `Externals/CEF/` | Microsoft redistributable file, not open source; Microsoft's terms apply | not in this repository |
| OpenSSL | 1.1.1g | statically linked into `revsecurity.dll` (which the engines and database drivers use for SSL and encryption) and into the server engine | OpenSSL License and original SSLeay License | [upstream](https://github.com/openssl/openssl/blob/OpenSSL_1_1_1g/LICENSE); an older copy is in [`ide/Open Source Licenses.txt`](ide/Open%20Source%20Licenses.txt) |
| libcurl | 7.51.0 | statically linked into the server engine (`server-community.exe`, in the binaries zip only) | curl licence (MIT/X style) | [upstream](https://github.com/curl/curl/blob/curl-7_51_0/COPYING); also in `ide/Open Source Licenses.txt` |
| ICU | 58.2 | statically linked into the engines and tools (through libfoundation) | Unicode licence ("ICU 58 and later"), plus the older ICU licence and third-party data notices in the same file | [upstream](https://github.com/unicode-org/icu/blob/release-58-2/icu4c/LICENSE) |

OpenSSL 1.1.1g, curl 7.51.0, ICU 58.2 and CEF/Chromium 74 are old and
no longer supported upstream. See [SECURITY.md](SECURITY.md).

## Libraries built from `thirdparty/`

The "Thirdparty" prebuilt archive holds static libraries built from the
`thirdparty/` tree (upstream `livecode-thirdparty` at commit
`e5e050573c226f60acfbb9107c2b4aea853b0cbe`, now vendored in this
repository). A few pieces, such as the CEF C++ wrapper, are compiled
from `thirdparty/` during the normal build instead. Either way the
source and, where upstream provided it, the licence text are in
`thirdparty/`.

| Component | Version | Used by | Licence | Licence text |
| --- | --- | --- | --- | --- |
| cairo (including pixman) | 1.9.4 | revPDFPrinter (on Windows the server engine does not link it) | LGPL 2.1 or MPL 1.1, at your choice (pixman: MIT-style) | [`thirdparty/libcairo/docs/`](thirdparty/libcairo/docs/) (`COPYING`, `COPYING-LGPL-2.1`, `COPYING-MPL-1.1`); pixman terms are in the headers of `thirdparty/libcairo/src/pixman*` |
| CEF C++ wrapper and headers | 74.1.16 (`thirdparty/libcef/include/cef_version.h`) | browser widget, revBrowser | BSD 3-clause | [`thirdparty/libcef/LICENSE.txt`](thirdparty/libcef/LICENSE.txt) |
| libffi | git commit `ee718066` | LiveCode Builder runtime, `lc-compile`, `lc-run` | MIT | file headers in `thirdparty/libffi/`, [upstream](https://github.com/libffi/libffi/blob/master/LICENSE) |
| giflib | 5.1.4 | engines, libgraphics | MIT | [`thirdparty/libgif/docs/COPYING`](thirdparty/libgif/docs/COPYING) |
| libjpeg (IJG) | 9b | engines, libgraphics | IJG licence | "LEGAL ISSUES" in [`thirdparty/libjpeg/docs/README`](thirdparty/libjpeg/docs/README) |
| libpng | 1.6.26 | engines, libgraphics | libpng licence | [`thirdparty/libpng/docs/LICENSE`](thirdparty/libpng/docs/LICENSE) |
| zlib | 1.2.8 | engines, revZip, revXML | zlib licence | "Copyright notice" in [`thirdparty/libz/docs/README`](thirdparty/libz/docs/README) |
| libzip | not recorded | revZip | BSD 3-clause | [`thirdparty/libzip/docs/LICENSE`](thirdparty/libzip/docs/LICENSE) |
| PCRE | 8.39 | engines | BSD | [`thirdparty/libpcre/docs/LICENCE`](thirdparty/libpcre/docs/LICENCE) |
| Skia | revision `20471894` | engine, libgraphics | BSD 3-clause | [upstream](https://github.com/google/skia/blob/main/LICENSE); file headers in `thirdparty/libskia/` |
| libxml2 | 2.9.4 | revXML | MIT | [`thirdparty/libxml/docs/COPYING`](thirdparty/libxml/docs/COPYING) |
| libxslt and libexslt | as vendored | revXML | MIT-style | [`thirdparty/libxslt/Copyright`](thirdparty/libxslt/Copyright) |
| SQLite | 3.51.1 | `dbsqlite.dll` | Public domain | header of `thirdparty/libsqlite/include/sqlite3.h`, [sqlite.org/copyright.html](https://www.sqlite.org/copyright.html) |
| sqlitedataset | 0.1.0 | `dbsqlite.dll` | MIT | [`thirdparty/libsqlite/docs/LICENSE`](thirdparty/libsqlite/docs/LICENSE) |
| MySQL Connector/C | 6.0.0 | `dbmysql.dll` | GPL version 2 with the MySQL FLOSS License Exception (version 0.6) | [`thirdparty/libmysql/docs/COPYING`](thirdparty/libmysql/docs/COPYING) and [`EXCEPTIONS-CLIENT`](thirdparty/libmysql/docs/EXCEPTIONS-CLIENT) |
| libpq (from PostgreSQL) | 8.1.8 | `dbpostgresql.dll` | PostgreSQL licence | [`thirdparty/libpq/docs/COPYRIGHT`](thirdparty/libpq/docs/COPYRIGHT) |

Not used by the Windows build, although present in `thirdparty/`:
FreeType, HarfBuzz and expat (Android, Linux and HTML5 builds only), and
iODBC (the Windows ODBC driver uses the system `odbc32.dll`). Their
licences are in `thirdparty/libfreetype/docs/`,
`thirdparty/libexpat/NOTICE` and `thirdparty/libiodbc/docs/`.

## Third-party code inside LiveCode's own sources

| Component | Where | Licence |
| --- | --- | --- |
| bsdiff (Colin Percival) | `engine/src/bsdiff_build.cpp`, `bsdiff_apply.cpp` | BSD 2-clause, in the file |
| SHA-2 and SHA-3 code from RHash (Aleksey Kravchenko) | `engine/src/sha256.cpp`, `sha512.cpp`, `sha3.cpp` (compiled into the engines) | Permissive (MIT-style) licence, in the file headers |
| GENTLE 97 runtime and parser code generated by GENTLE | compiled into `lc-compile.exe` and `lc-compile-ffi-java.exe` (installed in `Toolchain/`) | GENTLE's licence for generated software; see [below](#gentle) |
| IANA time zone code and data | `extensions/libraries/timezone/tz/` (timezone library) | Public domain; some files BSD 3-clause; see [`tz/LICENSE`](extensions/libraries/timezone/tz/LICENSE) |
| inih (Ben Hoyt) | `extensions/libraries/ini/inih/` (INI library) | BSD 3-clause, [`inih/LICENSE.txt`](extensions/libraries/ini/inih/LICENSE.txt) |
| QR code generator (John Craig) | `extensions/script-libraries/qr/` | Public domain, stated in the file |

## The IDE

The IDE in `ide/` (installed as `Toolset/`, `Plugins/`, `Resources/`,
`Documentation/` and `Extensions/`) is the OpenXTalk Lite 1.15 IDE with
OXT-Beyond's changes; [HISTORY.md](HISTORY.md) describes where it came
from.

### OpenXTalk Lite's changes to the LiveCode IDE

The LiveCode Community IDE is Copyright © LiveCode Ltd and licensed
under the GPLv3. OpenXTalk Lite changed and extended it: Terry Little
(from September 2023), Tom Perry (from September 2023 to 1.15), Paul
McClernan and other OpenXTalk forum members (see the
[README credits](README.md#credits)). These changes came to this
repository as installed files, without a separate licence statement.
Tom Perry has said on the OpenXTalk forums that OpenXTalk Lite remains
under LiveCode Community's licence, the GPLv3, and OXT-Beyond
distributes the IDE on that basis. Whether their changes also carry
LiveCode Ltd's permission to combine the code with OpenSSL and ATL has
not been confirmed; see [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md).

Parts of the IDE that have their own author or terms are listed below.

### Extensions shipped with the IDE

These are in `ide/Extensions/` and are installed in `Extensions/`.
The `<license>community</license>` element in their `manifest.xml`
files is not a licence statement: `lc-compile` writes it into every
manifest it generates
([`toolchain/lc-compile/src/generate.g`](toolchain/lc-compile/src/generate.g)).
The same goes for the xTalk Suite extensions, which are also installed
in `Extensions/` and are listed in their own
[section](#xtalk-suite-extensions).

| Extension | Author | Terms |
| --- | --- | --- |
| `community.openxtalk.plugin.oxtlite` (OXT Lite Custom Functions, `OXTLiteFunctions.livecodescript`, version 0.0.1, February 2024) | Tom Perry (manifest author "OpenXTalk") | Tom Perry's own notice, with a condition; quoted in full [below](#tom-perrys-notice-for-communityopenxtalkpluginoxtlite). |
| `community.ferruslogic.plugin.devguides` (DevGuides, manifest version 1.0.2, header version 1.0.6, August 2021): alignment guides while dragging objects | FerrusLogic Team ("( c ) FerrusLogic Team" in the header); changed by Tom Perry to be a preference | No licence text is included; only the copyright line and the manifest's "community" element. See [Still to review](#still-to-review). |
| `org.openxtalk.library.macosnativeapptools` (Openxtalk.org macOS Native Tools, version 1.0.2), with the sample stack `samples/MacOS-Native-Tools-Tester.oxtstack`; macOS only | Paul McClernan | MIT, according to the library's documentation comment ("This library is MIT licensed"). The MIT licence text itself is not included. |
| `com.livecode.widget.calendar` (Calendar, 1.0.0) and `com.livecode.widget.piechart` (Pie Chart, 1.0.0), sources `calendar.lcb`, `calendar-support.lcb` and `pieChart.lcb` with compiled modules | Manifest author "LiveCode"; added to OpenXTalk Lite by Terry Little (Pie Chart in .9, both widgets in 1.11) | The sources have no copyright or licence header, and where they were obtained is not recorded. They are not part of LiveCode Community's `extensions/` tree. See [Still to review](#still-to-review). |

#### Tom Perry's notice for `community.openxtalk.plugin.oxtlite`

The header of
[`ide/Extensions/community.openxtalk.plugin.oxtlite/OXTLiteFunctions.livecodescript`](ide/Extensions/community.openxtalk.plugin.oxtlite/OXTLiteFunctions.livecodescript)
reads, exactly:

```text
/*
* OXT Lite Custom Functions
* No copyright. This is free. There's only one stipulation*
* Feb 2024
* version 0.0.1
*
* This code is intended to provide extra functions to OpenXTalk / OpenXTalk Lite.
* This should be considered free to use by anyone, however there is one stipulation / condition:
* This code should in no part be used in any LiveCode product, or fork bearing the LiveCode product name. This stipulation cannot be modified or altered, and this notice MUST go with this plugin unaltered.
*/
```

OXT-Beyond ships the plugin with this notice unaltered. OXT-Beyond is
not a LiveCode product and is not named after LiveCode. If you reuse
this plugin, or OXT-Beyond as a whole, you must respect the condition
too: do not use the plugin in a LiveCode product or in a fork that bears
the LiveCode product name, and keep the notice with it unchanged. Do
not edit this header when changing the plugin.

### Plugins

These are in `ide/Plugins/` and are installed in `Plugins/`.

| Plugin | Author | Licence |
| --- | --- | --- |
| `Quick Dictionary.livecode` (v1.4) | Terry Little; concept and some SQLite code from MaxDictionary by MaxV; changes by Tom Perry (2024) | GPL version 3 or later, stated in the stack's script |
| `Report Builder.livecode` (v1.3) | Terry Little; changes by Tom Perry | GPL version 3 or later, stated in the stack's script |
| `App Browser.livecode` | LiveCode Ltd's Application Browser (`revapplicationoverview`), renamed and changed for OpenXTalk Lite by Terry Little, Tom Perry and Axwald | GPLv3, as part of the LiveCode Community IDE |

### Guides, dictionary and lessons

| Component | Where | Origin and terms |
| --- | --- | --- |
| User Guide and Data Grid Guide (PDF) | `ide/Documentation/PDF/` | Terry Little's debranded versions of LiveCode's User Guide and Data Grid guide. LiveCode's guides are part of LiveCode Community (GPLv3). No separate licence statement. |
| Guides in Markdown | `ide/Documentation/guides/` | Debranded copies of LiveCode Community's guides (GPLv3), dated 2022, apparently from the earlier OpenXTalk debranding work. |
| Dictionary database | `ide/Documentation/html_viewer/resources/data/api/api.sqlite` | LiveCode Community's dictionary (GPLv3), debranded by the OpenXTalk community, with entries for OpenXTalk libraries. |
| Plain-text dictionary exports | `ide/Documentation/html_viewer/resources/data/api/exports/` (about 3,700 files) | Generated from the dictionary database for Tom Perry's dictionary stack (`oxt_dictionary.oxtstack`). |
| "All Guides" and lessons stacks | `ide/Toolset/palettes/userguides/` | Tom Perry's stacks, collecting LiveCode's guides and lessons with Terry Little's and Paul McClernan's lessons. |
| Linked files | `ide/Documentation/linked_files/` | Sample stacks, zip archives and texts that the guides and lessons refer to, mostly from LiveCode's lessons, samples and newsletter articles (for example the data grid samples and the project environments for writing externals). Their terms are not recorded; see [Still to review](#still-to-review). |

### Examples and other resources

| Component | Where | Origin and terms |
| --- | --- | --- |
| Example stacks | `ide/Resources/Examples/` | The examples OpenXTalk Lite added in place of LiveCode's samplers: among them Terry Little's Animate Letter, DataGrid Table and Text To Image and his demo stacks (*Help > Demos*), a Video Player example (1.15), and LiveCode's Data Grid Tour and SQLite Tour, "edited and debranded for open source as requested by LiveCode Ltd." according to their text. The authors of the other examples are not recorded. |
| `neville-segments.mp4` | `ide/Resources/Examples/` | A video file shipped with the examples. Its author and licence are not recorded; see [Still to review](#still-to-review). |
| `oxt-respring.zip` | `ide/Resources/MacOs/` | Tom Perry's macOS helper application (an AppleScript applet) that restarts the IDE after an update on macOS. Not used on Windows. |
| `Default Preferences/livecode7.rev` | `ide/Resources/` | A preferences template from OpenXTalk Lite's installer. |
| The rest of `ide/Resources/` (Start Center, object library, mobile examples, sample icons) | | LiveCode Community's (GPLv3). |

### Fonts

| Font | Where | Licence |
| --- | --- | --- |
| Adobe Source Code Pro (14 `SourceCodePro-*.ttf` files) | `ide/Toolset/resources/supporting_files/fonts/` | SIL Open Font License 1.1, [`LICENSE.txt`](ide/Toolset/resources/supporting_files/fonts/LICENSE.txt) in the same folder |
| `fontawesome.ttf` (an icon font named "fontawesome", generated by IcoMoon) | `ide/Toolset/resources/supporting_files/fonts/` | not recorded; see [Still to review](#still-to-review) |
| `lcideicons.ttf` (icon font generated with Fontello) | `ide/Toolset/resources/supporting_files/fonts/` | not recorded; see [Still to review](#still-to-review) |
| Droid Sans Mono (`DroidSansMono.ttf`, "Digitized data copyright 2007, Google Corporation", made by Ascender Corporation) | `ide/Documentation/html_viewer/resources/data/api/` (used by the dictionary) | Apache License 2.0, according to the font's own licence field ([licence text](https://www.apache.org/licenses/LICENSE-2.0)). "Droid" is a trademark of Google. |
| Glyphicons Halflings (part of Bootstrap 3.3.7) | `ide/Documentation/html_viewer/fonts/` | MIT, with Bootstrap (below) |

### Documentation viewer

The HTML documentation viewer (`ide/Documentation/html_viewer/`)
includes these web libraries:

| Component | Version | Licence |
| --- | --- | --- |
| Bootstrap (with the Glyphicons Halflings font) | 3.3.7 | MIT, stated in the file header |
| jQuery | 1.11.1 | MIT ([jquery.org/license](https://jquery.org/license)) |
| jQuery Cookie | 1.4.1 | MIT, stated in the file header |
| jQuery Mousewheel | 3.1.13 | MIT, stated in the file header |
| marked | as bundled | MIT, stated in the file header |
| remarkable | 1.4.1 | MIT, stated in the file header |

### The IDE's own notice file

The IDE ships the notice file it inherited from LiveCode Community,
[`ide/Open Source Licenses.txt`](ide/Open%20Source%20Licenses.txt)
(installed at the root of the program folder). It covers bsdiff, curl,
FreeType, giflib, cairo (MPL), iODBC, libjpeg, bzip2, libpng, libxml2,
libzip, OpenSSL, PCRE, PostgreSQL, Skia, sqlitedataset, zlib, WebKit and
the merg externals. It does not cover ICU, CEF/Chromium, ANGLE,
SwiftShader, libffi, libxslt, MySQL Connector/C or the components
listed in this section; those are listed in this file.

### The OXT-Beyond icon

The OXT-Beyond icon (`ide/OXT-Beyond.ico`, `engine/rsrc/oxt-beyond.ico`
and the images in `Installer/oxt-beyond/branding/png/`) and the splash
screens are adapted from Tom Perry's OpenXTalk Lite icon
(`ide/OpenXTalk-lite_1024.ico`, introduced in OpenXTalk Lite 1.04), with
"Lite" replaced by "Beyond", by
[`Installer/oxt-beyond/branding/make-branding.ps1`](Installer/oxt-beyond/branding/make-branding.ps1).
The unmodified source image is kept in
`Installer/oxt-beyond/branding/source/`. The icon is distributed as part
of the IDE, on the same basis as the rest of OpenXTalk Lite's changes
(above).

## xTalk Suite extensions

The packages include fifteen extensions of the xTalk Suite by Seth
Morrow Software, in `Extensions/`: six LiveCode Builder libraries with
native code and nine LiveCode Script libraries. They are not kept in
this repository.
[`tools/oxt/xtalk_extensions.py`](tools/oxt/xtalk_extensions.py) takes
them from their own repositories on GitHub
(`SethMorrowSoftware/<repository>`) at the commits pinned in
[`tools/oxt/xtalk-extensions.json`](tools/oxt/xtalk-extensions.json),
checks every file against the SHA-256 recorded there, compiles the LCB
sources with OXT-Beyond's `lc-compile`, gives the script libraries a
`script "<name>"` first line where they have none and an
`extensionInitialize` / `extensionFinalize` pair at the end, and ships
everything else unchanged. `Extensions/XTALK-EXTENSIONS.txt` lists each
extension with its repository and commit. The native libraries
(`code/<platform>/` in each LCB extension, for Windows x86-64 and x86,
Linux x86-64 and x86, and macOS) are the prebuilt binaries committed to
the member repositories, which build them from the sources there; this
repository does not rebuild them. The source of each member's own code,
including its native shim, is in its repository at the pinned commit.

Every extension folder has a `licenses/` folder with its member's
licence files, which hold the full licence texts of the components
below.

| Extensions (folder in `Extensions/`) | Repository | Licence | Compiled into the native libraries | Licence texts in `licenses/` |
| --- | --- | --- | --- | --- |
| `org.openxtalk.library.sodium` | `SodiumXT` | MIT, © 2026 Seth Morrow | libsodium (1.0.22 in the Windows libraries, 1.0.20 in the others): ISC, © Frank Denis. SHA-3 from RHash (© 2013 Aleksey Kravchenko), taken through trezor-crypto: a permission notice in the style of the MIT licence. trezor-crypto's helpers: MIT, © Tomas Dzetkulic and Pavol Rusnak. | `LICENSE` (with libsodium's ISC text), `trezor-crypto-LICENSE`, `RHash-SHA3-NOTICE.txt` (the notice from the header of the member's `src/vendor/sha3.c`, the only place it has it) |
| `org.openxtalk.library.torrent`, `torrentHelpers` | `TorrentXT` | MIT, © 2026 Seth Morrow | libtorrent-rasterbar 2.1.1: BSD 3-clause, © Arvid Norberg; its licence also covers the code libtorrent includes (puff, an ed25519 implementation, SHA-1 and SHA-256, `route.h`). Boost: Boost Software License 1.0. OpenSSL 3 (3.6.4 in the Windows libraries, 3.5.4 in the macOS and Linux x86-64 ones), statically linked: Apache License 2.0; the Linux x86 library uses the system's OpenSSL (`libssl.so.3`) instead. | `LICENSE`, `THIRD-PARTY-LICENSES.md`, `OpenSSL-LICENSE.txt` |
| `org.openxtalk.library.enet`, `enetHelpers` | `enetxt` | MIT, © 2026 Seth Morrow | ENet 1.3.18: MIT, © Lee Salzman. The Windows libraries use the Visual C++ runtime (see below). | `LICENSE`, `THIRD-PARTY-LICENSES.md` |
| `org.openxtalk.library.datachannel`, `dataChannelHelpers` | `dataChannelXT` | MIT, © 2026 Seth Morrow Software | libdatachannel 0.24.5 and libjuice: Mozilla Public License 2.0, © Paul-Louis Ageneau. usrsctp: BSD 3-clause. plog: MIT. OpenSSL 3 (3.6.4 in the Windows libraries, 3.5.4 in the macOS one), statically linked: Apache License 2.0; the Linux libraries use the system's OpenSSL. | `LICENSE`, `THIRD-PARTY-LICENSES.md`, `OpenSSL-LICENSE.txt` |
| `org.openxtalk.box2dxt`, `box2dxt-kit` | `Box2Dxt` | MIT, © 2026 Seth Morrow and Box2Dxt contributors | Box2D 3.1.0: MIT, © 2019 Erin Catto. The Windows libraries use the Visual C++ runtime (see below). | `LICENSE` (with Box2D's notice) |
| `org.openxtalk.library.coin`, `coinxt` | `CoinXT` | MIT, © 2026 Seth Morrow | trezor-crypto: MIT. libsecp256k1: MIT, © Pieter Wuille. SHA-2 (`sha2.c`): BSD 3-clause, © Aaron D. Gifford and Pavol Rusnak, whose notice must be reproduced with the binaries. SHA-3/Keccak from RHash: MIT. RIPEMD-160: public domain. BLAKE-256 and BLAKE2b: CC0 1.0. Groestl: MIT, © Projet RNRT SAPHIR. The member's `THIRD-PARTY-LICENSES.md` maps every vendored file to its licence and copyright holder. | `LICENSE`, `THIRD-PARTY-LICENSES.md` |
| `onionxt`, `onion-httpd` | `OnionXT` | MIT, © 2026 Seth Morrow | none (LiveCode Script only) | `LICENSE` |
| `nostrxt`, `nostr-relay` | `NostrXT` | MIT, © 2026 Seth Morrow | none (LiveCode Script only) | `LICENSE` |

Notes:

- **OpenSSL 3.** `torrentxt` and `datachannelxt` link OpenSSL 3
  statically: OpenSSL is Copyright © 1998-2026 The OpenSSL Project
  Authors and © 1995-1998 Eric A. Young and Tim J. Hudson, and is
  licensed under the Apache License 2.0, which asks for a copy of the
  licence to go with the binaries. The members' own licence files do not
  include it (DataChannelXT's `LICENSE` and `THIRD-PARTY-LICENSES.md` even
  say that OpenSSL is not bundled, which is true only of its Linux
  libraries), so OXT-Beyond adds OpenSSL's `LICENSE.txt`, taken from the
  `openssl-3.6.4` tag of [openssl/openssl](https://github.com/openssl/openssl)
  and pinned by SHA-256 like the other files, as `OpenSSL-LICENSE.txt`
  to both extensions' `licenses/` folders. OpenSSL 3 has no `NOTICE`
  file. These copies are separate from the OpenSSL 1.1.1g inside
  `revsecurity.dll` ([Prebuilt libraries](#prebuilt-libraries)).
- **MPL 2.0 source.** The source of libdatachannel and libjuice is at
  [paullouisageneau/libdatachannel](https://github.com/paullouisageneau/libdatachannel)
  and [paullouisageneau/libjuice](https://github.com/paullouisageneau/libjuice);
  dataChannelXT's `CMakeLists.txt` at the pinned commit gives the exact
  versions it builds.
- **The Microsoft Visual C++ runtime.** `enetxt.dll` and `box2dxt.dll`
  are built with the dynamic Visual C++ runtime; the other libraries
  link it statically or, like CoinXT's MinGW build, use Windows' own
  `msvcrt.dll`. So that they also load on a PC without the Visual C++
  Redistributable, the packages include the DLLs they import next to
  them, in the `code/x86_64-win32/` and `code/x86-win32/` folders of the
  two extensions: `msvcp140.dll`, `vcruntime140.dll` and (x86-64 only)
  `vcruntime140_1.dll` for enetxt, `vcruntime140.dll` for Box2Dxt. They
  are copied unchanged from the Visual Studio redistributable folder
  (`VC\Redist\MSVC\<version>\<arch>\Microsoft.VC14x.CRT`) of the machine
  that made the package. `XTALK-EXTENSIONS.txt` gives their version and
  SHA-256. See [Microsoft components](#microsoft-components).
- **Standalones.** When a standalone includes one of these extensions,
  the standalone builder copies its native libraries (for enetxt and
  Box2Dxt also the Visual C++ runtime DLLs) into the standalone, but not
  its `licenses/` folder. Include those licence files with your
  application.

## Standalone runtimes for other platforms

OXT-Beyond builds only the Windows x86-64 engine. So that its IDE can
offer the same standalone targets as OpenXTalk Lite 1.15, the packages
include files that are not built from this repository. They come from
one release asset of this repository, `oxt-runtimes-1.15.zip` (release
tag `runtimes-1.15`), listed with its SHA-256 in
[`tools/oxt/external-assets.json`](tools/oxt/external-assets.json). The
asset was made with
[`tools/oxt/make_runtimes_asset.py`](tools/oxt/make_runtimes_asset.py)
from OpenXTalk Lite 1.15 for Windows
(`openxtalk-lite-1.15-win-noinstaller.7z`, build 202605052228), and the
files are unchanged. Its `PROVENANCE.md`, installed as
`PROVENANCE-oxt-runtimes-1.15.md` at the root of the program folder,
lists every file with its size and SHA-256 and says which ones are
byte-identical to the stock LiveCode Community 9.6.3 installer.

| Where it ends up | What it is |
| --- | --- |
| `Runtime/Windows/x86-32/` | 32-bit Windows standalone engine and externals: stock LiveCode Community 9.6.3 builds (all 86 files identical to LiveCode's installer). |
| `Runtime/Linux/x86-64/` | 64-bit Linux standalone engine (version 9.7.1-OXT, dated May 2026): Tom Perry's build. Its two support libraries (`revpdfprinter.so`, `revsecurity.so`) differ from LiveCode's 9.6.3 files and carry no version string; they are dated September 2023, before Tom's first engine builds, and their origin is not recorded (possibly LiveCode 9.6.3-rc-3 builds). Plus 42 shared libraries of other projects in `lib/` (for example glibc, GLib, PulseAudio, ALSA, libsndfile, FLAC, Ogg, Vorbis, Opus, LAME, mpg123, libxcb and X11 libraries, zlib and zstd). |
| `Runtime/Linux/x86-32/` | 32-bit Linux standalone engine (version string 9.6.3-rc-3, not identical to LiveCode's) and LiveCode's externals, plus 91 files of shared libraries of other projects in `lib/` (for example GTK 2, GDK, GLib, Pango, cairo, pixman, HarfBuzz, FreeType, fontconfig, libpng, libjpeg, libtiff, libwebp and X11 libraries). |
| `Runtime/Android/` | Android standalone engines for four ABIs (version string 9.6.3-rc-3) and support files; 31 of 38 files are identical to LiveCode's 9.6.3 installer, the others are as Tom Perry shipped them. |
| `Extensions/com.livecode.library.timezone/code/<platform>/` and `.../resources/` | The time zone library's native code for platforms other than Windows x86-64, including iOS (device and simulator) and macOS (17 of 23 files identical to LiveCode's; the iOS simulator and macOS `tz.dylib` files differ), and its zoneinfo data (identical to LiveCode's). |

Licences and corresponding source:

- **Files identical to LiveCode Community 9.6.3** (engines, externals,
  Android templates, time zone library): GPLv3. Source:
  [livecode/livecode](https://github.com/livecode/livecode), tag
  [`9.6.3`](https://github.com/livecode/livecode/tree/9.6.3). This
  repository's history contains the upstream commits up to that tag.
- **Tom Perry's 9.7.1-OXT Linux x86-64 engine**: GPLv3. Tom publishes
  his engine source archives for Windows, macOS and Linux at
  [openxtalk.net/OXT-lite-source](https://www.openxtalk.net/OXT-lite-source/index.php);
  which archive matches this engine is not recorded.
- **The other files that differ from LiveCode's 9.6.3 files** (among
  them the Linux x86-32 and Android engines that report `9.6.3-rc-3`,
  the Linux x86-64 support libraries and the iOS simulator and macOS
  time zone libraries): GPLv3. They are as Tom Perry shipped them in
  OpenXTalk Lite; how each one was built is not recorded. They may be
  LiveCode builds (source: tag
  [`9.6.3-rc-3`](https://github.com/livecode/livecode/tree/9.6.3-rc-3)
  or [`9.6.3`](https://github.com/livecode/livecode/tree/9.6.3)) or
  builds by Tom (source: his archives above).
- **IANA time zone data** (`resources/zoneinfo`): public domain; the
  source is in `extensions/libraries/timezone/tz/`.
- **Shared libraries in `Runtime/Linux/*/lib/`**: each under the licence
  of its own project (for example LGPL for glibc, GLib, GTK and Pango;
  MIT or BSD-style licences for several X11, compression and codec
  libraries). Their licence texts and sources are available from those
  projects; they are not in the asset. See
  [Still to review](#still-to-review).

The asset holds no standalone runtimes for macOS or iOS (only the time
zone library's native code for them, as OpenXTalk Lite 1.15 shipped
it), and nothing from `Ext/`.

## Files OpenXTalk Lite shipped that OXT-Beyond does not

OpenXTalk Lite 1.15 shipped these files. OXT-Beyond leaves them out of
the repository, its history and its packages:

| File | Why |
| --- | --- |
| `Ext/` (the mergExt externals blur 1.1.53, mergJSON 1.0.70, mergMarkdown 1.0.66 and mergMicrophone 1.0.66, for Windows, Linux and macOS) | The collection that LiveCode's installer builder downloaded from LiveCode's server. Each folder has a `LICENSE.txt` (MIT texts naming Trevor DeVore or M E R Goulding, and the GPLv3 text), but whether these cover the binaries as shipped, and where their corresponding source is, has not been established. Until it has, OXT-Beyond does not redistribute them. Stacks that use them need a copy from elsewhere. |
| `Documentation/linked_files/apple-human-interface-guidelines-2005.pdf` | Apple Inc. copyright, with no licence to redistribute. |
| `Documentation/linked_files/animationEngine6.zip` | A third-party library with no licence in the release. |

[`tools/oxt/layout.py`](tools/oxt/layout.py) classes the last two as
"excluded" (`NOT_REDISTRIBUTABLE`), and
[`tools/oxt/package.py`](tools/oxt/package.py) reports `Ext/` as an
intended difference from OpenXTalk Lite 1.15. OpenXTalk Lite's
`OpenXTalk Lite.lnk` shortcut and two empty SQLite files (`test.db`,
`Toolset/palettes/dictionary/api.sqlite`) are left out as well; they
contain nothing of use.

## The installer

`OXT-Beyond-<version>-win-x86_64-setup.exe` is made with
[Inno Setup](https://jrsoftware.org/isinfo.php) 6. The setup program and
the uninstaller it installs contain Inno Setup's code, Copyright ©
Jordan Russell and portions Copyright © Martijn Laan, under the
[Inno Setup License](https://jrsoftware.org/files/is/license.txt), a
permissive licence. The installer script
([`Installer/oxt-beyond/oxt-beyond.iss`](Installer/oxt-beyond/oxt-beyond.iss))
is part of OXT-Beyond.

## Microsoft components

The engine and revBrowser use Microsoft's Active Template Library (ATL),
and the binaries built from this repository statically link the
Microsoft Visual C++ runtime. Two of the bundled xTalk Suite extensions,
enetxt and Box2Dxt, need the runtime as DLLs instead, so the packages
also contain Microsoft's redistributable `msvcp140.dll`,
`vcruntime140.dll` and `vcruntime140_1.dll` as separate files, in those
extensions' `code/x86_64-win32/` and `code/x86-win32/` folders,
unchanged from Visual Studio's redistributable folder (see
[xTalk Suite extensions](#xtalk-suite-extensions)). These are Microsoft
components distributed under the Visual Studio licence terms for
redistributable code ("Distributable Code"), not open source. The ATL
combination is the reason for the licence exception in
[LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md).

## GENTLE

GENTLE 97 Campus Edition (Metarga GmbH) is in `toolchain/gentle/`. It
has been in the LiveCode Community tree since upstream. Its licence,
[`toolchain/gentle/LICENSE`](toolchain/gentle/LICENSE), has two parts:

- **GENTLE itself** is a build-time tool and is not shipped. It may be
  used at no charge for personal and educational purposes and in
  non-commercial projects; commercial use of any kind needs a licence
  from Metarga, and GENTLE itself may not be redistributed (apart from
  the copies the licence allows to be given to students and project
  partners).
- **What GENTLE generates is shipped.** The build uses GENTLE to
  generate the parser of the LiveCode Builder compiler, and that
  parser, together with the GENTLE runtime (`grts`), is compiled into
  `lc-compile.exe` and `lc-compile-ffi-java.exe`. Both are in
  `win-x86_64-bin`, and so in the binaries zip, and in `Toolchain/` of
  the installed program. For a non-commercial project, the licence
  allows the generated code and the runtime to be distributed as part
  of software distributed under the GNU General Public License, and it
  puts software generated with GENTLE under the GNU General Public
  License version 2 text that follows in the same file.

## Build-time tools (not shipped)

| Component | Where | Licence | Notes |
| --- | --- | --- | --- |
| GENTLE 97 Campus Edition | `toolchain/gentle/` | see [GENTLE](#gentle) | Generates the LiveCode Builder compiler's parser; its output is shipped, as described above. |
| gyp | `gyp/` | BSD 3-clause | Generates the Visual Studio projects. [`gyp/LICENSE`](gyp/LICENSE) |
| Google Test | `libcpptest/googletest` (submodule) | BSD 3-clause | C++ unit tests only. |
| Cygwin, Python, Perl, Visual Studio, Inno Setup, Chocolatey | installed separately | their own licences | See [BUILDING.md](BUILDING.md). Inno Setup's code is part of the setup program (see [The installer](#the-installer)). |

## Still to review

- **Tom Perry's condition** on `community.openxtalk.plugin.oxtlite`
  (quoted [above](#tom-perrys-notice-for-communityopenxtalkpluginoxtlite))
  is a restriction that the GPLv3 does not contain. How it fits with
  distributing the plugin inside a GPLv3 program has not been reviewed.
- **FerrusLogic's DevGuides** has a copyright line but no licence text.
  Its terms should be confirmed with FerrusLogic.
- **`community.openxtalk.plugin.oxtlite` was started from DevGuides'
  template.** Its script-local and constant declarations (lines 13-14 of
  `OXTLiteFunctions.livecodescript`) are identical to lines 12-13 of
  `DevGuides.livecodescript`, and its `extensionInitialize` /
  `extensionFinalize` skeleton follows the same pattern, so Tom Perry's
  "No copyright" notice sits over a few lines that come from FerrusLogic.
  This depends on the FerrusLogic question above.
- **The Calendar and Pie Chart widgets** have no copyright or licence
  header, and their origin is not recorded.
- **Paul McClernan's macOS Native Tools** states "MIT" but does not
  include the MIT licence text and copyright notice that the MIT licence
  asks for.
- **Droid Sans Mono** is under the Apache License 2.0, but the licence
  text is not shipped next to the font.
- **`neville-segments.mp4`**, the examples whose authors are not
  recorded, and **`Documentation/linked_files/`** (the sample stacks and
  zip archives from LiveCode's lessons and samples): authors and terms
  are not recorded.
- **The runtimes asset:** the shared libraries in `Runtime/Linux/*/lib/`
  come without their licence texts or source offers, and how Tom Perry
  built the runtime files that differ from LiveCode's 9.6.3 files is
  not recorded. Building these runtimes from source would settle both.
- `extensions/libraries/iconsvg/` contains SVG path data for Font Awesome
  icons (its default "fontawesome" icon family). The Font Awesome version
  and the licence notice that should go with it are not recorded in the
  repository.
- `ide/Documentation/html_viewer/js/highlight.pack.js` (highlight.js) and
  `jquery.session.js` have no licence header, and their versions are not
  recorded.
- `ide/Toolset/resources/supporting_files/fonts/fontawesome.ttf` is an
  IcoMoon-generated icon font named "fontawesome" (presumably Font
  Awesome icons), and `lcideicons.ttf` a
  Fontello-generated icon font ("Copyright (C) 2014 by original authors
  @ fontello.com"). Which icons they contain, and the licence notices
  that should go with them, are not recorded in the repository. The
  folder's `LICENSE.txt` covers only Source Code Pro.
- How GENTLE's terms for generated software (the GPL version 2 text and
  the non-commercial condition) fit with distributing `lc-compile.exe`
  under the GPLv3 has not been reviewed. Nor has the fact that this
  repository, like LiveCode Community before it, contains GENTLE's own
  source in `toolchain/gentle/`.
- Chromium 74 bundles many components with their own notices. This file
  does not reproduce them.
- **The xTalk Suite extensions.** The Visual C++ runtime DLLs shipped
  with enetxt and Box2Dxt are there because those two members build with
  the dynamic runtime (`/MD`); how Microsoft's terms for Distributable
  Code fit with distributing them inside a GPLv3 program has not been
  reviewed. A `/MT` build upstream, as SodiumXT, TorrentXT and
  DataChannelXT already use, would remove them. The OpenSSL licence text
  that OXT-Beyond adds for TorrentXT and DataChannelXT, and the
  statement in DataChannelXT's licence files that OpenSSL is not bundled,
  should be fixed in the member repositories. The Box2Dxt module reports
  version 0.2.0 while its CHANGELOG already has a 0.3.0 section.
