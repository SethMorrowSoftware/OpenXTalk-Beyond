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

"""revIDEPropertiesInfoOfSection with a section gives that section's rows.

Up to 0.2.7 the IDE library's revIDEPropertiesInfoOfSection, asked for one
section (revIDEPropertiesInfoOfSection(tObject, "Basic")), called
__orderPropSection, a handler the library has never had, so the call
stopped with "can't find handler" (found by #434's tour step). It now
orders the section as revIDEPropertiesInfo orders each section of the
whole list (__orderPropSubArray), so the two agree. Without a section,
revIDEPropertiesInfoOfSection, and revIDEPropertiesInfo through it, are
unchanged.

The IDE tour's inspector-button-menu step asks for the section that holds
each button kind's Style row and fails when the call throws, has no Style
row, or differs from that section of revIDEPropertiesInfo (it failed on
the 0.2.7 package's library, five times, with __orderPropSection, and
passes with this one). These tests hold the source and the step.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
LIBRARY = ('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
TOUR = ('tools', 'ci', 'ui-tour.livecodescript')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def code_of(text):
    """The script with its comments left out (block and line comments)."""
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    out = []
    for line in text.split('\n'):
        # a -- or # outside a string starts a comment
        kept, quoted = [], False
        i = 0
        while i < len(line):
            c = line[i]
            if c == '"':
                quoted = not quoted
            elif not quoted and (line.startswith('--', i) or c == '#'):
                break
            kept.append(c)
            i += 1
        out.append(''.join(kept))
    return '\n'.join(out)


def handler(text, name):
    m = re.search(r'^(?:private )?function %s\b.*?^end %s\b' % (name, name), text, re.M | re.S)
    if not m:
        raise AssertionError('no function %s' % name)
    return m.group(0)


class TheLibrary(unittest.TestCase):
    def test_every_double_underscore_function_called_is_defined(self):
        # the library's own helpers (__name) are its own: one called and
        # never defined stops its caller with "can't find handler"
        code = code_of(read(*LIBRARY))
        defined = set(re.findall(r'^\s*(?:private\s+)?(?:function|on|command)\s+(__\w+)', code, re.M | re.I))
        called = set(re.findall(r'\b(__\w+)\s*\(', code))
        self.assertEqual(sorted(called - defined), [])

    def test_a_section_is_ordered_as_the_whole_list_orders_each(self):
        body = code_of(handler(read(*LIBRARY), 'revIDEPropertiesInfoOfSection'))
        self.assertNotIn('__orderPropSection', body)
        self.assertIn('return __orderPropSubArray(tSharedPropertiesA, true)', body)
        # the whole list, without a section, is as it was
        self.assertIn('return __orderPropArray(tSharedPropertiesA, revIDEPropertySections())', body)

    def test_the_whole_list_hands_each_section_to_the_same_order(self):
        body = code_of(handler(read(*LIBRARY), '__orderPropArray'))
        self.assertIn('__orderPropSubArray(pPropsA[tSection], true)', body)

    def test_the_section_info_is_the_section_itself(self):
        # __objectPropertiesShared gives tPropertiesArray[pOptionalSection]
        # for a section, the shape __orderPropSubArray reads ("grouplist")
        shared = code_of(read(*LIBRARY))
        self.assertIn('return tPropertiesArray[pOptionalSection]', shared)


class TheTourStep(unittest.TestCase):
    def test_the_style_row_check_asks_for_its_section(self):
        tour = read(*TOUR)
        body = handler(tour, 'tourBmCheckRow')
        self.assertIn('return tourBmCheckSection(pWhat, pButton, tInfo)', body)

    def test_the_section_check_fails_on_a_throw_a_missing_row_or_a_difference(self):
        body = handler(read(*TOUR), 'tourBmCheckSection')
        self.assertIn('revIDEPropertiesInfoOfSection(pButton, tSection)', body)
        self.assertIn('catch tError', body)
        self.assertIn('section failed:', body)
        self.assertIn('section has no Style row', body)
        self.assertIn('if tGroups is not pInfo[tKey]["grouplist"] then', body)

    def test_the_step_is_in_the_tour(self):
        steps = re.search(r'^constant kSteps = "([^"]*)"', read(*TOUR), re.M).group(1).split(',')
        self.assertIn('inspector-button-menu', steps)


if __name__ == '__main__':
    unittest.main()
