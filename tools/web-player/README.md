# The Stack Player

A web page that opens any stack you give it, so that people can try a
stack in a browser without installing anything. It is OXT-Beyond's web
engine (Runtime/Emscripten) with one small stack, "Stack Player", built as
an ordinary web standalone by the IDE's own web builder. Experimental
since 0.2.7-rc.3; no engine change was needed for it.

## Using it

Releases carry it as `OXT-Beyond-<version>-web-player.zip`. Put the folder
in that zip on any web server and open its `index.html` (a browser will
not run the engine's `.wasm` from a file on disk). For a quick try:

```sh
cd StackPlayer && python3 -m http.server 8000
# then open http://localhost:8000/index.html
```

Then **Open...** (or drop on the page) a stack file, a folder, or a
`.zip` holding a stack and the files it uses. The stack takes the page
(`?mode=window` opens it in a window of its own instead). The bar above it
has **Home** (back to the player's list), **Reload** (the stack again as
it was saved) and **Download copy** (the stack as it is now, as a
download).

What it carries, so that a stack finds what its own web standalone
would: every script library (the Data Grid, Animation, Geometry, Internet,
Printing, Table, XML-RPC), the externals the web engine has (revXML,
revZip, revDB with SQLite, revSpeech) and every widget and library
extension whose platforms include the web. A stack's files go into the
browser's storage for the site (`/livecode/Documents/Stack Player`), so
the list, and whatever the stacks saved, are still there on the next
visit. A script error shows in a dialog with the object and the line.

Not yet: HyperCard stacks (they import and draw, but `go` never returns
on the web, an engine bug still to fix), opening a stack from a URL, and
extensions that are not installed with OXT-Beyond.

**A stack is a program.** In the player it can do what the page can:
run JavaScript, read and write what other stacks saved for that site, and
make requests with that site's cookies. Host the player on a site of its
own that holds nothing else of value.

## Files

| File | What it is |
|---|---|
| `stack-player.livecodescript` | the player stack's script |
| `build-player.livecodescript` | run by the IDE: makes the player stack (and the sample stacks) and builds it with `revSaveAsEmscriptenStandalone` |
| `index.html` | the page: the engine's own page with the bar above the stack |
| `build_player.py` | starts the IDE with the script above, puts the page in place, packs the zip and, with `--check`, drives the player in headless Chromium |

## Building and checking it

With an OXT-Beyond package (or a build) and Playwright with Chromium:

```sh
python3 tools/web-player/build_player.py --install <OXT-Beyond-<version> folder> \
    --work web-player --zip OXT-Beyond-web-player.zip --check
```

`--check` opens the sample stacks the build made: Tour (a widget, a
palette substack, a script error, Download copy, Home), Grid (the Data
Grid fills and reads its rows) and Data (revXML, SQLite and a file beside
the stack), then a second visit that must still list all three.
`OXT_CHROMIUM` names a Chromium to use instead of Playwright's.
Screenshots and the browser's console go to `<work>/check`. CI runs it in
build-linux.yml ("Web Stack Player") and attaches the zip to releases.
