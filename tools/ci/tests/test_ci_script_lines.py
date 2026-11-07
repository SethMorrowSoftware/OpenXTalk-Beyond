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

"""The scripts that CI opens in the IDE or an engine (tools/ci/*.livecodescript:
the IDE tour, the everyday tasks, the checks) have nothing between their
handlers but comments, blank lines and declarations.

A line of prose that lost its "--" (a comment rewrapped by hand) makes the
whole script fail to compile, and the engine then runs none of it: the IDE
tour on #406 printed no line at all for 15 minutes in each appearance
("No line from the script after 60 s"), and the IDE screenshots of the
release passed with the tour never run. Nothing builds these scripts
before CI opens them, so this reads them: outside a handler each line is
blank, a comment (--, #, // or a /* */ block), the script line, or a
constant, local or global declaration (and the lines that continue one
with a backslash), and every handler that starts ends.

  python3 -m unittest discover -s tools/ci/tests
"""

import glob
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

START = re.compile(r'^\s*(?:private\s+)?(?:on|command|function|getprop|setprop|before|after)\s+([A-Za-z_][\w.]*)',
                   re.I)
DECLARATION = re.compile(r'^\s*(?:constant|local|global|script)\b', re.I)


def stray_lines(text):
    """[(line number, line)] of what is outside a handler and is not a
    comment, a blank line or a declaration; a handler that never ends is
    one, at its first line."""
    found = []
    handler = None
    started = 0
    block = False
    continued = False
    for number, line in enumerate(text.lstrip('﻿').split('\n'), 1):
        stripped = line.strip()
        if block:
            block = '*/' not in stripped
            continue
        if handler is not None:
            if re.match(r'^\s*end\s+%s\s*$' % re.escape(handler), line, re.I):
                handler = None
            continue
        if continued:
            continued = stripped.endswith('\\')
            continue
        if not stripped or stripped.startswith(('--', '#', '//')):
            continue
        if stripped.startswith('/*'):
            block = '*/' not in stripped[2:]
            continue
        start = START.match(line)
        if start:
            handler, started = start.group(1), number
            continue
        if DECLARATION.match(line):
            continued = stripped.endswith('\\')
            continue
        found.append((number, line))
    if handler is not None:
        found.append((started, 'a handler %s that never ends' % handler))
    return found


class TheCIScripts(unittest.TestCase):

    def scripts(self):
        found = sorted(glob.glob(os.path.join(REPO, 'tools', 'ci', '*.livecodescript')))
        self.assertGreater(len(found), 20)
        return found

    def test_nothing_stray_between_handlers(self):
        for path in self.scripts():
            with open(path, encoding='utf-8') as f:
                stray = stray_lines(f.read())
            self.assertEqual(stray, [], os.path.relpath(path, REPO))

    def test_the_tour_and_the_everyday_tasks_are_among_them(self):
        names = [os.path.basename(p) for p in self.scripts()]
        self.assertIn('ui-tour.livecodescript', names)
        self.assertIn('everyday-tasks.livecodescript', names)


class TheCheck(unittest.TestCase):
    """The check itself, on the line that broke the tour and its kin."""

    def test_prose_that_lost_its_dashes(self):
        text = ('script "x"\n'
                '-- the answer and ask dialogs, and last,\n'
                'on the Mac, a default button in the background\n'
                '-- more\n'
                'on tourRun\n'
                '   put 1 into x\n'
                'end tourRun\n')
        # it reads as a handler named "the" that never ends
        self.assertEqual(stray_lines(text), [(3, 'a handler the that never ends')])

    def test_a_bare_line(self):
        text = '-- a comment\nthe IDE in the background\non a\nend a\n'
        self.assertEqual(stray_lines(text), [(2, 'the IDE in the background')])

    def test_what_may_be_there(self):
        text = ('﻿script "x"\n'
                '/* a block\n'
                'of prose */\n'
                '# a comment\n'
                '// another\n'
                'constant kA = "a,b," & \\\n'
                '      "c"\n'
                'local sA, sB\n'
                'global gA\n'
                'private function f pA\n'
                '   on the inside anything goes\n'
                'end f\n'
                'getProp cP\n'
                'end cP\n')
        self.assertEqual(stray_lines(text), [])


if __name__ == '__main__':
    unittest.main()
