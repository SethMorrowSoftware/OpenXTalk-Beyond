# The web IDE

The web IDE is the OXT-Beyond IDE running in a web page, with nothing to
download or install. It is the real IDE, the same scripts and stacks as the
desktop's, run by the IDE's own engine (development mode) built for the web
with Emscripten. The page fills the browser window, with the menu bar and
toolbar across the top. A button at the top right makes it full screen.
The IDE follows the browser between light and dark: its page asks for
the browser's colour scheme (`<meta name="oxt-appearance" content="system">`
in [index.html](index.html)), so `the systemAppearance` is the browser's
and the IDE hears `systemAppearanceChanged` when it changes. A web
standalone stays light unless its page asks the same (the HTML5 pane's
Appearance in the Standalone Settings).

What works in it:

- Home, the welcome stack the IDE opens with
  ([palettes/web home](../../ide/Toolset/palettes/web%20home/revwebhome.livecodescript)):
  live demos of what a stack can do in a browser, and the way to a new
  stack, the lessons, the examples and the Dictionary. Its "Show Home at
  startup" switch turns that off, and Help > Welcome to OXT-Beyond opens
  it again;
- Learn, the IDE's window for the lessons and the examples
  ([palettes/learn](../../ide/Toolset/palettes/learn/revlearn.livecodescript)),
  in Home's look: Help > Lessons, Help > Demos and Sample Stacks open it,
  and with the Option (Alt) key down they open the classic stacks. The
  page does not carry the guides' stack, so its Guides tab offers the
  User Guide PDF;
- the xTalk Academy, a course in programming for beginners and schools
  ([palettes/academy](../../ide/Toolset/palettes/academy/revacademy.livecodescript)):
  Help > xTalk Academy, Learn's lessons page and Home's "Learn to code"
  open it, and its playground runs each lesson's code in the page;
- making stacks, with the Tools palette, the Property Inspector and the
  Message Box;
- the Script Editor, with colouring, compile errors and the handler list;
- browse mode, which runs the stacks' scripts;
- the Dictionary, its API entries and its Guide;
- Help > Release Notes, the changes of every release (the page carries
  the changelog, the README's notes and the history);
- saving stacks: they are kept in the browser's storage (IndexedDB) between
  visits, in `~/Documents`. File > Download Stack gives the user a copy of
  the stack's file, and File > Open Stack opens one from their computer.
  The IDE's preferences (Open Recent, where the palettes are, ...) are kept
  there too;
- the extensions that are scripts or LiveCode Builder modules (widgets and
  libraries);
- revXML, revZip, revDB with SQLite, and revSpeech, which the web engine
  has built in.

What it leaves out (`revWebIDEMenu` in
[revwebidelibrary.livecodescript](../../ide/Toolset/libraries/revwebidelibrary.livecodescript)),
because a browser cannot do it: building standalones, the Extension
Builder (it runs `lc-compile`), quitting, update checks, the guides that
the page does not carry, the Resource Center and the tutorials. The zip
also leaves out the files of the Script Editor's font, Source Code Pro,
which the web engine cannot load (code shows in Droid Sans Mono, which the
Dictionary carries), and an unused archive of the Linux theme. A browser
keeps some shortcuts for itself (Ctrl+W closes the tab, Ctrl+N and Ctrl+T
open windows), so their menu items are picked with the mouse. The page asks
before it is closed once the IDE has started.

## Downloading it

Releases carry the web IDE as `OXT-Beyond-<version>-web-ide.zip`, from
the release after 0.2.7-rc.6.1 on. Extract it and, in its folder,
double-click `Start Web IDE.bat` on Windows or run `python3 serve.py`
on macOS and Linux: [serve.py](serve.py) serves the folder on this
computer only, at `http://localhost:8000/` (`python3 serve.py 8080` for
another port), and opens it in the browser. It needs Python 3 and
nothing else. To put it on a web site instead, copy the folder's files
to any web server (see "Serving it" below); serve.py and the `.bat` are
not needed there. The zip's [README.txt](README.txt) says the same for
the people who download it.

The release's zip is made by `.github/workflows/web-ide.yml` when
`.github/workflows/release.yml` calls it: the web IDE's engine built
from the release's commit, with the IDE of the release's own Linux
x86_64 package as it is (`build_site.py --zip`). Every other run of
`web-ide.yml` (a pull request or a push to main that changes the web
IDE, or a run by hand) makes the same zip, from the newest release's
IDE with the commit's scripts over it, as the artifact
`OXT-Beyond-web-ide`, which the run's summary links.

## How it is put together

| Part | Where |
| --- | --- |
| The engine, `development-community-<version>.js` and `.wasm` | `engine/engine.gyp`, targets `development-web` and `javascriptify-development`; `engine/src/mode_development.cpp` loads the IDE from `/boot` |
| The IDE's web branches | `revEnvironmentIsWeb()` in `ide/Toolset/home.livecodescript`, and the library `revWebIDELibrary`, which Home loads only on the web |
| The page | [index.html](index.html) |
| The site | [build_site.py](build_site.py): the page, the engine and `ide.zip` (the IDE, which the engine unpacks into `/boot`) |
| The download | `build_site.py --zip`: the site in one folder, with [serve.py](serve.py), [Start Web IDE.bat](Start%20Web%20IDE.bat) and [README.txt](README.txt) |

Every change to the engine for the web IDE is in code that only the web
engine compiles, and every change to the IDE's scripts asks
`revEnvironmentIsWeb()` first, so the desktop engines and the desktop IDE
work as before. The page is the IDE's screen: no window manager keeps a
window on it, so `revWebIDELibrary` keeps the palettes on the page and a
stack the user opens below the menu bar. The bugs of the web engine that
the web IDE found were fixed for web standalones too.

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

Add `--zip OXT-Beyond-<version>-web-ide.zip` to also write the
download zip (the zip goes outside the site's folder).

## Serving it

The site is static files. Any web server can serve it, with `.wasm` served
as `application/wasm`; a browser loads no WebAssembly from a `file:`
address. To try it on your own computer:

```sh
cd web-ide-site && python3 -m http.server 8000
```

(or run `python3 tools/web-ide/serve.py` from a copy of it in the site's
folder, as the download zip has it)

and open `http://localhost:8000/`. The first visit downloads about 59 MB
(the engine and the IDE), which the browser then keeps in its cache. The
page asks for the engine and the IDE with the site's stamp (`?v=`, a
digest of the three files, which `build_site.py` puts in the page), so a
browser that kept another version's copies, from the same address, never
starts them with this version's.

The page also keeps its own copy of the engine's WebAssembly and of the
IDE in the browser's Cache Storage, under those stamped addresses, so a
later visit downloads neither, whatever the server's cache headers say
(GitHub Pages allows ten minutes). The engine is compiled as it arrives
(`WebAssembly.compileStreaming`), not once all of it is here, and the
progress bar counts to the sizes `build_site.py` measured, so a server that
compresses (GitHub Pages gzips) does not throw it off. A new stamp's copies
replace the old ones once both are kept. The copy is a convenience only: a
browser that cannot keep one (a page that is neither https nor localhost, a
private window, no room) or lacks streaming compilation loads the IDE as
before, with XMLHttpRequest, and so does a load whose quicker way fails; a
start that fails deletes the copy, so the next visit downloads it again.
Its script carries `data-cfasync="false"`, so Cloudflare's Rocket Loader
leaves it as it is.
