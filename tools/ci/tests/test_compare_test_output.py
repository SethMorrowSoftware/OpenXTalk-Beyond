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

"""tools/ci/compare_test_output.py and the file it reads, which
run_engine_tests.py --output writes: two runs' tests are compared by what
they printed as well as by their results.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import compare_test_output  # noqa: E402
import run_engine_tests  # noqa: E402


def output_file(results):
    """What run_engine_tests.write_output writes for results."""
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, 'out.txt')
        run_engine_tests.write_output(path, '/engine', results)
        with open(path, encoding='utf-8') as f:
            return f.read()


def result(name, outcome, output, details=None):
    return run_engine_tests.Result('lcs', 'core/database/x: ' + name, outcome, output=output, details=details)


class Output(unittest.TestCase):
    def test_every_test_with_its_output(self):
        text = output_file([result('TestA', 'pass', 'ok - a\n# says hello\n'),
                            result('TestB', 'fail', 'not ok - b\n', ['stack trace']),
                            result('TestC', 'skip', '')])
        tests = compare_test_output.parse(text)
        self.assertEqual(list(tests), ['lcs: core/database/x: TestA', 'lcs: core/database/x: TestB',
                                       'lcs: core/database/x: TestC'])
        self.assertEqual(tests['lcs: core/database/x: TestA'], ('pass', ['ok - a', '# says hello']))
        self.assertEqual(tests['lcs: core/database/x: TestB'], ('fail', ['not ok - b', 'stack trace']))
        self.assertEqual(tests['lcs: core/database/x: TestC'], ('skip', []))

    def test_the_option(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, 'sub', 'out.txt')
            with mock.patch.object(run_engine_tests, 'tools_in',
                                   return_value={'engine': '/engine'}), \
                    mock.patch.object(run_engine_tests, 'compile_test_modules', return_value=[]), \
                    mock.patch.object(run_engine_tests, 'append_summary'), \
                    mock.patch.object(run_engine_tests, 'run_lcs',
                                      return_value=[result('TestA', 'pass', 'ok - a\n')]), \
                    contextlib.redirect_stdout(io.StringIO()):
                run_engine_tests.main(['--bin', d, '--suite', 'lcs', '--log', os.path.join(d, 'log.txt'),
                                       '--output', path])
            with open(path, encoding='utf-8') as f:
                self.assertEqual(compare_test_output.parse(f.read()),
                                 {'lcs: core/database/x: TestA': ('pass', ['ok - a'])})


class Compare(unittest.TestCase):
    BEFORE = ('# Engine: old\n'
              '### TEST pass lcs: t: TestSame\nok - same\n# same text\n'
              '### TEST pass lcs: t: TestText\nok - connects\n# no server: Can\'t connect to MySQL server\n'
              '### TEST fail lcs: t: TestLogin\nnot ok - connects\n'
              '### TEST pass lcs: t: TestGone\nok - gone\n')
    AFTER = ('# Engine: new\n'
             '### TEST pass lcs: t: TestSame\nok - same\n# same text\n'
             '### TEST pass lcs: t: TestText\nok - connects\n# no server: Can\'t connect to server\n'
             '### TEST pass lcs: t: TestLogin\nok - connects\n'
             '### TEST pass lcs: t: TestNew\nok - new\n')

    def differences(self):
        return compare_test_output.compare(compare_test_output.parse(self.BEFORE),
                                           compare_test_output.parse(self.AFTER))

    def test_a_changed_diagnostic_is_a_difference_though_both_pass(self):
        d = dict((t, (k, lines)) for t, k, lines in self.differences())
        self.assertEqual(d['lcs: t: TestText'], ('output', ["-# no server: Can't connect to MySQL server",
                                                            "+# no server: Can't connect to server"]))

    def test_a_changed_result(self):
        d = dict((t, (k, lines)) for t, k, lines in self.differences())
        self.assertEqual(d['lcs: t: TestLogin'], ('result', ['fail -> pass', '-not ok - connects',
                                                             '+ok - connects']))

    def test_tests_in_one_run_only(self):
        d = dict((t, k) for t, k, _ in self.differences())
        self.assertEqual(d['lcs: t: TestGone'], 'only before')
        self.assertEqual(d['lcs: t: TestNew'], 'only after')
        self.assertNotIn('lcs: t: TestSame', d)

    def run_main(self, before, after, *extra):
        with tempfile.TemporaryDirectory() as d:
            paths = []
            for name, text in (('before', before), ('after', after)):
                paths.append(os.path.join(d, name))
                with open(paths[-1], 'w', encoding='utf-8') as f:
                    f.write(text)
            summary = os.path.join(d, 'summary.md')
            out = io.StringIO()
            with mock.patch.dict(os.environ, {'GITHUB_STEP_SUMMARY': summary}), contextlib.redirect_stdout(out):
                status = compare_test_output.main(paths + list(extra))
            with open(summary, encoding='utf-8') as f:
                return status, out.getvalue(), f.read()

    def test_the_report_goes_to_the_summary_and_fails_only_when_asked(self):
        status, out, summary = self.run_main(self.BEFORE, self.AFTER)
        self.assertEqual(status, 0)
        self.assertEqual(out.strip(), summary.strip())
        self.assertIn('4 test(s) differ', out)
        self.assertEqual(self.run_main(self.BEFORE, self.AFTER, '--fail-on-difference')[0], 1)
        status, out, _ = self.run_main(self.BEFORE, self.BEFORE, '--fail-on-difference')
        self.assertEqual(status, 0)
        self.assertIn('No test\'s result or output differs.', out)


if __name__ == '__main__':
    unittest.main()
