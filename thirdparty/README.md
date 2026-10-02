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

## How the builds use it

Every platform's build compiles the "Thirdparty" libraries from this
folder (zlib, libpng, libjpeg, giflib, PCRE, libffi, Skia, libxml2,
libxslt, libzip, cairo, MySQL Connector/C, libpq, SQLite and, on Linux
and macOS, iODBC) into prebuilt archives, which the engine then links
(`prebuilt/unpacked/Thirdparty/...` on Windows):

- on Linux and macOS, in their workflows' step "Build the Thirdparty
  libraries from thirdparty/" (`prebuilt/build-libraries.sh`; see
  [Building on Linux](../BUILDING.md#12-building-on-linux) and
  [Building on macOS](../BUILDING.md#13-building-on-macos));
- on Windows, with `prebuilt\build-libraries-windows.ps1` (the msbuild
  target `thirdparty-prebuilts`; see
  [Prebuilt libraries](../BUILDING.md#6-prebuilt-libraries)). Until
  0.2.1-rc.2 Windows linked LiveCode Ltd's archive of this folder at
  commit `e5e0505` instead.

CI keeps the archives in its cache, keyed on the Git tree of this
folder, so any change here is built into the next build of every
platform; no archive has to be published. The headers are always taken
from this folder. Some pieces are compiled by the normal build instead:
`libsqlite/` for the `dbsqlite` database driver on Windows, the CEF C++
wrapper in `libcef/`, and `libopenssl/`, which builds `revsecurity` from
the prebuilt OpenSSL. FreeType, HarfBuzz, expat and iODBC are not used
on Windows.

## Updating a library

1. Replace the sources, keeping the folder layout and the `.gyp` file
   working, and update the library's `ORIGIN` file and licence files.
2. Update [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) and, if it
   fixes security problems, [SECURITY.md](../SECURITY.md).
3. Build and test on every platform: CI rebuilds the Thirdparty archives
   by itself. For a local Windows build, run
   `prebuilt\build-libraries-windows.ps1 -Libraries Thirdparty` again and
   delete `prebuilt\fetched\Thirdparty-*` and `prebuilt\unpacked\Thirdparty`,
   which keep the archive of the same name built before.

The upstream update procedure that used to be described here (submodule
pointers, the `livecode-private` repository and LiveCode's build
servers) no longer applies. It is in the Git history of this file.
