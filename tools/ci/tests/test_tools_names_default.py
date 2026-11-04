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
"""The Tools palette's modern look shows its tools with their names by
default (0.2.7-rc.6.15, seth): a fresh profile opens it as one column of
icons with their names, kTmNamesWidth wide, through the existing Show Names
option (revTools_modernNames). A profile that never chose is settled once,
and the choice saved: one that has used the modern look already (a size
kept, revTools_modernSize) keeps the icons alone it has always shown, and
a saved true or false is never changed. The IDE tour's step
tools-modern-default opens the palette on each kind of profile and checks
it; on the released 0.2.7-rc.6.14 Linux IDE it fails (icons alone, 120
wide) and with this palette it passes, light and dark.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PALETTE = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'tools', 'revtools.livecodescript')
TOUR = os.path.join(REPO, 'tools', 'ci', 'ui-tour.livecodescript')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def handler(text, name):
    m = re.search(r'^[ \t]*(?:private[ \t]+)?(?:command|on|function)[ \t]+%s\b(.*?)^[ \t]*end[ \t]+%s\b'
                  % (re.escape(name), re.escape(name)), text, re.M | re.S)
    if m is None:
        raise AssertionError('no handler ' + name)
    return m.group(1)


def code(body):
    return '\n'.join(line.split('--', 1)[0] for line in body.splitlines())


def constant(text, name):
    m = re.search(r'^constant %s = (\d+)$' % name, text, re.M)
    if m is None:
        raise AssertionError('no constant ' + name)
    return int(m.group(1))


class NamesDefaultTest(unittest.TestCase):
    def setUp(self):
        self.text = read(PALETTE)
        self.names = code(handler(self.text, 'tmShowNames'))

    def test_saved_choice_is_returned_as_it_is(self):
        # a saved true or false is the user's: only empty is settled
        self.assertRegex(self.names, r'put revIDEGetPreference\("revTools_modernNames"\) into tNames')
        self.assertRegex(self.names, r'if tNames is empty then')
        self.assertRegex(self.names, r'return tNames is true')
        self.assertEqual(self.names.count('revIDESetPreference'), 1)
        inner = self.names.split('if tNames is empty then', 1)[1].split('end if', 1)[0]
        self.assertIn('revIDESetPreference "revTools_modernNames", tNames', inner)

    def test_unset_is_on_only_where_no_size_was_kept(self):
        self.assertRegex(self.names, r'put revIDEGetPreference\("revTools_modernSize"\) is empty into tNames')

    def test_only_the_menu_and_the_default_write_it(self):
        writes = re.findall(r'revIDESetPreference "revTools_modernNames", ([^\n]+)', code(self.text))
        self.assertEqual(sorted(w.strip() for w in writes), ['not tmShowNames()', 'tNames'])

    def test_first_width_is_one_column_of_names(self):
        width = constant(self.text, 'kTmNamesWidth')
        cell = constant(self.text, 'kTmNameCell')
        pad = constant(self.text, 'kTmPad')
        gap = constant(self.text, 'kTmGap')
        avail = width - pad * 2 - 4  # as tmLayout's tAvail
        self.assertGreaterEqual(avail, cell, 'one name tile fits')
        self.assertLess(avail, cell * 2 + gap, 'two do not')
        # the header shows Run and Edit with their names from 170
        self.assertGreaterEqual(width, 170)
        body = code(handler(self.text, 'tmApplySize'))
        self.assertRegex(body, r'if tmShowNames\(\) then put kTmNamesWidth into tW\s+else put kTmDefaultWidth into tW')
        # a kept size still wins
        self.assertLess(body.index('tmKeptSize()'), body.index('kTmNamesWidth'))

    def test_tour_checks_each_profile(self):
        tour = read(TOUR)
        steps = [l for l in tour.splitlines() if l.startswith('constant kSteps')][0]
        self.assertIn('tools-modern-default', steps.split('"')[1].split(','))
        body = handler(tour, 'tour_tools_modern_default')
        for call in ('tourToolsDefaultOpen empty, empty', 'tourToolsDefaultOpen empty, "120,500"',
                     'tourToolsDefaultOpen false, empty', 'tourToolsDefaultOpen true, "380,500"'):
            self.assertIn(call, body)
        self.assertIn('tourTmNamesWhole', body)
        self.assertIn('tourTmReset', body)


if __name__ == '__main__':
    unittest.main()
