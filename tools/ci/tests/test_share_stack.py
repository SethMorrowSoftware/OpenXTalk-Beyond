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

"""File > Share Stack... (ide/Toolset/palettes/share/revsharestack.livecodescript
and revIDEActionShareStack), which packs a stack for the OXT Community
Stacks, the gallery of stacks that play in a web browser
(github.com/SethMorrowSoftware/oxt-community-stacks). What the source can
show without an engine:

  - the window's file is there, a script-only stack with a name of the
    IDE's own, drawn by revLearnKit;
  - the File menu has the item, for a user's stack only, and its pick goes
    to revIDEActionShareStack; the web IDE, which has no Desktop to write
    a package to, leaves it out;
  - revIDEActionShareStack opens that window, does nothing in the web IDE,
    and every question it asks falls back to answer;
  - nothing in the window or the command sends anything anywhere: the one
    address either knows is the forum's, opened in the browser;
  - the window's copy of the gallery's rules (the limits of a listing, the
    licences, the kinds of stack file) is the gallery's, as its
    tools/listing.py and tools/scan.py had them on 2026-11-14. A rule that
    changes there changes here and in this test.

tests/lcs/sharestack/sharestack.livecodescript runs the rules and the
packing in the engine, and the step share-stack of
tools/ci/ui-tour.livecodescript the window itself in the IDE.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
TOOLSET = os.path.join(REPO, 'ide', 'Toolset')
SHARE = os.path.join(TOOLSET, 'palettes', 'share', 'revsharestack.livecodescript')
MENUBAR = os.path.join(TOOLSET, 'palettes', 'menubar', 'revmenubar.livecodescript')
LIBRARY = os.path.join(TOOLSET, 'libraries', 'revidelibrary.8.livecodescript')
WEB = os.path.join(TOOLSET, 'libraries', 'revwebidelibrary.livecodescript')
TOUR = os.path.join(REPO, 'tools', 'ci', 'ui-tour.livecodescript')
ENGINE_TEST = os.path.join(REPO, 'tests', 'lcs', 'sharestack', 'sharestack.livecodescript')

# The gallery's rules (oxt-community-stacks, tools/listing.py LENGTHS,
# LICENCES and the limits of tags, tools/scan.py MAX_FILE_BYTES and
# STACK_EXTENSIONS), as they were on 2026-11-14
GALLERY_LIMITS = {
    'kTitleMin': 2, 'kTitleMax': 60,
    'kAuthorMin': 2, 'kAuthorMax': 40,
    'kAboutMin': 10, 'kAboutMax': 600,
    'kSlugMin': 3, 'kSlugMax': 40,
    'kMaxTags': 5, 'kMaxTagChars': 20,
    'kMaxFileBytes': 25 * 1024 * 1024,
}
GALLERY_LICENCES = {
    'MIT', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'GPL-3.0-only', 'GPL-3.0-or-later',
    'GPL-2.0-or-later', 'LGPL-3.0-or-later', 'MPL-2.0', 'CC0-1.0', 'CC-BY-4.0', 'CC-BY-SA-4.0', 'Unlicense',
}
GALLERY_STACK_EXTENSIONS = {'oxtstack', 'livecode', 'rev', 'livecodescript'}
FORUM = 'https://openxtalk.org/forum/'


def read(path):
    with open(path, encoding='utf-8-sig') as f:
        return f.read()


def handler(text, name):
    """The text of the handler `name` (on, command or function, private
    or not), from its first line to its end line."""
    m = re.search(r'^(?:private +)?(?:on|command|function) +%s\b.*?^end +%s\b' % (re.escape(name), re.escape(name)),
                  text, re.M | re.S)
    if m is None:
        raise AssertionError('no handler %s' % name)
    return m.group(0)


def code(text):
    """The script without its comments (lines that start with -- or #,
    and /* */ blocks), for what a handler does and not what is said of it."""
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return '\n'.join(line for line in text.split('\n') if not re.match(r'\s*(--|#)', line))


def constant(text, name):
    m = re.search(r'^constant +%s += +(.+)$' % re.escape(name), text, re.M)
    if m is None:
        raise AssertionError('no constant %s' % name)
    return m.group(1).strip()


class Window(unittest.TestCase):
    def setUp(self):
        self.text = read(SHARE)

    def test_it_is_a_script_only_stack_of_the_ide(self):
        self.assertTrue(self.text.startswith('script "revShareStack"\n'))
        # (a name that begins with "rev" is one of the IDE's own windows)
        self.assertEqual(os.path.basename(SHARE), 'revsharestack.livecodescript')

    def test_it_is_plain_ascii_with_unix_line_ends(self):
        with open(SHARE, 'rb') as f:
            data = f.read()
        self.assertNotIn(b'\r', data)
        data.decode('ascii')

    def test_it_is_drawn_by_the_kit(self):
        use = handler(self.text, 'ssUseKit')
        self.assertIn('/palettes/learn/revlearnkit.livecodescript', use)
        self.assertIn('set the behavior of me to the long id of stack "revLearnKit"', use)
        self.assertTrue(os.path.isfile(os.path.join(TOOLSET, 'palettes', 'learn', 'revlearnkit.livecodescript')))

    def test_every_colour_and_icon_it_names_is_the_kits(self):
        kit = read(os.path.join(TOOLSET, 'palettes', 'learn', 'revlearnkit.livecodescript'))
        colours = set(re.findall(r'case "([A-Za-z0-9]+)"', handler(kit, 'lkColor')))
        for name in set(re.findall(r'lkColor\("([^"]+)"\)', self.text)):
            self.assertIn(name, colours, 'lkColor("%s") is not a colour of revLearnKit' % name)
        icons = set(re.findall(r'case "([a-z0-9-]+)"', handler(kit, 'lkIconPaths')))
        named = set(re.findall(r'lkIcon\("[^"]+", "([^"]+)"', self.text))
        named |= set(re.findall(r'lkButton\("[^"]+", [^,]+, [^,]+, [^,]+, "[^"]*", "([^"]+)"', self.text))
        self.assertIn('send', named)
        for name in named:
            self.assertIn(name, icons, 'the icon "%s" is not one of revLearnKit' % name)

    def test_the_limits_are_the_gallerys(self):
        for name, value in GALLERY_LIMITS.items():
            self.assertEqual(int(constant(self.text, name)), value, name)
        extensions = constant(self.text, 'kStackExtensions').strip('"').split(',')
        self.assertEqual(set(extensions), GALLERY_STACK_EXTENSIONS)

    def test_the_licences_are_the_gallerys(self):
        body = handler(self.text, 'revShareStackLicences')
        lines = re.findall(r'"([^"|]+)\|([^"|]+)\|([^"|]+)"', body)
        self.assertEqual({line[0] for line in lines}, GALLERY_LICENCES)
        self.assertEqual(len(lines), len(GALLERY_LICENCES), 'a licence is there twice')
        # (the one a new author is given, and the plainest three first)
        self.assertEqual([line[0] for line in lines[:3]], ['MIT', 'CC0-1.0', 'GPL-3.0-or-later'])
        self.assertIn('put "MIT" into sInfo["licence"]', handler(self.text, 'revShareStackShow'))

    def test_the_package_is_one_folder_as_the_gallery_wants_it(self):
        pack = handler(self.text, 'revShareStackPack')
        self.assertIn('put "stacks/" & tSlug & "/" & tVersion & "/" into tPath', pack)
        for name in ('tPath & "listing.json"', 'tPath & tName', 'tPath & "screenshot.png"'):
            self.assertIn('revZipAddItemWithFile tZip, %s' % name, pack)
        self.assertEqual(pack.count('revZipAddItemWithFile'), 3)
        # refused before anything is written
        self.assertLess(pack.index('revShareStackCheck(pStack)'), pack.index('revZipOpenArchive'))
        self.assertLess(pack.index('revShareStackProblems(pInfo)'), pack.index('revZipOpenArchive'))
        # the stack's file is read and never written or saved
        self.assertNotIn('save ', code(pack))
        self.assertNotIn('into url ("binfile:" & tFile)', pack)

    def test_a_stack_the_gallery_refuses_is_refused_here(self):
        check = handler(self.text, 'revShareStackCheck')
        for what in ('the password of tMain is not empty', 'the externals of tMain is not empty',
                     'tExtension is not among the items of kStackExtensions', 'tSize > kMaxFileBytes'):
            self.assertIn(what, check)

    def test_nothing_is_sent_anywhere(self):
        # (the window knows no address at all: the three it names are the
        # beginnings it refuses in what the author typed)
        body = code(self.text)
        for start in ('"http://"', '"https://"', '"ftp://"'):
            self.assertEqual(body.count(start), 1, start)
            body = body.replace(start, '')
        body = body.lower()
        for word in ('launch ', 'open socket', 'post ', 'liburl', 'tsnet', 'shell(', 'open process',
                     'load url', '://', 'http', 'ftp'):
            self.assertNotIn(word, body, word)

    def test_the_window_asks_for_a_promise(self):
        pack = handler(self.text, 'ssPack')
        self.assertIn('not sAgreed', pack)
        self.assertLess(pack.index('not sAgreed'), pack.index('revShareStackPack'))
        self.assertIn('put false into sAgreed', handler(self.text, 'revShareStackShow'))


class Menu(unittest.TestCase):
    def test_the_file_menu_has_it_for_a_users_stack(self):
        menu = handler(read(MENUBAR), 'revMenubarFileMenu')
        self.assertIn('put enableMenuItem("Share Stack...", tIsUserTarget) & return after tFile', menu)
        # with the other ways a stack leaves the IDE, before printing
        self.assertLess(menu.index('"Save as Standalone Application..."'), menu.index('"Share Stack..."'))
        self.assertLess(menu.index('"Share Stack..."'), menu.index('"P&age Setup..."'))

    def test_its_pick_goes_to_the_library(self):
        pick = handler(read(MENUBAR), 'revMenubarFileMenuPick')
        self.assertRegex(pick, r'case "Share Stack\.\.\."\n\s+revIDEActionShareStack the long id of the topStack\n\s+break')

    def test_the_web_ide_leaves_it_out(self):
        web = handler(read(WEB), 'revWebIDEMenu')
        m = re.search(r'case "File"\n(.*?)break', web, re.S)
        self.assertIsNotNone(m)
        left_out = ''.join(re.findall(r'"([^"]*)"', code(m.group(1)))).split(',')
        self.assertIn('Share Stack...', left_out)
        self.assertIn('Save as Standalone Application...', left_out)


class Command(unittest.TestCase):
    def setUp(self):
        self.text = read(LIBRARY)
        self.body = handler(self.text, 'revIDEActionShareStack')

    def test_it_opens_the_window_of_the_toolset(self):
        self.assertIn('revIDESpecialFolderPath("Toolset") & "/palettes/share/revsharestack.livecodescript"', self.body)
        self.assertIn('dispatch "revShareStackShow" to stack tFile with tMain, pFolder', self.body)

    def test_it_does_nothing_in_the_web_ide(self):
        first = code(self.body).split('\n')[2:5]
        self.assertEqual([line.strip() for line in first], ['if revEnvironmentIsWeb() then', 'return empty', 'end if'])

    def test_a_stack_that_is_not_saved_is_asked_about(self):
        self.assertIn('the effective filename of tMain is empty or __shareStackIsEdited(tMain)', self.body)
        self.assertIn('revIDESaveStack tMain', self.body)
        self.assertLess(self.body.index('revIDESaveStack tMain'), self.body.index('dispatch "revShareStackShow"'))

    def test_a_save_that_failed_stops_it(self):
        # revIDESaveStack returns why it did not save (the engine's error,
        # or "Cancelled" at its question about the file's format) and
        # empty when it did. The package holds the file on the disk, so a
        # stack whose changes the user asked to save is not packed without
        # them (#509's review).
        save = handler(self.text, 'revIDESaveStack')
        self.assertIn('return "Cancelled"', save)
        self.assertTrue(save.rstrip().endswith('return tResultLog\nend revIDESaveStack'))
        m = re.search(r'revIDESaveStack tMain\n\s+put the result into tSaved\n(.*?)dispatch "revShareStackShow"',
                      self.body, re.S)
        self.assertIsNotNone(m)
        self.assertRegex(code(m.group(1)), r'if tHadFile and tSaved is not empty then\n\s+return empty\n\s+end if')
        self.assertLess(self.body.index('put the effective filename of tMain is not empty into tHadFile'),
                        self.body.index('revIDESaveStack tMain'))

    def test_every_question_falls_back_to_answer(self):
        # (revIDEKitDialog is false with the Option key down or when its
        # file is missing: the user is still asked, and still told)
        for name in ('revIDEActionShareStack', '__shareStackPacked'):
            asked = code(handler(self.text, name)).split('revIDEKitDialog(')
            self.assertGreater(len(asked), 1, name)
            for after in asked[1:]:
                self.assertRegex(after, r'\n\s+answer (question|information) ', name)

    def test_the_forum_is_the_only_address_and_the_user_opens_it(self):
        packed = code(handler(self.text, '__shareStackPacked'))
        self.assertEqual(re.findall(r'launch url "([^"]+)"', packed), [FORUM])
        self.assertIn('case "Open the Forum"', packed)
        self.assertNotIn('launch url', code(self.body))
        reveal = code(handler(self.text, '__shareStackReveal'))
        self.assertNotIn('url', reveal.lower())


class Tests(unittest.TestCase):
    def test_the_tour_runs_the_window(self):
        tour = read(TOUR)
        steps = constant(tour, 'kSteps').strip('"').split(',')
        self.assertIn('share-stack', steps)
        step = handler(tour, 'tour_share_stack')
        self.assertIn('revIDEActionShareStack tStack, tFolder', step)
        for shot in ('24c2-share-stack', '24c3-share-stack-filled', '24c4-share-stack-packed'):
            self.assertIn('"%s"' % shot, tour)

    def test_the_engine_tests_are_there(self):
        tests = read(ENGINE_TEST)
        for name in ('TestSlug', 'TestProblems', 'TestLicences', 'TestListing', 'TestCheck', 'TestPack'):
            self.assertIn('on %s\n' % name, tests)


if __name__ == '__main__':
    unittest.main()
