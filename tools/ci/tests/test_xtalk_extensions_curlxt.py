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

"""curlxt, the xTalk Suite's libcurl binding and its tsNet calls, as
tools/oxt/xtalk-extensions.json bundles it, and the Windows system DLL list
its Schannel TLS needed (secur32.dll).

The member is taken from the suite repository itself (curlxt/ in
SethMorrowSoftware/xtalk-suite), not a repository of its own, so its paths
carry the folder. The three extensions load in dependency order: the LCB
library, the helpers on it, then tsNetCompat on the helpers. No network.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))

import xtalk_extensions  # noqa: E402

PS1 = os.path.join(REPO, 'tools', 'ci', 'check-extension-imports.ps1')


def ps1_system_dlls():
    with open(PS1, encoding='utf-8') as f:
        text = f.read()
    m = re.search(r'\$SystemDlls\s*=\s*@\(([^)]*)\)', text)
    return {name.lower() for name in re.findall(r"'([^']+)'", m.group(1))}


class SystemDllsTest(unittest.TestCase):

    def test_the_two_lists_agree(self):
        # The PowerShell check of the built packages and the Python builder
        # must call the same DLLs "system": a DLL only one of them knows is
        # copied by one and refused by the other.
        self.assertEqual(ps1_system_dlls(), set(xtalk_extensions.SYSTEM_DLLS))

    def test_secur32_is_a_system_dll(self):
        self.assertTrue(xtalk_extensions.is_system_dll('SECUR32.dll'))
        self.assertIn('secur32.dll', ps1_system_dlls())

    def test_the_visual_cpp_runtime_is_not(self):
        for name in ('vcruntime140.dll', 'msvcp140.dll'):
            self.assertFalse(xtalk_extensions.is_system_dll(name), name)


class CurlxtMemberTest(unittest.TestCase):

    def setUp(self):
        self.data = xtalk_extensions.load_manifest()
        self.member = next((m for m in self.data['members'] if m['name'] == 'curlxt'), None)
        self.assertIsNotNone(self.member, 'no curlxt member in xtalk-extensions.json')

    def test_taken_from_the_suite(self):
        self.assertEqual(self.member['repository'], 'SethMorrowSoftware/xtalk-suite')
        own = [f['path'] for f in self.member['files'] if 'repository' not in f]
        self.assertTrue(own)
        for path in own:
            self.assertTrue(path.startswith('curlxt/'), path)

    def test_a_library_for_every_platform(self):
        have = {xtalk_extensions.library_platform(f)
                for f in xtalk_extensions.member_files(self.member, 'library')}
        self.assertEqual(have, set(self.data['platforms']))

    def test_windows_needs_no_runtime_dlls(self):
        # Built with the static CRT (/MT): nothing to copy next to it, so
        # nothing for vc_runtime to pin.
        for f in xtalk_extensions.member_files(self.member, 'library'):
            if xtalk_extensions.library_platform(f) in xtalk_extensions.WINDOWS_PLATFORMS:
                extra = [d for d in f['imports'] if not xtalk_extensions.is_system_dll(d)]
                self.assertEqual(extra, [], f['path'])

    def test_three_extensions_in_dependency_order(self):
        exts = [(e['kind'], e['id']) for e in self.member['extensions']]
        self.assertEqual(exts, [('lcb', 'org.openxtalk.library.curl'),
                                ('lcs', 'curlHelpers'), ('lcs', 'tsNetCompat')])
        by_id = {e['id']: e for e in self.member['extensions']}
        self.assertEqual(by_id['curlHelpers']['requires'], ['org.openxtalk.library.curl'])
        self.assertEqual(by_id['tsNetCompat']['requires'], ['curlHelpers'])
        order = [e['id'] for _, e in xtalk_extensions.dependency_order(self.data)]
        self.assertLess(order.index('org.openxtalk.library.curl'), order.index('curlHelpers'))
        self.assertLess(order.index('curlHelpers'), order.index('tsNetCompat'))

    def test_the_tsnet_probe_asks_for_the_tsnet_version(self):
        e = next(e for e in self.member['extensions'] if e['id'] == 'tsNetCompat')
        self.assertEqual(e['probe'], 'tsNetVersion()')
        self.assertRegex('1.4.5', e['expect'])

    def test_openssl_licence_is_carried(self):
        names = [f.get('name') for f in self.member['files'] if f['role'] == 'licence']
        self.assertIn('OpenSSL-LICENSE.txt', names)


if __name__ == '__main__':
    unittest.main()
