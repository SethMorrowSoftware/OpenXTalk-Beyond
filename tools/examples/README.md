# Remastered examples

The IDE's example stacks, remade in the look of Home and Learn: one
window, a sidebar of the stack's cards, a header with each card's title,
and each program on a stage with its scripts beside it, in colour. Each
remaster stands beside its original, which stays where it was
(`ide/Resources/Examples`, `ide/Resources/Start Center/samples`) as its
author made it. Learn's gallery opens the remaster, and lists the
originals under Classic.

| Remaster | Builder | Original, in `ide/Resources` | Made by |
| --- | --- | --- | --- |
| Quick Start Guide | [quick-start](quick-start.livecodescript) | `Examples/Quick Start.oxtstack` | Terry Little, 2024 |
| Animate a Letter | [animate-letter](animate-letter.livecodescript) | `Examples/Animate Letter.oxtstack` | Terry Little, 2022 |
| A Data Grid Tour | [data-grid-tour](data-grid-tour.livecodescript) | `Examples/Data Grid Tour.oxtstack` | LiveCode Ltd, debranded for OpenXTalk at LiveCode's request |
| A Tour of SQLite | [sqlite-tour](sqlite-tour.livecodescript) | `Examples/SQLite Tour.oxtstack` | LiveCode Ltd, debranded for OpenXTalk at LiveCode's request |
| Data Grid Tables | [data-grid-table](data-grid-table.livecodescript) | `Examples/DataGrid Table.oxtstack` | Terry Little, 2022 |
| SQLite Books | [sqlite-book-library](sqlite-book-library.livecodescript) | `Examples/SQLite Book Library.oxtstack` | Not recorded |
| RSS Reader | [rss-reader](rss-reader.livecodescript) | `Examples/RSS Demo.oxtstack` | Not recorded; its Import button's script says "via theotherbassist, April 2016" |
| Scroll an Image | [scroll-image](scroll-image.livecodescript) | `Examples/Scroll Image.oxtstack` | Not recorded (2013, its standalone settings say) |
| Play a Video | [video-player](video-player.livecodescript) | `Examples/Video Player.oxtstack` | Not recorded (it came in OpenXTalk Lite 1.15) |
| Zip Archives | [zip-archives](zip-archives.livecodescript) | `Examples/Zip Build Demo.oxtstack` and `Examples/Zip Extract Demo.oxtstack`, as one | Not recorded (2006, their standalone settings say) |
| Bouncing Balls | [bouncing-balls](bouncing-balls.livecodescript) | `Start Center/samples/sample_1/Balls.livecode` | LiveCode Ltd (then RunRev Ltd), 2011 |
| Bookshelf | [book-library](book-library.livecodescript) | `Start Center/samples/sample_2/BookLibrary.livecode` | LiveCode Ltd, 2014 |
| Balloon Game | [balloon-game](balloon-game.livecodescript) | `Start Center/samples/sample_4/balloon.livecode` | LiveCode Ltd (then RunRev Ltd), 2013 |

A remaster is a binary stack, `ide/Resources/Examples/Remastered/<name>.oxtstack`,
and it is never edited by hand: a script here builds it, and the stack is
built again when the script changes. The scripts are the source; the
stacks are committed beside them, built, so that the IDE needs nothing
to open them.

| File | What it is |
| --- | --- |
| [build-examples.livecodescript](build-examples.livecodescript) | Builds the examples: run it with an installed OXT-Beyond |
| [builder.livecodescript](builder.livecodescript) | The handlers every example's builder uses (`ex...`) |
| [frame-runtime.livecodescript](frame-runtime.livecodescript) | The script of the window in every remaster: the sidebar, the stage and the scripts panel |
| `<example>.livecodescript` | An example's builder: its cards, its programs, and its scripts |

The builders also use the drawing handlers of Learn's kit
([revlearnkit.livecodescript](../../ide/Toolset/palettes/learn/revlearnkit.livecodescript)):
`lkColor`, `lkBox`, `lkLabel`, `lkIcon` and the rest. What they draw is
saved in the stack as graphics, fields and images, so a remaster does not
need the kit to open.

## xTalk Suite demos

Learn also lists three whole apps of the
[xTalk Suite](https://github.com/SethMorrowSoftware/xtalk-suite), under
"xTalk Suite demos", which run on the suite's extensions that OXT-Beyond
ships built in. They are not remasters and have no builder here: each is
a binary stack in `ide/Resources/Examples/xTalk Suite/` whose stack
script is the suite's file, unchanged. Each is saved with its window
already built, so it opens ready to use, and its card script puts the
window in the middle of the screen each time it opens.

| Stack | The suite's file (stack script) | Needs |
| --- | --- | --- |
| No Cloud Quick Share | `nocloud/src/nocloudquickshare.livecodescript` | TorrentXT; SodiumXT for passphrases and the Tor path, and a Tor daemon for that path |
| Torrent Client | `torrentxt/examples/torrent-client.livecodescript` | TorrentXT |
| Box2D Platformer | `box2dxt/examples/box2dxt-platformer.livecodescript` | Box2Dxt |

No Cloud Quick Share and Torrent Client were made from the suite's
commit `34221ae` (the extensions' pins in
[`tools/oxt/xtalk-extensions.json`](../oxt/xtalk-extensions.json) are the
same files) with an OXT-Beyond engine: a new stack named after the app,
its script set to the file, saved in the 7.0 stack format. Box2D
Platformer is the stack Seth Morrow saved on 2026-10-14 after its first
run had imported the suite's `box2dxt/Spritesheets` and its sounds into
it, so that it opens without that folder, renamed from "Untitled 1";
every line of its script but the Box2Dxt Kit's doc comments is the
suite's file at `34221ae`.

No Cloud Quick Share and Torrent Client build their windows from their
scripts, and do it again only when the script's version tag differs
from the one the stack was stamped with.
[`prebuild-suite-demos.livecodescript`](prebuild-suite-demos.livecodescript)
runs each one's build once with messages locked and saves it, and sets
the card script of all three: run it in the IDE, on a machine with a
display, as its header says. Torrent Client's card script also applies
the height, download folder and upload cap that Torrent Client
remembers between runs, which its build applies only when it builds; the
build's own download folder is cleared before the save. Box2D Platformer
was saved built already, and only gets the card script.

To take a newer version, make the first two the same way and run
`prebuild-suite-demos.livecodescript`; for the platformer run the new
file once with the `Spritesheets` folder, let it import, save it, and
then run `prebuild-suite-demos.livecodescript` for its card script.

## Building

```sh
<install>/OXT-Beyond -ui tools/examples/build-examples.livecodescript
```

`<install>` is an installed OXT-Beyond (the folder with its engine, its
`Externals` and its `Extensions`). It builds every example in the
script's `kExamples` into `ide/Resources/Examples/Remastered`, and writes
a line for each step, ending with `DONE` or `FAILED <why>`. Before it
saves a stack, it compiles every script in it as the IDE's strict
compilation mode does, and a script that does not compile stops the
build. A line `WARN` names a word that the scripts panel cannot wrap:
the panel breaks a line only at a space, so a word longer than its line
(47 letters, less the line's indent) runs out of sight. A line
`WARN web` names a field or a button whose words fit in Helvetica but not
in Droid Sans, with the room they need and the room they have: a browser
has no other font, and the web IDE draws every font of a stack in it. The
build can measure Droid Sans only where it is installed (on Linux, in
`~/.fonts`); where it is not, a line `NOTE` says so, and no word is
checked for the web.

| Variable | What it does |
| --- | --- |
| `OXT_EXAMPLES` | The examples to build, by their builders' names, comma separated (`animate-letter`) |
| `OXT_EXAMPLES_OUT` | The folder the stacks go into |
| `OXT_INSTALL` | The install to load revXML and the drawing library from, when the engine run is not in one |
| `OXT_EXAMPLES_DEBUG` | Set, a failure writes the engine's whole error |

## The window

Every remaster is one window, 1024 by 640, which a 720p screen holds with
its title bar. The sidebar (232 wide) has the example's mark, the list of
its cards, and Back and Next; the header has the card's title and tagline;
below it is the card's content, from 256,104 to 1000,616. The arrow keys go
from card to card, and the sidebar stays still while the content slides.

Each card is one of four kinds, the last item of its line in the cards'
table (see `exNewStack`):

| Kind | What the card has |
| --- | --- |
| `front` | A front page: what the example is and who made it, and a tile for each card. A star in the list, not a number |
| `page` | A page of words or pictures, numbered, without a stage |
| `program` | The stage, 256,104 to 600,616, and beside it the panel of the scripts of the things on the card |
| `wide` | The stage across the content, 256,104 to 1000,616, and the scripts in a drawer over its right side, which the header's Scripts button opens and Escape shuts |

`keys` after the kind (`program keys`, `wide keys`) says that the card's
arrow keys play its program, so they do not go to the next card, and the
sidebar says so.

The stage is the graphic `Stage`, in the background group `Workbench`, and
the panel is the background group `Scripts`. A program names the stage to
find its room: `the loc of graphic "Stage"`, `the width of graphic
"Stage"`. The window's own controls have names that begin with `frame`, `code` or
`stage`, so that a program's controls can keep the names their author
gave them (a field `Title`, a button `Next`).

The panel shows the scripts of the card and of the controls on it, a chip
each, and the script of whatever is clicked (a click on a part of a
group, such as a button's label, shows the group's). The window gets the card's
messages after the card, so a card's own `preOpenCard` handler must
`pass preOpenCard`, or the window does not lay that card out; a control's
`mouseDown` handler that passes `mouseDown` lets the panel follow the
click.

A card opens with the keys on the graphic `frameFocus`, in the background
group `Focus`, off the card. Left to itself, the engine gives them to the
card's first field that takes typing, and the IDE counts a field opened for
typing as a change to the stack: a card with a box to type in would ask to
be saved when the window closed, with nothing typed. A click in the box, or
Tab, still opens it for typing. Neither has a script, so a key goes on to
the card and then to the window, as it does when nothing has the focus.

## Making a remaster

A builder is a script-only stack here, `<example>.livecodescript`, named
`OXTExample<Name>`, with a command `exBuild pFolder` that builds the stack,
saves it in pFolder and returns its path. Its own script holds the scripts
that go into the stack, each in a block that begins with a line
`/*@ <key>` and ends with a line `@*/`, so that they read as they will in
the stack; `exScript(<key>)` gives a block's text.
[animate-letter.livecodescript](animate-letter.livecodescript) is the one
to read first.

```
command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   put "Animate a Letter" into tInfo["name"]
   put "after Terry Little, 2022" into tInfo["credit"]
   ...
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   -- each card's controls, made on it: go card "...", then lkBox, exButton, ...
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Animate a Letter.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild
```

| Handler | What it makes |
| --- | --- |
| `exNewStack(pInfo)` | The stack and its first card, with the sidebar and the header (`pInfo`: name, credit, icon, accent, accent2, cards, noun, nouns, script) |
| `exAddCards` | The other cards, the stage and the panel on the program and wide cards, and each card's title, tagline and place in the list |
| `exHero pRect, pColors, pEyebrow, pTitle, pText` | A front page's banner |
| `exProgramTiles pTop, pColumns, pHeight, pGap` | A tile for each numbered card, which goes to it |
| `exButton(...)` | A rounded button with an icon, in the styles `primary`, `ghost`, `light` and `dark` |
| `exPanel(pName, pRect, pGroup)` | A white panel with a soft shadow |
| `exLetter(...)` | Animate a Letter's letter tiles |
| `exAddIcon pName, pPaths` | An icon the kit does not have, from Lucide's drawing of it |
| `exIcon(...)` | An icon, from those added or the kit's |
| `exCardInfo(pIndex, pWhat)`, `exCardNumber(pIndex)` | A card's line of the table, and its number in the list |
| `exCheck(pStack)`, `exSave pStack, pPath` | The strict compile of every script, and the save |

What a remaster keeps:

- **Its author's work and name.** The programs are the original's, with
  their comments, changed only where the window needs it (a place on the
  card is now a place on the stage) or where strict compilation needs it
  (a `local`, a quoted literal), with a comment saying so. The original's
  credits and dated comments go into the remaster's stack script as they
  were. The sidebar says who made it ("after Terry Little, 2022"), and so
  does the front page's banner.
- **Its pictures and sounds**, copied from the original stack when the
  stack is built, so that nothing is copied by hand.
- **A script that compiles in strict mode**, with every variable declared,
  and plain ASCII in every script and builder (a letter beyond ASCII is
  made with `numToCodepoint`).

Every word is sized as the build draws it, in Helvetica at 12, and
`exNewStack` gives the stack that font, so that it is drawn so wherever
it opens: Windows draws Helvetica as Arial, and Linux as Nimbus Sans or
Liberation Sans, all with Helvetica's widths. (Left empty, the stack's
font would be its platform's own, the IDE's Sans at 13 on Linux, and
words sized here would not fit.) A control of the example's own can have
another font, sized when the stack is built.
