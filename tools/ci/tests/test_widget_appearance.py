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



class TheIconPicker(unittest.TestCase):
    """The icon picker (the Inspector's SVG icon chooser) has no colour
    properties of its own: its getPaint gave black icons and names on a
    dark Inspector in the dark appearance (bwmilby, openxtalk.org p=26194).
    In the dark appearance on a dark card, as the engine decides it for the
    other widgets, it now draws its dark colours; in the light appearance
    every colour is the one it drew before."""

    LIGHT = {('background', 'popup'): 'stringToColor("255,255,255,128")',
             ('icon', 'selected'): 'stringToColor("0,150,150")',
             ('icon', 'fill'): 'color kIconColor',
             ('scrollbar', 'fill'): 'stringToColor("0,0,0,50")',
             ('frame', 'stroke'): 'stringToColor("188,188,188")'}

    def setUp(self):
        self.source = read('extensions', 'widgets', 'iconpicker', 'iconpicker.lcb')
        self.get = between(self.source, 'private handler getPaint(pLocation, pType) returns Paint', '\nend handler\n')

    def test_the_engine_says_whether_it_is_dark(self):
        syntax = read('engine', 'src', 'widget-syntax.cpp')
        call = between(syntax, 'extern "C" MC_DLLEXPORT_DEF void MCWidgetGetMyAppearanceIsDark(bool& r_dark)', '\n}\n')
        # the same decision as MCWidgetGetMyPaintForAppearance's, false
        # when there is no widget
        self.assertIn('r_dark = false;', call)
        self.assertIn('r_dark = MCWidgetIsInDarkAppearance(MCWidgetGetHost(MCcurrentwidget));', call)
        self.assertLess(syntax.index('static bool MCWidgetIsInDarkAppearance('),
                        syntax.index('MCWidgetGetMyAppearanceIsDark('))
        self.assertIn('public foreign handler MCWidgetGetMyAppearanceIsDark(out rDark as CBool) returns nothing '
                      'binds to "<builtin>"', read('engine', 'src', 'widget.lcb'))

    def test_every_colour_comes_from_getpaint(self):
        self.assertIn('constant kIconColor is [0,0,0]', self.source)
        body = self.source.replace(self.get, '')
        self.assertNotIn('color kIconColor', body)
        self.assertNotIn('stringToColor(', body)
        self.assertEqual(body.count('getPaint("icon", "fill")'), 3)
        self.assertIn('MCWidgetGetMyAppearanceIsDark(tDark)', self.source)

    def test_the_light_colours_are_as_before(self):
        # each colour's light return is the one before the change, and the
        # only return after its dark one
        for (location, kind), light in self.LIGHT.items():
            with self.subTest(location=location, kind=kind):
                start = self.get.index('pLocation is "%s"' % location)
                part = self.get[start:]
                part = part[part.index('pType is "%s"' % kind):]
                ret = part.index('return solid paint with %s' % light)
                self.assertNotIn('else if pType', part[:ret])
                before = part[:ret]
                if 'if tDark then' in before:
                    self.assertIn('end if', before[before.index('if tDark then'):])
        self.assertTrue(self.get.rstrip().endswith('return solid paint with stringToColor("255,100,200")'))

    def test_the_dark_colours_show_on_a_dark_card(self):
        icon = rgb(re.search(r'^constant kDarkIconColor is \[([^\]]+)\]', self.source, re.M).group(1).replace('0.86', '219'))
        self.assertGreater(luma(icon), 180)
        frame = rgb(re.search(r'^constant kDarkFrame is "([^"]+)"', self.source, re.M).group(1))
        self.assertGreater(luma(frame), 64)
        self.assertLess(luma(frame), 128)
        self.assertIn('constant kDarkIconColor is [0.86, 0.86, 0.86]', self.source)

    def test_the_tour_reads_the_screen(self):
        tour = read('tools', 'ci', 'ui-tour.livecodescript')
        steps = re.search(r'^constant kSteps = "([^"]+)"', tour, re.M).group(1).split(',')
        self.assertEqual(steps.index('icon-picker'), steps.index('widget-appearance') + 1)
        step = handler(tour, 'on', 'tour_icon_picker')
        self.assertIn('create widget "Picker" as "com.livecode.widget.iconpicker"', step)
        self.assertIn('the systemAppearance is "dark" and tourSystemLight(tCard) is false into tDark', step)
        self.assertIn('if item 2 of tShown < 20 then', step)
        self.assertIn('if item 1 of tShown < 20 then', step)
        self.assertIn('if tFails is not empty then throw', step)
        shown = handler(tour, 'function', 'tourPickerShown')
        self.assertIn('abs(tR - 219) <= 16', shown)

    def test_the_widgets_own_test(self):
        test = read('extensions', 'widgets', 'iconpicker', 'tests', 'colors.livecodescript')
        body = handler(test, 'on', 'TestFrameAndTheAppearance')
        self.assertIn('set the backgroundColor of card 1 of stack tStack to "30,30,30"', body)
        self.assertIn('_PickerFramePixel(tWidget) is "96,96,96"', body)
        self.assertEqual(body.count('_PickerFramePixel(tWidget) is "188,188,188"'), 2)


class TheIconChooser(unittest.TestCase):
    """The Inspector's SVG icon chooser on Linux with a dark GTK theme: the
    systemAppearance is light there (unless Preferences > Appearance follows
    the desktop), so the widget drew black icons on the dark card. The IDE,
    which reads the desktop as dark (revIDEAppearanceIsDark), sets the
    widget's darkIcons there, and only there: wherever the systemAppearance
    is dark the widget decides for itself, and in the light darkIcons is
    false, the default, so macOS and Windows draw what they did. The tour's
    icon-picker step reads the chooser on the screen, deciding by the card
    as drawn, not by the systemAppearance."""

    def setUp(self):
        self.behavior = read('ide', 'Toolset', 'palettes', 'inspector', 'editors',
                             'com.livecode.pi.svgiconfilter.behavior.livecodescript')
        self.source = read('extensions', 'widgets', 'iconpicker', 'iconpicker.lcb')

    def test_the_chooser_follows_the_ides_appearance(self):
        opening = handler(self.behavior, 'on', 'preOpenStack')
        self.assertIn('svgIconFilterShowAppearance', opening)
        self.assertLess(opening.index('set the selectedIcon'), opening.index('svgIconFilterShowAppearance'))
        show = handler(self.behavior, 'command', 'svgIconFilterShowAppearance')
        self.assertIn('set the darkIcons of widget "iconList" of me to \\\n'
                      '         svgIconFilterNeedsDark(revIDEAppearanceIsDark(), the systemAppearance)', show)

    def test_only_where_the_widget_would_draw_black_on_dark(self):
        needs = handler(self.behavior, 'function', 'svgIconFilterNeedsDark')
        self.assertIn('return pDesktopDark is true and pAppearance is not "dark"', needs)

    def test_dark_icons_is_off_unless_set(self):
        # false on a new widget and on one loaded from a stack (it is not
        # saved), so every widget the IDE does not ask is drawn as before
        self.assertIn('private variable mDarkIcons as Boolean', self.source)
        self.assertIn('property darkIcons get mDarkIcons set setDarkIcons', self.source)
        self.assertIn('metadata darkIcons.user_visible is "false"', self.source)
        for name in ('OnCreate()', 'OnLoad(in pProperties as Array)'):
            body = between(self.source, 'public handler %s' % name, '\nend handler\n')
            self.assertIn('put false into mDarkIcons', body)
        save = between(self.source, 'public handler OnSave(out rProperties as Array)', '\nend handler\n')
        self.assertNotIn('ark', save)

    def test_dark_icons_only_adds_to_the_engines_decision(self):
        dark = between(self.source, 'private handler isDarkAppearance() returns Boolean', '\nend handler\n')
        self.assertLess(dark.index('if mDarkIcons then'), dark.index('MCWidgetGetMyAppearanceIsDark(tDark)'))
        self.assertIn('return tDark', dark)
        setter = between(self.source, 'public handler setDarkIcons(in pDark as Boolean)', '\nend handler\n')
        self.assertIn('redraw all', setter)

    def test_the_tour_decides_by_the_card(self):
        tour = read('tools', 'ci', 'ui-tour.livecodescript')
        step = handler(tour, 'on', 'tour_icon_picker')
        self.assertIn('put tourIconChooserFails() after tFails', step)
        self.assertLess(step.index('put tourIconChooserFails() after tFails'),
                        step.index('if tFails is not empty then throw'))
        check = handler(tour, 'function', 'tourIconChooserFails')
        self.assertIn('set the behavior of stack tChooser to the long id of stack (tChooser & ".behavior")', check)
        self.assertIn('put tourCardPixel(tChooser) into tCard', check)
        self.assertIn('else if tourSystemLight(tCard) then', check)
        self.assertIn('else if item 2 of tShown < 20 or item 1 of tShown > item 2 of tShown then', check)
        # the decision reads the card only: the systemAppearance is recorded,
        # never tested
        decision = check[check.index('if tourSystemLight(tCard) is empty then'):check.index('tourShotStack')]
        self.assertNotIn('systemAppearance', decision)
        self.assertIn('set the dialogData to tData', check)
        self.assertIn('close stack tChooser', check)
        self.assertIn('is within the rect of control i of card 1 of stack pStack',
                      handler(tour, 'function', 'tourCardPixel'))

    def test_the_card_between_the_icons_is_not_counted(self):
        # the widget paints no background, so between its icons is the card,
        # and Windows draws a dark card 32,32,32: "black" by the count's 40.
        # Its light icons were 6761 light grey pixels among 74897 "black"
        # ones, every one of them the card, and the step failed there (#435's
        # Windows build, run 42704404828). The chooser's count is given the
        # card, and leaves out what is within a few of it
        tour = read('tools', 'ci', 'ui-tour.livecodescript')
        check = handler(tour, 'function', 'tourIconChooserFails')
        self.assertIn('put tourPickerShown(tChooser, tPicker, tCard) into tShown', check)
        self.assertLess(check.index('put tourCardPixel(tChooser) into tCard'),
                        check.index('put tourPickerShown(tChooser, tPicker, tCard) into tShown'))
        # the widget alone, on the tour's own stack, is counted as it was
        self.assertIn('put tourPickerShown(tName, tPicker) into tShown', handler(tour, 'on', 'tour_icon_picker'))
        count = handler(tour, 'function', 'tourPickerShown')
        self.assertTrue(count.startswith('\nfunction tourPickerShown pStack, pWidget, pCard\n'))
        near = re.search(r'\n      if abs\(tR - tCardR\) <= (\d+) and abs\(tG - tCardG\) <= (\d+) and '
                         r'abs\(tB - tCardB\) <= (\d+) then\n         next repeat\n'
                         r'      else if tR <= (\d+) and tG <= (\d+) and tB <= (\d+) then\n         add 1 to tBlack\n'
                         r'      else if abs\(tR - (\d+)\) <= (\d+) and abs\(tG - (\d+)\) <= (\d+) and '
                         r'abs\(tB - (\d+)\) <= (\d+) then\n         add 1 to tLight\n', count)
        self.assertIsNotNone(near, 'the count no longer reads as this test models it')
        numbers = [int(n) for n in near.groups()]
        self.assertEqual(len(set(numbers[0:3])), 1)
        self.assertEqual(len(set(numbers[3:6])), 1)
        self.assertEqual(len(set(numbers[6::2])), 1)
        self.assertEqual(len(set(numbers[7::2])), 1)
        tolerance, black, grey, spread = numbers[0], numbers[3], numbers[6], numbers[7]
        # with no card given, no pixel is near it
        nocard = re.search(r'put (-?\d+) into tCardR\n   put (-?\d+) into tCardG\n   put (-?\d+) into tCardB\n'
                           r'   if the number of items of pCard is 3 then\n', count)
        self.assertIsNotNone(nocard)
        for value in nocard.groups():
            self.assertLess(int(value) + tolerance, 0)

        def shown(pixels, card=None):
            blacks = lights = 0
            for colour, many in pixels:
                if card is not None and all(abs(c - k) <= tolerance for c, k in zip(colour, card)):
                    continue
                if all(c <= black for c in colour):
                    blacks += many
                elif all(abs(c - grey) <= spread for c in colour):
                    lights += many
            return blacks, lights

        def fails_on_a_dark_card(counts):
            # tourIconChooserFails: item 2 of tShown < 20 or item 1 of tShown > item 2 of tShown
            return counts[1] < 20 or counts[0] > counts[1]

        windows = (32, 32, 32)
        light_icons = [(windows, 74897), ((219, 219, 219), 6761)]
        # as it was counted, the card was black: the failure of the Windows build
        self.assertEqual(shown(light_icons), (74897, 6761))
        self.assertTrue(fails_on_a_dark_card(shown(light_icons)))
        # given the card, light icons on Windows' dark card pass
        self.assertEqual(shown(light_icons, windows), (0, 6761))
        self.assertFalse(fails_on_a_dark_card(shown(light_icons, windows)))
        # and black icons on that card are still black, and still fail
        black_icons = [(windows, 74897), ((0, 0, 0), 6761)]
        self.assertEqual(shown(black_icons, windows), (6761, 0))
        self.assertTrue(fails_on_a_dark_card(shown(black_icons, windows)))
        # Linux's dark card is not black by the count, and its black icons
        # (main 2f3775dc: 9783 black, 2 light grey) fail as they did
        linux = (51, 57, 59)
        self.assertEqual(shown([(linux, 70000), ((0, 0, 0), 9783), ((219, 219, 219), 2)], linux), (9783, 2))
        self.assertTrue(fails_on_a_dark_card(shown([(linux, 70000), ((0, 0, 0), 9783), ((219, 219, 219), 2)], linux)))
        # a card is never mistaken for the icons' black or their light grey
        self.assertGreater(black - tolerance, 0)
        self.assertGreater(grey - spread - tolerance, black)


if __name__ == '__main__':
    unittest.main()
