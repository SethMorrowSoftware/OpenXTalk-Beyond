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

"""Run the Background Workers library's web workers in a headless browser.

  python3 tools/ci/web_workers_check.py --runtime DIR (--engine FILE | --engine-cache DIR)
      [--browser B] [--work DIR] [--timeout SECONDS] [--expect-unsupported]

A web standalone can start no process, so in a browser the Background
Workers library makes each worker a web worker of the page, which loads
the engine again with the standalone's files and runs it without a user
interface (extensions/script-libraries/worker/worker.livecodescript, "IN A
BROWSER"). This builds a web standalone of tools/ci/web-workers-probe.
livecodescript with that library and the Background Database library, as
tools/ci/web_check.py builds its probe without the IDE (--runtime: the web
runtime folder, and a development engine that runs
tools/ci/web-deploy.livecodescript, OXT_WEB_KIND "workers"), opens its page
in a headless browser, and checks that each of the probe's cases said ok:
starting workers, calls with numbers, binary data and arrays both ways,
errors, progress, output, waits and messages in a worker, two workers at
once, the page going on while a worker counts, stopping, a worker whose
script quits, a script that does not compile, and the Background Database
library's refusal in a browser.

--expect-unsupported is for a runtime from before web workers (an engine
that cannot run in a web worker): the probe's first worker must then fail
("worker failed"), and the rest is not checked.
"""

import argparse
import os
import shutil
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import web_check  # noqa: E402
from web_check import CheckError, log, annotate, summary  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
PROBE_SCRIPT = os.path.join(HERE, 'web-workers-probe.livecodescript')
LIBRARIES = (os.path.join(REPO, 'extensions', 'script-libraries', 'worker', 'worker.livecodescript'),
             os.path.join(REPO, 'extensions', 'script-libraries', 'asyncdatabase', 'asyncdatabase.livecodescript'))

# The probe's cases, in the order it runs them
CASES = ('start', 'first-call', 'binary', 'array-in', 'array-out', 'error', 'no-handler', 'progress',
         'output', 'where', 'files', 'wait', 'send', 'busy', 'parallel-1', 'parallel-2', 'workers',
         'stop', 'stopped-call', 'quit-call', 'after-quit', 'quit', 'script-error', 'database')

# The probe's measurements that the check reports
MEASURES = ('first-call-ms', 'busy-ms', 'second-worker-ms')


def run_page(url, browser_name, timeout, expect_unsupported):
    """Open url and gather the probe's lines; returns (problems, lines)."""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        raise CheckError('the Python package playwright is missing (pip install playwright, then '
                         'python3 -m playwright install chromium)')
    problems, lines = [], []
    probes, info, console, page_errors = {}, {}, [], []
    done = []

    def on_console(msg):
        text = msg.text
        console.append((msg.type, text))
        if text.startswith('PROBE '):
            log('  %s' % text)
            parts = text[6:].split(' ', 2) + ['', '']
            if parts[0] == 'done':
                done.append(parts[1])
            elif parts[1] == 'info':
                info[parts[0]] = parts[2]
            else:
                probes.setdefault(parts[0], []).append((parts[1], parts[2]))
        else:
            log('  console.%s: %s' % (msg.type, text))

    with sync_playwright() as pw:
        browser = getattr(pw, browser_name).launch()
        try:
            page = browser.new_page()
            page.on('console', on_console)
            page.on('pageerror', lambda e: (page_errors.append(str(e)), log('  page error: %s' % e)))
            page.goto(url)
            deadline = time.time() + timeout
            while not done and time.time() < deadline:
                if expect_unsupported and 'first-call' in probes:
                    break
                page.wait_for_timeout(250)
        finally:
            browser.close()

    if expect_unsupported:
        seen = probes.get('first-call')
        if not seen:
            problems.append('the probe\'s first call never ended')
        elif seen[0][0] == 'ok':
            problems.append('a worker ran, though this runtime was expected not to run one: %s' % seen[0][1])
        elif 'worker failed' not in seen[0][1] and 'worker stopped' not in seen[0][1]:
            problems.append('the first call failed in another way: %s' % seen[0][1])
        else:
            lines.append('as expected, no worker ran: %s' % seen[0][1])
        return problems, lines

    if not done:
        problems.append('the probe did not finish within %d seconds' % timeout)
    for case in CASES:
        seen = probes.get(case)
        if not seen:
            problems.append('%s: the probe did not report it' % case)
        elif len(seen) > 1:
            problems.append('%s: reported %d times: %s' % (case, len(seen), seen))
        elif seen[0][0] != 'ok':
            problems.append('%s: %s %s' % (case, seen[0][0], seen[0][1]))
        else:
            lines.append('%s: %s' % (case, seen[0][1]))
    for case, seen in sorted(probes.items()):
        if case not in CASES:
            problems.append('%s: a case this check does not know: %s' % (case, seen))
    for name in MEASURES:
        if name in info:
            lines.append('%s: %s' % (name, info[name]))
    for text in page_errors:
        problems.append('the page threw: %s' % text)
    return problems, lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--runtime', required=True, help='the web runtime folder')
    ap.add_argument('--engine', help='a development engine (LiveCode-Community)')
    ap.add_argument('--engine-cache', help='download the pinned development engine into this folder')
    ap.add_argument('--browser', choices=('chromium', 'firefox', 'webkit'), default='chromium',
                    help='the browser that opens the page (default chromium)')
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--timeout', type=int, default=180, help='seconds for each step (default 180)')
    ap.add_argument('--expect-unsupported', action='store_true',
                    help='the runtime is from before web workers: the first worker must fail')
    args = ap.parse_args(argv)
    if bool(args.engine) == bool(args.engine_cache):
        ap.error('pass one of --engine and --engine-cache')

    work = os.path.abspath(args.work) if args.work else tempfile.mkdtemp(prefix='oxt-web-workers-')
    os.makedirs(work, exist_ok=True)
    problems, lines = [], []
    server = None
    try:
        runtime = os.path.abspath(args.runtime)
        version, js, wasm, html = web_check.runtime_files(runtime)
        engine = (os.path.abspath(args.engine) if args.engine
                  else web_check.fetch_engine(os.path.abspath(args.engine_cache)))
        log('Deploying with %s' % engine)
        os.environ['OXT_WEB_LIBRARIES'] = '\n'.join(LIBRARIES)
        startup = web_check.deploy(engine, runtime, version, work, args.timeout, kind='workers',
                                   script=PROBE_SCRIPT)
        site = os.path.join(work, 'site')
        shutil.rmtree(site, ignore_errors=True)
        web_check.make_standalone(runtime, js, wasm, html, startup, site, title='Workers Probe')
        server = web_check.make_server(site)
        url = 'http://127.0.0.1:%d/%s.html' % (server.server_address[1], web_check.STACK_NAME)
        log('Opening %s' % url)
        p, l = run_page(url, args.browser, args.timeout, args.expect_unsupported)
        problems += p
        lines += l
    except CheckError as e:
        problems.append(str(e))
    finally:
        if server:
            server.shutdown()

    log()
    for line in lines:
        log('  ' + line)
    if problems:
        log('FAILED:')
        for problem in problems:
            log('  ' + problem)
            annotate('error', 'web workers check: ' + problem)
    else:
        log('PASSED')
    summary('### Web workers check (%s)\n\n' % args.browser + ''.join('- %s\n' % x for x in lines)
            + ('\n**Failed:**\n\n' + ''.join('- %s\n' % x for x in problems) if problems else '\nAll checks passed.\n')
            + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
