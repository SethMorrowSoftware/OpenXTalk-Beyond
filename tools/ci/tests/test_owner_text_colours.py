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

"""What pictures in the dark of the windows the tour did not show found on
12 November 2026, read from the files without an engine: the stacks that
no longer keep a text colour their controls took (Replicate, its older
copy, the Printer Chooser, the Menu Builder's style chooser), the print
dialog's white boxes, the owners that are left as they are and why that
still holds, and the tour's step that looks at Replicate on every
platform's build (tools/ci/ui-tour.livecodescript). tools/ci/stack_inks.py
reads the stacks themselves in the Linux build; test_stack_inks.py tests
its rule on made-up dumps.

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
import stack_inks  # noqa: E402

PATCHES = os.path.join(REPO, 'tools', 'oxt', 'ide-stack-patches')
PALETTES = 'Toolset/palettes/'

# patch file: (stack, [(object, property, from, to)])
CLEARED = {
    'replicate-stack-text-colour.txt': (
        PALETTES + 'replicate.oxtstack', [('stack', 'foregroundColor', 'Black', '')]),
    'revreplicate-stack-text-colour.txt': (
        PALETTES + 'revreplicate.rev', [('stack', 'foregroundColor', 'Black', '')]),
    'revprinterchooser-stack-text-colour.txt': (
        PALETTES + 'revprinterchooser.rev', [('stack', 'foregroundColor', '0,0,0', '')]),
    'revmenumanager-style-popup-text-colour.txt': (
        PALETTES + 'revmenumanager.rev', [('stack "revMenuStylePopup"', 'foregroundColor', 'Black', '')]),
}
PRINT_DIALOG = 'revprintdialog-white-boxes.txt'
PRINT_ROWS = os.path.join(REPO, 'stack-scripts', 'ide', 'Toolset', 'palettes', 'revprintdialog.rev.bst', 'scripts')


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


class TestOwnersCleared(unittest.TestCase):
    def test_each_patch_clears_the_text_colour_its_stack_kept(self):
        for name, (stack, changes) in CLEARED.items():
            patch = cis.read_patch(os.path.join(PATCHES, name))
            self.assertEqual(patch[0], 'property', name)
            self.assertEqual(patch[1], stack, name)
            self.assertTrue(os.path.exists(os.path.join(REPO, 'ide', stack)), stack)
            self.assertEqual(patch[2], changes, name)
            for _, _, was, now in patch[2]:
                # black, which the dark window hid; none, so the theme's is used
                self.assertEqual(stack_inks.colour(was), (0, 0, 0), name)
                self.assertLess(stack_inks.contrast(stack_inks.colour(was), stack_inks.DARK_WINDOW),
                                stack_inks.MIN_CONTRAST)
                self.assertEqual(now, '', name)

    def test_the_stacks_are_ones_the_check_of_every_stack_reads(self):
        for stack, _ in CLEARED.values():
            self.assertTrue(('ide/' + stack).startswith(stack_inks.SCOPE), stack)

    def test_the_edit_menu_opens_the_stack_that_was_patched(self):
        opens = code(handler(read('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript'),
                             'tOpenReplicate'))
        self.assertIn('& "replicate.oxtstack" into tFilePath', opens)
        self.assertIn('modal stack tFilePath', opens)
        self.assertIn(PALETTES + 'replicate.oxtstack', [stack for stack, _ in CLEARED.values()])


class TestPrintDialog(unittest.TestCase):
    def setUp(self):
        self.patch = cis.read_patch(os.path.join(PATCHES, PRINT_DIALOG))

    def test_the_two_fields_lose_their_white_background(self):
        self.assertEqual(self.patch[:2], ('property', PALETTES + 'revprintdialog.rev'))
        self.assertEqual(self.patch[2][:2], [
            ('field "Pages" of group "Range" of card 1', 'backgroundColor', '255,255,255', ''),
            ('field "Filename" of group "Print Target" of card 1', 'backgroundColor', '255,255,255', '')])

    def test_the_list_of_printers_gets_black_for_its_white_box(self):
        self.assertEqual(self.patch[2][2:], [
            ('group "Printer List" of group "Print Target" of card 1', 'foregroundColor', '', '0,0,0')])

    def test_a_printers_row_keeps_no_colour_of_its_own_unless_chosen(self):
        # so its name takes the list's black; the chosen row sets white on
        # the selection's colour
        rows = 0
        for name in sorted(os.listdir(PRINT_ROWS)):
            text = code(read(PRINT_ROWS, name))
            if 'set the backgroundColor of field "Name" of me to fieldHiliteColor()' not in text:
                continue
            rows += 1
            self.assertIn('set the foregroundColor of field "Name" of me to "white"', text, name)
            self.assertIn('set the backgroundColor of field "Name" of me to empty', text, name)
            self.assertIn('set the foregroundColor of field "Name" of me to empty', text, name)
        self.assertGreater(rows, 0)


class TestOwnersLeft(unittest.TestCase):
    """The owners stack_inks.EXCEPTIONS excuses, while the reasons hold."""

    def test_the_three_are_listed(self):
        for key in (('ide/Toolset/palettes/revpagesetup.rev', stack_inks.THE_STACK),
                    ('ide/Toolset/palettes/revrulersh.rev', stack_inks.THE_STACK),
                    ('ide/Toolset/palettes/splash/revSplash.livecode', 'card "Main" (id 1008)')):
            self.assertIn(key, stack_inks.EXCEPTIONS)

    def test_page_setup_is_still_a_metacard_stack_file_and_has_no_patch(self):
        # The patch tool refuses to save it (the engine writes another
        # format). Once it is saved in a current format, clear its stack's
        # text colour with a patch and take it out of EXCEPTIONS
        with open(os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'revpagesetup.rev'), 'rb') as f:
            head = f.read(64)
        self.assertTrue(head.startswith(b'#!/bin/sh\n# MetaCard 2.4 stack\n'), head)
        for name in sorted(os.listdir(PATCHES)):
            if name.endswith('.txt'):
                self.assertNotEqual(cis.read_patch(os.path.join(PATCHES, name))[1],
                                    PALETTES + 'revpagesetup.rev', name)

    def test_the_splash_sets_its_cards_colour_as_it_opens(self):
        script = code(read('ide', 'Toolset', 'palettes', 'splash', 'revsplashstackbehavior.livecodescript'))
        self.assertIn('if the systemappearance is "dark" then set the foregroundColor of this card to white', script)
        self.assertIn('if the systemappearance is "light" then set the foregroundColor of this card to black', script)


class TestTour(unittest.TestCase):
    def setUp(self):
        self.tour = read('tools', 'ci', 'ui-tour.livecodescript')

    def test_replicate_is_a_step_between_search_and_the_object_library(self):
        steps = re.search(r'^constant kSteps = "([^"]*)"', self.tour, re.M).group(1).split(',')
        at = steps.index('replicate')
        self.assertEqual(steps[at - 1:at + 2], ['search', 'replicate', 'object-library'])

    def test_the_step_opens_the_stack_the_menu_opens_and_pictures_it(self):
        step = code(handler(self.tour, 'tour_replicate'))
        self.assertIn('put item 1 to -3 of the filename of stack "revMenubar" & slash & "replicate.oxtstack" into tFile',
                      step)
        self.assertIn('palette stack tFile', step)
        self.assertIn('tourShotStack tStack, "21-replicate"', step)

    def test_the_step_fails_on_labels_that_cannot_be_made_out(self):
        step = code(handler(self.tour, 'tour_replicate'))
        self.assertIn('put tourLabelsFaint(tStack) into tFaint', step)
        # too few measured is a failure too: a check of nothing passes
        self.assertRegex(step, r'if line 1 of tFaint < 6 then throw ')
        self.assertRegex(step, r'if tFaint is not empty then throw "Replicate\'s words cannot be made out:"')

    def test_a_label_is_measured_on_the_screen_against_what_most_of_it_is(self):
        faint = code(handler(self.tour, 'tourLabelsFaint'))
        self.assertIn('if the opaque of tControl or the disabled of tControl or not tourControlShown(tControl) '
                      'then next repeat', faint)
        self.assertIn('put tourWordsRect(tControl) into tRect', faint)
        self.assertIn('tourGrabRect pStack, tRect,', faint)
        self.assertIn('put tourMostLum() into tBack', faint)
        self.assertIn('put tourMaxDiff(0, 0, sPixWidth, sPixHeight, tBack) into tFar', faint)
        self.assertIn('if tFar < kLabelWordsSeen then', faint)
        self.assertIn('import snapshot from rect pRect', handler(self.tour, 'tourGrabRect'))

    def test_the_threshold_is_between_black_on_a_dark_window_and_the_themes_words(self):
        seen = int(re.search(r'^constant kLabelWordsSeen = (\d+)$', self.tour, re.M).group(1))
        # black is at most the window's own luminance from it: 32 on
        # Windows' dark window, 56 on GTK's (measured on Linux on main's
        # stack, where the theme's words were 199 from it after the patch)
        self.assertGreater(seen, 56)
        self.assertLess(seen, 199 - 40)


if __name__ == '__main__':
    unittest.main()
