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

"""tools/ci/release_inventory.py over a made-up package of tiny ELF and PE
files: every binary gets its origin (built here, the runtimes asset, the
Android runtime carried over from 1.15, an xTalk Suite library checked
against its pin, CEF), what the asset leaves out of the package's own
platform counts as built here, a file outside the known places is
unknown, and --fail-on-unknown fails only then.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import hashlib
import io
import json
import os
import shutil
import struct
import sys
import tempfile
import unittest
from unittest import mock

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import release_inventory  # noqa: E402


def elf(machine=62):
    """An ELF header (x86-64 by default) and nothing else."""
    head = b'\x7fELF' + bytes([2, 1, 1]) + bytes(9) + struct.pack('<HHI', 3, machine, 1)
    return head + bytes(64 - len(head))


def pe(machine=0x8664):
    data = bytearray(256)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 0x3c, 128)
    data[128:132] = b'PE\0\0'
    struct.pack_into('<H', data, 132, machine)
    return bytes(data)


class Inventory(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)
        self.root = os.path.join(self.dir, 'pkg')
        self.lib = pe()
        files = {
            'OXT-Beyond': elf(),
            'Externals/revdb.so': elf(),
            'Externals/CEF/libcef.so': elf(),
            'Runtime/Linux/x86-64/Standalone': elf(),
            'Runtime/Windows/x86-64/Standalone.exe': pe(),
            'Runtime/Windows/x86-64/CEF/libcef.dll': pe(),
            'Runtime/Android/arm64-v8a/Standalone': elf(183),
            'Extensions/com.livecode.library.timezone/code/x86_64-linux/libtz.so': elf(),
            'Extensions/com.livecode.library.timezone/code/x86-win32/tz.dll': pe(0x14c),
            'Extensions/org.example.xt/code/x86_64-win32/xt.dll': self.lib,
            'Extensions/org.example.xt/code/x86-win32/xt.dll': pe(0x14c),
            'Extensions/org.example.xt/code/x86_64-linux/xt.so': elf(),
            'Extensions/org.example.xt/xt.lcb': b'library xt\n',
            'Externals/revdb.so.dbg': elf(),
            'notes.txt': b'not a binary',
        }
        for rel, data in files.items():
            path = os.path.join(self.root, *rel.split('/'))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'wb') as f:
                f.write(data)
        self.assets = os.path.join(self.dir, 'assets.json')
        with open(self.assets, 'w', encoding='utf-8') as f:
            json.dump({'assets': [{'id': 'oxt-runtimes-9.9', 'source': 'builds of commit abcdef1234567',
                                   'exclude': {'linux-x86_64': ['Runtime/Linux/x86-64/**',
                                                                'Extensions/com.livecode.library.timezone/'
                                                                'code/x86_64-linux/**']}}]}, f)
        self.xtalk = os.path.join(self.dir, 'xtalk.json')
        with open(self.xtalk, 'w', encoding='utf-8') as f:
            json.dump({'members': [{'name': 'ExampleXT', 'repository': 'example/ExampleXT', 'commit': 'c0ffee',
                                    'extensions': [{'folder': 'org.example.xt'}],
                                    'files': [{'path': 'src/code/x86_64-win32/xt.dll', 'role': 'library',
                                               'sha256': hashlib.sha256(self.lib).hexdigest()},
                                              {'path': 'src/code/x86-win32/xt.dll', 'role': 'library',
                                               'sha256': '0' * 64}]}]}, f)

    def inventory(self, platform='linux-x86_64'):
        inv = release_inventory.inventory(self.root, platform, 'feedbeef', self.assets, self.xtalk)
        return {r['path']: r for r in inv['binaries']}, inv

    def test_origins(self):
        got, inv = self.inventory()
        origin = {p: r['origin'] for p, r in got.items()}
        self.assertEqual(origin, {
            'OXT-Beyond': 'built',
            'Externals/revdb.so': 'built',
            'Externals/CEF/libcef.so': 'cef',
            'Runtime/Linux/x86-64/Standalone': 'built',
            'Runtime/Windows/x86-64/Standalone.exe': 'runtimes',
            'Runtime/Windows/x86-64/CEF/libcef.dll': 'runtimes',
            'Runtime/Android/arm64-v8a/Standalone': 'runtimes-1.15',
            'Extensions/com.livecode.library.timezone/code/x86_64-linux/libtz.so': 'built',
            'Extensions/com.livecode.library.timezone/code/x86-win32/tz.dll': 'runtimes',
            'Extensions/org.example.xt/code/x86_64-win32/xt.dll': 'xtalk',
            'Extensions/org.example.xt/code/x86-win32/xt.dll': 'xtalk',
            'Extensions/org.example.xt/code/x86_64-linux/xt.so': 'xtalk',
        })
        self.assertEqual(got['OXT-Beyond']['details'], {'commit': 'feedbeef'})
        self.assertEqual(got['Runtime/Windows/x86-64/Standalone.exe']['details'],
                         {'asset': 'oxt-runtimes-9.9', 'commit': 'abcdef1234567'})
        self.assertTrue(got['Runtime/Windows/x86-64/CEF/libcef.dll']['details']['cef'])
        self.assertEqual(got['Runtime/Windows/x86-64/Standalone.exe']['archs'], ['x86_64'])
        self.assertEqual(inv['runtimes_asset']['commit'], 'abcdef1234567')

    def test_xtalk_pins(self):
        got, _ = self.inventory()
        self.assertIs(got['Extensions/org.example.xt/code/x86_64-win32/xt.dll']['details']['pinned'], True)
        self.assertIs(got['Extensions/org.example.xt/code/x86-win32/xt.dll']['details']['pinned'], False)
        self.assertIsNone(got['Extensions/org.example.xt/code/x86_64-linux/xt.so']['details']['pinned'])
        self.assertEqual(got['Extensions/org.example.xt/code/x86_64-win32/xt.dll']['details']['commit'], 'c0ffee')

    def test_asset_parts_of_another_platform(self):
        # A Windows package: the Linux runtime is the asset's
        got, _ = self.inventory('win-x86_64')
        self.assertEqual(got['Runtime/Linux/x86-64/Standalone']['origin'], 'runtimes')

    def run_main(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out), \
                mock.patch.dict(os.environ, {'GITHUB_ACTIONS': '', 'GITHUB_STEP_SUMMARY': ''}), \
                mock.patch.object(release_inventory, 'ASSETS', self.assets), \
                mock.patch.object(release_inventory, 'XTALK', self.xtalk):
            code = release_inventory.main(list(argv))
        return code, out.getvalue()

    def test_unknown_origin(self):
        stray = os.path.join(self.root, 'Stray', 'thing.so')
        os.makedirs(os.path.dirname(stray))
        with open(stray, 'wb') as f:
            f.write(elf())
        out_file = os.path.join(self.dir, 'inv.json')
        code, out = self.run_main(self.root, '--platform', 'linux-x86_64', '--out', out_file)
        self.assertEqual(code, 0, out)
        self.assertIn('Stray/thing.so', out)
        code, out = self.run_main(self.root, '--platform', 'linux-x86_64', '--out', out_file, '--fail-on-unknown')
        self.assertEqual(code, 1, out)
        with open(out_file, encoding='utf-8') as f:
            records = json.load(f)['binaries']
        self.assertEqual([r['origin'] for r in records if r['path'] == 'Stray/thing.so'], ['unknown'])

    def test_known_package_passes_fail_on_unknown(self):
        code, out = self.run_main(self.root, '--platform', 'linux-x86_64', '--out',
                                  os.path.join(self.dir, 'inv.json'), '--fail-on-unknown')
        self.assertEqual(code, 0, out)
        self.assertIn('x86-win32/xt.dll', out)  # listed as not as pinned


if __name__ == '__main__':
    unittest.main()
