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

The page asks for the engine and `standalone.zip` with the site's stamp
(`?v=`, a digest of those files, which `build_player.py` puts in the
page), so a browser or a CDN that kept another version's copies under the
same names never starts them with this version's. Its scripts carry
`data-cfasync="false"`, so Cloudflare's Rocket Loader leaves them as they
are. Behind a CDN, purge its cache when the site is updated from a release
before this one, which had no stamp.

The home page offers **Open a stack**, **Open a folder** and a drop zone
(a stack file, a folder, or a `.zip` holding a stack and the files it
uses), three whole stacks to play (**OXT-Beyond on the Web**, a tour of
what a stack can do in a page; **Learn xTalk**, a first course in ten
lessons; and the **xTalk Primer**, a home stack of examples), the stacks
opened before as cards (the bin on a card removes it), small samples
(**Fireworks**, animation by script; **Live Weather**, a forecast fetched
with `put url`; **Web Audio Piano**, sound made through `do ... as
"JavaScript"`; **Neon Snake**, a game whose best scores the browser keeps;
**QR Studio**, QR codes from the QR library, downloaded as PNG files;
**Talking Robot**, the browser's speech voices; **2048**, a game of
sliding tiles; **Quake Map**, live earthquakes from the USGS on a map;
**Beat Box**, a drum machine timed by Web Audio; **Kanban Board**,
cards dragged between columns; **Markdown Notes**, Markdown styled as you
type; **UI Gallery**, modern controls in a light and a dark theme;
**Photo Lab**, a photo of your own with looks and adjustments, downloaded
at full size; and three that the build makes), and **About**, which says in plain English
what works on the web, what works differently and what does not. The
stack then takes the page (`?mode=window` opens it in a window of its own
instead), and the bar above it has **Library** (back home), **Reload**
(the stack again as it was saved), **Download copy** (the stack as it is
now, as a download) and full screen. It follows the system's light or
dark theme. The page wears OXT-Beyond's own look, the site's front page
and web stacks gallery's: the logo's night sky and its fire. Its logo and
pictures are in `assets/`.

What it carries, so that a stack finds what its own web standalone
would: every script library (the Data Grid, Animation, Geometry, Internet,
Printing, Table, XML-RPC), the externals the web engine has (revXML,
revZip, revDB with SQLite, revSpeech) and every widget and library
extension whose platforms include the web. A stack's files go into the
browser's storage for the site (`/livecode/Documents/Stack Player`), so
the list, and whatever the stacks saved, are still there on the next
visit. A stack finds the files that came with it (opened with it, in its
folder, or in its `.zip`) as it would on the desktop: by paths relative to
its own folder, which is the `defaultFolder` while it is open, and through
`specialFolderPath("resources")`, which is still `/boot/standalone`, the
player's own folder, but has a link to each file and folder beside the
stack while it is open (a name the player's own files have there,
`DroidSansCombined.ttf` or an `extensionNN` folder, is not linked). A script error shows in a dialog with the object and the line.

The xTalk Suite's native libraries that have a web build (box2dxt's
Box2D, so the platformer and the Box2D games; sodiumxt, coinxt, and
datachannelxt over the browser's own WebRTC) are linked into the web
engine the player is built on, as into every HTML5 standalone's
(EXPERIMENTAL; `engine/src/em-xtalk-web.cpp`).

Not yet: extensions that are a layer over a native library with no web
build (torrentxt's torrents, enetxt's ENet). Such a stack opens and stops
where it first calls one, and the player names the extension instead of
showing its error trace. Also opening a stack from a URL, and
extensions that are not installed with OXT-Beyond.

HyperCard stacks open as File > Import Stack opens them on the desktop.
The player carries the IDE's HyperCard libraries
(`revhypercardscriptlibrary`, `revhypercarddiskimagelibrary` and
`revhypercardmacelibrary`, made substacks of the player by
`build-player.livecodescript`; the last, which decodes a stack's MACE
sounds into audio clips, is under the LGPL 2.1 or later, as its header
says). A file is a
HyperCard stack by its first bytes, whatever its name: the stack itself
(with its resource fork beside it as `Name.rsrc` or `._Name`, or in a
zip's `__MACOSX` folder), a MacBinary or BinHex copy, or an AppleSingle
file. It is imported once, with messages locked, its scripts are made to
compile here (`revHyperCardFixScripts`) and it is given the HyperCard
Library, and then it opens with its own messages. A Mac disk image (raw
HFS, DiskCopy 4.2, or a CD image with an Apple partition map), given
alone or in a folder or zip, lists its stacks to choose from; the one
chosen is copied out of it, with its resource fork, into the image's
folder of the library, beside a `Name.hcimage` file that names the image,
so that its scripts find the image's other stacks on a later visit too.

**A stack is a program.** In the player it can do what the page can:
run JavaScript, read and write what other stacks saved for that site, and
make requests with that site's cookies. Host the player on a site of its
own that holds nothing else of value.

## Files

| File | What it is |
|---|---|
| `stack-player.livecodescript` | the player stack's script |
| `build-player.livecodescript` | run by the IDE: makes the player stack (and the sample stacks) and builds it with `revSaveAsEmscriptenStandalone` |
| `index.html` | the page: the home, library, About panel and bar in HTML, and the engine's canvas for the stack; it writes the files it is given into the engine's `/uploads` and calls the player stack's `playerFromPage` |
| `stacks/` | the three stacks the home page features and the small samples with a picture, each with a picture of its first card (`.webp`, 960 wide at most); each one before the Phone Starter carries the colourized Script Viewer as a substack |
| `phone-starter.livecodescript`, `phone-starter-stack.livecodescript` | build `stacks/Phone Starter.oxtstack` (see below) |
| `assets/` | the page's logo and pictures, copied beside it |
| `build_player.py` | starts the IDE with the script above, puts the page in place, packs the zip and, with `--check`, drives the player in headless Chromium |

## The Phone Starter

`stacks/Phone Starter.oxtstack` is a stack to copy for a stack made for
phones, with the Mobile Web library
(`extensions/script-libraries/mobileweb`): a header, four cards under a
tab bar a thumb can reach (Home, List, Form, Gestures), a swipe left or
right to change tab, a list that scrolls with a finger, a form that stays
above the on-screen keyboard, and a pad (a group with its own `swipe`,
`pinch` and `longPress` handlers) for gestures. One line, `mwStart`,
makes it a phone stack: in a page of its own (an HTML5 standalone) it
fills the browser's window and fills it again when the phone turns, in
portrait or landscape (two columns, smaller bars, out of the notch); in
the player, whose page keeps its own layout, and on a desktop, it is a
phone-sized window. Without the library (an engine before 0.2.7) it still
opens and works, without the gestures.

The stack is never edited by hand. Its script is
`phone-starter-stack.livecodescript` and its controls are made by
`phone-starter.livecodescript`; change them, then build it again with any
OXT-Beyond engine:

```sh
<engine> -ui tools/web-player/phone-starter.livecodescript
```

`tools/ci/mobile_web_check.py` opens it on emulated phones (Playwright's
Pixel 7 and iPhone 13, in Chromium and WebKit) and checks the taps,
drags, swipes, pinch, long press, keyboard and turns (every card in
landscape must end above the tab bar); it fails if the
committed stack's script is not `phone-starter-stack.livecodescript`'s.
CI runs it in web.yml, after the web runtime check. To run it yourself:

```sh
python3 tools/ci/mobile_web_check.py --runtime <web runtime> --engine-cache <folder> --shots <folder>
```

## Building and checking it

With an OXT-Beyond package (or a build) and Playwright with Chromium:

```sh
python3 tools/web-player/build_player.py --install <OXT-Beyond-<version> folder> \
    --work web-player --zip OXT-Beyond-web-player.zip --check
```

The build also makes three sample stacks, which go into the folder's
`samples/` with the `samples.json` that the home page reads. `--check`
opens them: Tour through **Open stack** (a widget, a palette substack, a
script error, Download copy, Library), the Data Grid through its sample
card (the grid fills and reads its rows) and Data through **Open stack**
with its `note.txt` (revXML, SQLite and a file beside the stack); it also
opens About, then a second visit must still list all three, and removing
one must leave two. Last, a fresh browser opens each stack in `stacks/`
from its card, and none may report a script error (Live Weather opens
offline too: it says it could not reach open-meteo.com; Talking Robot
mimes the words in a browser with no voices, and Quake Map says it could
not reach earthquake.usgs.gov).
`OXT_CHROMIUM` names a Chromium to use instead of Playwright's.
Screenshots and the browser's console go to `<work>/check`. CI runs it in
build-linux.yml ("Web Stack Player") and attaches the zip to releases.
