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
    tools/listing.py there, 2026-11-17);
  - the index of stacks has the kit's list lines: each name in the middle
    of its line's hilite, and a last line that scrolls wholly into view,
    with the engine's own code held to what those two rest on.

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
KIT = os.path.join(TOOLSET, 'palettes', 'learn', 'revlearnkit.livecodescript')
TOUR = os.path.join(REPO, 'tools', 'ci', 'ui-tour.livecodescript')
ENGINE = os.path.join(REPO, 'engine', 'src')
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
        self.assertIn('return csOpenCopy(pFile, false)', code(handler(self.text, 'revCommunityStacksOpenToRead')))
        opened = code(handler(self.text, 'csOpenCopy'))
        lock = opened.index('lock messages')
        names = opened.index('csIsIDEName(tName)')
        go = opened.index('go stack pFile')
        unlock = opened.index('unlock messages')
        self.assertLess(lock, names)
        self.assertLess(names, go)
        self.assertLess(go, unlock)
        self.assertIn('revIDESetTool "pointer"', opened)
        # the only places a stack of the gallery is opened: this one, and
        # Open and Run's below
        self.assertEqual(self.code.count('go stack'), 2)

    def test_a_copy_opened_to_run_is_checked_first(self):
        # Open and Run (openxtalk.org p=26654): the same checks, with
        # messages locked, and the stack opened only after they pass, with
        # messages, as File > Open opens one, and with the browse tool
        self.assertIn('return csOpenCopy(pFile, true)', code(handler(self.text, 'revCommunityStacksOpenToRun')))
        opened = code(handler(self.text, 'csOpenCopy'))
        unlock = opened.index('unlock messages')
        self.assertIn('else if pRun then\n         put true into tGo\n      else\n         go stack pFile', opened)
        run = opened.index('if tGo then\n      go stack pFile')
        self.assertLess(unlock, run)
        self.assertIn('revIDESetTool "browse"', opened)
        # a refusal sets no tGo: tGo is set only in the branch after the
        # three refusals (a name taken, the IDE's name, a substack of one)
        self.assertLess(opened.index('else if tKept is tName then'), opened.index('else if pRun then'))
        self.assertLess(opened.index('else if tKept is not empty then'), opened.index('else if pRun then'))
        self.assertEqual(opened.count('put true into tGo'), 1)

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


    def test_the_words_under_the_name_are_whole_on_one_line(self):
        # With a wide system font (DejaVu Sans, the only font of some Linux
        # systems and of the build server) "Made and shared by people like
        # you" needed 199 pixels at size 11 and the label has 190: it went
        # on to a second line, and the label's bottom cut "you" (the IDE
        # screenshots of main at c77e5264, light and dark). The label is
        # one line, drawn a size smaller until it fits, and the tour fails
        # where a label of the sidebar needs more than it has.
        side = handler(self.code, 'csBuildSide')
        m = re.search(r'put lkLabel\("sideSub", [^\n]*\) into tObj\n(.*?)\n\s*\n', side, re.S)
        self.assertIsNotNone(m, 'the label under the name is not kept to be fitted')
        fit = m.group(1)
        self.assertIn('set the dontWrap of tObj to true', fit)
        self.assertIn('repeat while the formattedWidth of tObj > the width of tObj and the textSize of tObj > 9', fit)
        self.assertIn('set the textSize of tObj to the textSize of tObj - 1', fit)
        tour = read(TOUR)
        step = handler(tour, 'tour_community_stacks')
        for label in ('sideTitle', 'sideSub'):
            self.assertIn('tourCsWhole tWin, "%s"' % label, step)
        # before the first picture, so that a cut label fails the step
        self.assertLess(step.index('tourCsWhole tWin, "sideSub"'), step.index('"24c5-community-stacks-unsigned"'))
        whole = handler(tour, 'tourCsWhole')
        self.assertIn('set the dontWrap of field pField of stack pWin to true', whole)
        self.assertIn('put the formattedWidth of field pField of stack pWin into tNeed', whole)
        self.assertIn('if tNeed > tHas then\n      throw', whole)


class TheIndex(unittest.TestCase):
    """The list of stacks in the window's sidebar. With 0.2.8-dp.2's first
    builds its names sat low in the hilite (14 point text at the bottom of
    30 point lines), and the last stack of a list longer than the window
    never came wholly into view (bwmilby on the forum, macOS and Linux).
    The step community-stacks of the tour measures both in the IDE."""

    @classmethod
    def setUpClass(cls):
        cls.window = read(WINDOW)
        cls.kit = read(KIT)
        cls.tour = read(TOUR)

    def test_its_lines_are_the_kits_list_lines(self):
        side = code(handler(self.window, 'csBuildSide'))
        self.assertIn('lkListLines tObj, kIndexLine, 12', side)
        # and nothing after it sets the lines again
        after = side[side.index('lkListLines tObj, kIndexLine, 12'):]
        for prop in ('margins', 'fixedLineHeight', 'textHeight', 'listBehavior'):
            self.assertNotIn('set the %s of tObj' % prop, after)
        lines = code(handler(self.kit, 'lkListLines'))
        for line in ('set the listBehavior of pObj to true', 'set the fixedLineHeight of pObj to true',
                     'set the textHeight of pObj to pHeight'):
            self.assertIn(line, lines)

    def test_the_last_line_scrolls_wholly_into_view(self):
        # The engine stops a field's scroll at its text and two margins
        # less twice TEXT_Y_OFFSET: margins that add up to less leave the
        # end of the last line below the field
        lines = code(handler(self.kit, 'lkListLines'))
        m = re.search(r'set the margins of pObj to pLeft & ",(\d+),(\d+),(\d+)"', lines)
        self.assertIsNotNone(m, 'lkListLines sets no margins')
        top, bottom = int(m.group(1)), int(m.group(3))
        offset = int(re.search(r'^#define TEXT_Y_OFFSET (\d+)$', read(os.path.join(ENGINE, 'objdefs.h')), re.M).group(1))
        self.assertGreaterEqual(top + bottom, 2 * offset)
        field = read(os.path.join(ENGINE, 'field.cpp'))
        scroll = field[field.index('Exec_stat MCField::vscroll(int4 offset, Boolean doredraw)'):]
        scroll = scroll[:scroll.index('\n}\n')]
        self.assertIn('uint4 theight = textheight + topmargin + bottommargin - TEXT_Y_OFFSET * 2;', scroll)
        self.assertIn('if ((uint4)texty > theight - drect.height)\n\t\t\ttexty = theight - drect.height;', scroll)

    def test_the_names_are_set_in_the_middle_of_their_lines(self):
        fill = code(handler(self.window, 'csFillIndex'))
        put, centre = 'set the htmlText of field "idx" to tHtml', 'lkListCentre the long id of field "idx"'
        self.assertIn(put, fill)
        self.assertIn(centre, fill)
        # after the names are put: the shift is a style of the text
        self.assertLess(fill.index(put), fill.index(centre))
        self.assertEqual(self.window.count('set the htmlText of field "idx"'), 1)
        kit = code(handler(self.kit, 'lkListCentre'))
        self.assertIn('put measureText("Xg", pObj, "bounds") into tBounds', kit)
        self.assertIn('put (the textHeight of pObj - (item 4 of tBounds - item 2 of tBounds)) div 2 into tRoom', kit)
        # up by the font's descent too: see the next test
        self.assertIn('set the textShift of char 1 to -1 of pObj to (- (tRoom + item 4 of tBounds))', kit)

    def test_the_engine_sets_fixed_lines_as_the_shift_takes_them(self):
        # A fixed line's baseline is the line's height less the deepest
        # descent of the field's text; text shifted up by its descent or
        # more has none, and is drawn its shift above the baseline
        field = read(os.path.join(ENGINE, 'field.cpp'))
        recompute = field[field.index('void MCField::do_recompute(bool p_force_layout)'):]
        recompute = recompute[:recompute.index('\n}\n')]
        self.assertIn('if (descent > fixedd)\n\t\t\tfixedd = descent;', recompute)
        self.assertIn('fixedheight = fheight;\n\t\tfixeda = fixedheight - fixedd;', recompute)
        block = read(os.path.join(ENGINE, 'block.cpp'))
        self.assertIn('return MCU_max(0.0f, MCFontGetDescent(m_font) + shift);', block)
        self.assertIn('\t\ty += atts->shift;', block)

    def test_the_tour_measures_both_in_the_ide(self):
        step = handler(self.tour, 'tour_community_stacks')
        middle = 'get tourSelectedLineMiddle(tWin, "Community Stacks")\n         if it is not empty then throw it'
        self.assertEqual(step.count(middle), 2)
        # the first before the picture of the list, so that a low name fails the step
        self.assertLess(step.index(middle), step.index('"24c6-community-stacks"'))
        # a list longer than the index shows: 3 stacks and 21 more
        self.assertIn('repeat with tCount = 1 to 21', step)
        self.assertIn('the number of lines of field "idx" of stack tWin is not 24', step)
        self.assertIn('if the formattedHeight of field "idx" of stack tWin <= the height of field "idx" of stack tWin then\n'
                      '            throw', step)
        for when in ('at the end of the scroll', 'with the last stack in front'):
            self.assertIn('tourCsLastLine tWin, "%s"' % when, step)
        last = handler(self.tour, 'tourCsLastLine')
        self.assertIn('put the formattedRect of line -1 of field "idx" of stack pWin into tRect', last)
        self.assertIn('if item 2 of tRect < tTop or item 4 of tRect > tBottom then\n      throw', last)
        measure = handler(self.tour, 'tourSelectedLineMiddle')
        self.assertIn('if tourContrast(tRGB, tHilite) >= 3 then', measure)
        self.assertIn('if abs(tOff) > tFull / 8 then', measure)
        self.assertIn('is not wholly in view', measure)


class ThePage(unittest.TestCase):
    """The page of the stack or library in front. With 0.2.8-dp.2 the last
    line of a page longer than the window (the Easing library's) stayed
    partly below it at the end of the scroll: its lower 8 points were cut
    off (bwmilby on the forum, Linux and macOS). The page, like the
    Release Notes' page and the About window's panel, is a label of the
    kit's (a top margin of kTextInset, none below) that scrolls; the kit's
    lkPageEnd gives it the bottom margin the engine's scroll needs. The
    step community-stacks of the tour measures it in the IDE, and the
    dp.2 engine, with the kit's lkLabel, put the last line 8 points below
    a 364 point page before and wholly in it after."""

    @classmethod
    def setUpClass(cls):
        cls.kit = read(KIT)
        cls.tour = read(TOUR)

    def test_the_kits_page_end_leaves_room_for_the_last_line(self):
        # The engine stops a field's scroll at its text and two margins
        # less twice TEXT_Y_OFFSET (MCField::vscroll); the margins must add
        # up to that and 2 points more, for 2 points under the last line
        end = code(handler(self.kit, 'lkPageEnd'))
        m = re.search(r'set the bottomMargin of pObj to max\(the bottomMargin of pObj, (\d+) - the topMargin of pObj\)', end)
        self.assertIsNotNone(m, 'lkPageEnd sets no bottom margin')
        offset = int(re.search(r'^#define TEXT_Y_OFFSET (\d+)$', read(os.path.join(ENGINE, 'objdefs.h')), re.M).group(1))
        self.assertEqual(int(m.group(1)), 2 * offset + 2)
        # it only ever adds room: a bottom margin a window set is kept
        self.assertNotIn('set the margins', end)
        field = read(os.path.join(ENGINE, 'field.cpp'))
        scroll = field[field.index('Exec_stat MCField::vscroll(int4 offset, Boolean doredraw)'):]
        scroll = scroll[:scroll.index('\n}\n')]
        self.assertIn('uint4 theight = textheight + topmargin + bottommargin - TEXT_Y_OFFSET * 2;', scroll)
        # and a kit label has no bottom margin of its own: without
        # lkPageEnd its last line is cut
        label = code(handler(self.kit, 'lkLabel'))
        self.assertIn('set the margins of tObj to "0," & kTextInset & ",0,0"', label)
        self.assertEqual(constant(self.kit, 'kTextInset'), '4')

    def test_every_page_that_scrolls_has_it(self):
        pages = (
            (WINDOW, 'csBuild', 'lkScroller "pageThumb", tObj'),
            (os.path.join(TOOLSET, 'palettes', 'updates', 'revreleasenotes.livecodescript'), 'rnBuild',
             'lkScroller "pageThumb", tObj'),
            (os.path.join(TOOLSET, 'palettes', 'about', 'revabout.livecodescript'), None, 'lkScroller "panelThumb", tObj'),
        )
        for path, name, scroller in pages:
            text = code(read(path))
            if name is not None and re.search(r'^(?:private +)?(?:on|command) +%s\b' % name, text, re.M):
                text = code(handler(read(path), name))
            self.assertIn(scroller, text, path)
            self.assertIn('lkPageEnd tObj', text, path)
            # before the thumb is made, which measures the scroll
            self.assertLess(text.index('lkPageEnd tObj'), text.index(scroller), path)

    def test_the_tour_measures_it_in_the_ide(self):
        step = handler(self.tour, 'tour_community_stacks')
        self.assertIn('tourCsPageEnd tWin', step)
        end = handler(self.tour, 'tourCsPageEnd')
        self.assertIn('set the vScroll of field "page" of stack pWin to 30000', end)
        self.assertIn('put the formattedRect of line -1 of field "page" of stack pWin into tRect', end)
        self.assertIn('if item 4 of tRect > tBottom then\n      throw', end)
        self.assertIn('throw "the tour\'s long page fits the page', end)
        # the window's own text is put back
        self.assertIn('set the htmlText of field "page" of stack pWin to tSaved', end)


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
        # and so is opening it to run (openxtalk.org p=26654: a stack that
        # draws its screen as it opens shows its cards bare when it is
        # opened to look at): the dialog says both, Open It to Look stays
        # the last button (Return's), and Open and Run is the one before
        self.assertIn('case "Open and Run"', copy)
        # sent, so that no try waits under the copy's opening scripts: the
        # window's Get a Copy calls this inside one, and while a try waits
        # the engine shows no error (Codex review of #617)
        self.assertIn('send "revIDECommunityStacksRunCopy tResult, tFileName" to me in 0 milliseconds', copy)
        self.assertNotIn('revCommunityStacksOpenToRun', copy)
        run = code(handler(self.text, 'revIDECommunityStacksRunCopy'))
        self.assertIn('dispatch "revCommunityStacksOpenToRun" to stack __communityStacksFile() with pFile', run)
        self.assertNotIn('try', run)
        self.assertIn('shows its cards bare', copy)
        self.assertIn('"Show the Folder" & return & "Done" & return & "Open and Run" & return & "Open It to Look" into tSpec["buttons"]', copy)
        self.assertIn('with "Show the Folder" or "Done" or "Open and Run" or "Open It to Look"', copy)
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
                     '24c8-community-stacks-ask', '24c9-community-stacks-copy', '24c10-community-stacks-long'):
            self.assertIn('"%s"' % shot, tour)

    def test_the_engine_tests_are_there(self):
        tests = read(ENGINE_TEST)
        for name in ('TestSiteAndKey', 'TestVerify', 'TestParse', 'TestParseLeavesOutWhatBreaksTheRules',
                     'TestParseCleansWhatItKeeps', 'TestLoad', 'TestLoadOnlyFromHttps', 'TestGet',
                     'TestGetKeepsOnlyWhatTheListNames', 'TestOpenToRead', 'TestOpenToReadRefusesTheIDEsNames',
                     'TestOpenToReadLeavesAnOpenStackAlone', 'TestOpenToRun',
                     'TestOpenToRunLetsTheStacksErrorsThrough', 'TestOpenToRunRefusesWhatOpenToReadRefuses'):
            self.assertIn('on %s\n' % name, tests)


if __name__ == '__main__':
    unittest.main()
