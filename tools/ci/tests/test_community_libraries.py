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

"""The script libraries of the Community Stacks' gallery in the IDE: the
window's Libraries (ide/Toolset/palettes/community/revcommunitystacks.livecodescript)
and its Install (revIDECommunityLibraryInstall). A library has no box
around it once it is installed, so what the source can show without an
engine is held here:

  - the list of libraries is believed only with the gallery's signature,
    checked before it is read, by the same key as the stacks' list;
  - a library's licence is one the gallery offers for a library: GPL 3,
    or one that a program under GPL 3 can take in (LIBRARY_LICENCES in
    tools/listing.py of github.com/oxt-stacks/oxt-community-stacks);
  - a library's name is never one that the IDE, the engine or the xTalk
    Suite keeps for its own (scan.library_name_problem there);
  - the package is the one the gallery's builder names, the bytes that the
    signed list names, with its manifest naming the library the list does;
    and nothing is installed but through the Extension Manager;
  - Install asks first, says that there is no box, and installs nothing
    when it is not agreed to;
  - the IDE tour's step community-libraries runs all of it in the IDE.

tests/lcs/communitystacks runs the list's rules and the package's checks
in the engine.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

from test_community_stacks import read, handler, code, WINDOW, LIBRARY, TOUR, ENGINE_TEST, GUIDE

# LIBRARY_LICENCES of the gallery's tools/listing.py (2026-11-18)
GALLERY_LIBRARY_LICENCES = {
    'GPL-3.0-only', 'GPL-3.0-or-later', 'LGPL-3.0-only', 'LGPL-3.0-or-later',
    'Apache-2.0', 'MIT', 'BSD-2-Clause', 'BSD-3-Clause',
}
# _RESERVED_NAME_STARTS and _RESERVED_NAMES of the gallery's tools/scan.py
GALLERY_RESERVED_STARTS = ('rev', 'com.livecode.', 'org.openxtalk.', 'community.openxtalk.')
GALLERY_RESERVED_NAMES = {'home', 'ide', 'livecode', 'oxt', 'openxtalk', 'help', 'library', 'stack'}


class Window(unittest.TestCase):
    def setUp(self):
        self.text = read(WINDOW)
        self.code = code(self.text)

    def test_the_list_is_checked_before_it_is_read(self):
        load = code(handler(self.text, 'revCommunityLibrariesLoad'))
        sig = load.index('csFetch(tSite, "libraries.sig"')
        check = load.index('put revCommunityStacksVerify(tList, tSignature, pPublicKey) into tProblem')
        parse = load.index('return revCommunityLibrariesParse(tList)')
        self.assertLess(sig, check)
        self.assertLess(check, parse)
        self.assertEqual(load.count('revCommunityLibrariesParse('), 1)
        # every way out before the parse is a problem, or no list at all
        before = load[:parse]
        self.assertEqual(before.count('return tOut'), before.count('into tOut["problem"]') + 1)
        self.assertIn('if tProblem is "missing" then\n      put 0 into tOut["count"]', load)
        self.assertIn('put true into tOut["unsigned"]', load)

    def test_the_licences_are_the_gallerys_for_a_library(self):
        licences = handler(self.text, 'csLibraryLicences')
        self.assertEqual(set(re.findall(r'"([A-Za-z0-9.+-]+)\|', licences)), GALLERY_LIBRARY_LICENCES)
        # any other licence leaves the library out
        licence = code(handler(self.text, 'csLibraryLicence'))
        self.assertTrue(licence.rstrip().endswith('return empty\nend csLibraryLicence'))
        self.assertIn('set the caseSensitive to true', licence)
        clean = code(handler(self.text, 'csCleanLibrary'))
        self.assertIn('put csLibraryLicence(pRaw["licence"]) into tEntry["licence"]', clean)

    def test_a_name_is_never_the_ides(self):
        name = code(handler(self.text, 'csIsLibraryName'))
        self.assertIn('csIsIDEName(pName)', name)
        ide = code(handler(self.text, 'csIsIDEName'))
        for start in GALLERY_RESERVED_STARTS:
            self.assertTrue('begins with "%s"' % start in ide or 'begins with "%s"' % start in name, start)
        names = re.search(r'is among the items of "([^"]+)"', name).group(1).split(',')
        self.assertEqual(set(names), GALLERY_RESERVED_NAMES)

    def test_the_package_is_the_builders(self):
        clean = code(handler(self.text, 'csCleanLibrary'))
        self.assertIn('if tValue is not ("l/" & tSlug & "/" & tVersion & "/" & tSlug & "-" & tVersion & ".lce") then',
                      clean)
        self.assertIn('tValue begins with ("l/" & tSlug & "/")', clean)
        # the manifest first, as the Extension Manager reads it
        self.assertIn('tEntry["files"][1]["path"] is not "manifest.xml"', clean)

    def test_the_package_is_the_listed_bytes(self):
        get = code(handler(self.text, 'revCommunityLibrariesGet'))
        whole = get.index('csSha256(tPackage) is not pEntry["sha256"]')
        kept = get.index('put tPackage into url ("binfile:" & tFile)')
        each = get.index('csSha256(tData) is not pEntry["files"][tIndex]["sha256"]')
        manifest = get.index('contains ("<name>" & pEntry["name"] & "</name>")')
        self.assertLess(whole, kept)
        self.assertLess(kept, each)
        self.assertLess(each, manifest)
        self.assertIn('delete file tFile', get)
        # it fetches; it never installs
        self.assertNotIn('revIDEExtensionInstall', get)
        self.assertIn('pEntry["kind"] is not "library"', get)

    def test_the_window_opens_nothing_but_the_gallerys_pages(self):
        self.assertEqual(self.code.count('launch url'), 1)
        actions = code(handler(self.text, 'lkAction'))
        for case in ('demo', 'script'):
            body = actions[actions.index('case "%s"' % case):]
            body = body[:body.index('break')]
            self.assertIn('csLaunch sStacks[sPage]', body)
        clean = code(handler(self.text, 'csCleanLibrary'))
        self.assertIn('put "s/" & tValue & "/play.html" into tEntry["play"]', clean)
        self.assertIn('matchText(tValue, "\\A[a-z0-9]+(-[a-z0-9]+)*\\z")', clean)

    def test_words_of_the_list_are_escaped_where_they_are_drawn(self):
        body = code(handler(self.text, 'csLibraryHtml'))
        self.assertIn('lkEscape(pEntry["description"])', body)
        self.assertIn('lkEscape(item 2 of tLine)', body)
        self.assertIn('lkEscape(item 1 of tLine)', body)
        self.assertIn('lkEscape(tTags)', body)
        self.assertIn('lkEscape(tInstalled)', body)

    def test_install_goes_through_the_ide(self):
        install = code(handler(self.text, 'csInstall'))
        self.assertIn('revIDECommunityLibraryInstall sStacks[sPage], sSite', install)
        self.assertNotIn('revIDEExtensionInstall', self.code)


class Install(unittest.TestCase):
    def setUp(self):
        self.text = read(LIBRARY)

    def test_it_asks_first_and_says_there_is_no_box(self):
        install = code(handler(self.text, 'revIDECommunityLibraryInstall'))
        ask = install.index('put "Install this library?" into tSpec["heading"]')
        agreed = install.index('if tChoice is not "Install" then\n      return empty')
        fetch = install.index('dispatch "revCommunityLibrariesGet" to stack tFile with pEntry, pFolder, pSite')
        checked = install.index('if tResult begins with "error:" then')
        installed = install.index('revIDEExtensionInstall tResult')
        self.assertLess(ask, agreed)
        self.assertLess(agreed, fetch)
        self.assertLess(fetch, checked)
        self.assertLess(checked, installed)
        self.assertIn('there is no box around it', install)
        self.assertIn('Install libraries only from people you trust.', install)
        self.assertNotIn('launch url', install)
        self.assertNotIn('://', install)
        # the package is not kept once it is installed, and the result is
        # what the Extension Manager reports, not what was hoped
        self.assertIn('delete file tResult', install)
        self.assertIn('put revIDEExtensionProperty(pEntry["name"], "status") into tStatus', install)
        self.assertIn('if tStatus is not "installed" or tVersion is not pEntry["version"] then', install)
        self.assertIn('if revEnvironmentIsWeb() or pEntry is not an array then\n      return empty', install)

    def test_the_action_takes_the_libraries(self):
        action = code(handler(self.text, 'revIDEActionCommunityStacks'))
        self.assertIn('dispatch "revCommunityStacksShow" to stack tFile with pSite, pPublicKey, pMode', action)


class TheTour(unittest.TestCase):
    def test_the_tour_installs_one(self):
        tour = read(TOUR)
        steps = re.search(r'^constant kSteps = "([^"]+)"', tour, re.M).group(1).split(',')
        self.assertEqual(steps[steps.index('community-stacks') + 1], 'community-libraries')
        step = handler(tour, 'tour_community_libraries')
        for said in ('revIDEActionCommunityStacks tSite, tKey, "libraries"',
                     'revIDECommunityLibraryInstall tEntry, tSite, tFolder & "/fetched"',
                     'if tOut is not "pong" then throw',
                     'revIDEExtensionUninstall tPing',
                     'a package that was changed was kept'):
            self.assertIn(said, step)

    def test_the_engine_tests_and_the_guide(self):
        tests = read(ENGINE_TEST)
        for name in ('TestLibrariesParse', 'TestLibrariesParseLeavesOutWhatBreaksTheRules', 'TestLibrariesLoad',
                     'TestLibrariesGet', 'TestLibrariesUsesWords'):
            self.assertRegex(tests, r'(?m)^on %s$' % name)
        row = [line for line in read(GUIDE).split('\n') if line.startswith('| **Community Stacks...**')][0]
        for said in ('Libraries', 'Install', 'no box', 'people you trust'):
            self.assertIn(said, row)


if __name__ == '__main__':
    unittest.main()
