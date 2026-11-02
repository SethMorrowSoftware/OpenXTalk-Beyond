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
# MODE says what the page does: "pass" answers everything; "count",
# "visible", "press" and "close" hang in locator.count(),
# locator.is_visible(), keyboard.press() and browser.close() (calls that
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

class Keyboard(object):
    def press(self, key):
        if mode == 'press':
            hang()

class Element(object):
    def is_visible(self):
        if mode == 'visible':
            hang()
        return True
    def click(self, **options):
        pass

class Locator(object):
    def __init__(self, selector):
        self.selector = selector
        self.first = Element()
    def count(self):
        if mode == 'count':
            hang()
        return 1
    def is_visible(self):
        return False

class Page(object):
    keyboard = Keyboard()
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
    def screenshot(self, path):
        with open(path, 'wb') as f:
            f.write(b'png')

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

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def soak(self, mode, minutes='0.03', unresponsive='1'):
        """(exit status, log) of the soak against the made-up page; a soak
        still running after 60 seconds fails the test."""
        env = dict(os.environ, GITHUB_ACTIONS='true', GITHUB_STEP_SUMMARY=self.summary,
                   PYTHONIOENCODING='utf-8')
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

    def test_a_page_that_hangs_on_a_key_press(self):
        self.hangs_at('press', "turning Home's page")

    def test_a_browser_that_hangs_as_it_closes(self):
        self.hangs_at('close', 'closing the browser')


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
