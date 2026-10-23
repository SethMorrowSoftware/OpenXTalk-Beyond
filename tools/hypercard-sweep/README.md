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
  25 seconds a stack.

Without a display, `click at`, paint tools and anything that waits for a
person are not representative. Count them, but don't fix them because a
headless run reported them.

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
- for a `run` sweep, the errors while running and the handlers no object
  had (the XCMDs and XFCNs that scripts actually reach).

`--compare` goes stack by stack and handler by handler. A rule that only
adds forms must show **newly left out: 0**. Any handler it does list is a
regression to fix before merging.

## The logs

`runs/<name>/NNNNN.txt` has one tab-separated line per event. The
following lines are written:

| Line | Fields |
|---|---|
| `IMPORTED` | name, cards |
| `NOIMPORT` | error |
| `FIX` | the import report's summary |
| `LEFT` | handler, compile error, its rewritten text |
| `OPENED` | none |
| `ERR` or `THROW` | phase, error, the script line and its object |
| `DONE` | none |
| `EXIT` | the engine's exit code, or `timeout` |

Text that can contain returns is base64. The `LEFT` lines come from
`revHyperCardLeftOutHandlers()` in the script library.
