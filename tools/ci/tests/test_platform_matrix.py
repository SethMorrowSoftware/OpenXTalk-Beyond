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

"""The platform matrix (tools/ci/platform-matrix.json) and the package
checks that read it: README.md states every floor in it; check_elf_floor.py
--matrix fails a file over its platform's floor and passes the named
exceptions, but fails an exception that matches nothing;
check_native_deps.py holds each slice of a universal library to its own
architecture's floor; check_macho_floor.py --matrix gives the extensions
their own x86_64 floor. The binaries are made up (the readers are
replaced), so the tests run anywhere.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import re
import shutil
import sys
import tempfile
import unittest
from unittest import mock

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import check_elf_floor  # noqa: E402
import check_macho_floor  # noqa: E402
import check_native_deps  # noqa: E402
import platform_matrix  # noqa: E402

X86_LIBS = ('sodiumxt.so', 'box2dxt.so', 'torrentxt.so', 'datachannelxt.so')


def needs(**versions):
    """[(library, version name)] needing the given GLIBC etc. versions."""
    return [('libc.so.6' if n == 'GLIBC' else 'libstdc++.so.6', '%s_%s' % (n, v)) for n, v in versions.items()]


class TempTree(object):
    def __init__(self, files):
        self.root = tempfile.mkdtemp()
        for rel in files:
            path = os.path.join(self.root, *rel.split('/'))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'wb') as f:
                f.write(b'x')

    def close(self):
        shutil.rmtree(self.root)


def run_main(module, argv):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err), \
            mock.patch.dict(os.environ, {'GITHUB_ACTIONS': ''}):
        code = module.main(argv)
    return code, out.getvalue() + err.getvalue()


class MatrixAndReadme(unittest.TestCase):
    def setUp(self):
        self.matrix = platform_matrix.load()

    def test_readme_states_every_floor(self):
        with open(os.path.join(REPO, 'README.md'), encoding='utf-8') as f:
            readme = re.sub(r'\s+', ' ', f.read())
        for where, phrase in platform_matrix.readme_phrases(self.matrix):
            self.assertIn(re.sub(r'\s+', ' ', phrase), readme,
                          '%s: README.md no longer says %r; change the matrix and README.md together'
                          % (where, phrase))

    def test_floors_are_versions(self):
        for name in ('mac-universal',):
            for arch, v in platform_matrix.macos_limits(self.matrix, name).items():
                self.assertRegex(v, r'^\d+\.\d+$', '%s %s' % (name, arch))
        for name in ('linux-x86_64', 'linux-arm64', 'linux-x86'):
            limits, exceptions = platform_matrix.elf_limits(self.matrix, name)
            self.assertEqual(set(limits), {'GLIBC', 'GLIBCXX', 'CXXABI', 'GCC'}, name)
            for pattern, ex_limits, reason in exceptions:
                self.assertTrue(reason)
                for n, v in ex_limits.items():
                    self.assertGreater(check_elf_floor.version_key(v), check_elf_floor.version_key(limits[n]),
                                       '%s: an exception must be above the floor it excuses' % pattern)

    def test_extension_floor_does_not_lower_arm64(self):
        # The mistake the modernization report warned of: a single 10.15
        # would reject every arm64 slice, which cannot go below 11.0
        ext = platform_matrix.macos_limits(self.matrix, 'mac-universal', 'extensions')
        self.assertEqual(ext['arm64'], '11.0')
        self.assertEqual(ext['x86_64'], '10.15')

    def test_unknown_platform(self):
        with self.assertRaises(platform_matrix.MatrixError):
            platform_matrix.elf_limits(self.matrix, 'linux-sparc')


class ElfFloorMatrix(unittest.TestCase):
    def tree(self, extra=()):
        files = ['bin/engine'] + ['Extensions/x/code/x86-linux/%s' % n for n in X86_LIBS] + list(extra)
        t = TempTree(files)
        self.addCleanup(t.close)
        return t

    def run_check(self, root, info):
        def fake(path, via_dynamic=False):
            rel = os.path.relpath(path, root).replace(os.sep, '/')
            return {'machine': 'x86_64', 'type': 'DYN', 'needs': info.get(rel, needs(GLIBC='2.17'))}
        with mock.patch.object(check_elf_floor, 'read_elf', side_effect=fake):
            return run_main(check_elf_floor, [root, '--matrix', 'linux-x86_64'])

    def shipped(self):
        """The 32-bit libraries as rc.6.9 shipped them."""
        return {'Extensions/x/code/x86-linux/sodiumxt.so': needs(GLIBC='2.33'),
                'Extensions/x/code/x86-linux/box2dxt.so': needs(GLIBC='2.34'),
                'Extensions/x/code/x86-linux/torrentxt.so': needs(GLIBC='2.38'),
                'Extensions/x/code/x86-linux/datachannelxt.so': needs(GLIBC='2.38')}

    def test_shipped_package_passes(self):
        t = self.tree()
        code, out = self.run_check(t.root, self.shipped())
        self.assertEqual(code, 0, out)
        self.assertIn('4 exceptions above', out)

    def test_new_file_over_the_floor_fails_with_path_and_version(self):
        t = self.tree(['Externals/new.so'])
        info = self.shipped()
        info['Externals/new.so'] = needs(GLIBC='2.32')
        code, out = self.run_check(t.root, info)
        self.assertEqual(code, 1)
        self.assertIn('Externals/new.so: needs GLIBC_2.32 (from libc.so.6), newer than GLIBC_2.31', out)

    def test_libstdcxx_over_the_floor_fails(self):
        t = self.tree()
        info = self.shipped()
        info['bin/engine'] = needs(GLIBCXX='3.4.29')
        code, out = self.run_check(t.root, info)
        self.assertEqual(code, 1)
        self.assertIn('needs GLIBCXX_3.4.29', out)

    def test_exception_is_a_ceiling_not_a_pass(self):
        t = self.tree()
        info = self.shipped()
        info['Extensions/x/code/x86-linux/sodiumxt.so'] = needs(GLIBC='2.34')
        code, out = self.run_check(t.root, info)
        self.assertEqual(code, 1)
        self.assertIn('sodiumxt.so: needs GLIBC_2.34 (from libc.so.6), newer than GLIBC_2.33 (its own limit)', out)

    def test_stale_exception_fails(self):
        t = TempTree(['bin/engine'] + ['Extensions/x/code/x86-linux/%s' % n for n in X86_LIBS[:3]])
        self.addCleanup(t.close)
        code, out = self.run_check(t.root, self.shipped())
        self.assertEqual(code, 1)
        self.assertIn('datachannelxt.so=GLIBC:2.38 matches no file', out)

    def test_plain_max_still_works(self):
        t = self.tree()
        fake = lambda path, via_dynamic=False: {'machine': 'x86_64', 'type': 'DYN', 'needs': needs(GLIBC='2.17')}
        with mock.patch.object(check_elf_floor, 'read_elf', side_effect=fake):
            code, out = run_main(check_elf_floor, [t.root, '--max', 'GLIBC=2.31'])
        self.assertEqual(code, 0, out)


class NativeDepsPerSlice(unittest.TestCase):
    def setUp(self):
        t = TempTree(['Extensions/x/code/universal-mac/lib.dylib'])
        self.addCleanup(t.close)
        self.root = t.root

    def run_deps(self, slices, argv):
        checker = lambda path, folder, here: (['arm64', 'x86_64'], [], [], [], {'macOS': max(slices.values())})
        with mock.patch.dict(check_native_deps.CHECKERS, {'mac': checker}), \
                mock.patch.object(check_native_deps, '_slice_floors', return_value=slices):
            return run_main(check_native_deps, ['--root', self.root, '--platform', 'mac'] + argv)

    def test_extensions_as_shipped_pass(self):
        code, out = self.run_deps({'arm64': (11, 0), 'x86_64': (10, 15)}, ['--matrix', 'mac-universal/extensions'])
        self.assertEqual(code, 0, out)

    def test_x86_64_slice_over_its_floor_fails(self):
        code, out = self.run_deps({'arm64': (11, 0), 'x86_64': (11, 0)}, ['--matrix', 'mac-universal/extensions'])
        self.assertEqual(code, 1)
        self.assertIn('lib.dylib: [x86_64] needs macOS 11.0, newer than 10.15', out)

    def test_arm64_slice_over_its_floor_fails(self):
        code, out = self.run_deps({'arm64': (12, 0), 'x86_64': (10, 15)}, ['--matrix', 'mac-universal/extensions'])
        self.assertEqual(code, 1)
        self.assertIn('[arm64] needs macOS 12.0, newer than 11.0', out)

    def test_arch_without_floor_fails(self):
        code, out = self.run_deps({'arm64': (11, 0), 'x86_64': (10, 15)}, ['--max-macos', 'arm64=11.0'])
        self.assertEqual(code, 1)
        self.assertIn('has a x86_64 slice, for which no macOS floor is given', out)

    def test_single_floor_unchanged(self):
        # The old form holds every slice to one version, as before
        code, out = self.run_deps({'arm64': (11, 0), 'x86_64': (10, 15)}, ['--max-macos', '15.0'])
        self.assertEqual(code, 0, out)
        code, out = self.run_deps({'arm64': (11, 0), 'x86_64': (10, 15)}, ['--max-macos', '10.15'])
        self.assertEqual(code, 1)


class MachoFloorMatrix(unittest.TestCase):
    def test_matrix_gives_minos_and_the_extensions_part(self):
        t = TempTree(['a'])
        self.addCleanup(t.close)
        seen = {}

        def fake(root, minos, sdk=None, arch=None, allow=None, exclude=(), only_arch=None, file_minos=()):
            seen.update(minos=minos, file_minos=list(file_minos))
            return [('a', 'arm64', 'DYLIB', 'macOS', '11.0', '11.0', '')], [], [], {}
        with mock.patch.object(check_macho_floor, 'check', side_effect=fake):
            code, out = run_main(check_macho_floor, [t.root, '--matrix', 'mac-universal'])
        self.assertEqual(code, 0, out)
        v = check_macho_floor.parse_version
        self.assertEqual(seen['minos'], {'arm64': v('11.0'), 'x86_64': v('10.13')})
        self.assertEqual(seen['file_minos'], [('Contents/Tools/Extensions/*/code/universal-mac/*', 'x86_64',
                                               v('10.15'))])


if __name__ == '__main__':
    unittest.main()
