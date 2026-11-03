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
| Learn Box2D | [learn-box2d](learn-box2d.livecodescript) | None: made here, in the same look | OXT-Beyond, 2026 |
| Learn SodiumXT | [learn-sodiumxt](learn-sodiumxt.livecodescript) | None: made here, a Learn stack (below) | OXT-Beyond, 2026 |
| Learn CoinXT | [learn-coinxt](learn-coinxt.livecodescript) | None: made here, a Learn stack (below) | OXT-Beyond, 2026 |
| Learn NostrXT | [learn-nostrxt](learn-nostrxt.livecodescript) | None: made here, a Learn stack (below) | OXT-Beyond, 2026 |

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
| [learn-runtime.livecodescript](learn-runtime.livecodescript) | The script of the group "Learn" in every Learn stack: its lessons' Run, Copy and Reset, the call pages and the Reference |
| `<example>.livecodescript` | An example's builder: its cards, its programs, and its scripts |

The builders also use the drawing handlers of Learn's kit
([revlearnkit.livecodescript](../../ide/Toolset/palettes/learn/revlearnkit.livecodescript)):
`lkColor`, `lkBox`, `lkLabel`, `lkIcon` and the rest. What they draw is
saved in the stack as graphics, fields and images, so a remaster does not
need the kit to open.

## Learn Box2D

Learn Box2D is the one example here with no original: it was made in
the remasters' look to teach Box2D, the physics engine built in as
Box2Dxt. Each of its thirteen lessons (the world, body types, shapes,
materials, forces, hinges, springs, sliders, wheels, dragging, contacts,
ray casts and terrain) is a `wide` card with:

- a live world in a court, drawn by the `Lab` background group's script
  (`/*@ Lab` in the builder), which steps the world on a timer, draws
  every body and joint, lets a body be thrown with the mouse, and gives
  each card Reset, Pause and Step;
- a row of buttons, each running a handler of the card's own script
  (the builder's `buttons` block names them, and the build stops if one
  is missing);
- "How it works", and the list of every Box2D call the card's script
  makes, read from the script when the stack is built: a click on one
  says what it does (the builder's `docs` block, which must have a line
  for every call).

The card's script is the lesson, and the Scripts drawer shows it. Its
`labBuild` makes the world and `labStep` runs after each step; the Lab's
handlers (`labShow`, `labWalls`, `labMX`, ...) are the drawing and the
unit changes, so the card's script is all Box2D.

```sh
xvfb-run -a <install>/OXT-Beyond -ui tools/examples/test-learn-box2d.livecodescript
```

runs every lesson of the built stack with Box2Dxt loaded from the
install: each card runs for three seconds, each of its buttons is
pressed, and the line at the court's top must not report an error; every
body must be in the court; and a button on nine of the cards must do
what its lesson says (gravity changes, a ball bounces, the motor speeds
up, the car drives, contacts are counted, ...). First, the front page's
banner must be running its toy: a little world of its own (the front
card's script) that rains shapes onto a spinning paddle, and blasts them
with b2WorldExplode where the banner is clicked. It ends with `DONE` or `FAILED`.
`OXT_LEARN_BOX2D` names another copy of the stack, and
`OXT_LEARN_BOX2D_SNAPS` a folder for a picture of each card.

A script calling handlers is not a click, so

```sh
python3 tools/examples/learn-box2d-clicks.py --install <install> [--shots <folder>] [--only Rays]
```

clicks the stack with a real mouse, the way a user does: the install's
standalone engine opens it in a window on an Xvfb screen of its own,
with `learn-box2d-clicks.livecodescript` writing what the window shows
to a file ten times a second, and xdotool (which it needs, with Xvfb)
clicks. It clicks the toy, checks every tile opens its lesson, and on
each lesson: the sidebar entry, every button, every call in the list
(each must explain itself, scrolled to with the wheel where the list is
longer than the panel), Pause (nothing moves), Step (it stays paused),
Pause again, Reset, a body dragged with the mouse, the Scripts drawer,
and a click on an empty court on Rays and Terrain; then the arrow keys,
the car's on Wheels, and Back and Next. No click may raise a script
error. It ends with `DONE` or `FAILED n`, and CI runs it after the test
above.

Where Box2Dxt is not loaded (the web IDE, for now), each lesson says so
at the top of its court, and the rest of the stack still opens and reads.

## Learn stacks: the xTalk Suite's extensions

A Learn stack teaches one of the extensions of the
[xTalk Suite](https://github.com/SethMorrowSoftware/xtalk-suite) that
OXT-Beyond has built in, one idea a card, for a reader new to it. Home
lists them under "The xTalk Suite": Learn SodiumXT, Learn CoinXT and
Learn NostrXT so far; Learn Box2D, above, has a look of its own. Each is built by its builder
(`learn-<extension>.livecodescript`) with the `exLearn...` handlers of
[builder.livecodescript](builder.livecodescript), and has:

- a front page: a banner, a tile for each lesson, three tips, and a
  panel that says whether the extension is loaded;
- a lesson on each card: "In plain words" (the builder's
  `/*@ <card>/words` block), the calls its script makes (a click on one
  opens that call's page over the script), and the script itself
  (`/*@ <card>/try`), which the reader can change, Run, Copy and Reset.
  Run gives the script to a hidden button and clicks it; the script
  writes its answer into the field "Result", and an error says what and
  at which line;
- a Reference card: every public handler of the extension, searchable,
  each with its syntax, summary, parameters, what it returns, an example,
  and the lessons that use it. The pages are made from the dictionary's
  own data (`Documentation/html_viewer/resources/data/api_extensions/`
  of the install that builds the stack), stored compressed in the stack.

The build stops if a lesson's words or calls do not fit their panel, if
a line of a script is wider than the code panel, if a script is taller
than it (24 lines), or if a call has no page. Lessons are plain text and a few links, so a stack stays small
(Learn SodiumXT is about 150 KB, 47 KB compressed).

```sh
xvfb-run -a <install>/OXT-Beyond -ui tools/examples/test-learn-stacks.livecodescript
```

loads each Learn stack's extensions from the install (its `cLoad` says
which) and checks, on a real engine: the front page says the extension
is loaded; on every lesson the script shown is the lesson's, every line
of it and of its result fits its panel and all of the script fits
without scrolling, Run (twice) gives a result
matching the lesson's `/*@ <card>/expect` pattern, and every call opens
its own page; Copy, an edit then Reset, a script that does not compile
and one that stops each say the right thing; the Reference lists every
handler, every link in every page goes somewhere, and a search finds and
clears; and, in the light look and then the dark, every colour of every
word in a lesson, a page and the Reference is 4.5 to 1 or more from the
colour under it (the WCAG's ratio for text). The builder chooses those
colours to pass (`exLearnReadable` darkens or lightens an extension's
accent as far as it must), and the test holds it to that. `OXT_LEARN_STACKS` names other copies of the stacks;
`OXT_LEARN_NOLOAD=1` loads nothing and checks that the stack says the
extension is not loaded, as it does where it is not installed (the web
IDE, for now); `OXT_LEARN_SNAPS` is a folder for pictures.

```sh
python3 tools/examples/learn-clicks.py --install <install> [--stack <file>] [--shots <folder>]
```

clicks every Learn stack with a real mouse, as `learn-box2d-clicks.py`
does Learn Box2D (`learn-clicks.livecodescript` reports what the window
shows): a tile, every lesson from the sidebar, Run and its result, every
call and Back to the script, Copy, typing into a script and Reset, a line
of the Reference, the wheel, a search typed and cleared, and Back and
Next. No click may raise a script error. CI runs both.

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
