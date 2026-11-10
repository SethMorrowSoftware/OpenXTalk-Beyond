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

"""A new HyperCard import looks like HyperCard (the HyperCard roadmap's
decisions A and B): white paper and black-and-white buttons
(revHyperCardClassicLook), and the Mac fonts it names shown in look-alikes
(revHyperCardMacFonts: Chicago in the public-domain ChicagoFLF, Geneva,
New York, Monaco and Palatino in faces of their kind). Each can be turned
off: File > Import Stack's "Classic HyperCard Look" and "Mac Font
Look-alikes" on the desktop, and a box on the web Stack Player's page for
the look.

What the two handlers do to a stack is tested by the engine tests of
tests/lcs/core/interface/hypercard-scripts.livecodescript. These tests
hold the wiring those cannot reach: the menu items and the preferences
they set, the import that reads them, ChicagoFLF in a folder the IDE does
not load at startup (so only an imported stack loads it), the front
script that loads it again for such a stack, and the player page's box.

  python3 -m unittest discover -s tools/ci/tests
"""

import hashlib
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
TOOLSET = os.path.join(REPO, 'ide', 'Toolset')
FONTS = os.path.join(TOOLSET, 'resources', 'supporting_files', 'fonts')
CHICAGO = os.path.join(FONTS, 'hypercard', 'ChicagoFLF.ttf')
CHICAGO_SHA256 = '3c5896edd062de6a2fd786317e3e2f75982219ab623a184beba55bd951b38762'


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def handler(text, name):
    """The text of the handler `name` of a script (on, command, function,
    private or not)."""
    m = re.search(r'^(?:private\s+)?(?:on|command|function)\s+' + re.escape(name) + r'\b.*?^end\s+' +
                  re.escape(name) + r'\b', text, re.M | re.S)
    if not m:
        raise AssertionError('no handler ' + name)
    return m.group(0)


class ImportMenu(unittest.TestCase):
    def setUp(self):
        self.menubar = read('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript')

    def test_mac_fonts_item_follows_its_preference(self):
        self.assertIn('toggleMenuItem("Mac Font Look-alikes/|hypercardfonts", '
                      'revIDEGetPreference("cHyperCardMacFonts") is not false)', self.menubar)

    def test_mac_fonts_item_turns_its_preference_over(self):
        self.assertRegex(self.menubar, r'if item 2 of pWhich is "hypercardfonts" then\s+'
                         r'revIDESetPreference "cHyperCardMacFonts", '
                         r'\(revIDEGetPreference\("cHyperCardMacFonts"\) is false\)')

    def test_classic_look_item_is_still_there(self):
        self.assertIn('"Classic HyperCard Look/|hypercardlook"', self.menubar)

    def test_web_ide_tour_reads_every_option(self):
        tour = read('tools', 'ci', 'web-ide-tour.livecodescript')
        m = re.search(r'constant kImportStackPrefs = "([^"]*)"', tour)
        prefs = m.group(1).split(',')
        for pref in re.findall(r'revIDEGetPreference\("(cHyperCard\w+)"\) is not false\) & return after tFile',
                               self.menubar):
            self.assertIn(pref, prefs)


class ImportStack(unittest.TestCase):
    def setUp(self):
        self.importer = handler(read('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript'),
                                'revIDEImportHyperCardStack')

    def test_mac_fonts_unless_turned_off(self):
        self.assertRegex(self.importer, r'revIDEGetPreference\("cHyperCardMacFonts"\) is not false then\s+'
                         r'try\s+revHyperCardUseMacFonts\s+revHyperCardMacFonts tStack\s+catch')

    def test_after_the_classic_look(self):
        self.assertLess(self.importer.index('revHyperCardClassicLook tStack'),
                        self.importer.index('revHyperCardMacFonts tStack'))


class ChicagoFLF(unittest.TestCase):
    def test_the_font_is_the_public_domain_file(self):
        with open(CHICAGO, 'rb') as f:
            self.assertEqual(hashlib.sha256(f.read()).hexdigest(), CHICAGO_SHA256)

    def test_its_statement_goes_with_it(self):
        readme = read('ide', 'Toolset', 'resources', 'supporting_files', 'fonts', 'hypercard', 'README.txt')
        self.assertIn('I consider those two in the public domain.', readme)
        self.assertIn(CHICAGO_SHA256, readme)
        self.assertIn('ChicagoFLF', read('THIRD-PARTY-NOTICES.md'))

    def test_ide_does_not_load_it_at_startup(self):
        # revIDELibrary loads the *.ttf files of the fonts folder itself
        # (files(), which does not look into the folders inside it)
        ide = read('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
        self.assertIn('put files(revIDESpecialFolderPath("fonts")) into tFonts', ide)
        self.assertNotIn('ChicagoFLF.ttf', os.listdir(FONTS))

    def test_library_finds_it(self):
        library = handler(read('ide', 'Toolset', 'libraries', 'revhypercardscriptlibrary.livecodescript'),
                          'revHyperCardMacFontFile')
        self.assertIn('/resources/supporting_files/fonts/hypercard/ChicagoFLF.ttf', library)
        # the library sits two folders below Toolset
        self.assertTrue(os.path.isfile(os.path.join(TOOLSET, 'libraries', 'revhypercardscriptlibrary.livecodescript')))

    def test_front_script_loads_it_for_an_imported_stack_only(self):
        front = handler(read('ide', 'Toolset', 'libraries', 'revfrontscriptlibrary.livecodescript'), 'preOpenStack')
        self.assertRegex(front, r'if "ChicagoFLF" is in the uHyperCard\["fonts"\] of tOpening then\s+'
                         r'revHyperCardUseMacFonts')
        # inside a try: an error there must not stop a stack opening
        load = front.index('revHyperCardUseMacFonts')
        self.assertLess(front.rindex('try', 0, load), load)
        self.assertGreater(front.index('end try', load), load)

    def test_web_ide_carries_it(self):
        site = read('tools', 'web-ide', 'build_site.py')
        m = re.search(r"LEAVE_OUT_PATTERN = re\.compile\(\s*r'([^']*)'\)", site)
        self.assertIsNone(re.match(m.group(1), 'Toolset/resources/supporting_files/fonts/hypercard/ChicagoFLF.ttf'))


class StackPlayer(unittest.TestCase):
    def setUp(self):
        self.page = read('tools', 'web-player', 'index.html')
        self.player = read('tools', 'web-player', 'stack-player.livecodescript')

    def test_page_has_the_box_ticked(self):
        self.assertRegex(self.page, r'<input type="checkbox" id="hc-classic" checked>')

    def test_page_tells_the_player(self):
        self.assertIn("call('hclook\\n' + (classicLook() ? 'on' : 'off'));", self.page)
        self.assertIn("localStorage.setItem('oxtHyperCardClassic', on ? 'on' : 'off')", self.page)

    def test_player_takes_the_verb(self):
        verbs = re.search(r'if tVerb is among the items of "([^"]*)" then', self.player).group(1).split(',')
        self.assertIn('hclook', verbs)
        self.assertRegex(handler(self.player, 'playerDo'), r'case "hclook"\s+[\s\S]*?put line 1 of tArgs is "off" into sNoClassicLook')

    def test_look_unless_unticked(self):
        fix = handler(self.player, 'playerFixHyperCard')
        self.assertRegex(fix, r'if sNoClassicLook is not true then\s+try\s+revHyperCardClassicLook pStack')


if __name__ == '__main__':
    unittest.main()
