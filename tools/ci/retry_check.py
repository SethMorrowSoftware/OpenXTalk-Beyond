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

"""Run a check, and run it again if it fails, at most a given number of
times in all, keeping the files of every try.

  python3 tools/ci/retry_check.py [--tries N] [--files DIR] [--what TEXT]
      -- COMMAND [ARG]...

The CI's checks in headless WebKit fail now and then where the same
check passes in Chromium and Firefox, and in WebKit on the next run: the
page crashes, a page opened beside it is closed under the check
(tools/ci/web_check.py), or a computation in the page comes out wrong
(the web IDE's xTalk Suite check). The workflows run those checks through
this with --tries 2 in WebKit, and --tries 1, a single run as before, in
the other browsers.

COMMAND runs at most --tries times (default 2), until it exits with
status 0. --files is the folder COMMAND writes its files to, which the
job uploads: before another try, the folder is moved aside, so that each
try starts without the last one's files, and when the last try has ended
each earlier try's folder is moved into it as try-1, try-2, ... A try
that fails and is followed by another, and a check that passes only on a
later try, each give a warning (an annotation under GitHub Actions, and
a line in the job summary), so that the flake stays in sight. --what
names the check in them (default: COMMAND's file name).

Exit status: the last try's (128 + the signal's number for a try that a
signal ended), or 2 when the options are wrong.

Only the Python 3 standard library is used.
"""

import argparse
import os
import shutil
import subprocess
import sys


def log(text):
    print(text, flush=True)


def warn(text):
    """A warning in the log, as an annotation under GitHub Actions, and
    in the job summary."""
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        log('::warning::' + text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A'))
    else:
        log('warning: ' + text)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('- %s\n' % text)


def aside(files, tried):
    """Where try number <tried>'s folder waits for the next try to end."""
    return '%s.try-%d' % (os.path.normpath(files), tried)


def run(command):
    """COMMAND's exit status, 128 + the signal's number for one that a
    signal ended."""
    try:
        status = subprocess.call(command)
    except OSError as e:
        log('could not run %s: %s' % (command[0], e))
        return 127
    return 128 - status if status < 0 else status


def retry(command, tries=2, files=None, what=None):
    what = what or os.path.basename(command[0])
    statuses = []
    for tried in range(1, tries + 1):
        if tried > 1:
            log('%s, try %d of %d' % (what, tried, tries))
        status = run(command)
        statuses.append(status)
        if status == 0:
            break
        if tried < tries:
            kept = ''
            if files and os.path.exists(files):
                shutil.move(files, aside(files, tried))
                kept = "; its files will be in try-%d of %s" % (tried, os.path.basename(os.path.normpath(files)))
            warn('%s failed on try %d of %d (exit status %d) and runs again%s'
                 % (what, tried, tries, status, kept))

    # Every earlier try's files, into the last one's folder
    if files:
        for tried in range(1, len(statuses)):
            if os.path.exists(aside(files, tried)):
                os.makedirs(files, exist_ok=True)
                shutil.move(aside(files, tried), os.path.join(files, 'try-%d' % tried))

    if statuses[-1] == 0 and len(statuses) > 1:
        warn('%s passed on try %d of %d after failing (exit status %s): a flake, or a problem '
             'that comes and goes' % (what, len(statuses), tries,
                                       ', '.join(str(s) for s in statuses[:-1])))
    return statuses[-1]


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if '--' not in argv:
        print('usage: retry_check.py [--tries N] [--files DIR] [--what TEXT] -- COMMAND [ARG]...',
              file=sys.stderr)
        return 2
    split = argv.index('--')
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--tries', type=int, default=2, help='how many times COMMAND runs at most (default 2)')
    ap.add_argument('--files', help='the folder COMMAND writes its files to')
    ap.add_argument('--what', help='the check\'s name in the warnings')
    args = ap.parse_args(argv[:split])
    command = argv[split + 1:]
    if not command or args.tries < 1:
        ap.print_usage(sys.stderr)
        return 2
    return retry(command, args.tries, args.files, args.what)


if __name__ == '__main__':
    sys.exit(main())
