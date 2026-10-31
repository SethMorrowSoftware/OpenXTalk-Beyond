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

"""The engine's version text names it BeyondEngine (tperry2x, openxtalk.org
p=25816; seth chose "Everywhere" on 2026-10-31): `the version` reads
9.7.1-BeyondEngine where it read 9.7.1-OXT, and the long version ends
"(BeyondEngine)". The build number (25923) and the numbers before the
tag are unchanged, so a script that reads item 1 of the version, or
compares its first characters, sees what it saw before; one that looks
for "OXT" in it does not.

Everything that derives a name from the version text follows it: the web
engine's files (standalone-community-<version>.js), the Linux window
class and the desktop file's StartupWMClass, the server's home folder and
the Community licence file. These tests hold the file "version" to the
new name, and hold the tools that read an engine's version back out of a
binary (make_runtimes_asset's VERSION_RX, which every Standalone in the
runtimes asset must match) and the packager's window class to it, while
still reading an older engine's 9.7.1-OXT.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))

import make_runtimes_asset  # noqa: E402
import package  # noqa: E402


def version_file():
    fields = {}
    with open(os.path.join(REPO, 'version'), encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^\s*(\w+)\s*=\s*(.*?)\s*$', line)
            if m:
                fields[m.group(1)] = m.group(2)
    return fields


class TheVersionFile(unittest.TestCase):
    def test_the_short_version_is_beyondengine(self):
        self.assertEqual(version_file()['BUILD_SHORT_VERSION'], '9.7.1-BeyondEngine')

    def test_the_long_version_is_beyondengine(self):
        self.assertEqual(version_file()['BUILD_LONG_VERSION'], '9.7.1.25923 (BeyondEngine)')

    def test_the_numbers_are_unchanged(self):
        v = version_file()
        self.assertEqual((v['BUILD_MAJOR_VERSION'], v['BUILD_MINOR_VERSION'], v['BUILD_POINT_VERSION'],
                          v['BUILD_REVISION']), ('9', '7', '1', '25923'))


class TheToolsThatReadIt(unittest.TestCase):
    def test_a_standalone_reports_the_whole_name(self):
        found = make_runtimes_asset.VERSION_RX.findall(b'\0engine 9.7.1-BeyondEngine\0')
        self.assertEqual(found, [b'9.7.1-BeyondEngine'])

    def test_an_older_engine_still_reads(self):
        found = make_runtimes_asset.VERSION_RX.findall(b'\x009.7.1-OXT\x00 9.6.3-rc-3\x00 9.6.3\x00')
        self.assertEqual(found, [b'9.7.1-OXT', b'9.6.3-rc-3', b'9.6.3'])

    def test_the_linux_window_class(self):
        # MCStack::sethints: "livecode", the edition, "_", the short version
        # with "." and "-" as "_"; the desktop file's StartupWMClass
        self.assertEqual(package.ide_window_class(REPO), 'livecodecommunity_9_7_1_BeyondEngine')


class TheEngineTest(unittest.TestCase):
    def test_testversion_expects_the_name(self):
        path = os.path.join(REPO, 'tests', 'lcs', 'core', 'engine', 'engine.livecodescript')
        with open(path, encoding='utf-8') as f:
            script = f.read()
        start = script.index('\non TestVersion')
        body = script[start:script.index('\nend TestVersion', start)]
        self.assertIn('item 2 of tItem3 is "BeyondEngine"', body)


if __name__ == '__main__':
    unittest.main()
