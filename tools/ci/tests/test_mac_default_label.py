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

"""A Mac default button's label in the background (Skids, openxtalk.org
p=26152).

While the app is active a default button is drawn in the accent colour
with a white label. In the background the theme draws it as a plain
button (engine/src/buttondraw.cpp, drawstandardbutton: when
MCappisactive is false it sets WTHEME_STATE_SUPPRESSDEFAULT), but the
label of a default button with no text colour of its own was forced
white whether the app was active or not, so after a script launched
another app every default button was white on white. The label is white
only while the app is active, in each of the two places that decide it.

The engine test tests/lcs/core/interface/default-button-background
measures it on the Mac: it puts the engine in the background and reads a
default button's label against its face. This test reads the source, so
that every platform's checks hold the rule.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class TheDefaultLabelInTheBackground(unittest.TestCase):

    def setUp(self):
        source = read('engine', 'src', 'buttondraw.cpp')
        start = source.index('bool t_should_use_white_text = false;')
        self.branch = source[start:source.index('if (t_should_use_white_text)', start)]
        self.source = source

    def conditions(self):
        """Each `if (...)` that sets t_should_use_white_text, as one line."""
        found = re.findall(r'if \((.*?)\)\s*\n\s*(?:\{\s*\n\s*)?t_should_use_white_text = true;',
                           self.branch, re.S)
        return [' '.join(c.split()) for c in found]

    def test_white_only_while_active(self):
        conditions = self.conditions()
        # the glowing (hilited before macOS 11) or default button of the
        # usual height, and the default button with no text colour of its
        # own
        self.assertEqual(len(conditions), 2, conditions)
        for condition in conditions:
            self.assertIn('MCappisactive', condition)
            self.assertNotIn('!MCappisactive', condition)
        self.assertIn('!getcindex(DI_FORE, t_index) && !getpindex(DI_FORE, t_index)', conditions[1])

    def test_the_theme_suppresses_the_default_look_in_the_background(self):
        # what the label follows: in the background the default button is
        # drawn without its accent colour
        self.assertIn('if (!MCappisactive)\n\t\t\t\twinfo.state |= WTHEME_STATE_SUPPRESSDEFAULT;', self.source)

    def test_the_engine_test_is_in_ci(self):
        test = read('tests', 'lcs', 'core', 'interface', 'default-button-background.livecodescript')
        self.assertIn('on TestDefaultButtonLabelInTheBackground', test)
        self.assertIn('launch "/System/Library/CoreServices/Finder.app"', test)
        self.assertIn('TestAssert "a default button\'s label can be seen on its face in the background", '
                      'tFarthest >= 200', test)
        # it asserts only in the background, which the face shows (grey,
        # not the accent colour); an active app's test is skipped, not
        # passed
        face = test[test.index('-- the face, left of the label'):test.index('put 0 into tFarthest')]
        self.assertIn('min(item 1 of tFace, item 2 of tFace, item 3 of tFace) > 24 then', face)
        self.assertIn('TestSkip "a default button\'s label can be seen on its face in the background"', face)
        self.assertIn('exit TestDefaultButtonLabelInTheBackground', face)
        # it launches the Finder: one of the tests that act on the desktop
        runner = read('tools', 'ci', 'run_engine_tests.py')
        intrusive = runner[runner.index('INTRUSIVE = ('):]
        intrusive = intrusive[:intrusive.index('\n)\n')]
        self.assertIn("r'^lcs: core/interface/default-button-background: '", intrusive)


if __name__ == '__main__':
    unittest.main()
