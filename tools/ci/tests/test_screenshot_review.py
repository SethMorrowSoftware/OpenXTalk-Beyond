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
- The icons of the Standalone Settings' Inclusions card took the engine's
  colour, which on Linux is the GTK theme's: white with a dark theme, on
  the rows the IDE draws light and white. They take the colour of the
  row's name (revIDEColor "text_1"); the step standalone-settings measures
  each icon on its row.
- Preferences' Automatic Updates pane showed OpenXTalk Lite's notes of its
  own last update as the "Summary of last update" (from
  Toolset/palettes/updates/whatsnew.txt, "respring implemented for
  updater"). The package no longer carries the file, so the pane shows no
  summary, as it already did on the Mac; the step preferences looks for
  one.
- Search and Replace cut off "cards only" ("card" on Linux, "cards o" on
  the Mac): its check box reached past its group "Options", which ended
  at 253. A patch of the binary stack widens the group to 318
  (revsearch-cards-only-width.txt); the step search measures every check
  box against its rect and its group's, and clicks one under the widened
  group.
- On Linux the IDE is drawn in the desktop's sans font, DejaVu Sans on
  Ubuntu (13 pixels), wider than the fonts of the Mac and Windows the
  windows were laid out in. In Preferences 31 check boxes, buttons and
  labels were cut off or ran into the next control ("...click edits
  scrip", "Display tool tips after" under its field, "Sort controls" for
  "Sort controls by:"), and the colour scheme menu's arrow ran over
  "Follow System Appearance"; in Search and Replace "Remove from Lis" and
  three more. Property patches of the binary stacks
  (revpreferencesgui-fit-*.txt, revsearch-fit-linux.txt, and the colour
  scheme menu's rect in revpreferencesgui-follow-appearance-width.txt)
  give each the room its words need in DejaVu Sans. The steps preferences
  (each pane) and search measure every check box, radio button, push
  button, option menu and label: against its rect, its groups and the
  window, and the next control on its line. Run on the released rc.6.11
  IDE with DejaVu Sans they fail on all of these (30 in Preferences); with
  the patched stacks they pass, light and dark.
- The same check of the Standalone Settings, card by card (the step
  standalone-settings), found seven more: "the profile librar" and "Only
  include profiles selected" on the General card, "Android armv",
  "Visibl", "Write External Storag" and "In App Purchasing" run into its
  check box on the Android card, and "save report to fil" on Bug Reports.
  standalone-settings-fit-linux.txt gives each its room. A label's words
  are measured where the engine lays them out (tourWordsRect, the
  formattedRect of its text less the spaces at its end), and a label
  beside them by where its own words start, so a version number's dots
  one point clear of the next box, or "Required" over "Used", are not
  taken for words cut off; a field with a border is a box that shows a
  value, such as a path, and is left out.
- On Windows the line under each Preferences pane that says where the
  preferences are saved ran off the window's edge: the path has the
  user's name in it (on GitHub's Windows machine its words needed 473
  pixels of 423). Folders in its middle give way to "..." until it fits,
  and its tooltip holds the whole path
  (revpreferencesgui-prefs-path-fits.txt); the step preferences tries a
  long path on every platform.
- On Windows' dark mode three disabled check boxes were drawn as if
  enabled, bold and white, beside disabled ones drawn grey: Preferences'
  "Show classic Start Center" and "Load Start Center when last user stack
  is closed" (both 223 from the window, as the enabled ones, where "Load
  Start Center on start-up" was 112) and Standalone Settings' "Rename
  stackfiles generically". Each had a background colour or pattern saved
  on it, never painted as it is not opaque, which made the engine keep
  the etched label of the Windows look for it
  (MCButtonDisabledInkOnDarkTheme keeps it for a button with a background
  of its own). Property patches clear them
  (revpreferencesgui-start-center-disabled-labels.txt,
  revstandalonesettings-rename-files-disabled-label.txt); the steps
  preferences and standalone-settings measure the words of every check
  box and radio button that shows (tourLabelInks): a disabled one's are
  no more than 0.7 of the enabled ones' median, and 24 or more. On the
  released rc.6.11 IDE with a dark Linux theme every disabled one fails
  (17, the engine's etched label then), light passes.
- On the Apple silicon Mac's screen, 1024 by 768, OXT-Beyond Home is as
  wide as the screen and cannot move clear of the Tools palette, which
  floats over its sidebar: the step academy read the palette's grey
  (88,88,88) for the selected index line's words, in the Mac's dark
  appearance. A check that reads a window's pixels off the screen hides
  the palette while it does when the palette is over what it reads
  (tourToolsAside, tourToolsBack): the selected index line and the words
  of the check boxes. The snapshots a person looks through keep it.
- On Linux the toolbar cut "Select Grouped" off at its "S" when it was
  on (the review of the rc.6.12 pull request's tour, the dark appearance):
  a lit button's label is bold (setButtonHilite, and any button's while it
  is pressed), and revMenubarButtonFormattedWidth measured the labels
  plain. Eight of the eleven buttons were narrower than their bold words
  in DejaVu Sans ("Select Grouped" 107 of 120, "Messages" 72 of 81). Each
  label is measured plain and bold; the step menubar-modern measures every
  button's labels bold, in both looks. On the released rc.6.11 IDE it
  fails on all eight; with the change it passes, and the toolbar is 999
  pixels wide on Linux, where it was 922.
- On Linux the colour scheme menu of Preferences' Script Editor pane
  still had its arrow over the last "e" of "Follow System Appearance" in
  its 204 pixels (the same review): the engine puts an option menu's words
  in its middle, as a push button's, and GTK draws the arrow over the right
  of the menu, from 22 to 13 pixels before its right on Ubuntu's theme.
  The tour's check took the engine's own allowance for the arrow, 202 in
  all, which assumes the words leave the arrow's room free. The menu is 212
  pixels wide with its words at its left
  (revpreferencesgui-follow-appearance-width.txt). On Linux the step
  preferences measures where the words of every option menu end, by their
  advance, against the arrow (tourMenuWordsClear, 20 pixels: the arrow's 22
  less the 2 by which the words' ink stops short of their advance), and
  each of the colour scheme menu's choices. On the released rc.6.11 IDE
  with the rc.6.12 stack it fails on this menu alone (its words end at 644,
  the arrow's room starts at 638); with the change it passes (635 of 646).
- On Linux the xTalk Assistant's Settings cut a row of pixels off the
  capitals of each note's first line ("Paste your Anthropic API key
  here", "0 to 10: tries..."). The engine starts a label's words 6 points
  above its top margin, so the notes' margin of 4 put their words 2
  points above the notes, and in GitHub's Ubuntu machine's rendering the
  capitals' tops fell there. Their top margin is 6, and the three beside
  a box sit at its row's top, so their words are where they were. Every
  label the step xtalk-assistant finds in the Settings and Memory
  windows, and the steps preferences, standalone-settings and search,
  must have its words start no higher than its top (tourFieldsWhole), and
  a field whose border is 0 wide counts as a label, as the assistant's
  are. On the released rc.6.11 IDE the step fails on the six notes (their
  words at 158 in a note at 160); with the change it passes, and
  Preferences, Standalone Settings and Search fail on nothing new.
- The icon chooser's Image library menu read black on dark grey in the
  dark appearance on Windows and Linux: OpenXTalk Lite 1.15 saved it with
  black words, and those platforms draw an option menu's box in the
  theme's colours and its words in the button's. A patch of the binary
  stack (light-icon-chooser-menu.txt) clears the words' colour, so they
  take the theme's. The step icon-chooser measures the menu's words on its
  box (tourMenuWordsInk, 96 or more): on the released rc.6.11 IDE on Linux
  they differ by 63 in the dark appearance and fail; with the patch by
  174, and by 220 in the light one.
- The whole tour ran past its 600 seconds on the Intel Mac (the light
  appearance, 141 snapshots) and came within a minute of it on Windows
  and the Apple silicon Mac, as the review's checks were added. It has
  900 (tools/ci/ui_tour.py), and each workflow step that runs it 20
  minutes, room for the IDE's start and the snapshots printed after.

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
INCLUSIONS_ROW = ('ide', 'Toolset', 'palettes', 'standalone settings',
                  'revstandalonesettingsinclusionsrowbehavior.livecodescript')
MENUBAR = ('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript')
ASSISTANT = ('ide', 'Extensions', 'org.openxtalk.plugin.xtalkassistant', 'xtalkassistant.livecodescript')


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


class TheInclusionIcons(unittest.TestCase):
    """The Inclusions card's icons are in the colour of their row's name."""

    def test_the_row(self):
        layout = handler(read(INCLUSIONS_ROW), 'on', 'LayoutControl')
        name = 'set the textColor of line 1 of field "description" of me to revIDEColor("text_1")'
        icon = 'set the foregroundColor of widget "icon" of me to revIDEColor("text_1")'
        self.assertIn(name, layout)
        self.assertIn(icon, layout)
        self.assertLess(layout.index(name), layout.index(icon))

    def test_the_tour_measures_it(self):
        tour = read(TOUR)
        step = handler(tour, 'on', 'tour_standalone_settings')
        self.assertIn('if tCard is "Inclusions" then\n         get tourInclusionIcons(tStack)\n'
                      '         if it is not empty then put it & return after tFails', step)
        self.assertIn('if tFails is not empty then throw line 1 to -1 of tFails\nend tour_standalone_settings', step)
        check = handler(tour, 'function', 'tourInclusionIcons')
        self.assertIn('if the name of control i is not ("widget" && quote & "icon" & quote) then next repeat', check)
        self.assertIn('export snapshot from rect tRect to tData as PNG', check)
        self.assertIn('if tMax < 64 then', check)
        self.assertIn('if tRects is empty then return "the Inclusions card shows no icons"', check)


class TheUpdateSummary(unittest.TestCase):
    """Preferences shows no summary of OpenXTalk Lite's last update."""

    def test_no_file(self):
        self.assertFalse(os.path.exists(os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'updates', 'whatsnew.txt')))

    def test_the_installer_does_without_it(self):
        iss = read(('Installer', 'oxt-beyond', 'oxt-beyond.iss'))
        self.assertIn('Source: "{#StageDir}\\Toolset\\palettes\\updates\\whatsnew.txt"; '
                      'DestDir: "{app}\\Toolset\\palettes\\updates"; Flags: ignoreversion skipifsourcedoesntexist', iss)
        # an install over an older one takes its Toolset folder away first
        self.assertIn('Type: filesandordirs; Name: "{app}\\Toolset"', iss)

    def test_the_tour_looks(self):
        step = handler(read(TOUR), 'on', 'tour_preferences')
        self.assertIn('if the visible of field "updNote" of card "Automatic Updates" of stack tStack and \\\n'
                      '         field "updNote" of card "Automatic Updates" of stack tStack is not empty then', step)
        self.assertIn('put "the Automatic Updates pane shows a summary of an update that is not this release\'s:"',
                      step)


class TheSearchOptions(unittest.TestCase):
    """Search and Replace shows "cards only" whole."""

    def test_the_patch(self):
        patch = read(PATCHES + ('revsearch-cards-only-width.txt',))
        self.assertIn('file: Toolset/palettes/revsearch.rev\n'
                      'object: group "Options" of card 1\n'
                      'property: rect\n'
                      'from: 18,97,253,208\n'
                      'to: 18,97,318,208\n', patch)

    def test_the_tour_measures_it(self):
        tour = read(TOUR)
        step = handler(tour, 'on', 'tour_search')
        self.assertIn('put tourButtonsWhole(tStack) into tFails\n   put tourFieldsWhole(tStack) after tFails', step)
        self.assertIn('click at the loc of button "Custom Properties" of group "Properties" of card 1 of stack tStack',
                      step)
        check = handler(tour, 'function', 'tourButtonsWhole')
        self.assertIn('put min(tRight, item 3 of the rect of group id (the id of tOwner) of this card) into tRight',
                      check)
        self.assertIn('if tNeed > tRight + 2 then', check)


def patches_of(name):
    """The object/property/from/to entries of a property patch, in order."""
    entries = []
    obj = None
    for line in read(PATCHES + (name,)).splitlines():
        if line.startswith('object: '):
            obj = line[len('object: '):]
        elif line.startswith('property: '):
            entries.append([obj, line[len('property: '):], None, None])
        elif line.startswith('from: '):
            entries[-1][2] = line[len('from: '):]
        elif line.startswith('to: '):
            entries[-1][3] = line[len('to: '):]
    return entries


def rects(name):
    """{object: (from rect, to rect)} of the rect patches of a file."""
    out = {}
    for obj, prop, frm, to in patches_of(name):
        if prop == 'rect':
            out[obj] = (tuple(int(n) for n in frm.split(',')), tuple(int(n) for n in to.split(',')))
    return out


class TheLinuxFonts(unittest.TestCase):
    """Every control the tour found cut off in DejaVu Sans, on the released
    rc.6.11 IDE, has the room it needs. NEEDS holds what the tour measured
    there: the right edge a check box's words reach, or the width or height
    a push button, an option menu or a label needs; NEXT, where a control's
    words end and the control they reached, which now starts at least 3
    points after them."""

    NEEDS = {
        'revpreferencesgui-fit-general.txt': [
            ('button "opt edit script shortcut" of card "General"', 'right', 521),
            ('button "ReloadStartCenter" of card "General"', 'right', 518),
        ],
        'revpreferencesgui-fit-files-memory.txt': [
            ('button "destroyStack" of card "Files & Memory"', 'right', 390),
            ('field id 1045 of card "Files & Memory"', 'width', 361),
            ('button "Preserve Stack Creator" of card "Files & Memory"', 'right', 385),
            ('button "Preserve Stack Version" of card "Files & Memory"', 'right', 598),
            ('group "Stack File Property Preservation" of card "Files & Memory"', 'right', 598),
            ('button "absoluteImagePaths" of card "Files & Memory"', 'right', 478),
        ],
        'revpreferencesgui-fit-appearance.txt': [
            # the check box revpreferencesgui-desktop-appearance.txt makes
            ('group "Appearance" of card "Appearance"', 'right', 691),
            ('field id 1082 of card "Appearance"', 'width', 152),
            ('field id 1078 of card "Appearance"', 'height', 36),
        ],
        'revpreferencesgui-fit-object-sizes.txt': [
            ('field id 1109 of card "Object Sizes"', 'width', 139),
            ('field id 1112 of card "Object Sizes"', 'width', 127),
            ('field id 1113 of card "Object Sizes"', 'width', 151),
            ('field id 1114 of card "Object Sizes"', 'width', 176),
        ],
        'revpreferencesgui-fit-script-editor.txt': [
            ('button "Variable Preservation" of card "Script Editor"', 'right', 346),
            ('button "Hide Message Box" of card "Script Editor"', 'right', 463),
            ('field id 1164 of card "Script Editor"', 'width', 145),
        ],
        'revpreferencesgui-fit-ui-tweaks.txt': [
            ('field id 1517 of card "UI Tweaks"', 'width', 220),
        ],
        'revpreferencesgui-fit-extras-dictionary.txt': [
            ('button "tidyUpStacks" of card "Extras"', 'right', 577),
            ('button "ScreenSharedMemory" of card "Extras"', 'right', 652),
            ('button "inExtBrowser" of card "Dictionary"', 'right', 537),
        ],
        'revpreferencesgui-fit-project-browser.txt': [
            # "Sort controls by:" on one line: its words and two margins
            ('field "sortControlsLabel" of card "Project Browser"', 'width', 122),
        ],
        'revpreferencesgui-fit-compatibility.txt': [
            ('button "cMenuBarOffset" of card "Compatibility"', 'right', 661),
            ('field id 1457 of card "Compatibility"', 'width', 503),
        ],
        'revpreferencesgui-fit-mobile-support.txt': [
            ('button "Remove entry" of card "Mobile Support"', 'width', 99),
        ],
        'revpreferencesgui-follow-appearance-width.txt': [
            ('button "Colorization Scheme" of card "Script Editor"', 'width', 202),
        ],
        'revsearch-fit-linux.txt': [
            ('button "Remove from List" of card 1', 'width', 123),
            ('button "Custom Properties" of card 1', 'right', 338),
        ],
    }

    # (patch file, where the words end, the control they reached)
    NEXT = [
        ('revpreferencesgui-fit-files-memory.txt', 396, 'field "Num Recent Files" of card "Files & Memory"'),
        ('revpreferencesgui-fit-appearance.txt', 334, 'field "tooltip delay" of card "Appearance"'),
        ('revpreferencesgui-fit-appearance.txt', 415, 'button "tHandBtn" of card "Appearance"'),
        ('revpreferencesgui-fit-appearance.txt', 509, 'button "middleButtonToggle" of card "Appearance"'),
        ('revpreferencesgui-fit-appearance.txt', 309, 'button "selectionhandle color" of card "Appearance"'),
        ('revpreferencesgui-fit-ui-tweaks.txt', 402, 'button "labelsections size" of card "UI Tweaks"'),
        ('revpreferencesgui-fit-project-browser.txt', 307, 'button "controlSortType" of card "Project Browser"'),
        ('revsearch-fit-linux.txt', 222, 'field "Replace" of card 1'),
    ]

    @staticmethod
    def measure(rect, kind):
        return {'right': rect[2], 'width': rect[2] - rect[0], 'height': rect[3] - rect[1]}[kind]

    def test_each_has_room(self):
        for name, needs in self.NEEDS.items():
            patched = rects(name)
            for obj, kind, need in needs:
                self.assertIn(obj, patched, name)
                frm, to = patched[obj]
                # cut off before (beyond the tour's 2 points), whole now
                self.assertLess(self.measure(frm, kind) + 2, need, (name, obj))
                self.assertGreaterEqual(self.measure(to, kind), need, (name, obj))
        # "Obey dontSearch properties" needed 223 of its 221: whole in the
        # tour's 2 points, with room now for a font a little wider
        self.assertGreaterEqual(rects('revsearch-fit-linux.txt')['button "Obey dontSearch properties" of card 1'][1][2],
                                233)

    def test_the_words_end_before_the_next(self):
        for name, end, after in self.NEXT:
            frm, to = rects(name)[after]
            self.assertLess(frm[0], end + 3, (name, after))
            self.assertGreaterEqual(to[0], end + 3, (name, after))
        # the "Horizontal scroll" check box (it needs to 449) ends where the
        # colour scheme menu starts
        box = rects('revpreferencesgui-fit-script-editor.txt')['button "Horizontal scroll" of card "Script Editor"'][1]
        menu = rects('revpreferencesgui-follow-appearance-width.txt')[
            'button "Colorization Scheme" of card "Script Editor"'][1]
        self.assertGreaterEqual(box[2], 449)
        self.assertGreaterEqual(menu[0], box[2])
        # a widened control stays within its group, and clear of the next
        general = rects('revpreferencesgui-fit-general.txt')
        self.assertGreaterEqual(general['group "Shortcuts" of card "General"'][1][2],
                                general['button "opt edit script shortcut" of card "General"'][1][2])
        editor = rects('revpreferencesgui-fit-script-editor.txt')
        self.assertGreaterEqual(editor['field id 1171 of card "Script Editor"'][1][0],
                                editor['button "Hide Message Box" of card "Script Editor"'][1][2])
        files = rects('revpreferencesgui-fit-files-memory.txt')
        self.assertGreaterEqual(files['group "Stack File Property Preservation" of card "Files & Memory"'][1][2],
                                files['button "Preserve Stack Version" of card "Files & Memory"'][1][2])

    def test_moved_controls_keep_their_size(self):
        # what moves right keeps its width and height, and the Project
        # Browser's column moves together
        for name in ('revpreferencesgui-fit-appearance.txt', 'revpreferencesgui-fit-ui-tweaks.txt',
                     'revpreferencesgui-fit-project-browser.txt'):
            for obj, (frm, to) in rects(name).items():
                if obj.startswith(('button', 'graphic')) and frm[0] != to[0]:
                    self.assertEqual((frm[2] - frm[0], frm[1], frm[3]), (to[2] - to[0], to[1], to[3]), (name, obj))
        moved = {to[0] - frm[0] for obj, (frm, to) in rects('revpreferencesgui-fit-project-browser.txt').items()
                 if obj.startswith('button')}
        self.assertEqual(moved, {18})

    def test_the_tour_measures_each_pane(self):
        tour = read(TOUR)
        step = handler(tour, 'on', 'tour_preferences')
        self.assertIn('      put tourButtonsWhole(tStack) after tFails\n'
                      '      put tourFieldsWhole(tStack) after tFails\n'
                      '   end repeat', step)
        self.assertIn('if tFails is not empty then throw line 1 to -1 of tFails\nend tour_preferences', step)
        # the colour scheme menu: its formattedWidth less its label, on the
        # pane that shows (a closed control's formattedWidth is 0)
        self.assertIn('dispatch "revPrefsGoSection" to stack tStack with "Script Editor"', step)
        self.assertIn('put the formattedWidth of tMenu - measureText(the label of tMenu, tMenu) into tItem', step)
        self.assertNotIn('measureText(tItem, tMenu) + 16', step)

    def test_the_checks(self):
        tour = read(TOUR)
        buttons = handler(tour, 'function', 'tourButtonsWhole')
        self.assertIn('else if the style of button i of this card is among the items of "standard,default" then',
                      buttons)
        self.assertIn('the style of button i of this card is "menu" and the menuMode of button i of this card is '
                      '"option"', buttons)
        self.assertIn('if tNeed > the width of button i of this card + 2 then', buttons)
        self.assertIn('put tourNextOnLine(the long id of button i of this card, false) into tNext', buttons)
        fields = handler(tour, 'function', 'tourFieldsWhole')
        self.assertIn('(not the lockText of field i of this card and the traversalOn of field i of this card)', fields)
        # (a field whose border is 0 wide draws none, and is a label:
        # TheAssistantNotes)
        self.assertIn('the listBehavior of field i of this card or \\\n'
                      '            (the showBorder of field i of this card and the borderWidth of field i of this card > 0) '
                      'then next repeat', fields)
        self.assertIn('put tourWordsRect(the long id of field i of this card) into tWords', fields)
        self.assertIn('if item 3 of tWords > the right of field i of this card + 2 or '
                      'item 1 of tWords < the left of field i of this card - 2 then', fields)
        self.assertIn('put the formattedHeight of field i of this card - the bottomMargin of field i of this card + 2 '
                      'into tNeed', fields)
        self.assertIn('if tNext is not empty and item 1 of tNext <= min(item 3 of tWords, the right of field i of this card) '
                      'then', fields)
        words = handler(tour, 'function', 'tourWordsRect')
        self.assertIn('repeat while tLast > 0 and (char tLast of tText is space or char tLast of tText is tab or '
                      'char tLast of tText is return)', words)
        self.assertIn('return the formattedRect of char 1 to tLast of field id (the id of pField) of tCard', words)
        shown = handler(tour, 'function', 'tourControlShown')
        self.assertIn('the left of pControl >= the width of this stack', shown)
        nxt = handler(tour, 'function', 'tourNextOnLine')
        self.assertIn('if not pWithin and the right of control j of tCard <= the right of pControl then next repeat',
                      nxt)
        # a label beside starts where its words do, and an empty one is
        # not there
        self.assertIn('put tourWordsRect(the long id of control j of tCard) into tWords\n'
                      '         if tWords is empty then next repeat\n'
                      '         put max(tStart, item 1 of tWords) into tStart', nxt)
        # every failure of the step preferences is reported together
        step = handler(tour, 'on', 'tour_preferences')
        self.assertNotIn('throw "the Automatic Updates pane', step)
        self.assertNotIn('throw "the Script Editor pane', step)
        self.assertEqual(step.count('throw '), 2, step)  # Preferences did not open, and tFails


class TheStandaloneSettings(unittest.TestCase):
    """The Standalone Settings' options have room for their words in
    DejaVu Sans. NEEDS holds what the tour measured on the released rc.6.11
    IDE: the right edge each option's words reach."""

    PATCH = 'standalone-settings-fit-linux.txt'
    NEEDS = [
        ('button id 1267 of card "General"', 430),   # Include profiles on objects and the profile library
        ('button id 1210 of card "General"', 551),   # Only include profiles selected below
        ('button id 2064 of card "Android"', 232),   # Android armv7
        ('button id 2247 of card "Android"', 187),   # Visible
        ('button id 2403 of card "Android"', 585),   # Write External Storage
        ('button id 2821 of card "Android"', 704),   # Coarse Location, 704 of 703 before
        ('button id 1187 of card "Bug Reports"', 373),  # Allow user to save report to file
        ('button id 1189 of card "Bug Reports"', 365),  # Allow user to enter comments, 365 of 364 before
    ]

    def test_the_patch(self):
        self.assertIn('file: Toolset/palettes/standalone settings/revstandalonesettings.8.rev\n',
                      read(PATCHES + (self.PATCH,)))

    def test_each_has_room(self):
        patched = rects(self.PATCH)
        for obj, need in self.NEEDS:
            frm, to = patched[obj]
            self.assertGreaterEqual(to[2], need, obj)
        # each that was cut off beyond the tour's 2 points
        for obj, need in self.NEEDS[:5] + self.NEEDS[6:7]:
            self.assertLess(patched[obj][0][2] + 2, need, obj)

    def test_the_moved_keep_their_size_and_clear_the_next(self):
        patched = rects(self.PATCH)
        # "Hidden" moves right of "Visible", and the check box of "In App
        # Purchasing" right of its label's words (which end at 147)
        hidden, visible = patched['button id 2248 of card "Android"'][1], patched['button id 2247 of card "Android"'][1]
        self.assertGreaterEqual(hidden[0], visible[2])
        box = patched['button id 3193 of card "Android"']
        self.assertEqual(box[0][2] - box[0][0], box[1][2] - box[1][0])
        self.assertGreater(box[1][0], 147)
        # the right column of permissions starts after "Write External
        # Storage", each still as wide as its words (Fine Location 686,
        # Vibration 659, Idle Timer 666, Ad Support 671, all + 10)
        write = patched['button id 2403 of card "Android"'][1]
        for obj, need in (('button id 2820 of card "Android"', 696), ('button id 2821 of card "Android"', 714),
                          ('button id 2831 of card "Android"', 669), ('button id 2833 of card "Android"', 676),
                          ('button id 2854 of card "Android"', 681)):
            to = patched[obj][1]
            self.assertGreaterEqual(to[0], write[2], obj)
            self.assertGreaterEqual(to[2] + 2, need, obj)
        # armv7 ends before arm64 (243) starts
        self.assertLess(patched['button id 2064 of card "Android"'][1][2], 243)
        # the groups round the moved radio buttons grow with them
        self.assertEqual(patched['group id 1220 of card "General"'][1][2], patched['button id 1210 of card "General"'][1][2] + 4)
        self.assertEqual(patched['group id 2246 of card "Android"'][1][2], hidden[2] + 4)

    def test_the_tour_measures_each_card(self):
        step = handler(read(TOUR), 'on', 'tour_standalone_settings')
        self.assertIn('      put tourButtonsWhole(tStack) after tFails\n'
                      '      put tourFieldsWhole(tStack) after tFails\n', step)
        self.assertLess(step.index('tourShotStack tStack, "15-standalone-"'), step.index('put tourButtonsWhole(tStack)'))


class ThePreferencesPath(unittest.TestCase):
    """The line under each Preferences pane that says where the preferences
    are saved fits a long path: folders in its middle give way to "...",
    and its tooltip holds the whole path."""

    SCRIPT = ('stack-scripts', 'ide', 'Toolset', 'palettes', 'revpreferencesgui.rev.bst', 'scripts',
              'stack_revPreferencesGUI_field_id_1349.livecodescript')

    def test_the_patch(self):
        patch = read(PATCHES + ('revpreferencesgui-prefs-path-fits.txt',))
        self.assertIn('file: Toolset/palettes/revpreferencesgui.rev\nobject: field "Menu" of card "General"\n', patch)
        self.assertIn('|   prefPathFit myPrefsLoc|\n|end updPrefPath|\n', patch)

    def test_the_stack_has_it(self):
        # the stack's own script, as tools/oxt/stack-scripts.sh dumps it (the
        # Linux build checks the dump against the stack)
        script = read(self.SCRIPT)
        update = handler(script, 'on', 'updPrefPath')
        self.assertLess(update.index('into field "prefloc" of group "Navigation"'), update.index('prefPathFit myPrefsLoc'))
        fit = handler(script, 'on', 'prefPathFit')
        self.assertIn('set the tooltip of field "prefloc" of group "Navigation" of stack "revPreferencesGUI" to pPath', fit)
        # the room is measured before the item delimiter changes (the
        # margins are a list of numbers)
        self.assertLess(fit.index('item 1 of the margins'), fit.index('set the itemDelimiter to "/"'))
        self.assertIn('repeat while the formattedWidth of line 2 of field "prefloc" of group "Navigation" of stack '
                      '"revPreferencesGUI" > tRoom and the number of items of tShown > 3', fit)
        # the path it is given is the one it measures, whatever the field held
        self.assertLess(fit.index('put tShown into line 2 of field "prefloc"'), fit.index('repeat while'))
        self.assertIn('put "..." into item 2 of tShown', fit)
        self.assertIn('delete item 3 of tShown', fit)

    def test_the_tour_tries_a_long_path(self):
        step = handler(read(TOUR), 'on', 'tour_preferences')
        self.assertIn('dispatch "prefPathFit" to field "Menu" of group "Navigation" of stack tStack with tPath', step)
        self.assertIn('"/.../" is not in tShown or not (tShown ends with "/preferences/oxt-beyond7.rev")', step)
        # the real path is put back before the window closes
        self.assertLess(step.index('dispatch "prefPathFit"'),
                        step.index('dispatch "updPrefPath" to field "Menu" of group "Navigation" of stack tStack'))
        self.assertLess(step.index('dispatch "updPrefPath"'), step.index('close stack tStack'))


class TheDisabledLabels(unittest.TestCase):
    """A disabled check box's words are drawn like every other disabled
    one's: none has a background colour or pattern saved on it that is
    never painted, and the tour measures each one's words against the
    enabled ones'."""

    PATCHES = {
        'revpreferencesgui-start-center-disabled-labels.txt': (
            'file: Toolset/palettes/revpreferencesgui.rev\n',
            ['object: button "ReloadStartCenter" of card "General"\nproperty: backgroundColor\n'
             'from: 255,255,255\nto: \n',
             'object: button "StartCenterClassicPref" of card "General"\nproperty: backgroundColor\n'
             'from: 255,255,255\nto: \n']),
        'revstandalonesettings-rename-files-disabled-label.txt': (
            'file: Toolset/palettes/standalone settings/revstandalonesettings.8.rev\n',
            ['object: button "renameFiles" of group "moveSubstacks" of group "Advanced Options" of card "Stacks"\n'
             'property: backgroundPattern\nfrom: 200921\nto: \n']),
    }

    def test_the_patches(self):
        for name, (stack, objects) in self.PATCHES.items():
            patch = read(PATCHES + (name,))
            self.assertIn(stack, patch, name)
            for obj in objects:
                self.assertIn(obj, patch, name)

    def test_the_tour_measures_each_window(self):
        tour = read(TOUR)
        for step, what in (('tour_preferences', 'Preferences'), ('tour_standalone_settings', 'Standalone Settings')):
            body = handler(tour, 'on', step)
            # none kept from a step before, each pane or card measured as it
            # shows, and compared once all are
            self.assertLess(body.index('tourLabelInksReset'), body.index('tourLabelInks tStack'), step)
            self.assertLess(body.index('tourLabelInks tStack'),
                            body.index('put tourDisabledLabels("%s") after tFails' % what), step)
            self.assertLess(body.index('put tourDisabledLabels("%s") after tFails' % what),
                            body.rindex('if tFails is not empty then throw'), step)
        # in the preferences, each pane in the loop over them
        prefs = handler(tour, 'on', 'tour_preferences')
        loop = prefs[prefs.index('repeat for each line tPane'):prefs.index('end repeat')]
        self.assertIn('tourLabelInks tStack', loop)

    def test_the_measure(self):
        tour = read(TOUR)
        inks = handler(tour, 'command', 'tourLabelInks')
        # check boxes and radio buttons that are not opaque, whose words show
        self.assertIn('is not among the items of "checkbox,radioButton"', inks)
        self.assertIn('if the opaque of tControl or not the showName of tControl then next repeat', inks)
        self.assertIn('if not tourControlShown(tControl) then next repeat', inks)
        # its words, clear of its box, against the window behind it
        self.assertIn('put tourLum(1, 1) into tBack', inks)
        self.assertIn('tourMaxDiff(26, 3, tRight, sPixHeight - 3, tBack)', inks)
        check = handler(tour, 'function', 'tourDisabledLabels')
        self.assertIn('item 2 of tLine > tMedian * 0.7', check)
        self.assertIn('item 2 of tLine < 24', check)
        self.assertIn('put empty into sLabelInks', check)
        # declared before the handlers that use it
        self.assertLess(tour.index('\nlocal sLabelInks\n'), tour.index('\ncommand tourLabelInks pStack\n'))
        self.assertLess(tour.index('\nlocal sCtlChecks, sCtlFails, sPixWidth, sPixHeight, sPixData\n'),
                        tour.index('\ncommand tourLabelInks pStack\n'))


class TheToolsPalette(unittest.TestCase):
    """A check that reads a window's pixels off the screen reads that
    window's, not the Tools palette's over it."""

    def test_aside_and_back(self):
        tour = read(TOUR)
        aside = handler(tour, 'function', 'tourToolsAside')
        # only an open, visible palette, and only when it is over the rect
        self.assertIn('if the mode of stack "revTools" is 0 or not the visible of stack "revTools" then return false',
                      aside)
        self.assertIn('if item 1 of pRect < item 3 of tTools and item 3 of pRect > item 1 of tTools', aside)
        self.assertIn('and item 2 of pRect < item 4 of tTools and item 4 of pRect > item 2 of tTools then', aside)
        self.assertLess(aside.index('hide stack "revTools"'), aside.index('return true'))
        back = handler(tour, 'command', 'tourToolsBack')
        self.assertIn('show stack "revTools"', back)

    def test_the_selected_line(self):
        body = handler(read(TOUR), 'function', 'tourSelectedLineInk')
        # hidden just before the snapshot, shown again just after, even
        # when the snapshot throws
        self.assertLess(body.index('put tourToolsAside(tRect) into tAside'),
                        body.index('export snapshot from rect tRect to tData as PNG'))
        self.assertLess(body.index('export snapshot from rect tRect to tData as PNG'),
                        body.index('if tAside then tourToolsBack'))
        self.assertLess(body.index('if tAside then tourToolsBack'),
                        body.index('if tError is not empty then throw tError'))

    def test_the_check_boxes(self):
        body = handler(read(TOUR), 'command', 'tourLabelInks')
        # once for the window, before the first snapshot and back after
        # the last
        self.assertLess(body.index('put tourToolsAside(the rect of stack pStack) into tAside'),
                        body.index('repeat with i = 1 to the number of buttons of this card'))
        self.assertLess(body.index('import snapshot from rect tRect'), body.index('if tAside then tourToolsBack'))
        self.assertLess(body.rindex('end repeat'), body.index('if tAside then tourToolsBack'))

    def test_the_snapshots_keep_it(self):
        # the snapshots for a person to look through are as the screen is
        shot = handler(read(TOUR), 'command', 'tourShotStack')
        self.assertNotIn('tourToolsAside', shot)

    def test_the_check_boxes_under_the_dock(self):
        # The Mac runners' screen is 1024 x 768, and the Dock covers the
        # bottom of Standalone Settings' Android card: "NFC Tag Reading"
        # measured the Dock's icons (188 against the enabled ones' 218, the
        # rc.6.12 pull request's Apple silicon dark tour). A check box not
        # whole in the working screenRect is left out, and the log says so;
        # the others are measured as before
        body = handler(read(TOUR), 'command', 'tourLabelInks')
        self.assertIn('put line 1 of the working screenRects into tArea', body)
        self.assertLess(body.index('put line 1 of the working screenRects into tArea'),
                        body.index('repeat with i = 1 to the number of buttons of this card'))
        check = body.index('if item 1 of tRect < item 1 of tArea or item 2 of tRect < item 2 of tArea or')
        self.assertIn('item 3 of tRect > item 3 of tArea or item 4 of tRect > item 4 of tArea then', body)
        # in global coordinates, before the snapshot of the screen
        self.assertLess(body.index('put globalLoc(item 1 to 2 of tRect) into tTopLeft'), check)
        self.assertLess(check, body.index('import snapshot from rect tRect'))
        skip = body[check:body.index('import snapshot from rect tRect')]
        self.assertIn('"is not whole in the working screenRect"', skip)
        self.assertIn('next repeat', skip)


class TheToolbarLabels(unittest.TestCase):
    """A toolbar button is as wide as its words bold, as a lit one shows
    them."""

    def test_a_lit_button_is_bold(self):
        # what the width has to hold
        lit = handler(read(MENUBAR), 'on', 'setButtonHilite')
        self.assertIn('set the textStyle of pLongID to "bold"', lit)

    def test_each_label_measured_plain_and_bold(self):
        body = handler(read(MENUBAR), 'function', '__buttonMaxFormattedWidth')
        labels = body.index('repeat for each item tHilite in "true,false"')
        styles = body.index('repeat for each item tStyle in "plain,bold"')
        style = body.index('set the textStyle of button pName of group "toolbar" of me to tStyle')
        measure = body.index('put max(tWidth, the formattedwidth of button pName of group "toolbar" of me) into tWidth')
        self.assertLess(labels, styles)
        self.assertLess(styles, style)
        self.assertLess(style, measure)
        # and the button is left as it was
        self.assertLess(body.index('put the textStyle of button pName of group "toolbar" of me into tOldStyle'), labels)
        self.assertLess(measure, body.index('set the textStyle of button pName of group "toolbar" of me to tOldStyle'))
        self.assertLess(measure, body.index('set the label of button pName of group "toolbar" of me to tOldLabel'))
        # the layout sizes every button by it
        layout = handler(read(MENUBAR), 'on', 'layoutMenu')
        self.assertIn('put revMenubarButtonFormattedWidth(tItem) into tWidth', layout)
        self.assertIn('return max(__buttonMaxFormattedWidth(pName), kMinimumMenuButtonWidth)',
                      handler(read(MENUBAR), 'function', 'revMenubarButtonFormattedWidth'))

    def test_the_tour_measures_it(self):
        tour = read(TOUR)
        step = handler(tour, 'on', 'tour_menubar_modern')
        for look, shot in (('modern', '03-menubar-modern-on'), ('classic', '03-menubar-classic')):
            check = 'if it is not empty then put "%s: a label is cut off:" && it & return after tFails' % look
            self.assertIn(check, step)
            # before the snapshot of that look
            self.assertLess(step.index(check), step.index('tourShotStack tMb, "%s"' % shot))
        # with the toggles on: Select Grouped was the one cut off
        self.assertLess(step.index('tourMbToggles true'), step.index('a label is cut off'))
        check = handler(tour, 'function', 'tourMbLabelsCut')
        self.assertIn('dispatch function "revMenubarButtonText" to stack tMb with tName, tHilite', check)
        self.assertIn('set the textStyle of tBtn to "bold"', check)
        self.assertIn('if tNeed > the width of tBtn then', check)
        self.assertLess(check.index('put the formattedWidth of tBtn into tNeed'), check.index('if tNeed > the width of tBtn then'))
        # each button as it was, for the snapshots and tourMbPrint
        self.assertIn('set the textStyle of tBtn to tStyle', check)
        self.assertIn('set the label of tBtn to tLabel', check)


class TheOptionMenuArrows(unittest.TestCase):
    """On Linux an option menu's words end clear of the arrow GTK draws over
    its right."""

    MENU = 'button "Colorization Scheme" of card "Script Editor"'
    # "Follow System Appearance" in DejaVu Sans, 13 pixels (the tour's
    # measureText on GitHub's Ubuntu machine and here), the menu's margins,
    # and the tour's room for the arrow
    WORDS, MARGIN, ROOM = 176, 4, 20

    def test_the_colour_scheme_menu(self):
        entries = {(obj, prop): (frm, to) for obj, prop, frm, to in
                   patches_of('revpreferencesgui-follow-appearance-width.txt')}
        self.assertEqual(entries[(self.MENU, 'textAlign')], ('center', 'left'))
        left, top, right, bottom = (int(n) for n in entries[(self.MENU, 'rect')][1].split(','))
        self.assertEqual((left, top, bottom), (454, 145, 167))
        # whole, as the engine measures it (its words, margins and arrow)
        self.assertGreaterEqual(right - left, self.WORDS + 2 * self.MARGIN + 18)
        # at its left the words end clear of the arrow
        self.assertLessEqual(left + self.MARGIN + 1 + self.WORDS, right - self.ROOM)
        # in the middle of rc.6.12's 204 pixels they did not
        self.assertGreater(454 + round((204 + self.WORDS) / 2), 658 - self.ROOM)
        # its right stays inside its group (182,4,725,402) and the window (700)
        self.assertLessEqual(right, 700)

    def test_the_tour_measures_it(self):
        tour = read(TOUR)
        whole = handler(tour, 'function', 'tourButtonsWhole')
        self.assertIn('if tKind is "option menu" and the platform is "Linux" then\n'
                      '            get tourMenuWordsClear(the long id of button i of this card, the label of button i of this card)',
                      whole)
        check = handler(tour, 'function', 'tourMenuWordsClear')
        self.assertIn('constant kTourMenuArrowRoom = 20\nfunction tourMenuWordsClear pMenu, pWords', tour)
        self.assertIn('put measureText(pWords, pMenu) into tWords', check)
        self.assertIn('put the left of pMenu + tMargin + 1 + tWords into tEnd', check)
        self.assertIn('put the left of pMenu + round((the width of pMenu + tWords) / 2) into tEnd', check)
        self.assertIn('if tEnd > the right of pMenu - kTourMenuArrowRoom then', check)
        # and every choice of the colour scheme menu, as it shows
        step = handler(tour, 'on', 'tour_preferences')
        self.assertIn('repeat for each line tPane in the text of tMenu\n'
                      '         if tPane is empty or tPane begins with "-" then next repeat\n'
                      '         get tourMenuWordsClear(tMenu, tPane)', step)


class TheAssistantNotes(unittest.TestCase):
    """The xTalk Assistant's Settings notes start their words inside their
    tops."""

    # the engine starts a label's words this far above its top margin (the
    # tour's formattedRect of a note: 158 for a note at 160 with a margin
    # of 4, 160 with one of 6)
    LIFT = 6

    def test_the_notes_top_margin(self):
        note = handler(read(ASSISTANT), 'command', 'xtaSettingsNote')
        m = re.search(r'set the margins of field pName to "(\d+),(\d+),(\d+),(\d+)"', note)
        self.assertIsNotNone(m)
        self.assertGreaterEqual(int(m.group(2)), self.LIFT)

    def test_the_notes_beside_a_box(self):
        build = handler(read(ASSISTANT), 'command', 'xtaBuildSettings')
        for name in ('Max Tokens Note', 'Fix Rounds Note', 'Timeout Note'):
            # at the row's top: with the margin of 6 their words are where
            # they were, 2 points down with a margin of 4
            self.assertIn('xtaSettingsNote "%s", tLeft + 88, tTop, tRight, 20' % name, build)

    def test_the_notes_under_a_box(self):
        build = handler(read(ASSISTANT), 'command', 'xtaBuildSettings')
        for name in ('Key Note', 'Base URL Note', 'Model Note'):
            # a point under the box above (24 high), and tall enough for two
            # lines of 13 and the margins
            self.assertIn('add 25 to tTop\n   xtaSettingsNote "%s", tLeft, tTop, tRight, 31' % name, build)

    def test_the_tour_measures_it(self):
        tour = read(TOUR)
        whole = handler(tour, 'function', 'tourFieldsWhole')
        # a field whose border is 0 wide is a label
        self.assertIn('(the showBorder of field i of this card and the borderWidth of field i of this card > 0) then next repeat',
                      whole)
        top = whole.index('if tWords is not empty and item 2 of tWords < the top of field i of this card then')
        self.assertLess(whole.index('if the vScroll of field i of this card is 0 then'), top)
        self.assertLess(top, whole.index('if the dontWrap of field i of this card then'))
        # the Settings and the Memory window, before their snapshots
        for shot, stack in (('tourShotXta', 'kXtaSettings'), ('tourShotXtaMemory', 'kXtaMemory')):
            body = handler(tour, 'on', shot)
            check = body.index('get tourFieldsWhole(%s)\n      if it is not empty then tourXtaProblem it' % stack)
            self.assertLess(check, body.index('tourShotStack %s,' % stack))


class TheIconChooserMenu(unittest.TestCase):
    """The icon chooser's Image library menu shows its words in the
    theme's colour."""

    def test_the_patch(self):
        entries = {(obj, prop): (frm, to) for obj, prop, frm, to in
                   patches_of('light-icon-chooser-menu.txt')}
        self.assertEqual(entries, {('button "library chooser" of card 1', 'foregroundColor'): ('black', '')})
        self.assertIn('file: Toolset/palettes/reviconchooser.rev\n',
                      read(PATCHES + ('light-icon-chooser-menu.txt',)))

    def test_the_tour_measures_it(self):
        tour = read(TOUR)
        self.assertIn('constant kTourMenuWordsInk = 96\n', tour)
        step = handler(tour, 'on', 'tour_icon_chooser')
        measure = step.index('put tourMenuWordsInk(tMenu) into tInk')
        self.assertIn('put the long id of button "library chooser" of card 1 of stack "revIconChooser" into tMenu', step)
        self.assertLess(measure, step.index('if tInk < kTourMenuWordsInk then'))
        # measured before the snapshot, and the window closed before a
        # failure is thrown
        self.assertLess(measure, step.index('tourShotStack "revIconChooser", "27-icon-chooser"'))
        self.assertLess(step.index('close stack "revIconChooser"'), step.index('if tError is not empty then throw tError'))
        ink = handler(tour, 'function', 'tourMenuWordsInk')
        # the menu's own window's coordinates, then the screen's pixels
        self.assertLess(ink.index('set the defaultStack to the short name of tStack'),
                        ink.index('put globalLoc(item 1 to 2 of tRect) into tTopLeft'))
        self.assertIn('import snapshot from rect tRect', ink)
        self.assertIn('put tourLum((tEnd + sPixWidth - 24) div 2, sPixHeight div 2) into tFace', ink)
        self.assertIn('return tourMaxDiff(2, 4, tEnd, sPixHeight - 4, tFace)', ink)


class TheTourBudget(unittest.TestCase):
    """The whole tour has the time its steps take, and each workflow step
    that runs it more than that."""

    WORKFLOWS = ('build-linux.yml', 'build-macos.yml', 'build-windows.yml', 'ui-tour.yml')

    def budget(self):
        m = re.search(r"add_argument\('--timeout', type=int, default=(\d+),", read(('tools', 'ci', 'ui_tour.py')))
        self.assertIsNotNone(m)
        return int(m.group(1))

    def test_the_tour(self):
        # 600 was short of the Intel Mac's light run on 1 November 2026
        self.assertGreaterEqual(self.budget(), 900)

    def test_each_step(self):
        budget = self.budget()
        steps = 0
        for wf in self.WORKFLOWS:
            text = read(('.github', 'workflows', wf))
            for step in re.split(r'\n      - ', text)[1:]:
                # the step's own lines, not the comments before the next
                step = '\n'.join(line for line in step.split('\n') if not line.lstrip().startswith('#'))
                if 'tools/ci/ui_tour.py' not in step:
                    continue
                steps += 1
                m = re.search(r'--timeout[ =](\d+)', step)
                seconds = int(m.group(1)) if m else budget
                limit = re.search(r'^        timeout-minutes: (\d+)$', step, re.M)
                if limit is None:
                    continue
                # the IDE's start (about 100 s on the Mac) and the
                # snapshots printed after the run, on top of the run
                self.assertGreaterEqual(int(limit.group(1)) * 60, seconds + 240, '%s: %s' % (wf, step.split('\n')[0]))
        self.assertGreaterEqual(steps, 9)


if __name__ == '__main__':
    unittest.main()
