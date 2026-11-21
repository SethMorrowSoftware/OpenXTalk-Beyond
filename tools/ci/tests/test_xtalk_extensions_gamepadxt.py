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

"""gamepadxt, the xTalk Suite's game controller library (SDL 3's gamepad
layer behind org.openxtalk.library.gamepadxt), as
tools/oxt/xtalk-extensions.json bundles it and the web engine links it.

It is the first native member with no Android libraries (SDL reaches
controllers there through a Java activity of its own, which an OXT-Beyond
app does not have), so this also holds that a desktop-only member is left
out of the Android probe rather than refused by it. A web-linked member is
named in the manifest, KNOWN in xtalk_web_libraries.py, the three lists of
engine/src/em-xtalk-web.cpp (whose name row and function row are read by
the same index) and the web standalone builder's two constants; one left
out is linked and never found, or found and never linked, and fails only
in a browser. No network.

  python3 -m unittest discover -s tools/ci/tests
"""

import ast
import fnmatch
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))

import android_check  # noqa: E402
import xtalk_extensions  # noqa: E402
import xtalk_web_libraries as xwl  # noqa: E402

MODULE = 'org.openxtalk.library.gamepadxt'


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def constant(name, text):
    return re.search(r'^constant %s = "([^"]*)"' % re.escape(name), text, re.M).group(1).split(',')


def engine_lists(text):
    """The three lists of em-xtalk-web.cpp, each in the order written"""
    declared = re.findall(r'__attribute__\(\(weak\)\) const MCSLibraryStaticExport \*(\w+)_web_exports\(void\);', text)
    names = re.findall(r'\{ nullptr, "(\w+)", nullptr \},', text)
    table = text[text.index('t_exports[])(void) ='):]
    table = table[:table.index('};')]
    functions = re.findall(r'^\s*(\w+)_web_exports,\s*$', table, re.M)
    return declared, names, functions


class GamepadxtMemberTest(unittest.TestCase):

    def setUp(self):
        self.data = xtalk_extensions.load_manifest()
        self.member = next((m for m in self.data['members'] if m['name'] == 'gamepadxt'), None)
        self.assertIsNotNone(self.member, 'no gamepadxt member in xtalk-extensions.json')

    def test_taken_from_the_suite(self):
        self.assertEqual(self.member['repository'], 'SethMorrowSoftware/xtalk-suite')
        for f in self.member['files']:
            self.assertTrue(f['path'].startswith('gamepadxt/'), f['path'])

    def test_a_library_for_every_desktop_platform_and_none_for_android(self):
        have = {xtalk_extensions.library_platform(f)
                for f in xtalk_extensions.member_files(self.member, 'library')}
        desktop = {p for p in self.data['platforms'] if not p.endswith('-android')}
        self.assertEqual(have, desktop)

    def test_the_android_probe_leaves_it_out(self):
        # A member with no Android library at all is skipped; one with some
        # and not all would be an error (a package for the others would
        # hold no code for it)
        found = [m['name'] for m, _, _ in android_check.xtalk_android_extensions(self.data)]
        self.assertNotIn('gamepadxt', found)
        self.assertTrue(found)

    def test_windows_needs_no_runtime_dlls(self):
        # Built with the static CRT (/MT): nothing to copy next to it
        for f in xtalk_extensions.member_files(self.member, 'library'):
            if xtalk_extensions.library_platform(f) in xtalk_extensions.WINDOWS_PLATFORMS:
                self.assertTrue(f['imports'], f['path'])
                extra = [d for d in f['imports'] if not xtalk_extensions.is_system_dll(d)]
                self.assertEqual(extra, [], f['path'])

    def test_one_library_extension_and_its_probe(self):
        exts = [(e['kind'], e['id']) for e in self.member['extensions']]
        self.assertEqual(exts, [('lcb', MODULE)])
        e = self.member['extensions'][0]
        self.assertEqual(e['probe'], 'gpLibraryVersion()')
        # What the shim answers: SDL's own version, which must be 3
        self.assertRegex('SDL 3.4.20', e['expect'])
        self.assertNotRegex('SDL 2.32.10', e['expect'])
        self.assertNotRegex('SDL 3.4.20 and more', e['expect'])

    def test_its_licence_is_carried(self):
        # SDL's zlib notice and HIDAPI's BSD-style one are in this file
        self.assertIn('gamepadxt/LICENSE', [f['path'] for f in xtalk_extensions.member_files(self.member, 'licence')])


class SdlWindowsDllsTest(unittest.TestCase):

    def test_what_sdl_imports_on_windows_needs_nothing_shipped(self):
        # Besides the DLLs other members import, SDL's Windows code imports
        # SetupAPI (to list the controllers plugged in), COM (ole32) and
        # shell32, in the case the pinned gamepadxt.dll files write them.
        # The package builder and the PowerShell check of the built
        # packages must both call them system DLLs, or one copies what the
        # other refuses
        ps1 = read('tools', 'ci', 'check-extension-imports.ps1')
        ps1 = {n.lower() for n in re.findall(r"'([^']+)'", re.search(r'\$SystemDlls\s*=\s*@\(([^)]*)\)', ps1).group(1))}
        for name in ('SETUPAPI.dll', 'ole32.dll', 'SHELL32.dll'):
            self.assertTrue(xtalk_extensions.is_system_dll(name), name)
            self.assertIn(name.lower(), ps1)
        # still not the Visual C++ runtime: gamepadxt links it statically
        self.assertFalse(xtalk_extensions.is_system_dll('vcruntime140.dll'))


class GamepadxtWebTest(unittest.TestCase):

    def setUp(self):
        self.libs = {lib['name']: lib for lib in xwl.load()[1]['libraries']}
        self.cpp = read('engine', 'src', 'em-xtalk-web.cpp')
        self.builder = read('ide-support', 'revsaveasemscriptenstandalone.livecodescript')

    def test_the_archive_is_pinned(self):
        self.assertIn('gamepadxt', self.libs)
        lib = self.libs['gamepadxt']
        self.assertEqual(lib['repository'], 'SethMorrowSoftware/xtalk-suite')
        self.assertEqual(lib['path'], 'gamepadxt/src/code/wasm32-emscripten/gamepadxt.a')
        # one compiler for everything linked into one module
        self.assertEqual(lib['emscripten'], xwl.emscripten_version())

    def test_the_engine_registers_it_by_one_index(self):
        declared, names, functions = engine_lists(self.cpp)
        for found in (declared, names, functions):
            self.assertEqual(found.count('gamepadxt'), 1, found)
        # The name row and the function row are read by the same index
        self.assertEqual(names.index('gamepadxt'), functions.index('gamepadxt'))

    def test_a_row_out_of_step_is_seen(self):
        # The reader above must see a function row that is missing
        _, names, functions = engine_lists(self.cpp.replace('\t\tgamepadxt_web_exports,\n', ''))
        self.assertIn('gamepadxt', names)
        self.assertNotIn('gamepadxt', functions)

    def test_the_fetcher_and_the_standalone_builder_know_it(self):
        self.assertIn('gamepadxt', xwl.KNOWN)
        self.assertEqual(tuple(constant('kXTalkWebLibraries', self.builder)), xwl.KNOWN)
        self.assertIn(MODULE, constant('kXTalkWebExtensions', self.builder))

    def test_asyncify_leaves_sdl_instrumented(self):
        # Unlike box3dxt's physics, SDL can sleep: its delay calls
        # emscripten_sleep in an engine built with Asyncify, and a function
        # taken out of Asyncify's instrumentation that sleeps stops the
        # engine. No pattern of the list may reach SDL or the shim
        tree = ast.parse(read('util', 'emscripten-javascriptify.py'))
        lists = [ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                 and any(getattr(t, 'id', None) == 'asyncify_remove_xtalk' for t in n.targets)]
        self.assertEqual(len(lists), 1)
        for pattern in lists[0]:
            for name in ('SDL_DelayNS', 'SDL_SYS_DelayNS', 'SDL_LockSpinlock', 'SDL_UpdateGamepads', 'gpx_poll'):
                self.assertFalse(fnmatch.fnmatchcase(name, pattern), '%s would take %s out' % (pattern, name))

    def test_the_browser_check_has_its_step(self):
        check = read('tools', 'ci', 'web-ide-xtalk.livecodescript')
        steps = constant('kSteps', check)
        self.assertIn('gamepad', steps)
        # before the steps that need a network, so a relay that is down
        # cannot hide it
        self.assertLess(steps.index('gamepad'), steps.index('nostr'))
        body = re.search(r'(?ms)^on xt_gamepad\b(.*?)^end xt_gamepad', check)
        self.assertIsNotNone(body, 'no xt_gamepad handler')
        for call in ('gpStart', 'gpVirtualAttach', 'gpVirtualSetButton', 'gpPoll', 'gpEvents', 'gpPadStick',
                     'gpPadRumble', 'gpVirtualLED', 'gpVirtualDetach', 'gpAssertCount', 'gpStop'):
            self.assertIn(call, body.group(1), call)


if __name__ == '__main__':
    unittest.main()
