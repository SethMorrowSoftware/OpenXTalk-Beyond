# Third-party notices

OpenXTalk Lite is licensed under the GNU General Public License,
version 3 ([LICENSE](LICENSE)); [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md)
describes an additional permission and which parts it covers. The Windows binaries
also contain, or ship next to, software written by other people under
other licences. This file lists that software, its licence, and where
the full licence text can be found.

It covers the Windows x86_64 build only. Versions are the ones this
repository builds today. Paths are relative to the repository root;
links point to the upstream licence text for the matching version where
the text is not in this repository.

This list was put together by reading the build files and the contents
of the prebuilt archives. It may be incomplete. If you spot something
missing or wrong, please open an issue.

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
| libcurl | 7.51.0 | statically linked into the server engine (`server-community.exe`) | curl licence (MIT/X style) | [upstream](https://github.com/curl/curl/blob/curl-7_51_0/COPYING); also in `ide/Open Source Licenses.txt` |
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
| GENTLE 97 runtime and parser code generated by GENTLE | compiled into `lc-compile.exe` and `lc-compile-ffi-java.exe`, which ship in `win-x86_64-bin` | GENTLE's licence for generated software; see [below](#gentle) |
| IANA time zone code and data | `extensions/libraries/timezone/tz/` (timezone library) | Public domain; some files BSD 3-clause; see [`tz/LICENSE`](extensions/libraries/timezone/tz/LICENSE) |
| inih (Ben Hoyt) | `extensions/libraries/ini/inih/` (INI library) | BSD 3-clause, [`inih/LICENSE.txt`](extensions/libraries/ini/inih/LICENSE.txt) |
| QR code generator (John Craig) | `extensions/script-libraries/qr/` | Public domain, stated in the file |

## Files shipped with the IDE

The IDE in `ide/` ships its own notice file,
[`ide/Open Source Licenses.txt`](ide/Open%20Source%20Licenses.txt),
inherited from LiveCode Community. It covers bsdiff, curl, FreeType,
giflib, cairo (MPL), iODBC, libjpeg, bzip2, libpng, libxml2, libzip,
OpenSSL, PCRE, PostgreSQL, Skia, sqlitedataset, zlib, WebKit and the
merg externals. It does not cover ICU, CEF/Chromium, ANGLE, SwiftShader,
libffi, libxslt or MySQL Connector/C; those are listed above.

The IDE also includes these fonts, in
`ide/Toolset/resources/supporting_files/fonts/`:

| Component | Licence |
| --- | --- |
| Adobe Source Code Pro (14 `SourceCodePro-*.ttf` files) | SIL Open Font License 1.1, [`LICENSE.txt`](ide/Toolset/resources/supporting_files/fonts/LICENSE.txt) in the same folder |
| `fontawesome.ttf` (an icon font named "fontawesome", generated by IcoMoon) | not recorded; see [Still to review](#still-to-review) |
| `lcideicons.ttf` (icon font generated with Fontello) | not recorded; see [Still to review](#still-to-review) |

The IDE's documentation viewer (`ide/Documentation/html_viewer/`)
includes these web libraries:

| Component | Version | Licence |
| --- | --- | --- |
| Bootstrap (with the Glyphicons Halflings font) | 3.3.7 | MIT, stated in the file header |
| jQuery | 1.11.1 | MIT ([jquery.org/license](https://jquery.org/license)) |
| jQuery Cookie | 1.4.1 | MIT, stated in the file header |
| jQuery Mousewheel | 3.1.13 | MIT, stated in the file header |
| marked | as bundled | MIT, stated in the file header |
| remarkable | 1.4.1 | MIT, stated in the file header |

## Microsoft components

The engine and revBrowser use Microsoft's Active Template Library (ATL),
and the binaries statically link the Microsoft Visual C++ runtime.
These are Microsoft components distributed under the Visual Studio
licence terms for redistributable code, not open source. The ATL
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
  `win-x86_64-bin` and so in the release zips. For a non-commercial
  project, the licence allows the generated code and the runtime to be
  distributed as part of software distributed under the GNU General
  Public License, and it puts software generated with GENTLE under the
  GNU General Public License version 2 text that follows in the same
  file.

## Build-time tools (not shipped)

| Component | Where | Licence | Notes |
| --- | --- | --- | --- |
| GENTLE 97 Campus Edition | `toolchain/gentle/` | see [GENTLE](#gentle) | Generates the LiveCode Builder compiler's parser; its output is shipped, as described above. |
| gyp | `gyp/` | BSD 3-clause | Generates the Visual Studio projects. [`gyp/LICENSE`](gyp/LICENSE) |
| Google Test | `libcpptest/googletest` (submodule) | BSD 3-clause | C++ unit tests only. |
| Cygwin, Python, Perl, Visual Studio | installed separately | their own licences | See [BUILDING.md](BUILDING.md). |

## Still to review

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
