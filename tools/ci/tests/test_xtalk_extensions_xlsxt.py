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

"""xlsxt, the xTalk Suite's Excel .xlsx library (libxlsxwriter, zlib and
Expat behind org.openxtalk.library.xlsxt), as OXT-Beyond bundles it and
links it into the web engine.

A member that is linked into the web engine is named in six places, and
one left out fails only in a browser: with "unable to load foreign
library" when the engine has no table for it, or with a call that never
returns when its C names are not kept out of Asyncify. This holds the six
to each other. No network.

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
import xtalk_web_libraries as xwl  # noqa: E402

EXTENSION = 'org.openxtalk.library.xlsxt'


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def constant(name, text):
    return re.search(r'^constant %s = "([^"]*)"' % name, text, re.M).group(1)


class XlsxtMemberTest(unittest.TestCase):

    def setUp(self):
        self.data = xtalk_extensions.load_manifest()
        self.member = next((m for m in self.data['members'] if m['name'] == 'xlsxt'), None)
        self.assertIsNotNone(self.member, 'no xlsxt member in xtalk-extensions.json')

    def test_taken_from_the_suite(self):
        self.assertEqual(self.member['repository'], 'SethMorrowSoftware/xtalk-suite')
        own = [f['path'] for f in self.member['files'] if 'repository' not in f]
        self.assertTrue(own)
        for path in own:
            self.assertTrue(path.startswith('xlsxt/'), path)

    def test_one_extension_that_says_what_it_is(self):
        exts = [(e['kind'], e['id']) for e in self.member['extensions']]
        self.assertEqual(exts, [('lcb', EXTENSION)])
        e = self.member['extensions'][0]
        self.assertEqual(e['probe'], 'xlLibraryVersion()')
        self.assertRegex('xlsxt ABI 1; libxlsxwriter 1.2.4; zlib 1.4; expat 2.10.0', e['expect'])
        self.assertNotRegex('', e['expect'])

    def test_its_licences_are_carried(self):
        paths = [f['path'] for f in self.member['files'] if f['role'] == 'licence']
        self.assertIn('xlsxt/LICENSE', paths)
        # libxlsxwriter's, zlib's and Expat's notices, which the BSD and MIT
        # licences ask to have beside the binaries
        self.assertIn('xlsxt/THIRD-PARTY-LICENSES.md', paths)

    def test_a_library_for_every_platform(self):
        # a desktop or Android package with the extension and no library
        # would list a library whose every call fails
        have = {xtalk_extensions.library_platform(f)
                for f in xtalk_extensions.member_files(self.member, 'library')}
        self.assertEqual(have, set(self.data['platforms']))

    def test_windows_needs_no_runtime_dlls(self):
        for f in xtalk_extensions.member_files(self.member, 'library'):
            if xtalk_extensions.library_platform(f) in xtalk_extensions.WINDOWS_PLATFORMS:
                extra = [d for d in f['imports'] if not xtalk_extensions.is_system_dll(d)]
                self.assertEqual(extra, [], f['path'])


class XlsxtWebTest(unittest.TestCase):

    def setUp(self):
        self.libs = {lib['name']: lib for lib in xwl.load()[1]['libraries']}

    def test_the_archive_is_pinned(self):
        self.assertIn('xlsxt', self.libs)
        lib = self.libs['xlsxt']
        self.assertEqual(lib['repository'], 'SethMorrowSoftware/xtalk-suite')
        self.assertEqual(lib['path'], 'xlsxt/src/code/wasm32-emscripten/xlsxt.a')
        # one compiler for everything linked into one module
        self.assertEqual({l['emscripten'] for l in self.libs.values()}, {lib['emscripten']})

    def test_the_engine_has_its_table(self):
        cpp = read('engine', 'src', 'em-xtalk-web.cpp')
        for name in xwl.KNOWN:
            self.assertRegex(cpp, r'__attribute__\(\(weak\)\)[^;\n]*\b%s_web_exports\(void\);' % name)
            self.assertIn('{ nullptr, "%s", nullptr }' % name, cpp)
            self.assertRegex(cpp, r'(?m)^\s*%s_web_exports,' % name)

    def test_its_c_names_are_kept_out_of_asyncify(self):
        # A library that never waits: instrumented by Asyncify it would be
        # larger and slower for nothing, and the names are those the suite's
        # wasm lane holds every global of the archive to.
        text = read('util', 'emscripten-javascriptify.py')
        block = re.search(r'asyncify_remove_xtalk\s*=\s*\[(.*?)\n\s*\]\n', text, re.S).group(1)
        block = re.sub(r'#[^\n]*', '', block)   # the comments have apostrophes
        names = re.findall(r"'([^']+)'", block)
        self.assertIn('xlx_*', names)
        self.assertIn('xlxw_*', names)

    def test_a_standalone_gets_the_engine_that_has_it(self):
        saver = read('ide-support', 'revsaveasemscriptenstandalone.livecodescript')
        self.assertEqual(tuple(constant('kXTalkWebLibraries', saver).split(',')), xwl.KNOWN)
        self.assertIn(EXTENSION, constant('kXTalkWebExtensions', saver).split(','))

    def test_the_browser_check_has_its_step(self):
        check = read('tools', 'ci', 'web-ide-xtalk.livecodescript')
        steps = constant('kSteps', check).split(',')
        self.assertIn('xlsx', steps)
        # before the steps that need a network, so a relay that is down
        # cannot hide it
        self.assertLess(steps.index('xlsx'), steps.index('nostr'))
        body = re.search(r'(?ms)^on xt_xlsx\b(.*?)^end xt_xlsx', check)
        self.assertIsNotNone(body, 'no xt_xlsx handler')
        for call in ('xlWorkbookNew', 'xlWorkbookAddChart', 'xlReadOpen', 'xlReadCell', 'xlLastError'):
            self.assertIn(call, body.group(1), call)

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


if __name__ == '__main__':
    unittest.main()
