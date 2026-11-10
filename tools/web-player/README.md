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
