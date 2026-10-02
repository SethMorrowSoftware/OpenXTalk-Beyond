# Third-party libraries

This folder holds the sources of the third-party libraries that the
engine and externals use: cairo, CEF (headers and C++ wrapper), curl
(headers), expat, libffi, FreeType, giflib, HarfBuzz, iODBC, libjpeg,
MySQL Connector/C, OpenSSL (glue code), PCRE, libpng, libpq, Skia,
SQLite, libxml2, libxslt, zlib and libzip. Most library folders have an
`ORIGIN` file (the upstream version) and, where upstream provided one,
its licence under `docs/`. The exceptions are `libffi` (version in
`libffi/git_master/source.txt`), `libskia` (revision in
`libskia/git-revision.txt`), and `libgif`, `libharfbuzz`, `libopenssl`
and `libxslt`, which have no `ORIGIN` file.
[THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) lists the licences.

It was the separate `livecode/livecode-thirdparty` repository, included
as a submodule. It was imported unchanged from upstream commit
`e5e050573c226f60acfbb9107c2b4aea853b0cbe` (commit `4c9715a77` in this
repository). Since then, Tom Perry's changes (commit `38d5712b2`)
updated SQLite in `libsqlite/` from 3.34.0 to 3.51.1 and added
`libexpat/lib/asciitab_old.h`, a copy of `asciitab.h` from his working
files.

## How the Windows build uses it

Most of these libraries are **not** compiled during a normal Windows
build. The engine links static libraries from the "Thirdparty" prebuilt
archive instead (`prebuilt/unpacked/Thirdparty/...`). That archive was
built by LiveCode Ltd from this folder at commit `e5e0505` and is mirrored
in the
[`prebuilts-v1` release](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases/tag/prebuilts-v1).
The headers, on the other hand, are always taken from this folder.

So a change to a library's source here does **not** reach the Windows
programs until the Thirdparty archive is rebuilt and published. The
exceptions, compiled from this folder by the normal build, are:

- `libsqlite/` (the `dbsqlite.dll` database driver), because the archive
  still contains SQLite 3.34.0;
- the CEF C++ wrapper in `libcef/`;
- `libopenssl/`, which builds `revsecurity.dll` from the prebuilt
  OpenSSL.

FreeType, HarfBuzz, expat and iODBC are not used on Windows.

## How the Linux and macOS builds use it

The Linux and macOS workflows build the Thirdparty libraries from this
folder themselves (the step "Build the Thirdparty libraries from
thirdparty/", with `prebuilt/build-libraries.sh`), and keep the result
in the GitHub Actions cache. The cache key includes the Git tree of this
folder, so any change here is built into the next Linux and macOS
builds; no archive has to be published for them. See
[Building on Linux](../BUILDING.md#12-building-on-linux) and
[Building on macOS](../BUILDING.md#13-building-on-macos).

## Updating a library

1. Replace the sources, keeping the folder layout and the `.gyp` file
   working, and update the library's `ORIGIN` file and licence files.
2. Update [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) and, if it
   fixes security problems, [SECURITY.md](../SECURITY.md).
3. If the library comes from the Thirdparty archive on Windows (see
   above), the change also needs a new archive for Windows (Linux and
   macOS build it from this folder):
   - build the static libraries with the `thirdparty-prebuilts` MSBuild
     target (`cmd /c ..\make.cmd thirdparty-prebuilts` in
     `build-win-x86_64`, after configuring as in
     [BUILDING.md](../BUILDING.md)), for both Release and Debug;
   - package them as `Thirdparty-<id>-x86_64-win32-v141_static_{release,debug}-PIC.tar.bz2`,
     each holding one folder `x86_64-win32-v141_static_{release,debug}/lib/`,
     like the existing archives;
   - publish them as assets of a **new** release tag (never replace the
     assets of an existing one), and update `prebuilt/versions/thirdparty`,
     `prebuilt/SHA256SUMS` and the default `PREBUILT_URL` in
     `prebuilt/fetch-libraries.sh`.

   This process has not been tried in this repository yet. Upstream's
   scripts for it are `prebuilt/scripts/build-thirdparty.bat` and
   `prebuilt/build-libs.bat`, which still expect Visual Studio 2017.

The upstream update procedure that used to be described here (submodule
pointers, the `livecode-private` repository and LiveCode's build
servers) no longer applies. It is in the Git history of this file.
