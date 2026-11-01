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

"""Keeps the web IDE open in a headless browser for a while and records how
much memory and processor it takes: a check for what makes a browser give
up on the page (Safari reloads a page whose web process it kills).

  python3 tools/ci/web_ide_soak.py --site DIR --out DIR
      [--browser chromium|firefox|webkit] [--minutes N]

--site is the web IDE's site (index.html, the engine and ide.zip), served
as it is on 127.0.0.1 and opened at 1400 x 900. Once the IDE has opened,
the page stays open for --minutes (default 5) with Home, the IDE's
animated welcome stack, in front: every 20 seconds the script clicks
Home's title bar and presses the right arrow key, which turns Home's page,
so that each of its pages (the bouncing balls, the drawing, ...) runs for
a while.

Every 2 seconds it writes a line to <out>/memory.csv: the seconds since
the IDE opened, the resident memory of the browser's largest web content
process (MB), the processor time that process took since the last line
(percent of one core), and the engine's WebAssembly memory (MB). The
process is found by its command line (Chromium's renderer, WebKit's
WebKitWebProcess or WPEWebProcess, Firefox's content process), on Linux
and macOS; on Windows the process columns are empty.

Every 30 seconds the log has a line with the latest numbers, so that a
run that ends badly shows how it got there. The page is asked for its
numbers with a time limit: a page whose engine keeps the browser's main
thread busy does not answer, and the script would wait for it for ever.

The check fails when the IDE does not open, the page reports an error of
its own (a JavaScript error, or the engine stopping), the browser's web
process crashes, the page loads itself again, or the page does not answer
for --unresponsive seconds (default 60). It does not fail on the numbers,
which it reports (start, peak, end, and the growth after the first
minute) in the log and, under GitHub Actions, in the job summary: what a
browser tolerates differs from one device to the next.

Exit status 0 when the check passes, 1 otherwise. Needs Python 3.8 or
later and the Python package playwright with the browser
(python3 -m playwright install <browser>).
"""

import argparse
import functools
import http.server
import os
import shutil
import subprocess
import sys
import threading
import time

WIDTH, HEIGHT = 1400, 900

# What the page shows while the IDE loads, and when it fails
# (tools/web-ide/index.html)
OPENED = "document.getElementById('loading').style.display === 'none'"
FAILED = "document.getElementById('error').style.display === 'block'"

# The engine's WebAssembly memory, in bytes (HEAPU8 is exported:
# util/emscripten-javascriptify.py)
HEAP = "(window.Module && Module.HEAPU8) ? Module.HEAPU8.length : 0"

# A browser's web content processes, by their command line (Playwright's
# WebKit on Linux is the WPE port, whose process is WPEWebProcess)
PROCESSES = {
    'chromium': ('--type=renderer',),
    'webkit': ('WebKitWebProcess', 'WPEWebProcess'),
    'firefox': ('-contentproc',),
}

SAMPLE = 2
TURN = 20
REPORT = 30


def log(text):
    print(text, flush=True)


def annotate(kind, text):
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        print('::%s title=Web IDE soak::%s' % (kind, text.replace('\n', ' ')), flush=True)


def serve(folder):
    class Handler(http.server.SimpleHTTPRequestHandler):
        extensions_map = dict(http.server.SimpleHTTPRequestHandler.extensions_map,
                              **{'.wasm': 'application/wasm', '.js': 'text/javascript'})

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0),
                                             functools.partial(Handler, directory=folder))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def ask(page, expression, seconds):
    """The value of a JavaScript expression in the page, or None if the
    page does not answer within seconds. (page.evaluate() has no time
    limit; page.wait_for_function() has, and returns the value.)"""
    try:
        handle = page.wait_for_function('() => ({value: %s})' % expression, timeout=seconds * 1000)
    except Exception as e:  # noqa: BLE001 - a time-out, or a page that went away
        if type(e).__name__ == 'TimeoutError':
            return None
        raise
    return handle.json_value()['value']


def ticks_per_second():
    try:
        return os.sysconf('SC_CLK_TCK')
    except (AttributeError, ValueError, OSError):
        return 100


def web_process(browser):
    """(pid, resident MB) of the browser's largest web content process, or
    None where ps cannot say."""
    if os.name == 'nt':
        return None
    try:
        text = subprocess.run(['ps', '-axo', 'pid=,rss=,args='], capture_output=True,
                              text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    best = None
    for line in text.splitlines():
        fields = line.split(None, 2)
        if (len(fields) == 3 and fields[1].isdigit()
                and any(name in fields[2] for name in PROCESSES[browser])):
            found = (int(fields[0]), int(fields[1]) / 1024.0)
            if best is None or found[1] > best[1]:
                best = found
    return best


def cpu_seconds(pid):
    """The processor time a process has taken (Linux), or None."""
    try:
        with open('/proc/%d/stat' % pid) as f:
            fields = f.read().rsplit(')', 1)[1].split()
        return (int(fields[11]) + int(fields[12])) / float(ticks_per_second())
    except (OSError, ValueError, IndexError):
        return None


def summary(browser, problems, report):
    path = os.environ.get('GITHUB_STEP_SUMMARY')
    if not path:
        return
    with open(path, 'a', encoding='utf-8') as f:
        f.write('### Web IDE soak (%s)\n\n' % browser)
        f.write('%s.\n\n' % ('Passed' if not problems else 'Failed'))
        for p in problems:
            f.write('- %s\n' % p.replace('\n', ' '))
        if problems:
            f.write('\n')
        if report:
            f.write('```\n%s\n```\n\n' % '\n'.join(report))


def describe(samples):
    """Lines that sum up the samples [(seconds, rss, cpu, heap)]."""
    lines = []
    for index, name in ((1, 'web process, resident MB'), (3, 'WebAssembly memory, MB')):
        values = [(s[0], s[index]) for s in samples if s[index] is not None]
        if not values:
            lines.append('%s: not measured' % name)
            continue
        after = [v for v in values if v[0] >= 60] or values
        growth = (after[-1][1] - after[0][1]) / max(1.0, (after[-1][0] - after[0][0]) / 60.0)
        lines.append('%s: %.0f at the start, %.0f at most, %.0f at the end; %+.1f a minute after the first minute'
                     % (name, values[0][1], max(v[1] for v in values), values[-1][1], growth))
    cpu = [s[2] for s in samples if s[2] is not None]
    if cpu:
        lines.append('web process, processor: %.0f%% of a core on average, %.0f%% at most'
                     % (sum(cpu) / len(cpu), max(cpu)))
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--site', required=True, help='the web IDE site (build_site.py --out)')
    ap.add_argument('--out', required=True, help='the folder for the record (replaced)')
    ap.add_argument('--browser', default='chromium', choices=sorted(PROCESSES),
                    help='the browser (Playwright\'s build)')
    ap.add_argument('--minutes', type=float, default=5, help='how long the page stays open')
    ap.add_argument('--timeout', type=float, default=300, help='seconds for the IDE to open')
    ap.add_argument('--unresponsive', type=float, default=60,
                    help='seconds the page may go without answering')
    args = ap.parse_args()

    from playwright.sync_api import sync_playwright

    site = os.path.abspath(args.site)
    if not os.path.isfile(os.path.join(site, 'ide.zip')):
        raise SystemExit('error: %s has no ide.zip: is it a web IDE site?' % site)
    out = os.path.abspath(args.out)
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    server = serve(site)
    url = 'http://127.0.0.1:%d/' % server.server_address[1]
    log('Site   : %s' % site)
    log('Page   : %s' % url)
    log('Browser: %s, %g minutes' % (args.browser, args.minutes))

    problems, samples = [], []
    started = time.time()
    console = open(os.path.join(out, 'console.txt'), 'w', encoding='utf-8')
    csv = open(os.path.join(out, 'memory.csv'), 'w', encoding='utf-8')
    csv.write('seconds,web_process_mb,web_process_cpu_percent,wasm_memory_mb\n')

    def stamp():
        return '%7.1f' % (time.time() - started)

    with sync_playwright() as p:
        browser = getattr(p, args.browser).launch()
        page = browser.new_page(viewport={'width': WIDTH, 'height': HEIGHT})
        # A click or a wait gives up rather than waiting for ever
        page.set_default_timeout(30000)
        page.on('console', lambda m: console.write('%s %s %s\n' % (stamp(), m.type, m.text)))
        state = {'opened': False, 'crashed': False, 'loads': 0}

        def page_error(error):
            console.write('%s PAGE ERROR %s\n' % (stamp(), error))
            problems.append('page error: %s' % error)

        def crashed(_page):
            console.write('%s CRASH\n' % stamp())
            state['crashed'] = True

        def navigated(frame):
            if frame == page.main_frame:
                state['loads'] += 1
                console.write('%s LOAD %s\n' % (stamp(), frame.url))
        page.on('pageerror', page_error)
        page.on('crash', crashed)
        page.on('framenavigated', navigated)
        try:
            page.goto(url)
            page.wait_for_function('%s || %s' % (OPENED, FAILED), timeout=args.timeout * 1000)
            status = ask(page, '%s ? document.getElementById("error").textContent : ""' % FAILED, 30)
            if status:
                raise RuntimeError('the IDE did not open: %s' % status)
            state['opened'] = True
            loads = state['loads']
            log('%s the IDE opened' % stamp())
            note = page.locator('#note button')
            if note.is_visible():
                note.click()

            opened = time.time()
            last_cpu = None
            last_answer = opened
            next_turn = opened + TURN
            next_report = opened + REPORT
            while time.time() - opened < args.minutes * 60:
                time.sleep(SAMPLE)
                if state['crashed']:
                    raise RuntimeError('the browser\'s web process crashed')
                if state['loads'] != loads:
                    raise RuntimeError('the page loaded itself again')
                answer = ask(page, '[%s ? document.getElementById("error").textContent : null, %s]'
                             % (FAILED, HEAP), SAMPLE)
                now = time.time()
                if answer is None:
                    heap = None
                    console.write('%s NO ANSWER\n' % stamp())
                    if now - last_answer > args.unresponsive:
                        raise RuntimeError('the page did not answer for %d seconds' % (now - last_answer))
                else:
                    last_answer = now
                    if answer[0] is not None:
                        raise RuntimeError('the page reported: %s' % answer[0])
                    heap = answer[1] / 1048576.0 or None
                found = web_process(args.browser)
                rss = cpu = None
                if found:
                    rss = found[1]
                    seconds = cpu_seconds(found[0])
                    if seconds is not None and last_cpu and last_cpu[0] == found[0]:
                        cpu = 100.0 * (seconds - last_cpu[1]) / max(0.001, now - last_cpu[2])
                    last_cpu = (found[0], seconds, now) if seconds is not None else None
                sample = (round(now - opened, 1), rss, cpu, heap)
                samples.append(sample)
                csv.write(','.join('' if v is None else ('%.1f' % v) for v in sample) + '\n')
                csv.flush()
                if now >= next_report:
                    next_report = now + REPORT
                    log('%s web process %s MB, %s%% of a core; WebAssembly memory %s MB'
                        % (stamp(), '?' if rss is None else '%.0f' % rss,
                           '?' if cpu is None else '%.0f' % cpu,
                           'no answer' if heap is None else '%.0f' % heap))
                if answer is not None and now >= next_turn:
                    next_turn = now + TURN
                    # Home's title bar is the page's own element
                    # (engine/src/em-dc.js): a click there brings Home to
                    # the front and does nothing else
                    # (OXT-Beyond Home, from 0.2.7-rc.6.12; Home's own
                    # window, titled Welcome to OXT-Beyond, before it)
                    title = page.locator('.oxt-window-title', has_text='OXT-Beyond Home')
                    if title.count() == 0:
                        title = page.locator('.oxt-window-title', has_text='Welcome to OXT-Beyond')
                    if title.count() > 0 and title.first.is_visible():
                        title.first.click()
                        page.keyboard.press('ArrowRight')
                        console.write('%s TURN\n' % stamp())
            page.screenshot(path=os.path.join(out, 'last.png'))
        except Exception as e:  # noqa: BLE001 - every failure is reported
            problems.append('%s: %s' % (type(e).__name__, str(e).splitlines()[0] if str(e) else ''))
            try:
                page.screenshot(path=os.path.join(out, 'failure.png'))
            except Exception:  # noqa: BLE001
                pass
        finally:
            browser.close()
            server.shutdown()
            console.close()
            csv.close()

    report = describe(samples)
    for line in report:
        log(line)
    summary(args.browser, problems, report)
    if problems:
        # The page's last words, where the job's log shows them
        with open(os.path.join(out, 'console.txt'), encoding='utf-8', errors='replace') as f:
            tail = f.read().splitlines()[-40:]
        if tail:
            log('The console\'s last %d lines:' % len(tail))
            for line in tail:
                log('  ' + line[:300])
    for problem in problems:
        log('FAILED: %s' % problem)
        annotate('error', problem)
    if not problems:
        log('Passed')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
