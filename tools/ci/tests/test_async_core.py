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

"""The engine's background jobs (engine/src/async-core.cpp): the check that
runs them on their own (tools/ci/async_core_check.py), here run for real,
with the sanitizers where the machine has them, since it needs nothing but
a C++ compiler; and what keeps that file able to be built on its own.

  python3 -m unittest discover -s tools/ci/tests

These tests run on Linux in "CI checks" and on Windows and macOS in "CI
checks (Windows, macOS)", which is where the Windows and macOS halves of
the file first meet their systems.
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import async_core_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class CheckScript(unittest.TestCase):
    def test_builds_the_core_with_the_check(self):
        cmd = async_core_check.build_command('/tmp/x', 'g++')
        self.assertIn(os.path.join(REPO, 'engine', 'src', 'async-core.cpp'), cmd)
        self.assertIn(os.path.join(CI, 'async-core-check.cpp'), cmd)
        self.assertIn('-Werror', cmd)
        self.assertIn('-pthread', cmd)
        self.assertNotIn('-static', cmd)
        self.assertFalse([x for x in cmd if x.startswith('-fsanitize')])

    def test_sanitizers_and_windows(self):
        self.assertIn('-fsanitize=address,undefined',
                      async_core_check.build_command('/tmp/x', 'g++', sanitize='address'))
        self.assertIn('-fsanitize=thread', async_core_check.build_command('/tmp/x', 'g++', sanitize='thread'))
        windows = async_core_check.build_command('/tmp/x.exe', 'g++', windows=True)
        self.assertIn('-static', windows)
        self.assertNotIn('-pthread', windows)

    def test_runs_in_a_folder_and_takes_a_group(self):
        self.assertEqual(async_core_check.run_command('/b/check', '/b/files'), ['/b/check', '/b/files'])
        self.assertEqual(async_core_check.run_command('/b/check', '/b/files', 'copy', wine=True),
                         ['wine', '/b/check', '/b/files', 'copy'])

    def test_wine_gets_none_of_this_environment(self):
        os.environ['OXT_ASYNC_TEST_VARIABLE'] = '1'
        try:
            env = async_core_check.wine_environment('/p')
        finally:
            del os.environ['OXT_ASYNC_TEST_VARIABLE']
        self.assertNotIn('OXT_ASYNC_TEST_VARIABLE', env)
        self.assertEqual(env['WINEPREFIX'], '/p')
        self.assertEqual(env['LC_ALL'], 'C.UTF-8')

    def test_summary_and_sanitizer_reports(self):
        out = 'PASS one\nFAIL two (3)\nPASS three\nWARNING: ThreadSanitizer: data race (pid=1)\n' \
              '==1==ERROR: AddressSanitizer: heap-use-after-free\nx.cpp:1:2: runtime error: signed overflow\n'
        passes, failures = async_core_check.summarise(out)
        self.assertEqual((len(passes), failures), (2, ['FAIL two (3)']))
        self.assertEqual(len(async_core_check.sanitizer_reports(out)), 3)
        self.assertEqual(async_core_check.sanitizer_reports('PASS one\n'), [])


class TheCore(unittest.TestCase):
    """What lets async-core.cpp be built and checked without the engine,
    and keeps it to what every compiler of the engine has."""

    def setUp(self):
        self.source = read('engine', 'src', 'async-core.cpp')
        self.header = read('engine', 'src', 'async-core.h')

    def test_includes_nothing_of_the_engine(self):
        for text in (self.source, self.header):
            self.assertEqual(re.findall(r'#\s*include\s+"([^"]+)"', text),
                             ['async-core.h'] if text is self.source else [])
        for name in ('foundation', 'globdefs', 'MCValue', 'MCStringRef', 'MCDataRef', 'MCNameRef'):
            self.assertNotIn(name, self.source)

    def test_uses_no_container_thread_or_lock_of_the_library(self):
        # docs/development/C++-features.md
        includes = set(re.findall(r'#\s*include\s+<([^>]+)>', self.source))
        for header in ('thread', 'mutex', 'condition_variable', 'future', 'vector', 'string', 'map',
                       'memory', 'functional', 'algorithm', 'iostream'):
            self.assertNotIn(header, includes)
        self.assertIsNone(re.search(r'\bstd::(?!atomic\b|nothrow\b)\w+', self.source),
                          'only std::atomic and std::nothrow are used')
        self.assertNotIn('thread_local', self.source)
        self.assertNotRegex(self.source, r'\b(try|catch|throw)\b')

    def test_every_job_has_its_done_event_from_the_start(self):
        # The end of a job can always be told: its event is allocated with it
        create = self.source[self.source.index('\nJobCreate('):self.source.index('\nJobRelease(')]
        self.assertIn('done_event', create)
        self.assertIn('calloc(1, sizeof(QueuedEvent))', create)

    def test_the_other_systems_check_it_when_it_changes(self):
        import yaml
        workflow = yaml.safe_load(read('.github', 'workflows', 'ci-checks-other-os.yml'))
        triggers = workflow[True] if True in workflow else workflow['on']
        for event in ('push', 'pull_request'):
            self.assertIn('engine/src/async-core.*', triggers[event]['paths'])


class RunsHere(unittest.TestCase):
    """The check itself. OXT_ASYNC_CHECK=0 leaves it out."""

    def run_check(self, sanitize=None):
        if os.environ.get('OXT_ASYNC_CHECK') == '0':
            self.skipTest('OXT_ASYNC_CHECK=0')
        if not async_core_check.find_compiler():
            self.skipTest('no C++ compiler')
        status, output = async_core_check.check(sanitize=sanitize)
        if status == 'skipped':
            self.skipTest('the sanitizer cannot run on this machine')
        if sanitize and status == 'failed' and 'the check did not build' in output and \
                not async_core_check.summarise(output)[0]:
            # The compiler is there without the sanitizer's runtime; a
            # build that fails for another reason fails the plain run too
            self.skipTest('the compiler has no %s sanitizer here' % sanitize)
        passes, failures = async_core_check.summarise(output)
        self.assertEqual(status, 'passed', output[-6000:])
        self.assertEqual(failures, [])
        self.assertGreater(len(passes), 100)

    def test_the_check_passes(self):
        self.run_check()

    @unittest.skipIf(sys.platform == 'win32', 'MinGW-w64 has no sanitizers')
    def test_the_check_passes_with_the_address_sanitizer(self):
        self.run_check('address')

    @unittest.skipIf(sys.platform == 'win32', 'MinGW-w64 has no sanitizers')
    def test_the_check_passes_with_the_thread_sanitizer(self):
        self.run_check('thread')


if __name__ == '__main__':
    unittest.main()
