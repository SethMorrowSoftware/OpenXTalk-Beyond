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

"""What the review of the IDE tour's screenshots before 0.2.7-rc.6.12 found,
and the IDE tour's checks that hold it (tools/ci/ui-tour.livecodescript):

- The Script Editor's Search Results pane wrote each result in #505050 and
  #101010, colours for the light appearance, so in the dark one its lines
  were all but invisible. A patch of the binary stack
  (tools/oxt/ide-stack-patches/revscripteditor-search-results-dark-*.txt,
  mirrored in stack-scripts/) picks them by revIDEAppearanceIsDark(); the
  step script-editor-search measures the first result's contrast on the
  pane.
- On Linux and Windows the engine draws a field's selected text in the
  field's background colour (engine/src/block.cpp), and the index lists of
  Release Notes, the How-to and the Academy (the kit's fields, with none
  set) took the dark window's in the dark appearance: the selected line
  read dark on violet. The kit gives them, its inputs and its code panels
  white (lkSelectedInk); the steps release-notes, learn and academy
  measure the selected line on its hilite.
- The sparkles of the banner at the top of a How-to or Academy page sat at
  fixed parts of its width, so in a narrow window they landed on its words
  ("idea at a time", "Tom Perry"). They are not drawn on the banner's
  words or buttons (lkTextZones, lkInZones); the steps learn and academy
  look for one that is.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

TOUR = ('tools', 'ci', 'ui-tour.livecodescript')
KIT = ('ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
LEARN = ('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
ACADEMY = ('ide', 'Toolset', 'palettes', 'academy', 'revacademy.livecodescript')
RELEASE_NOTES = ('ide', 'Toolset', 'palettes', 'updates', 'revreleasenotes.livecodescript')
SE_SCRIPTS = ('stack-scripts', 'ide', 'Toolset', 'palettes', 'script editor', 'revscripteditor.8.rev.bst', 'scripts')
SE_COPIES = ('stack_revSETemplate_group_id_53759.livecodescript',
             'stack_revNewScriptEditor_1_group_id_53759.livecodescript')
PATCHES = ('tools', 'oxt', 'ide-stack-patches')


def read(parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def handler(text, kind, name):
    """The handler `name` of `text` (from its first line to its end line)."""
    m = re.search(r'^(?:private )?%s %s\b.*?^end %s\b' % (kind, re.escape(name), re.escape(name)),
                  text, re.M | re.S)
    if m is None:
        raise AssertionError('no %s %s' % (kind, name))
    return m.group(0)


class TheSearchResults(unittest.TestCase):
    """Each copy of the pane picks its colours by the appearance, and the
    light ones are those it had."""

    CHOICE = '\n'.join((
        '   local tObjectInk, tLineInk',
        '   if revIDEAppearanceIsDark() then',
        '      put "#AAAAAA" into tObjectInk',
        '      put "#E6E6E6" into tLineInk',
        '   else',
        '      put "#505050" into tObjectInk',
        '      put "#101010" into tLineInk',
        '   end if',
    ))
    LINE = ('      put "<p><font color=" & quote & tObjectInk & quote & ">" & tObjectString & "(" & '
            'item 2 of tMatch &  "): " & "</font><font color=" & quote & tLineInk & quote & ">" & '
            'tContext & "</font></p>" & return after tHtml')

    def test_each_copy_of_the_pane(self):
        for name in SE_COPIES:
            script = read(SE_SCRIPTS + (name,))
            results = handler(script, 'command', 'setResults')
            self.assertIn(self.CHOICE, results, name)
            self.assertIn(self.LINE, results, name)
            self.assertLess(results.index(self.CHOICE), results.index(self.LINE), name)
            self.assertNotIn('"#101010" & quote & ">" & tContext', results, name)

    def test_the_patches(self):
        for n, stack in ((1, 'revSETemplate'), (2, 'revNewScriptEditor 1')):
            patch = read(PATCHES + ('revscripteditor-search-results-dark-%d.txt' % n,))
            self.assertIn('file: Toolset/palettes/script editor/revscripteditor.8.rev\n', patch)
            self.assertIn('object: group "Search Results" of group "Panes" of card "Main" of stack "%s"\n' % stack,
                          patch)
            replacement = patch.split('\nwith:\n', 1)[1]
            lines = [l[1:-1] for l in replacement.splitlines() if l.startswith('|')]
            self.assertIn(self.CHOICE, '\n'.join(lines))
            self.assertIn(self.LINE, lines)

    def test_the_tour_measures_it(self):
        tour = read(TOUR)
        step = handler(tour, 'on', 'tour_script_editor_search')
        self.assertIn('put tourSearchResultsInk(tSE) into tFails', step)
        self.assertIn('if tFails is not empty then throw tFails', step)
        check = handler(tour, 'function', 'tourSearchResultsInk')
        self.assertIn('tourPixelAt(', check)
        self.assertIn('the textColor of char 1 of line 2 of field 1 of group "Search Results"', check)
        self.assertIn('the textColor of char -2 of line 2 of field 1 of group "Search Results"', check)
        self.assertIn('if tRatio < 4.5 then', check)


class TheSelectedLine(unittest.TestCase):
    """The kit's lists, inputs and code panels say what colour their
    selected text is, and the tour measures the selected line."""

    def test_the_kit(self):
        kit = read(KIT)
        ink = handler(kit, 'command', 'lkSelectedInk')
        self.assertIn('set the backgroundColor of pObj to pRGB', ink)
        self.assertIn('lkSelectedInk tObj, "255,255,255"', handler(kit, 'function', 'lkInput'))
        self.assertIn('lkSelectedInk tObj, "255,255,255"', handler(kit, 'function', 'lkCodeField'))

    def test_each_index(self):
        listed = ('   set the listBehavior of tObj to true\n'
                  '   set the autoHilite of tObj to true\n'
                  '   -- (its selected line white on the hilite, in the dark appearance too)\n'
                  '   lkSelectedInk tObj, "255,255,255"\n')
        for parts, count in ((RELEASE_NOTES, 1), (LEARN, 1), (ACADEMY, 2)):
            text = read(parts)
            self.assertEqual(text.count('set the listBehavior of tObj to true'), count, parts[-1])
            self.assertEqual(text.count(listed), count, parts[-1])

    def test_the_tour_measures_it(self):
        tour = read(TOUR)
        self.assertIn('put tourSelectedLineInk(tNew, "Release Notes") into tFails',
                      handler(tour, 'on', 'tour_release_notes'))
        self.assertIn('get tourSelectedLineInk(tWin, "the How-to")', handler(tour, 'on', 'tour_learn'))
        self.assertIn('get tourSelectedLineInk(tWin, "the Academy")', handler(tour, 'on', 'tour_academy'))
        check = handler(tour, 'function', 'tourSelectedLineInk')
        self.assertIn('the hilitedLine of field "idx"', check)
        self.assertIn('export snapshot from rect tRect', check)
        self.assertIn('tourContrast(tBestRGB, tHilite)', check)
        self.assertIn('if tRatio < 3 then', check)


class TheSparkles(unittest.TestCase):
    """A banner's sparkles are not drawn on its words or buttons."""

    def test_the_kit(self):
        kit = read(KIT)
        zones = handler(kit, 'function', 'lkTextZones')
        self.assertIn('the formattedWidth of field tName', zones)
        self.assertIn('the formattedHeight of field tName', zones)
        self.assertIn('there is a group tName and the visible of group tName', zones)
        inside = handler(kit, 'function', 'lkInZones')
        self.assertIn('pX >= item 1 of tZone - pPad and pX <= item 3 of tZone + pPad', inside)

    def test_each_banner(self):
        for parts, build, frame, fields, groups in (
                (LEARN, 'leHero', 'leHeroFrame', 'p_heroEyebrow,p_heroTitle,p_heroText,p_heroCredit',
                 'p_heroB1,p_heroB2,p_heroB3'),
                (ACADEMY, 'acHero', 'acHeroFrame', 'p_heroEyebrow,p_heroTitle,p_heroText,p_heroStats',
                 'p_heroB1,p_heroB2')):
            text = read(parts)
            hero = handler(text, 'command', build)
            zones = 'put lkTextZones(tBg, "%s", "%s") into sHero["zones"]' % (fields, groups)
            self.assertIn(zones, hero, build)
            # (after the words and buttons are laid out, before the first frame)
            self.assertLess(hero.index('set the rect of tBg to'), hero.index(zones), build)
            self.assertLess(hero.index(zones), hero.index('   %s\n' % frame), build)
            for name in fields.split(','):
                self.assertIn('lkLabel("%s"' % name, hero, build)
            self.assertIn('set the visible of graphic tObj to not lkInZones(sHero["zones"], round(tX) - item 1 of tRect, '
                          'round(tY) - item 2 of tRect, 8)', handler(text, 'command', frame), frame)

    def test_the_tour_looks(self):
        tour = read(TOUR)
        self.assertIn('get tourHeroSparklesClear(tWin, "the How-to")', handler(tour, 'on', 'tour_learn'))
        self.assertIn('get tourHeroSparklesClear(tWin, "the Academy")', handler(tour, 'on', 'tour_academy'))
        check = handler(tour, 'function', 'tourHeroSparklesClear')
        self.assertIn('repeat with tPass = 1 to 5', check)
        self.assertIn('the formattedWidth of field tName of this card', check)


if __name__ == '__main__':
    unittest.main()
