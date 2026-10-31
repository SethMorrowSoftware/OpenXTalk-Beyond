# HyperCard corpus sweep

These tools import a whole collection of HyperCard stacks the way
File > Import Stack does, and count what still goes wrong. A change to the
HyperCard importer or to its script rewrites
(`ide/Toolset/libraries/revhypercard*.livecodescript`) states its effect
as the difference between two sweeps. For example, rule T34 compiled N
more handlers and left out none that compiled before.

The sweep needs no display. Each stack runs in its own engine, started
with `-ui`, so a stack that hangs or crashes affects only itself.

## 1. Get the stacks out of a disk image

```sh
pip install machfs
python3 extract.py HyperCard-Stacks.img stacks/
```

This writes every stack as `stacks/NNNNN.bin` (MacBinary, so both forks
come along) and lists them in `stacks/index.tsv` with their paths on the
disk. It reads an HFS volume, or a CD image with an Apple partition map.
A folder of MacBinary stacks from anywhere else works the same way.

## 2. Sweep

```sh
python3 sweep.py --engine /path/to/LiveCode-Community --stacks stacks/ --out runs/fix-main
```

The engine path depends on the platform:

- **Linux:** the `LiveCode-Community` binary.
- **Windows:** the IDE's `.exe`.
- **Mac:** the binary inside the app, `Contents/MacOS/...`.

There are two modes:

- **`--mode fix`** (the default) imports each stack, runs
  `revHyperCardFixScripts` and logs the handlers it still had to leave
  out, with the compile error of each. It takes a few seconds a stack.
- **`--mode run`** goes on to open the stack, visit its first 40 cards and
  click up to 20 buttons on each of the first 20 cards. It logs every
  error while running with the script line that raised it. Allow
  25 seconds a stack. The stack opens with its own `openStack`,
  `openBackground` and `openCard`, where many stacks set themselves up
  and call their externals first. (The import opens a stack with
  messages locked, so before the sweep closed it and opened it again,
  those handlers never ran, and runs from before then are not
  comparable with runs after.)

  Each visit and each click is a message of its own, as a person does
  one thing at a time. The engine starts each one afresh, as it starts
  each of a person's clicks: no screen or messages left locked by the
  click before, and no dynamic path left from it (after a `go`, the
  rest of that handler's messages go on to the card it went to as well
  as through its own stack). The stack's own `idle` and timer messages
  run in between. Runs from before then made every visit and click in
  one handler, so they are not comparable with runs after: there, a
  button's `go home` that opened another stack once left the stack's
  own handlers unanswered for the rest of the tour, as the engine then
  sent the messages of a handler that had gone to another stack to that
  stack in place of its own (pull request 252 changed that).

  A button that is hidden or disabled when its turn comes is not
  clicked: a person cannot click a button they cannot see, and
  HyperCard sends a disabled button no mouse messages. The log has a
  `SKIP` line for it. Runs from before then clicked those buttons too,
  and their scripts, which never run in HyperCard, raised errors and
  waited where a stack works (a hidden "coverhide" button showing a field
  that is not there), so they are not comparable with runs after.

The IDE keeps its stack revIcons in memory, and its substacks hold
HyperCard's brushes and patterns, so a stack's `set the pattern to 12`
or `reset paint` finds them there. The sweep loads that stack too
(`--icons`, by default this checkout's
`ide/Toolset/palettes/revicons.rev`). Runs from before then
counted every such line as an error ("brushPattern: can't find image",
"brush: can't find image") that the IDE does not raise, so they are not
comparable with runs after. With the pattern found, such a stack goes on
to paint with `drag`, which a run without a display cannot do, so some of
them now time out there instead (5 of the 26 stacks of the disk image
that had those errors).

Without a display, `click at`, paint tools and anything that waits for a
person are not representative. Count them, but don't fix them because a
headless run reported them. A modal window, which would wait for a person
until the stack timed out, is closed a quarter of a second after it opens,
as its Cancel button would close it, and counted in the report.

`answer` and `ask` are answered as a person most often answers them, with
the default button: an `answer`'s last button (OK if it has none), as in
HyperCard, and an `ask`'s OK with the reply it offers. The log has a
`DIALOG` line for each. The engine shows them with the stacks "Answer
Dialog" and "Ask Dialog", which the IDE has; the sweep makes its own.
Runs from before then had none, and there `it` was the engine's request
to the dialog (its kind, title, prompt and buttons in one) rather than a
reply, so a script that asked until it was told 1, 2 or 3 asked until the
stack timed out, and one that asked for a year did sums with that text.
They are not comparable with runs after.

A script's `exit to top` ends every handler that is running, the sweep's
own too, so before the sweep went on after one, the tour stopped at the
first click or card visit whose script ended with it, and the stack timed
out. Now the sweep notices such a step within a quarter of a second, logs
it (`ABORT`) and goes on with the next step, as a person goes on after a
click that stopped. It also logs each step as it starts (`AT`), so that
the report says where the stacks that timed out were: opening, going to
a card or clicking a button. Runs from before then are not comparable
with runs after: 56 of the 165 stacks of the disk image that timed out
with no error at all have an `exit to top` in their scripts.

`--hypertalk-order` sets each stack's `hyperTalkCompatible` before its
scripts are fixed, as File > Import Stack does unless File > Import
Stack > HyperCard Message Order is turned off, so the stack runs with
HyperCard's rules: its message order and dynamic path, its arithmetic,
its text properties and styles, its `round` and its seconds. Use it for
every sweep with an engine that has the property (0.2.7-rc.6.3 and
later), since that is how the stacks are imported, and compare a run
with it only with another run with it.

`--image` names the disk image that `extract.py` read the stacks from.
A stack then finds the other stacks of its application on that image, as
one that File > Import Stack imported from the image does: a `go` or a
`start using` that names a stack opens the one in the same folder on the
image, or else the first one of that name anywhere on it. Without
`--image`, no such stack is found, because the stacks folder names its
files by number. Compare a run with `--image` only with another run with
it.

`--lib` loads the HyperCard libraries from another folder, such as a
released build's `Toolset/libraries`. That lets you compare the released
rules with a branch's rules on the same engine:

```sh
python3 sweep.py --engine ENGINE --stacks stacks/ --out runs/fix-released --lib /path/to/released/Toolset/libraries
python3 sweep.py --engine ENGINE --stacks stacks/ --out runs/fix-branch
```

A stopped sweep picks up where it left off: a stack whose log is
complete is skipped. `--jobs` sets how many engines run at once (the
default is one per CPU).

## 3. Report

```sh
python3 report.py runs/fix-branch                          # one run
python3 report.py runs/fix-released --compare runs/fix-branch
```

A single report lists:

- the handlers left out, grouped by parse error, with a few lines of
  HyperTalk for each;
- the lines left out of handlers that were kept (rule T39), grouped the
  same way;
- for a `run` sweep, the errors while running and the handlers no object
  had (the XCMDs and XFCNs that scripts actually reach).

`--compare` goes stack by stack and handler by handler. A handler that is
no longer left out either compiles whole ("newly compiling") or was kept
with lines left out of it ("newly kept with lines left out"). A rule that
only adds forms must show **newly left out: 0**. Any handler it does list
is a regression to fix before merging. A doMenu handler counts as one
handler in both runs, whether the import kept its name (HyperCard's
message order) or named it hcDoMenu.

For two `run` sweeps, `--compare` also counts the errors while running in
each, the stacks with no error at all, and the kinds of error that came
more or less often in the second. A handler that compiles now runs, so it
can reach an XCMD or XFCN the stack does not have: count those, but
they are not regressions.

How long a stack takes depends on how busy the machine is, so a stack
that comes close to the time limit can time out in one run and not in
another, and its errors with it. Compare runs made with the same
`--jobs` on the same machine, and read a change of a few timed-out
stacks, and of their errors, as possibly that.

## The logs

`runs/<name>/NNNNN.txt` has one tab-separated line per event. The
following lines are written:

| Line | Fields |
|---|---|
| `IMPORTED` | name, cards |
| `NOIMPORT` | error |
| `FIX` | the import report's summary |
| `LEFT` | handler, compile error, its rewritten text |
| `LINE` | handler, line in it, `skipped` or `stops`, compile error, the line's HyperTalk |
| `AT` | phase: a step of the run as it starts (`open`, `card N`, `click N,M`) |
| `OPENED` | none |
| `ERR` or `THROW` | phase, error, the script line that failed (in a repeat or an if, the line inside it) and its object |
| `ABORT` | phase: a step a script ended with `exit to top`, after which the tour went on |
| `MODAL` | phase, the name of a modal window the sweep closed |
| `SKIP` | phase: a click left out, the button hidden or disabled |
| `DIALOG` | phase, the dialog's kind (`answer plain`, `ask password`, ...), the reply the sweep gave (base64) |
| `DONE` | none |
| `EXIT` | the engine's exit code, or `timeout` |

Text that can contain returns is base64. The `LEFT` lines come from
`revHyperCardLeftOutHandlers()` in the script library, and the `LINE`
lines from `revHyperCardLeftOutLines()`: the lines rule T39 left out of a
handler that it kept (a library from before T39 writes none).
