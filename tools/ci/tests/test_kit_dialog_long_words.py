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

"""The IDE's dialog in the look of Learn breaks a word wider than its panel
of text: a field wraps only at a space, so a path with none ("Your copy is
ready" of File > Community Stacks, "Your stack is packed" of File > Share
Stack, which on a Mac name /private/var/folders/...) ran past the panel and
was cut off. tests/lcs/dialogs/kitdialog.livecodescript runs
revKitDialogFitWords on an engine; the dialog itself is modal, so no
headless test can open it, and this checks, from the file, that kdBuild
calls it on the panel as soon as the panel has its text, before the panel
is sized to that text.

  python3 -m unittest discover -s tools/ci/tests -p test_kit_dialog_long_words.py
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DIALOG = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'kitdialog', 'revkitdialog.livecodescript')


def handler(text, kind, name):
    m = re.search(r'^(?:private\s+)?%s\s+%s\b.*?^end\s+%s\b' % (kind, name, name), text, re.M | re.S)
    return m.group(0) if m else ''


class KitDialogLongWords(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        with open(DIALOG, encoding='utf-8') as f:
            cls.text = f.read()

    def test_the_handler_is_public(self):
        # (the test of it dispatches to the dialog's stack)
        body = handler(self.text, 'command', 'revKitDialogFitWords')
        self.assertTrue(body, 'revKitDialogFitWords is gone')
        self.assertFalse(body.startswith('private'))

    def test_kdbuild_fits_the_panel_after_its_text_and_before_its_height(self):
        build = handler(self.text, 'command', 'kdBuild')
        self.assertTrue(build, 'kdBuild is gone')
        lines = [x.strip() for x in build.splitlines()]
        text_at = [i for i, x in enumerate(lines)
                   if x.startswith('set the htmlText of tObj to kdTextHtml(sSpec["text"])')]
        self.assertEqual(len(text_at), 1, 'the panel gets its text once')
        fit_at = text_at[0] + 1
        self.assertEqual(lines[fit_at], 'revKitDialogFitWords tObj')
        height_at = [i for i, x in enumerate(lines) if 'the formattedHeight of tObj' in x]
        self.assertTrue(height_at and height_at[0] > fit_at,
                        'the panel is sized to its text after the words are fitted')

    def test_the_engine_test_is_there(self):
        test = os.path.join(REPO, 'tests', 'lcs', 'dialogs', 'kitdialog.livecodescript')
        with open(test, encoding='utf-8') as f:
            body = f.read()
        self.assertIn('revKitDialogFitWords', body)
        self.assertIn('/private/var/folders/', body)


if __name__ == '__main__':
    unittest.main()
