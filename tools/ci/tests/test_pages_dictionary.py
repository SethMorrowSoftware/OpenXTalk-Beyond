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

"""The online Dictionary (seth's choice 12A of 2026-10-31): Help >
Dictionary Online opens OXT-Beyond's own Dictionary on the project's GitHub
Pages site, which tools/pages/build_pages.py makes from the web IDE zip
with tools/pages/build_dictionary.py. The web IDE workflow makes it from
its zip and reads it in a browser (tools/pages/check_dictionary.py); the
UI tour picks the menu item. These tests make it from the repository's
viewer with small data, and hold the address the IDE opens to the folder
the site puts it in. Playwright is not needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import io
import json
import os
import re
import shutil
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stderr, redirect_stdout

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
PAGES = os.path.join(REPO, 'tools', 'pages')
VIEWER = os.path.join(REPO, 'ide', 'Documentation', 'html_viewer')
sys.path.insert(0, PAGES)

import build_dictionary  # noqa: E402
import build_pages  # noqa: E402

SCRIPT = [
    {'id': 'livecode_script-1', 'name': 'answer', 'display name': 'answer', 'library': 'livecode_script',
     'type': 'command', 'syntax': ['answer <prompt>']},
    {'id': 'livecode_script-2', 'name': 'ask', 'display name': 'ask', 'library': 'livecode_script',
     'type': 'command', 'syntax': ['ask <prompt>']},
]
BUILDER = [
    {'id': 'livecode_builder-1', 'name': 'absoperator', 'display name': 'AbsOperator',
     'library': 'livecode_builder', 'type': 'operator', 'syntax': ['the abs of <Operand>']},
]


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def entries_js(entries):
    # (as the docs builder writes them: the objects, with commas, no brackets)
    return ',\n'.join(json.dumps(e, indent=1) for e in entries)


def make_viewer(folder, script=SCRIPT, builder=BUILDER):
    """A copy of the repository's viewer (its template, css/, js/, fonts/
    and resources/media/, which git keeps) with small dictionary data."""
    shutil.copyfile(os.path.join(VIEWER, 'api.html.template'), os.path.join(folder, 'api.html.template'))
    for part in build_dictionary.COPIED:
        shutil.copytree(os.path.join(VIEWER, part), os.path.join(folder, part))
    for name, entries in (('livecode_script', script), ('livecode_builder', builder)):
        data = os.path.join(folder, 'resources', 'data', 'api_' + name)
        os.makedirs(data)
        if entries is not None:
            with open(os.path.join(data, name + '.js'), 'w', encoding='utf-8') as f:
                f.write(entries_js(entries))
    return folder


def make_ide_zip(path, viewer=None):
    """ide.zip as the web IDE has it: the IDE under boot/, the viewer under
    boot/Documentation/html_viewer."""
    with zipfile.ZipFile(path, 'w') as z:
        z.writestr('boot/Toolset/home.livecodescript', 'script "home"\n')
        if viewer:
            for root, dirs, names in os.walk(viewer):
                for name in names:
                    full = os.path.join(root, name)
                    rel = os.path.relpath(full, viewer).replace(os.sep, '/')
                    z.write(full, build_dictionary.IDE_ZIP_PREFIX + rel)
            z.writestr(build_dictionary.IDE_ZIP_PREFIX + 'resources/data/api/api.sqlite', b'SQLite format 3\0')


class Build(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-dictionary-')
        self.viewer = os.path.join(self.work, 'viewer')
        os.makedirs(self.viewer)
        self.out = os.path.join(self.work, 'out')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def out_text(self, *path):
        with open(os.path.join(self.out, *path), encoding='utf-8') as f:
            return f.read()

    def test_the_page(self):
        make_viewer(self.viewer)
        counts = build_dictionary.build(self.viewer, self.out, '0.2.7-rc.6.11')
        self.assertEqual(counts, {'xTalk Script': 2, 'xTalk Builder': 1})
        page = self.out_text('index.html')
        self.assertIn('<title>OXT-Beyond Dictionary 0.2.7-rc.6.11</title>', page)
        self.assertNotIn('[[', page)
        self.assertIn('<script charset="UTF-8" src="built_api.js"></script>', page)
        self.assertIn('<link href="css/lcdoc.css" rel="stylesheet">', page)
        self.assertIn("setEdition('community');", page)
        self.assertIn("goEntryName('', '', '');", page)
        # every file the page loads is there
        for ref in re.findall(r'(?:src|href)="((?:css|js)/[^"]+|built_api\.js)"', page):
            self.assertTrue(os.path.isfile(os.path.join(self.out, *ref.split('/'))), ref)

    def test_the_data(self):
        make_viewer(self.viewer)
        build_dictionary.build(self.viewer, self.out)
        text = self.out_text('built_api.js')
        self.assertTrue(text.startswith('var dictionary_data =\n{\n\t"docs":['))
        data = json.loads(text[len('var dictionary_data ='):])
        self.assertEqual([(d['display name'], d['name']) for d in data['docs']],
                         [('xTalk Script', 'livecode_script'), ('xTalk Builder', 'livecode_builder')])
        self.assertEqual(data['docs'][0]['doc'], SCRIPT)
        self.assertEqual(data['docs'][1]['doc'], BUILDER)

    def test_files_in_name_order(self):
        # (an API's .js files are joined in name order, as one list)
        make_viewer(self.viewer)
        folder = os.path.join(self.viewer, 'resources', 'data', 'api_livecode_script')
        os.rename(os.path.join(folder, 'livecode_script.js'), os.path.join(folder, 'script.js'))
        with open(os.path.join(folder, 'dg.js'), 'w', encoding='utf-8') as f:
            f.write(entries_js([dict(SCRIPT[0], id='livecode_script-9', name='datagrid')]))
        counts = build_dictionary.build(self.viewer, self.out)
        self.assertEqual(counts['xTalk Script'], 3)
        data = json.loads(self.out_text('built_api.js')[len('var dictionary_data ='):])
        self.assertEqual([e['name'] for e in data['docs'][0]['doc']], ['datagrid', 'answer', 'ask'])

    def test_no_missing_images(self):
        # lcdoc.css's edition badges name LiveCode's commercial skins, which
        # no OXT-Beyond IDE has: those declarations go, their glyph stays
        make_viewer(self.viewer)
        build_dictionary.build(self.viewer, self.out)
        css = self.out_text('css', 'lcdoc.css')
        self.assertNotIn('ideSkin/bubble.png', css)
        self.assertIn('url("../resources/media/vertical_resizer_580.png")', css)
        self.assertIn('#table_list tr.indy > td:nth-child(1):before {\n\tfont-family: "Glyphicons Halflings";', css)
        self.assertIn('ideSkin/bubble.png', read('ide', 'Documentation', 'html_viewer', 'css', 'lcdoc.css'))

    def test_another_missing_file_is_refused(self):
        make_viewer(self.viewer)
        with open(os.path.join(self.viewer, 'css', 'codestyle.css'), 'a', encoding='utf-8') as f:
            f.write('\nbody { background: url("../resources/media/none.png"); }\n')
        with self.assertRaisesRegex(build_dictionary.DictionaryError, 'none.png'):
            build_dictionary.build(self.viewer, self.out)

    def test_no_data(self):
        make_viewer(self.viewer)
        shutil.rmtree(os.path.join(self.viewer, 'resources', 'data', 'api_livecode_builder'))
        with self.assertRaisesRegex(build_dictionary.DictionaryError, 'build_docs.sh'):
            build_dictionary.build(self.viewer, self.out)
        self.assertFalse(os.path.exists(self.out))

    def test_an_api_without_entries(self):
        make_viewer(self.viewer, builder=None)
        with self.assertRaisesRegex(build_dictionary.DictionaryError, 'no entries'):
            build_dictionary.build(self.viewer, self.out)

    def test_data_that_is_not_json(self):
        make_viewer(self.viewer)
        with open(os.path.join(self.viewer, 'resources', 'data', 'api_livecode_builder', 'livecode_builder.js'),
                  'a', encoding='utf-8') as f:
            f.write('}')
        with self.assertRaisesRegex(build_dictionary.DictionaryError, 'not JSON'):
            build_dictionary.build(self.viewer, self.out)

    def test_a_hole_left(self):
        make_viewer(self.viewer)
        with open(os.path.join(self.viewer, 'api.html.template'), 'a', encoding='utf-8') as f:
            f.write('<!-- [[tSomethingNew]] -->\n')
        with self.assertRaisesRegex(build_dictionary.DictionaryError, r'\[\[tSomethingNew\]\]'):
            build_dictionary.build(self.viewer, self.out)

    def test_not_an_empty_folder(self):
        make_viewer(self.viewer)
        os.makedirs(self.out)
        with open(os.path.join(self.out, 'x'), 'w') as f:
            f.write('x')
        with self.assertRaisesRegex(build_dictionary.DictionaryError, 'not empty'):
            build_dictionary.build(self.viewer, self.out)

    def test_the_template_has_every_hole(self):
        # the holes this page fills are the template's, and the title is
        # the one replaced
        template = read('ide', 'Documentation', 'html_viewer', 'api.html.template')
        self.assertEqual(sorted(set(re.findall(r'\[\[[^\]]*\]\]', template))), sorted(build_dictionary.HOLES))
        self.assertEqual(template.count('<title>Dictionary</title>'), 1)


class FromTheWebIde(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-dictionary-')
        os.makedirs(os.path.join(self.work, 'viewer'))
        self.viewer = make_viewer(os.path.join(self.work, 'viewer'))
        self.site = os.path.join(self.work, 'site')
        os.makedirs(self.site)
        self.out = os.path.join(self.work, 'out')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def test_the_ide_zip(self):
        make_ide_zip(os.path.join(self.site, 'ide.zip'), self.viewer)
        counts = build_dictionary.build_from_ide_site(self.site, self.out)
        self.assertEqual(counts, {'xTalk Script': 2, 'xTalk Builder': 1})
        self.assertTrue(os.path.isfile(os.path.join(self.out, 'index.html')))
        # (the data is in built_api.js; the IDE's database is not copied)
        self.assertFalse(os.path.exists(os.path.join(self.out, 'resources', 'data')))

    def test_an_ide_without_the_viewer(self):
        make_ide_zip(os.path.join(self.site, 'ide.zip'))
        with self.assertRaises(build_dictionary.NoViewer):
            build_dictionary.build_from_ide_site(self.site, self.out)
        err = io.StringIO()
        with redirect_stderr(err):
            status = build_dictionary.main(['--ide-site', self.site, '--out', self.out])
        self.assertEqual(status, 3)
        self.assertIn('no boot/Documentation/html_viewer/api.html.template', err.getvalue())

    def test_main(self):
        make_ide_zip(os.path.join(self.site, 'ide.zip'), self.viewer)
        out = io.StringIO()
        with redirect_stdout(out):
            status = build_dictionary.main(['--ide-site', self.site, '--out', self.out, '--version', '1.2'])
        self.assertEqual(status, 0)
        self.assertIn('xTalk Script: 2 entries', out.getvalue())
        self.assertIn('xTalk Builder: 1 entries', out.getvalue())


class TheSite(unittest.TestCase):
    """build_pages.py puts the Dictionary beside the web IDE, from it."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-')
        os.makedirs(os.path.join(self.work, 'viewer'))
        self.viewer = make_viewer(os.path.join(self.work, 'viewer'))
        self.out = os.path.join(self.work, 'site')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def web_ide_zip(self, with_viewer):
        ide_zip = os.path.join(self.work, 'ide.zip')
        make_ide_zip(ide_zip, self.viewer if with_viewer else None)
        path = os.path.join(self.work, 'OXT-Beyond-9.9.9-web-ide.zip')
        with zipfile.ZipFile(path, 'w') as z:
            z.writestr('OXT-Beyond-9.9.9-web-ide/index.html', '<!DOCTYPE html><title>Web IDE</title>')
            z.write(ide_zip, 'OXT-Beyond-9.9.9-web-ide/ide.zip')
            z.writestr('OXT-Beyond-9.9.9-web-ide/serve.py', '')
        return path

    def build(self, zip_path):
        args = build_pages.argparse.Namespace(out=self.out, ide=zip_path, ide_version='9.9.9', player=None,
                                              player_version=None, map=None, map_version=None)
        with redirect_stdout(io.StringIO()):
            build_pages.build(args)
        with open(os.path.join(self.out, 'index.html'), encoding='utf-8') as f:
            return f.read()

    def test_with_the_dictionary(self):
        front = self.build(self.web_ide_zip(True))
        self.assertTrue(os.path.isfile(os.path.join(self.out, 'dictionary', 'index.html')))
        self.assertTrue(os.path.isfile(os.path.join(self.out, 'dictionary', 'built_api.js')))
        self.assertIn('<a class="button" href="dictionary/">Open the Dictionary</a>', front)
        self.assertIn('<a class="button" href="ide/">Open the Web IDE</a>', front)
        self.assertNotIn('@DICTIONARY', front)
        with open(os.path.join(self.out, 'dictionary', 'index.html'), encoding='utf-8') as f:
            self.assertIn('<title>OXT-Beyond Dictionary 9.9.9</title>', f.read())

    def test_a_web_ide_without_it(self):
        front = self.build(self.web_ide_zip(False))
        self.assertFalse(os.path.exists(os.path.join(self.out, 'dictionary')))
        self.assertNotIn('Open the Dictionary', front)
        self.assertIn('Open the Web IDE', front)

    def test_a_broken_dictionary_stops_the_site(self):
        os.remove(os.path.join(self.viewer, 'resources', 'data', 'api_livecode_script', 'livecode_script.js'))
        with self.assertRaisesRegex(build_pages.BuildError, 'the dictionary'):
            self.build(self.web_ide_zip(True))


class TheIdeOpensIt(unittest.TestCase):
    """Help > Dictionary Online opens the site's Dictionary folder."""

    def url(self, text, name):
        m = re.search(r'^constant %s = "([^"]+)"$' % name, text, re.M)
        self.assertIsNotNone(m, name)
        return m.group(1)

    def test_the_address(self):
        menubar = read('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript')
        url = self.url(menubar, 'kOnlineDictionaryURL')
        # the project's Pages site (as the release posts give it), and the
        # folder build_pages.py puts the Dictionary in
        self.assertEqual(url, 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/dictionary/')
        handler = menubar.split('on tOpenOnlineDict', 1)[1].split('end tOpenOnlineDict', 1)[0]
        live = [l.strip() for l in handler.splitlines() if l.strip() and not l.strip().startswith('--')]
        self.assertEqual(live, ['revGoURL kOnlineDictionaryURL'])
        self.assertIn('case "Dictionary Online"\n         send "tOpenOnlineDict" to this stack', menubar)
        self.assertIn('put "Dictionary Online" & return after tHelp', menubar)

    def test_the_tour_picks_it(self):
        tour = read('tools', 'ci', 'ui-tour.livecodescript')
        menubar = read('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript')
        self.assertEqual(self.url(tour, 'kTourOnlineDictionary'), self.url(menubar, 'kOnlineDictionaryURL'))
        steps = re.search(r'^constant kSteps = "([^"]+)"', tour, re.M).group(1).split(',')
        self.assertIn('dictionary-online', steps)
        self.assertIn('\non tour_dictionary_online\n', tour)
        self.assertIn('dispatch "menuPick" to button "Help" of group "revMenuBar" of stack "revMenuBar" '
                      'with "Dictionary Online"', tour)

    def test_ci_reads_it(self):
        workflow = read('.github', 'workflows', 'web-ide.yml')
        self.assertIn('python3 tools/pages/build_pages.py --out "$RUNNER_TEMP/pages" --ide "$zip"', workflow)
        self.assertIn('tools/pages/check_dictionary.py \\\n            --site "$RUNNER_TEMP/pages/dictionary"',
                      workflow)
        for path in ('tools/pages/build_pages.py', 'tools/pages/build_dictionary.py',
                     'tools/pages/check_dictionary.py'):
            self.assertEqual(workflow.count('      - %s\n' % path), 2, path)


if __name__ == '__main__':
    unittest.main()
