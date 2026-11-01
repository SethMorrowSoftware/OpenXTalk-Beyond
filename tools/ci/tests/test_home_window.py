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

"""OXT-Beyond Home (ide/Toolset/palettes/home/revhub.livecodescript), the
one window of Home's welcome, the xTalk Academy and Learn's how-to lessons,
guides and examples, from 0.2.7-rc.6.12, and what left the package with it.
What the source and the packaging can show without an engine:

  - Home's five places, each drawn by a stack that is there, and every
    name the IDE's ways in use (Help's items, those before Home included,
    the toolbar's, the old palettes') going to the place it names;
  - Help's items, and the old names still picked by a script;
  - the classic stacks gone from ide/ (and from every package, and the
    web IDE), their mirrors in stack-scripts/ with them, and no patch of
    tools/oxt/ide-stack-patches left pointing at one;
  - every example of Learn's gallery that the IDE has: its remaster
    installed, and the original kept in tools/examples/originals, which
    the builders read; every group an example names is a group of the
    gallery;
  - the Stack Player's course and tour left out alike by Learn's gallery,
    the package and the web IDE.

tools/ci/ui-tour.livecodescript (steps home-ways-in and home-places) runs
the window itself in the IDE.

  python3 -m unittest discover -s tools/ci/tests
"""

import glob
import os
import re
import sys
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))

import build_site  # noqa: E402
import layout  # noqa: E402
import package  # noqa: E402

IDE = os.path.join(REPO, 'ide')
TOOLSET = os.path.join(IDE, 'Toolset')
HUB = os.path.join(TOOLSET, 'palettes', 'home', 'revhub.livecodescript')
LEARN = os.path.join(TOOLSET, 'palettes', 'learn', 'revlearn.livecodescript')
MENUBAR = os.path.join(TOOLSET, 'palettes', 'menubar', 'revmenubar.livecodescript')
ORIGINALS = os.path.join(REPO, 'tools', 'examples', 'originals')

# What left the package with Home (paths below ide/)
REMOVED = (
    'Toolset/palettes/welcome',
    'Toolset/palettes/start center',
    'Toolset/palettes/tutorial',
    'Resources/Start Center',
    'Resources/Mobile Examples',
    'Resources/Examples/xTalk Suite',
    'Resources/Examples/demos.oxtstack',
    'Resources/Examples/Text To Image.oxtstack',
)

# The places, and the stack that draws each
PLACES = {'home': 'revWebHome', 'academy': 'revAcademy', 'howto': 'revLearn',
          'guides': 'revLearn', 'examples': 'revLearn'}

# The names the IDE's ways in give Home (revHubShow, revHubGo), and the
# place each must open
NAMES = {
    'home': 'home', 'welcome': 'home', 'start center': 'home', '': 'home',
    'academy': 'academy', 'xTalk Academy': 'academy', 'tutorials': 'academy', 'tutorial': 'academy',
    'howto': 'howto', 'How-to': 'howto', 'lessons': 'howto', 'Lessons': 'howto',
    'guides': 'guides', 'Guides': 'guides',
    'examples': 'examples', 'Examples': 'examples', 'demos': 'examples', 'Demos': 'examples',
    'Sample Stacks': 'examples',
}


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def handler(text, name):
    """The text of the handler or function name in a script."""
    m = re.search(r'^(?:private\s+)?(?:on|command|function)\s+%s\b.*?^end\s+%s\s*$' % (name, name),
                  text, re.M | re.S)
    if not m:
        raise AssertionError('no handler %s' % name)
    return m.group(0)


def code(text):
    """A script without its comments (-- and # to the end of a line, and
    /* */ blocks), its strings kept."""
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    out = []
    for line in text.splitlines():
        quoted, cut = False, len(line)
        for i, c in enumerate(line):
            if c == '"':
                quoted = not quoted
            elif not quoted and (line.startswith('--', i) or c == '#'):
                cut = i
                break
        out.append(line[:cut])
    return '\n'.join(out)


def strings(text):
    """The string literals in a piece of script, in order, its comments
    left out."""
    return re.findall(r'"([^"]*)"', code(text))


def hub_place(name):
    """revHubPlace, read from its switch: the place a name stands for."""
    body = handler(read(HUB), 'revHubPlace')
    want = ' '.join(name.split()).lower()
    cases = []
    for line in body.splitlines():
        line = line.strip()
        m = re.match(r'case "([^"]*)"$', line)
        if m:
            cases.append(m.group(1))
            continue
        m = re.match(r'return "([^"]*)"$', line)
        if m and cases:
            if want in cases:
                return m.group(1)
            cases = []
            continue
        if line == 'default':
            cases = None
        elif m and cases is None:
            return m.group(1)
    raise AssertionError('revHubPlace has no default')


def table_lines(text, function):
    """The lines a table function builds, as one string each ("a" & "b"
    joined): put "..." & ... after tTable."""
    body = handler(text, function)
    lines, current = [], ''
    for line in body.splitlines():
        s = line.strip()
        if not s.startswith('put ') and not current:
            continue
        current += ''.join(strings(s))
        if 'after tTable' in s:
            if current:
                lines.append(current)
            current = ''
    return lines


class HomePlaces(unittest.TestCase):

    def test_five_places_each_drawn_by_a_stack_that_is_there(self):
        places = strings(handler(read(HUB), 'hbPlaces'))
        keys = [p.split('|')[0] for p in places]
        self.assertEqual(keys, ['home', 'academy', 'howto', 'guides', 'examples'])
        for p in places:
            self.assertEqual(len(p.split('|')), 4, p)
        files = {
            'revWebHome': 'palettes/web home/revwebhome.livecodescript',
            'revAcademy': 'palettes/academy/revacademy.livecodescript',
            'revLearn': 'palettes/learn/revlearn.livecodescript',
            'revLearnKit': 'palettes/learn/revlearnkit.livecodescript',
        }
        module = handler(read(HUB), 'hbModuleFile')
        for stack, path in files.items():
            with self.subTest(stack=stack):
                self.assertIn(path, module)
                self.assertTrue(os.path.isfile(os.path.join(TOOLSET, path)), path)
                first = read(os.path.join(TOOLSET, path)).splitlines()[0]
                self.assertEqual(first, 'script "%s"' % stack)
        modules = handler(read(HUB), 'hbModule')
        self.assertIn('return "revWebHome"', modules)
        self.assertIn('return "revAcademy"', modules)
        self.assertIn('return "revLearn"', modules)

    def test_every_name_goes_to_its_place(self):
        for name, place in NAMES.items():
            with self.subTest(name=name):
                self.assertEqual(hub_place(name), place)

    def test_each_hosted_stack_answers_the_four_messages(self):
        for path in ('palettes/web home/revwebhome.livecodescript',
                     'palettes/academy/revacademy.livecodescript',
                     'palettes/learn/revlearn.livecodescript'):
            text = read(os.path.join(TOOLSET, path))
            for message in ('revHubAttach', 'revHubStart', 'revHubNavigate', 'revHubDetach'):
                with self.subTest(stack=path, message=message):
                    self.assertRegex(text, r'(?m)^on %s\b' % message)

    def test_the_window_fits_the_smallest_screens(self):
        text = read(HUB)
        width = int(re.search(r'^constant kMinWidth = (\d+)', text, re.M).group(1))
        height = int(re.search(r'^constant kMinHeight = (\d+)', text, re.M).group(1))
        # the runners' and the smallest supported screens are 1024 by 768
        self.assertLessEqual(width, 1024)
        self.assertLessEqual(height, 768 - 100)


class WaysIn(unittest.TestCase):

    def test_help_lists_the_places(self):
        menu = handler(read(MENUBAR), 'revMenubarHelpMenu')
        items = strings(menu)
        for name in ('xTalk Academy', 'How-to', 'Guides', 'Examples'):
            with self.subTest(item=name):
                self.assertIn(name, items)
        # in the order of Home's sidebar
        order = [items.index(n) for n in ('xTalk Academy', 'How-to', 'Guides', 'Examples')]
        self.assertEqual(order, sorted(order))
        for old in ('Lessons', 'Demos'):
            self.assertNotIn(old, items)

    def test_old_and_new_help_names_are_picked(self):
        pick = handler(read(MENUBAR), 'revMenubarHelpMenuPick')
        for name in ('xTalk Academy', 'How-to', 'Lessons', 'Guides', 'Examples', 'Demos',
                     'Welcome to OXT-Beyond'):
            with self.subTest(item=name):
                self.assertIn('case "%s"' % name, pick)

    def test_the_ways_in_try_home_first(self):
        menubar = read(MENUBAR)
        for name, place in (('tOpenHome', 'home'), ('tOpenAcademy', 'academy')):
            with self.subTest(handler=name):
                self.assertIn('revMenubarOpenHub("%s")' % place, handler(menubar, name))
        self.assertIn('revMenubarOpenHub(pSection)', handler(menubar, 'revMenubarOpenLearn'))
        self.assertIn('revMenubarOpenHub("academy")', handler(menubar, 'revMenubarMenuButtonClicked'))
        self.assertIn('/home/revhub.livecodescript"', handler(menubar, 'revMenubarOpenHub'))
        library = read(os.path.join(TOOLSET, 'libraries', 'revidelibrary.8.livecodescript'))
        self.assertIn('revIDEOpenHome("home")', handler(library, 'revIDEOpenPalette'))
        self.assertIn('palettes/home/revhub.livecodescript', handler(library, 'revIDEOpenHome'))
        web = read(os.path.join(TOOLSET, 'libraries', 'revwebidelibrary.livecodescript'))
        self.assertIn('revHubShow', handler(web, 'revWebIDEShowHome'))
        learn = read(LEARN)
        self.assertIn('leOpenInHome', handler(learn, 'revLearnShow'))
        academy = read(os.path.join(TOOLSET, 'palettes', 'academy', 'revacademy.livecodescript'))
        self.assertIn('acOpenInHome', handler(academy, 'revAcademyShow'))

    def test_the_old_palette_names_still_name_palettes(self):
        library = read(os.path.join(TOOLSET, 'libraries', 'revidelibrary.8.livecodescript'))
        palettes = strings(handler(library, 'revIDEAvailablePalettes'))
        joined = ''.join(palettes).split(',')
        # a script or plugin that opens them gets Home's welcome
        self.assertIn('Start Center', joined)
        self.assertIn('Welcome', joined)


class WhatLeftThePackage(unittest.TestCase):

    def test_gone_from_the_repository(self):
        for path in REMOVED:
            with self.subTest(path=path):
                self.assertFalse(os.path.exists(os.path.join(IDE, *path.split('/'))))

    def test_gone_from_every_package(self):
        for name, platform in package.PLATFORMS.items():
            staged, problems = package.ide_pairs(REPO, platform)
            with self.subTest(platform=name):
                self.assertEqual(problems, [])
                self.assertEqual(platform.ide_include, ())
                for target, _ in staged:
                    for path in REMOVED:
                        self.assertFalse(target == path or target.startswith(path + '/'), target)
                    # of the examples, only the remasters, the Stack
                    # Player's stacks and the video Play a Video plays
                    if target.startswith('Resources/Examples/'):
                        self.assertTrue(target.startswith(('Resources/Examples/Remastered/',
                                                           'Resources/Examples/Showcase/'))
                                        or target == 'Resources/Examples/neville-segments.mp4', target)

    def test_no_mirror_without_its_stack(self):
        root = os.path.join(REPO, 'stack-scripts')
        for folder in glob.glob(os.path.join(root, '**', '*.bst'), recursive=True):
            stack = os.path.relpath(folder, root)[:-len('.bst')]
            with self.subTest(stack=stack):
                self.assertTrue(os.path.isfile(os.path.join(REPO, stack)), stack)

    def test_no_patch_without_its_stack(self):
        for path in glob.glob(os.path.join(REPO, 'tools', 'oxt', 'ide-stack-patches', '*.txt')):
            for line in read(path).splitlines():
                if line.startswith('file: '):
                    target = line[len('file: '):]
                    with self.subTest(patch=os.path.basename(path)):
                        self.assertTrue(os.path.isfile(os.path.join(IDE, *target.split('/'))), target)


class Examples(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.learn = read(LEARN)
        cls.table = [line.split('|') for line in table_lines(cls.learn, 'leExampleTable')]

    def test_the_table_reads(self):
        self.assertGreaterEqual(len(self.table), 10)
        for row in self.table:
            self.assertGreaterEqual(len(row), 10, row)

    def test_every_remaster_installed_and_every_original_kept(self):
        for row in self.table:
            with self.subTest(example=row[1]):
                self.assertTrue(os.path.isfile(os.path.join(IDE, *row[8].split('/'))), row[8])
                # the original is not installed, and is kept for its builder
                self.assertFalse(os.path.isfile(os.path.join(IDE, *row[0].split('/'))), row[0])
                kept = os.path.join(ORIGINALS, *row[0].split('/')[-2:]) \
                    if 'Start Center' in row[0] else os.path.join(ORIGINALS, os.path.basename(row[0]))
                self.assertTrue(os.path.isfile(kept), kept)

    def test_every_builder_finds_its_original(self):
        for path in glob.glob(os.path.join(REPO, 'tools', 'examples', '*.livecodescript')):
            text = read(path)
            for m in re.finditer(r'put tRepo & "([^"]*)" into tOriginal', text):
                with self.subTest(builder=os.path.basename(path)):
                    self.assertTrue(os.path.isfile(REPO + m.group(1)), m.group(1))

    def test_every_group_is_in_the_gallery(self):
        groups = re.findall(r'(?:^|\n|")([a-z]+)\|', '\n'.join(strings(handler(self.learn, 'leExampleGroups'))))
        self.assertEqual(groups, ['start', 'web', 'small', 'tours', 'apps', 'samples'])
        for row in self.table:
            with self.subTest(example=row[1]):
                self.assertIn(row[4], groups)
        info = '\n'.join(strings(handler(self.learn, 'leShowcaseInfo')))
        for group in re.findall(r'(?:^|\n)([a-z]+)\|', info):
            self.assertIn(group, groups)

    def test_the_players_course_and_tour_left_out_alike(self):
        self.assertEqual(set(package.SHOWCASE_LEFT_OUT), set(build_site.SHOWCASE_LEFT_OUT))
        names = [n for n, _ in package.showcase_stacks(REPO)]
        self.assertTrue(names)
        for left in package.SHOWCASE_LEFT_OUT:
            self.assertNotIn(left, names)
            self.assertIn(left[:-len('.oxtstack')], handler(self.learn, 'leShowcaseTable'))
        filtered = re.search(r'repeat for each item tName in "([^"]*)"\s*\n\s*filter tFiles without',
                             handler(self.learn, 'leShowcaseTable'))
        self.assertIsNotNone(filtered)
        self.assertEqual({n + '.oxtstack' for n in filtered.group(1).split(',')},
                         set(package.SHOWCASE_LEFT_OUT))


if __name__ == '__main__':
    unittest.main()
