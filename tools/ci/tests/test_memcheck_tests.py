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

"""tools/ci/memcheck_tests.py: which of memcheck's reports count, and when
a test failed as a test. The log below is the shape of memcheck's on
0.2.7-rc.6.9's engine for TestDeleteGroupOfTarget (shortened): an invalid
read and write of a control freed under its message, and the engine's own
mismatched delete, which does not count.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import memcheck_tests  # noqa: E402

LOG = '''==2744== Mismatched free() / delete / delete []
==2744==    at 0x484A164: operator delete(void*) (in vgpreload_memcheck-amd64-linux.so)
==2744==    by 0x4942D8: ??? (in Standalone)
==2744==  Address 0x5a0 is 0 bytes inside a block of size 16 alloc'd
==2744==    at 0x4846828: operator new[](unsigned long) (in vgpreload_memcheck-amd64-linux.so)
==2744== 
==2744== Invalid read of size 8
==2744==    at 0x4FC267: ??? (in Standalone)
==2744==    by 0x4FC976: ??? (in Standalone)
==2744==  Address 0x79d50e8 is 200 bytes inside a block of size 376 free'd
==2744==    at 0x484A164: operator delete(void*) (in vgpreload_memcheck-amd64-linux.so)
==2744==  Block was alloc'd at
==2744==    at 0x48479E8: operator new(unsigned long, std::nothrow_t const&) (in vgpreload_memcheck-amd64-linux.so)
==2744== 
==2744== Invalid write of size 8
==2744==    at 0x4FC280: ??? (in Standalone)
==2744==  Address 0x79d50e8 is 200 bytes inside a block of size 376 free'd
==2744== 
==2744== Invalid read of size 1
==2744==    at 0x4FC2C8: ??? (in Standalone)
==2744== 
'''


class Reports(unittest.TestCase):
    def test_each_report_is_found(self):
        reports = memcheck_tests.memcheck_reports(LOG)
        self.assertEqual([r[0] for r in reports], [
            'Mismatched free() / delete / delete []',
            'Invalid read of size 8',
            'Invalid write of size 8',
            'Invalid read of size 1'])

    def test_a_report_keeps_its_lines(self):
        reports = memcheck_tests.memcheck_reports(LOG)
        read = reports[1][1].split('\n')
        self.assertEqual(read[0], 'Invalid read of size 8')
        self.assertIn('   at 0x4FC267: ??? (in Standalone)', read)
        self.assertIn(" Address 0x79d50e8 is 200 bytes inside a block of size 376 free'd", read)
        self.assertIn(' Block was alloc\'d at', read)
        self.assertNotIn('Invalid write of size 8', read)

    def test_only_uses_of_freed_or_foreign_memory_count(self):
        reports = memcheck_tests.memcheck_reports(LOG)
        self.assertEqual([r[0] for r in memcheck_tests.counted(reports)], [
            'Invalid read of size 8', 'Invalid write of size 8', 'Invalid read of size 1'])

    def test_an_invalid_free_counts(self):
        log = ('==9== Invalid free() / delete / delete[] / realloc()\n'
               '==9==    at 0x1: free\n==9== \n')
        reports = memcheck_tests.memcheck_reports(log)
        self.assertEqual(len(memcheck_tests.counted(reports)), 1)

    def test_other_reports_do_not_count(self):
        log = ('==9== Conditional jump or move depends on uninitialised value(s)\n'
               '==9==    at 0x1: f\n==9== \n'
               '==9== Mismatched free() / delete / delete []\n==9==    at 0x2: g\n')
        self.assertEqual(memcheck_tests.counted(memcheck_tests.memcheck_reports(log)), [])

    def test_a_clean_log(self):
        self.assertEqual(memcheck_tests.memcheck_reports(''), [])
        self.assertEqual(memcheck_tests.memcheck_reports('==1== \n'), [])


class TestFailed(unittest.TestCase):
    def test_passed(self):
        self.assertFalse(memcheck_tests.test_failed(0, 'ok - script compiles\nok - the group is gone\n'))

    def test_a_not_ok(self):
        self.assertTrue(memcheck_tests.test_failed(0, 'ok - script compiles\nnot ok - the group is gone\n'))

    def test_an_expected_failure(self):
        self.assertFalse(memcheck_tests.test_failed(0, 'ok - a\nnot ok - b # TODO later\n'))

    def test_exit_status_and_timeout(self):
        self.assertTrue(memcheck_tests.test_failed(1, 'ok - a\n'))
        self.assertTrue(memcheck_tests.test_failed(None, 'ok - a\n'))

    def test_no_output(self):
        self.assertTrue(memcheck_tests.test_failed(0, ''))


class Running(unittest.TestCase):
    """How main() starts valgrind, without valgrind or an engine: a
    relative --bin, as build-linux.yml passes (linux-x86_64-bin), names
    the engine by its absolute path, since the tests run in tests/. On
    the first CI run valgrind was given linux-x86_64-bin/standalone-community
    from tests/ and stopped at once."""

    def setUp(self):
        import shutil
        import tempfile
        self.top = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.top)
        bin_dir = os.path.join(self.top, 'linux-x86_64-bin')
        os.makedirs(os.path.join(bin_dir, 'modules', 'lci'))
        for name in ('standalone-community', 'lc-compile', 'lc-run'):
            open(os.path.join(bin_dir, name), 'w').close()
        self.bin_dir = bin_dir
        self.calls = []
        saved = (memcheck_tests.shutil.which, memcheck_tests.run_engine_tests.run_process, os.getcwd())

        def restore():
            memcheck_tests.shutil.which = saved[0]
            memcheck_tests.run_engine_tests.run_process = saved[1]
            os.chdir(saved[2])
        self.addCleanup(restore)
        memcheck_tests.shutil.which = lambda name: '/usr/bin/valgrind'

        def run_process(cmd, cwd, env, timeout):
            self.calls.append((cmd, cwd))
            log = [a for a in cmd if a.startswith('--log-file=')][0][len('--log-file='):]
            with open(log, 'w') as f:
                f.write(self.vg_log)
            return self.status, self.out, self.err
        memcheck_tests.run_engine_tests.run_process = run_process
        self.vg_log, self.status, self.out, self.err = '', 0, 'ok - script compiles\n', ''

    def run_main(self, *extra):
        import contextlib
        import io
        printed = io.StringIO()
        with contextlib.redirect_stdout(printed):
            code = memcheck_tests.main(['--bin', 'linux-x86_64-bin'] + list(extra) +
                                       ['core/interface/delete.livecodescript:TestDeleteGroupOfTarget'])
        return code, printed.getvalue()

    def test_a_relative_bin_names_the_engine_absolutely(self):
        os.chdir(self.top)
        code, printed = self.run_main()
        self.assertEqual(code, 0, printed)
        cmd, cwd = self.calls[0]
        engine = cmd[cmd.index('-ui') - 1]
        self.assertTrue(os.path.isabs(engine), engine)
        self.assertEqual(os.path.realpath(engine),
                         os.path.realpath(os.path.join(self.bin_dir, 'standalone-community')))
        self.assertTrue(os.path.isabs(cmd[cmd.index('-ui') + 1]))

    def test_a_test_that_never_ran_says_why(self):
        os.chdir(self.top)
        self.status, self.out = 1, ''
        self.vg_log = 'valgrind: linux-x86_64-bin/standalone-community: No such file or directory\n'
        self.err = 'something on stderr\n'
        code, printed = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn('no test output; exit status 1', printed)
        self.assertIn('No such file or directory', printed)
        self.assertIn('something on stderr', printed)

    def test_why_not_run_leaves_out_reports(self):
        self.assertEqual(memcheck_tests.why_not_run(LOG, ''), [])


if __name__ == '__main__':
    unittest.main()
