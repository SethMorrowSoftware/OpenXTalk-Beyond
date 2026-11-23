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

"""box3dxt, the xTalk Suite's Box3D binding, as
tools/oxt/xtalk-extensions.json bundles it, and the lists that name the
libraries the web engine links.

The member is taken from the suite repository itself (box3dxt/ in
SethMorrowSoftware/xtalk-suite), so its paths carry the folder. Its web
archive is one of "web_libraries". A web library is named in five places,
and one that is missing from any of them is linked and never found, or
found and never linked: the manifest, KNOWN in xtalk_web_libraries.py, and
the declaration, the name row and the function row of
engine/src/em-xtalk-web.cpp, whose two tables are read by the same index;
the web standalone builder's kXTalkWebLibraries chooses the engine that has
them. No network.

  python3 -m unittest discover -s tools/ci/tests
"""

import ast
import os
import re
import sys
import unittest

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))

import xtalk_extensions  # noqa: E402
import xtalk_web_libraries  # noqa: E402

ENGINE = os.path.join(REPO, 'engine', 'src', 'em-xtalk-web.cpp')
BUILDER = os.path.join(REPO, 'ide-support', 'revsaveasemscriptenstandalone.livecodescript')
JAVASCRIPTIFY = os.path.join(REPO, 'util', 'emscripten-javascriptify.py')
WEB_IDE = os.path.join(REPO, '.github', 'workflows', 'web-ide.yml')
MODULE = 'org.openxtalk.library.boxthreed'


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def engine_lists(text):
    """The three lists of em-xtalk-web.cpp, each in the order written"""
    declared = re.findall(r'__attribute__\(\(weak\)\) const MCSLibraryStaticExport \*(\w+)_web_exports\(void\);', text)
    names = re.findall(r'\{ nullptr, "(\w+)", nullptr \},', text)
    table = text[text.index('t_exports[])(void) ='):]
    table = table[:table.index('};')]
    functions = re.findall(r'^\s*(\w+)_web_exports,\s*$', table, re.M)
    return declared, names, functions


def builder_constant(name, text):
    m = re.search(r'^constant %s = "([^"]*)"' % re.escape(name), text, re.M)
    return m.group(1).split(',')


class WebLibraryNamesTest(unittest.TestCase):

    def test_the_engines_three_lists_are_one_list(self):
        declared, names, functions = engine_lists(read(ENGINE))
        self.assertTrue(names)
        # The name row and the function row are read by the same index
        self.assertEqual(names, functions)
        self.assertEqual(names, declared)

    def test_the_fetcher_knows_what_the_engine_registers(self):
        _, names, _ = engine_lists(read(ENGINE))
        self.assertEqual(list(xtalk_web_libraries.KNOWN), names)

    def test_every_pinned_library_is_one_the_engine_registers(self):
        pinned = [w['name'] for w in xtalk_web_libraries.load()[1]['libraries']]
        _, names, _ = engine_lists(read(ENGINE))
        self.assertEqual(sorted(pinned), sorted(names))

    def test_the_web_builder_asks_for_the_same_libraries(self):
        _, names, _ = engine_lists(read(ENGINE))
        self.assertEqual(builder_constant('kXTalkWebLibraries', read(BUILDER)), names)

    def test_a_list_out_of_step_is_seen(self):
        # The readers above must see a row that is missing or moved
        text = read(ENGINE)
        declared, names, functions = engine_lists(text.replace('\t\tbox3dxt_web_exports,\n', ''))
        self.assertNotEqual(names, functions)
        declared, names, functions = engine_lists(text.replace('\t{ nullptr, "box3dxt", nullptr },\n', ''))
        self.assertNotEqual(names, functions)


class Box3dxtMemberTest(unittest.TestCase):

    def setUp(self):
        self.data = xtalk_extensions.load_manifest()
        self.member = next((m for m in self.data['members'] if m['name'] == 'box3dxt'), None)
        self.assertIsNotNone(self.member, 'no box3dxt member in xtalk-extensions.json')

    def test_taken_from_the_suite(self):
        self.assertEqual(self.member['repository'], 'SethMorrowSoftware/xtalk-suite')
        for f in self.member['files']:
            self.assertTrue(f['path'].startswith('box3dxt/'), f['path'])

    def test_a_library_for_every_platform(self):
        have = {xtalk_extensions.library_platform(f)
                for f in xtalk_extensions.member_files(self.member, 'library')}
        self.assertEqual(have, set(self.data['platforms']))

    def test_windows_needs_no_runtime_dlls(self):
        # Built with the static CRT (/MT): nothing to copy next to it
        for f in xtalk_extensions.member_files(self.member, 'library'):
            if xtalk_extensions.library_platform(f) in xtalk_extensions.WINDOWS_PLATFORMS:
                extra = [d for d in f['imports'] if not xtalk_extensions.is_system_dll(d)]
                self.assertEqual(extra, [], f['path'])

    def test_one_library_extension_and_its_probe(self):
        exts = [(e['kind'], e['id']) for e in self.member['extensions']]
        self.assertEqual(exts, [('lcb', MODULE)])
        e = self.member['extensions'][0]
        self.assertEqual(e['probe'], 'b3LibraryVersion()')
        # What the shim answers: its ABI, then Box3D's own version
        self.assertRegex('box3dxt ABI 3; Box3D 0.2.0', e['expect'])
        self.assertNotRegex('box3dxt', e['expect'])

    def test_its_licence_is_carried(self):
        self.assertTrue(xtalk_extensions.member_files(self.member, 'licence'))

    def test_the_web_engine_links_it(self):
        web = {w['name']: w for w in xtalk_web_libraries.load()[1]['libraries']}
        self.assertIn('box3dxt', web)
        self.assertEqual(web['box3dxt']['repository'], self.member['repository'])
        self.assertEqual(web['box3dxt']['path'], 'box3dxt/src/code/wasm32-emscripten/box3dxt.a')
        self.assertEqual(web['box3dxt']['emscripten'], xtalk_web_libraries.emscripten_version())

    def test_a_web_standalone_that_uses_it_gets_that_engine(self):
        builder = read(BUILDER)
        self.assertIn(MODULE, builder_constant('kXTalkWebExtensions', builder))
        self.assertIn('box3dxt', builder_constant('kXTalkWebLibraries', builder))

    def test_asyncify_leaves_the_physics_step_alone(self):
        # As Box2Dxt's 'b2*': Box3D and the shim never yield, and without
        # the pattern Asyncify instruments b3World_Step and everything it
        # reaches through a pointer (a slower, larger engine)
        tree = ast.parse(read(JAVASCRIPTIFY))
        lists = [ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                 and any(getattr(t, 'id', None) == 'asyncify_remove_xtalk' for t in n.targets)]
        self.assertEqual(len(lists), 1)
        self.assertIn('b3*', lists[0])

    def test_the_web_ide_check_builds_it_from_its_pin(self):
        # The web IDE's xTalk check runs on the newest release's package,
        # which may not bundle box3dxt yet: the extensions this checkout
        # pins are built into it before its site is made, or the engine
        # links Box3D with no extension to call it
        steps = yaml.safe_load(read(WEB_IDE))['jobs']['xtalk']['steps']
        names = [s.get('name') for s in steps]
        build = names.index("Build the suite's extensions as pinned")
        self.assertLess(build, names.index('Build the site'))
        run = steps[build]['run']
        self.assertIn('tools/oxt/xtalk_extensions.py build', run)
        self.assertIn('--out "$OXT_ROOT/Extensions"', run)


if __name__ == '__main__':
    unittest.main()
