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

"""The browser's CEF code on Windows (libbrowser/src/libbrowser_cef_dll.h):
CEF 156 needs C++20, so it is built with MSVC v143 into libbrowser-cef.dll,
revbrowser and the helper processes, while the engine stays on v141.

Held here: every Windows target that compiles CEF's headers is v143 with
/std:c++20 and nothing else is; the engine does not link the DLL; the
engine passes every function of MCBrowserCefHost and the DLL forwards each
one; the prebuilt libraries are found under their v141 names from a v143
project; and the packages carry the DLL beside libcef.dll.

  python3 -m unittest discover -s tools/ci/tests

What only MSVC can tell (that it all compiles and loads) the Windows build
says (build-windows.yml).
"""

import ast
import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
SRC = os.path.join(REPO, 'libbrowser', 'src')
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def gyp(*parts):
    return ast.literal_eval(read(*parts))


def targets(tree):
    """Every target of a gyp file, conditions included."""
    found = []

    def walk(node):
        if isinstance(node, dict):
            if 'target_name' in node:
                found.append(node)
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)
    walk(tree)
    return found


def target(path, name):
    for t in targets(gyp(*path.split('/'))):
        if t['target_name'] == name:
            return t
    raise AssertionError('%s has no target %s' % (path, name))


# The Windows targets that compile CEF 156's headers
V143 = [
    ('libbrowser/libbrowser.gyp', 'libbrowser-cef'),
    ('libbrowser/libbrowser.gyp', 'libbrowser-cefprocess'),
    ('revbrowser/revbrowser.gyp', 'external-revbrowser'),
    ('revbrowser/revbrowser.gyp', 'revbrowser-cefprocess'),
    ('thirdparty/libcef/libcef.gyp', 'libcef_library_wrapper'),
]


class Toolsets(unittest.TestCase):
    def test_the_cef_targets_are_v143_and_cxx20(self):
        for path, name in V143:
            t = target(path, name)
            self.assertEqual(t.get('msbuild_toolset'), 'v143', name)
            options = t.get('msvs_settings', {}).get('VCCLCompilerTool', {}).get('AdditionalOptions', [])
            self.assertIn('/std:c++20', options, name)
            self.assertEqual(t['msvs_settings']['VCCLCompilerTool'].get('ExceptionHandling'), '1', name)

    def test_no_other_target_leaves_v141(self):
        found = []
        for root, dirs, files in os.walk(REPO):
            dirs[:] = [d for d in dirs if d not in ('.git', 'gyp', 'node_modules') and not d.startswith('build-')]
            for name in files:
                if name.endswith('.gyp'):
                    path = os.path.relpath(os.path.join(root, name), REPO).replace(os.sep, '/')
                    try:
                        tree = gyp(*path.split('/'))
                    except (ValueError, SyntaxError):
                        continue
                    for t in targets(tree):
                        if 'msbuild_toolset' in t:
                            found.append((path, t['target_name']))
        self.assertEqual(sorted(found), sorted(V143))

    def test_the_engine_stays_on_v141(self):
        self.assertIn('\'msvs_compiler_version\': "141"', read('config', 'win32.gypi'))

    def test_prebuilt_paths_name_the_v141_archives(self):
        # $(PlatformToolset) is the project's own toolset: v143 in a v143
        # project, where no prebuilt archive is named for it
        for path in ('prebuilt/libcef.gyp', 'prebuilt/libicu.gyp', 'prebuilt/libopenssl.gyp',
                     'prebuilt/libcurl.gyp', 'prebuilt/thirdparty.gyp', 'thirdparty/libopenssl/libopenssl.gyp',
                     'libbrowser/libbrowser.gyp', 'revbrowser/revbrowser.gyp'):
            self.assertNotIn('$(PlatformToolset)', read(*path.split('/')), path)

    def test_the_wrapper_is_unicode_on_windows(self):
        self.assertRegex(read('thirdparty', 'libcef', 'libcef.gyp'),
                         r"'toolset_os == \"win\"',\s*\{\s*(#[^\n]*\n\s*)*'defines':\s*\[\s*'NOMINMAX',\s*'UNICODE',\s*'_UNICODE',")


class EngineDoesNotLinkTheDll(unittest.TestCase):
    def test_the_copy_target_stops_the_link(self):
        t = target('libbrowser/libbrowser.gyp', 'libbrowser-cef-copy')
        self.assertEqual(t['type'], 'none')
        self.assertEqual(t.get('dependencies_traverse'), 0)
        self.assertEqual(t['dependencies'], ['libbrowser-cef'])
        self.assertIn('<(PRODUCT_DIR)/libbrowser-cef.dll', t['copies'][0]['files'])
        self.assertEqual(t['copies'][0]['destination'], '<(PRODUCT_DIR)/Externals/CEF/')

    def test_libbrowser_reaches_the_dll_only_through_the_copy(self):
        text = read('libbrowser', 'libbrowser.gyp')
        self.assertNotRegex(text, r"'libbrowser-cef',\s*\n\s*'\.\./prebuilt")
        lib = target('libbrowser/libbrowser.gyp', 'libbrowser')
        deps = []
        for cond in lib.get('conditions', []):
            deps += cond[1].get('dependencies', [])
        self.assertIn('libbrowser-cef-copy', deps)
        self.assertNotIn('libbrowser-cef', deps)

    def test_the_engine_has_no_cef_code_on_windows(self):
        lib = target('libbrowser/libbrowser.gyp', 'libbrowser')
        removed = []
        for cond in lib['target_conditions']:
            if cond[0] == 'toolset_os == "win"':
                removed += cond[1].get('sources!', [])
        for name in ('src/libbrowser_cef.cpp', 'src/libbrowser_cef_win.cpp', 'src/libbrowser_win.rc'):
            self.assertIn(name, removed)
        self.assertIn('src/libbrowser_cef_loader_win.cpp', lib['sources'])

    def test_the_dll_has_the_cef_code(self):
        t = target('libbrowser/libbrowser.gyp', 'libbrowser-cef')
        self.assertEqual(t['type'], 'shared_library')
        self.assertIn('MCBROWSER_CEF_DLL', t['defines'])
        for name in ('src/libbrowser.cpp', 'src/libbrowser_cef.cpp', 'src/libbrowser_cef_win.cpp',
                     'src/libbrowser_cef_dll_win.cpp', 'src/libbrowser_win.rc'):
            self.assertIn(name, t['sources'])
        # its own copies of these would be second copies of the engine's state
        for name in ('src/libbrowser_memory.cpp', 'src/libbrowser_value.cpp'):
            self.assertNotIn(name, t['sources'])


def host_members():
    text = read('libbrowser', 'src', 'libbrowser_cef_dll.h')
    body = re.search(r'struct MCBrowserCefHost\s*\{(.*?)\};', text, re.S).group(1)
    names = re.findall(r'\(\*(\w+)\)', body)
    names += re.findall(r'^\s*MCBrowser\w+ (\w+);', body, re.M)
    return set(names), body


class HostTable(unittest.TestCase):
    def test_the_engine_fills_every_member(self):
        names, _body = host_members()
        loader = read('libbrowser', 'src', 'libbrowser_cef_loader_win.cpp')
        filled = set(re.findall(r't_host\.(\w+) = ', loader))
        self.assertEqual(filled - {'version', 'size'}, names)

    def test_the_dll_calls_every_member(self):
        names, _body = host_members()
        dll = read('libbrowser', 'src', 'libbrowser_cef_dll_win.cpp')
        called = set(re.findall(r's_host\.(\w+)\(', dll))
        self.assertEqual(called, names)

    def test_the_dll_checks_the_version_and_size(self):
        dll = read('libbrowser', 'src', 'libbrowser_cef_dll_win.cpp')
        self.assertIn('p_host->version != kMCBrowserCefHostVersion', dll)
        self.assertIn('p_host->size != sizeof(MCBrowserCefHost)', dll)

    def test_the_dll_forwards_what_the_cef_code_calls(self):
        # Each libbrowser function the CEF code calls that has state of its
        # own in the engine is defined in the DLL, and only there
        dll = read('libbrowser', 'src', 'libbrowser_cef_dll_win.cpp')
        cef = read('libbrowser', 'src', 'libbrowser_cef.cpp') + read('libbrowser', 'src', 'libbrowser_cef_win.cpp')
        for name in set(re.findall(r'\b(MCBrowser(?:List|Dictionary)(?:Create|Release|Set\w+)|MCBrowserRunloop\w+|'
                                   r'MCBrowser(?:Add|Remove)RunloopAction|MCBrowserMemory(?:Allocate|Reallocate|Deallocate))\(',
                                   cef)):
            self.assertRegex(dll, r'\n(?:bool|void) %s\(' % name, name)

    def test_the_library_part_of_libbrowser_is_left_out_of_the_dll(self):
        text = read('libbrowser', 'src', 'libbrowser.cpp')
        head, sep, tail = text.partition('#if !defined(MCBROWSER_CEF_DLL)')
        self.assertTrue(sep)
        self.assertTrue(tail.rstrip().endswith('#endif // !MCBROWSER_CEF_DLL'))
        # the classes stay; the library's state does not
        self.assertIn('MCBrowserBase::MCBrowserBase', head)
        for name in ('MCBrowserAddRunloopAction', 'MCBrowserLibraryInitialize', 'MCBrowserFactoryGet'):
            self.assertNotIn(name + '(', head)
            self.assertIn(name + '(', tail)


class Packages(unittest.TestCase):
    def test_package_txt_puts_the_dll_beside_libcef(self):
        text = read('Installer', 'package.txt')
        m = re.search(r'^component Externals\.CEF\.Windows\n(.*?)(?=^component |\Z)', text, re.S | re.M)
        self.assertIn('executable win-[[TargetArchitecture]]:libbrowser-cef.dll', m.group(1))

    def test_package_py_does_too(self):
        import package
        for name in ('win-x86_64', 'win-x86'):
            p = package.PLATFORMS[name]
            self.assertIn('libbrowser-cef.dll', p.cef['helpers_in_cef'])
            self.assertIn('Externals/CEF/libbrowser-cef.dll', [x[0] for x in p.not_installed])

    def test_the_standalone_builder_copies_it(self):
        # It copies every file of the CEF folder but the helpers (*.exe)
        text = read('ide-support', 'revsaveasstandalone.livecodescript')
        self.assertIn('filter lines of tCEFFIles not matching "*.exe"', text)


if __name__ == '__main__':
    unittest.main()
