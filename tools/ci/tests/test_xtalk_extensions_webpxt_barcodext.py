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

"""webpxt (WebP pictures, libwebp) and barcodext (barcodes, zxing-cpp), the
xTalk Suite's two image members, as tools/oxt/xtalk-extensions.json bundles
them, and the lists that name the libraries the web engine links.

Both members are taken from the suite repository itself (webpxt/ and
barcodext/ in SethMorrowSoftware/xtalk-suite), so their paths carry the
folder. Their web archives are two of "web_libraries". A web library is
named in five places, and one that is missing from any of them is linked
and never found, or found and never linked: the manifest, KNOWN in
xtalk_web_libraries.py, and the declaration, the name row and the function
row of engine/src/em-xtalk-web.cpp, whose two tables are read by the same
index; the web standalone builder's kXTalkWebLibraries chooses the engine
that has them. No network.

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
BROWSER_CHECK = os.path.join(REPO, 'tools', 'ci', 'web-ide-xtalk.livecodescript')

# member -> (its LCB module, its probe, what the shim answers it)
MEMBERS = {
    'webpxt': ('org.openxtalk.library.webpxt', 'wpLibraryVersion()', 'webpxt ABI 1; libwebp 1.6.0'),
    'barcodext': ('org.openxtalk.library.barcodext', 'bcLibraryVersion()', 'barcodext ABI 1; zxing-cpp 3.1.1'),
}


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


class WebLibraryListsTest(unittest.TestCase):

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
        # The readers above must see a row that is missing
        text = read(ENGINE)
        for name in MEMBERS:
            declared, names, functions = engine_lists(text.replace('\t\t%s_web_exports,\n' % name, ''))
            self.assertNotEqual(names, functions, name)
            declared, names, functions = engine_lists(text.replace('\t{ nullptr, "%s", nullptr },\n' % name, ''))
            self.assertNotEqual(names, functions, name)


class ImageMembersTest(unittest.TestCase):

    def setUp(self):
        self.data = xtalk_extensions.load_manifest()
        self.members = {m['name']: m for m in self.data['members'] if m['name'] in MEMBERS}

    def test_both_are_bundled(self):
        self.assertEqual(sorted(self.members), sorted(MEMBERS))

    def test_taken_from_the_suite(self):
        for name, m in self.members.items():
            self.assertEqual(m['repository'], 'SethMorrowSoftware/xtalk-suite', name)
            for f in m['files']:
                self.assertTrue(f['path'].startswith(name + '/'), f['path'])
            self.assertEqual(m['version_from']['path'], '%s/src/%s.lcb' % (name, name))

    def test_a_library_for_every_platform(self):
        for name, m in self.members.items():
            have = sorted(xtalk_extensions.library_platform(f)
                          for f in xtalk_extensions.member_files(m, 'library'))
            self.assertEqual(have, sorted(self.data['platforms']), name)
            for f in xtalk_extensions.member_files(m, 'library'):
                # Each library carries the member's name, as its .lcb binds it
                self.assertEqual(f['path'].rsplit('/', 1)[-1].split('.')[0], name, f['path'])

    def test_windows_needs_no_runtime_dlls(self):
        # Built with the static CRT (/MT): nothing to copy next to them
        for name, m in self.members.items():
            for f in xtalk_extensions.member_files(m, 'library'):
                if xtalk_extensions.library_platform(f) in xtalk_extensions.WINDOWS_PLATFORMS:
                    extra = [d for d in f['imports'] if not xtalk_extensions.is_system_dll(d)]
                    self.assertEqual(extra, [], f['path'])

    def test_one_library_extension_and_its_probe(self):
        for name, m in self.members.items():
            module, probe, answer = MEMBERS[name]
            self.assertEqual([(e['kind'], e['id']) for e in m['extensions']], [('lcb', module)])
            e = m['extensions'][0]
            self.assertEqual(e['main'], '%s/src/%s.lcb' % (name, name))
            self.assertEqual(e['probe'], probe)
            # What the shim answers: its ABI, then its library's version
            self.assertRegex(answer, e['expect'])
            self.assertNotRegex(name, e['expect'])
            self.assertNotRegex('%s ABI ; ' % name, e['expect'])

    def test_its_licences_are_carried(self):
        for name, m in self.members.items():
            self.assertEqual([f['path'] for f in xtalk_extensions.member_files(m, 'licence')],
                             ['%s/LICENSE' % name], name)

    def test_the_web_engine_links_them(self):
        web = {w['name']: w for w in xtalk_web_libraries.load()[1]['libraries']}
        for name, m in self.members.items():
            self.assertIn(name, web)
            self.assertEqual(web[name]['repository'], m['repository'])
            self.assertEqual(web[name]['path'], '%s/src/code/wasm32-emscripten/%s.a' % (name, name))
            self.assertEqual(web[name]['emscripten'], xtalk_web_libraries.emscripten_version())
            # The archive is the one of the bundled extension's commit: the
            # web engine and the desktop libraries answer the same calls
            self.assertEqual(web[name]['commit'], m['commit'], name)

    def test_their_names_are_kept_out_of_asyncify(self):
        # Neither library waits: instrumented by Asyncify they would be
        # larger and slower for nothing. The patterns are matched as the
        # link matches them, a '*' standing for any run of characters, on
        # names as the wasm's name section spells them (C++ demangled).
        import fnmatch
        text = read(os.path.join(REPO, 'util', 'emscripten-javascriptify.py'))
        block = re.search(r'asyncify_remove_xtalk\s*=\s*\[(.*?)\n\s*\]\n', text, re.S).group(1)
        block = re.sub(r'#[^\n]*', '', block)   # the comments have apostrophes
        names = re.findall(r"'([^']+)'", block)
        for pattern in ('wpx_*', 'WebP*', 'VP8*', 'SharpYuv*', 'bcx_*', '*ZXing::*', 'ZBarcode_*', 'zint_*', 'zueci_*'):
            self.assertIn(pattern, names)
        for name in ('wpx_decode', 'WebPDecodeRGBA', 'VP8LDecodeImage', 'SharpYuvConvert', 'bcx_read_image',
                     'ZXing::ReadBarcodes(ZXing::ImageView const&, ZXing::ReaderOptions const&)',
                     'void ZXing::QRCode::Foo<int>(int)', 'ZBarcode_Encode', 'zint_code128'):
            self.assertTrue(any(fnmatch.fnmatchcase(name, p) for p in names), name)
        # and nothing of the engine's own is taken with them
        for name in ('MCScreenDC::wait(double, bool, bool)', 'MCImage::setimagedata', 'main', 'MCWebpSomething'):
            self.assertFalse(any(fnmatch.fnmatchcase(name, p) for p in names
                                 if p in ('wpx_*', 'WebP*', 'VP8*', 'SharpYuv*', 'bcx_*', '*ZXing::*',
                                          '*librscpp::*', 'ZBarcode_*', 'zint_*', 'gs1_*', 'zueci_*')), name)

    def test_a_web_standalone_that_uses_them_gets_that_engine(self):
        builder = read(BUILDER)
        for name, (module, _, _) in MEMBERS.items():
            self.assertIn(module, builder_constant('kXTalkWebExtensions', builder))
            self.assertIn(name, builder_constant('kXTalkWebLibraries', builder))

    def test_the_browser_check_runs_them(self):
        text = read(BROWSER_CHECK)
        steps = re.search(r'^constant kSteps = "([^"]*)"', text, re.M).group(1).split(',')
        for step, probe in (('webp', 'wpLibraryVersion()'), ('barcode', 'bcLibraryVersion()')):
            self.assertIn(step, steps)
            body = re.search(r'(?ms)^on xt_%s\n(.*?)^end xt_%s$' % (step, step), text)
            self.assertIsNotNone(body, 'no handler xt_%s' % step)
            self.assertIn(probe, body.group(1))


if __name__ == '__main__':
    unittest.main()
