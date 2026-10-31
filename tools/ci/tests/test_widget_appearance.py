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

"""Widgets whose colours nobody set by hand follow light and dark (seth's
choice 2A of 2026-10-31; bwmilby, openxtalk.org p=25665, p=25680). The IDE
gives a new header bar, navigation bar, segmented control, switch button or
tree view its metadata's light defaults as colours of its own, so in the
dark appearance they stayed light grey on a dark card. Now each draws a
colour that is still its light default in the dark one, in the dark
appearance on a dark card only (MCWidgetGetMyPaintForAppearance in
widget-syntax.cpp); a colour set to anything else is drawn as set, the
properties read what they did, and the light appearance is drawn as before.

The IDE tour checks it on the screen (tools/ci/ui-tour.livecodescript, the
step widget-appearance, and on a Mac after each live switch in
system-switch), and the segmented control's own tests that the light
appearance is drawn as before (extensions/widgets/segmented/tests/
colors.livecodescript). These tests hold the pieces to each other.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

WIDGETS = ('header', 'navbar', 'segmented', 'switchbutton', 'treeview')

# 'my ... paint' numbers the colours as MCWidgetGetMyPaint does
PAINTS = {'foreground': ('0', 'Fore', 'foregroundColor'),
          'background': ('1', 'Back', 'backgroundColor'),
          'border': ('3', 'Border', 'borderColor')}


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def between(text, start, end):
    i = text.index(start)
    return text[i:text.index(end, i + len(start))]


def handler(script, kind, name):
    start = script.index('\n%s %s' % (kind, name))
    return script[start:script.index('\nend %s\n' % name, start)]


def rgb(text):
    return tuple(int(x) for x in re.split(r'\s*,\s*', text.strip()))


def luma(colour):
    r, g, b = colour
    return (299 * r + 587 * g + 114 * b) / 1000


class TheEngine(unittest.TestCase):
    """widget-syntax.cpp: the light default is swapped for the dark only in
    the dark appearance, behind which the card is drawn dark, and only for a
    colour of the widget's own."""

    def setUp(self):
        self.syntax = read('engine', 'src', 'widget-syntax.cpp')
        self.call = between(self.syntax,
                            'extern "C" MC_DLLEXPORT_DEF void MCWidgetGetMyPaintForAppearance(', '\n}\n')

    def test_the_call_is_exported_and_declared(self):
        self.assertIn('extern "C" MC_DLLEXPORT_DEF void MCWidgetGetMyPaintForAppearance(uinteger_t p_type, '
                      'MCCanvasColorRef p_light, MCCanvasColorRef p_dark, MCCanvasPaintRef& r_paint)', self.syntax)
        lcb = read('engine', 'src', 'widget.lcb')
        self.assertIn('public foreign handler MCWidgetGetMyPaintForAppearance(in pPaintType as CUInt, '
                      'in pLight as Color, in pDark as Color, out rPaint as Paint) returns nothing '
                      'binds to "<builtin>"', lcb)

    def test_only_a_colour_of_its_own_still_the_light_default(self):
        self.assertIn('t_host -> getcindex((uint2)p_type, t_index) && MCWidgetIsInDarkAppearance(t_host)', self.call)
        self.assertIn('MCWidgetColorIsCanvasColor(t_color, p_light)', self.call)
        self.assertIn('MCCanvasSolidPaintMakeWithColor(p_dark,', self.call)
        # anything else is 'my ... paint', as before
        self.assertTrue(self.call.rstrip().endswith('MCWidgetGetMyPaint(p_type, r_paint);'), self.call[-200:])

    def test_only_in_the_dark_appearance_on_a_dark_card(self):
        dark = between(self.syntax, 'static bool MCWidgetIsInDarkAppearance(', '\n}\n')
        self.assertIn('if (t_appearance != kMCSystemAppearanceDark)\n        return false;', dark)
        self.assertIn('t_back -> getforecolor(DI_BACK,', dark)
        self.assertIn('return t_luma < 32768;', dark)


class TheWidgets(unittest.TestCase):
    """Each of the five draws its colours through paintFor, whose light
    colours are its metadata's defaults (what the IDE gives a new one), and
    whose dark ones put a dark background under lighter labels and
    border."""

    def test_every_colour_goes_through_the_appearance(self):
        for name in WIDGETS:
            with self.subTest(widget=name):
                source = read('extensions', 'widgets', name, name + '.lcb')
                for paint in PAINTS:
                    self.assertNotIn('my %s paint' % paint, source)
                self.assertIn('MCWidgetGetMyPaintForAppearance(pType,', source)
                for paint, (number, short, _prop) in PAINTS.items():
                    for call in re.findall(r'paintFor\((\d), k%sLight, k%sDark\)' % (short, short), source):
                        self.assertEqual(call, number, '%s: paintFor(%s, k%sLight...)' % (name, call, short))
                calls = re.findall(r'paintFor\((\d), k(\w+?)Light, k(\w+?)Dark\)', source)
                self.assertTrue(calls, name)
                for number, light, dark in calls:
                    self.assertEqual(light, dark, name)

    def test_the_light_colours_are_the_metadatas_defaults(self):
        for name in WIDGETS:
            source = read('extensions', 'widgets', name, name + '.lcb')
            colours = {}
            for paint, (_number, short, prop) in PAINTS.items():
                light = re.search(r'^constant k%sLight is \[([^\]]+)\]' % short, source, re.M)
                dark = re.search(r'^constant k%sDark is \[([^\]]+)\]' % short, source, re.M)
                default = re.search(r'^metadata %s\.default is "([^"]*)"' % prop, source, re.M)
                used = ('k%sLight' % short) in source.replace('constant k%sLight' % short, '')
                with self.subTest(widget=name, colour=prop):
                    if not used:
                        self.assertIsNone(light)
                        continue
                    self.assertIsNotNone(default, 'no %s default' % prop)
                    self.assertIsNotNone(dark, 'no k%sDark' % short)
                    self.assertEqual(rgb(light.group(1)), rgb(default.group(1)))
                    colours[short] = (luma(rgb(light.group(1))), luma(rgb(dark.group(1))))
            # the background light in the light and dark in the dark, and
            # the labels and the border on it the other way round in each,
            # so that they show on it in both
            with self.subTest(widget=name):
                back_light, back_dark = colours['Back']
                self.assertGreaterEqual(back_light, 128)
                self.assertLess(back_dark, 128)
                for short in ('Fore', 'Border'):
                    if short in colours:
                        on_light, on_dark = colours[short]
                        self.assertLess(on_light, back_light, '%s k%sLight' % (name, short))
                        self.assertGreater(on_dark, back_dark + 16, '%s k%sDark' % (name, short))

    def test_the_backgrounds_the_tour_checks(self):
        source = read('extensions', 'widgets', 'segmented', 'segmented.lcb')
        self.assertIn('constant kBackLight is [244, 244, 244]', source)
        self.assertIn('constant kBackDark is [64, 64, 64]', source)


class TheChecks(unittest.TestCase):
    """The tour reads the screen in light and dark, and after each of the
    Mac's live switches; the segmented control's tests read a snapshot."""

    def setUp(self):
        self.tour = read('tools', 'ci', 'ui-tour.livecodescript')

    def test_the_step(self):
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertIn('widget-appearance', steps)
        step = handler(self.tour, 'on', 'tour_widget_appearance')
        self.assertIn('tourSegmentsCheck(tName, tMade, "244,244,244", "64,64,64",', step)
        self.assertIn('tourSegmentsCheck(tName, tHand, "200,120,40", "200,120,40",', step)
        self.assertIn('tourSegmentsProperties(tMade,', step)
        # in the Mac's dark tour the dark colours are what is checked
        self.assertIn('if the platform is "MacOS" and $OXT_TOUR_APPEARANCE is "dark" and not sSegmentsDark then', step)
        self.assertIn('if tFails is not empty then throw', step)

    def test_made_as_the_ide_makes_one(self):
        make = handler(self.tour, 'function', 'tourSegmentsMake')
        self.assertIn('revIDECreateObject "com.livecode.widget.segmented"', make)
        props = handler(self.tour, 'function', 'tourSegmentsProperties')
        self.assertIn('"0,0,0/244,244,244/109,109,109"', props)

    def test_what_it_reads(self):
        check = handler(self.tour, 'function', 'tourSegmentsCheck')
        self.assertIn('the systemAppearance is "dark" and tourSystemLight(tCard) is false into sSegmentsDark', check)
        self.assertIn('if abs(item i of tShown - item i of tWant) > 16 then', check)
        self.assertEqual(self.tour.count('\nlocal sSegmentsDark\n'), 1)
        self.assertLess(self.tour.index('\nlocal sSegmentsDark\n'), self.tour.index('\non tour_widget_appearance\n'))

    def test_after_every_switch(self):
        step = handler(self.tour, 'on', 'tour_system_switch')
        loop = between(step, 'repeat for each item tTarget in tOther & comma & tStart', 'end repeat\n      if')
        self.assertIn('tourSegmentsCheck(tColorsStack, tSegments, "244,244,244", "64,64,64",', loop)
        self.assertIn('if sSegmentsDark is not (tTarget is "dark") then', loop)
        self.assertIn('put tourSegmentsMake(tColorsStack, "Segments", "10,10,310,50") into tSegments', step)

    def test_the_widgets_own_test(self):
        test = read('extensions', 'widgets', 'segmented', 'tests', 'colors.livecodescript')
        body = handler(test, 'on', 'TestDefaultColorsAndTheAppearance')
        self.assertIn('set the backgroundColor of card 1 of stack tStack to "30,30,30"', body)
        self.assertIn('_SegmentPixel(tStack, tWidget) is "244,244,244"', body)
        self.assertIn('_SegmentPixel(tStack, tWidget) is "64,64,64"', body)
        self.assertIn('_SegmentPixel(tStack, tWidget) is "200,120,40"', body)


if __name__ == '__main__':
    unittest.main()
