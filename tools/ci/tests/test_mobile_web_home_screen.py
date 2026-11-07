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
"""The Mobile Web library's page side in a web app opened from an
iPhone's Home Screen, and the bare Stack Player's page (play.html) with
a stack that fills it (bwmilby, Bug Hunt, Nov 2026, the Phone Starter on
an iPhone 18 Pro):

- turned on its side, the stack had a gap on the left: play.html's
  #stage kept its safe-area padding when the library made the stack as
  big as the page, so the stack moved in by the left inset (an iPhone
  gives both sides one in landscape) and lost as much on the right
- turned back upright, the stack's bottom (the tab bar) sat where a
  browser's toolbar would be, with black under it, until the app was
  closed: WebKit reported a shorter page after the turn

The library's browser script is taken out of mobileweb.livecodescript
(each line of mwBrowserScript) and run under Node with a page made of
plain objects, so the numbers a phone reports can be set by hand. Away
from a Home Screen app the answers are those of before, to the pixel.

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import shutil
import subprocess
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
LIBRARY = os.path.join(REPO, 'extensions', 'script-libraries', 'mobileweb', 'mobileweb.livecodescript')
PLAY = os.path.join(REPO, 'tools', 'web-player', 'play.html')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def browser_script():
    """mwBrowserScript's JavaScript, as the library hands it to the page:
    every put "..." line, and the library's name for "var lib"."""
    body = re.search(r'^private function mwBrowserScript\n(.*?)^end mwBrowserScript', read(LIBRARY), re.M | re.S).group(1)
    lines = []
    for line in body.split('\n'):
        line = line.strip()
        if line.startswith('put "var lib = " & mwQuote(kLibrary)'):
            lines.append("var lib = 'mobileweb';")
            continue
        found = re.match(r'^put "(.*)"(?: & return)? after tScript$', line)
        if found:
            lines.append(found.group(1))
    return '\n'.join(lines)


# A page of plain objects: the window's sizes, screen, navigator.standalone
# and visualViewport as the test sets them; the html element's attributes
# and style properties as the script leaves them
FAKE_PAGE = r"""
function element(tag) {
  var e = {tagName: tag, attrs: {}, children: [], props: {}, parentNode: null,
    style: {cssText: '',
      setProperty: function(k, v) { e.props[k] = v; },
      removeProperty: function(k) { delete e.props[k]; },
      getPropertyValue: function(k) { return e.props[k] || ''; }},
    setAttribute: function(k, v) { e.attrs[k] = String(v); },
    getAttribute: function(k) { return k in e.attrs ? e.attrs[k] : null; },
    hasAttribute: function(k) { return k in e.attrs; },
    removeAttribute: function(k) { delete e.attrs[k]; },
    appendChild: function(c) { c.parentNode = e; e.children.push(c); if (c.id) byId[c.id] = c; return c; },
    removeChild: function(c) { e.children.splice(e.children.indexOf(c), 1); c.parentNode = null; if (c.id) delete byId[c.id]; }};
  return e;
}
var byId = {};
var html = element('HTML'), head = element('HEAD'), body = element('BODY');
var page = SETUP;
var document = {documentElement: html, head: head, body: body,
  createElement: element,
  getElementById: function(id) { return byId[id] || null; },
  querySelector: function(q) {
    var all = head.children.filter(function(c) { return c.tagName === 'meta'; });
    if (q === 'meta[name=viewport]') return all.filter(function(c) { return c.name === 'viewport'; })[0] || null;
    if (q === 'meta[data-oxt-mobile-web]') return all.filter(function(c) { return c.hasAttribute('data-oxt-mobile-web'); })[0] || null;
    return null;
  }};
Object.defineProperty(html, 'clientWidth', {get: function() { return page.w; }});
var window = {document: document, navigator: page.navigator, screen: page.screen,
  scrollTo: function() {}, addEventListener: function() {}, removeEventListener: function() {}};
Object.defineProperty(window, 'innerWidth', {get: function() { return page.w; }});
Object.defineProperty(window, 'innerHeight', {get: function() { return page.h; }});
Object.defineProperty(window, 'visualViewport', {get: function() {
  return page.vv === false ? null : {width: page.w, height: page.vvh || page.h, scale: 1, offsetTop: 0};
}});
var screen = page.screen;
function getComputedStyle() { return {paddingTop: '0px', paddingRight: '0px', paddingBottom: '0px', paddingLeft: '0px'}; }
(function() { SCRIPT })();
var m = window.__oxtMobileWeb, out = [];
function look(label) {
  out.push({label: label, page: m.pageSize(), view: m.viewport(),
    height: html.style.getPropertyValue('--oxt-mobile-web-height'),
    filled: html.getAttribute('data-mobile-web-filled'),
    fillCss: byId['oxt-mobile-web-fill'] ? byId['oxt-mobile-web-fill'].textContent : null});
}
STEPS
process.stdout.write(JSON.stringify(out));
"""

IPHONE = "{w: 402, h: 874, navigator: {standalone: true}, screen: {width: 402, height: 874}}"


@unittest.skipUnless(shutil.which('node'), 'node is not installed')
class HomeScreenHeight(unittest.TestCase):

    def run_page(self, setup, steps):
        script = FAKE_PAGE.replace('SETUP', setup).replace('SCRIPT', browser_script()).replace('STEPS', steps)
        out = subprocess.run([shutil.which('node'), '-e', script], capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout)

    TURN = """
      m.fillPage(false, 'fill'); look('upright');
      page.w = 874; page.h = 402; look('on its side');
      page.w = 402; page.h = 780; look('upright again');
    """

    def test_turned_back_upright_the_page_is_as_tall_as_it_was(self):
        seen = self.run_page(IPHONE, self.TURN)
        self.assertEqual(seen[0]['page'], '402,874')
        self.assertEqual(seen[1]['page'], '874,402')
        self.assertEqual(seen[1]['view'].split(',')[7], 'landscape')
        again = seen[2]
        self.assertEqual(again['page'], '402,874')
        width, height, keyboard = again['view'].split(',')[:3]
        self.assertEqual((width, height, keyboard), ('402', '874', '0'))
        self.assertEqual(again['view'].split(',')[7], 'portrait')
        # the page's html and body as tall as the stack, not innerHeight
        self.assertEqual(again['height'], '874px')
        self.assertIn('height:var(--oxt-mobile-web-height,100%)', again['fillCss'])
        self.assertEqual(seen[0]['height'], '')

    def test_a_browser_tab_follows_innerheight_as_before(self):
        # Safari's toolbar comes and goes: the page is as tall as it says
        seen = self.run_page("{w: 402, h: 874, navigator: {}, screen: {width: 402, height: 874}}", self.TURN)
        self.assertEqual(seen[2]['page'], '402,780')
        self.assertEqual(seen[2]['view'].split(',')[:3], ['402', '780', '0'])
        self.assertEqual(seen[2]['height'], '')

    def test_a_window_narrower_than_the_screen_follows_innerheight(self):
        # an iPad's app in a window of its own can be made shorter
        seen = self.run_page("{w: 600, h: 900, navigator: {standalone: true}, screen: {width: 1024, height: 1366}}", """
          m.fillPage(false, 'fill'); look('tall'); page.h = 700; look('shorter');
        """)
        self.assertEqual(seen[1]['page'], '600,700')

    def test_never_taller_than_the_screen(self):
        seen = self.run_page(IPHONE, """
          page.h = 2000; look('a wrong report'); page.h = 800; look('after');
        """)
        self.assertEqual(seen[1]['page'], '402,800')

    def test_the_keyboard_is_still_told(self):
        seen = self.run_page(IPHONE, """
          m.fillPage(false, 'fill'); look('upright');
          page.w = 874; page.h = 402; look('on its side');
          page.w = 402; page.h = 780; page.vvh = 480; look('typing');
        """)
        width, height, keyboard = seen[2]['view'].split(',')[:3]
        self.assertEqual(keyboard, '300')
        self.assertEqual(height, '574')

    def test_without_a_visual_viewport(self):
        seen = self.run_page("{w: 402, h: 874, vv: false, navigator: {standalone: true}, screen: {width: 402, height: 874}}",
                             self.TURN)
        self.assertEqual(seen[2]['view'].split(',')[:3], ['402', '874', '0'])

    def test_the_html_element_says_how_the_page_is_filled(self):
        seen = self.run_page(IPHONE, """
          m.fillPage(true); look('asked');
          m.fillPage(false, 'fill'); look('filled');
          m.unfillPage(); look('given back');
          m.fillPage(); look('fitted');
        """)
        self.assertEqual([s['filled'] for s in seen], [None, 'fill', None, 'fit'])

    def test_given_back_the_page_loses_the_height(self):
        seen = self.run_page(IPHONE, self.TURN + "m.unfillPage(); out.push({height: html.style.getPropertyValue('--oxt-mobile-web-height')});")
        self.assertEqual(seen[2]['height'], '874px')
        self.assertEqual(seen[3]['height'], '')


class FilledPlayerPage(unittest.TestCase):

    def test_play_takes_its_padding_off_a_stack_that_fills_it(self):
        page = read(PLAY)
        self.assertIn('html[data-mobile-web-filled="fill"] #stage{padding:0}', page)
        # the padding stays for a stack shown at its own size, or fitted
        self.assertIn('padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)}', page)

    def test_only_mwfillscreen_fills(self):
        library = read(LIBRARY)
        self.assertEqual(library.count("fillPage(false, 'fill')"), 1)
        fill = re.search(r'^command mwFillScreen.*?^end mwFillScreen', library, re.M | re.S).group(0)
        self.assertIn("fillPage(false, 'fill')", fill)

    def test_the_script_runs(self):
        self.assertIn('function pageHeight(lw)', browser_script())


if __name__ == '__main__':
    unittest.main()
