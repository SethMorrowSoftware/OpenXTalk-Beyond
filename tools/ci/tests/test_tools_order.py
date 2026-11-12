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

"""Every tile of the Tools palette has its place, the same on every disk.

The palette orders a section's tiles by each tool's "order"
(revtools.livecodescript: sort ... numeric ascending by ...["order"]). The
IDE library numbers the tools from classicToolsOrder.tsv, which up to
0.2.7 named only the 22 classic controls. The eight shapes and the three
vector tools had no number, so the sort left them as "the keys of" their
array came, and that follows the order the array was filled in: the order
the disk lists the files of the definitions' folder (the files, unsorted on
Linux).

Seen on 12 November 2026 in main's own pictures: one linux-arm64 run
showed Speech Bubble where Rectangle stands and Rectangle last, where every
other platform and the linux-arm64 runs before it showed Five Point Star,
Oval, Arrow, Ten Point Star, Rectangle, Regular Polygon, Round Rectangle,
Speech Bubble. Measured with the engine: of 3000 shuffled orders of the
definitions 2520 give that usual order and 480 the swapped one, never
another, and the three vector tools never change. A copy of the folder
that lists in a swapping order shows the swap in the real palette, in the
classic and the modern look.

The fix names the shapes and the vector tools in classicToolsOrder.tsv, in
the order the palette has always shown them, so nothing moves on a disk
that showed the usual order and a disk that swapped two shapes shows them
as everyone else does.

The IDE tour's step tools-modern-check reads the tiles row by row in both
looks and asks the library for each tool's number, on every platform's
build. An IDE whose file does not name the shapes (a release before 0.2.8)
is noted there and not checked; this test holds that the file names them,
so the step's checks run on every build of this source.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DEFINITIONS = os.path.join(REPO, 'ide', 'Toolset', 'resources', 'supporting_files', 'property_definitions')
ORDER = os.path.join(DEFINITIONS, 'classicToolsOrder.tsv')
LIBRARY = os.path.join(REPO, 'ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
PALETTE = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'tools', 'revtools.livecodescript')
TOUR = os.path.join(REPO, 'tools', 'ci', 'ui-tour.livecodescript')

PREFIX = 'com.livecode.interface.classic.'

# The classic controls, in the places they have had since OpenXTalk's file
CONTROLS = ['Button', 'Checkbox', 'DefaultButton', 'RadioButton', 'RectangleButton', 'TabPanel',
            'LabelField', 'Field', 'TextArea', 'TableField', 'ListField', 'DataGrid',
            'OptionMenu', 'PulldownMenu', 'ComboBox', 'PopupMenu',
            'Progressbar', 'Slider', 'LittleArrows', 'Scrollbar', 'Image', 'Player']
# The shapes and the vector tools, as the palette showed them on every
# platform's pictures before they had a number (row by row from the left)
SHAPES = ['FivePointStar', 'OvalGraphic', 'Arrow', 'TenPointStar',
          'RectangleGraphic', 'RegularGraphic', 'RoundRectGraphic', 'SpeechBubble']
VECTOR_TOOLS = ['CurveGraphic', 'PolygonGraphic', 'LineGraphic']

# The types of definition whose tools the palette shows, and the library's
# function that gives each to the palette
CONTROL_TYPES = ('button', 'field', 'scrollbar', 'player', 'image', 'data grid')
SHAPE_TYPE = 'graphic'
VECTOR_TYPE = 'graphic tool'


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


def definitions():
    """{name less the prefix: its type, lower case} of every definition file."""
    found = {}
    for name in sorted(os.listdir(DEFINITIONS)):
        if not (name.startswith(PREFIX) and name.endswith('.tsv')):
            continue
        kind = ''
        for line in read(os.path.join(DEFINITIONS, name)).splitlines():
            cells = line.split('\t')
            if cells[0] == 'type':
                kind = cells[1].strip().lower() if len(cells) > 1 else ''
                break
        found[name[len(PREFIX):-len('.tsv')]] = kind
    return found


def order():
    """The file's lines, each less the prefix."""
    lines = read(ORDER).split('\n')
    return [line[len(PREFIX):] if line.startswith(PREFIX) else line for line in lines]


class TheOrderFile(unittest.TestCase):

    def test_every_tool_the_palette_shows_has_a_place(self):
        shown = sorted(name for name, kind in definitions().items()
                       if kind in CONTROL_TYPES or kind in (SHAPE_TYPE, VECTOR_TYPE))
        # what this test knows of is what the folder holds: a new shape or
        # control must be given its place here and in the file
        self.assertEqual(shown, sorted(CONTROLS + SHAPES + VECTOR_TOOLS))
        placed = order()
        self.assertEqual([name for name in shown if name not in placed], [],
                         'a tool with no place stands as the disk lists its definition')

    def test_each_place_is_one_tool_with_a_definition(self):
        raw = read(ORDER)
        self.assertNotIn('\r', raw)
        lines = raw.split('\n')
        # a line that is not a tool would be numbered as one: no empty
        # line, and none after the last tool
        self.assertEqual([line for line in lines if not line.startswith(PREFIX)], [])
        placed = order()
        self.assertEqual(len(placed), len(set(placed)), 'a tool is named twice')
        known = definitions()
        self.assertEqual([name for name in placed if name not in known], [])

    def test_the_controls_keep_their_places(self):
        self.assertEqual(order()[:len(CONTROLS)], CONTROLS)

    def test_the_shapes_and_the_vector_tools_stand_as_the_palette_showed_them(self):
        placed = order()
        self.assertEqual([name for name in placed if name in SHAPES], SHAPES)
        self.assertEqual([name for name in placed if name in VECTOR_TOOLS], VECTOR_TOOLS)
        # after the controls, whose numbers do not change
        self.assertEqual(placed[len(CONTROLS):], SHAPES + VECTOR_TOOLS)


class TheLibraryAndThePalette(unittest.TestCase):
    """What turns a line of the file into a tile's place."""

    def setUp(self):
        self.library = read(LIBRARY)
        self.palette = read(PALETTE)

    def test_the_library_numbers_the_tools_from_the_file(self):
        self.assertIn('return "classicToolsOrder.tsv"', handler(self.library, '__classicToolsOrderFilename'))
        body = code(handler(self.library, '__orderClassicTools'))
        self.assertIn('__classicToolsOrderFilename()', body)
        self.assertRegex(body, r'repeat for each line tTool in tToolsToLoad\s+add 1 to tOrder\s+'
                               r'put tOrder into sClassicObjectProperties\[tTool\]\["order"\]')

    def test_each_kind_of_tool_goes_to_the_palette_with_its_number(self):
        # the whole entry is handed on, its "order" with it
        for name, kind in (('revIDEGraphics', SHAPE_TYPE), ('revIDEGraphicTools', VECTOR_TYPE)):
            body = code(handler(self.library, name))
            self.assertIn('sClassicObjectProperties[tIndex]["type"] is "%s"' % kind, body)
            self.assertIn('put sClassicObjectProperties[tIndex] into tReturnData[tIndex]', body)
        body = code(handler(self.library, 'revIDEClassicControls'))
        self.assertIn('is among the items of "%s"' % ','.join(CONTROL_TYPES), body)
        self.assertIn('put sClassicObjectProperties[tIndex] into tReturnData[tIndex]', body)

    def test_the_palette_orders_a_section_by_the_numbers(self):
        body = code(handler(self.palette, 'tmViewOrder'))
        self.assertIn('sort lines tOrder numeric ascending by pData[each]["order"]', body)
        # the classic look's own loop, the same
        self.assertIn('sort lines tOrder numeric ascending by sViewsData[tView][each]["order"]', code(self.palette))


class TheTourStep(unittest.TestCase):

    def setUp(self):
        self.tour = read(TOUR)
        self.step = code(handler(self.tour, 'tour_tools_modern_check'))

    def constant(self, name):
        m = re.search(r'^constant %s = "([^"]+)"$' % name, self.tour, re.M)
        self.assertIsNotNone(m, 'no constant ' + name)
        return m.group(1).split(',')

    def test_the_tour_knows_the_same_order(self):
        self.assertEqual(self.constant('kTmShapeOrder'), SHAPES)
        self.assertEqual(self.constant('kTmVectorOrder'), VECTOR_TOOLS)

    def test_both_looks_are_read_and_each_tool_has_its_own_number(self):
        for what in ('tourTmCheck tourTmReadingOrder("graphic") is kTmShapeOrder, \\\n'
                     '            "the classic look\'s shapes stand in their order',
                     'tourTmCheck tourTmReadingOrder("graphictools") is kTmVectorOrder, \\\n'
                     '            "the classic look\'s vector tools stand in their order',
                     'tourTmCheck tourTmReadingOrder("graphic") is kTmShapeOrder, \\\n'
                     '            "the modern look\'s shapes stand in their order',
                     'tourTmCheck tourTmOwnOrders(revIDEGraphics()), ',
                     'tourTmCheck tourTmOwnOrders(revIDEGraphicTools()), '):
            self.assertIn(what, self.step)
        # the classic look is read before the modern one is turned on
        self.assertLess(self.step.index("the classic look's shapes"), self.step.index('tourToolsModern(empty, false)'))
        self.assertLess(self.step.index('tourToolsModern(empty, false)'), self.step.index("the modern look's shapes"))

    def test_the_order_is_read_from_where_the_tiles_are(self):
        body = code(handler(self.tour, 'tourTmReadingOrder'))
        self.assertIn('tourTmGroupTiles(pView)', body)
        # by row, then from the left: not by the buttons' numbers
        self.assertIn('the top of tTile', body)
        self.assertIn('the left of tTile', body)
        self.assertNotIn('the number of', body)
        body = code(handler(self.tour, 'tourTmOwnOrders'))
        self.assertIn('if pData[tKey]["order"] is not an integer then return false', body)
        self.assertIn('if tSeen[pData[tKey]["order"]] is not empty then return false', body)
        self.assertIn('if the number of elements of pData is 0 then return false', body)

    def test_only_an_ide_whose_file_names_no_shape_is_left_unchecked(self):
        # the step's checks run when the file names the shapes, which
        # TheOrderFile holds for this source; an IDE of a release before
        # them is noted, not failed
        body = code(handler(self.tour, 'tourTmShapesPlaced'))
        self.assertIn('revIDESpecialFolderPath("Object Property Definitions") & "/classicToolsOrder.tsv"', body)
        self.assertIn('contains "%sSpeechBubble"' % PREFIX, body)
        self.assertIn('put tourTmShapesPlaced() into tPlaced', self.step)
        self.assertRegex(self.step, r'if tPlaced then\s+tourTmCheck tourTmReadingOrder\("graphic"\)')
        self.assertRegex(self.step, r'else\s+tourRecord "INFO tools-modern-check: this IDE gives the shapes no place')
        self.assertIn(PREFIX + 'SpeechBubble', read(ORDER))


if __name__ == '__main__':
    unittest.main()
