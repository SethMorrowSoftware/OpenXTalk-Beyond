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

"""The Object menu's Copy Graphics as SVG Paths did nothing (OpenXTalkPaul,
openxtalk.org p=25819): OpenXTalk Lite 1.01 added the item, and its call to
revOXTIDEGraphicPointsToSVGPath, but never the command, so a pick threw
"can't find handler". The command is in the IDE library now, and the IDE
tour picks the item with graphics selected and reads the clipboard
(tools/ci/ui-tour.livecodescript, the step svg-paths). These tests hold the
pieces to each other, and hold every revOXTIDE command the menu bar calls
to a handler that exists. The copy also goes on the clipboard under the
types Adobe Illustrator reads (OpenXTalkPaul, p=25820), which the tour
reads back.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

MENUBAR = ('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript')
LIBRARY = ('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def handler(script, kind, name):
    start = script.index('\n%s %s' % (kind, name))
    return script[start:script.index('\nend %s\n' % name, start)]


def defined_in_ide():
    """Every handler name defined in a script of the IDE, lower case."""
    names = set()
    for top, _dirs, files in os.walk(os.path.join(REPO, 'ide')):
        for name in files:
            if name.endswith('.livecodescript'):
                with open(os.path.join(top, name), encoding='utf-8-sig', errors='replace') as f:
                    for m in re.finditer(r'^(?:private\s+)?(?:on|command|function)\s+([A-Za-z_]\w*)',
                                         f.read(), re.M):
                        names.add(m.group(1).lower())
    return names


class TheMenuBar(unittest.TestCase):
    def test_every_revoxtide_command_it_calls_exists(self):
        # a call at the start of a statement, as the menu picks make them
        menubar = read(*MENUBAR)
        called = set(m.group(1) for m in re.finditer(r'^\s+(revOXTIDE\w+)\b', menubar, re.M))
        self.assertIn('revOXTIDEGraphicPointsToSVGPath', called)
        defined = defined_in_ide()
        for name in sorted(called):
            with self.subTest(command=name):
                self.assertTrue(name.lower() in defined, '%s is called by the menu bar and defined nowhere' % name)

    def test_the_item_passes_the_selection(self):
        pick = handler(read(*MENUBAR), 'on', 'revMenubarObjectMenuPick')
        self.assertIn('case "Copy Graphics as SVG Paths"\n         revOXTIDEGraphicPointsToSVGPath the selobjs', pick)


class TheCommand(unittest.TestCase):
    def setUp(self):
        self.library = read(*LIBRARY)

    def test_it_puts_the_svg_on_the_clipboard(self):
        command = handler(self.library, 'command', 'revOXTIDEGraphicPointsToSVGPath')
        self.assertIn('put revOXTIDEGraphicsToSVG(pObjects) into tSVG', command)
        self.assertIn('set the clipboardData["text"] to tSVG', command)

    def test_illustrators_types_join_the_text(self):
        # openxtalk.org p=25820: Illustrator and VectorCraft paste these as
        # vector paths; seth said yes on 2026-10-31
        types = 'com.adobe.illustrator.svg,com.adobe.illustrator.svgm,com.adobe.svg'
        self.assertIn('constant kSVGClipboardTypes = "%s"' % types, self.library)
        command = handler(self.library, 'command', 'revOXTIDEGraphicPointsToSVGPath')
        self.assertIn('put textEncode(tSVG, "UTF-8") into tData', command)
        # the text first (which clears the clipboard), then the types, all in
        # one lock, and the lock always let go
        lock = command.index('lock the clipboard')
        text = command.index('set the clipboardData["text"] to tSVG')
        raw = command.index('set the rawClipboardData[tType] to tData')
        unlock = command.index('unlock the clipboard')
        self.assertLess(lock, text)
        self.assertLess(text, raw)
        self.assertLess(raw, unlock)
        self.assertIn('repeat for each item tType in kSVGClipboardTypes', command)
        self.assertIn('catch tError', command[raw:unlock])

    def test_a_path_for_each_graphic(self):
        svg = handler(self.library, 'function', 'revOXTIDEGraphicsToSVG')
        self.assertIn('if word 1 of tObject is not "graphic" then next repeat', svg)
        self.assertIn('http://www.w3.org/2000/svg', svg)
        # the box holds half of each line beyond its graphic's rect
        self.assertIn('put (the lineSize of tObject + 1) div 2 into tPad', svg)
        path = handler(self.library, 'private function', '__revOXTIDEGraphicToSVGPath')
        self.assertIn('the effective points of pGraphic', path)
        run = handler(self.library, 'private function', '__revOXTIDESVGRun')
        self.assertIn('if tCount > 1 and line tCount of pRun is line 1 of pRun then', run)


class TheTour(unittest.TestCase):
    def setUp(self):
        self.tour = read('tools', 'ci', 'ui-tour.livecodescript')

    def test_the_step(self):
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertIn('svg-paths', steps)
        step = handler(self.tour, 'on', 'tour_svg_paths')
        self.assertIn('set the clipboardData["text"] to "nothing copied"', step)
        self.assertIn('dispatch "revMenubarObjectMenuPick" to stack "revMenuBar" with "Copy Graphics as SVG Paths"', step)
        self.assertIn('put tourSvgChecks(the clipboardData["text"]) into tFails', step)
        self.assertIn('if tFails is not empty then throw', step)

    def test_what_it_checks(self):
        checks = handler(self.tour, 'function', 'tourSvgChecks')
        for path in ('M10,10 L110,10 L110,60 L10,60 Z', 'M130,10 L180,60 L130,60 Z', 'M200,10 L280,60'):
            self.assertIn(path, checks)
        self.assertIn('the number of lines of pSVG is not 5', checks)
        self.assertIn('word 1 of tBox > 9 or word 2 of tBox > 9', checks)

    def test_it_reads_illustrators_types_back(self):
        step = handler(self.tour, 'on', 'tour_svg_paths')
        self.assertIn('put tourSvgRawChecks(the clipboardData["text"]) after tFails', step)
        raw = handler(self.tour, 'function', 'tourSvgRawChecks')
        self.assertIn('"com.adobe.illustrator.svg,com.adobe.illustrator.svgm,com.adobe.svg"', raw)
        self.assertIn('put the keys of the rawClipboardData into tKeys', raw)
        self.assertIn('textDecode(the rawClipboardData[tType], "UTF-8")', raw)
        self.assertIn('if tText is not pSVG then', raw)
        self.assertIn('unlock the clipboard', raw)


if __name__ == '__main__':
    unittest.main()
