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
Its --stray-errors and --own-error, and the page stopping its start only
on an error of its own. Playwright is not needed.

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


class StrayErrors(unittest.TestCase):
    """--stray-errors and --own-error (2026-11-04: seth's web IDE showed
    "Something went wrong" in a normal window and opened in a private one,
    which leaves the browser's extensions out; the page stopped on any
    error). The page's rule and the scripts that raise the errors are
    tools/ci/stray_errors.py's, held by test_stray_errors.py; these hold
    the web IDE's check to them."""

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def test_the_web_ide_s_listener(self):
        page = self.read('tools', 'web-ide', 'index.html')
        body = page.split("window.addEventListener('error', function(e) {", 1)[1].split('});', 1)[0]
        self.assertIn('if (!oxtOwnError(e)) {', body)
        self.assertLess(body.index('oxtOwnError(e)'), body.index('fail('))
        # the start is not stopped after the IDE has opened, as before
        self.assertLess(body.index('if (started)'), body.index('oxtOwnError(e)'))

    def test_the_tour_uses_the_shared_scripts(self):
        import stray_errors
        self.assertIs(web_ide_tour.STRAY_ERRORS, stray_errors.STRAY_ERRORS)
        self.assertIs(web_ide_tour.OWN_ERROR, stray_errors.OWN_ERROR)
        # the thrown errors are not counted as the page's
        self.assertIn('if args.stray_errors and STRAY_MARK in str(error):',
                      self.read('tools', 'ci', 'web_ide_tour.py'))

    def test_one_or_the_other(self):
        with self.assertRaises(SystemExit):
            web_ide_tour.main(['--site', 'x', '--out', 'y', '--stray-errors', '--own-error'])

    def test_the_workflow_runs_both_in_each_browser(self):
        text = self.read('.github', 'workflows', 'web-ide.yml')
        self.assertIn('--stray-errors \\\n            --only start --timeout 480', text)
        self.assertIn('--own-error \\\n            --timeout 480', text)
        small = text.split('\n  small:\n', 1)[1].split('\n  soak:\n', 1)[0]
        self.assertIn('browser: [chromium, firefox]', small)
        self.assertEqual(small.count("if: ${{ matrix.size == '800x500' }}"), 3)


class Update(unittest.TestCase):
    """An update of the site in a kept browser profile (web-ide.yml's
    upgrade job): the newest release's web IDE saves a stack and a
    preference (the tour's keep step), and this commit's, at the same
    address in the same profile, must find them (kept). "Will I have to
    clear my cache?" (seth, 2026-11-04)."""

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def test_the_tour_has_the_steps_only_when_asked(self):
        tour = self.read('tools', 'ci', 'web-ide-tour.livecodescript')
        steps = [line for line in tour.splitlines() if line.startswith('constant kSteps')][0]
        steps = steps.split('"')[1].split(',')
        self.assertIn('constant kAskedSteps = "keep,kept"', tour)
        for step in ('keep', 'kept'):
            self.assertIn(step, steps)
            self.assertIn('\non tour_%s\n' % step, tour)
        # a tour with no --only leaves them out
        self.assertIn('if tOnly is empty and tStep is among the items of kAskedSteps then', tour)
        keep = tour.split('\non tour_keep\n', 1)[1].split('\nend tour_keep', 1)[0]
        kept = tour.split('\non tour_kept\n', 1)[1].split('\nend tour_kept', 1)[0]
        self.assertIn('save stack kKept', keep)
        self.assertIn('revIDESetPreference "oxtWebTourKept", kKeptText', keep)
        self.assertIn('tourCheckStorage false, empty, 5000', keep)
        self.assertIn('if tText is not kKeptText then', kept)
        self.assertIn('if tPref is not kKeptText then', kept)
        self.assertIn('oxt-web-tour-kept.oxtstack', keep)
        self.assertIn('oxt-web-tour-kept.oxtstack', kept)

    def test_profile_and_port(self):
        text = self.read('tools', 'ci', 'web_ide_tour.py')
        self.assertIn('launch_persistent_context(', text)
        self.assertIn('server = serve(site, args.port)', text)
        self.assertIn("ThreadingHTTPServer(('127.0.0.1', port),", text)

    def test_the_workflow_updates_the_released_site(self):
        text = self.read('.github', 'workflows', 'web-ide.yml')
        job = text.split('\n  upgrade:\n', 1)[1].split('\n  soak:\n', 1)[0]
        self.assertIn('browser: [chromium, firefox]', job)
        self.assertIn('--pattern "*-web-ide.zip"', job)
        before = job.index('--site "$RELEASED_SITE"')
        after = job.index('--site "$RUNNER_TEMP/site"')
        self.assertLess(before, after)
        self.assertIn('--profile "$RUNNER_TEMP/profile" --port 8765 --only start,keep --timeout 480', job)
        self.assertIn('--profile "$RUNNER_TEMP/profile" --port 8765 --only start,storage-open,kept,sample '
                      '--timeout 480', job)


class PropertyListeners(unittest.TestCase):
    """The web IDE's engine tells the IDE that a property changed, as the
    desktop engines do: the Inspector shows a property again only then,
    and a colour taken away with Reset to default stayed in its swatch
    until the window was closed (LittleNemo, openxtalk.org p=25968 and
    p=25970). The tours' inspector-reset-colour steps check it in the IDE;
    these hold the pieces to each other."""

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def wait_loop(self, name):
        text = self.read('engine', 'src', name)
        body = text.split('MCScreenDC::wait(', 1)[1]
        return body.split('\n}\n', 1)[0]

    def test_the_web_wait_sends_them_before_the_pending_messages(self):
        body = self.wait_loop('em-dc.cpp')
        self.assertIn('MCModeQueueEvents();', body)
        self.assertLess(body.index('MCModeQueueEvents();'), body.index('handlepending('))
        self.assertIn('#include "mode.h"', self.read('engine', 'src', 'em-dc.cpp'))

    def test_as_the_desktop_waits_do(self):
        for name in ('desktop-dc.cpp', 'lnxdce.cpp', 'w32dce.cpp'):
            self.assertIn('MCModeQueueEvents();', self.wait_loop(name), name)

    def test_a_standalone_sends_none(self):
        text = self.read('engine', 'src', 'mode_standalone.cpp')
        self.assertIn('void MCModeQueueEvents(void)\n{\n}', text)

    def test_both_tours_reset_a_colour(self):
        for name in ('web-ide-tour.livecodescript', 'ui-tour.livecodescript'):
            tour = self.read('tools', 'ci', name)
            steps = [line for line in tour.splitlines() if line.startswith('constant kSteps')][0]
            self.assertIn('inspector-reset-colour', steps.split('"')[1].split(','), name)
            step = tour.split('\non tour_inspector_reset_colour\n', 1)[1].split('\nend tour_inspector_reset_colour', 1)[0]
            self.assertIn('dispatch "menuPick" to button "inspectMenu" of tEditor with "Reset to default"', step, name)
            self.assertIn('after Reset the swatch still shows 0,160,0', step, name)
            self.assertIn('set the backgroundColor of tButton to "0,0,200"', step, name)


if __name__ == '__main__':
    unittest.main()
