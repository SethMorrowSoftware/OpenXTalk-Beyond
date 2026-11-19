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

"""The online Dictionary opens at the word in its address (seth,
2026-11-19, for the forum's [dict]put[/dict] tag): dictionary/#put or
dictionary/?entry=put opens the entry, ?api=builder an xTalk Builder one,
?type= picks among entries of one name, and a name that is no entry's lists
the entries that have it in them. tools/pages/build_dictionary.py puts the
script in the online page only: the IDE's page (the template) must stay as
it was, which is held here too.

The page is made from the repository's viewer with small data, as
test_pages_dictionary makes it, and opened in Chromium through Node's
Playwright; those cases skip when there is no node or no playwright, and
the ones on the page's text run everywhere.

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, os.path.join(REPO, 'tools', 'pages'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_dictionary  # noqa: E402
import test_pages_dictionary as made  # noqa: E402

NODE = shutil.which('node')

SCRIPT = [
    {'id': 'livecode_script-1', 'name': 'answer', 'display name': 'answer', 'library': 'livecode_script',
     'type': 'command', 'syntax': ['answer <prompt>']},
    {'id': 'livecode_script-2', 'name': 'put', 'display name': 'put', 'library': 'livecode_script',
     'type': 'command', 'syntax': ['put <value>']},
    {'id': 'livecode_script-3', 'name': 'date', 'display name': 'date', 'library': 'livecode_script',
     'type': 'function', 'syntax': ['the date']},
    {'id': 'livecode_script-4', 'name': 'date', 'display name': 'date', 'library': 'livecode_script',
     'type': 'keyword', 'syntax': ['date']},
    {'id': 'livecode_script-5', 'name': 'the date', 'display name': 'the date', 'library': 'livecode_script',
     'type': 'glossary', 'syntax': ['the date']},
]
# (the page's list reads each entry's display syntax, as the docs builder
# writes it)
for _entry in SCRIPT:
    _entry['display syntax'] = _entry['syntax']
BUILDER = [dict(e, **{'display syntax': e['syntax']}) for e in made.BUILDER]

# What the page shows after it has opened at an address: the title of the
# entry it shows, its type, and how many rows its list has
SHOWN = r'''
const { chromium } = require('playwright');
(async () => {
  const [page_url, ...addresses] = process.argv.slice(2);
  const browser = await chromium.launch();
  const out = [];
  try {
    for (const address of addresses) {
      const page = await browser.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(String(e)));
      await page.goto(page_url + address);
      await page.waitForFunction(() => document.querySelector('#table_list tr') || location.hash == '#zzz');
      await page.waitForTimeout(300);
      out.push(await page.evaluate(errs => ({
        title: document.querySelector('#api_entry h1')
          ? document.querySelector('#api_entry h1').childNodes[0].textContent.trim() : null,
        type: (tState.data[tState.selected_entry_index[tState.selected_api_id]] || {}).type,
        api: dictionary_data.docs[tState.selected_api_id].name,
        rows: document.querySelectorAll('#table_list tr').length,
        errors: errs,
      }), errors));
      if (address === '#put') {
        await page.evaluate(() => { location.hash = 'answer'; });
        await page.waitForFunction(() =>
          document.querySelector('#api_entry h1').textContent.indexOf('answer') === 0);
        out.push({ title: 'after hashchange: answer' });
        await page.evaluate(() => { location.hash = ''; });
        await page.waitForTimeout(150);
        out.push({ title: await page.evaluate(() =>
          document.querySelector('#api_entry h1').childNodes[0].textContent.trim()) });
      }
      await page.close();
    }
  } finally {
    await browser.close();
  }
  console.log(JSON.stringify(out));
})().catch(e => { console.error(e); process.exit(1); });
'''


def has_playwright():
    if not NODE:
        return False
    return subprocess.run([NODE, '-e', 'require("playwright")'], capture_output=True).returncode == 0


class Page(unittest.TestCase):
    """The script is in the online page and not in the IDE's."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-deep-link-')
        viewer = os.path.join(self.work, 'viewer')
        os.makedirs(viewer)
        made.make_viewer(viewer, script=SCRIPT, builder=BUILDER)
        self.out = os.path.join(self.work, 'out')
        build_dictionary.build(viewer, self.out)
        with open(os.path.join(self.out, 'index.html'), encoding='utf-8') as f:
            self.page = f.read()

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def test_online_page_has_it_once_after_the_ready_handler(self):
        self.assertEqual(self.page.count(build_dictionary.DEEP_LINK_MARK), 1)
        self.assertLess(self.page.index("goEntryName('', '', '')"),
                        self.page.index(build_dictionary.DEEP_LINK_MARK))
        self.assertLess(self.page.index(build_dictionary.DEEP_LINK_MARK), self.page.index('</body>'))

    def test_template_does_not(self):
        with open(os.path.join(made.VIEWER, 'api.html.template'), encoding='utf-8') as f:
            template = f.read()
        self.assertNotIn(build_dictionary.DEEP_LINK_MARK, template)
        self.assertNotIn('hashchange', template)

    def test_a_page_with_no_single_body_is_refused(self):
        with self.assertRaises(build_dictionary.DictionaryError):
            build_dictionary.opens_at_a_word('<html></html>')
        with self.assertRaises(build_dictionary.DictionaryError):
            build_dictionary.opens_at_a_word('</body></body>')

    @unittest.skipUnless(has_playwright(), 'needs node and its playwright')
    def test_in_a_browser(self):
        script = os.path.join(self.work, 'shown.js')
        with open(script, 'w', encoding='utf-8') as f:
            f.write(SHOWN)
        url = 'file://' + os.path.join(self.out, 'index.html')
        addresses = ['', '#put', '?entry=answer', '#PUT', '?entry=date&type=keyword',
                     '?entry=date&type=function', '#the%20date', '?entry=the+date',
                     '?entry=absoperator&api=builder', '#zzz', '#%E0%A4%A']
        done = subprocess.run([NODE, script, url] + addresses, capture_output=True, text=True,
                              timeout=180, env=dict(os.environ, NODE_PATH=self.node_path()))
        self.assertEqual(done.returncode, 0, done.stderr)
        shown = json.loads(done.stdout.strip().splitlines()[-1])
        plain, put, after, emptied, answer, upper, keyword, function, spaced, plus, builder, nothing, bad = shown
        for each in (plain, put, answer, upper, keyword, function, spaced, plus, builder, nothing, bad):
            self.assertEqual(each['errors'], [])
        # with no word, the page opens as it did: at its list, no entry drawn
        self.assertIsNone(plain['title'])
        self.assertEqual(plain['rows'], len(SCRIPT))
        self.assertEqual(put['title'], 'put')
        self.assertEqual(after['title'], 'after hashchange: answer')
        # an empty #, as the viewer's own href="#" links make, is let be
        self.assertEqual(emptied['title'], 'answer')
        self.assertEqual(emptied.get('errors', []), [])
        self.assertEqual(answer['title'], 'answer')
        self.assertEqual(upper['title'], 'put')
        self.assertEqual((keyword['title'], keyword['type']), ('date', 'keyword'))
        self.assertEqual((function['title'], function['type']), ('date', 'function'))
        self.assertEqual(spaced['title'], 'the date')
        self.assertEqual(plus['title'], 'the date')
        self.assertEqual((builder['title'], builder['api']), ('AbsOperator', 'livecode_builder'))
        # no entry has the name: the list is searched for it, and nothing is
        # found; a hash that is not text is let be
        self.assertEqual(nothing['rows'], 0)
        self.assertIsNone(bad['title'])
        self.assertEqual(bad['rows'], len(SCRIPT))

    @staticmethod
    def node_path():
        # the pre-installed playwright is global to node
        root = subprocess.run(['npm', 'root', '-g'], capture_output=True, text=True).stdout.strip()
        return os.pathsep.join(p for p in (os.environ.get('NODE_PATH', ''), root) if p)


if __name__ == '__main__':
    unittest.main()
