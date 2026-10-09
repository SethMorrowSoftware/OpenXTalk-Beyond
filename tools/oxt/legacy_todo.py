#!/usr/bin/env python3
"""Write LEGACY-TODO.md: the FIXME, TODO and HACK notes in the inherited code.

Lists every line that `git grep` finds with one of the markers as a whole
word (in any case), by marker and by the top-level folder it is in, each
linked to its line. Run it from anywhere in the repository after a change
that adds, removes or moves notes:

    python3 tools/oxt/legacy_todo.py            # rewrite LEGACY-TODO.md
    python3 tools/oxt/legacy_todo.py --check    # fail if it is out of date
"""

import argparse
import collections
import os
import re
import subprocess
import sys

MARKERS = [
    ("FIXME", "Code its authors knew to be wrong or incomplete."),
    ("HACK", "Workarounds their authors were not happy with."),
    ("TODO", "Work left for later."),
]

# The same exclusions as the search shown in the file's introduction.
PATHSPEC = [
    ".", ":!thirdparty", ":!prebuilt/fetched", ":!gyp", ":!docs",
    ":!tools/ci", ":!tools/oxt", ":!*.md", ":!*.txt", ":!*.json", ":!*.map", ":!*.strings",
]

INTRO = """\
# FIXME, TODO and HACK notes in the legacy code

Every FIXME, TODO and HACK comment in the code OXT-Beyond inherited: LiveCode Community's engine, libraries, toolchain, externals, extensions and IDE scripts, and Tom Perry's OpenXTalk Lite changes to them. It is a map of known loose ends, kept as a starting point for work; most notes were written by LiveCode's developers years ago, and some may no longer be true. When a fix removes or rewords a note, this list is made again in the same pull request.

Not covered: the third-party libraries in `thirdparty/` (each has its own upstream), the bundled copy of GYP in `gyp/`, the dictionary and guides in `docs/`, OXT-Beyond's own build and CI tools in `tools/ci/` and `tools/oxt/`, and the scripts inside the IDE's binary stacks (`.livecode`, `.rev` and `.oxtstack` files), which a text search cannot read.

How it is made: `tools/oxt/legacy_todo.py` writes this file from a case-insensitive whole-word search for `FIXME`, `TODO` and `HACK` (so `COCOA-TODO` and `V6-TODO` count, and so does "hack" in a sentence). A line with more than one marker is listed under each. Run `python3 tools/oxt/legacy_todo.py` after a change that adds, removes or moves notes; `--check` tells whether this file is up to date. The search is:

```sh
git grep -n -I -i -w -E 'FIXME|TODO|HACK' -- . ':!thirdparty' ':!prebuilt/fetched' ':!gyp' ':!docs' \\
    ':!tools/ci' ':!tools/oxt' ':!*.md' ':!*.txt' ':!*.json' ':!*.map' ':!*.strings'
```
"""

# Comment leaders removed from the start of a note's text.
# A bare "*" only counts when space or the end of the line follows it, so
# "*TODO*" keeps its asterisks.
LEADER = re.compile(r"^(?://+!?|/\*+!?|\*+(?=\s|$)|#+|--+!?|;+|<!--)\s*")

# Longer notes are cut to this many characters.
MAX_TEXT = 160


def note_text(p_line):
    text = p_line.strip()
    # Drop a comment leader, unless code comes before the comment.
    while True:
        stripped = LEADER.sub("", text, count=1)
        if stripped == text:
            break
        text = stripped.strip()
    text = re.sub(r"\s*(?:\*+/|-->)\s*$", "", text).strip()
    if len(text) > MAX_TEXT:
        text = text[:MAX_TEXT - 3] + "..."
    return text


def section_name(p_path):
    if "/" not in p_path:
        return "(top level)"
    return p_path.split("/", 1)[0]


def anchor(p_marker, p_section):
    name = "top-level" if p_section == "(top level)" else p_section
    return "%s-%s" % (p_marker.lower(), re.sub(r"[^a-z0-9-]+", "-", name.lower()))


def find_notes(p_root):
    output = subprocess.run(
        ["git", "grep", "-n", "-I", "-i", "-w", "-E", "FIXME|TODO|HACK", "--"] + PATHSPEC,
        cwd=p_root, check=True, stdout=subprocess.PIPE).stdout
    notes = {marker: [] for marker, _ in MARKERS}
    for raw in output.splitlines():
        line = raw.decode("utf-8", "replace")
        path, number, content = line.split(":", 2)
        for marker, _ in MARKERS:
            if re.search(r"(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % marker, content, re.IGNORECASE):
                notes[marker].append((path, int(number), note_text(content)))
    return notes


def escape(p_text):
    return p_text.replace("|", "\\|")


def render(p_notes):
    out = [INTRO]
    out.append("| Marker | Notes |")
    out.append("| --- | --- |")
    for marker, _ in MARKERS:
        out.append("| [%s](#%s) | %d |" % (marker, marker.lower(), len(p_notes[marker])))
    for marker, description in MARKERS:
        by_section = collections.defaultdict(list)
        for note in p_notes[marker]:
            by_section[section_name(note[0])].append(note)
        sections = sorted(by_section, key=lambda s: (-len(by_section[s]), s))
        out.append("")
        out.append("## %s" % marker)
        out.append("")
        out.append("%s %d notes, by part of the repository:" % (description, len(p_notes[marker])))
        out.append("")
        out.append(", ".join("[%s](#%s) (%d)" % (s, anchor(marker, s), len(by_section[s]))
                             for s in sections))
        for section in sections:
            out.append("")
            out.append('<a id="%s"></a>' % anchor(marker, section))
            out.append("")
            out.append("### %s: %s (%d)" % (marker, section, len(by_section[section])))
            out.append("")
            for path, number, text in sorted(by_section[section]):
                out.append("- [%s:%d](%s#L%d) %s" % (path, number, path.replace(" ", "%20"),
                                                    number, escape(text)))
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="exit with 1 if LEGACY-TODO.md is not up to date")
    args = parser.parse_args()

    root = subprocess.run(["git", "rev-parse", "--show-toplevel"], check=True,
                          stdout=subprocess.PIPE).stdout.decode().strip()
    target = os.path.join(root, "LEGACY-TODO.md")
    text = render(find_notes(root))

    if args.check:
        with open(target, encoding="utf-8") as f:
            if f.read() != text:
                print("LEGACY-TODO.md is out of date: run python3 tools/oxt/legacy_todo.py")
                return 1
        return 0

    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
