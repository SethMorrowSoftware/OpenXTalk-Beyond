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

Since 0.2.7-rc.6.12 an oval, an arc of one and a rounded rectangle are
copied as the curves the engine draws for them, not as the polygon of
their effective points (OpenXTalkPaul, p=25837; seth, 2026-11-01). The
reference below draws them as engine/src/graphicscontext.cpp does, and the
tour's step svg-curves expects its paths.

  python3 -m unittest discover -s tools/ci/tests
"""

import math
import os
import re
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

MENUBAR = ('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript')
LIBRARY = ('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
DRAWING = ('engine', 'src', 'graphicscontext.cpp')

# The graphics of the tour's step svg-curves, (name, style, rect, filled,
# startAngle, arcAngle, roundRadius), and their paths as the reference
# draws them
CURVES = (
    ('oval', 'oval', (10, 10, 110, 60), True, 0, 360, 0),
    ('round', 'roundrect', (130, 10, 230, 60), False, 0, 360, 30),
    ('arc', 'oval', (10, 80, 110, 130), False, 45, 180, 0),
    ('wedge', 'oval', (130, 80, 230, 130), True, 300, 90, 0),
)
CURVE_PATHS = (
    'M110,35 C110,21.19 87.61,10 60,10 C32.39,10 10,21.19 10,35 C10,48.81 32.39,60 60,60 '
    'C87.61,60 110,48.81 110,35 Z',
    'M215,10 C223.28,10 230,16.72 230,25 L230,45 C230,53.28 223.28,60 215,60 L145,60 '
    'C136.72,60 130,53.28 130,45 L130,25 C130,16.72 136.72,10 145,10 Z',
    'M95.36,87.32 C85.98,82.63 73.26,80 60,80 C32.39,80 10,91.19 10,105 C10,111.63 15.27,117.99 24.64,122.68',
    'M205,126.65 C220.47,122.18 230,113.93 230,105 C230,100.61 227.69,96.3 223.3,92.5 L180,105 Z',
)


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def handler(script, kind, name):
    start = script.index('\n%s %s' % (kind, name))
    return script[start:script.index('\nend %s\n' % name, start)]


def lc_round(x):
    """round(x, 2) as the engine computes it (MCMathEvalRoundToPrecision)."""
    factor = pow(10 + sys.float_info.epsilon * 6.0, 2)
    r = x * factor
    r = math.ceil(r - 0.5) if r < 0 else math.floor(r + 0.5)
    return r / factor


def lc_text(x):
    """A number as a script shows it under the default numberFormat."""
    return ('%.6f' % x).rstrip('0').rstrip('.')


def point(x, y):
    return lc_text(lc_round(x)) + ',' + lc_text(lc_round(y))


def arc_data(cx, cy, rx, ry, start, angle):
    """The engine's arc (add_legacy_arc): from start, counterclockwise from
    3 o'clock, a cubic for each part up to the next multiple of 90 degrees,
    its control points along the tangents 4/3 tan(a/4) of the radius away
    for a part of a degrees."""
    a = start % 360
    d = ' M' + point(cx + rx * math.cos(math.pi * a / 180), cy - ry * math.sin(math.pi * a / 180))
    while angle > 0:
        delta = min(90 - a % 90, angle)
        e = a + delta
        k = 4 / 3 * math.tan(math.pi * delta / 720)
        hk, vk = rx * k, ry * k
        ca, sa = math.cos(math.pi * a / 180), math.sin(math.pi * a / 180)
        cb, sb = math.cos(math.pi * e / 180), math.sin(math.pi * e / 180)
        d += (' C' + point(cx + rx * ca - hk * sa, cy - ry * sa - vk * ca) + ' ' +
              point(cx + rx * cb + hk * sb, cy - ry * sb + vk * cb) + ' ' + point(cx + rx * cb, cy - ry * sb))
        angle -= delta
        a = e
    return d


def reference_curves(style, rect, filled, start, angle, radius):
    """The path data of a graphic drawn as the engine draws it in its rect,
    or '' where the IDE writes its effective points instead."""
    left, top, right, bottom = rect
    width, height = right - left, bottom - top
    if width <= 0 or height <= 0:
        return ''
    if style == 'roundrect':
        # add_legacy_rounded_rectangle, given half the roundRadius
        if radius <= 0:
            return ''
        rx, ry = min(width, radius) / 2, min(height, radius) / 2
        k = 4 / 3 * math.tan(math.pi / 8)
        hk, vk = rx * k, ry * k
        l, r, t, b = left + rx, right - rx, top + ry, bottom - ry
        d = ' M' + point(r, top) + ' C' + point(r + hk, top) + ' ' + point(right, t - vk) + ' ' + point(right, t)
        if b > t:
            d += ' L' + point(right, b)
        d += ' C' + point(right, b + vk) + ' ' + point(r + hk, bottom) + ' ' + point(r, bottom)
        if l < r:
            d += ' L' + point(l, bottom)
        d += ' C' + point(l - hk, bottom) + ' ' + point(left, b + vk) + ' ' + point(left, b)
        if b > t:
            d += ' L' + point(left, t)
        d += ' C' + point(left, t - vk) + ' ' + point(l - hk, top) + ' ' + point(l, top) + ' Z'
        return d.strip()
    if style == 'oval':
        if angle <= 0:
            return ''
        rx, ry = width / 2, height / 2
        cx, cy = left + rx, top + ry
        d = arc_data(cx, cy, rx, ry, start, min(angle, 360))
        if angle >= 360:
            d += ' Z'
        elif filled:
            # add_legacy_segment: back to the centre
            d += ' L' + point(cx, cy) + ' Z'
        return d.strip()
    return ''


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


class TheCurves(unittest.TestCase):
    """An oval, an arc of one and a rounded rectangle as the engine draws
    them (OpenXTalkPaul, openxtalk.org p=25837; seth said yes on
    2026-11-01)."""

    def setUp(self):
        self.library = read(*LIBRARY)

    def test_the_curves_before_the_points(self):
        path = handler(self.library, 'private function', '__revOXTIDEGraphicToSVGPath')
        curves = path.index('put __revOXTIDESVGCurves(pGraphic) into tData')
        self.assertLess(curves, path.index('if tData is empty then'))
        self.assertLess(curves, path.index('the effective points of pGraphic'))

    def test_the_engines_geometry(self):
        curves = handler(self.library, 'private function', '__revOXTIDESVGCurves')
        self.assertIn('if tStyle is not among the items of "oval,roundrect" then return empty', curves)
        # the box is the rect, as a rectangle's path is
        self.assertIn('put item 3 of tRect - item 1 of tRect into tWidth', curves)
        # a rounded rectangle's corners: half the roundRadius
        self.assertIn('put min(tWidth, tRadius) / 2 into tRX', curves)
        self.assertIn('put min(tHeight, tRadius) / 2 into tRY', curves)
        self.assertIn('put 4 / 3 * tan(pi / 8) into tK', curves)
        # a filled arc goes back to the centre
        self.assertIn('put " L" & __revOXTIDESVGPoint(tCX, tCY) & " Z" after tData', curves)
        arc = handler(self.library, 'private function', '__revOXTIDESVGArc')
        self.assertIn('put min(90 - tFrom mod 90, pAngle) into tDelta', arc)
        self.assertIn('put 4 / 3 * tan(pi * tDelta / 720) into tK', arc)
        number = handler(self.library, 'private function', '__revOXTIDESVGPoint')
        self.assertIn('return round(pX, 2) & "," & round(pY, 2)', number)

    def test_the_engine_draws_them_so(self):
        # what the reference copies; if the drawing changes, so must both
        drawing = read(*DRAWING)
        self.assertIn('add_legacy_rounded_rectangle(m_gcontext, t_rect, radius * 0.5);', drawing)
        self.assertIn('t_delta = MCU_min(90 - p_start % 90, p_angle);', drawing)
        self.assertIn('double h = tan(M_PI * (e - s) / 720.0);', drawing)
        segment = drawing[drawing.index('static void add_legacy_segment('):]
        self.assertIn('add_legacy_line_to(p_gcontext, cx, cy);', segment[:segment.index('\n}\n')])

    def test_the_reference(self):
        # a circle of radius 10 at 20,20: its four quarters
        k = lc_text(lc_round(10 * 4 / 3 * math.tan(math.pi / 8)))
        self.assertEqual(k, '5.52')
        self.assertEqual(reference_curves('oval', (10, 10, 30, 30), False, 0, 360, 0),
                         'M30,20 C30,14.48 25.52,10 20,10 C14.48,10 10,14.48 10,20 '
                         'C10,25.52 14.48,30 20,30 C25.52,30 30,25.52 30,20 Z')
        # a quarter from 3 o'clock up, open; filled, a wedge
        self.assertEqual(reference_curves('oval', (10, 10, 30, 30), False, 0, 90, 0),
                         'M30,20 C30,14.48 25.52,10 20,10')
        self.assertEqual(reference_curves('oval', (10, 10, 30, 30), True, 0, 90, 0),
                         'M30,20 C30,14.48 25.52,10 20,10 L20,20 Z')
        # what the IDE leaves to the effective points
        self.assertEqual(reference_curves('oval', (10, 10, 30, 30), False, 0, 0, 0), '')
        self.assertEqual(reference_curves('roundrect', (10, 10, 30, 30), False, 0, 0, 0), '')
        self.assertEqual(reference_curves('oval', (10, 10, 10, 30), False, 0, 360, 0), '')
        self.assertEqual(reference_curves('rectangle', (10, 10, 30, 30), False, 0, 0, 0), '')

    def test_the_paths_the_tour_expects(self):
        for graphic, path in zip(CURVES, CURVE_PATHS):
            with self.subTest(graphic=graphic[0]):
                self.assertEqual(reference_curves(*graphic[1:]), path)


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

    def test_the_curves_step(self):
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertEqual(steps[steps.index('svg-paths') + 1], 'svg-curves')
        step = handler(self.tour, 'on', 'tour_svg_curves')
        self.assertIn('dispatch "revMenubarObjectMenuPick" to stack "revMenuBar" with "Copy Graphics as SVG Paths"', step)
        self.assertIn('put tourSvgCurveChecks(the clipboardData["text"]) into tFails', step)
        self.assertIn('tourShotStack tName, "04g-svg-curves"', step)
        self.assertIn('if tFails is not empty then throw', step)
        # the graphics the reference draws
        for name, style, rect, filled, start, angle, radius in CURVES:
            with self.subTest(graphic=name):
                self.assertIn('tourSvgGraphic("%s", "%s", "%s"' % (name, style, ','.join(map(str, rect))), step)
                if start:
                    self.assertIn('set the startAngle of t%s to %d' % (name.title(), start), step)
                if style == 'oval' and angle != 360:
                    self.assertIn('set the arcAngle of t%s to %d' % (name.title(), angle), step)
                if radius:
                    self.assertIn('set the roundRadius of t%s to %d' % (name.title(), radius), step)
        checks = handler(self.tour, 'function', 'tourSvgCurveChecks')
        # a literal continued on the next line ("..." & \ "...") read whole
        joined = re.sub(r'"\s*&\s*\\\n\s*"', '', checks)
        for path in CURVE_PATHS:
            self.assertIn('tourSvgPathLine("%s"' % path, joined)
        self.assertIn('the number of lines of pSVG is not 6', checks)
        self.assertIn('"viewBox=" & quote & "9 9 222 122" & quote', checks)

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
