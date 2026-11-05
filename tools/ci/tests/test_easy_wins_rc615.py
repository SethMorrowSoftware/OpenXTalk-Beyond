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

"""Two small IDE fixes, held in the source; the IDE tour runs them.

The extension library's dark mode hook. Every extension the IDE loads,
unloads, installs or uninstalls calls __extensionsChanged, which ran the
hook each time: a setAllToDarkMode or setAllToLightMode and an
IDEToDarkMode or IDEToLightMode waiting for every extension, hundreds of
them pending in a slow start (the Intel Mac tour that timed out on
2026-11-01). The hook now runs once a batch, with the ideExtensionsChanged
notice that was already batched. The tour's step extensions-theme-pass
unloads and loads three libraries (six changes) and counts the hook
messages: 6 on the released 0.2.7-rc.6.13 Linux IDE, 1 with this library.

Launch Editor (revIDEEditImage, and revEditImage from a script). In a
stack whose hcAddressing is true a card's image and a background's can
have one number; both were exported to one temp<N>.png, so Update gave the
first the second's picture and emptied the second. Each image has its own
file now, and the first of a number keeps temp<N>.png. The tour's step
edit-image-numbers edits a card image and a background image of number 1
together: on rc.6.13 one file and the background's image emptied, with
this library two files and each image its own picture.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
EXTENSIONS = ('ide', 'Toolset', 'libraries', 'revideextensionlibrary.livecodescript')
IDE_LIBRARY = ('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
TOUR = ('tools', 'ci', 'ui-tour.livecodescript')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def handler(script, name, kinds=r'(?:private )?(?:on|command|function)'):
    found = re.search(r'\n%s %s\b' % (kinds, re.escape(name)), script)
    if not found:
        raise AssertionError('no handler %s' % name)
    end = re.compile(r'\nend %s[ \t]*\n' % re.escape(name)).search(script, found.start())
    return script[found.start():end.start()]


def tour_steps(tour):
    return re.search(r'constant kSteps = "([^"]*)"', tour).group(1).split(',')


class TheExtensionsThemeHook(unittest.TestCase):
    def setUp(self):
        self.lib = read(*EXTENSIONS)

    def test_a_change_only_queues_the_batch(self):
        changed = handler(self.lib, '__extensionsChanged')
        self.assertIn('send "doExtensionsChangedBatch" to me in 10 millisecs', changed)
        self.assertIn('cancel sExtensionsChangedMsg', changed)
        for word in ('IDEToDarkMode', 'IDEToLightMode', 'setAllToDarkMode', 'setAllToLightMode', 'cDarkMode'):
            self.assertNotIn(word, changed)

    def test_the_batch_runs_the_hook_then_the_notice(self):
        batch = handler(self.lib, 'doExtensionsChangedBatch')
        self.assertLess(batch.index('put empty into sExtensionsChangedMsg'), batch.index('__extensionsThemeHook'))
        self.assertEqual(batch.strip().splitlines()[-1].strip(), 'doExtensionsChanged')

    def test_the_hook_sends_what_it_sent_before(self):
        hook = handler(self.lib, '__extensionsThemeHook')
        for line in ('setAllToDarkMode', 'setAllToLightMode',
                     'send "IDEToDarkMode" to me in 0 millisecs',
                     'send "IDEToLightMode" to me in 0 millisecs',
                     'get the cDarkMode of stack "revPreferences"'):
            self.assertIn(line, hook)
        self.assertIn('cancel sExtensionsThemeMsg', hook)

    def test_a_direct_notice_is_as_it_was(self):
        # __extensionUpdateUIWithPackage calls doExtensionsChanged itself
        self.assertEqual([x.strip() for x in handler(self.lib, 'doExtensionsChanged').strip().splitlines()[1:]],
                         ['ideMessageSend "ideExtensionsChanged"'])

    def test_the_script_locals_come_before_their_first_use(self):
        # an undeclared name in a handler above its declaration would be a
        # handler local of its own
        declared = self.lib.index('local sExtensionsChangedMsg, sExtensionsThemeMsg')
        for name in ('sExtensionsChangedMsg', 'sExtensionsThemeMsg'):
            self.assertLess(declared, self.lib.index(name))

    def test_the_tour_counts_it(self):
        tour = read(*TOUR)
        self.assertIn('extensions-theme-pass', tour_steps(tour))
        step = handler(tour, 'tour_extensions_theme_pass')
        self.assertIn('revIDEExtensionUnload tId', step)
        self.assertIn('revIDEExtensionReload tId', step)
        self.assertIn('if sTourHookCount is not 1 then', step)


class TheLaunchEditorFiles(unittest.TestCase):
    def setUp(self):
        self.edit = handler(read(*IDE_LIBRARY), 'revIDEEditImage')

    def test_each_image_has_a_file_of_its_own(self):
        self.assertIn('put "temp" & tNumber & "-" & tLineNo & ".png" into tTempFiles[tLineNo]', self.edit)
        # the first image of a number keeps the old name
        self.assertIn('put "temp" & tNumber & ".png" into tTempFiles[tLineNo]', self.edit)
        self.assertIn('export tImage to file tTempFiles[tLineNo] as png', self.edit)

    def test_update_and_cancel_use_those_files(self):
        self.assertIn('set the text of tImage to URL ("binfile:" & tTempFiles[tLineNo])', self.edit)
        self.assertEqual(self.edit.count('delete file tTempFiles[tLineNo]'), 2)
        self.assertNotIn('("temp" & tNumber & ".png")', self.edit)

    def test_the_tour_edits_two_images_of_one_number(self):
        tour = read(*TOUR)
        self.assertIn('edit-image-numbers', tour_steps(tour))
        step = handler(tour, 'tour_edit_image_numbers')
        self.assertIn('set the hcAddressing of stack kTourEditStack to true', step)
        self.assertIn('if the number of tCardImage is not the number of tBgImage then', step)
        self.assertIn('send "mouseUp" to button "Update" of card 1 of stack "Answer Dialog"',
                      handler(tour, 'tourEditAct'))


if __name__ == '__main__':
    unittest.main()
