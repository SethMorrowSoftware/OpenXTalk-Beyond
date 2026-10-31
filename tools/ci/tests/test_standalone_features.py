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

"""standalone_check.py's feature probes (the modernization plan's MOD-03):
a runtime built from this commit fails without a feature, one from the
runtimes asset is only reported, and the probe stack asks about every
feature the check knows. No engine is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import standalone_check as sc  # noqa: E402

ALL_YES = ['PROBE version=9.7.1-OXT processor=x86_64 platform=Linux environment=command line',
           'FEATURE microseconds=yes', 'FEATURE matches=yes', 'FEATURE literal-arrays=yes']
OLD = ['PROBE version=9.7.1-OXT processor=x86 platform=Win32 environment=command line',
       'FEATURE microseconds=error', 'FEATURE matches=no', 'FEATURE literal-arrays=yes']


class Features(unittest.TestCase):
    def test_all_present(self):
        for own in (True, False):
            problems, lines = sc.check_features('linux-x86_64', ALL_YES, own)
            self.assertEqual(problems, [])
            self.assertEqual(lines, ['linux-x86_64: features microseconds=yes, matches=yes, literal-arrays=yes'])

    def test_own_runtime_without_one_fails(self):
        problems, _ = sc.check_features('win-x86_64', OLD, True)
        self.assertEqual(problems, ['win-x86_64: the standalone, built from this commit, lacks '
                                    'microseconds=error, matches=no'])

    def test_asset_runtime_without_one_is_reported(self):
        problems, lines = sc.check_features('win-x86', OLD, False)
        self.assertEqual(problems, [])
        self.assertIn('microseconds=error', lines[0])
        self.assertIn('reported, not failed', lines[0])

    def test_no_feature_lines_fails_either_way(self):
        for own in (True, False):
            problems, _ = sc.check_features('linux-x86', ALL_YES[:1], own)
            self.assertEqual(problems, ['linux-x86: the standalone wrote no FEATURE lines'])

    def test_probe_stack_asks_the_documented_features(self):
        with open(sc.DEPLOY_SCRIPT, encoding='utf-8') as f:
            script = f.read()
        body = script[script.index('private function featureProbes'):script.index('end featureProbes')]
        asked = re.findall(r'put "([a-z0-9-]+)" & tab', body)
        self.assertEqual(asked, ['microseconds', 'matches', 'literal-arrays'])
        for name in asked:
            self.assertRegex(name, sc.FEATURE_RE.pattern[len('^FEATURE '):].split('=')[0])
            self.assertIn('--    %s' % name, script)


if __name__ == '__main__':
    unittest.main()
