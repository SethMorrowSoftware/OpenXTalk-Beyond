# mergJSON

Monte Goulding's mergJSON, the JSON external of LiveCode's mergExt
collection, built from its source with the copy of Jansson it is written
for. LiveCode's installer put the mergExt collection in the IDE's `Ext`
folder, and OpenXTalk Lite shipped LiveCode's binaries of it. OXT-Beyond
does not redistribute those binaries (THIRD-PARTY-NOTICES.md, "Files
OpenXTalk Lite shipped that OXT-Beyond does not"), so it builds mergJSON
from this source instead. That gives stacks written for LiveCode
`JSONToArray` and `ArrayToJSON` again, and with them the OAuth2 library
(`extensions/script-libraries/oauth2`), which calls both.

## Where the files come from

- `src/mergJSON.c`, `src/mergJSONLibrary.livecodescript`, `mergJSON.lcdoc`
  and `LICENSE.txt` are as upstream: https://github.com/montegoulding/mergJSON
  at commit `db85296` (18 June 2019). mergJSON is offered under the GPL 3
  (`LICENSE.txt`) or under a commercial licence from mergExt, and this
  copy is used under the GPL 3.
- `jansson/` is Monte Goulding's fork of Jansson, which the mergJSON
  repository holds as a submodule: https://github.com/montegoulding/jansson
  at commit `17ac0ee` (`v2.11-31-g17ac0ee`), which adds
  `JSON_DECODE_NUMBER_AS_STRING` to Jansson 2.11. Only `src/` is kept,
  without its build files (`Makefile.am`, `jansson.def`,
  `jansson_config.h.in`), with `LICENSE` (MIT, Petri Lehtinen), `CHANGES`
  and `README.rst`.
- `include/` and `win-include/` hold the configuration headers that
  Jansson's own build would write (`jansson_config.h`,
  `jansson_private_config.h`), as the mergJSON repository keeps them:
  `win-include/` for Windows and `include/` for everything else. Their
  line ends are LF here; nothing else differs.
- `rsrc/mergJSON-Info.plist` is upstream's `mergJSON-Info.plist` with the
  Xcode variables it named written out, and without its empty CFPlugIn
  keys. `mergJSON.exports` lists the two symbols the Mac bundle exports,
  as the other externals' export lists do.
- `src/external.h` is OXT-Beyond's. `mergJSON.c` includes "external.h",
  the copy of LiveCode's externals SDK that the mergJSON repository keeps
  beside it; this one includes the SDK in `libexternal/` instead, which
  the other externals are built against, so `mergJSON.c` stays as it is
  upstream.
- `mergjson.gyp` is OXT-Beyond's: it builds the external as
  `revxml.gyp` builds revXML, against `libExternal`, as a bundle on macOS.

## Where it is installed

`tools/oxt/package.py` puts each desktop package's own build in
`Ext/mergJSON` (on macOS `Contents/Tools/Ext/mergJSON`), named as
LiveCode named it, because the standalone builder tells the
architectures apart by the end of the name: `mergJSON-x64.dll` or
`mergJSON-x86.dll` on Windows, `mergJSON-x64.so` or `mergJSON-arm64.so`
on Linux, and `mergJSON.bundle` (universal) on macOS. The library,
`mergJSONLibrary.livecodescript`, and the two licences go beside it
(`LICENSE.txt`, and Jansson's as `LICENSE-jansson.txt`).

When the IDE starts, it adds every external in a folder of `Ext` to
the externals of stack "Home" and loads the folder's libraries
(`revInternal__SetupExternals` and `revInternal__InitialiseLibraries` in
`ide/Toolset/home.livecodescript`). The library puts `JSONToArray` and
`ArrayToJSON` in the back scripts, so a stack's own handlers with those
names, and a library it starts using, come first, as they did in
LiveCode. The Standalone Settings list mergJSON under "Inclusions", and
a standalone that uses it gets the external and the library, but only
for the platforms whose build the package has: a Windows x64 install
builds x64 Windows standalones with it, not 32-bit ones.

## Tests

`tests/lcs/ext/mergjson.livecodescript` loads the external and the
library as the IDE does and pins what a script sees from them, as a
stack written for LiveCode's mergJSON would see it, quirks included (a
number keeps the text it had in the JSON; text that reads as a number is
written as one). It runs Jansson against the JSONTestSuite cases that
the JSON library is checked against, with the same six exceptions that
mergJSON's own `tests/broken.json` lists. The IDE tour's `ext-mergjson`
step (`tools/ci/ui-tour.livecodescript`) checks a package: that the IDE
loaded the external and the library from `Ext/mergJSON`, that JSON goes
both ways, and that the standalone builder would include this
computer's build.
