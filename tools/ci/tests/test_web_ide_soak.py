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

"""tools/ci/web_ide_soak.py, the web IDE soak, run against a made-up
Playwright whose page answers, or stops answering at one step.

  python3 -m unittest discover -s tools/ci/tests

On main 25a872e97 (2026-11-02) the soak in WebKit printed its last line
after 355 seconds and then waited until the job's 25-minute limit ended
it: the page stopped answering while the script was in a call that has
no time limit of its own (finding Home's title bar, a key press), so the
soak neither failed nor reported where. Each run here is a process of its
own with a time limit: a soak that hangs is a failed test, not a hung
one.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

CI = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

# The made-up Playwright, put in sys.modules before the soak imports it.
# MODE says what the page does: "pass" answers everything, and a click in
# the middle of Home's Next (where it is in revwebhome.livecodescript, for
# OXT-Beyond Home's window) turns Home's page, whose header (the
# screenshot of a clip) is the page's own picture and, on the first page,
# a new one at every look; "stuck" is the same but a click turns no page,
# with Home on its second page, whose header stands still; "first" keeps
# Home on its first page, whose header moves, whatever is done (no key
# has turned the page since #557); "count", "visible", "click" and "close"
# hang in locator.count(),
# locator.is_visible(), mouse.click() and browser.close() (calls that
# Playwright gives no time limit); "silent" answers until the IDE has
# opened and then no question, which the soak's own time limit catches.
# The browser's processes are the made-up browser's too, not the host's
# (web_process): on the macos-15 runner each soak here took about 36
# seconds, where 2 do on Linux, and the silent one more than 60, as if
# the host's ps took half a minute (CI scripts on macos-15, #322).
FAKE = r'''
import os, sys, threading, time, types
ci, mode, argv = sys.argv[1], sys.argv[2], sys.argv[3:]
sys.path.insert(0, ci)

def hang():
    threading.Event().wait()

class TimeoutError(Exception):
    pass

class Handle(object):
    def __init__(self, value):
        self.value = value
    def json_value(self):
        return {'value': self.value}

# Home's window's canvas, as dp.2's web IDE has it at 1400 x 900; Next's
# middle, from its left and bottom (hmBuildHostedSide, hmLayout); the pages
PLACE = {'x': 60.0, 'y': 119.0, 'width': 1280.0, 'height': 761.0}
NEXT = (248 - 120 + 106 / 2.0, 640 - 510 - 32 / 2.0)
PAGES = ['home', 'speak', 'move', 'draw', 'web', 'app']
home = {'page': 1 if mode == 'stuck' else 0, 'looks': 0, 'clicks': []}

def turn():
    home['page'] = (home['page'] + 1) % len(PAGES)
    with open(os.environ['FAKE_TURNS'], 'a') as f:
        f.write(PAGES[home['page']] + '\n')

class Keyboard(object):
    def press(self, key):
        pass

class Mouse(object):
    def click(self, x, y, **options):
        if mode == 'click':
            hang()
        home['clicks'].append((x, y))
        # Next is at least 106 by 32
        if (mode not in ('stuck', 'first') and abs(x - PLACE['x'] - NEXT[0]) < 53
                and abs(PLACE['y'] + PLACE['height'] - NEXT[1] - y) < 16):
            turn()

class Element(object):
    def __init__(self, selector):
        self.selector = selector
    def is_visible(self):
        if mode == 'visible':
            hang()
        return True
    def click(self, **options):
        pass
    def locator(self, selector, **options):
        return Locator(selector)
    def bounding_box(self):
        return dict(PLACE) if self.selector == 'canvas' else None

class Locator(object):
    def __init__(self, selector):
        self.selector = selector
        self.first = Element(selector)
    def count(self):
        if mode == 'count':
            hang()
        return 1
    def is_visible(self):
        return False

def picture(colour):
    # A PNG of the header's clip, 776 x 60, of one colour
    import struct, zlib
    def chunk(kind, body):
        return (struct.pack('>I', len(body)) + kind + body
                + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff))
    rows = b''.join(b'\x00' + bytes(colour) * 776 for y in range(60))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 776, 60, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))

class Page(object):
    keyboard = Keyboard()
    mouse = Mouse()
    main_frame = object()
    def set_default_timeout(self, ms):
        pass
    def on(self, event, handler):
        pass
    def goto(self, url):
        pass
    def wait_for_function(self, expression, timeout=None):
        if not expression.startswith('() =>'):
            return Handle(True)
        if mode == 'silent' and 'HEAPU8' in expression:
            time.sleep(timeout / 1000.0)
            raise TimeoutError('Timeout %dms exceeded.' % timeout)
        return Handle([None, 100 * 1048576] if 'HEAPU8' in expression else '')
    def locator(self, selector, **options):
        return Locator(selector)
    def screenshot(self, path=None, clip=None):
        if clip is not None:
            # The header, where the soak finds it (hmLayout: the pages
            # 152 right and 60 down in this window)
            assert clip == {'x': PLACE['x'] + 224 + 152, 'y': PLACE['y'] + 10 + 60,
                            'width': 776, 'height': 60}, clip
            home['looks'] += 1
            page = home['page']
            if page == 0:
                return picture(((home['looks'] * 50) % 256, 40, 90))
            return picture((40 * page, 200, 255 - 40 * page))
        with open(path, 'wb') as f:
            f.write(b'png')
        return b'png'

class Browser(object):
    def new_page(self, **options):
        return Page()
    def close(self):
        if mode == 'close':
            hang()

class Kind(object):
    def launch(self):
        return Browser()

class Playwright(object):
    chromium = webkit = firefox = Kind()
    def __enter__(self):
        return self
    def __exit__(self, *exc):
        return False

sync_api = types.ModuleType('playwright.sync_api')
sync_api.sync_playwright = Playwright
package = types.ModuleType('playwright')
package.sync_api = sync_api
sys.modules['playwright'] = package
sys.modules['playwright.sync_api'] = sync_api

import web_ide_soak as soak
soak.SAMPLE, soak.TURN, soak.REPORT = 0.05, 0, 0.5
soak.STILL_WAIT, soak.LOOK, soak.TURN_WAIT = 0.05, 0.02, 0.2
soak.web_process = lambda browser: (4242, 500.0)
sys.argv = ['web_ide_soak.py'] + argv
sys.exit(soak.main())
'''


class WebIdeSoakTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.site = os.path.join(self.tmp, 'site')
        os.makedirs(self.site)
        open(os.path.join(self.site, 'ide.zip'), 'wb').close()
        self.out = os.path.join(self.tmp, 'out')
        self.summary = os.path.join(self.tmp, 'summary.md')
        # The pages the made-up Home turned to, one a line
        self.turns = os.path.join(self.tmp, 'turns.txt')
        open(self.turns, 'w').close()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def soak(self, mode, minutes='0.03', unresponsive='1'):
        """(exit status, log) of the soak against the made-up page; a soak
        still running after 60 seconds fails the test."""
        env = dict(os.environ, GITHUB_ACTIONS='true', GITHUB_STEP_SUMMARY=self.summary,
                   PYTHONIOENCODING='utf-8', FAKE_TURNS=self.turns)
        try:
            done = subprocess.run([sys.executable, '-c', FAKE, CI, mode, '--site', self.site,
                                   '--out', self.out, '--browser', 'webkit', '--minutes', minutes,
                                   '--unresponsive', unresponsive],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env,
                                  timeout=60)
        except subprocess.TimeoutExpired:
            self.fail('the soak hung (mode %s) and was still waiting after 60 seconds' % mode)
        return done.returncode, done.stdout.decode('utf-8', 'replace')

    def read(self, *path):
        with open(os.path.join(*path), encoding='utf-8') as f:
            return f.read()

    def test_a_page_that_answers_passes(self):
        status, out = self.soak('pass')
        self.assertEqual(status, 0, out)
        self.assertIn('Passed', out)
        self.assertIn('TURN', self.read(self.out, 'console.txt'))
        self.assertGreater(len(self.read(self.out, 'memory.csv').splitlines()), 2)
        self.assertTrue(os.path.exists(os.path.join(self.out, 'last.png')))
        self.assertIn('Passed.', self.read(self.summary))
        self.assertIn('web process, resident MB: 500 at the start', out)

    def test_home_s_pages_are_turned_by_its_next(self):
        # Until #557 the right arrow key turned Home's page; since, only
        # Next does, and the soak clicks it: every page in turn runs
        status, out = self.soak('pass', minutes='0.08')
        self.assertEqual(status, 0, out)
        pages = self.read(self.turns).split()
        self.assertGreaterEqual(len(pages), 6, out)
        self.assertEqual(pages[:6], ['speak', 'move', 'draw', 'web', 'app', 'home'])
        console = self.read(self.out, 'console.txt')
        self.assertIn('TURN turned', console)
        self.assertIn('TURN moving', console)
        self.assertNotIn('TURN still', console)
        self.assertRegex(out, r"Home's Next: the page turned in (\d+) of \1 tries where a turn could be seen")
        self.assertIn("Home's Next: the page turned in", self.read(self.summary))

    def test_a_click_that_turns_no_page_fails(self):
        # A click that misses Next: the header stands still before and
        # after it, and the soak says so
        status, out = self.soak('stuck', minutes='0.08')
        self.assertEqual(status, 1, out)
        self.assertEqual(self.read(self.turns), '')
        self.assertIn('TURN still', self.read(self.out, 'console.txt'))
        self.assertRegex(out, r"FAILED: a click on Home's Next turned its page in 0 of the \d+ tries "
                         r"where a turn could be seen")
        self.assertIn('Failed.', self.read(self.summary))

    def test_a_home_that_stays_on_its_first_page_fails(self):
        # Home on its first page throughout, as when the soak pressed the
        # arrow key after #557: the header moves by itself at every look,
        # so no turn is seen and none is compared, and the soak fails for it
        status, out = self.soak('first', minutes='0.08')
        self.assertEqual(status, 1, out)
        self.assertEqual(self.read(self.turns), '')
        self.assertNotIn('TURN turned', self.read(self.out, 'console.txt'))
        self.assertRegex(out, r"FAILED: Home's page was never seen to turn: its header moved by itself "
                         r"at every one of \d+ tries")

    def test_a_page_that_stops_answering_questions_fails(self):
        # The soak's own time limit, which ask() has always had
        status, out = self.soak('silent')
        self.assertEqual(status, 1, out)
        self.assertIn('FAILED: RuntimeError: the page did not answer for', out)

    def hangs_at(self, mode, step):
        status, out = self.soak(mode)
        self.assertEqual(status, 1, out)
        problem = 'the page did not answer for 1 seconds while %s' % step
        self.assertIn('FAILED: ' + problem, out)
        self.assertIn('::error title=Web IDE soak::' + problem, out)
        self.assertIn('NO ANSWER while ' + step, self.read(self.out, 'console.txt'))
        summary = self.read(self.summary)
        self.assertIn('Failed.', summary)
        self.assertIn('- ' + problem, summary)
        # The numbers so far are reported, as for any other failure
        self.assertIn('WebAssembly memory, MB: 100 at the start', out)

    def test_a_page_that_hangs_while_home_is_found(self):
        self.hangs_at('count', "turning Home's page")

    def test_a_page_that_hangs_while_home_is_looked_at(self):
        self.hangs_at('visible', "turning Home's page")

    def test_a_page_that_hangs_on_a_click(self):
        self.hangs_at('click', "turning Home's page")

    def test_a_browser_that_hangs_as_it_closes(self):
        self.hangs_at('close', 'closing the browser')


def soak_module():
    sys.path.insert(0, CI)
    try:
        import web_ide_soak
    finally:
        sys.path.remove(CI)
    return web_ide_soak


class HomeGeometryTest(unittest.TestCase):
    """Where the soak clicks and looks is where Home has Next and its page
    header, in this checkout's Home: a click that misses Next turns no
    page, as the right arrow key has turned none since #557."""

    def setUp(self):
        self.soak = soak_module()
        root = os.path.join(CI, '..', '..', 'ide', 'Toolset')
        with open(os.path.join(root, 'palettes', 'web home', 'revwebhome.livecodescript'),
                  encoding='utf-8') as f:
            self.home = f.read()
        with open(os.path.join(root, 'palettes', 'home', 'revhub.livecodescript'), encoding='utf-8') as f:
            self.hub = f.read()

    def find(self, pattern):
        import re
        found = re.findall(pattern, self.home)
        self.assertEqual(len(found), 1, pattern)
        return found[0]

    def test_the_layout_s_numbers(self):
        soak = self.soak
        self.assertEqual(int(self.find(r'\nconstant kWidth = (\d+)\n')), soak.HOME_WIDTH)
        self.assertEqual(int(self.find(r'\nconstant kHeight = (\d+)\n')), soak.HOME_HEIGHT)
        self.assertEqual(int(self.find(r'\nconstant kSide = (\d+)\n')), soak.HOME_SIDE)
        self.assertEqual(int(self.find(r'if hmHosted\(\) then\s+return (\d+)\s+end if\s+return kSide')),
                         soak.HOMES[0][1])
        self.assertEqual(soak.HOMES[1][1], soak.HOME_SIDE)
        # The pages in the middle of the room right of the sidebar, and
        # Next moved down with the window's foot
        self.find(r'put max\(max\(0, hmSide\(\) - 224\), \(pWidth \+ hmSide\(\) - kSide - kWidth\) div 2\) '
                  r'into tOX')
        self.find(r'put max\(0, \(pHeight - kHeight\) div 2\) into tOY')
        self.find(r'put pHeight - sLaidH into tFoot')
        self.find(r'repeat for each item tName in "startup,back,next"\s+'
                  r'set the top of group tName to the top of group tName \+ tFoot')

    def test_next(self):
        soak = self.soak
        number = r'(\d+), (\d+), (\d+), "Next", "chevron-right", "dark", empty, empty, "page next", (\d+)\)'
        # OXT-Beyond Home's, at tSide - 120
        back, top, height, width = map(int, self.find(r'hmButton\("next", tSide - ' + number))
        self.assertEqual(soak.HOMES[0][2], soak.HOMES[0][1] - back + width // 2)
        self.assertEqual(soak.NEXT_ABOVE_BOTTOM, soak.HOME_HEIGHT - (top + height // 2))
        # Home's own window's
        left, top, height, width = map(int, self.find(r'hmButton\("next", ' + number))
        self.assertEqual(soak.HOMES[1][2], left + width // 2)
        self.assertEqual(soak.NEXT_ABOVE_BOTTOM, soak.HOME_HEIGHT - (top + height // 2))
        self.assertEqual(soak.NEXT_ABOVE_BOTTOM, 114)

    def test_the_header(self):
        soak = self.soak
        left, top, right, bottom = soak.HEADER
        for name in ('hdrTitle', 'hdrTag'):
            rect = [int(n) for n in self.find(r'hmLabel\("%s", "(\d+,\d+,\d+,\d+)"' % name).split(',')]
            self.assertTrue(left <= rect[0] and top <= rect[1] and rect[2] <= right and rect[3] <= bottom,
                            (name, rect))

    def test_the_window_titles(self):
        self.assertIn('set the label of me to "%s"' % self.soak.HOMES[0][0], self.hub)
        self.assertIn('set the label of me to "%s"' % self.soak.HOMES[1][0], self.home)

    def test_the_places_in_dp2_s_window(self):
        # dp.2's web IDE at 1400 x 900, where a click there turned the page
        point, header = self.soak.home_places({'x': 60, 'y': 119, 'width': 1280, 'height': 761},
                                              *self.soak.HOMES[0][1:])
        self.assertEqual(point, (60 + 181, 119 + 761 - 114))
        self.assertEqual(header, {'x': 60 + 224 + 152, 'y': 119 + 10 + 60, 'width': 776, 'height': 60})
        # A window no bigger than Home's pages: the hosted pages start
        # right of the wider sidebar
        point, header = self.soak.home_places({'x': 0, 'y': 0, 'width': 1024, 'height': 640},
                                              *self.soak.HOMES[0][1:])
        self.assertEqual((point, header['x'], header['y']), ((181, 526), 248, 10))
        point, header = self.soak.home_places({'x': 0, 'y': 0, 'width': 1024, 'height': 640},
                                              *self.soak.HOMES[1][1:])
        self.assertEqual((point, header['x'], header['y']), ((145, 526), 224, 10))


def png(rows, colour, filters):
    """A PNG of rows (lists of pixels), each row with the next filter."""
    import struct
    import zlib
    step = 4 if colour == 6 else 3
    data, prior = b'', [0] * (len(rows[0]) * step)
    for y, row in enumerate(rows):
        line = [v for pixel in row for v in pixel[:step]]
        kind = filters[y % len(filters)]
        out = []
        for i, v in enumerate(line):
            a = line[i - step] if i >= step else 0
            b = prior[i]
            c = prior[i - step] if i >= step else 0
            if kind == 0:
                guess = 0
            elif kind == 1:
                guess = a
            elif kind == 2:
                guess = b
            elif kind == 3:
                guess = (a + b) >> 1
            else:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                guess = a if pa <= pb and pa <= pc else b if pb <= pc else c
            out.append((v - guess) & 255)
        data += bytes([kind] + out)
        prior = line

    def chunk(kind, body):
        return (struct.pack('>I', len(body)) + kind + body
                + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff))
    head = struct.pack('>IIBBBBB', len(rows[0]), len(rows), 8, colour, 0, 0, 0)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', head) + chunk(b'IDAT', zlib.compress(data))
            + chunk(b'IEND', b''))


class ChangedTest(unittest.TestCase):
    """How much of the header a turn changed, from two screenshots."""

    def setUp(self):
        import random
        self.soak = soak_module()
        rng = random.Random(557)
        self.rows = [[(rng.randrange(256), rng.randrange(256), rng.randrange(256), 255)
                      for x in range(23)] for y in range(11)]

    def test_every_filter_in_rgb_and_rgba(self):
        for colour in (2, 6):
            for filters in ([0], [1], [2], [3], [4], [0, 1, 2, 3, 4]):
                width, height, rows = self.soak.png_pixels(png(self.rows, colour, filters))
                step = 4 if colour == 6 else 3
                self.assertEqual((width, height), (23, 11))
                self.assertEqual(rows, [bytes(v for p in row for v in p[:step]) for row in self.rows],
                                 (colour, filters))

    def test_the_share_changed(self):
        soak = self.soak
        before = png(self.rows, 6, [4, 1])
        self.assertEqual(soak.changed(before, before), 0.0)
        # The same picture, filtered otherwise: no change
        self.assertEqual(soak.changed(before, png(self.rows, 6, [0, 2, 3])), 0.0)
        after = [list(row) for row in self.rows]
        # 11 pixels changed by more than 32 in one colour, 11 by 32 or less
        for y in range(11):
            r, g, b, a = after[y][0]
            after[y][0] = ((r + 128) % 256, g, b, a)
            r, g, b, a = after[y][1]
            after[y][1] = (r, g, b ^ 16, a)
        self.assertAlmostEqual(soak.changed(before, png(after, 6, [4])), 11 / (23 * 11.0))
        # What it cannot read changed throughout, unless the same
        self.assertEqual(soak.changed(b'not a png', b'not a png either'), 1.0)
        self.assertEqual(soak.changed(before, png([row[:20] for row in self.rows], 6, [0])), 1.0)
        self.assertIsNone(soak.png_pixels(b'png'))


class TheWorkflowTest(unittest.TestCase):
    """web-ide.yml's soak step gives each try a time limit, and two
    WebKit tries fit in the step's: a hung try is stopped and the second
    runs."""

    def step(self):
        import re
        with open(os.path.join(CI, '..', '..', '.github', 'workflows', 'web-ide.yml'), encoding='utf-8') as f:
            text = f.read()
        start = text.index('      - name: Web IDE soak\n')
        end = text.index('\n      - name:', start + 1)
        return re, text[start:end]

    def test_each_try_has_a_time_limit_and_two_fit_in_the_step(self):
        re, step = self.step()
        self.assertIn('tools/ci/retry_check.py', step)
        limit = re.search(r'--try-minutes (\d+(?:\.\d+)?)', step)
        self.assertIsNotNone(limit, 'the soak step gives its tries no time limit')
        minutes = float(limit.group(1))
        step_minutes = re.search(r"timeout-minutes: \$\{\{ matrix\.browser == 'webkit' && (\d+) \|\| (\d+) \}\}",
                                 step)
        tries = re.search(r"TRIES: \$\{\{ matrix\.browser == 'webkit' && (\d+) \|\| (\d+) \}\}", step)
        soak = re.search(r'--minutes (\d+(?:\.\d+)?)', step)
        self.assertTrue(step_minutes and tries and soak, step)
        # Each try has room for the soak and the IDE's opening ...
        self.assertGreaterEqual(minutes, float(soak.group(1)) + 3)
        # ... and every try, with a minute for each stop, fits in the step
        for browser in (1, 2):
            self.assertLess(int(tries.group(browser)) * (minutes + 1), int(step_minutes.group(browser)))


if __name__ == '__main__':
    unittest.main()
