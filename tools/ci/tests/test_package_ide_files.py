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

"""The IDE's files that each platform's package stages
(tools/oxt/package.py, ide_pairs): the Windows icons at the root of an
install, OXT-Beyond's and OpenXTalk Lite's, only in the Windows package
(tperry2x on openxtalk.org: "the linux version ships with a windows ico
file"), and every other file of the IDE in every package, as before,
the Windows standalones' sample icons included.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import sys
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))

import layout  # noqa: E402
import package  # noqa: E402

ICONS = set(package.WINDOWS_ONLY_IDE_FILES)


class IdeFilesOfEachPackage(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.plans = {}
        for name, platform in package.PLATFORMS.items():
            staged, problems = package.ide_pairs(REPO, platform)
            every, _ = layout.plan_assemble(REPO, platform.ide_include)
            cls.plans[name] = (platform, dict(staged), dict(every), problems)

    def test_the_windows_icons_only_in_the_windows_package(self):
        for name, (platform, staged, every, problems) in self.plans.items():
            with self.subTest(platform=name):
                self.assertEqual(problems, [])
                self.assertLessEqual(ICONS, set(every))
                if platform.family == 'windows':
                    self.assertLessEqual(ICONS, set(staged))
                else:
                    self.assertEqual(ICONS & set(staged), set())

    def test_every_other_file_as_before(self):
        # What a package leaves out is the icons, on Linux and macOS, and
        # nothing else; what it stages comes from where it did
        for name, (platform, staged, every, _) in self.plans.items():
            with self.subTest(platform=name):
                left_out = set(every) - set(staged)
                self.assertEqual(left_out, set() if platform.family == 'windows' else ICONS)
                for target, repo_path in staged.items():
                    self.assertEqual(every[target], repo_path)

    def test_the_sample_icons_in_every_package(self):
        # The icons the standalone builder gives a Windows application,
        # built on any platform (revsaveasstandalone, revsblibrary)
        for name, (platform, staged, _, _) in self.plans.items():
            with self.subTest(platform=name):
                for arch in ('x86-64', 'x86-32'):
                    for icon in ('genericapp.ico', 'genericdoc.ico'):
                        self.assertIn('Runtime/Windows/%s/Support/Sample Icons/%s' % (arch, icon), staged)

    def test_the_icons_are_the_root_icons_of_the_ide(self):
        # A new .ico at the IDE's root is decided on here: Windows only, or
        # in every package
        root = {f for f in os.listdir(os.path.join(REPO, 'ide')) if f.lower().endswith('.ico')}
        self.assertEqual(root, ICONS)
        self.assertLessEqual(ICONS, {name for name, _ in layout.ROOT_IDE_FILES})


if __name__ == '__main__':
    unittest.main()
