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

"""The Dictionary's pages in the web IDE's dark appearance. The palette asks
a page for the dark with ?appearance=dark, but the web engine's browser
widget shows a file from an object URL, which carries no query
(engine/src/em-browser.js, _fileOf), so in a dark browser the pages opened
light, white in the dark IDE (0.2.7-rc.6.10 to 0.2.7). Two things put that
right, and each is held here:

  - on HTML5 the palette (revdictionarybehavior) says the appearance on the
    IDE's own page, which holds the Dictionary's in a frame, and the pages'
    templates (ide/Documentation/html_viewer/*.html.template) read it as
    they open, so a page is never light meanwhile. The script is cut out of
    each template and run under Node with stand-ins for the window and its
    parent; skipped when there is no node. (It follows the IDE, not the
    system: test_pages_dictionary holds the templates free of
    prefers-color-scheme.)
  - the palette gives a page the appearance when it has loaded too, on
    HTML5 only: the desktops' pages take it from the URL, and their
    browsers are not asked as a page has just loaded (the widget on Windows
    answered nothing then).

What the two do together in a browser is the web IDE tour's (tools/ci/
web-ide-tour.livecodescript, tour_dictionary).

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import shutil
import subprocess
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
VIEWER = os.path.join(REPO, 'ide', 'Documentation', 'html_viewer')
TEMPLATES = ('api.html.template', 'guide.html.template')
BEHAVIOR = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'dictionary', 'behaviors',
                        'revdictionarybehavior.livecodescript')
NODE = shutil.which('node')

MARK = 'data-oxt-dictionary-appearance'

# Each case is a page: whether it is the top window, what its parent's page
# says the Dictionary's appearance is (null for nothing), and whether reading
# the parent throws (another site's page)
HARNESS = r'''
var source = %(source)s;
var cases = %(cases)s;
var out = cases.map(function (c) {
  var doc = {documentElement: {className: 'was'}};
  var parent = {document: {documentElement: {getAttribute: function (name) {
    if (c.throws) throw new Error('another site');
    return name === 'data-oxt-dictionary-appearance' ? c.says : null;
  }}}};
  var win = {location: {protocol: 'blob:', search: ''}};
  win.parent = c.top ? win : parent;
  var threw = false;
  try { new Function('window', 'document', source)(win, doc); } catch (e) { threw = true; }
  return {name: doc.documentElement.className, threw: threw};
});
console.log(JSON.stringify(out));
'''


def head_scripts(page):
    head = page.split('</head>')[0]
    return re.findall(r'<script>(.*?)</script>', head, flags=re.S)


def case(says='dark', top=False, throws=False):
    return {'says': says, 'top': top, 'throws': throws}


def handler(source, kind, name):
    found = re.search(r'^%s %s\b[^\n]*\n(.*?)^end %s$' % (kind, name, name), source, flags=re.S | re.M)
    if found is None:
        raise AssertionError('no %s %s' % (kind, name))
    return [line.strip() for line in found.group(1).split('\n')
            if line.strip() and not line.strip().startswith('--')]


class DictionaryWebAppearanceTest(unittest.TestCase):
    def script(self, template):
        with open(os.path.join(VIEWER, template), encoding='utf-8') as f:
            page = f.read()
        found = [s for s in head_scripts(page) if MARK in s]
        self.assertEqual(len(found), 1, '%s: one script in its head reads %s' % (template, MARK))
        return page, found[0]

    def test_each_template_reads_the_ide_page_in_its_head(self):
        for template in TEMPLATES:
            page, script = self.script(template)
            head = page.split('</head>')[0]
            # after the dark sheet, so the class has rules to pick; and the
            # script keeps to itself
            self.assertLess(head.index('oxt-dark.css'), head.index(script), template)
            self.assertTrue(script.startswith('(function () { try {'), template)
            self.assertTrue(script.endswith('catch (e) {} })();'), template)
            # (the templates are merged: neither marker of an expression)
            self.assertNotIn('[[', script, template)
            self.assertNotIn('<?', script, template)

    @unittest.skipIf(NODE is None, 'no node')
    def test_the_page_takes_the_dark_only_where_the_palette_said_so(self):
        cases = [
            case(),                 # the web IDE's palette said dark
            case(says='light'),     # ... said light
            case(says=None),        # a page inside one that says nothing
            case(top=True),         # the page by itself, as on the desktops
            case(throws=True),      # inside another site's page
        ]
        want = ['was oxt-dark', 'was', 'was', 'was', 'was']
        for template in TEMPLATES:
            _, script = self.script(template)
            run = HARNESS % {'source': json.dumps(script), 'cases': json.dumps(cases)}
            out = subprocess.run([NODE, '-e', run], capture_output=True, text=True, timeout=60)
            self.assertEqual(out.returncode, 0, out.stderr)
            got = json.loads(out.stdout)
            self.assertEqual([g['name'] for g in got], want, template)
            self.assertEqual([g['threw'] for g in got], [False] * len(cases), template)

    def test_the_palette_says_the_appearance_on_the_web_only(self):
        with open(BEHAVIOR, encoding='utf-8') as f:
            source = f.read()
        mark = handler(source, 'private command', 'dictMarkWebPage')
        # nothing is done off HTML5 (where "do ... as JavaScript" is refused)
        at = mark.index('if the platform is not "HTML5" then')
        self.assertEqual(mark[at + 1:at + 3], ['exit dictMarkWebPage', 'end if'])
        said = [i for i, line in enumerate(mark) if line.startswith('do ') and line.endswith('as "JavaScript"')]
        self.assertEqual(len(said), 1)
        self.assertGreater(said[0], at)
        self.assertIn("setAttribute('%s', '\" & tAppearance & \"')" % MARK, mark[said[0]])
        # it is said before a page is asked for, and again at each switch
        tab = handler(source, 'on', 'showTab')
        self.assertLess(tab.index('dictMarkWebPage'), tab.index('set the url of widget "Dictionary" of me to tUrl'))
        self.assertIn('dictMarkWebPage', handler(source, 'private command', 'dictApplyAppearance'))
        # the desktops still ask in the URL, before the page is first drawn
        self.assertIn('put "?appearance=dark" after tUrl', tab)

    def test_the_palette_gives_a_loaded_page_the_appearance_on_the_web_only(self):
        with open(BEHAVIOR, encoding='utf-8') as f:
            source = f.read()
        code = handler(source, 'on', 'browserNavigateComplete')
        at = code.index('dictApplyAppearance')
        self.assertEqual(code[at - 1], 'if the platform is "HTML5" then')
        self.assertEqual(code[at + 1], 'end if')
        self.assertEqual(code.count('dictApplyAppearance'), 1)


if __name__ == '__main__':
    unittest.main()
