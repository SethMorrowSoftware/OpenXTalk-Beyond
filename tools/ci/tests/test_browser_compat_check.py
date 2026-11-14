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

"""The browser compatibility check (tools/ci/browser_compat_check.py): how
it compares a run with the lines recorded from the release before, what it
excuses, the recorded lines themselves, the probe script, and the Linux
workflow step that runs it.

  python3 -m unittest discover -s tools/ci/tests

The check itself needs a built package and a screen; it runs in the Linux
build (build-linux.yml).
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import browser_compat_check as bcc  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))
EXPECTED = os.path.join(CI, 'browser-compat', 'linux-x86_64.txt')
PROBE = os.path.join(CI, 'browser-compat-check.livecodescript')
WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'build-linux.yml')


def expected_lines():
    with open(EXPECTED, encoding='utf-8') as f:
        return [x.rstrip('\n') for x in f if x.strip() and not x.startswith('#')]


class Compare(unittest.TestCase):
    def test_the_same_lines_pass(self):
        lines = expected_lines()
        self.assertEqual(bcc.compare(lines, list(lines)), [])

    def test_a_changed_value_fails(self):
        lines = expected_lines()
        changed = [x.replace('origin=http://libbrowser_dummy_url', 'origin=null') for x in lines]
        problems = bcc.compare(lines, changed)
        self.assertTrue(problems)
        self.assertTrue(all(p.startswith('changed: ') for p in problems))

    def test_a_missing_and_a_new_line_fail(self):
        lines = expected_lines()
        problems = bcc.compare(lines, lines[1:] + ['z9 extra: url = x'])
        self.assertIn('missing: ' + lines[0], problems)
        self.assertIn('new: z9 extra: url = x', problems)

    def test_the_order_does_not_matter(self):
        lines = expected_lines()
        self.assertEqual(bcc.compare(lines, list(reversed(lines))), [])

    def test_observations_keep_only_obs_lines(self):
        self.assertEqual(bcc.observations(['INFO version=1', 'OBS a: b = c', 'DONE']), ['a: b = c'])


class Allowed(unittest.TestCase):
    W10 = ('w10 relative link: messages = '
           'browserDocumentLoadFailed: http://libbrowser_dummy_url/page2.html?x=1#y ERR_NAME_NOT_RESOLVED ; '
           'browserNavigateFailed: http://libbrowser_dummy_url/page2.html?x=1#y ERR_NAME_NOT_RESOLVED ; '
           'browserDocumentLoadComplete: %s  ; browserNavigateComplete: %s ')

    def test_either_page_after_a_failed_load(self):
        for page in ('chrome-error://chromewebdata/', 'http://libbrowser_dummy_url/page2.html?x=1#y'):
            self.assertTrue(bcc.allowed(self.W10 % (page, page)), page)

    def test_nothing_else_after_a_failed_load(self):
        page = 'http://elsewhere/'
        self.assertFalse(bcc.allowed(self.W10 % (page, page)))

    def test_only_its_own_line(self):
        page = 'chrome-error://chromewebdata/'
        self.assertFalse(bcc.allowed((self.W10 % (page, page)).replace('w10 relative link', 'w9 fragment')))

    def test_every_entry_has_a_reason(self):
        for where, pattern, reason in bcc.ALLOWED:
            re.compile(pattern)
            self.assertTrue(reason.strip(), where)
            self.assertIn(where, [x.partition(' = ')[0] for x in expected_lines()],
                          '%s excuses a line the recording does not have' % where)


class Recording(unittest.TestCase):
    def test_every_line_is_an_obs_line_with_a_step(self):
        keys = []
        for x in expected_lines():
            head, sep, _value = x.partition(' = ')
            self.assertEqual(sep, ' = ', x)
            self.assertRegex(head, r'^[wr]\d+ [^:]+: \S', x)
            keys.append(head)
        self.assertEqual(len(keys), len(set(keys)), 'a step and what recorded twice')

    def test_the_served_base_is_written_as_base(self):
        text = '\n'.join(expected_lines())
        self.assertNotRegex(text, r'127\.0\.0\.1:\d+')
        self.assertIn('{BASE}page1.html', text)

    def test_htmltext_pages_keep_their_dummy_url(self):
        # The whole point of the check: CEF 74's LoadString gave an htmlText
        # page the dummy URL as its address, origin and base, and storage
        reports = [x for x in expected_lines() if x.startswith('w') and ': page reports = ' in x
                   and 'htmlText' in x.partition(':')[0]]
        self.assertTrue(reports)
        for x in reports:
            self.assertIn('href=http://libbrowser_dummy_url/ ', x)
            self.assertIn('origin=http://libbrowser_dummy_url ', x)
            self.assertIn('localStorage ok', x)

    def test_both_parts_are_recorded(self):
        steps = {x.split(' ', 1)[0][0] for x in expected_lines()}
        self.assertEqual(steps, {'w', 'r'})


class CrashTrace(unittest.TestCase):
    """A crashed run is run again under gdb (a fake one here, which says
    how it was called and prints a stack)."""

    def setUp(self):
        import shutil
        import tempfile
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir)
        gdb = os.path.join(self.dir, 'gdb')
        with open(gdb, 'w') as f:
            f.write('#!/bin/sh\necho "args: $*"\necho "Thread 1 \\"x\\" received signal SIGSEGV, Segmentation fault."\n'
                    'echo "#0  0x1 in cef_initialize () from libcef.so"\necho "#1  0x2 in MCCefInitialise ()"\n'
                    'echo "unrelated"\n')
        os.chmod(gdb, 0o755)
        self.env = dict(os.environ)
        self.env['PATH'] = self.dir + os.pathsep + self.env.get('PATH', '')
        self.old_path = os.environ['PATH']
        os.environ['PATH'] = self.env['PATH']
        self.addCleanup(os.environ.__setitem__, 'PATH', self.old_path)

    def test_the_stack_is_kept(self):
        lines = bcc.crash_trace([], ['/x/engine', 'probe.livecodescript'], self.dir, self.env, 10)
        self.assertEqual(lines, ['  Thread 1 "x" received signal SIGSEGV, Segmentation fault.',
                                 '  #0  0x1 in cef_initialize () from libcef.so',
                                 '  #1  0x2 in MCCefInitialise ()'])


class Probe(unittest.TestCase):
    def test_the_probe_reads_what_the_driver_sets(self):
        with open(PROBE, encoding='utf-8') as f:
            script = f.read()
        for name in ('OXT_COMPAT_LOG', 'OXT_COMPAT_WHAT', 'OXT_COMPAT_BASE', 'OXT_COMPAT_EXTENSIONS',
                     'OXT_COMPAT_REVBROWSER'):
            self.assertIn(name, script)
        with open(bcc.__file__, encoding='utf-8') as f:
            driver = f.read()
        for name in re.findall(r'\$(OXT_COMPAT_\w+)', script):
            self.assertIn(name, driver)

    def test_the_probe_writes_done(self):
        with open(PROBE, encoding='utf-8') as f:
            self.assertIn('"DONE"', f.read())


class Workflow(unittest.TestCase):
    def test_the_linux_package_job_runs_it_on_x86_64(self):
        with open(WORKFLOW, encoding='utf-8') as f:
            text = f.read()
        m = re.search(r"- name: Browser compatibility check[^\n]*\n(.*?)(?=\n      - name:|\Z)", text, re.S)
        self.assertIsNotNone(m, 'no "Browser compatibility check" step in build-linux.yml')
        step = m.group(1)
        self.assertIn("matrix.arch == 'x86_64'", step)
        self.assertIn('tools/ci/browser_compat_check.py --install "$OXT_ROOT"', step)


if __name__ == '__main__':
    unittest.main()
