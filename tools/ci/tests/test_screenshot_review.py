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
  IDE with DejaVu Sans they fail on all of these (31 in Preferences); with
  the patched stacks they pass, light and dark.

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
                      '         if it is not empty then throw it', step)
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
        self.assertIn('throw "the Automatic Updates pane shows a summary of an update that is not this release\'s:"',
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
        self.assertIn('put the formattedWidth of field i of this card - the rightMargin of field i of this card '
                      'into tNeed', fields)
        self.assertIn('put the formattedHeight of field i of this card - the bottomMargin of field i of this card + 2 '
                      'into tNeed', fields)
        self.assertIn('if tNext is not empty and item 1 of tNext < tTo + 3 then', fields)
        shown = handler(tour, 'function', 'tourControlShown')
        self.assertIn('the left of pControl >= the width of this stack', shown)
        nxt = handler(tour, 'function', 'tourNextOnLine')
        self.assertIn('if not pWithin and the right of control j of tCard <= the right of pControl then next repeat',
                      nxt)


if __name__ == '__main__':
    unittest.main()
