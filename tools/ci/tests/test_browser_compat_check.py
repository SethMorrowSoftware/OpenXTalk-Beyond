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


# The fake gdb, readelf and addr2line are shell scripts; the trace is
# Linux's (the check runs gdb only there)
@unittest.skipIf(os.name == 'nt', 'fake tools as shell scripts')
class CrashTrace(unittest.TestCase):
    """A crashed run is run again under gdb (a fake one here, which writes
    its arguments to a file and prints what gdb would)."""

    def setUp(self):
        import shutil
        import tempfile
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir)
        gdb = os.path.join(self.dir, 'gdb')
        with open(gdb, 'w') as f:
            f.write('#!/bin/sh\nfor a in "$@"; do printf "%%s\\n" "$a"; done > "%s"\n'
                    'echo "CALL cef_api_hash"\necho "CALL cef_execute_process"\necho "CALL cef_initialize"\n'
                    'echo "CALL cef_do_message_loop_work"\necho "CALL cef_do_message_loop_work"\n'
                    'echo "CALL cef_browser_host_create_browser_sync"\n'
                    'echo "Thread 1 \\"x\\" received signal SIGSEGV, Segmentation fault."\n'
                    'echo "#0  0x1 in ?? () from libcef.so"\necho "#1  0x2 in MCCefInitialise ()"\n'
                    'echo "=> 0x7fffe650dc39:\tmov (%%rax),%%rdx"\necho "rip            0x7fffe650dc39      0x7fffe650dc39"\n'
                    'echo "0x00007fffd0000000  0x00007fffe8000000  Yes (*)     /x/Externals/CEF/libcef.so"\n'
                    'echo "unrelated"\n' % os.path.join(self.dir, 'args.txt'))
        os.chmod(gdb, 0o755)
        self.env = dict(os.environ)
        self.env['PATH'] = self.dir + os.pathsep + self.env.get('PATH', '')
        old = os.environ['PATH']
        os.environ['PATH'] = self.env['PATH']
        self.addCleanup(os.environ.__setitem__, 'PATH', old)

    def test_the_calls_the_stack_and_where_libcef_is(self):
        lines = bcc.crash_trace([], ['/x/engine', 'probe.livecodescript'], self.dir, self.env, 10)
        self.assertEqual(lines, ['  CALL cef_api_hash', '  CALL cef_execute_process', '  CALL cef_initialize',
                                 '  CALL cef_do_message_loop_work (x2)',
                                 '  CALL cef_browser_host_create_browser_sync',
                                 '  Thread 1 "x" received signal SIGSEGV, Segmentation fault.',
                                 '  #0  0x1 in ?? () from libcef.so',
                                 '  #1  0x2 in MCCefInitialise ()',
                                 '  => 0x7fffe650dc39:\tmov (%rax),%rdx',
                                 '  rip            0x7fffe650dc39      0x7fffe650dc39',
                                 '  0x00007fffd0000000  0x00007fffe8000000  Yes (*)     /x/Externals/CEF/libcef.so'])

    def test_gdb_is_asked_for_each_traced_call_then_runs_the_engine(self):
        bcc.crash_trace([], ['/x/engine', 'probe.livecodescript'], self.dir, self.env, 10)
        with open(os.path.join(self.dir, 'args.txt')) as f:
            args = f.read().splitlines()
        for name in bcc.TRACED_CEF_CALLS:
            self.assertIn('dprintf %s,"CALL %s\\n"' % (name, name), args)
        self.assertLess(args.index('set breakpoint pending on'), args.index('run'))
        self.assertEqual(args[-3:], ['--args', '/x/engine', 'probe.livecodescript'])


    def test_the_frames_in_libcef_are_named_from_its_symbols(self):
        from unittest import mock
        seen = []

        def symbolize(dbg, text_start, pcs):
            seen.append((dbg, text_start, pcs))
            return ['at 0x10:', '    cef::Thing()', '    cef/libcef/x.cc:12']
        env = {'OXT_COMPAT_CEF_SYMBOLS': '1'}
        with mock.patch.dict(os.environ, env), \
                mock.patch.object(bcc, 'cef_symbols', lambda cwd: ('/s/libcef.so.dbg', 'from here (9 MB)')), \
                mock.patch.object(bcc, 'symbolize', symbolize):
            lines = bcc.crash_trace([], ['/x/engine', 'probe.livecodescript'], self.dir, self.env, 10)
        # the frame in libcef and the instruction at the crash, each once
        self.assertEqual(seen, [('/s/libcef.so.dbg', 0x7fffd0000000, [0x1, 0x7fffe650dc39])])
        self.assertEqual(lines[-4:], ["  libcef's symbols: from here (9 MB)", '  at 0x10:',
                                      '      cef::Thing()', '      cef/libcef/x.cc:12'])

    def test_no_symbols_unless_asked(self):
        from unittest import mock
        with mock.patch.dict(os.environ, {'OXT_COMPAT_CEF_SYMBOLS': '0'}), \
                mock.patch.object(bcc, 'cef_symbols', lambda cwd: self.fail('fetched')):
            lines = bcc.crash_trace([], ['/x/engine', 'probe.livecodescript'], self.dir, self.env, 10)
        self.assertFalse([x for x in lines if 'symbols' in x])


# The fake gdb, readelf and addr2line are shell scripts; the trace is
# Linux's (the check runs gdb only there)
@unittest.skipIf(os.name == 'nt', 'fake tools as shell scripts')
class Symbolize(unittest.TestCase):
    """The pcs are moved from where libcef's .text was loaded to where the
    symbols put it (fake readelf and addr2line here)."""

    def test_addresses_move_to_the_symbols_text(self):
        import tempfile
        from unittest import mock
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'readelf'), 'w') as f:
                f.write('#!/bin/sh\necho "  [15] .text  NOBITS  0000000003000000 001000 ..."\n')
            with open(os.path.join(d, 'addr2line'), 'w') as f:
                f.write('#!/bin/sh\nprintf "%%s\\n" "$@" > "%s"\n'
                        'printf "0x0000000003000010\\nInner()\\n/b/src/cef/libcef/a.cc:3\\n'
                        'Outer()\\n/b/src/base/b.cc:9\\n"\n' % os.path.join(d, 'args'))
            for x in ('readelf', 'addr2line'):
                os.chmod(os.path.join(d, x), 0o755)
            with mock.patch.dict(os.environ, {'PATH': d + os.pathsep + os.environ['PATH']}):
                lines = bcc.symbolize('/s/libcef.so.dbg', 0x7fff00000000, [0x7fff00000010, 0x7fff00000020])
            with open(os.path.join(d, 'args')) as f:
                args = f.read().splitlines()
        self.assertEqual(args[-2:], ['0x3000010', '0x3000020'])
        self.assertIn('/s/libcef.so.dbg', args)
        self.assertEqual(lines, ['at 0x0000000003000010:', '    Inner()', '    cef/libcef/a.cc:3',
                                 '    Outer()', '    base/b.cc:9'])


class CefSymbols(unittest.TestCase):
    def test_the_symbols_of_the_cef_in_prebuilt(self):
        import tempfile
        import urllib.request
        from unittest import mock
        seen = []

        def refuse(url, timeout=None):
            seen.append(url)
            raise OSError('refused')
        with tempfile.TemporaryDirectory() as d, mock.patch.object(urllib.request, 'urlopen', refuse):
            dbg, note = bcc.cef_symbols(d)
        self.assertIsNone(dbg)
        self.assertIn('OSError: refused', note)
        def version(name):
            with open(os.path.join(bcc.REPO, 'prebuilt', 'versions', name)) as f:
                return f.read().strip()
        self.assertEqual(seen, ['https://cef-builds.spotifycdn.com/cef_binary_%s%%2B%s%%2Bchromium-%s'
                                '_linux64_release_symbols.tar.bz2'
                                % (version('cef'), version('cef_buildrevision'), version('cefchromium'))])


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
