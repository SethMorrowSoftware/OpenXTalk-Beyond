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

"""tools/ci/retry_check.py, which runs the web checks again in WebKit when
they fail, on a made-up check.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import retry_check  # noqa: E402

# The made-up check: each run counts itself in the file COUNT, writes its
# number to run.txt in the folder FILES (unless FILES is -), and exits with
# the status given for its run, the last one for every run after. A status
# that ends in n writes no files; "term" is ended by SIGTERM. "hang" never
# ends: it starts a child that never ends either, as the web IDE soak's
# browser is, writes the child's process id to child-<run>.pid beside
# COUNT, and waits; "stubborn" hangs and ignores SIGTERM too.
CHECK = r'''
import os, signal, subprocess, sys, time
count, files, statuses = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
n = 1
if os.path.exists(count):
    with open(count) as f:
        n = int(f.read()) + 1
with open(count, 'w') as f:
    f.write(str(n))
status = statuses[min(n, len(statuses)) - 1]
if files != '-' and not status.endswith('n'):
    os.makedirs(files, exist_ok=True)
    with open(os.path.join(files, 'run.txt'), 'w') as f:
        f.write(str(n))
if status == 'term':
    os.kill(os.getpid(), signal.SIGTERM)
if status in ('hang', 'stubborn'):
    if status == 'stubborn':
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
    child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(600)'])
    with open(os.path.join(os.path.dirname(count), 'child-%d.pid' % n), 'w') as f:
        f.write(str(child.pid))
    time.sleep(600)
sys.exit(int(status.rstrip('n')))
'''


def alive(pid):
    """Whether a process is running (POSIX; a zombie, which has ended and
    waits for its parent, counts as ended)."""
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    try:
        with open('/proc/%d/stat' % pid) as f:
            return f.read().rsplit(')', 1)[1].split()[0] != 'Z'
    except OSError:
        return True


class RetryCheckTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.count = os.path.join(self.tmp, 'count')
        self.files = os.path.join(self.tmp, 'web-check')
        self.summary = os.path.join(self.tmp, 'summary.md')
        env = mock.patch.dict(os.environ, {'GITHUB_ACTIONS': 'true', 'GITHUB_STEP_SUMMARY': self.summary})
        env.start()
        self.addCleanup(env.stop)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def check(self, statuses, files=True):
        return [sys.executable, '-c', CHECK, self.count, self.files if files else '-', statuses]

    def retry(self, statuses, tries=2, files=True, minutes=None):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = retry_check.retry(self.check(statuses, files), tries,
                                       self.files if files else None, 'the check', minutes)
        return status, out.getvalue()

    def child(self, run):
        with open(os.path.join(self.tmp, 'child-%d.pid' % run)) as f:
            return int(f.read())

    def runs(self):
        with open(self.count) as f:
            return int(f.read())

    def kept(self, *path):
        with open(os.path.join(self.files, *path)) as f:
            return f.read()

    def summary_lines(self):
        if not os.path.exists(self.summary):
            return []
        with open(self.summary) as f:
            return f.read().splitlines()

    def test_a_check_that_passes_runs_once(self):
        status, out = self.retry('0')
        self.assertEqual((status, self.runs()), (0, 1))
        self.assertEqual(os.listdir(self.files), ['run.txt'])
        self.assertEqual(self.summary_lines(), [])
        self.assertNotIn('warning', out)

    def test_a_flake_passes_on_the_second_try_with_both_tries_files(self):
        status, out = self.retry('1,0')
        self.assertEqual((status, self.runs()), (0, 2))
        self.assertEqual(sorted(os.listdir(self.files)), ['run.txt', 'try-1'])
        self.assertEqual((self.kept('try-1', 'run.txt'), self.kept('run.txt')), ('1', '2'))
        self.assertEqual(sorted(os.listdir(self.tmp)), ['count', 'summary.md', 'web-check'])
        lines = self.summary_lines()
        self.assertEqual(len(lines), 2, lines)
        self.assertTrue(lines[0].startswith('- the check failed on try 1 of 2 (exit status 1) and runs '
                                            'again; its files will be in try-1 of web-check'), lines[0])
        self.assertTrue(lines[1].startswith('- the check passed on try 2 of 2 after failing (exit status 1)'),
                        lines[1])
        self.assertEqual(out.count('::warning::'), 2)
        self.assertIn('the check, try 2 of 2', out)

    def test_a_check_that_fails_every_try_gives_the_last_tries_status(self):
        status, out = self.retry('3,5')
        self.assertEqual((status, self.runs()), (5, 2))
        self.assertEqual((self.kept('try-1', 'run.txt'), self.kept('run.txt')), ('1', '2'))
        lines = self.summary_lines()
        self.assertEqual(len(lines), 1, lines)
        self.assertIn('failed on try 1 of 2 (exit status 3) and runs again', lines[0])

    def test_one_try_is_the_check_run_once(self):
        status, out = self.retry('1,0', tries=1)
        self.assertEqual((status, self.runs()), (1, 1))
        self.assertEqual(os.listdir(self.files), ['run.txt'])
        self.assertEqual(self.summary_lines(), [])
        self.assertNotIn('warning', out)

    def test_three_tries(self):
        status, _ = self.retry('1,2,0', tries=3)
        self.assertEqual((status, self.runs()), (0, 3))
        self.assertEqual(sorted(os.listdir(self.files)), ['run.txt', 'try-1', 'try-2'])
        self.assertEqual([self.kept('try-1', 'run.txt'), self.kept('try-2', 'run.txt'), self.kept('run.txt')],
                         ['1', '2', '3'])
        self.assertIn('after failing (exit status 1, 2)', self.summary_lines()[-1])

    def test_the_first_tries_files_are_kept_when_the_last_writes_none(self):
        status, _ = self.retry('1,2n')
        self.assertEqual((status, self.runs()), (2, 2))
        self.assertEqual(os.listdir(self.files), ['try-1'])
        self.assertEqual(self.kept('try-1', 'run.txt'), '1')

    def test_a_try_that_wrote_no_files(self):
        status, _ = self.retry('1n,0')
        self.assertEqual((status, self.runs()), (0, 2))
        self.assertEqual(os.listdir(self.files), ['run.txt'])
        self.assertNotIn('its files', self.summary_lines()[0])

    def test_without_files(self):
        status, _ = self.retry('1,0', files=False)
        self.assertEqual((status, self.runs()), (0, 2))
        self.assertFalse(os.path.exists(self.files))

    @unittest.skipIf(os.name == 'nt', 'a POSIX signal')
    def test_a_try_that_a_signal_ended(self):
        status, _ = self.retry('term')
        self.assertEqual((status, self.runs()), (128 + signal.SIGTERM, 2))
        self.assertIn('(exit status %d)' % (128 + signal.SIGTERM), self.summary_lines()[0])

    def test_a_command_that_cannot_run(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = retry_check.retry([os.path.join(self.tmp, 'no-such-program')], 2)
        self.assertEqual(status, 127)
        self.assertEqual(out.getvalue().count('could not run'), 2)

    def test_outside_github_actions(self):
        with mock.patch.dict(os.environ, {'GITHUB_ACTIONS': '', 'GITHUB_STEP_SUMMARY': ''}):
            status, out = self.retry('1,0')
        self.assertEqual(status, 0)
        self.assertIn('warning: the check failed on try 1 of 2', out)
        self.assertNotIn('::warning::', out)
        self.assertEqual(self.summary_lines(), [])

    def test_an_annotation_is_one_line(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            retry_check.warn('100% of\r\nthe runs')
        self.assertEqual(out.getvalue(), '::warning::100%25 of%0D%0Athe runs\n')

    # A try's time limit (--try-minutes): the web IDE soak in WebKit hung
    # on main 25a872e97 and took the step's whole 25 minutes, so its
    # second try never ran

    def test_a_try_that_hangs_is_stopped_and_the_next_try_runs(self):
        started = time.monotonic()
        status, out = self.retry('hang,0', minutes=0.03)
        self.assertLess(time.monotonic() - started, 60)
        self.assertEqual((status, self.runs()), (0, 2))
        self.assertEqual((self.kept('try-1', 'run.txt'), self.kept('run.txt')), ('1', '2'))
        self.assertIn('the check did not finish in 0.03 minutes on try 1 of 2 and was stopped '
                      '(exit status 124)', out)
        lines = self.summary_lines()
        self.assertEqual(len(lines), 2, lines)
        self.assertTrue(lines[0].startswith('- the check did not finish in 0.03 minutes and was stopped '
                                            'on try 1 of 2 (exit status 124) and runs again; its files '
                                            'will be in try-1 of web-check'), lines[0])
        self.assertIn('passed on try 2 of 2 after failing (exit status 124)', lines[1])

    def test_a_last_try_that_hangs_fails_with_124(self):
        status, out = self.retry('hang', tries=1, minutes=0.03)
        self.assertEqual((status, self.runs()), (retry_check.TIMED_OUT, 1))
        self.assertEqual(retry_check.TIMED_OUT, 124)
        self.assertIn('did not finish in 0.03 minutes on try 1 of 1 and was stopped', out)

    @unittest.skipIf(os.name == 'nt', 'a POSIX process group')
    def test_what_a_stopped_try_started_is_stopped_too(self):
        self.retry('hang,hang', minutes=0.03)
        for run in (1, 2):
            child = self.child(run)
            deadline = time.monotonic() + 10
            while alive(child) and time.monotonic() < deadline:
                time.sleep(0.1)
            self.assertFalse(alive(child), 'try %d\'s child %d is still running' % (run, child))

    @unittest.skipIf(os.name == 'nt', 'a POSIX signal')
    def test_a_try_that_ignores_sigterm_is_killed(self):
        with mock.patch.object(retry_check, 'GRACE', 0.5):
            started = time.monotonic()
            status, _ = self.retry('stubborn', tries=1, minutes=0.03)
        self.assertEqual(status, 124)
        self.assertLess(time.monotonic() - started, 30)
        child = self.child(1)
        deadline = time.monotonic() + 10
        while alive(child) and time.monotonic() < deadline:
            time.sleep(0.1)
        self.assertFalse(alive(child))

    def test_a_try_within_its_time_limit_is_untouched(self):
        status, out = self.retry('3,0', minutes=5)
        self.assertEqual((status, self.runs()), (0, 2))
        self.assertNotIn('did not finish', out)
        self.assertIn('failed on try 1 of 2 (exit status 3)', self.summary_lines()[0])

    @unittest.skipIf(os.name == 'nt', 'a POSIX signal')
    def test_a_sigterm_to_this_script_reaches_a_try_with_a_time_limit(self):
        # A cancelled job's SIGTERM, which a command in its own process
        # group would not get
        script = ('import sys; sys.path.insert(0, %r); import retry_check; '
                  'sys.exit(retry_check.main(["--tries", "1", "--try-minutes", "5", "--"] + sys.argv[1:]))'
                  % os.path.dirname(os.path.abspath(retry_check.__file__)))
        process = subprocess.Popen([sys.executable, '-c', script] + self.check('hang'),
                                   stdout=subprocess.DEVNULL)
        deadline = time.monotonic() + 30
        while not os.path.exists(os.path.join(self.tmp, 'child-1.pid')) and time.monotonic() < deadline:
            time.sleep(0.1)
        os.kill(process.pid, signal.SIGTERM)
        self.assertEqual(process.wait(timeout=30), 128 + signal.SIGTERM)
        child = self.child(1)
        deadline = time.monotonic() + 10
        while alive(child) and time.monotonic() < deadline:
            time.sleep(0.1)
        self.assertFalse(alive(child))

    def test_the_options(self):
        with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(retry_check.main(['--tries', '2']), 2)
            self.assertEqual(retry_check.main(['--tries', '2', '--']), 2)
            self.assertEqual(retry_check.main(['--tries', '0', '--', sys.executable, '-c', '']), 2)
            for minutes in ('0', '-1', 'nan'):
                self.assertEqual(retry_check.main(['--try-minutes', minutes, '--', sys.executable, '-c', '']), 2)
            self.assertEqual(retry_check.main(['--tries', '1', '--try-minutes', '1', '--', sys.executable, '-c',
                                               'import sys; sys.exit(3)']), 3)
            for bad in (['--tries', 'two'], ['--try-minutes', 'ten'], ['--no-such-option']):
                with self.assertRaises(SystemExit) as e:
                    retry_check.main(bad + ['--', sys.executable, '-c', ''])
                self.assertEqual(e.exception.code, 2)
            self.assertEqual(retry_check.main(['--files', self.files, '--what', 'the check', '--']
                                              + self.check('1,0')), 0)
            self.assertEqual(retry_check.main(['--tries', '1', '--'] + self.check('7')), 7)
            # what follows the first -- is the command's, a -- in it too
            self.assertEqual(retry_check.main(['--tries', '1', '--', sys.executable, '-c',
                                               'import sys; sys.exit(sys.argv[1:] != ["--", "x"])',
                                               '--', 'x']), 0)
        self.assertEqual(self.runs(), 3)
        self.assertEqual(self.kept('try-1', 'run.txt'), '1')


if __name__ == '__main__':
    unittest.main()
