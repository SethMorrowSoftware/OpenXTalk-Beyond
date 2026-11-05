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

"""A stack made with the Mobile Web library has the whole screen on a
tablet too, in the Stack Player's page (index.html) and the bare player
(play.html). On a touch screen that is not a phone's (an iPad), the body's
data-mobile-web-fill is "touch": the library may fill the page, and the
player gives the window to a stack whose scripts call mwStart,
mwFillScreen or mwFitStack (playerUsesMobileWeb). Every other stack opens
there as before, at its own size, and is fitted to the screen only on a
phone (#348). build_player.py --check opens the Responsive Starter and
2048 on an iPad Mini (check_tablet).

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PLAYER = os.path.join(REPO, 'tools', 'web-player')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def js_function(page, name):
    found = re.search(r'\n  function %s\(\) \{\n(.*?)\n  \}\n' % name, page, re.S)
    assert found, name
    return found.group(1)


class ThePages(unittest.TestCase):

    def setUp(self):
        self.pages = {name: read('tools', 'web-player', name) for name in ('index.html', 'play.html')}

    def test_a_touch_screen_that_is_not_a_phone(self):
        for name, page in self.pages.items():
            self.assertEqual(js_function(page, 'isTouch'),
                             "    return window.matchMedia('(pointer: coarse)').matches;", name)
            choose = js_function(page, 'choosePhone')
            # the phone first (no attribute), then a tablet ("touch"), then
            # anything else ("no", as before)
            phone = choose.index("if (isPhone()) document.body.removeAttribute('data-mobile-web-fill');")
            touch = choose.index("else if (isTouch()) document.body.setAttribute('data-mobile-web-fill', 'touch');")
            other = choose.index("else document.body.setAttribute('data-mobile-web-fill', 'no');")
            self.assertLess(phone, touch, name)
            self.assertLess(touch, other, name)
        # the same tests in both pages
        self.assertEqual(js_function(self.pages['index.html'], 'isPhone'), js_function(self.pages['play.html'], 'isPhone'))

    def test_the_players_page_plays_full_screen_only_what_filled_it(self):
        page = self.pages['index.html']
        fills = js_function(page, 'fillsTheScreen')
        self.assertIn("var fill = document.body.getAttribute('data-mobile-web-fill');", fills)
        self.assertIn("return fill === null || (fill === 'touch' && !!document.getElementById('oxt-mobile-web-fill'));", fills)
        self.assertIn("document.body.classList.toggle('phone-play', on && fillsTheScreen());", page)

    def test_the_library_fills_a_touch_page(self):
        # the library keeps a page's layout only for "no"
        library = read('extensions', 'script-libraries', 'mobileweb', 'mobileweb.livecodescript')
        self.assertIn("return el && el.getAttribute('data-mobile-web-fill') === 'no';", library)


class ThePlayerStack(unittest.TestCase):

    def setUp(self):
        self.player = read('tools', 'web-player', 'stack-player.livecodescript')

    def handler(self, kind, name):
        found = re.search(r'^(?:private )?%s %s\b.*?\n(.*?)^end %s$' % (kind, name, name), self.player, re.M | re.S)
        self.assertIsNotNone(found, name)
        return found.group(1)

    def test_it_asks_the_page_for_a_touch_screen(self):
        touch = self.handler('function', 'playerOnTouch')
        self.assertIn('if the platform is not "HTML5" then\n      return false', touch)
        self.assertIn("document.body.getAttribute('data-mobile-web-fill') === 'touch' ? 'yes' : 'no'", touch)

    def test_only_a_mobile_web_stack_takes_a_tablets_screen(self):
        open_ = self.handler('command', 'playerOpenFile')
        self.assertIn('put playerOnPhone() and sMode is "page" into tOnPhone', open_)
        self.assertIn('put tOnPhone into tTakeTheScreen', open_)
        self.assertRegex(open_, r'if not tOnPhone and not tHyperCard and sMode is "page" then\s+'
                                r'put playerOnTouch\(\) and playerUsesMobileWeb\(pPath\) into tTakeTheScreen\s+end if')
        self.assertRegex(open_, r'if tTakeTheScreen then\s+playerTakeTheScreen\s+end if\s+try')
        self.assertIn('put tTakeTheScreen and playerLibraryFilled() into tTookTheScreen', open_)
        self.assertRegex(open_, r'else if the mode of stack tName > 0 then\s+if tTakeTheScreen then\s+'
                                r'set the resizable of stack tName to tResizable')
        # fitted to the screen only on a phone, as before
        self.assertIn('if tOnPhone and not tTookTheScreen and the mode of stack tName > 0 then\n      playerFitToPhone tName', open_)
        self.assertEqual(open_.count('playerFitToPhone'), 1)

    def pattern(self):
        uses = self.handler('function', 'playerUsesMobileWeb')
        found = re.search(r'matchText\(tScripts, "([^"]+)"\)', uses)
        self.assertIsNotNone(found)
        # the engine's PCRE: (?i) as Python's
        return re.compile(found.group(1))

    def test_it_reads_every_script_of_the_stack(self):
        uses = self.handler('function', 'playerUsesMobileWeb')
        self.assertIn('the script of stack pPath', uses)
        self.assertIn('the script of card tCard of stack pPath', uses)
        self.assertIn('the behavior of stack pPath', uses)
        self.assertRegex(uses, r'catch tError\s+return false')

    def test_what_counts_as_a_mobile_web_stack(self):
        pattern = self.pattern()
        for script in ('responsive-starter-stack.livecodescript', 'phone-starter-stack.livecodescript'):
            self.assertTrue(pattern.search(read('tools', 'web-player', script)), script)
        for yes in ('   mwStart', 'mwStart the short name of me, "swipe"', 'if mwIsTouchScreen() then mwFitStack',
                    'MWFILLSCREEN "x"', 'mwFitStack'):
            self.assertTrue(pattern.search(yes), yes)
        for no in ('mwStartSensor "location"', 'mwIsTouchScreen()', 'mwStop', 'mwResponsive', 'xmwStart',
                   'mwFitStacks', 'put "mw" & "Start"'):
            self.assertFalse(pattern.search(no), no)


if __name__ == '__main__':
    unittest.main()
