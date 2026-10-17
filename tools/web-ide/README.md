# The web IDE

The web IDE is the OXT-Beyond IDE running in a web page, with nothing to
download or install. It is the real IDE, the same scripts and stacks as the
desktop's, run by the IDE's own engine (development mode) built for the web
with Emscripten. The page fills the browser window, with the menu bar and
toolbar across the top. A button at the top right makes it full screen.

What works in it:

- making stacks, with the Tools palette, the Property Inspector and the
  Message Box;
- the Script Editor, with colouring, compile errors and the handler list;
- browse mode, which runs the stacks' scripts;
- saving stacks: they are kept in the browser's storage (IndexedDB) between
  visits, in `~/Documents`. File > Download Stack gives the user a copy of
  the stack's file, and File > Open Stack opens one from their computer;
- the extensions that are scripts or LiveCode Builder modules (widgets and
  libraries);
- revXML, revZip, revDB with SQLite, and revSpeech, which the web engine
  has built in.

What it leaves out (`revWebIDEMenu` in
[revwebidelibrary.livecodescript](../../ide/Toolset/libraries/revwebidelibrary.livecodescript)),
because a browser cannot do it: building standalones, the Extension
Builder (it runs `lc-compile`), quitting, update checks, the guides that
the page does not carry, the Resource Center and the tutorials. A browser
keeps some shortcuts for itself (Ctrl+W closes the tab, Ctrl+N and Ctrl+T
open windows), so their menu items are picked with the mouse. The page asks
before it is closed once the IDE has started.

## How it is put together

| Part | Where |
| --- | --- |
| The engine, `development-community-<version>.js` and `.wasm` | `engine/engine.gyp`, targets `development-web` and `javascriptify-development`; `engine/src/mode_development.cpp` loads the IDE from `/boot` |
| The IDE's web branches | `revEnvironmentIsWeb()` in `ide/Toolset/home.livecodescript`, and the library `revWebIDELibrary`, which Home loads only on the web |
| The page | [index.html](index.html) |
| The site | [build_site.py](build_site.py): the page, the engine and `ide.zip` (the IDE, which the engine unpacks into `/boot`) |

Every change to the engine for the web IDE is in code that only the web
engine compiles, and every change to the IDE's scripts asks
`revEnvironmentIsWeb()` first, so the desktop IDE and the web standalone
engine work as before.

## Building it

On Linux, with what [`tools/ci/build-web.sh`](../ci/build-web.sh) needs
(BUILDING.md, "Building the web engine"):

```sh
tools/ci/build-web-ide.sh <installed OXT-Beyond> web-ide-site
```

`<installed OXT-Beyond>` is an installed or extracted Linux OXT-Beyond, whose
built parts (its Extensions, Dictionary and binary stacks) the site takes,
with this checkout's script-only stacks over them. The script builds the
libraries if they are missing, then the web IDE's engine, then the site.
After a change to the IDE's scripts only, the site can be made again from
the engine already built:

```sh
python3 tools/web-ide/build_site.py --install <installed OXT-Beyond> \
    --engine build-emscripten/livecode/out/Release --out web-ide-site --repo .
```

## Serving it

The site is static files. Any web server can serve it, with `.wasm` served
as `application/wasm`; a browser loads no WebAssembly from a `file:`
address. To try it on your own computer:

```sh
cd web-ide-site && python3 -m http.server 8000
```

and open `http://localhost:8000/`. The first visit downloads about 57 MB
(the engine and the IDE), which the browser then keeps in its cache.
