#!/usr/bin/env python3
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

"""Engine tests under valgrind's memcheck, on Linux: for a fix of a use of
freed memory, which need not crash, so that a test that passes can still
be wrong. The first were the tests of the crash of the Script Editor's
Breakpoints pane (mwieder and tperry2x, openxtalk.org, October 2026): a
control freed under its own message when a script deleted its group. On
0.2.7-rc.6.9 they pass as tests, and memcheck reports an invalid read and
an invalid write in each.

  python3 tools/ci/memcheck_tests.py --bin DIR [--log FILE] [--timeout S]
      FILE:HANDLER...

FILE is a test file under tests/lcs (core/interface/delete.livecodescript)
and HANDLER one of its tests (TestDeleteGroupOfTarget). Each runs as
tools/ci/run_engine_tests.py runs it (the build's standalone engine, -ui,
tests/_testrunner.livecodescript invoke), under valgrind --tool=memcheck.
A test fails when it fails as a test (a "not ok" line, no "ok" line, or
an exit status other than 0) or when memcheck reports a use of memory that
is freed or was never the program's: an invalid read, write or free. Its
other reports (the engine's own mismatched new and free, which predate
this) are listed and not counted. Exit status 0 when every test is clean,
1 when one is not, 2 when the check cannot run (no valgrind, no engine).
Only the Python 3 standard library is used.
"""

import argparse
import os
import re
import shutil
import sys
import tempfile

CI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import run_engine_tests  # noqa: E402

# The reports that are a use of freed or foreign memory, as memcheck words
# their first line (after the ==pid== prefix)
COUNTED = re.compile(r'^(Invalid (read|write) of size \d+|Invalid free\(\) / delete / delete\[\] / realloc\(\))')

# The first line of any report, which ends the one before
REPORT = re.compile(r'^==\d+== (\S.*)$')


def memcheck_reports(text):
    """memcheck's reports in its log text: a list of (first line, whole
    report), the ==pid== prefixes taken off."""
    reports = []
    current = None
    for line in text.splitlines():
        m = re.match(r'^==\d+==( ?)(.*)$', line)
        if not m:
            continue
        body = m.group(2)
        if not body.strip():
            current = None
            continue
        if m.group(1) == ' ' and not body.startswith(' '):
            current = [body]
            reports.append(current)
        elif current is not None:
            current.append(body)
    return [(lines[0], '\n'.join(lines)) for lines in reports]


def counted(reports):
    """The reports that are a use of freed or foreign memory."""
    return [r for r in reports if COUNTED.match(r[0])]


def test_failed(status, out):
    """Whether the test failed as a test: its exit status, no "ok" line, or
    a "not ok" line (other than an expected failure, "# TODO")."""
    lines = out.splitlines()
    if status != 0:
        return True
    if not any(l.startswith('ok') for l in lines):
        return True
    return any(l.startswith('not ok') and '# TODO' not in l for l in lines)


def why_not_run(vg_text, err, count=12):
    """The lines that say why a test gave no output: valgrind's own (its
    log's lines that are not part of a report, such as "valgrind: ... No
    such file or directory") and the last of the engine's stderr."""
    lines = [l for l in vg_text.splitlines() if l.strip() and not re.match(r'^==\d+==', l)]
    lines += [l for l in err.splitlines() if l.strip()][-count:]
    return lines[:count * 2]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0],
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--bin', required=True, help='the build output (linux-<arch>-bin)')
    parser.add_argument('--log', help='write every test\'s output and memcheck\'s log here')
    parser.add_argument('--timeout', type=int, default=900, help='seconds for each test (default: 900)')
    parser.add_argument('tests', nargs='+', metavar='FILE:HANDLER')
    args = parser.parse_args(argv)

    valgrind = shutil.which('valgrind')
    if valgrind is None:
        print('memcheck: valgrind is not installed')
        return 2
    try:
        # (absolute, as run_engine_tests.py makes it: the tests run in
        # tests/, where a relative path such as CI's linux-x86_64-bin
        # names nothing, and valgrind stopped at once)
        tools = run_engine_tests.tools_in(os.path.abspath(args.bin), 'linux')
    except run_engine_tests.SuiteError as e:
        print('memcheck: %s' % e)
        return 2

    tests_dir = os.path.join(REPO, 'tests')
    runner = run_engine_tests.lc_path(os.path.join(tests_dir, '_testrunner.livecodescript'))
    env = run_engine_tests.child_env()
    env['HOME'] = tempfile.mkdtemp(prefix='memcheck-home-')
    log_lines = []
    bad = 0
    for test in args.tests:
        path, sep, name = test.rpartition(':')
        if not sep or not path or not name:
            print('memcheck: %s is not FILE:HANDLER' % test)
            return 2
        full = os.path.join(tests_dir, 'lcs', path)
        if not os.path.isfile(full):
            print('memcheck: no test file %s' % full)
            return 2
        with tempfile.NamedTemporaryFile(prefix='memcheck-', suffix='.txt', delete=False) as f:
            vg_log = f.name
        cmd = [valgrind, '--tool=memcheck', '-q', '--error-limit=no', '--log-file=' + vg_log,
               tools['engine'], '-ui', runner, 'invoke', run_engine_tests.lc_path(full), name]
        status, out, err = run_engine_tests.run_process(cmd, tests_dir, env, args.timeout)
        with open(vg_log, encoding='utf-8', errors='replace') as f:
            vg_text = f.read()
        os.unlink(vg_log)
        reports = memcheck_reports(vg_text)
        uses = counted(reports)
        failed = test_failed(status, out)
        others = [r[0] for r in reports if r not in uses]
        verdict = 'FAIL' if failed or uses else 'PASS'
        if verdict == 'FAIL':
            bad += 1
        print('%s  %s:%s  (%s; %d use(s) of freed or foreign memory%s)' % (
            verdict, path, name,
            'timed out' if status is None else
            ('test failed' if failed else 'test passed'),
            len(uses),
            '; also: ' + ', '.join(sorted(set(others))) if others else ''))
        # (the first lines of each: where it was used, and where freed)
        for first, whole in uses[:4]:
            print('      ' + '\n      '.join(whole.split('\n')[:16]))
        if failed:
            for line in out.splitlines():
                if line.startswith('not ok') or line.startswith('#'):
                    print('      ' + line)
            if not any(l.startswith('ok') or l.startswith('not ok') for l in out.splitlines()):
                # the test never ran: why, from valgrind and the engine
                print('      no test output; exit status %s' % status)
                for line in why_not_run(vg_text, err):
                    print('      ' + line)
        log_lines += ['== %s:%s (exit status %s)' % (path, name, status), out, err,
                      '-- memcheck', vg_text]
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write('\n'.join(log_lines))
    print('%d test(s) under memcheck, %d with a failure' % (len(args.tests), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
