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

"""What the review of the IDE's screenshots for 0.2.8-dp.1 found, read from
the files without an engine: the text colours that seven stacks' controls
no longer keep, the Preferences window's note for a machine with no JDK
and its Debug Properties names, the script editor's handler menu on a Mac
in the dark, and the tour's checks of them (tools/ci/ui-tour.livecodescript
looks at the windows themselves, on every platform's build).

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import check_ide_stacks as cis  # noqa: E402

PATCHES = os.path.join(REPO, 'tools', 'oxt', 'ide-stack-patches')
PREFS = os.path.join(REPO, 'stack-scripts', 'ide', 'Toolset', 'palettes', 'revpreferencesgui.rev.bst', 'scripts')

# patch file: (stack, the controls whose own text colour it clears)
CLEARED = {
    'revstandalonesettings-own-text-colours.txt': (
        'Toolset/palettes/standalone settings/revstandalonesettings.8.rev',
        ['button "UAC Execution Level" of group "Windows" of card "Windows"',
         'field "Required label" of card "Android"', 'field "Used label" of card "Android"',
         'field "n/a label" of card "Android"',
         'field id 3617 of card "iOS"', 'field id 3618 of card "iOS"', 'field id 3619 of card "iOS"']),
    'revimagelibrary-library-menu-text-colour.txt': (
        'Toolset/palettes/revimagelibrary.rev', ['button "library chooser" of card "Objects"']),
    'revplugineditor-list-menu-text-colour.txt': (
        'Toolset/palettes/revplugineditor.rev', ['button "list" of card 1']),
    'report-builder-font-menu-text-colour.txt': (
        'Plugins/Report Builder.livecode', ['button "Font" of card 1']),
    'nudge-editor-increment-text-colour.txt': (
        'Toolset/palettes/inspector/editors/com.livecode.pi.nudge.livecode', ['button "Increment" of card 1']),
    'revpreferencesgui-start-center-text-colours.txt': (
        'Toolset/palettes/revpreferencesgui.rev',
        ['button "ReloadStartCenter" of card "General"', 'button "StartCenterClassicPref" of card "General"']),
    'revscripteditor-handler-menu-text-colour.txt': (
        'Toolset/palettes/script editor/revscripteditor.8.rev',
        ['button "Fake Handler Menu" of card "Main" of stack "revNewScriptEditor 1"']),
}


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def code(text):
    """A script's lines without its comment lines."""
    return '\n'.join(line for line in text.splitlines() if not line.strip().startswith('--'))


def handler(script, name):
    m = re.search(r'^(on|function|command) %s\b.*?^end %s\s*$' % (name, name), script, re.S | re.M)
    if not m:
        raise AssertionError('no handler ' + name)
    return m.group(0)


class TestOwnTextColours(unittest.TestCase):
    def test_each_patch_clears_the_text_colour_of_its_controls(self):
        for name, (stack, controls) in CLEARED.items():
            patch = cis.read_patch(os.path.join(PATCHES, name))
            self.assertEqual(patch[0], 'property', name)
            self.assertEqual(patch[1], stack, name)
            self.assertTrue(os.path.exists(os.path.join(REPO, 'ide', stack)), stack)
            self.assertEqual([c[0] for c in patch[2]], controls, name)
            for obj, prop, was, now in patch[2]:
                self.assertEqual(prop, 'foregroundColor', obj)
                self.assertEqual(now, '', obj)
                # a colour that one of the two windows hid
                self.assertIn(was, ('0,0,0', 'black', '66,66,66', '64,64,64'), obj)

    def test_the_stacks_are_ones_the_check_of_every_stack_reads(self):
        import stack_inks
        for stack, _ in CLEARED.values():
            self.assertTrue(('ide/' + stack).startswith(stack_inks.SCOPE), stack)


class TestScriptEditorHandlerMenu(unittest.TestCase):
    SCRIPT = ('ide', 'Toolset', 'palettes', 'script editor', 'behaviors', 'revseutilities.livecodescript')

    def test_no_script_gives_the_handler_menu_a_text_colour(self):
        found = 0
        for root, _, names in os.walk(os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'script editor')):
            for n in names:
                if not n.endswith('.livecodescript'):
                    continue
                for line in code(read(root, n)).splitlines():
                    m = re.search(r'set the (foregroundColor|foreColor|textColor) of (button|btn) "Fake Handler Menu".* to (.*)$',
                                  line, re.I)
                    if m:
                        found += 1
                        self.assertEqual(m.group(3).split('--')[0].strip(), '""', line.strip())
        # the Mac's dark branch and the other platforms' reset
        self.assertEqual(found, 2)

    def test_tperrys_dated_comment_is_kept(self):
        self.assertIn('-- tperry 13-09-2025', handler(read(*self.SCRIPT), 'pFixupMacElements'))


class TestPreferences(unittest.TestCase):
    def card(self):
        return read(PREFS, 'stack_revPreferencesGUI_card_id_1254.livecodescript')

    def test_the_note_for_no_jdk_names_jdk_17_on_every_platform(self):
        body = handler(self.card(), 'updateJDK')
        notes = re.findall(r'put "([^"]*)" into cd fld "fmobtip"', body)
        self.assertEqual(len(notes), 1, notes)
        self.assertIn('JDK 17', notes[0])
        # one line of the note's 468 pixels (its field is 36 high, with room for one)
        self.assertLessEqual(len(notes[0]), 70)
        before = body[:body.index('into cd fld "fmobtip"')]
        self.assertIn('if tJDK is empty then', before)
        self.assertNotRegex(before.split('if tJDK is empty then')[-1], r'the platform')

    def test_nothing_of_the_mobile_support_pane_names_java_8(self):
        self.assertNotRegex(code(self.card()), r'(?i)jdk-?8|8u\d|java 8')

    def test_the_patch_is_the_cards(self):
        patch = cis.read_patch(os.path.join(PATCHES, 'revpreferencesgui-mobile-jdk-tip.txt'))
        self.assertEqual(patch[:3], ('script', 'Toolset/palettes/revpreferencesgui.rev', 'card "Mobile Support"'))
        old, new = (text.decode('utf-8') for text in patch[3:5])
        self.assertIn('jdk-8u202', old)
        self.assertIn('JDK 17', new)
        self.assertIn(new, self.card())

    def test_debug_properties_names_are_in_the_colour_of_a_selected_rows_words(self):
        body = code(handler(read(PREFS, 'stack_revPreferencesGUI_field_id_1475.livecodescript'), 'fFormatCols'))
        self.assertIn('set the backgroundColor of char tFromCharNum to tToCharNum of line tcount of cd fld "fPREFFS" '
                      'to revIDEColor("dataView_hiliteColor")', body)
        self.assertIn('set the foregroundColor of char tFromCharNum to tToCharNum of line tcount of cd fld "fPREFFS" '
                      'to revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor"))', body)
        # the accentColor, which is what dataView_TextHiliteColor gives: blue on that blue
        self.assertNotIn('dataView_TextHiliteColor', body)
        self.assertNotIn('the accentColor', body)

    def test_the_ide_library_has_what_the_pane_calls(self):
        library = read('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
        self.assertRegex(library, r'(?m)^function revIDEHilitedTextColor pHiliteColor')
        self.assertIn('"dataView_hiliteColor"', library)


class TestTour(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tour = read('tools', 'ci', 'ui-tour.livecodescript')

    def test_the_script_editor_step_reads_the_handler_menus_colour(self):
        body = code(handler(self.tour, 'tour_script_editor'))
        self.assertIn('put the foregroundColor of button "Fake Handler Menu" of stack tSE into tInk', body)
        self.assertRegex(body, r'if tInk is not empty then\s+throw ')

    def test_the_preferences_step_looks_at_the_two_panes_and_fails_without_them(self):
        body = code(handler(self.tour, 'tour_preferences'))
        self.assertIn('put tourDebugPropertyNames(tStack) after tFails', body)
        self.assertIn('put tourJDKTip(tStack) after tFails', body)
        self.assertRegex(body, r'repeat for each item tPane in "debug-properties,mobile-support"\s+'
                               r'if tSeen\[tPane\] is not true then put .* after tFails')
        self.assertIn('if tFails is not empty then throw', body)

    def test_the_names_must_stand_out_from_what_is_behind_them(self):
        body = code(handler(self.tour, 'tourDebugPropertyNames'))
        self.assertIn('the foregroundColor of char tFrom of line tLine of tField', body)
        self.assertIn('the backgroundColor of char tFrom of line tLine of tField', body)
        self.assertIn('put tourContrast(tInk, tBack) into tRatio', body)
        self.assertRegex(body, r'if tRatio < 2\.5 then\s+return "')
        # a list with no name, or a name with no colours, fails too
        self.assertRegex(body, r'if tLine is empty then return "')
        self.assertRegex(body, r'if the number of items of tInk is not 3 or the number of items of tBack is not 3 then\s+return "')

    def test_the_note_must_name_jdk_17_and_fit_where_it_shows(self):
        body = code(handler(self.tour, 'tourJDKTip'))
        self.assertIn('if not the visible of tField then return empty', body)
        self.assertRegex(body, r'if "JDK 17" is not in tText or "8u" is in tText then\s+return "')
        self.assertRegex(body, r'if tNeed > the height of tField then\s+return "')

    def test_what_the_pictures_of_0_2_7_showed_would_fail(self):
        # The names' colours in the pictures of 0.2.7 (the accentColor on the
        # selection blue), by the tour's own measure, and after
        import stack_inks
        blue = (48, 160, 209)
        for name, ink in (('Windows', (0, 120, 215)), ('macOS', (0, 122, 255))):
            self.assertLess(stack_inks.contrast(ink, blue), 2.5, name)
        self.assertGreater(stack_inks.contrast((255, 255, 255), blue), 2.5)
        self.assertGreater(stack_inks.contrast((0, 0, 0), blue), 2.5)


if __name__ == '__main__':
    unittest.main()
