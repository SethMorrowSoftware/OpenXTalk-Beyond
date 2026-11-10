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

"""Compare two runs of the engine tests: what each test printed, not only
whether it passed.

  python3 tools/ci/compare_test_output.py BEFORE AFTER [--title TEXT]
      [--fail-on-difference]

BEFORE and AFTER are files that tools/ci/run_engine_tests.py --output
wrote, usually from two builds (the released one and the changed one) run
on the same tests. CLAUDE.md asks that a change that could alter what a
script sees run the scripts it touches before and after it and compare
the results; a test's diagnostics (TestDiagnostic) carry what a script
would see, such as an error text, so a difference there is a difference
for scripts even where both runs pass.

The report, in Markdown, goes to standard output and, in GitHub Actions,
to the job's summary. It lists each test whose result or output differs,
with the lines that differ, and the tests that only one run has. The
exit status is 0 unless --fail-on-difference is given and something
differs.
"""

import argparse
import difflib
import os
import re
import sys

HEADER = re.compile(r'^### TEST (\S+) (.+)$')


def parse(text):
    """{test: (outcome, [lines])}, in the order of the file."""
    tests = {}
    current = None
    for line in text.splitlines():
        m = HEADER.match(line)
        if m:
            current = m.group(2)
            tests[current] = (m.group(1), [])
        elif current is not None:
            tests[current][1].append(line.rstrip())
    return tests


def compare(before, after):
    """[(test, kind, detail lines)] for each difference: kind is "only
    before", "only after", "result" or "output"."""
    out = []
    for test in list(before) + [t for t in after if t not in before]:
        if test not in after:
            out.append((test, 'only before', []))
            continue
        if test not in before:
            out.append((test, 'only after', []))
            continue
        (b_outcome, b_lines), (a_outcome, a_lines) = before[test], after[test]
        diff = [d for d in difflib.unified_diff(b_lines, a_lines, 'before', 'after', lineterm='', n=0)
                if not d.startswith(('---', '+++', '@@'))]
        if b_outcome != a_outcome:
            out.append((test, 'result', ['%s -> %s' % (b_outcome, a_outcome)] + diff))
        elif diff:
            out.append((test, 'output', diff))
    return out


def report(title, before_path, after_path, before, after, differences):
    md = ['### %s' % title, '',
          'Before: `%s` (%d tests). After: `%s` (%d tests).' % (
              before_path, len(before), after_path, len(after)), '']
    if not differences:
        md.append('No test\'s result or output differs.')
        return '\n'.join(md)
    md.append('%d test(s) differ:' % len(differences))
    md.append('')
    md.append('```text')
    for test, kind, lines in differences:
        md.append('%s (%s)' % (test, kind))
        md.extend('    ' + x for x in lines)
    md.append('```')
    return '\n'.join(md)


def main(argv=None):
    ap = argparse.ArgumentParser(description='Compare two runs of the engine tests (run_engine_tests.py --output).')
    ap.add_argument('before')
    ap.add_argument('after')
    ap.add_argument('--title', default='Engine tests before and after')
    ap.add_argument('--fail-on-difference', action='store_true')
    args = ap.parse_args(argv)
    with open(args.before, encoding='utf-8', errors='replace') as f:
        before = parse(f.read())
    with open(args.after, encoding='utf-8', errors='replace') as f:
        after = parse(f.read())
    differences = compare(before, after)
    md = report(args.title, args.before, args.after, before, after, differences)
    print(md)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8', newline='\n') as f:
            f.write(md + '\n')
    return 1 if differences and args.fail_on_difference else 0


if __name__ == '__main__':
    sys.exit(main())
