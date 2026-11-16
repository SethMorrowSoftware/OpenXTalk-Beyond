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
"""A new entry in the Extension Manager's list never takes the index of
one that is there (Emily-Elizabeth, forum, 2026-11-15). LiveCode gave a
new entry "the number of elements of sExtensions + 1"; once an entry had
gone (an uninstall, an older version replaced, a package installed again
from another folder), that was the index of the newest entry, and the next
install wrote over it. The Box2Dxt Kit, installed right after Box2D, took
Box2D's entry and was refused with "Dependency org.openxtalk.box2dxt not
available". The four places that make an entry ask __extensionNewCacheIndex
for one past the highest index in use, which is the same number as before
when nothing has gone. ide/tests/extensionmanager/cacheslot runs it in the
IDE.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
LIBRARY = os.path.join(REPO, 'ide', 'Toolset', 'libraries', 'revideextensionlibrary.livecodescript')
IDE_TEST = os.path.join(REPO, 'ide', 'tests', 'extensionmanager', 'cacheslot.livecodescript')


def read(path):
    with open(path, encoding='utf-8-sig') as f:
        return f.read()


def handler(text, name):
    m = re.search(r'^[ \t]*(?:private[ \t]+)?(?:command|on|function)[ \t]+%s\b(.*?)^[ \t]*end[ \t]+%s\b'
                  % (re.escape(name), re.escape(name)), text, re.M | re.S)
    if m is None:
        raise AssertionError('no handler ' + name)
    return m.group(1)


def code(body):
    return '\n'.join(line.split('--', 1)[0].split('#', 1)[0] for line in body.splitlines())


def new_index(keys):
    """__extensionNewCacheIndex, in Python, checked against its source."""
    return max([k for k in keys if isinstance(k, int)] + [0]) + 1


class ExtensionCacheSlotTest(unittest.TestCase):
    def setUp(self):
        self.text = read(LIBRARY)

    def test_no_count_plus_one(self):
        self.assertNotRegex(code(self.text), r'number of elements of sExtensions\s*\+\s*1')

    def test_every_new_entry_asks_for_a_fresh_index(self):
        for name in ('__extensionInstallPackage', '__extensionDownloadBegin',
                     '__revIDELCBExtensionLoad', '__revIDELCSExtensionLoad'):
            self.assertIn('put __extensionNewCacheIndex() into tCacheIndex', code(handler(self.text, name)), name)

    def test_function(self):
        body = code(handler(self.text, '__extensionNewCacheIndex'))
        self.assertIn('repeat for each key tExtensionID in sExtensions', body)
        self.assertIn('if tExtensionID is an integer and tExtensionID > tMax then', body)
        self.assertIn('return tMax + 1', body)
        # with no gap it is LiveCode's number, so nothing else moves
        for n in range(0, 6):
            self.assertEqual(new_index(list(range(1, n + 1))), n + 1)
        # the case that lost Box2D: C, Box2D, then C uninstalled
        self.assertEqual(new_index([1, 3]), 4)
        self.assertNotEqual(len([1, 3]) + 1, 4)

    def test_ide_test(self):
        ide = read(IDE_TEST)
        self.assertIn('on TestInstallAfterUninstall', ide)
        self.assertIn('revIDEExtensionUninstall kC', ide)
        self.assertIn('"A is still in the list after B installs"', ide)
        # B must not require A: a regression would stop the run at the
        # install's error dialog instead of failing
        self.assertNotIn('<requires', ide)


if __name__ == '__main__':
    unittest.main()
