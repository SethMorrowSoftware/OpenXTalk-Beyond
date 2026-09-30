#!/usr/bin/env python3
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

"""List the colour literals that IDE scripts set as colours, and fail on new
ones.

  python tools/ci/check_ide_colour_literals.py [--repo DIR] [--baseline FILE]
      [--update] [--list]

The IDE's colours belong in one table, revIDEColor (and ideColorGet, which it
falls back to), so that the light and the dark appearance can be checked and
changed in one place (tools/ci/ide-contrast-check.livecodescript checks that
table). A colour written straight into a palette script bypasses both. This
lint finds such colours in ide/**/*.livecodescript: every statement

  set [the] <property> [of <object>] to <literal>

that starts a line, follows "then" or "else" on the same line (as in
"if the systemAppearance is "dark" then set the backColor of me to ...", a
common form of one-off dark-mode colours) or follows a ";", whose property
names a colour (color, colour, colors, colorOverlay["color"],
viewProp["row color"], ...) and whose value is a literal colour: an RGB
triplet such as 60,60,60 or "255,80,0", a "#rrggbb" string, or a colour name
such as white or gray70 (the engine's colorNames). Statements inside the
handlers revIDEColor and ideColorGet, commented-out statements and values
that are expressions (variables, function calls, the accentColor, ...) are
not literals.

It also finds colour constants,

  [private] constant kEffectiveTextColor = "100,100,100"[, kOther = ...]

whose name starts with k and names a colour and whose value is a literal
colour: the statements that set such a constant as a colour show only its
name, so the literal is here.

Each literal is recorded as

  <file> | <handler> | <property> = <literal>

(a constant as "constant <name>", with the handler "(script)" when it is
declared outside handlers)

(no line numbers, so unrelated edits do not change the record). The baseline
(tools/ci/ide-colour-literals-baseline.txt, one record per line, repeated
for repeated literals) lists the literals that are known. The check is a
ratchet: it fails (exit status 1) only when a record occurs more often than
in the baseline, and reports baseline records that no longer occur, so that
the baseline can shrink. --update rewrites the baseline with the current
records; --list prints every record with its line number.

Under GitHub Actions the new literals become error annotations and the counts
go to the job summary. Needs Python 3.8 or later, standard library only.
"""

import argparse
import collections
import os
import re
import sys

# The engine's colour names (the colorNames), without their numbered
# variants: "gray70" or "Blue4" is a known name followed by digits.
COLOUR_NAMES = frozenset("""
aliceblue antiquewhite aquamarine azure beige bisque black blanchedalmond blue
blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue
cornsilk cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkkhaki
darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon
darkseagreen darkslateblue darkslategray darkturquoise darkviolet deeppink
deepskyblue dimgray dodgerblue firebrick floralwhite forestgreen gainsboro
ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink
indianred ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue
lightcoral lightcyan lightgoldenrod lightgoldenrodyellow lightgray lightgreen
lightpink lightsalmon lightseagreen lightskyblue lightslateblue lightslategray
lightsteelblue lightyellow limegreen linen magenta maroon mediumaquamarine
mediumblue mediumforestgreen mediumgoldenrod mediumorchid mediumpurple
mediumseagreen mediumslateblue mediumspringgreen mediumturquoise
mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy
navyblue oldlace olivedrab orange orangered orchid palegoldenrod palegreen
paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue
purple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell
sienna skyblue slateblue slategray snow springgreen steelblue tan thistle
tomato turquoise violet violetred wheat white whitesmoke yellow yellowgreen
""".split())

# Handlers that are the colour table itself
TABLE_HANDLERS = frozenset(['revidecolor', 'idecolorget'])

HANDLER_START = re.compile(
    r'^\s*(?:private\s+)?(?:on|command|function|getprop|setprop|before|after)\s+([A-Za-z_][\w.]*)',
    re.IGNORECASE)
HANDLER_END = re.compile(r'^\s*end\s+([A-Za-z_][\w.]*)\s*$', re.IGNORECASE)
SET_THE = re.compile(r'^\s*set\s+(?:the\s+)?(.*)$', re.IGNORECASE | re.DOTALL)
# "then" and "else" as whole words (not inside an identifier such as
# tThen or revIDE.else), where a statement on the same line starts
STATEMENT_WORD = re.compile(r'(?<![\w.])(?:then|else)(?![\w.])', re.IGNORECASE)
TO_WORD = re.compile(r'\bto\b', re.IGNORECASE)
CONSTANT = re.compile(r'^\s*(?:private\s+)?constant\s+(.*)$', re.IGNORECASE | re.DOTALL)
# One "name = value" of a constant declaration; the value is a string or a
# word (a constant declaration takes literals only)
CONSTANT_ITEM = re.compile(r'\s*([A-Za-z_]\w*)\s*=\s*("[^"]*"|[^,\s]+)\s*(?:,|$)')
COLOUR_CONSTANT = re.compile(r'^k\w*colou?r', re.IGNORECASE)
RGB = re.compile(r'^"?\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})(?:\s*,\s*(\d{1,3}))?\s*"?$')
HEX = re.compile(r'^"?(#[0-9A-Fa-f]{6})"?$')
NAME = re.compile(r'^"?([A-Za-z]+)(\d{0,3})"?$')

# The line continuation character of old (Mac Roman) scripts, read as UTF-8
NOT_SIGN = chr(0xAC)


def strip_comment(line):
    """The line without a trailing --, # or // comment (outside strings)."""
    in_string = False
    i = 0
    while i < len(line):
        c = line[i]
        if c == '"':
            in_string = not in_string
        elif not in_string:
            if line.startswith('--', i) or line.startswith('//', i) or c == '#':
                # "#" also starts a colour such as "#FF8000", which is inside
                # a string and so never reaches here
                return line[:i]
        i += 1
    return line


def statements(line):
    """The statements of a logical line (without its comment): the pieces
    between ";" and the words "then" and "else", outside strings. The
    condition of a one-line "if" is a piece of its own, which is no set
    statement."""
    pieces = []
    in_string = False
    start = 0
    i = 0
    while i < len(line):
        c = line[i]
        if c == '"':
            in_string = not in_string
        elif not in_string:
            if c == ';':
                pieces.append(line[start:i])
                start = i + 1
            else:
                # The lookbehind sees the character before i
                m = STATEMENT_WORD.match(line, i)
                if m:
                    pieces.append(line[start:i])
                    start = i = m.end()
                    continue
        i += 1
    pieces.append(line[start:])
    return pieces


def logical_lines(text):
    """(line number, text) of each statement: comments removed, block
    comments skipped and lines continued with a trailing backslash (or the
    LiveCode continuation character) joined."""
    in_block = False
    pending = None
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw
        if in_block:
            end = line.find('*/')
            if end < 0:
                continue
            line = line[end + 2:]
            in_block = False
        while True:
            start = strip_comment(line).find('/*')
            if start < 0:
                break
            end = line.find('*/', start + 2)
            if end < 0:
                line = line[:start]
                in_block = True
                break
            line = line[:start] + ' ' + line[end + 2:]
        line = strip_comment(line).rstrip()
        if pending is not None:
            start_number, previous = pending
            line = previous + ' ' + line.strip()
        else:
            start_number = number
        if line.endswith('\\') or line.endswith(NOT_SIGN):
            pending = (start_number, line[:-1].rstrip())
            continue
        pending = None
        yield start_number, line
    if pending is not None:
        yield pending


def literal_colour(value):
    """The normalised literal colour in a set statement's value, or None."""
    value = value.strip()
    while value.startswith('(') and value.endswith(')'):
        value = value[1:-1].strip()
    m = RGB.match(value)
    if m:
        channels = [c for c in m.groups() if c is not None]
        if all(int(c) <= 255 for c in channels):
            return ','.join(str(int(c)) for c in channels)
        return None
    m = HEX.match(value)
    if m:
        return m.group(1).upper()
    m = NAME.match(value)
    if m and m.group(1).lower() in COLOUR_NAMES:
        return (m.group(1) + m.group(2)).lower()
    return None


def scan_script(text):
    """(line, handler, property, literal) for each colour literal set in a
    script's text."""
    handler = '(script)'
    for number, line in logical_lines(text):
        m = HANDLER_END.match(line)
        if m and handler != '(script)' and m.group(1).lower() == handler.lower():
            handler = '(script)'
            continue
        m = HANDLER_START.match(line)
        if m:
            handler = m.group(1)
            continue
        if handler.lower() in TABLE_HANDLERS:
            continue
        m = CONSTANT.match(line)
        if m:
            rest = m.group(1)
            position = 0
            while position < len(rest):
                item = CONSTANT_ITEM.match(rest, position)
                if not item or item.end() == position:
                    break
                position = item.end()
                if COLOUR_CONSTANT.match(item.group(1)):
                    literal = literal_colour(item.group(2))
                    if literal is not None:
                        yield number, handler, 'constant ' + item.group(1).lower(), literal
            continue
        for piece in statements(line):
            m = SET_THE.match(piece)
            if not m:
                continue
            statement = m.group(1)
            tos = list(TO_WORD.finditer(statement))
            if not tos:
                continue
            target = statement[:tos[-1].start()]
            value = statement[tos[-1].end():]
            # The property is what comes before " of " (or all of the target)
            prop = re.split(r'\s+of\s+', target.strip(), maxsplit=1, flags=re.IGNORECASE)[0]
            if not re.search(r'colou?r', prop, re.IGNORECASE):
                continue
            literal = literal_colour(value)
            if literal is None:
                continue
            prop = re.sub(r'\s+', ' ', prop.strip()).lower()
            yield number, handler, prop, literal


def read_text(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
    return data.decode('utf-8', errors='replace')


def scan_repo(repo):
    """{record: [(path, line), ...]} for ide/**/*.livecodescript."""
    found = collections.OrderedDict()
    ide = os.path.join(repo, 'ide')
    paths = []
    for folder, dirs, files in os.walk(ide):
        dirs.sort()
        for name in sorted(files):
            if name.lower().endswith('.livecodescript'):
                paths.append(os.path.join(folder, name))
    for path in paths:
        rel = os.path.relpath(path, repo).replace(os.sep, '/')
        for number, handler, prop, literal in scan_script(read_text(path)):
            record = '%s | %s | %s = %s' % (rel, handler, prop, literal)
            found.setdefault(record, []).append((rel, number))
    return found, len(paths)


def read_baseline(path):
    counts = collections.Counter()
    if not os.path.isfile(path):
        return counts
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\r\n').strip()
            if line and not line.startswith('#'):
                counts[line] += 1
    return counts


def github(message):
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        print(message)


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..')),
                        help='repository root (default: two levels up from this script)')
    parser.add_argument('--baseline', default=os.path.join(here, 'ide-colour-literals-baseline.txt'),
                        help='baseline file (default: %(default)s)')
    parser.add_argument('--update', action='store_true', help='rewrite the baseline with the current literals')
    parser.add_argument('--list', action='store_true', help='print every literal with its line number')
    args = parser.parse_args(argv)

    found, file_count = scan_repo(args.repo)
    total = sum(len(v) for v in found.values())
    if args.list:
        for record, places in found.items():
            for rel, number in places:
                print('%s:%d: %s' % (rel, number, record.split(' | ', 1)[1]))

    if args.update:
        header = [
            '# Known colour literals that IDE scripts set as colours, one line per',
            '# occurrence: <file> | <handler> | <property> = <literal>.',
            '# tools/ci/check_ide_colour_literals.py fails only on literals that are',
            '# not listed here (use a revIDEColor tag for a new colour) and reports',
            '# entries that no longer occur. Regenerate with',
            '#   python tools/ci/check_ide_colour_literals.py --update',
        ]
        lines = []
        for record in sorted(found):
            lines.extend([record] * len(found[record]))
        with open(args.baseline, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(header + lines) + '\n')
        print('Wrote %d literal(s) in %d record(s) to %s' % (total, len(found), args.baseline))
        return 0

    baseline = read_baseline(args.baseline)
    new = []
    for record, places in found.items():
        extra = len(places) - baseline.get(record, 0)
        if extra > 0:
            # Which occurrences are the new ones is unknown; report the last
            new.extend((record, rel, number) for rel, number in places[-extra:])
    gone = []
    for record, count in sorted(baseline.items()):
        missing = count - len(found.get(record, []))
        if missing > 0:
            gone.extend([record] * missing)

    print('IDE colour literals: %d in %d script(s) (%d file(s) scanned); baseline %d; new %d; no longer found %d'
          % (total, len({p[0] for v in found.values() for p in v}), file_count,
             sum(baseline.values()), len(new), len(gone)))
    if new:
        print('\nNew colour literals (use revIDEColor instead, or add them to the baseline):')
        for record, rel, number in new:
            print('  %s:%d: %s' % (rel, number, record.split(' | ', 1)[1]))
            github('::error file=%s,line=%d,title=IDE colour literal::%s set to a literal colour; use a revIDEColor tag'
                   % (rel, number, record.split(' | ', 2)[2]))
    if gone:
        print('\nBaseline records that no longer occur (remove them from the baseline):')
        for record in gone:
            print('  ' + record)
        github('::warning title=IDE colour literals::%d baseline record(s) no longer occur; '
               'shrink tools/ci/ide-colour-literals-baseline.txt' % len(gone))

    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('### IDE colour literals\n\n%d literal colour(s) set in IDE scripts; %d in the baseline, '
                    '%d new, %d baseline record(s) no longer found.\n\n' % (total, sum(baseline.values()), len(new), len(gone)))
            if new:
                f.write('New:\n\n```text\n%s\n```\n\n' % '\n'.join(
                    '%s:%d: %s' % (rel, number, record.split(' | ', 1)[1]) for record, rel, number in new[:50]))
    return 1 if new else 0


if __name__ == '__main__':
    sys.exit(main())
