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

"""tools/ci/appearance_check.py: what passes and what fails, from the lines
the engine logs; the keyfile it writes; and that the check script, the
workflow and the Python agree on the steps.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import appearance_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))

GOOD = [
    'INFO platform=Linux version=9.7.1 processor=x86_64',
    'DEFAULT false light 0',
    'MESSAGE dark 1',
    'OPTIN dark 1',
    'WROTE default ',
    'MESSAGE light 2',
    'SWITCH light 2',
    'WROTE prefer-dark ',
    'MESSAGE dark 3',
    'BACK dark 3',
    'MESSAGE light 4',
    'OPTOUT light 4',
    'WROTE default ',
    'QUIET light 4',
    'QUIT 12345',
]


def failures(result):
    return [name for name, ok, _ in appearance_check.evaluate(result) if not ok]


class Evaluate(unittest.TestCase):
    def test_a_good_run_passes(self):
        self.assertEqual(failures(GOOD), [])

    def test_the_old_engine_fails(self):
        # An engine without the property: setting it is an error, and the
        # systemAppearance is always light
        old = ['DEFAULT false light 0', 'ERROR 192,0,0: property not found', 'QUIT 1']
        self.assertIn('the script ran without an error', failures(old))
        self.assertTrue(any(f.startswith('OPTIN') for f in failures(old)))

    def test_a_desktop_switch_not_followed_fails(self):
        result = [x if not x.startswith('SWITCH') else 'SWITCH dark 1' for x in GOOD]
        self.assertEqual([f for f in failures(result) if f.startswith('SWITCH')], [
            'SWITCH: the systemAppearance is light after 2 systemAppearanceChanged'])

    def test_a_message_while_opted_out_fails(self):
        result = [x if not x.startswith('QUIET') else 'QUIET light 5' for x in GOOD]
        self.assertEqual(failures(result), ['QUIET: the systemAppearance is light after 4 systemAppearanceChanged'])

    def test_twice_for_one_switch_fails(self):
        result = [x if not x.startswith('BACK') else 'BACK dark 4' for x in GOOD]
        self.assertEqual(failures(result), ['BACK: the systemAppearance is dark after 3 systemAppearanceChanged'])

    def test_on_by_default_fails(self):
        result = ['DEFAULT true dark 0'] + GOOD[2:]
        self.assertIn('as it starts, the useDesktopAppearance is false and the systemAppearance light',
                      failures(result))

    def test_no_quit_fails(self):
        self.assertEqual(failures(GOOD[:-1]), ['the engine quit when it was done'])


class Files(unittest.TestCase):
    def test_keyfile(self):
        self.assertEqual(appearance_check.keyfile_text('prefer-dark'),
                         "[org/gnome/desktop/interface]\ncolor-scheme='prefer-dark'\n")

    def test_the_script_logs_every_step(self):
        with open(appearance_check.SCRIPT, encoding='utf-8') as f:
            script = f.read()
        self.assertIn('logLine "DEFAULT"', script)
        for name, _, _ in appearance_check.EXPECTED:
            self.assertIn('step "%s"' % name, script)
        # the keyfile's group, as the Python writes it
        self.assertIn(appearance_check.KEYFILE_GROUP, script)

    def test_the_linux_build_runs_it(self):
        with open(os.path.join(REPO, '.github', 'workflows', 'build-linux.yml'), encoding='utf-8') as f:
            workflow = f.read()
        self.assertRegex(workflow, r'python3 tools/ci/appearance_check\.py --engine "\$OXT_ROOT/Runtime/Linux/')
        self.assertIn('gsettings-desktop-schemas', workflow)


if __name__ == '__main__':
    unittest.main()
