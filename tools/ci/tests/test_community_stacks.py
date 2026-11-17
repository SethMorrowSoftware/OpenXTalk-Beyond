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

"""File > Community Stacks...
(ide/Toolset/palettes/community/revcommunitystacks.livecodescript,
revIDEActionCommunityStacks and revIDECommunityStacksGetCopy), the gallery
of stacks that people share (github.com/oxt-stacks/oxt-community-stacks)
in the IDE. What the source can show without an engine:

  - the window's file is there, a script-only stack with a name of the
    IDE's own, drawn by revLearnKit;
  - the File menu has the item and its pick goes to
    revIDEActionCommunityStacks; the web IDE leaves it out;
  - the key the gallery's list is checked with is the gallery's: the one
    line of signing-key.pub in its repository, as it was on 2026-11-17.
    A new key there is a new key here and in this test, and nowhere else;
  - the gallery's address is its own site, over https, and never
    openxtalk.org or the maintainer's own pages, where a shared stack
    must never be served;
  - the list is checked before it is read, and nothing of it is shown
    when the check fails or cannot be made;
  - no address is taken from the list: the one thing the window opens in
    the browser is the gallery's site and a path under it;
  - a copy is asked about first, and opened with messages locked;
  - the limits it holds a list to are the gallery's (tools/scan.py and
    tools/listing.py there, 2026-11-17).

tests/lcs/communitystacks/communitystacks.livecodescript runs the
checking, the rules and the unpacking in the engine, and the step
community-stacks of tools/ci/ui-tour.livecodescript the window itself in
the IDE.

  python3 -m unittest discover -s tools/ci/tests
"""

import base64
import os
import re
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
TOOLSET = os.path.join(REPO, 'ide', 'Toolset')
WINDOW = os.path.join(TOOLSET, 'palettes', 'community', 'revcommunitystacks.livecodescript')
MENUBAR = os.path.join(TOOLSET, 'palettes', 'menubar', 'revmenubar.livecodescript')
LIBRARY = os.path.join(TOOLSET, 'libraries', 'revidelibrary.8.livecodescript')
WEB = os.path.join(TOOLSET, 'libraries', 'revwebidelibrary.livecodescript')
TOUR = os.path.join(REPO, 'tools', 'ci', 'ui-tour.livecodescript')
ENGINE_TEST = os.path.join(REPO, 'tests', 'lcs', 'communitystacks', 'communitystacks.livecodescript')
GUIDE = os.path.join(REPO, 'ide', 'Documentation', 'guides', 'The IDE.md')

# signing-key.pub of github.com/oxt-stacks/oxt-community-stacks (its
# commit 3e9be8f, 2026-11-17): the public half of the key that signs the
# gallery's list. The secret half is a secret of that repository alone.
GALLERY_PUBLIC_KEY = '1CV25/gGPnbu3x57BfSyI8DKKvfUVUpvxJFN7YMZ+NA='
# Where the gallery is served: an address of its own, shared with nothing
# (docs/MAINTAINING.md there, "Where the gallery may live")
GALLERY_SITE = 'https://oxt-stacks.github.io/oxt-community-stacks/'
# The gallery's limits, tools/scan.py (MAX_FILES, MAX_FILE_BYTES,
# MAX_TOTAL_BYTES, STACK_EXTENSIONS) as they were on 2026-11-17
GALLERY_LIMITS = {
    'kMaxFiles': 200,
    'kMaxFileBytes': 25 * 1024 * 1024,
    'kMaxDownloadBytes': 50 * 1024 * 1024,
}
GALLERY_STACK_EXTENSIONS = {'oxtstack', 'livecode', 'rev', 'livecodescript'}
GALLERY_LICENCES = {
    'MIT', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause', 'GPL-3.0-only', 'GPL-3.0-or-later',
    'GPL-2.0-or-later', 'LGPL-3.0-or-later', 'MPL-2.0', 'CC0-1.0', 'CC-BY-4.0', 'CC-BY-SA-4.0', 'Unlicense',
}


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
        self.text = read(WINDOW)
        self.code = code(self.text)

    def test_it_is_a_script_only_stack_of_the_ide(self):
        self.assertTrue(self.text.startswith('script "revCommunityStacks"\n'))
        self.assertIn('set the behavior of me to the long id of stack "revLearnKit"', self.text)
        self.text.encode('ascii')

    def test_the_key_is_the_gallerys(self):
        self.assertEqual(constant(self.text, 'kPublicKey'), '"%s"' % GALLERY_PUBLIC_KEY)
        self.assertEqual(len(base64.b64decode(GALLERY_PUBLIC_KEY, validate=True)), 32)
        # (and it is written in one place)
        self.assertEqual(self.text.count(GALLERY_PUBLIC_KEY), 1)

    def test_the_site_is_the_gallerys_own_address(self):
        self.assertEqual(constant(self.text, 'kSite'), '"%s"' % GALLERY_SITE)
        # (the one address in the script: nothing else is ever asked for
        # or opened)
        self.assertEqual({found.rstrip('.') for found in re.findall(r'https?://[^\s"]*', self.code)},
                         {GALLERY_SITE, 'https://'})
        for never in ('openxtalk.org', 'sethmorrowsoftware'):
            self.assertNotIn(never, self.code.lower())

    def test_a_site_is_https_or_a_folder_for_a_test(self):
        site = code(handler(self.text, 'csSite'))
        self.assertIn('pSite begins with "https://"', site)
        self.assertIn('there is a folder pSite', site)
        self.assertNotIn('http://', site)
        fetch = code(handler(self.text, 'csFetch'))
        self.assertIn('if pSite begins with "https://" then', fetch)
        # (the request itself: no word of the user or this computer)
        get = code(handler(self.text, 'revCommunityStacksHttpGet'))
        self.assertEqual(re.findall(r'set the httpHeaders to (.+)', get)[0],
                         '"User-Agent: OXT-Beyond" & return & "Connection: close"')
        self.assertIn('set the httpHeaders to tOldHeaders', get)

    def test_the_list_is_checked_before_it_is_read(self):
        load = code(handler(self.text, 'revCommunityStacksLoad'))
        check = load.index('revCommunityStacksVerify(tIndex, tSignature, pPublicKey)')
        parse = load.index('revCommunityStacksParse(tIndex)')
        self.assertLess(check, parse)
        self.assertEqual(load.count('revCommunityStacksParse('), 1)
        # every way out before the list is read carries a problem
        before = load[:parse]
        self.assertEqual(before.count('return tOut'), before.count('into tOut["problem"]'))
        # no signature is a refusal, said as what it is
        self.assertIn('put true into tOut["unsigned"]', load)

    def test_the_check_fails_closed(self):
        verify = code(handler(self.text, 'revCommunityStacksVerify'))
        self.assertIn('put sxSignVerifyDetached(tSignature, pIndex, tKey) into tGood', verify)
        # believed only on true: an error, or anything else, is a refusal
        self.assertIn('if tGood is not true then', verify)
        self.assertRegex(verify, r'catch tError\s+return "')
        self.assertTrue(verify.rstrip().endswith('return empty\nend revCommunityStacksVerify'))
        self.assertEqual(verify.count('return empty'), 1)

    def test_no_address_comes_from_the_list(self):
        launch = code(handler(self.text, 'csLaunch'))
        self.assertIn('launch url (tSite & pPath)', launch)
        self.assertIn('if not (tSite begins with "https://") then', launch)
        self.assertEqual(self.code.count('launch url'), 1)
        clean = code(handler(self.text, 'csCleanEntry'))
        # a page of the list is a path under the stack's own folder
        self.assertIn('tValue begins with ("s/" & tSlug & "/")', clean)
        self.assertIn('if not csIsText(tValue) or not (tValue begins with tPrefix) then', clean)

    def test_a_copy_is_only_the_listed_bytes(self):
        get = code(handler(self.text, 'revCommunityStacksGet'))
        whole = get.index('csSha256(tZip) is not pEntry["sha256"]')
        each = get.index('csSha256(tData) is not pEntry["files"][tIndex]["sha256"]')
        write = get.index('csWrite(tDest["folder"], pEntry, tFiles)')
        self.assertLess(whole, each)
        self.assertLess(each, write)
        # only the files the list names are taken out of the download
        self.assertNotIn('revZipEnumerateItems', self.code)
        self.assertNotIn('revZipExtractItemToFile', self.code)
        # and an existing folder is never written into
        self.assertIn('if there is a folder pFolder or there is a file pFolder then', code(handler(self.text, 'csWrite')))

    def test_a_copy_opens_without_running(self):
        opened = code(handler(self.text, 'revCommunityStacksOpenToRead'))
        lock = opened.index('lock messages')
        go = opened.index('go stack pFile')
        unlock = opened.index('unlock messages')
        self.assertLess(lock, go)
        self.assertLess(go, unlock)
        self.assertIn('revIDESetTool "pointer"', opened)
        self.assertIn('csIsIDEName(tName)', opened)
        # the only place a stack of the gallery is opened
        self.assertEqual(self.code.count('go stack'), 1)

    def test_the_limits_are_the_gallerys(self):
        for name, value in GALLERY_LIMITS.items():
            self.assertEqual(int(constant(self.text, name)), value, name)
        self.assertEqual(set(constant(self.text, 'kStackExtensions').strip('"').split(',')), GALLERY_STACK_EXTENSIONS)
        licences = handler(self.text, 'csLicences')
        self.assertEqual(set(re.findall(r'"([A-Za-z0-9.+-]+)\|', licences)), GALLERY_LICENCES)

    def test_words_of_the_list_are_escaped_where_they_are_drawn(self):
        for name in ('csEntryHtml', 'csProblemHtml', 'csFillIndex'):
            body = code(handler(self.text, name))
            for shown in re.findall(r'(?:pEntry|sStacks\[tIndex\]|sProblem)\["(?:title|author|description|problem)"\]', body):
                self.assertIn('lkEscape(%s)' % shown, body, name)
        entry = code(handler(self.text, 'csEntryHtml'))
        self.assertIn('lkEscape(tTags)', entry)
        self.assertIn('lkEscape(item 1 of tLine)', entry)


class Menu(unittest.TestCase):
    def test_the_file_menu_has_it(self):
        menubar = read(MENUBAR)
        self.assertIn('put "Community Stacks..." & return after tFile', menubar)
        share = menubar.index('put enableMenuItem("Share Stack...", tIsUserTarget) & return after tFile')
        item = menubar.index('put "Community Stacks..." & return after tFile')
        self.assertLess(share, item)
        self.assertLess(item - share, 400)
        pick = re.search(r'case "Community Stacks\.\.\."\n\s+(.+)\n\s+break', menubar)
        self.assertIsNotNone(pick)
        self.assertEqual(pick.group(1), 'revIDEActionCommunityStacks')

    def test_the_web_ide_leaves_it_out(self):
        web = handler(read(WEB), 'revWebIDEMenu')
        self.assertRegex(web, r'"Share Stack\.\.\.,Community Stacks\.\.\.,Quit,Exit" into tLeaveOut')

    def test_the_guide_says_what_it_does(self):
        guide = read(GUIDE)
        row = [line for line in guide.split('\n') if line.startswith('| **Community Stacks...**')]
        self.assertEqual(len(row), 1)
        for said in ('browser', 'signature', 'copy'):
            self.assertIn(said, row[0])


class Actions(unittest.TestCase):
    def setUp(self):
        self.text = read(LIBRARY)

    def test_the_action_opens_the_window_and_not_in_the_web_ide(self):
        action = code(handler(self.text, 'revIDEActionCommunityStacks'))
        self.assertIn('if revEnvironmentIsWeb() then\n      return empty', action)
        self.assertIn('dispatch "revCommunityStacksShow" to stack tFile with pSite, pPublicKey', action)
        self.assertIn('"/palettes/community/revcommunitystacks.livecodescript"',
                      handler(self.text, '__communityStacksFile'))

    def test_a_copy_is_asked_about_first(self):
        copy = code(handler(self.text, 'revIDECommunityStacksGetCopy'))
        ask = copy.index('put "Get a copy of this stack?" into tSpec["heading"]')
        agreed = copy.index('if tChoice is not "Get a Copy" then\n      return empty')
        fetch = copy.index('dispatch "revCommunityStacksGet" to stack tFile with pEntry, pFolder, pSite')
        opened = copy.index('dispatch "revCommunityStacksOpenToRead" to stack tFile with tResult')
        self.assertLess(ask, agreed)
        self.assertLess(agreed, fetch)
        self.assertLess(fetch, opened)
        # it says that a stack is a program, and where to try one
        self.assertIn('A stack is a program.', copy)
        self.assertIn('play it in your browser', copy)
        # opening is the user's choice, and what follows is said
        self.assertIn('case "Open It to Look"', copy)
        self.assertIn('its scripts run when you choose the browse tool', copy)
        # nothing here opens the browser or any address
        self.assertNotIn('launch url', copy)
        self.assertNotIn('://', copy)

    def test_every_question_falls_back_to_answer(self):
        copy = code(handler(self.text, 'revIDECommunityStacksGetCopy'))
        self.assertEqual(copy.count('if not revIDEKitDialog(tSpec, tChoice) then'), 2)
        self.assertEqual(copy.count('answer information'), 2)
        say = code(handler(self.text, '__communityStacksSay'))
        self.assertIn('if not revIDEKitDialog(tSpec, tChoice) then\n      answer information', say)


class Tests(unittest.TestCase):
    def test_the_tour_runs_the_window(self):
        tour = read(TOUR)
        steps = constant(tour, 'kSteps').strip('"').split(',')
        self.assertIn('community-stacks', steps)
        self.assertEqual(steps.index('community-stacks'), steps.index('share-stack') + 1)
        step = handler(tour, 'tour_community_stacks')
        self.assertIn('revIDEActionCommunityStacks tSite, tKey', step)
        self.assertIn('revIDECommunityStacksGetCopy tEntry, tSite, tCopies', step)
        # a packaged IDE has SodiumXT, and the step fails when it is not loaded
        self.assertIn('if tInstalled and not tHave then\n         throw', step)
        # the refusals it checks
        for refused in ('a list with no signature was shown', 'a list changed after it was signed was shown',
                        'a download that was changed was kept', "the copy's opening scripts ran",
                        'a file the list does not name was written',
                        'a list that could not be checked was shown'):
            self.assertIn(refused, step)
        for shot in ('24c5-community-stacks-unsigned', '24c6-community-stacks', '24c7-community-stacks-search',
                     '24c8-community-stacks-ask', '24c9-community-stacks-copy'):
            self.assertIn('"%s"' % shot, tour)

    def test_the_engine_tests_are_there(self):
        tests = read(ENGINE_TEST)
        for name in ('TestSiteAndKey', 'TestVerify', 'TestParse', 'TestParseLeavesOutWhatBreaksTheRules',
                     'TestParseCleansWhatItKeeps', 'TestLoad', 'TestLoadOnlyFromHttps', 'TestGet',
                     'TestGetKeepsOnlyWhatTheListNames', 'TestOpenToRead', 'TestOpenToReadRefusesTheIDEsNames',
                     'TestOpenToReadLeavesAnOpenStackAlone'):
            self.assertIn('on %s\n' % name, tests)


if __name__ == '__main__':
    unittest.main()
