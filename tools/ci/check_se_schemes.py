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

"""Check the contrast of the script editor's colour schemes on the editor's
background.

  python tools/ci/check_se_schemes.py [--repo DIR] [--baseline FILE]
      [--update] [--list]

The script editor colours script text with a colorization scheme: the
schemes are built into seColorizationLoadScheme of
ide/Toolset/palettes/script editor/behaviors/revseutilities.livecodescript,
one "case" each, as lines

  <group|class|keyword> <name> <text style> <r,g,b>

Every token colour is text on the editor's background, so it needs the WCAG
2 contrast ratio for text, 4.5:1. The background is the default of
sePrefGetDefaults: editor,backgroundcolor (white) for a light scheme, and
editor,backgroundcolordark for a dark scheme (30,30,30 while no default is
set). A scheme is dark when its name contains "dark" or it is "vibrant"
(Tom Perry's and upstream LiveCode's schemes for a dark background).

The default dark scheme (colorization,schemedark of sePrefGetDefaults), the
scheme the script editor uses in the dark appearance unless the user picks
another, must pass without exceptions. The other schemes are older ones
that users may have chosen; their known failures are listed in the baseline
(tools/ci/se-schemes-baseline.txt, one "<scheme> | <token> | <ratio>" per
line) and do not fail the check, which is a ratchet: a failure that is not
in the baseline fails it, and baseline entries that pass now are reported.
--update rewrites the baseline with the current failures of the schemes
other than the default dark one; --list prints every token.

Exit status 1 when the check fails. Under GitHub Actions failures become
error annotations and the counts go to the job summary. Needs Python 3.8 or
later, standard library only.
"""

import argparse
import os
import re
import sys

SCRIPT = os.path.join('ide', 'Toolset', 'palettes', 'script editor', 'behaviors', 'revseutilities.livecodescript')
MINIMUM = 4.5
# The dark background while sePrefGetDefaults has no editor,backgroundcolordark
FALLBACK_DARK = (30, 30, 30)

HANDLER = re.compile(r'^\s*(?:private\s+)?(?:command|on|function)\s+(\w+)', re.IGNORECASE)
CASE = re.compile(r'^\s*case\s+"([^"]+)"', re.IGNORECASE)
TOKEN = re.compile(r'"((?:group|class|keyword)\s+\S+)\s+\S+\s+(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})"')
DEFAULT = re.compile(r'^\s*put\s+"([^"]*)"\s+into\s+tPrefs\["([^"]+)"\]', re.IGNORECASE)


def read_text(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
    return data.decode('utf-8', errors='replace').replace('\r\n', '\n')


def parse(text):
    """({scheme: [(token, (r, g, b)), ...]}, {preference: default}) from the
    script: the schemes of seColorizationLoadScheme and the string defaults
    of sePrefGetDefaults."""
    schemes = {}
    defaults = {}
    handler = None
    scheme = None
    for line in text.split('\n'):
        m = HANDLER.match(line)
        if m:
            handler = m.group(1).lower()
            scheme = None
            continue
        if re.match(r'^\s*end\s+\w+\s*$', line, re.IGNORECASE) and handler and \
                line.strip().lower() == 'end ' + handler:
            handler = None
            continue
        if handler == 'secolorizationloadscheme':
            m = CASE.match(line)
            if m:
                scheme = m.group(1).lower()
                schemes.setdefault(scheme, [])
                continue
            if scheme is not None:
                for token in TOKEN.finditer(line):
                    rgb = tuple(int(c) for c in token.groups()[1:])
                    schemes[scheme].append((re.sub(r'\s+', ' ', token.group(1)), rgb))
                if re.match(r'^\s*break\s*$', line, re.IGNORECASE):
                    scheme = None
        elif handler == 'seprefgetdefaults':
            m = DEFAULT.match(line)
            if m:
                defaults[m.group(2).lower()] = m.group(1)
    # A case without tokens (the "Custom" scheme read from a file) is no scheme
    return {k: v for k, v in schemes.items() if v}, defaults


def luminance(rgb):
    def channel(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(fore, back):
    a, b = luminance(fore), luminance(back)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def rgb_of(value):
    parts = [p.strip() for p in (value or '').split(',')]
    if len(parts) >= 3 and all(p.isdigit() and int(p) <= 255 for p in parts[:3]):
        return tuple(int(p) for p in parts[:3])
    return None


def is_dark(scheme):
    return 'dark' in scheme or scheme == 'vibrant'


def read_baseline(path):
    entries = set()
    if os.path.isfile(path):
        with open(path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    # The ratio is for the reader; the entry is scheme | token
                    entries.add(' | '.join(part.strip() for part in line.split('|')[:2]))
    return entries


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..')),
                        help='repository root (default: two levels up from this script)')
    parser.add_argument('--baseline', default=os.path.join(here, 'se-schemes-baseline.txt'),
                        help='baseline file (default: %(default)s)')
    parser.add_argument('--update', action='store_true', help='rewrite the baseline with the current failures')
    parser.add_argument('--list', action='store_true', help='print every token with its ratio')
    args = parser.parse_args(argv)

    rel = SCRIPT.replace(os.sep, '/')
    schemes, defaults = parse(read_text(os.path.join(args.repo, SCRIPT)))
    problems = []
    if not schemes:
        problems.append('no colorization scheme found in seColorizationLoadScheme')
    light_back = rgb_of(defaults.get('editor,backgroundcolor')) or (255, 255, 255)
    dark_back = rgb_of(defaults.get('editor,backgroundcolordark')) or FALLBACK_DARK
    dark_default = (defaults.get('colorization,schemedark') or '').lower()
    if dark_default and dark_default not in schemes:
        problems.append('the default dark scheme "%s" is not a built-in scheme' % dark_default)

    failures = []
    for scheme in sorted(schemes):
        back = dark_back if is_dark(scheme) else light_back
        for token, rgb in schemes[scheme]:
            value = ratio(rgb, back)
            if args.list:
                print('%-14s %-28s %-12s on %-12s %5.2f' % (scheme, token, '%d,%d,%d' % rgb, '%d,%d,%d' % back, value))
            if value < MINIMUM:
                failures.append((scheme, token, value, rgb, back))

    if args.update:
        lines = ['# Known failures of tools/ci/check_se_schemes.py: script editor scheme',
                 '# colours below 4.5:1 on the editor background, one',
                 '# "<scheme> | <token> | <ratio>" per line. The default dark scheme may not',
                 '# be listed. Regenerate with python tools/ci/check_se_schemes.py --update']
        lines += ['%s | %s | %.2f' % (s, t, v) for s, t, v, _, _ in failures if s != dark_default]
        with open(args.baseline, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines) + '\n')
        print('Wrote %d known failure(s) to %s' % (len(lines) - 4, args.baseline))
        return 0

    baseline = read_baseline(args.baseline)
    new = []
    known = 0
    seen = set()
    for scheme, token, value, rgb, back in failures:
        key = '%s | %s' % (scheme, token)
        seen.add(key)
        if scheme != dark_default and key in baseline:
            known += 1
            continue
        new.append('%s: %s %d,%d,%d on %d,%d,%d is %.2f:1, below %.1f:1%s' % (
            scheme, token, rgb[0], rgb[1], rgb[2], back[0], back[1], back[2], value, MINIMUM,
            ' (the default dark scheme)' if scheme == dark_default else ''))
    fixed = sorted(baseline - seen)

    print('Script editor schemes: %d scheme(s), %d token(s); light on %s, dark on %s; default dark scheme: %s'
          % (len(schemes), sum(len(v) for v in schemes.values()), '%d,%d,%d' % light_back,
             '%d,%d,%d' % dark_back, dark_default or '(none)'))
    print('%d token(s) below %.1f:1: %d in the baseline, %d new; %d baseline entr%s pass now'
          % (len(failures), MINIMUM, known, len(new), len(fixed), 'y' if len(fixed) == 1 else 'ies'))
    for message in problems + new:
        print('FAILED  %s: %s' % (rel, message))
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::error file=%s,title=Script editor schemes::%s' % (rel, message))
    for entry in fixed:
        print('passes now, remove from the baseline: %s' % entry)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('### Script editor schemes\n\n%d token(s) below 4.5:1, %d in the baseline, %d new.\n\n'
                    % (len(failures), known, len(new) + len(problems)))
    return 1 if new or problems else 0


if __name__ == '__main__':
    sys.exit(main())
