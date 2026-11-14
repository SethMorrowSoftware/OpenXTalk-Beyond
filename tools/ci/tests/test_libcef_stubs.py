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

"""CEF 156 in the build: the generated files of thirdparty/libcef (the weak
stubs of libcef and the wrapper's source list) match what their
generators make of the vendored headers and sources, the stub generator's
rules, tools/cxx_by_std.sh (the C++20 compiler for the browser's sources
on the Linux build's GCC 9), and the CEF files the packages take.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
LIBCEF = os.path.join(REPO, 'thirdparty', 'libcef')
CXX_BY_STD = os.path.join(REPO, 'tools', 'cxx_by_std.sh')
FILES = os.path.join(CI, 'cef-156-files.txt')
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))


def generate(script, *args, cwd=LIBCEF):
    return subprocess.run([sys.executable, script] + list(args), cwd=cwd, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class Generated(unittest.TestCase):
    def test_libcef_stubs_is_fresh(self):
        out = generate('gen_libcef_stubs.py', 'include').stdout
        self.assertEqual(out, read(os.path.join(LIBCEF, 'libcef.stubs')),
                         'run "python3 gen_libcef_stubs.py include > libcef.stubs" in thirdparty/libcef')

    def test_libcef_gypi_is_fresh(self):
        out = generate('gen_libcef_paths.py', 'libcef_dll').stdout
        self.assertEqual(out, read(os.path.join(LIBCEF, 'libcef.gypi')),
                         'run "python3 gen_libcef_paths.py libcef_dll > libcef.gypi" in thirdparty/libcef')

    def test_only_known_types_are_left_out(self):
        # What the generator does not know it writes as a comment, so the
        # function has no stub; these are Windows entry points and a test
        # function, which the browser does not call
        err = generate('gen_libcef_stubs.py', 'include').stderr
        unknown = set(re.findall(r'unknown type: (.+)', err))
        self.assertLessEqual(unknown, {'HINSTANCE', 'LPWSTR', 'mainPtr', 'wWinMainPtr', 'cef_test_cert_type_t'})

    def test_the_cef_version_matches_prebuilt(self):
        version = read(os.path.join(REPO, 'prebuilt', 'versions', 'cef')).strip()
        rev = read(os.path.join(REPO, 'prebuilt', 'versions', 'cef_buildrevision')).strip()
        chromium = read(os.path.join(REPO, 'prebuilt', 'versions', 'cefchromium')).strip()
        header = read(os.path.join(LIBCEF, 'include', 'cef_version.h'))
        self.assertIn('#define CEF_VERSION "%s+%s+chromium-%s"' % (version, rev, chromium), header)
        sums = read(os.path.join(REPO, 'prebuilt', 'cef-sha1sums'))
        for dist in ('linux64_minimal', 'windows64_minimal', 'windows32_minimal'):
            self.assertIn('cef_binary_%s+%s+chromium-%s_%s.tar.bz2' % (version, rev, chromium, dist), sums)

    def test_cef_config_keeps_x11_to_linux(self):
        text = read(os.path.join(LIBCEF, 'include', 'cef_config.h'))
        self.assertRegex(text, r'#if defined\(__linux__\)\n#define CEF_X11 1\n#endif')


class MainArgs(unittest.TestCase):
    def test_cef_gets_the_program_on_linux(self):
        # CEF 156 (Chrome's start-up) reads the program from the arguments
        # on Linux, which CEF 74 was given none of
        for path in ('libbrowser/src/libbrowser_cef.cpp', 'revbrowser/src/cefbrowser.cpp'):
            text = read(os.path.join(REPO, *path.split('/')))
            self.assertIn('readlink("/proc/self/exe"', text, path)
            self.assertIn('return CefMainArgs(1, s_argv);', text, path)
            self.assertRegex(text, r'#if defined\(__linux__\)\n\tCefMainArgs t_args = MCCefLinuxMainArgs\(\);', path)

    def test_chromium_loads_no_gtk_3_into_the_gtk_2_engine(self):
        # Chromium's Linux UI would load GTK 3 beside the engine's GTK 2,
        # and CefInitialize crashed; the fallback UI loads no GTK
        for path in ('libbrowser/src/libbrowser_cef.cpp', 'revbrowser/src/cefbrowser.cpp'):
            text = read(os.path.join(REPO, *path.split('/')))
            self.assertRegex(text, r'if \(!p_command_line->HasSwitch\(kUiToolkit\)\)\n\t+'
                                   r'p_command_line->AppendSwitchWithValue\(kUiToolkit, "fallback"\);', path)
            self.assertIn('static const char kUiToolkit[] = "ui-toolkit";', text, path)
        lib = read(os.path.join(REPO, 'libbrowser', 'src', 'libbrowser_cef.cpp'))
        self.assertRegex(lib, r'AppendDeviceScaleFactor\(p_command_line\);\n\t\tAppendLinuxUiToolkit\(p_command_line\);')
        rev = read(os.path.join(REPO, 'revbrowser', 'src', 'cefbrowser.cpp'))
        # revBrowser had no CefApp; on Linux it now has one that gives the switch
        self.assertRegex(rev, r'#if defined\(__linux__\)\n\tCefRefPtr<CefApp> t_app = new MCRevBrowserCefApp\(\);\n'
                              r'#else\n\tCefRefPtr<CefApp> t_app = nil;\n#endif')


class StubRules(unittest.TestCase):
    """The generator on headers of its own."""

    def stubs(self, files):
        d = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, d)
        for name, text in files.items():
            path = os.path.join(d, 'include', name)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w') as f:
                f.write(text)
        gen = os.path.join(LIBCEF, 'gen_libcef_stubs.py')
        return generate(gen, 'include', cwd=d).stdout.splitlines()

    def test_types_and_optional_stubs(self):
        lines = self.stubs({
            'capi/cef_a_capi.h': 'CEF_EXPORT int64_t cef_a(uint32_t x, const char* y);\n'
                                 'CEF_EXPORT void cef_b(void);\n'
                                 'CEF_EXPORT cef_basetime_t cef_c(cef_basetime_t t);\n',
            'internal/cef_x_win.h': 'CEF_EXPORT int cef_w(int x);\n',
            'internal/cef_x_linux.h': 'CEF_EXPORT int cef_l(int x);\n',
            'test/cef_t_capi.h': 'CEF_EXPORT void* cef_t(void);\n',
            'views/cef_d_capi.h': 'CEF_EXPORT int cef_r(const cef_rect_t* r);\n'
                                  'CEF_EXPORT int cef_v(cef_rect_t r);\n',
        })
        self.assertEqual(lines[0], 'cef ./Externals/CEF/libcef ./Externals/CEF/libcef ./Externals/CEF/libcef')
        body = set(lines[1:])
        self.assertIn('\tcef_a: (integer,pointer) -> (integer64)', body)
        self.assertIn('\tcef_b: () -> ()', body)
        self.assertIn('\tcef_c: (integer64) -> (integer64)', body)
        # one platform's or the test library's: optional
        self.assertIn('\t? cef_w: (integer) -> (integer)', body)
        self.assertIn('\t? cef_l: (integer) -> (integer)', body)
        self.assertIn('\t? cef_t: () -> (pointer)', body)
        # a 16-byte struct by pointer is a pointer; by value, optional
        self.assertIn('\tcef_r: (pointer) -> (integer)', body)
        self.assertIn('\t? cef_v: (pointer) -> (integer)', body)


class CxxByStd(unittest.TestCase):
    """tools/cxx_by_std.sh hands -std=c++20 to $OXT_CXX20 and the rest to
    $OXT_CXX (two fake compilers that say who they are)."""

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir)
        self.env = dict(os.environ)
        for name in ('old', 'new'):
            path = os.path.join(self.dir, name)
            with open(path, 'w') as f:
                f.write('#!/bin/sh\necho %s "$@"\n' % name)
            os.chmod(path, 0o755)
        self.env['OXT_CXX'] = os.path.join(self.dir, 'old')
        self.env['OXT_CXX20'] = os.path.join(self.dir, 'new')

    def run_it(self, *args):
        return subprocess.run(['sh', CXX_BY_STD] + list(args), env=self.env, check=True,
                              stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()

    def test_cxx20_goes_to_the_new_compiler(self):
        for flag in ('-std=c++20', '-std=gnu++20', '-std=c++2a', '-std=gnu++2a'):
            self.assertEqual(self.run_it('-c', 'a.cpp', '-std=c++11', flag), 'new -c a.cpp -std=c++11 ' + flag)

    def test_the_rest_goes_to_the_usual_compiler(self):
        self.assertEqual(self.run_it('-c', 'a.cpp', '-std=c++11'), 'old -c a.cpp -std=c++11')
        self.assertEqual(self.run_it('-o', 'x', 'a.o', 'b.o'), 'old -o x a.o b.o')

    def test_arguments_with_spaces_survive(self):
        self.assertEqual(self.run_it('-DX=a b', '-std=c++20'), 'new -DX=a b -std=c++20')

    def test_it_is_executable(self):
        # As git records it: Windows checkouts have no execute bit
        out = subprocess.run(['git', 'ls-files', '--stage', '--', 'tools/cxx_by_std.sh'], cwd=REPO, check=True,
                             stdout=subprocess.PIPE, universal_newlines=True).stdout
        self.assertTrue(out.startswith('100755 '), out)

    def test_the_linux_build_configures_with_it(self):
        text = read(os.path.join(REPO, '.github', 'workflows', 'build-linux.yml'))
        self.assertRegex(text, r'export CXX="\$GITHUB_WORKSPACE/tools/cxx_by_std\.sh"[^\n]*\n\s*make config-linux-"\$ARCH"')
        self.assertRegex(text, r'BUILD_PKGS: >-\n\s+build-essential gcc g\+\+ g\+\+-10 ')

    def test_only_the_browser_takes_cxx20(self):
        found = []
        for root, dirs, files in os.walk(REPO):
            dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules') and not d.startswith('build-')]
            for name in files:
                if name.endswith(('.gyp', '.gypi')):
                    if '-std=c++20' in read(os.path.join(root, name)):
                        found.append(os.path.relpath(os.path.join(root, name), REPO).replace(os.sep, '/'))
        self.assertEqual(sorted(found), ['libbrowser/libbrowser.gyp', 'revbrowser/revbrowser.gyp',
                                         'thirdparty/libcef/libcef.gyp'])


class PackageFiles(unittest.TestCase):
    """The CEF files of package.txt and package.py are the distribution's."""

    def distribution(self, platform):
        names = set()
        for line in read(FILES).splitlines():
            if line.startswith('#') or not line.strip():
                continue
            plat, path, _size = line.split('\t')
            if plat != platform:
                continue
            name = path.split('/', 1)[1]
            if name.startswith('locales/'):
                continue
            names.add(name)
        return names

    def package_txt(self, component, prefix):
        text = read(os.path.join(REPO, 'Installer', 'package.txt'))
        m = re.search(r'^component %s\n(.*?)(?=^component |\Z)' % re.escape(component), text, re.S | re.M)
        self.assertIsNotNone(m, component)
        return {x for x in re.findall(prefix + r':Externals/CEF/(\S+)', m.group(1)) if x != 'locales'}

    def test_linux(self):
        dist = self.distribution('linux64')
        self.assertEqual(self.package_txt('Externals.CEF.Linux', r'linux-\[\[TargetArchitecture\]\]'), dist)
        import package
        p = package.PLATFORMS['linux-x86_64']
        # chrome-sandbox is installed by package.txt but left out of the package
        self.assertEqual(set(p.cef['files']), dist - {'chrome-sandbox'})

    def test_windows(self):
        # the launchers and the import library are not shipped
        dist = self.distribution('windows64') - {'bootstrap.exe', 'bootstrapc.exe', 'libcef.lib'}
        self.assertEqual(self.package_txt('Externals.CEF.Windows', r'win-\[\[TargetArchitecture\]\]'), dist)
        import package
        p = package.PLATFORMS['win-x86_64']
        self.assertEqual(set(p.cef['files']), dist)


if __name__ == '__main__':
    unittest.main()
