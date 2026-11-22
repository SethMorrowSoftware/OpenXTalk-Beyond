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

"""render3dxt, the xTalk Suite's software 3D renderer, as
tools/oxt/xtalk-extensions.json bundles it, and its place in the lists
that name the libraries the web engine links.

The member is taken from the suite repository itself (render3dxt/ in
SethMorrowSoftware/xtalk-suite), so its paths carry the folder. Its web
archive is one of "web_libraries"; the five places a web library is named
are held to one list by test_xtalk_extensions_box3dxt.py's
WebLibraryNamesTest, so here only render3dxt's own rows are checked. No
network.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))

import xtalk_extensions  # noqa: E402
import xtalk_web_libraries  # noqa: E402

ENGINE = os.path.join(REPO, 'engine', 'src', 'em-xtalk-web.cpp')
BUILDER = os.path.join(REPO, 'ide-support', 'revsaveasemscriptenstandalone.livecodescript')
WEB_IDE_CHECK = os.path.join(REPO, 'tools', 'ci', 'web-ide-xtalk.livecodescript')
JAVASCRIPTIFY = os.path.join(REPO, 'util', 'emscripten-javascriptify.py')
MODULE = 'org.openxtalk.library.renderthreed'


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def builder_constant(name, text):
    m = re.search(r'^constant %s = "([^"]*)"' % re.escape(name), text, re.M)
    return m.group(1).split(',')


class Render3dxtMemberTest(unittest.TestCase):

    def setUp(self):
        self.data = xtalk_extensions.load_manifest()
        self.member = next((m for m in self.data['members'] if m['name'] == 'render3dxt'), None)
        self.assertIsNotNone(self.member, 'no render3dxt member in xtalk-extensions.json')

    def test_taken_from_the_suite(self):
        self.assertEqual(self.member['repository'], 'SethMorrowSoftware/xtalk-suite')
        for f in self.member['files']:
            self.assertTrue(f['path'].startswith('render3dxt/'), f['path'])

    def test_a_library_for_every_platform(self):
        have = {xtalk_extensions.library_platform(f)
                for f in xtalk_extensions.member_files(self.member, 'library')}
        self.assertEqual(have, set(self.data['platforms']))

    def test_windows_needs_no_runtime_dlls(self):
        # Built with the static CRT (CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded):
        # nothing to copy next to it
        for f in xtalk_extensions.member_files(self.member, 'library'):
            if xtalk_extensions.library_platform(f) in xtalk_extensions.WINDOWS_PLATFORMS:
                extra = [d for d in f['imports'] if not xtalk_extensions.is_system_dll(d)]
                self.assertEqual(extra, [], f['path'])

    def test_one_library_extension_and_its_probe(self):
        exts = [(e['kind'], e['id']) for e in self.member['extensions']]
        self.assertEqual(exts, [('lcb', MODULE)])
        e = self.member['extensions'][0]
        self.assertEqual(e['probe'], 'r3LibraryVersion()')
        # What the shim answers (r3x_library_version): its version and ABI,
        # then the two readers compiled in
        self.assertRegex('render3dxt 0.1.0 ABI 1; stb_image 2.34; fast_obj 1.3', e['expect'])
        self.assertNotRegex('render3dxt', e['expect'])
        self.assertNotRegex('box3dxt ABI 3; Box3D 0.2.0', e['expect'])

    def test_its_licence_is_carried(self):
        # LICENSE holds the notices of stb_image and fast_obj too
        self.assertTrue(xtalk_extensions.member_files(self.member, 'licence'))

    def test_the_web_engine_links_it(self):
        web = {w['name']: w for w in xtalk_web_libraries.load()[1]['libraries']}
        self.assertIn('render3dxt', web)
        self.assertEqual(web['render3dxt']['repository'], self.member['repository'])
        self.assertEqual(web['render3dxt']['path'], 'render3dxt/src/code/wasm32-emscripten/render3dxt.a')
        self.assertEqual(web['render3dxt']['emscripten'], xtalk_web_libraries.emscripten_version())
        self.assertIn('render3dxt', xtalk_web_libraries.KNOWN)
        self.assertIn('render3dxt_web_exports', read(ENGINE))

    def test_asyncify_leaves_it_out(self):
        # util/emscripten-javascriptify.py: the families of functions that
        # call through a pointer (its readers' input functions, the text
        # results' snprintf) and never yield, which Asyncify would
        # otherwise instrument, as it would the whole of stb_image
        text = read(JAVASCRIPTIFY)
        m = re.search(r'^asyncify_remove_xtalk = \[(.*?)^    \]', text, re.M | re.S)
        self.assertIsNotNone(m, 'no asyncify_remove_xtalk list')
        body = '\n'.join(line.split('#', 1)[0] for line in m.group(1).splitlines())
        names = re.findall(r"'([^']+)'", body)
        for name in ('r3x_*', 'stbi*', 'fast_obj*'):
            self.assertIn(name, names)
        # Only by prefix: a plain name of the shim's own could be the name
        # of an engine function that does yield
        for name in ('text_of', 'file_open', 'parse_float'):
            self.assertNotIn(name, names)

    def test_a_web_standalone_that_uses_it_gets_that_engine(self):
        builder = read(BUILDER)
        self.assertIn(MODULE, builder_constant('kXTalkWebExtensions', builder))
        self.assertIn('render3dxt', builder_constant('kXTalkWebLibraries', builder))

    def test_the_web_ide_check_runs_it(self):
        # tools/ci/web-ide-xtalk.livecodescript: a step that is not in
        # kSteps never runs, and one in kSteps with no handler fails
        text = read(WEB_IDE_CHECK)
        m = re.search(r'^constant kSteps = "([^"]*)"', text, re.M)
        self.assertIn('render3d', m.group(1).split(','))
        self.assertRegex(text, r'(?m)^on xt_render3d$')


if __name__ == '__main__':
    unittest.main()
