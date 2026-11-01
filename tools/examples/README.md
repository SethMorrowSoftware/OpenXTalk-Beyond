# Remastered examples

The IDE's example stacks, remade in the look of Home: one window, a
sidebar of the stack's cards, a header with each card's title, and each
program on a stage with its scripts beside it, in colour. Home's
Examples place opens the remasters, and only they are installed.

The originals, as their authors made them, are kept here in
[`originals/`](originals/), because the builders read their pictures,
data and text from them. They were installed (in `ide/Resources/Examples`
and `ide/Resources/Start Center/samples`) and listed under Classic until
0.2.7-rc.6.12, when Home took the place of the Start Center, the Welcome
window and OpenXTalk Lite's demos, and the classic copies left the
package.

| Remaster | Builder | Original, in `originals/` | Made by |
| --- | --- | --- | --- |
| Quick Start Guide | [quick-start](quick-start.livecodescript) | `Quick Start.oxtstack` | Terry Little, 2024 |
| Animate a Letter | [animate-letter](animate-letter.livecodescript) | `Animate Letter.oxtstack` | Terry Little, 2022 |
| A Data Grid Tour | [data-grid-tour](data-grid-tour.livecodescript) | `Data Grid Tour.oxtstack` | LiveCode Ltd, debranded for OpenXTalk at LiveCode's request |
| A Tour of SQLite | [sqlite-tour](sqlite-tour.livecodescript) | `SQLite Tour.oxtstack` | LiveCode Ltd, debranded for OpenXTalk at LiveCode's request |
| Data Grid Tables | [data-grid-table](data-grid-table.livecodescript) | `DataGrid Table.oxtstack` | Terry Little, 2022 |
| SQLite Books | [sqlite-book-library](sqlite-book-library.livecodescript) | `SQLite Book Library.oxtstack` | Not recorded |
| RSS Reader | [rss-reader](rss-reader.livecodescript) | `RSS Demo.oxtstack` | Not recorded; its Import button's script says "via theotherbassist, April 2016" |
| Scroll an Image | [scroll-image](scroll-image.livecodescript) | `Scroll Image.oxtstack` | Not recorded (2013, its standalone settings say) |
| Play a Video | [video-player](video-player.livecodescript) | `Video Player.oxtstack` | Not recorded (it came in OpenXTalk Lite 1.15) |
| Zip Archives | [zip-archives](zip-archives.livecodescript) | `Zip Build Demo.oxtstack` and `Zip Extract Demo.oxtstack`, as one | Not recorded (2006, their standalone settings say) |
| Bouncing Balls | [bouncing-balls](bouncing-balls.livecodescript) | `sample_1/Balls.livecode` | LiveCode Ltd (then RunRev Ltd), 2011 |
| Bookshelf | [book-library](book-library.livecodescript) | `sample_2/BookLibrary.livecode` | LiveCode Ltd, 2014 |
| Balloon Game | [balloon-game](balloon-game.livecodescript) | `sample_4/balloon.livecode` | LiveCode Ltd (then RunRev Ltd), 2013 |

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

Learn once listed four apps of the
[xTalk Suite](https://github.com/SethMorrowSoftware/xtalk-suite) (No Cloud
Quick Share, Torrent Client, Box2D Platformer and Texas Hold'em), saved
as binary stacks in `ide/Resources/Examples/xTalk Suite/`. Home leaves
them out: each is a whole app that lives in the suite, where it is made
and released, and the extensions they run on are still built in. The
last copies, and `prebuild-suite-demos.livecodescript` that saved them,
are in the history of the 0.2.7-rc.6.11 tag.

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
| `OXT_EXAMPLES_KEEP_LIGHT` | Set, the light stack is the one already in the output folder, as it was built before: only the dark colours and the window's script are added to it, so its light look stays as it was to the pixel |

### Light and dark

A remaster follows the desktop between light and dark, as Learn does
(openxtalk.org p=25438). Each example is built twice, with the kit's
colours light and then dark (`lkSetDark`), in the same order, so the two
builds have the same objects with the same ids. Where an object's colours
differ, the light stack keeps both, in the custom property sets `uLight`
and `uDark` (`build-examples.livecodescript` says what is in them), and
the window's script puts the one the desktop wants on every object when a
card opens (`frameLook`): dark when the IDE's `revIDEAppearanceIsDark()`
says so, light otherwise, and light where there is no IDE (a standalone, a
browser). In the dark build, `lkDarkLiteral` and `lkMix` turn the light
page's colours written as numbers (a white panel, a slate ink, white
tinted with the accent) into the dark page's. The sidebar and the scripts
panel are dark in both. The stage and what a program puts on it are left
as they are, light: the programs were written for a white stage.

## The window

Every remaster is one window, 1024 by 640, which a 720p screen holds with
its title bar. The sidebar (232 wide) has the example's mark, the list of
its cards, and Back and Next; the header has the card's title and tagline;
below it is the card's content, from 256,104 to 1000,616. Next goes to the
next card, and Back to the card you came from, however you came (Back and
Next, the list, the front page, a key, or a program going on by itself),
or to the card before when there is none: so a card chosen in the list or
on the front page, then Back, is where you were. The arrow keys go to the
card before and the card after, and the sidebar stays still while the
content slides.

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
