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

"""Check the IDE's preference defaults for a first install.

  python tools/ci/check_ide_prefs.py [--repo DIR]

A fresh install has no preferences file: Toolset/home.livecodescript makes
one with revInternal__ResetPreferences (also run by Preferences > Reset
Preferences to Defaults), and at the end of every start
(revInternal__openStack, "Validating preference settings") it gives an
empty preference its default, which covers preferences that an older
profile does not have yet. This check reads the script (no engine needed)
and asserts the defaults the project decided on:

  - cIDEAppearance "light": the IDE starts light on every system, dark
    ones included; dark is a choice (View > Appearance, or Preferences >
    Appearance);
  - cStackAppearance "light": the user's own stacks look as in a
    standalone, which is light unless the stack opts in;
  - cMakeRevMenuBarStandard true: the menubar is a standard window;
  - cMakeRevMenuBarDraggable false, under that name (OpenXTalk Lite's
    revInternal__ResetPreferences wrote it as "MakeRevToolBarDraggable",
    a key nothing reads, so no such key may remain);

each set by revInternal__ResetPreferences and given to an empty preference
by the start-up check. It also checks that the menubar
(Toolset/palettes/menubar/revmenubar.livecodescript) treats an unset
cMakeRevMenuBarStandard as a standard window: the menubar lays itself out
before the start-up check runs, so testing "is true" there would dock the
menubar of a profile without the preference on its first start.

Exit status 1 when a check fails. Under GitHub Actions failures become
error annotations. Needs Python 3.8 or later, standard library only.
"""

import argparse
import os
import re
import sys

HOME = os.path.join('ide', 'Toolset', 'home.livecodescript')
MENUBAR = os.path.join('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript')

# preference: (default as written in revInternal__ResetPreferences, the
# value the start-up check gives an empty preference)
DEFAULTS = {
    'cIDEAppearance': 'light',
    'cStackAppearance': 'light',
    'cMakeRevMenuBarStandard': 'true',
    'cMakeRevMenuBarDraggable': 'false',
}
WRONG_KEYS = ('MakeRevToolBarDraggable',)


def read_text(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
    return data.decode('utf-8', errors='replace').replace('\r\n', '\n')


def handler(text, name):
    """The text of the handler `name` (from its first line to its end
    line), or None."""
    m = re.search(r'^[ \t]*(?:private[ \t]+)?(?:command|on|function)[ \t]+%s\b.*?^[ \t]*end[ \t]+%s[ \t]*$'
                  % (re.escape(name), re.escape(name)), text, re.MULTILINE | re.DOTALL | re.IGNORECASE)
    return m.group(0) if m else None


def code_lines(text):
    """The lines of a script without -- comments (the checks look at code)."""
    for line in text.split('\n'):
        yield re.sub(r'\s*--.*$', '', line)


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..')),
                        help='repository root (default: two levels up from this script)')
    args = parser.parse_args(argv)

    failures = []
    home_rel = HOME.replace(os.sep, '/')
    menubar_rel = MENUBAR.replace(os.sep, '/')
    home = read_text(os.path.join(args.repo, HOME))
    reset = handler(home, 'revInternal__ResetPreferences')
    startup = handler(home, 'revInternal__openStack')
    if reset is None:
        failures.append((home_rel, 'no handler revInternal__ResetPreferences'))
    if startup is None:
        failures.append((home_rel, 'no handler revInternal__openStack'))

    for pref, value in DEFAULTS.items():
        if reset is not None:
            found = [m.group(1) for line in code_lines(reset)
                     for m in [re.search(r'\bput\s+"([^"]*)"\s+into\s+tPropsArray\s*\[\s*"%s"\s*\]' % pref, line, re.IGNORECASE)] if m]
            if not found:
                failures.append((home_rel, 'revInternal__ResetPreferences does not set %s' % pref))
            elif found[-1].lower() != value:
                failures.append((home_rel, 'revInternal__ResetPreferences sets %s to "%s", not "%s"' % (pref, found[-1], value)))
            else:
                print('ok      %s: revInternal__ResetPreferences sets %s to "%s"' % (home_rel, pref, value))
        if startup is not None:
            pattern = (r'\bif\s+the\s+%s\s+of\s+stack\s+"revPreferences"\s+is\s+empty\s+then\s+'
                       r'set\s+the\s+%s\s+of\s+stack\s+"revPreferences"\s+to\s+"?(\w+)"?' % (pref, pref))
            found = [m.group(1) for line in code_lines(startup) for m in [re.search(pattern, line, re.IGNORECASE)] if m]
            if not found:
                failures.append((home_rel, 'the start-up check does not give an empty %s its default' % pref))
            elif any(v.lower() != value for v in found):
                failures.append((home_rel, 'the start-up check gives an empty %s "%s", not "%s"' % (pref, found[0], value)))
            else:
                print('ok      %s: the start-up check gives an empty %s "%s"' % (home_rel, pref, value))

    for key in WRONG_KEYS:
        if re.search(r'tPropsArray\s*\[\s*"%s"\s*\]|\bthe\s+%s\s+of\s+stack\s+"revPreferences"' % (key, key),
                     home, re.IGNORECASE):
            failures.append((home_rel, 'the preference key "%s" is set; the menubar reads cMakeRevMenuBarDraggable' % key))
        else:
            print('ok      %s: no preference key "%s"' % (home_rel, key))

    menubar = read_text(os.path.join(args.repo, MENUBAR))
    docked = [line.strip() for line in code_lines(menubar)
              if re.search(r'\bcMakeRevMenuBarStandard\s+of\s+stack\s+"revPreferences"\s+is\s+true\b', line, re.IGNORECASE)]
    if docked:
        failures.append((menubar_rel, 'tests cMakeRevMenuBarStandard "is true", which docks the menubar while the '
                                      'preference is unset: %s' % docked[0]))
    else:
        print('ok      %s: an unset cMakeRevMenuBarStandard is a standard window' % menubar_rel)

    for rel, message in failures:
        print('FAILED  %s: %s' % (rel, message))
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::error file=%s,title=IDE preferences::%s' % (rel, message))
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('### IDE preference defaults\n\n%s\n\n' % (
                'The first-install defaults are as decided (light IDE, light user stacks, menubar as a standard window).'
                if not failures else '\n'.join('- `%s`: %s' % item for item in failures)))
    print('IDE preferences: %s' % ('passed' if not failures else 'FAILED (%d problem(s))' % len(failures)))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
