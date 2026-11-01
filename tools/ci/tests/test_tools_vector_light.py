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

"""The Tools palette's Line tile kept its light when another vector tool
was chosen after it (micmac, openxtalk.org p=25846). Every vector tile
chooses the graphic tool, with the template graphic's style for its shape,
so going from one to another changes no tool: the engine sends no newTool,
the IDE no ideToolChanged, and the palette never moved its light. The
palette's mouseDown now lights the tile itself when the tool was the
graphic tool already, in the classic look and the modern one (whose
ideToolChanged hands over to tmToolChanged). The IDE tour's step
tools-vector chooses Line, Polygon, Curve and Line in both looks and
checks the light is on each; on the released 0.2.7-rc.6.11 Linux IDE it
fails and with this palette it passes.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PALETTE = ('ide', 'Toolset', 'palettes', 'tools', 'revtools.livecodescript')
MESSAGES = ('ide', 'Toolset', 'libraries', 'revidemessagehandlerlibrary.livecodescript')
TOUR = ('tools', 'ci', 'ui-tour.livecodescript')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def handler(script, kind, name):
    start = script.index('\n%s %s' % (kind, name))
    # (an end line can carry trailing spaces, as ideToolChanged's does)
    return script[start:re.compile(r'\nend %s[ \t]*\n' % name).search(script, start).start()]


class ThePalette(unittest.TestCase):
    def setUp(self):
        self.palette = read(*PALETTE)

    def test_the_tool_changes_only_by_newtool(self):
        # why the palette must light the tile itself: ideToolChanged comes
        # only from newTool, which the engine sends only for a new tool
        new_tool = handler(read(*MESSAGES), 'on', 'newTool')
        self.assertIn('send "ideMessageSend" &&  "ideToolChanged"', new_tool)

    def test_a_vector_tile_lights_itself(self):
        down = handler(self.palette, 'on', 'mouseDown')
        case = down[down.index('case "graphic tool"'):]
        case = case[:case.index('break')]
        was = case.index('put the tool into tWasTool')
        choose = case.index('revIDESetTool the cToolName of the target')
        light = case.index('if tWasTool is the cToolName of the target then ideToolChanged')
        self.assertLess(was, choose)
        self.assertLess(choose, light)

    def test_both_looks_follow_ideToolChanged(self):
        changed = handler(self.palette, 'on', 'ideToolChanged')
        self.assertIn('tmToolChanged tTool', changed)
        self.assertIn('the style of the templategraphic is not the cStyle of tControlID', changed)
        modern = handler(self.palette, 'command', 'tmToolChanged')
        self.assertIn('the style of the templategraphic is not the cStyle of tObj', modern)


class TheTour(unittest.TestCase):
    def setUp(self):
        self.tour = read(*TOUR)

    def test_the_step(self):
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertIn('tools-vector', steps)
        # before the modern look's steps, which expect the classic look back
        self.assertLess(steps.index('tools-vector'), steps.index('tools-modern'))
        step = handler(self.tour, 'on', 'tour_tools_vector')
        self.assertIn('put tourToolsVectorCheck("classic") into tFails', step)
        self.assertIn('put tourToolsVectorCheck("modern") after tFails', step)
        self.assertIn('tourToolsClassic', step[step.index('tourToolsVectorCheck("modern")'):])
        check = handler(self.tour, 'function', 'tourToolsVectorCheck')
        self.assertIn('repeat for each item tName in "Line,Polygon,Curve,Line"', check)
        self.assertIn('tourTmClick tTile', check)
        self.assertIn('the rect of tLight is not the rect of tTile', check)


if __name__ == '__main__':
    unittest.main()
