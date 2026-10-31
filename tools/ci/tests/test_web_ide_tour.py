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

"""web_ide_tour.py's --size, the page's size as the IDE opens: the web IDE
check opens it on pages smaller than Home (web-ide.yml's Web IDE small
window, openxtalk.org p=25583). Its --color-scheme, and the web IDE's page
following the browser between light and dark (seth's choice of
2026-10-30): the page asks for it, its title bars have dark colours, the
check runs the tour in both and its appearance step switches the page.
Playwright is not needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import argparse
import os
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import web_ide_tour  # noqa: E402


class PageSize(unittest.TestCase):
    def test_sizes(self):
        self.assertEqual(web_ide_tour.page_size('640x480'), (640, 480))
        self.assertEqual(web_ide_tour.page_size('800X500'), (800, 500))

    def test_not_sizes(self):
        for text in ('640', '640x', 'x480', '640x480x2', '-640x480', '640 x 480', '100x480', 'axb'):
            with self.assertRaises(argparse.ArgumentTypeError, msg=text):
                web_ide_tour.page_size(text)

    def test_default_is_as_before(self):
        self.assertEqual((web_ide_tour.WIDTH, web_ide_tour.HEIGHT), (1400, 900))

    def test_the_workflow_runs_the_small_sizes_in_firefox(self):
        with open(os.path.join(REPO, '.github', 'workflows', 'web-ide.yml'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('browser: [chromium, firefox]\n        size: [800x500, 640x480]', text)
        self.assertIn('--size "$SIZE"', text)



class FollowsTheBrowser(unittest.TestCase):
    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def test_the_page_asks_for_the_browser_scheme(self):
        page = self.read('tools', 'web-ide', 'index.html')
        self.assertIn('<meta name="oxt-appearance" content="system">', page)
        self.assertIn('@media (prefers-color-scheme: dark)', page)

    def test_the_check_runs_light_and_dark(self):
        text = self.read('.github', 'workflows', 'web-ide.yml')
        self.assertIn('scheme: [light, dark]', text)
        self.assertIn('--color-scheme "$SCHEME"', text)

    def test_the_tour_switches_the_scheme(self):
        tour = self.read('tools', 'ci', 'web-ide-tour.livecodescript')
        steps = [line for line in tour.splitlines() if line.startswith('constant kSteps')][0]
        self.assertIn('appearance', steps.split('"')[1].split(','))
        self.assertIn('tourAct "scheme"', tour)
        self.assertIn("verb == 'scheme'", self.read('tools', 'ci', 'web_ide_tour.py'))


class NotSaved(unittest.TestCase):
    """The web IDE's not-saved bar (seth's choice 6A of 2026-10-31): the
    engine's storage tells the page when the browser stops or starts
    keeping the home folder, the page shows or hides the bar, and the
    tour's storage-open and storage steps (and --refuse-storage, the
    storage refused from the start) check both, in the browser. These
    tests hold the pieces to each other."""

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def test_the_engine_tells_the_page(self):
        js = self.read('engine', 'src', 'em-system.js')
        self.assertIn("new CustomEvent('oxtstoragestate'", js)
        self.assertIn("Module['livecodeStorageError'] = text;", js)
        # a write that fails, a write that works, a folder not loaded
        self.assertIn("console.warn('The home folder could not be kept: ' + error);", js)
        self.assertGreaterEqual(js.count('LiveCodeStorage._report('), 4)

    def test_the_page_listens(self):
        page = self.read('tools', 'web-ide', 'index.html')
        self.assertIn('<div id="storage" role="alert">', page)
        self.assertIn('<span id="storage-error"></span>', page)
        self.assertIn("window.addEventListener('oxtstoragestate', showStorage);", page)
        self.assertIn('Module.livecodeStorageError', page)
        # (the bar is hidden until the engine says otherwise)
        rule = page.split('#storage {', 1)[1].split('}', 1)[0]
        self.assertIn('display: none;', rule)

    def test_the_tour_has_the_steps(self):
        tour = self.read('tools', 'ci', 'web-ide-tour.livecodescript')
        steps = [line for line in tour.splitlines() if line.startswith('constant kSteps')][0]
        steps = steps.split('"')[1].split(',')
        for step in ('storage-open', 'storage'):
            self.assertIn(step, steps)
            self.assertIn('\non tour_%s\n' % step.replace('-', '_'), tour)
        # storage-open runs early, as the IDE opened
        self.assertEqual(steps.index('storage-open'), steps.index('start') + 1)
        self.assertIn("refused by the tour", tour)

    def test_refuse_storage(self):
        self.assertIn("IDBFactory.prototype.open = function()", web_ide_tour.REFUSE_STORAGE)
        self.assertIn("'refused by the tour'", web_ide_tour.REFUSE_STORAGE)
        self.assertIn('refused: false,', web_ide_tour.PAGE_SCRIPT)
        text = self.read('.github', 'workflows', 'web-ide.yml')
        self.assertIn('--refuse-storage \\\n            --only storage-open', text)
        self.assertIn("if: ${{ matrix.size == '800x500' }}", text)


if __name__ == '__main__':
    unittest.main()
