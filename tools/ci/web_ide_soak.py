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
Home's title bar and then Home's Next button, so that each of Home's pages
(the bouncing balls, the drawing, ...) runs for a while. (Until 0.2.8-dp.2
it pressed the right arrow key, which turned the page then; since #557 the
arrow keys turn no page, and Home's first page ran throughout.) Whether
the page turned is seen in Home's page header, compared before and after
the click: the log says how many tries turned the page, and the check
fails when fewer than half of the tries that could be seen did (a click
that misses Next), or when the page was never seen to turn (Home's first
page, whose header moves by itself, the only one shown throughout).

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
What has no time limit of its own in Playwright (finding Home's title
bar, a mouse click, closing the browser) runs under a watchdog, which ends
the check when one of them takes longer than --unresponsive seconds: on
main 25a872e97 (2026-11-02) the soak in WebKit stopped after 355 seconds
and waited until the job's limit ended it.

The check fails when the IDE does not open, the page reports an error of
its own (a JavaScript error, or the engine stopping), the browser's web
process crashes, the page loads itself again, or the page does not answer
for --unresponsive seconds (default 60), whether to the script's questions
or while the script turns Home's page. It does not fail on the numbers,
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

# Home's window, by its title: OXT-Beyond Home (from 0.2.7-rc.6.12), or
# Home's own window before it. With each, its sidebar's width and the
# middle of its Next button across, in CSS pixels from the left of the
# window's canvas, where a card pixel is a CSS pixel
# (ide/Toolset/palettes/web home/revwebhome.livecodescript: hmSide, and
# Next at tSide - 120 in hmBuildHostedSide, at 104 in hmBuildSide, at
# least 106 and 82 wide)
HOMES = (('OXT-Beyond Home', 248, 248 - 120 + 106 // 2),
         ('Welcome to OXT-Beyond', 200, 104 + 82 // 2))
# Home's pages are laid out for a window kWidth by kHeight with a kSide
# sidebar, and hmLayout moves them to the middle of the room right of the
# sidebar; Next, 32 high at 510, moves down with the window's foot, so its
# middle is always this far above the window's bottom
HOME_WIDTH, HOME_HEIGHT, HOME_SIDE = 1024, 640, 200
NEXT_ABOVE_BOTTOM = HOME_HEIGHT - (510 + 32 // 2)
# Every page's header (hdrTitle and hdrTag, 224,14 to 1000,70), which
# stands still on every page but the first, whose hero moves over it
HEADER = (224, 10, 1000, 70)
# Seconds between the two looks at the header before the click, between
# the looks after it, and the most a turn may take to show; the share of
# the header's pixels that may change on a page that stands still, and
# that a turn changes at least (in dp.2's web IDE a turn changed 7 to 8
# percent of it, and a turn to or from the first page, whose hero moves
# over it, 80 percent and more)
STILL_WAIT = 1
LOOK = 0.5
TURN_WAIT = 10
STILL, TURNED = 0.002, 0.02


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


def png_pixels(data):
    """(width, height, rows) of an 8-bit RGB or RGBA PNG that is not
    interlaced, as a browser's screenshot is, each row bytes of RGBA or
    RGB; None for any other PNG."""
    import struct
    import zlib
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    pos, head, chunks = 8, None, []
    while pos + 8 <= len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            head = struct.unpack('>IIBBBBB', body)
        elif kind == b'IDAT':
            chunks.append(body)
        elif kind == b'IEND':
            break
        pos += 12 + length
    if head is None or head[2] != 8 or head[3] not in (2, 6) or head[6] != 0:
        return None
    width, height = head[0], head[1]
    step = 3 if head[3] == 2 else 4
    stride = width * step
    try:
        raw = zlib.decompress(b''.join(chunks))
    except zlib.error:
        return None
    if len(raw) < height * (stride + 1):
        return None
    rows, prior = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind = raw[start]
        line = bytearray(raw[start + 1:start + 1 + stride])
        if kind == 1:
            for i in range(step, stride):
                line[i] = (line[i] + line[i - step]) & 255
        elif kind == 2:
            for i in range(stride):
                line[i] = (line[i] + prior[i]) & 255
        elif kind == 3:
            for i in range(stride):
                left = line[i - step] if i >= step else 0
                line[i] = (line[i] + ((left + prior[i]) >> 1)) & 255
        elif kind == 4:
            for i in range(stride):
                a = line[i - step] if i >= step else 0
                b = prior[i]
                c = prior[i - step] if i >= step else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        elif kind != 0:
            return None
        rows.append(bytes(line))
        prior = line
    return width, height, rows


def changed(before, after):
    """The share of the pixels that differ between two screenshots of the
    same place (by more than 32 in a colour, as a turn's and an
    animation's do and the browser's own small differences do not); 0 or
    1 when one of them is not a PNG png_pixels() reads."""
    if before == after:
        return 0.0
    a, b = png_pixels(before), png_pixels(after)
    if a is None or b is None or a[:2] != b[:2] or not a[0] or not a[1]:
        return 1.0
    step = len(a[2][0]) // a[0]
    count = 0
    for row_a, row_b in zip(a[2], b[2]):
        if row_a == row_b:
            continue
        for i in range(0, len(row_a), step):
            if (abs(row_a[i] - row_b[i]) > 32 or abs(row_a[i + 1] - row_b[i + 1]) > 32
                    or abs(row_a[i + 2] - row_b[i + 2]) > 32):
                count += 1
    return count / float(a[0] * a[1])


def home_places(box, side, next_x):
    """The middle of Home's Next and the clip of its page header, in the
    page's CSS pixels, for its window's canvas at box (hmLayout)."""
    x, y, width, height = box['x'], box['y'], box['width'], box['height']
    ox = max(max(0, side - 224), int(width + side - HOME_SIDE - HOME_WIDTH) // 2)
    oy = max(0, int(height - HOME_HEIGHT) // 2)
    header = {'x': x + HEADER[0] + ox, 'y': y + HEADER[1] + oy,
              'width': HEADER[2] - HEADER[0], 'height': HEADER[3] - HEADER[1]}
    return (x + next_x, y + height - NEXT_ABOVE_BOTTOM), header


def turn_home(page):
    """Clicks Home's title bar and its Next; what came of it: 'missing'
    (no Home window shown), 'moving' (the header moved by itself, so the
    turn could not be seen), 'turned' or 'still', with the share of the
    header that changed."""
    for name, side, next_x in HOMES:
        title = page.locator('.oxt-window-title', has_text=name)
        if title.count() > 0:
            break
    else:
        return 'missing', None
    if not title.first.is_visible():
        return 'missing', None
    window = page.locator('.oxt-window', has=page.locator('.oxt-window-title', has_text=name))
    box = window.first.locator('canvas').first.bounding_box()
    if not box:
        return 'missing', None
    point, header = home_places(box, side, next_x)
    # Home's title bar is the page's own element (engine/src/em-dc.js): a
    # click there brings Home to the front and does nothing else, so that
    # nothing covers Next
    title.first.click()
    before = page.screenshot(clip=header)
    time.sleep(STILL_WAIT)
    still = page.screenshot(clip=header)
    moving = changed(before, still) > STILL
    page.mouse.click(point[0], point[1])
    share = 0.0
    waited = time.time() + TURN_WAIT
    while True:
        time.sleep(LOOK)
        share = changed(still, page.screenshot(clip=header))
        if share >= TURNED or time.time() > waited:
            break
    if moving:
        return 'moving', share
    return ('turned' if share >= TURNED else 'still'), share


def judge_turns(turns):
    """The problem with Home's turns ({outcome: count}), or None."""
    tries = sum(turns.values()) - turns.get('missing', 0)
    seen = turns.get('turned', 0) + turns.get('still', 0)
    if not tries:
        if turns.get('missing', 0) >= 2:
            return 'Home\'s window was not found, so its page was never turned'
        return None
    if seen and turns.get('turned', 0) * 2 < seen:
        return ('a click on Home\'s Next turned its page in %d of the %d tries where a turn could be seen'
                % (turns.get('turned', 0), seen))
    if not seen and tries >= 2:
        return ('Home\'s page was never seen to turn: its header moved by itself at every one of %d '
                'tries, as only Home\'s first page\'s does' % tries)
    return None


def describe_turns(turns):
    if not turns:
        return []
    return ['Home\'s Next: the page turned in %d of %d tries where a turn could be seen; %d tries '
            'on a page that moves by itself, %d with no Home window'
            % (turns.get('turned', 0), turns.get('turned', 0) + turns.get('still', 0),
               turns.get('moving', 0), turns.get('missing', 0))]


class Watchdog(object):
    """Ends the check when one step takes longer than its time limit.
    ask(), a click on an element and a screenshot have a time limit of
    their own; locator.count(), is_visible(), mouse.click() and
    browser.close() wait for the page
    as long as it takes, and a page that stops answering in the middle of
    one would hold the script until the job's limit, with nothing in the
    log to say where. hung(step, seconds) is called from the watchdog's own
    thread, while the script's thread is still waiting: it reports and
    ends the process (os._exit), which also ends Playwright's driver and
    the browser it started."""

    def __init__(self, hung):
        self.hung = hung
        self.lock = threading.Lock()
        self.step = None
        threading.Thread(target=self.watch, daemon=True).start()

    def limit(self, step, seconds):
        """A context in which step must end within seconds."""
        watchdog = self

        class Limit(object):
            def __enter__(self):
                with watchdog.lock:
                    watchdog.step = (step, seconds, time.monotonic() + seconds)

            def __exit__(self, *exc):
                with watchdog.lock:
                    watchdog.step = None
                return False
        return Limit()

    def watch(self):
        while True:
            time.sleep(0.25)
            with self.lock:
                step = self.step
            if step is not None and time.monotonic() > step[2]:
                self.hung(step[0], step[1])
                return


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


def finish(browser, out, problems, samples, turns=None):
    """Reports the run (the numbers, Home's turns, the problems and the
    console's last lines) and gives the exit status."""
    report = describe(samples) + describe_turns(turns)
    for line in report:
        log(line)
    summary(browser, problems, report)
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

    problems, samples, turns = [], [], {}
    started = time.time()
    console = open(os.path.join(out, 'console.txt'), 'w', encoding='utf-8')
    csv = open(os.path.join(out, 'memory.csv'), 'w', encoding='utf-8')
    csv.write('seconds,web_process_mb,web_process_cpu_percent,wasm_memory_mb\n')

    def stamp():
        return '%7.1f' % (time.time() - started)

    def hung(step, seconds):
        # From the watchdog's thread: the script's own thread is still
        # waiting for the page, and only the end of the process frees it
        console.write('%s NO ANSWER while %s\n' % (stamp(), step))
        console.flush()
        csv.flush()
        problems.append('the page did not answer for %d seconds while %s' % (seconds, step))
        try:
            finish(args.browser, out, list(problems), list(samples), dict(turns))
        finally:
            sys.stdout.flush()
            os._exit(1)
    watchdog = Watchdog(hung)

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
            with watchdog.limit('closing the page\'s note', args.unresponsive):
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
                    with watchdog.limit('turning Home\'s page', args.unresponsive):
                        outcome, share = turn_home(page)
                    next_turn = time.time() + TURN
                    turns[outcome] = turns.get(outcome, 0) + 1
                    console.write('%s TURN %s%s\n' % (stamp(), outcome, '' if share is None else
                                                      ' (%.1f%% of the header changed)' % (100 * share)))
            with watchdog.limit('taking the last screenshot', args.unresponsive):
                page.screenshot(path=os.path.join(out, 'last.png'))
            problem = judge_turns(turns)
            if problem:
                problems.append(problem)
        except Exception as e:  # noqa: BLE001 - every failure is reported
            problems.append('%s: %s' % (type(e).__name__, str(e).splitlines()[0] if str(e) else ''))
            try:
                with watchdog.limit('taking a screenshot of the failure', args.unresponsive):
                    page.screenshot(path=os.path.join(out, 'failure.png'))
            except Exception:  # noqa: BLE001
                pass
        finally:
            with watchdog.limit('closing the browser', args.unresponsive):
                browser.close()
            server.shutdown()
            console.close()
            csv.close()

    return finish(args.browser, out, problems, samples, turns)


if __name__ == '__main__':
    sys.exit(main())
