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

"""audioxt, the xTalk Suite's sound library (miniaudio behind
org.openxtalk.library.audioxt), as tools/oxt/xtalk-extensions.json bundles
it and the web engine links it.

The member is taken from the suite repository itself (audioxt/ in
SethMorrowSoftware/xtalk-suite), so its paths carry the folder. Its web
archive is one of "web_libraries", and a web-linked library is named in
more places than the manifest: one left out fails only in a browser, with
"unable to load foreign library" when the engine has no table for it, or,
for this library, as code the browser's Web Audio calls into for every
block of sound. This holds each place to the others for audioxt: the
manifest, KNOWN in xtalk_web_libraries.py, the declaration, the name row
and the function row of engine/src/em-xtalk-web.cpp (read by one index),
the web standalone builder's two lists, the names kept out of Asyncify,
and the browser check's step. No network.

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

MODULE = 'org.openxtalk.library.audioxt'


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
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


def asyncify_remove_xtalk(text):
    """The patterns of util/emscripten-javascriptify.py's asyncify_remove_xtalk"""
    block = text[text.index('asyncify_remove_xtalk = ['):]
    block = block[:block.index('\n    ]')]
    code = '\n'.join(line.split('#', 1)[0] for line in block.split('\n')[1:])
    return re.findall(r"'([^']+)'", code)


class AudioxtWebTest(unittest.TestCase):

    def test_the_engine_registers_it_at_one_index(self):
        declared, names, functions = engine_lists(read('engine', 'src', 'em-xtalk-web.cpp'))
        self.assertIn('audioxt', names)
        # The name row and the function row are read by the same index
        self.assertEqual(names.index('audioxt'), functions.index('audioxt'))
        self.assertEqual(names.index('audioxt'), declared.index('audioxt'))

    def test_a_row_out_of_step_is_seen(self):
        # The reader above must see a row that is missing
        text = read('engine', 'src', 'em-xtalk-web.cpp')
        _, names, functions = engine_lists(text.replace('\t\taudioxt_web_exports,\n', ''))
        self.assertNotIn('audioxt', functions)
        self.assertIn('audioxt', names)

    def test_the_fetcher_knows_it(self):
        self.assertIn('audioxt', xtalk_web_libraries.KNOWN)

    def test_its_archive_is_pinned_from_the_suite(self):
        web = {w['name']: w for w in xtalk_web_libraries.load()[1]['libraries']}
        self.assertIn('audioxt', web)
        self.assertEqual(web['audioxt']['repository'], 'SethMorrowSoftware/xtalk-suite')
        self.assertEqual(web['audioxt']['path'], 'audioxt/src/code/wasm32-emscripten/audioxt.a')
        self.assertEqual(web['audioxt']['emscripten'], xtalk_web_libraries.emscripten_version())

    def test_a_web_standalone_that_uses_it_gets_that_engine(self):
        builder = read('ide-support', 'revsaveasemscriptenstandalone.livecodescript')
        self.assertIn(MODULE, builder_constant('kXTalkWebExtensions', builder))
        self.assertIn('audioxt', builder_constant('kXTalkWebLibraries', builder))

    def test_its_names_are_kept_out_of_asyncify(self):
        # Web Audio calls into the library for each block of sound, while
        # the engine may be asleep; the shim's exports and miniaudio, whose
        # every function is ma_*, are left uninstrumented (and smaller)
        patterns = asyncify_remove_xtalk(read('util', 'emscripten-javascriptify.py'))
        self.assertIn('aux_*', patterns)
        self.assertIn('ma_*', patterns)

    def test_no_other_ma_function_is_in_the_web_engine(self):
        # 'ma_*' also matches MySQL's client library (libmariadb), whose
        # functions must not be left out of Asyncify if it is ever linked
        # into the web engine. It is not: the web's revDB has the SQLite
        # driver alone (revdb.gyp's emscripten targets, em-externals.cpp)
        gyp = read('revdb', 'revdb.gyp')
        web = gyp[gyp.index('\'OS == "emscripten"\''):]
        self.assertIn('dbsqlite-static', web)
        self.assertNotIn('mysql', web.lower())
        self.assertNotIn('mysql', read('engine', 'src', 'em-externals.cpp').lower())

    def test_the_browser_check_has_an_audio_step(self):
        text = read('tools', 'ci', 'web-ide-xtalk.livecodescript')
        steps = re.search(r'^constant kSteps = "([^"]*)"', text, re.M).group(1).split(',')
        self.assertIn('audio', steps)
        body = re.search(r'^on xt_audio\n(.*?)^end xt_audio', text, re.M | re.S)
        self.assertIsNotNone(body)
        for call in ('auLibraryVersion', 'auBackendName', 'auEngineCreateOffline', 'auEngineRender',
                     'auWAVEncode', 'auDecodeData', 'auEngineCreate(0', 'auShutDown'):
            self.assertIn(call, body.group(1), call)
        # The desktop's mix, which the WebAssembly build gives bit for bit
        self.assertRegex(text, r'(?m)^constant kAudioMixSha1 = "[0-9a-f]{40}"$')

    def test_the_browser_check_runs_this_checkout_s_extensions(self):
        # The check's site is made from a released install, whose
        # Extensions are that release's: a member added since would have
        # its table in the engine built here and no extension in the page.
        # The job builds the pinned ones over them before it builds the site.
        text = read('.github', 'workflows', 'web-ide.yml')
        job = text[text.index('Fetch the suite\'s apps and relay library'):]
        job = job[:job.index('Web IDE xTalk Suite check')]
        build = job.find('xtalk_extensions.py build --bin "$OXT_ROOT/Toolchain" --out "$OXT_ROOT/Extensions"')
        site = job.find('tools/web-ide/build_site.py --install "$OXT_ROOT"')
        self.assertGreater(build, -1)
        self.assertGreater(site, build)


class AudioxtMemberTest(unittest.TestCase):

    def setUp(self):
        self.data = xtalk_extensions.load_manifest()
        self.member = next((m for m in self.data['members'] if m['name'] == 'audioxt'), None)
        self.assertIsNotNone(self.member, 'no audioxt member in xtalk-extensions.json')

    def test_taken_from_the_suite(self):
        self.assertEqual(self.member['repository'], 'SethMorrowSoftware/xtalk-suite')
        for f in self.member['files']:
            self.assertTrue(f['path'].startswith('audioxt/'), f['path'])

    def test_the_web_archive_is_the_member_s_commit(self):
        # One commit for the extension and the engine's archive: a binding
        # newer than the archive would bind a symbol the table lacks
        web = {w['name']: w for w in xtalk_web_libraries.load()[1]['libraries']}
        self.assertEqual(web['audioxt']['commit'], self.member['commit'])

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
        self.assertEqual(e['probe'], 'auLibraryVersion()')
        # What the shim answers: its ABI, then miniaudio's own version
        self.assertRegex('audioxt ABI 1; miniaudio 0.11.26', e['expect'])
        self.assertNotRegex('audioxt', e['expect'])

    def test_its_licence_is_carried(self):
        self.assertTrue(xtalk_extensions.member_files(self.member, 'licence'))


if __name__ == '__main__':
    unittest.main()
