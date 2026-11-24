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

"""The smoke test's check of a file that is not a stack
(tools/ci/run_livecode_check.py), on what engines printed and with a
made-up engine.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import shutil
import stat
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import run_livecode_check  # noqa: E402

# What the Linux engine of 0.2.7-rc.6.4 printed on such a file, and what the
# fixed engine prints
CRASH = ['/opt/OXT-Beyond-0.2.7-rc.6.4/OXT-Beyond exiting on signal 11']
STARTUP_ERROR = ['Startup error - file is not a stack (a script-only stack\'s first line is script "name")']

# The made-up engine, run as <engine> -ui <file>: it ends as the fixed engine
# does when the file's first line is not script "name", and as the file's
# script would if it ran when it is
ENGINE = r'''#!/usr/bin/env python3
import sys
if sys.argv[1] != '-ui':
    sys.exit(3)
with open(sys.argv[2], encoding='utf-8') as f:
    first = f.readline()
if first.startswith('script "'):
    print('ran the file as a script')
    sys.exit(0)
sys.stderr.write('Startup error - file is not a stack (a script-only stack\'s first line is script "name")\n')
sys.exit(255)
'''


class NotAStackProblemTest(unittest.TestCase):

    def test_the_startup_error(self):
        self.assertIsNone(run_livecode_check.not_a_stack_problem(255, [], STARTUP_ERROR))

    def test_a_crash_on_linux(self):
        # The engine's signal handler prints its line and exits with -1
        self.assertEqual(run_livecode_check.not_a_stack_problem(255, [], CRASH),
                         'the engine crashed (%s)' % CRASH[0])

    def test_a_crash_on_macos(self):
        # The handler prints its line and returns, and the system ends the
        # process with the signal
        self.assertEqual(run_livecode_check.not_a_stack_problem(-11, [], CRASH),
                         'the engine crashed (%s)' % CRASH[0])
        self.assertEqual(run_livecode_check.not_a_stack_problem(-11, [], []),
                         'the engine was ended by signal 11')

    def test_no_end(self):
        self.assertEqual(run_livecode_check.not_a_stack_problem(None, [], []), 'the engine did not finish')

    def test_a_run(self):
        self.assertEqual(run_livecode_check.not_a_stack_problem(0, ['ran the file as a script'], []),
                         'the engine exited with 0, as if the file were a stack or had run')

    def test_another_error(self):
        self.assertEqual(run_livecode_check.not_a_stack_problem(255, [], ['Startup error - failed to read stackfile']),
                         'exit code 255, without the startup error "file is not a stack"')


@unittest.skipIf(os.name == 'nt', 'a POSIX script as the engine')
class CheckNotAStackTest(unittest.TestCase):

    def setUp(self):
        self.folder = tempfile.mkdtemp(prefix='oxt-test-not-a-stack-')
        self.engine = os.path.join(self.folder, 'OXT-Beyond')
        with open(self.engine, 'w', encoding='utf-8', newline='\n') as f:
            f.write(ENGINE)
        os.chmod(self.engine, os.stat(self.engine).st_mode | stat.S_IXUSR)

    def tearDown(self):
        shutil.rmtree(self.folder, ignore_errors=True)

    def test_the_file_has_no_first_line(self):
        problem, code, out, err = run_livecode_check.check_not_a_stack(self.engine, {}, self.folder, 60)
        self.assertIsNone(problem, (code, out, err))
        self.assertEqual((code, out, err), (255, [], STARTUP_ERROR))

    def test_the_file_is_removed(self):
        before = set(os.listdir(tempfile.gettempdir()))
        run_livecode_check.check_not_a_stack(self.engine, {}, self.folder, 60)
        left = [x for x in set(os.listdir(tempfile.gettempdir())) - before if x.startswith('oxt-not-a-stack-')]
        self.assertEqual(left, [])


class LinuxBrowserOffTest(unittest.TestCase):
    """linux_browser_off: whether a check turns the browser widget off
    (LIVECODE_USE_CEF=0) as the Linux launcher does: only with no CEF and no
    WebKitGTK helper whose --probe succeeds."""

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir)
        self.engine = os.path.join(self.dir, 'OXT-Beyond')
        open(self.engine, 'w').close()
        self.externals = os.path.join(self.dir, 'Externals')
        os.makedirs(self.externals)

    def helper(self, status):
        path = os.path.join(self.dir, run_livecode_check.WEBKIT_HELPER)
        with open(path, 'w') as f:
            f.write('#!/bin/sh\n[ "$1" = --probe ] || exit 9\nexit %d\n' % status)
        os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)

    def off(self):
        return run_livecode_check.linux_browser_off(self.engine, self.externals)

    def test_cef_keeps_it_on(self):
        os.makedirs(os.path.join(self.externals, 'CEF'))
        open(os.path.join(self.externals, 'CEF', 'libcef.so'), 'w').close()
        self.assertFalse(self.off())

    def test_no_cef_and_no_helper_turns_it_off(self):
        self.assertTrue(self.off())

    @unittest.skipIf(os.name == 'nt', 'a shell script helper')
    def test_no_cef_and_webkitgtk_keeps_it_on(self):
        self.helper(0)
        self.assertFalse(self.off())

    @unittest.skipIf(os.name == 'nt', 'a shell script helper')
    def test_no_cef_and_a_failing_probe_turns_it_off(self):
        self.helper(1)
        self.assertTrue(self.off())

    def test_a_helper_that_cannot_run_turns_it_off(self):
        path = os.path.join(self.dir, run_livecode_check.WEBKIT_HELPER)
        open(path, 'w').close()
        os.chmod(path, 0o644)
        self.assertTrue(self.off())


if __name__ == '__main__':
    unittest.main()
