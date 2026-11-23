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

On a phone (a touch screen whose short side is 600 pixels or less) a
stack has the whole screen. The page takes `data-mobile-web-fill="no"`
off its body there, so a stack made for phones that calls `mwStart` fills
the screen as it does in a standalone of its own; any other stack is
fitted to the screen (`mwFitStack`: scaled to it, and fitted again when
the phone turns), and taps land on the controls under them. The menu bar
and the window's title step aside for one round button, back to the
library, which leaving a stack also gives back the page's own look
(`mwStop`). Anywhere else a stack is shown in its window, at its own size,
as before.

If the engine stops in a browser (it runs out of the stack the browser
gives a page, as on an older build on an iPhone or an iPad, or
WebAssembly fails), a note across the top of the page says so, with the
browser's words and its user agent, instead of a blank page. A
standalone's page (`engine/rsrc/emscripten-html-template.html`) does the
same.

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
**Beat Box**, a drum machine timed by Web Audio; **Beyond Beats**, a
beat studio with a channel rack, a playlist, a piano roll and a mixer,
its sounds made by Web Audio; **Kanban Board**,
cards dragged between columns; **Markdown Notes**, Markdown styled as you
type; **UI Gallery**, modern controls in a light and a dark theme;
**Photo Lab**, a photo of your own with looks and adjustments, downloaded
at full size; **Box2Dxt Platformer**, the xTalk Suite's seven scrolling
levels on Box2D; **Render3D Tour**, ten small 3D scenes drawn by the
xTalk Suite's render3dxt; and three that the build makes), and **About**, which says in plain English
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
browser's storage for the site (`/openxtalk/Documents/Stack Player`), so
the list, and whatever the stacks saved, are still there on the next
visit. A stack finds the files that came with it (opened with it, in its
folder, or in its `.zip`) as it would on the desktop: by paths relative to
its own folder, which is the `defaultFolder` while it is open, and through
`specialFolderPath("resources")`, which is still `/boot/standalone`, the
player's own folder, but has a link to each file and folder beside the
stack while it is open (a name the player's own files have there,
`DroidSansCombined.ttf` or an `extensionNN` folder, is not linked). A script error shows in a dialog with the object and the line.

The xTalk Suite's native libraries that have a web build (box2dxt's
Box2D, so the platformer and the Box2D games; box3dxt's Box3D and its
renderer; render3dxt, so the Render3D Tour; sodiumxt, coinxt,
datachannelxt over the browser's own WebRTC, audioxt's miniaudio over
Web Audio, xlsxt's Excel files, written into the page's own file
system, gamepadxt, which reads game controllers through the browser's
Gamepad API, webpxt's WebP pictures, barcodext's barcodes and midixt,
which reaches MIDI devices through the browser's Web MIDI once the
visitor allows it) are linked into the web
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

A HyperCard stack already converted to a stack file before File > Import
Stack fixed its scripts (an import in 0.2.6 or earlier, or one with Make
HyperTalk Scripts Compile turned off) opens as it is. Such a stack often
stops with "can't find handler": one HyperTalk line that this engine does
not compile takes every handler of its script with it, and its XCMDs have
no stand-ins. When it does, and it is one (the importer's mark,
`uHyperCard["source"]`, no behavior, and a script that does not compile or
an XCMD of its own that it calls and nothing defines), the player says so
and offers **Fix and Reopen**: the stack opens again with HyperCard's
message order and its scripts fixed as the import fixes them now
(`revHyperCardFixScripts`), only in memory; the file in the library is not
changed. A stack that plays without such an error is never changed.

**A stack is a program.** In the player it can do what the page can:
run JavaScript, read and write what other stacks saved for that site, and
make requests with that site's cookies. Host the player on a site of its
own that holds nothing else of value.

## The bare player

`play/` beside the player (`<site>/play/` on the web site) is a second
page on the same engine and player stack that shows the stack and nothing
else: no bar, no window around it, no library or logo, on a plain black
page (LittleNemo, openxtalk.org p=26036). It is for putting a stack on a
page of its own, as an HTML5 standalone would be, without building one.
What it plays is in the address:

| Address | What |
| --- | --- |
| `play/?stack=games/my.oxtstack` | a stack file, or a `.zip` of a stack and its files, on the same site (relative to the page, or from the site's root). Another site's file is refused: the stack would run as this site, with what other stacks saved here |
| `play/?play=2048` | one of the player's samples, by its title |
| `&align=top-left` | the stack at the top left; by default it is in the middle of the window, scrolled from its top left when it is bigger |
| `&bg=white` | the colour around the stack (any CSS colour) |
| `&mode=window` | as in the player: the stack in a window of its own |
| `&fill=yes` | the stack fills the window on a desktop too, as on a phone: one made with the Mobile Web library fills it, and any other is scaled to fit it (its whole card, as big as fits) and fitted again when the window changes size. Without it a stack is shown at its own size, as before |

With neither `stack` nor `play` it offers one Open button, and takes a
stack dropped on it. On a phone (a coarse pointer and a short side of 600
or less, the test the player's own page makes) the page takes off its
`data-mobile-web-fill="no"`, so the player stack gives a stack the whole
screen (#348): one that calls the Mobile Web library's `mwStart`,
`mwFillScreen` or `mwFitStack` fills it, as on its own page, and the
Phone Starter does. Anywhere else the page keeps the attribute and shows
every stack at its own size, as the player does; without it the player
took a desktop browser for a phone and scaled every stack up to the
window. On a tablet (another touch screen, an iPad) the page sets
`data-mobile-web-fill="touch"`: a stack made with the Mobile Web library
(its scripts call `mwStart`, `mwFillScreen` or `mwFitStack`) has the
whole screen there too, so the Responsive Starter is laid out as a
tablet's, and every other stack opens as it does on a desktop, at its own
size and never fitted; the player's own page does the same, with its bar
out of the way only for a stack that filled the screen. It keeps out of a phone's notch and home bar
(`viewport-fit=cover` and the safe-area insets) and uses `100dvh`, which
iOS Safari's toolbar does not cover; a stack the library makes as big as
the page (`mwFillScreen`, or `mwStart` with a resizable stack such as the
Phone Starter) keeps out of them itself, so the page takes its padding off
for it (the library marks the html element `data-mobile-web-filled="fill"`).
Before, an iPhone on its side showed such a stack moved in from the left by
the inset and cut off as much on the right. The stacks it opens go into the
same library as the player's (the browser's storage for the site).
`build_player.py --check` opens it (`check_bare`: a sample at its own
size in the middle with nothing around it, the page's colour just past
the edges of what is drawn and not just inside them, a stack of the site
at the top left, another site's refused, and the Phone Starter drawn to
both sides, the top and the bottom of an iPhone's window, read from the
screenshot's pixels and not only the canvas's size, in Chromium and,
where Playwright's WebKit is installed, in WebKit), and `check_tablet`
opens the Responsive Starter and 2048 on an iPad Mini, portrait and
landscape, in both pages: the one drawn to the window's corners, the other
with the same rect and canvas as on that iPad with the page's touch test
answering no.

## Files

| File | What it is |
|---|---|
| `stack-player.livecodescript` | the player stack's script |
| `build-player.livecodescript` | run by the IDE: makes the player stack (and the sample stacks) and builds it with `revSaveAsEmscriptenStandalone` |
| `play.html` | the bare player (above), written as `play/index.html` |
| `index.html` | the page: the home, library, About panel and bar in HTML, and the engine's canvas for the stack; it writes the files it is given into the engine's `/uploads` and calls the player stack's `playerFromPage` |
| `stacks/` | the three stacks the home page features and the small samples with a picture, each with a picture of its first card (`.webp`, 960 wide at most); each one before the Phone Starter carries the colourized Script Viewer as a substack |
| `phone-starter.livecodescript`, `phone-starter-stack.livecodescript` | build `stacks/Phone Starter.oxtstack` (see below) |
| `responsive-starter.livecodescript`, `responsive-starter-stack.livecodescript` | build `stacks/Responsive Starter.oxtstack` (see below) |
| `nova-rescue.livecodescript`, `nova-rescue-stack.livecodescript`, `nova-rescue/` | build `stacks/Nova Rescue.oxtstack` from Kenney's pictures, sounds and font (see below) |
| `wobble-forts.livecodescript`, `wobble-forts-stack.livecodescript`, `wobble-forts/` | build `stacks/Wobble Forts.oxtstack` from Kenney's pictures, sounds and font and its levels (see below) |
| `puzzle-almanac.livecodescript`, `puzzle-almanac-stack.livecodescript`, `puzzle-almanac/` | build `stacks/Puzzle Almanac.oxtstack` from Kenney's pictures and sounds, Atkinson Hyperlegible, its puzzles and its words (see below) |
| `ember-bricks.livecodescript`, `ember-bricks-stack.livecodescript`, `ember-bricks/` | build `stacks/Ember Bricks.oxtstack` from its levels, the sounds made for it and Atkinson Hyperlegible (see below) |
| `beyond-beats.livecodescript`, `beyond-beats-stack.livecodescript`, `beyond-beats/` | build `stacks/Beyond Beats.oxtstack` with its audio core (see below) |
| `box2dxt-platformer.livecodescript`, `box2dxt_platformer_files.py`, `box2dxt-platformer/pin.json` | build `stacks/Box2Dxt Platformer.oxtstack` from the xTalk Suite's platformer and sheets, as pinned (see below) |
| `render3d-tour.livecodescript`, `render3d-tour-stack.livecodescript` | build `stacks/Render3D Tour.oxtstack` from its script alone (see below) |
| `assets/` | the page's logo and pictures, copied beside it |
| `build_player.py` | starts the IDE with the script above, puts the page in place, packs the zip and, with `--check`, drives the player in headless Chromium |

## The Phone Starter

`stacks/Phone Starter.oxtstack` is a stack to copy for a stack made for
phones, with the Mobile Web library
(`extensions/script-libraries/mobileweb`): a header, five cards under a
tab bar a thumb can reach (Home, List, Form, Gestures, Phone), a swipe
left or right to change tab, a list that scrolls with a finger, a form
that stays above the on-screen keyboard, a pad (a group with its own
`swipe`, `pinch`, `longPress` and touch handlers, which draw a ring under
each finger; a pinch sizes the dot round its centre and moves it with the
fingers) for gestures, and a Phone card that takes a photo, shares,
finds where the phone is, rolls a ball as it tilts, keeps the screen on
and hides the browser's bars. One line, `mwStart`,
makes it a phone stack: in a page of its own (an HTML5 standalone) it
fills the browser's window and fills it again when the phone turns, in
portrait or landscape (two columns, smaller bars, out of the notch); in
the player on a desktop, whose page keeps its own layout, it is a
phone-sized window, and in the player on a phone it fills the screen. Without the library (an engine before 0.2.7) it still
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
drags, swipes, pinch, long press, fingers, keyboard, the Phone card (a
location it is given, a photo through the file chooser, a tilt it
makes) and turns (every card in landscape must end above the tab bar);
it fails if the
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

## The Responsive Starter

`stacks/Responsive Starter.oxtstack` is a stack to copy for one stack
that is laid out for a phone, a tablet and a desktop, with the Mobile Web
library's layout rules (`mwResponsive`; the guide *Stacks for Every
Screen*): Places, three cards (Explore, Saved, How it works) under a tab
bar on a phone, a rail on a tablet and a sidebar on a desktop; a grid of
places in one, two or three columns; a place's details in a sheet over
the grid on a phone and a pane beside it on a tablet or a desktop; a
search, keys and hover for a mouse, and a dark look. Every control's
place is a rule in its `mwLayout` custom properties, which the builder
sets; the stack's script does only what a rule cannot say, in
`rsAfterLayout` and `layoutChanged`.

The stack is never edited by hand. Its script is
`responsive-starter-stack.livecodescript` and its controls are made by
`responsive-starter.livecodescript`; change them, then build it again
with any OXT-Beyond engine:

```sh
<engine> -ui tools/web-player/responsive-starter.livecodescript
```

`tools/ci/responsive_web_check.py` opens it on an iPhone 13, an iPad Mini
and a desktop (light and dark), in Chromium and WebKit, and checks each
layout, the sheet and the pane, a turn, a notch, the keys, a narrow
window and the look; it fails if the committed stack's script is not
`responsive-starter-stack.livecodescript`'s. CI runs it in web.yml, after
the Mobile Web check. To run it yourself:

```sh
python3 tools/ci/responsive_web_check.py --runtime <web runtime> --engine-cache <folder> --shots <folder>
```

## Nova Rescue

`stacks/Nova Rescue.oxtstack` is a game made for a phone: a rescue
cutter flies up through a dying star system, a finger dragged anywhere
flies it (it fires on its own), and flying over the astronauts drifting
down rescues them. Rescues in a row raise a bonus, up to five times; one
that drifts away starts it again. Meteors split when shot, raiders dive,
weave and fire, power-ups drop (twin lasers, a shield, a repair, stars),
a sector ends when its crew is rescued and every fourth with a
mothership. Its best score, stars and settings are kept between visits.
In a page of its own it fills the phone's screen, upright or turned
(then the play area is a column with the score beside it), keeps out of
the notch (the Mobile Web library's safe-area insets) and pauses when the page is hidden or the phone turns; on a
desktop it plays with the mouse and the arrow keys (P pauses).

How it is made, for anyone making a game like it: one card; every screen
a group over the play area; a fixed set of buttons for each kind of
thing that flies, each showing a picture of a hidden "Art" card as its
icon, moved by one loop that moves everything by the time since the last
frame; the sounds mixed by the browser's Web Audio (the engine plays one
at a time). The card's colour is a colour, not a pattern: a pattern cost
most of a frame on a phone. In headless Chromium emulating a phone it
kept 55 to 60 frames a second, the game's own work under a millisecond
of each (nrState's fps, work and draw say so on any screen).

Its pictures, sounds and font are Kenney's (https://kenney.nl), CC0, in
`nova-rescue/` with each pack's licence and `SOURCES.md`, which says
where each comes from. `nova-rescue/make_assets.py` made them from the
packs: the pictures drawn again at two or three times their size from
Kenney's vector sheets, for a phone's screen, the sounds as WAV files
(Ogg is not played by older iPhones), and the title's NOVA drawn from the
font with a true V (KenVector Future draws V as U). No word written in
that font has a V; `tools/ci/tests/test_nova_rescue.py` holds it so.

The stack is never edited by hand. Its script is
`nova-rescue-stack.livecodescript` and its controls are made by
`nova-rescue.livecodescript`; change them, then build it again with any
OXT-Beyond engine:

```sh
<engine> -ui tools/web-player/nova-rescue.livecodescript
```

`tests/lcs/webplayer/nova-rescue.livecodescript` plays it on a desktop
engine (and in the web engine, with the other script tests) with the
clock in the test's hands: rescues and the bonus, hits, the end of a run,
the best score kept, lasers, power-ups, sectors and the mothership, the
screens at five sizes and a turn in the middle of a run.
`tools/ci/nova_rescue_check.py` plays it on emulated phones (Pixel 7 and
iPhone 13, in Chromium and WebKit) with real touches: Play, a finger that
flies the ship, a rescue, Pause, the frame rate, a turn and no script
error. CI runs it in web.yml, after the Responsive Starter's check.

It also has a page of its own on the web site's gallery
(`games/nova-rescue/`, see [tools/pages](../pages/README.md)), which
plays this sample in the bare player. The stack's `cJavascriptHandlers`
are `nrPageHidden` (the page is hidden: a run pauses) and `nrState`, so
that `tools/pages/check_nova_rescue_page.py` can ask the game how it is
there; `build_player.py --check` runs that check on the player it
builds. To run the phone check yourself:

```sh
python3 tools/ci/nova_rescue_check.py --runtime <web runtime> --engine-cache <folder> --shots <folder>
```

## Wobble Forts

`stacks/Wobble Forts.oxtstack` is a slower game for a phone, on Box2D
(the Box2Dxt extension): the round Bloops are pulled back in a launcher
and let go at the wobbly forts of the square Grumps, built of wood,
glass, stone, metal and TNT. A Grump pops when it is hit hard enough or
falls; a block breaks as it is hit, a little at a time, glass soonest and
metal hardly at all, and TNT goes off. Each Bloop has a trick, done by a
tap in flight: the blue one dashes, the pink one splits in three, the
green one slams down, the beige one bursts; the yellow one has none.
Fifteen forts in three lands (the Meadow, the Dunes and Shroom Hollow),
each land ending in a boss; a fort cleared with Bloops to spare earns up
to three stars, and the stars, best scores and settings are kept between
visits. Upright or turned, the world is drawn to fit the window, under
the notch; P or Esc pauses, R plays the level again.

How it is made: one card; every screen a group over the world; a set of
buttons for the pieces, each showing a picture of a hidden "Art" card as
its icon, and a few more for the dust, the debris and the points that
fly; one loop that steps the world by a sixtieth of a second at a time
and moves only the buttons whose piece moved (a fort at rest costs
almost nothing). The levels are text, `wobble-forts/levels.txt`, one line
a piece; the tests hold that every one stands still until it is hit. The
sounds are mixed by the browser's Web Audio, faster for a small piece's
knock than a big one's. In headless Chromium emulating a phone it kept
60 to 80 frames a second, the game's own work about a millisecond of
each (wfState's fps, work, draw and step say so).

Without Box2Dxt (an engine or a page without the extension) the game
says so on its first card and plays nothing; a web standalone needs the
extension's module among its deploy's modules, as the check below does.

Its pictures, sounds and font are Kenney's (https://kenney.nl), CC0, in
`wobble-forts/` with each pack's licence and `SOURCES.md`, which says
where each comes from. `wobble-forts/make_assets.py` made them from the
packs: the pictures drawn again at twice their size from Kenney's vector
sheets, the sounds as WAV files, and the title's words drawn from Kenney
Blocks. None of them is used by Nova Rescue, the platformer or Pixel
Maker.

The stack is never edited by hand. Its script is
`wobble-forts-stack.livecodescript` and its controls are made by
`wobble-forts.livecodescript`; change them, then build it again with any
OXT-Beyond engine:

```sh
<engine> -ui tools/web-player/wobble-forts.livecodescript
```

`tests/lcs/webplayer/wobble-forts.livecodescript` plays it on a desktop
engine with the clock in the test's hands: every level read and standing
still, a shot and the next Bloop, a fort cleared and the stars kept, out
of Bloops, every trick, a pause, a saved file that makes no sense and the
screens at six sizes. Its tests of play need Box2Dxt: `OXT_BOX2DXT`
names its folder (or an installed IDE's folder), and without it they are
skipped. `tools/ci/wobble_forts_check.py` builds a standalone with
Box2Dxt and plays it on emulated phones (Pixel 7 and iPhone 13, in
Chromium and WebKit) with real touches: Play, How to play, the map, a
pull and a shot, the frame rate, Pause, a fort cleared and its stars, the
next level, a turn upright and no script error. CI runs it in web.yml,
after Nova Rescue's check. To run it yourself:

```sh
python3 tools/ci/wobble_forts_check.py --runtime <web runtime> --engine-cache <folder> --shots <folder>
```

It also has a page of its own on the web site's gallery
(`games/wobble-forts/`, see [tools/pages](../pages/README.md)), which
plays this sample in the bare player. The stack's `cJavascriptHandlers`
are `wfPageHidden` (the page is hidden: a level pauses) and `wfState`, so
that `tools/pages/check_wobble_forts_page.py` can ask the game how it is
there; `build_player.py --check` runs that check on the player it builds.

## The Render3D Tour

`stacks/Render3D Tour.oxtstack` shows what render3dxt, the xTalk Suite's
3D renderer, can do, one thing at a time. It has ten exhibits: a sun
and its planets, with moons, a ring and a comet, where a click on a planet
flies the camera to it; the
shapes made to measure and a model; textures from a checkerboard, from
imageData and from a PNG with gaps; five materials; a sun and three
coloured lamps to switch by a click; a model read from the text of an OBJ
file; hills built corner by corner; fog between two rows of columns;
finding what is under the pointer and what a ray meets; and 225 cubes
moved in one call a frame. Drag the picture to look round, and turn the
wheel (or press + and -) to come closer. Every texture and model is made
in its script: the stack carries no file.

The picture is an ordinary image, 640 by 480, whose imageData render3dxt
writes. On a desktop the next picture is drawn on other threads while the
engine does its own work; in a browser there are none, so it is drawn at
once, and Smooth edges starts off there. The corner of the picture says
how many pictures a second it is showing. An engine without render3dxt
opens the stack on a notice and draws nothing.

`render3d-tour.livecodescript` builds it with any OXT-Beyond engine
(`<engine> -ui tools/web-player/render3d-tour.livecodescript`), from
`render3d-tour-stack.livecodescript`.
`tests/lcs/webplayer/render3d-tour.livecodescript` opens it on a desktop
engine and drives every exhibit through the hooks its script has
(`rtTestBegin`, `rtTestStep`, `rtClickView`, `rtHoverView`, `rtState`);
with `OXT_RENDER3DXT` set to a folder that has the extension it checks the
pictures, the click on a lamp and on a ball, the labels, the camera and
that closing gives back everything render3dxt made.
`tools/ci/tests/test_render3d_tour.py` holds the committed stack to its
script.

## The Box2Dxt platformer

`stacks/Box2Dxt Platformer.oxtstack` is the xTalk Suite's platformer
(`box2dxt/examples/box2dxt-platformer.livecodescript`): seven levels,
each its own scrolling world, played with the keys (the arrows or WASD to
run, Space to jump, again in the air for a double jump, Shift or X to
dash, Esc to pause), on Box2D through the b2k Game Kit that its script
carries. Collect every coin of a level and its flag turns gold; the
seventh flag wins. It is made for a window with a keyboard, 1024 by 640:
on a phone the player fits it to the screen, but it has no touch
controls.

It is the suite's game, not changed here. The game, and the five Kenney
sheets it draws from (CC0, the suite's `box2dxt/Spritesheets`), are not
kept in this repository: `box2dxt-platformer/pin.json` pins them to a
commit of the suite, each file to its size and SHA-256, and
`box2dxt_platformer_files.py` fetches them (or reads them from a checkout
of the suite, `--local`) and refuses any that is not the pinned one.
On its own first run the game asks for the sheets' folder, imports every
atlas, frame and sound into its stack and asks to save it
(pfImportMedia); `box2dxt-platformer.livecodescript` makes that import
with the game's own handlers, with no question asked, and saves the
stack, so that in the player it opens straight to its title with
everything inside it. The build is the same, byte for byte, wherever it
runs. The stack is never edited by hand: to take a newer platformer,
change the commit in `pin.json`, run `--repin` with `--local` at that
commit, then build it again with any OXT-Beyond engine:

```sh
python3 tools/web-player/box2dxt_platformer_files.py --out <dir>
OXT_PLATFORMER_FILES=<dir> <engine> -ui tools/web-player/box2dxt-platformer.livecodescript
```

`build_player.py --check` plays it: it opens on its title with no
question, Space builds level 1 and the arrows and Space play it, with no
script error. `tools/ci/tests/test_box2dxt_platformer.py` holds the pin,
the fetch and the stack to each other. Learn's gallery and the package
leave it out (`SHOWCASE_LEFT_OUT`), as the package has left out the
suite's demos since #298.

## Puzzle Almanac

`stacks/Puzzle Almanac.oxtstack` is a slow game for a phone, and for a
child as much as anyone: a daily book of two puzzles, the same for
everyone each day. Number Place is a grid of 4, 6 or 9 squares a side in
boxes, where every row, column and box holds each number once; every
puzzle has one answer, found by looking alone (no guess is ever needed),
with notes to pencil in, a hint, undo, and mistakes shown or not as the
settings say. Hidden Word is a word of 4, 5 or 6 letters to find in six
tries: a try's tiles turn gold for a letter in its place, blue for one in
another place and stone for one not in the word, and gold and blue carry
a mark as well as a colour; a try must be a word, and a word found says
what it means. The day's puzzle of each kind earns a sticker (thirty
animals, then gold stars) and keeps a run of days going; Practice gives
as many more as anyone likes, of any size or length. There is no clock,
no score and nothing lost for a wrong try. A voice can say each number
placed. On a computer the keys play it: N and W open the puzzles, the
arrows and 1 to 9 (or the letters and Enter) play, Esc goes back.

How it is made: one card; every screen (Home, Numbers, Words, Stickers)
a group and every panel (Done, Practice, How to play, Settings) a group
behind a veil; the tiles and stickers are buttons showing a picture of a
hidden "Art" card. Nothing runs while nothing moves. The puzzles are
`puzzle-almanac/data/numbers.txt`, 496 of them made by
`puzzle-almanac/make_puzzles.py` from a seed (`--check` makes them again
and compares), each with one answer found by singles alone. The game
makes the day's from one of them with its numbers renamed, its rows,
columns, bands and stacks reordered and perhaps turned half round, with a
random-number maker of its own, so that a day's puzzle is the same on
every engine. The hidden words, with what each means, are
`data/answers.txt`, written for the game; a try may be any word of
`data/words.txt`, ENABLE's words of 4 to 6 letters. What a player has
done is kept between visits (in the browser's storage on the web). A
board is a string of up to 81 digits, and `is` compares two strings that
look like numbers as numbers, to 15 digits or so, so the game compares
boards digit for digit (`paSameDigits`).

Its pictures and sounds are Kenney's (https://kenney.nl), CC0, from packs
none of the other games use; its font is Atkinson Hyperlegible, made for
low vision by the Braille Institute, under the SIL Open Font License.
`puzzle-almanac/make_assets.py` made the tiles and sparkles at three
times their size (the animals are Kenney's own, at twice theirs) and the
sounds WAV files, and gave the font Macintosh name records
that say what its Windows ones do: the web engine's font loader reads a
font's name from those, and without them the font loaded in no browser.
Each licence is in `puzzle-almanac/licenses/`, and `SOURCES.md` there says
where each file comes from.

The stack is never edited by hand. Its script is
`puzzle-almanac-stack.livecodescript` and its controls are made by
`puzzle-almanac.livecodescript`; change them, then build it again with
any OXT-Beyond engine:

```sh
<engine> -ui tools/web-player/puzzle-almanac.livecodescript
```

`tests/lcs/webplayer/puzzle-almanac.livecodescript` plays it on a desktop
engine with the clock and the day in the test's hands: the day's puzzles
of day 310, every square of each size answering a tap, a number placed,
a note, a hint and undo, a puzzle solved and its sticker, a word found
and one missed, tries that are not words, the stickers, the keys, a run
of days kept and broken, a saved file that makes no sense and the screens
at several sizes. `tools/ci/tests/test_puzzle_almanac.py` holds the stack
to its files and checks, with a port of the game's transform, that the
day's puzzle of any day has one answer found by looking.
`tools/ci/puzzle_almanac_check.py` builds a standalone and plays it on
emulated phones (Pixel 7 and iPhone 13, in Chromium and WebKit) with real
touches: How to play, a Number Place solved and its sticker, a Hidden
Word typed and found, the stickers, a reload that keeps them, a turn on
its side and no script error. CI runs it in web.yml, after Wobble Forts'
check. To run it yourself:

```sh
python3 tools/ci/puzzle_almanac_check.py --runtime <web runtime> --engine-cache <folder> --shots <folder>
```

It also has a page of its own on the web site's gallery
(`games/puzzle-almanac/`, see [tools/pages](../pages/README.md)), which
plays this sample in the bare player. The stack's `cJavascriptHandlers`
are `paPageHidden` (the page is hidden: the board is saved at once) and
`paState`, so that `tools/pages/check_puzzle_almanac_page.py` can ask the
game how it is there; `build_player.py --check` runs that check on the
player it builds.

## Ember Bricks

`stacks/Ember Bricks.oxtstack` is a brick breaker for a phone, a tablet
or a desktop, and the first of the samples that two people play together.
A paddle keeps a ball in the air and the ball breaks a wall of bricks:
plain ones, tough ones that take two hits and armoured ones that take
three, steel that no ball breaks, bombs that take their neighbours with
them, and embers that always drop a spark. Bricks broken one soon after
another raise the heat, which multiplies the score, up to five times, and
cools when the ball finds nothing. Ten sparks fall from broken bricks: a
wide paddle, three balls for one, a fireball that goes through bricks, a
slow ball, a paddle that grips, bolts from the paddle's ends, a net under
it, a life, and two dark ones not to catch (a small paddle, a fast ball).
There are twenty-four levels, which come round again faster with some
bricks made tough; a life is won every 20,000 points; the best score,
the levels reached and the settings are kept between visits.

It lays itself out for whatever window it has. The arena is always two
wide for three high, as large as fits; on an upright phone the score, the
heat and the lives are over it, and in a wide window (a phone on its
side, a desktop) they are beside it. In a page of its own it fills a
phone's screen, keeps out of the notch and the home bar (the Mobile Web
library's safe-area insets) and pauses when the page is hidden or the
phone turns. On a desktop's page the Stack Player shows a stack at its
own size, 900 by 640 for this one: the game takes the browser window's
size while that is the smaller, and a link that ends `&fill=yes` gives it
the whole window. A finger dragged anywhere moves the paddle and, lifted,
sends the ball off; a mouse moves the paddle to where it is, and the keys
play it too (the arrows or A and D, Space, P to pause, Esc to go back).
While a level is played the mouse's pointer is hidden over the arena,
where it points at nothing and is in the ball's way; it shows over the
score and the pause button beside the arena, on a pause and on every
other screen, and outside the window. (The engine has one cursor for
all of its windows, so the game gives it back whenever its frames stop,
and leaves alone one that another script holds locked.) In a browser the
same goes for a tablet's trackpad or mouse, an iPad's with its keyboard
say, since its page says that it has a pointer as well as a touch
screen. In an app on a phone or a tablet a mouse's pointer is the
system's own, which the engine does not hide, and the game leaves it as
it is.

**The Online Duel** is a match between two players, each on their own
wall: the same wall for both, three minutes on the clock, most points
wins. A lost ball costs 150 points, not a life, and a wall cleared is the
next one at once. The heat sends the rival trouble: at three times a
fast ball, at four a small paddle, at five a row of tough bricks pushed
in at the top of their wall. Each sees the other's arena, small, beside
their own.

The two are linked directly, over a WebRTC data channel made by
DataChannelXT (the xTalk Suite's; the web engine has it over the
browser's own RTCPeerConnection), so there is no game server and nothing
to sign in to. Before a link can be made each game has to tell the other
where it is, and there are two ways to.

**The lobby** is the one the duel opens on. A player gives a name (the
game makes one up to begin with, and keeps the one given between visits)
and goes online, and sees who else is there: a tap on a player challenges
them, and their ACCEPT begins the match. QUICK MATCH pairs the first two
players who ask for one. PLAY A FRIEND makes a room with a code of six
letters and a link to send, the page's own address ending in `?duel=` and
the code: a friend who opens the link, or types the code, is matched with
the room's maker and nobody else. A match over, both are back in the
lobby. The lobby has no server of the game's either. The players meet on
public Nostr relays (`wss://nos.lol`, `wss://relay.damus.io` and
`wss://nostr.mom`, which are xTalk Chat's; a stack's `cRelays` property
names others), through NostrXT and its relay library. Each game has a key
made for the visit, and sends two kinds of small signed message, both of
the ephemeral kinds, which a relay passes on and is not meant to keep
(some hold them a few minutes): one says "I am here" to the room, with
the name and what the player is doing, and the other carries a challenge
or a WebRTC session description to one player, sealed so that only that
player reads it (NIP-44). So the other players see the
name a player gave, and the relays see that and the internet address it
came from, as any web site does. The step before going online says so,
nothing is sent until the player goes online, and while a match is played
the game is off the relays. What comes from them is read as a stranger's:
a name is cut to sixteen plain characters, and a description is checked
as a code is.

**PLAY BY CODE**, on the lobby's first step, is the swap of two codes,
sent by any chat or mail, for a player who wants no lobby and wherever
there is none: the host's game makes an invite code and the host sends
it; the other player pastes it into their game, which makes an answer
code to send back; the host pastes that, and the match begins. A code is
a WebRTC session description, compressed and written in letters and
digits. The answer has to reach the host within about a minute of being
made (after that the answerer's side gives up, and the two start again),
which two people passing codes by hand often miss; the lobby carries the
same two descriptions in a second or two.

However the two met, each game asks a public STUN server
(`stun.l.google.com:19302`) what its address on the internet is, so that
the two find each other through home routers; nothing of a match goes
through that server, and two players behind strict company or mobile
networks may not be able to link at all, since no relay (TURN) server is
used. The duel plays wherever DataChannelXT is: in a browser (the Stack
Player, the web IDE, a web standalone that includes it) and in OXT-Beyond
on a desktop. The lobby is there wherever NostrXT is too, which is the
same places (a web standalone needs NostrXT with its relay library,
CoinXT and SodiumXT among its inclusions beside DataChannelXT); without
it the duel opens on the two codes, as it did before there was a lobby.
The Android engine has no DataChannelXT yet, so there the game says that
this build cannot make the link.

How it is made, for anyone making a game like it: one card and no
pictures. Every brick, ball, spark and bolt is a graphic from a fixed set
that the builder makes, shown, moved and coloured by one loop that moves
everything by the time since the last frame, in units of a 320 by 480
arena that the layout scales. The levels are `ember-bricks/levels.txt`,
ten letters to a row, which the builder puts in the stack as they are.
The sounds are made by `ember-bricks/make_assets.py` from sine, square
and triangle waves and noise (`--check` makes them again and compares),
and mixed by the browser's Web Audio. In a duel each game sends the other
a line of text ten times a second, its score, paddle, balls and bricks,
on a channel that does not resend what is lost (the next line makes the
last one old), and the few lines that must arrive (the start, trouble,
the last score, a rematch) on one that does. A line the game cannot read
is nothing to it.

The lobby is a pattern for any game of two, in the script's section "The
online lobby": a room is a tag (`t`) that everyone in it asks the relays
for; "I am here" is an event of an ephemeral kind, said again every
twenty seconds and forgotten after fifty; a word to one player is tagged
with that player's key (`p`) and sealed. A relay that holds such events
for a while gives them to whoever asks, so the game asks for none that
is kept (`limit` 0) and takes for news nothing made more than two
minutes ago, nor a player's older "I am here" after a newer one. And
every message carries its count as a tag: an event is known by its
words and the second it was made in, and a relay passes on only the
first of two it takes for the same. A relay that goes is asked again:
after fifteen seconds while another is open, after three when none is,
since a lobby with no relay open is given up after twelve; three times,
counted afresh once a relay has stayed a minute. (A phone that slept
lost its relays meanwhile: the time asleep is not counted as waiting.)
NostrXT's relay library tells the top stack what a relay says, or the
one object that asked for everything (`nxrInit`), which another stack's
chat may be. So the game asks for nothing: it names a callback of its
own to each relay it opens (`nxrSetCallback`) and hears it through a
hidden button whose script is at the back of the message path while the
game is online. It works whichever stack is on top, takes nothing from
xTalk Chat, and closes only the relays it opened.

Its font is Atkinson Hyperlegible, by the Braille Institute, under the
SIL Open Font License: the same two files as Puzzle Almanac's. Its sounds
and levels were made for it and are OXT-Beyond's own.
`ember-bricks/SOURCES.md` says where each file comes from.

The stack is never edited by hand. Its script is
`ember-bricks-stack.livecodescript` and its controls are made by
`ember-bricks.livecodescript`; change them, then build it again with any
OXT-Beyond engine:

```sh
<engine> -ui tools/web-player/ember-bricks.livecodescript
```

`tests/lcs/webplayer/ember-bricks.livecodescript` plays it on a desktop
engine with the clock in the test's hands: every screen and setting, the
ball off the walls and the paddle, each kind of brick, the heat, every
spark, lives and levels, what is kept between visits, the layout at
phone, tablet and desktop sizes, the lobby's steps, the codes, a whole
duel with nobody at its other end (what the game would send is read, and
the test says what the rival does), and the online lobby with no relay
(the test is the other players: it says what they send, and reads what
the game would send them). `tools/ci/tests/test_ember_bricks.py` holds
the stack to its files, the levels to their rules, the lobby to what is
said of it here and the checks to the game.
`tools/ci/ember_bricks_check.py` builds a standalone with the xTalk
Suite's modules and script libraries that the game uses, and plays it on
emulated phones (Pixel 7 and iPhone 13, in Chromium and WebKit) with real
touches. Then, in Chromium, it plays a duel between two pages over a real
WebRTC link made by the two codes: the invite and the answer by the
clipboard, clocks in step, each other's scores, the result, a rematch and
one player leaving. And then the lobby, between three pages (a desktop's
window and two phones) on a Nostr relay of its own on 127.0.0.1
(`tools/ci/nostr_test_relay.py`, told to keep what it passes on for five
minutes, as some public relays do): going online by a typed name, each
page's list of the others, a challenge accepted and played over a real
link, the third page seeing the two in a duel, the lobby again after the
match, the relay hanging up on all three and each back on it by itself,
a quick match, and a friend's room joined by the link that was copied.
No check goes to the public relays, which CI must neither lean on nor
write to. Last, in both browsers, a desktop's page plays a level with a
mouse: the pointer the page shows is hidden over the arena, shows over
the pause button and on a pause, and is hidden again when the level goes
on. Then a tablet's page with a trackpad plays it the same way: a page
with a touch screen that is made to say it has a pointer too, as an
iPad with its keyboard says, which no browser the check drives can be.
CI runs it in web.yml, after Puzzle Almanac's check. To run it
yourself:

```sh
python3 tools/ci/ember_bricks_check.py --runtime <web runtime> --engine-cache <folder> --shots <folder>
```

The stack's `cJavascriptHandlers` are `ebPageHidden` (the page is hidden:
a level pauses), `ebPasted` (the page hands the game the text its PASTE
button read off the clipboard) and `ebState` and `ebRectOf`, so that a
check can ask the game how it is.

## Beyond Beats

A beat studio for a browser, grown from Beat Box (which stays as it is,
the short example). Four views, one at a time:

- **Channels**, the rack: up to twelve channels, each a sound with its
  own volume, pan, mute and solo, and a row of pads for the pattern
  shown. A pattern has 16 or 32 steps, a step off or on at a velocity
  from 1 to 9 (a click puts one on, a drag paints a row, a shift-click or
  right-click makes it loud, soft or normal). A channel's name opens the
  sound picker; its colour chooses it for the piano roll.
- **Piano roll**: notes for the chosen channel in the pattern shown, two
  octaves at a time from C1 to B6. A click adds a note and a drag makes it
  longer; a drag moves one by steps and semitones, or its right end makes
  it longer or shorter; a click takes it away and a shift-click makes it
  louder or softer. A key plays its note.
- **Playlist**: eight tracks of 128 bars, 32 shown at a time. A click puts
  the chosen pattern in (a 32-step pattern takes two bars) or takes a
  block out, a drag paints or clears a track, a shift-click chooses a
  block's pattern, and a click on the ruler is where Song mode starts.
- **Mixer**: a strip a channel, with a filter, a reverb send, a delay
  send, pan, a fader with its meter, mute, solo and a tuning, and the
  master's volume and meter; the reverb is a room or a hall and the delay
  an eighth, a dotted eighth or a quarter, with its feedback.

Up to sixteen patterns are made, cloned, cleared, deleted and renamed in
the list beside the views. Pattern mode plays the pattern shown; Song mode
plays the playlist. The sounds are a kit of sixteen, five synths (a saw
lead, a square bass, a soft pad, a pluck and keys) and up to eight samples
of the user's own (a WAV, MP3 or OGG file of up to 4 MB, loaded from the
picker or the File menu). Undo and Redo (also Ctrl+Z and Ctrl+Shift+Z or
Ctrl+Y) go back over the last sixty changes, a drag being one; a sample
loaded over another is a change too, and Undo brings back the other's
sound with its name (each sample's file has a key of its own, and a file
no step can reach any more is deleted). The song is
kept in the browser's storage and is there on the next visit; the File
menu saves it as a file to download (its samples inside it) and opens one
again, exports the song or pattern as a WAV file, loads a sample, starts a
new song (pressed twice) or brings the demo back. Songs saved by the first
version still open.

The stack owns the song and the screen; the page owns the sound and the
clock. `beyond-beats/audio-core.js`, kept in the stack as the custom
property `cAudioCore` and run once with `do ... as "JavaScript"`, makes
`window.beyondBeats`: the kit, made sample by sample from oscillators and
seeded noise, and the synths, made of oscillators, a filter and envelopes
(no sound files, so nothing to license, and the same sounds in every
browser); for each channel a filter, a fader, a stereo panner, a meter and
sends to a reverb (a convolver with a made impulse) and a tempo-synced
delay; a master gain, a limiter and a soft clip; and a scheduler that
books each step on the audio clock a tenth of a second ahead, so a slow
frame of the engine never moves the beat. Stop fades out every voice it
booked in a few milliseconds, a long note still sounding as well as a
step booked ahead, and the reverb and delay ring on. Swing moves every second
sixteenth later by up to half a step. The stack tells the core the song
after every change (`beyondBeats.set`) and asks it about sixty times a
second which step is sounding and how loud each channel is, to move the
playhead and the meters. Export renders the song again offline
(`OfflineAudioContext`) through the same mixer and hands the browser a
WAV file. The core never calls back into the stack. Outside a browser the
stack opens and edits as well and its playhead runs, without sound.

The stack is never edited by hand. Its script is
`beyond-beats-stack.livecodescript` and its controls are made by
`beyond-beats.livecodescript`; change them or the core, then build it
again with any OXT-Beyond engine:

```sh
<engine> -ui tools/web-player/beyond-beats.livecodescript
```

`tests/lcs/webplayer/beyond-beats.livecodescript` drives the song, the
screen and the files on a desktop engine (and in the web engine, with
`tools/ci/web_tests.py`): the rack (pads and the points they are at,
velocity, a painted row, 16 and 32 steps, tempo and swing, the sliders,
mute and solo, channels and the sound picker), patterns, the views and
the layout, the playlist (blocks, drags, scrolling, Song mode and where
it starts), the piano roll (adding, stretching, moving and deleting
notes, velocity, the channel and octaves), the mixer and the master,
undo and redo (a sample loaded over another among them), New and Demo,
what the page is told, song files and samples, a file that is not a song,
and Play in both modes.
`tools/ci/beyond_beats_check.py` checks the rest in headless Chromium: the
audio core alone, its songs rendered offline and measured sample by sample
(the kit and the synths, each step on its sample, swing, volume, velocity,
pan, mute, solo, notes and tuning, the filter, the reverb and the delay,
the playlist, user samples, the limiter, the meters, the live clock, Stop
silencing a held note and a step booked ahead, and the WAV export), and
the stack in a Stack Player (Play starts the page's
core with the stack's song, a pad clicked is in it at once, the views and
the pattern list answer, Song mode plays the playlist, and Stop stops
it). `build_player.py --check` runs both;
`tools/ci/tests/test_beyond_beats.py` holds the stack to its files. To run
the browser check yourself, with a Stack Player you have built or
downloaded:

```sh
python3 tools/ci/beyond_beats_check.py --player <StackPlayer folder> --shots <folder>
```
