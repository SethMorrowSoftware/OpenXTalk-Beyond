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


if __name__ == '__main__':
    unittest.main()
