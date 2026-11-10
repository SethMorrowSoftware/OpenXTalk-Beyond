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

"""The web engine's home folder, as the docs tell it.

Since 0.2.7-rc.6.2 the web engine's home folder (specialFolderPath("home"))
is /openxtalk, and /livecode, its old name, is a link to it (em-system.cpp,
em-system.js). The Deploying Your Application guide still said /livecode
until rc.6.17. This holds every doc that names the folder to the name the
engine uses, read from the engine's own sources, and holds the old name to
the engine as well, so a change to either side fails here.

It also keeps the guide's prose free of the old product name: "LiveCode"
may appear only in code (backticks: `livecodeStandalone`, the page's
`liveCode` object, `com.livecode.emscripten`, all real names that scripts
and pages use) and in link addresses (lessons.livecode.com).

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
GUIDE = ('ide', 'Documentation', 'guides', 'Deploying Your Application.md')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def engine_home():
    m = re.search(r'#define kMCEmscriptenStandardFolderHome "([^"]+)"',
                  read('engine', 'src', 'em-system.cpp'))
    return m.group(1)


def engine_legacy_home():
    m = re.search(r"_legacyFolder: '([^']+)'", read('engine', 'src', 'em-system.js'))
    return m.group(1)


def prose(markdown):
    """The text a reader sees as words: code spans, indented code blocks
    and link addresses removed."""
    lines = [l for l in markdown.splitlines() if not l.startswith('    ')]
    text = '\n'.join(lines)
    text = re.sub(r'`[^`]*`', '', text)
    text = re.sub(r'\]\([^)]*\)', ']', text)
    return text


class TheEngine(unittest.TestCase):

    def test_the_home_folder_is_openxtalk(self):
        self.assertEqual(engine_home(), '/openxtalk')

    def test_the_old_name_is_still_a_link(self):
        # Old stacks and saved paths name /livecode: it must keep working.
        self.assertEqual(engine_legacy_home(), '/livecode')
        self.assertIn('"~livecode"', read('engine', 'src', 'em-system.cpp'))


class TheDeployingGuide(unittest.TestCase):

    def setUp(self):
        self.text = read(*GUIDE)

    def test_home_names_the_engines_folder(self):
        m = re.search(r'`specialFolderPath\("home"\)` is `([^`]+)`', self.text)
        self.assertIsNotNone(m, 'the guide no longer says what the home folder is')
        self.assertEqual(m.group(1), engine_home())

    def test_the_old_name_is_told_as_the_old_name(self):
        # Every mention of /livecode in the guide is the "until rc.6.2" note.
        legacy = '`%s`' % engine_legacy_home()
        for m in re.finditer(re.escape(legacy), self.text):
            around = self.text[max(0, m.start() - 300):m.end() + 300]
            self.assertIn('Until 0.2.7-rc.6.2', around)

    def test_no_livecode_in_the_prose(self):
        found = re.findall(r'.{0,30}\blive\s*code\b.{0,30}', prose(self.text), re.I)
        self.assertEqual(found, [])


class TheOtherDocs(unittest.TestCase):

    def test_the_dictionary_entry(self):
        text = read('docs', 'dictionary', 'function', 'specialFolderPath.lcdoc')
        m = re.search(r'\* "home": Always `([^`]+)`', text)
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1), engine_home())

    def test_the_stack_players_folder(self):
        self.assertIn('`%s/Documents/Stack Player`' % engine_home(),
                      read('tools', 'web-player', 'README.md'))

    def test_the_stack_player_trims_the_folder_from_errors(self):
        # Its error toast cuts the library folder from paths; it must match
        # the folder the engine uses now, and the old name too.
        page = read('tools', 'web-player', 'index.html')
        m = re.search(r"text\.replace\(/(.+?)/g, ''\), 'error'", page)
        self.assertIsNotNone(m)
        pattern = m.group(1).replace('\\/', '/')
        for home in (engine_home(), engine_legacy_home()):
            path = home + '/Documents/Stack Player/a.oxtstack'
            self.assertEqual(re.sub(pattern, '', path), 'a.oxtstack', home)


if __name__ == '__main__':
    unittest.main()
