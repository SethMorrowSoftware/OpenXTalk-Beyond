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

"""tools/web-ide/build_site.py: what the web IDE's zip leaves out. Since
seth's decision 13 (2026-10-31) it leaves out the Source Code Pro font
files, which the web engine cannot load (the web IDE of 0.2.7-rc.6.9 said
"can't load font file" for every one of them, and loaded FontAwesome and
lcideicons), and the unused archive of the Linux theme (bwmilby,
openxtalk.org p=25582). Everything else it took stays: the fonts that
load, the fonts' licence and the theme's folder.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))

import build_site  # noqa: E402

FONTS = 'Toolset/resources/supporting_files/fonts'
THEMES = 'Toolset/resources/supporting_files/themes'


class LeftOut(unittest.TestCase):
    def test_source_code_pro_is_left_out(self):
        for name in ('SourceCodePro-Regular.ttf', 'SourceCodePro-BlackIt.ttf',
                     'SourceCodePro-ExtraLightIt.ttf', 'SourceCodePro-Semibold.ttf'):
            self.assertTrue(build_site.leave_out(FONTS + '/' + name), name)

    def test_fonts_that_load_stay(self):
        for name in ('fontawesome.ttf', 'lcideicons.ttf', 'LICENSE.txt'):
            self.assertFalse(build_site.leave_out(FONTS + '/' + name), name)

    def test_only_the_fonts_folder(self):
        # A stack or extension of the user's own with a font of that name
        # elsewhere is not touched
        self.assertFalse(build_site.leave_out('Extensions/x/SourceCodePro-Regular.ttf'))
        self.assertFalse(build_site.leave_out('Resources/SourceCodePro-Regular.ttf'))
        self.assertFalse(build_site.leave_out(FONTS + '/SourceCodePro-Regular.ttf.txt'))

    def test_linux_theme_archive_is_left_out(self):
        self.assertTrue(build_site.leave_out(THEMES + '/com.livecode.theme.linux.tar.xz'))

    def test_theme_folders_stay(self):
        for rel in ('com.livecode.theme.linux/loading.gif',
                    'com.livecode.theme.linux/dark/com.livecode.tool.Browse.icon.png',
                    'com.livecode.theme.mac.10.0/loading.gif',
                    'com.livecode.theme.win.6.0/loading.gif'):
            self.assertFalse(build_site.leave_out(THEMES + '/' + rel), rel)

    def test_earlier_rules_hold(self):
        self.assertTrue(build_site.leave_out('Toolset/palettes/userguides/allguides.oxtstack'))
        self.assertTrue(build_site.leave_out('Toolset/palettes/tutorial/x.rev'))
        self.assertTrue(build_site.leave_out('Extensions/com.x/code/x86_64-linux/libx.so'))
        self.assertFalse(build_site.leave_out('Toolset/home.livecodescript'))


class TheRepositorysIDE(unittest.TestCase):
    """The IDE's own fonts and themes, as the repository has them: only the
    Source Code Pro files and the theme archive go."""

    def test_fonts(self):
        folder = os.path.join(REPO, 'ide', *FONTS.split('/'))
        names = sorted(os.listdir(folder))
        gone = [n for n in names if build_site.leave_out(FONTS + '/' + n)]
        kept = [n for n in names if not build_site.leave_out(FONTS + '/' + n)]
        self.assertTrue(gone, 'no Source Code Pro files found in %s' % folder)
        self.assertTrue(all(n.startswith('SourceCodePro-') and n.endswith('.ttf') for n in gone), gone)
        self.assertEqual([n for n in names if n.startswith('SourceCodePro-')], gone)
        self.assertIn('fontawesome.ttf', kept)
        self.assertIn('lcideicons.ttf', kept)

    def test_themes(self):
        folder = os.path.join(REPO, 'ide', *THEMES.split('/'))
        gone = [n for n in sorted(os.listdir(folder)) if build_site.leave_out(THEMES + '/' + n)]
        self.assertEqual(gone, ['com.livecode.theme.linux.tar.xz'])


class IdeFiles(unittest.TestCase):
    """ide_files over a made-up installed layout"""

    def test_zip_files(self):
        with tempfile.TemporaryDirectory() as install:
            def put(rel):
                path = os.path.join(install, *rel.split('/'))
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'w') as f:
                    f.write('x')
            for rel in ('Toolset/home.livecodescript', 'Extensions/readme.txt',
                        FONTS + '/SourceCodePro-Regular.ttf', FONTS + '/SourceCodePro-It.ttf',
                        FONTS + '/fontawesome.ttf', FONTS + '/lcideicons.ttf',
                        FONTS + '/LICENSE.txt',
                        THEMES + '/com.livecode.theme.linux.tar.xz',
                        THEMES + '/com.livecode.theme.linux/loading.gif'):
                put(rel)
            files = build_site.ide_files(install, None)
            self.assertNotIn(FONTS + '/SourceCodePro-Regular.ttf', files)
            self.assertNotIn(FONTS + '/SourceCodePro-It.ttf', files)
            self.assertNotIn(THEMES + '/com.livecode.theme.linux.tar.xz', files)
            for rel in (FONTS + '/fontawesome.ttf', FONTS + '/lcideicons.ttf',
                        FONTS + '/LICENSE.txt', THEMES + '/com.livecode.theme.linux/loading.gif',
                        'Toolset/home.livecodescript'):
                self.assertIn(rel, files)


if __name__ == '__main__':
    unittest.main()
