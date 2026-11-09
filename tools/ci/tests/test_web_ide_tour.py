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
import json
import os
import shutil
import subprocess
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


class MessageBoxColours(unittest.TestCase):
    """The script typed in the Message Box kept the colours of the
    appearance it was typed in, so after a switch from light to dark its
    words were olive, purple, navy and black on the dark field (seth, the
    web IDE, 2026-11-08). The Message Box colours it again as the
    appearance changes; the tour's message-box-colours step checks the
    contrast in both appearances in the browser, and that light mode is
    coloured as before. These hold the pieces to each other."""

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read().lstrip('\ufeff')

    def test_the_tour_has_the_step_after_appearance(self):
        tour = self.read('tools', 'ci', 'web-ide-tour.livecodescript')
        steps = [line for line in tour.splitlines() if line.startswith('constant kSteps')][0]
        steps = steps.split('"')[1].split(',')
        self.assertIn('message-box-colours', steps)
        self.assertEqual(steps.index('message-box-colours'), steps.index('appearance') + 1)
        step = tour.split('\non tour_message_box_colours\n', 1)[1].split('\nend tour_message_box_colours', 1)[0]
        for card in ('Single Line', 'Multiple Lines'):
            self.assertIn(card, step)
        self.assertIn('tourAct "scheme dark"', step)
        self.assertIn('tourAct "scheme light"', step)
        # light mode as it was: the same htmlText after the switch back
        self.assertIn('if the htmlText of tField is not tLight then', step)
        check = tour.split('\nfunction tourColourProblem pField, pLabel\n', 1)[1].split('\nend tourColourProblem', 1)[0]
        self.assertIn('if tContrast < 3 then', check)

    def test_the_message_box_colours_again(self):
        box = self.read('ide', 'Toolset', 'palettes', 'message box', 'behaviors',
                        'revmessageboxbehavior.livecodescript')
        changed = box.split('\non ideSystemAppearanceChanged\n', 1)[1].split('\nend ideSystemAppearanceChanged', 1)[0]
        self.assertIn('__RecolorizeMessages', changed)
        again = box.split('\ncommand __RecolorizeMessages\n', 1)[1].split('\nend __RecolorizeMessages', 1)[0]
        self.assertEqual(again.count('dispatch "revSEColorizeField" to stack "revSEUtilities" with tField'), 2)
        self.assertIn('field "message" of card "Single Line" of me', again)
        self.assertIn('field "script" of card "Multiple Lines" of me', again)

    def test_the_history_is_coloured_as_typed(self):
        line = self.read('ide', 'Toolset', 'palettes', 'message box', 'behaviors',
                         'revmessageboxsinglelinemessagebehavior.livecodescript')
        self.assertNotIn('_internal script colorize', line)
        for name in ('revNextLine', 'revPrevLine'):
            body = line.split('\ncommand %s\n' % name, 1)[1].split('\nend %s' % name, 1)[0]
            self.assertIn('dispatch "revSEColorizeField" to stack "revSEUtilities" with the long id of me', body)

    def test_the_engine_test_exists(self):
        test = self.read('tests', 'lcs', 'messagebox', 'appearancecolours.livecodescript')
        for name in ('TestAppearanceChangeColoursBothFields', 'TestAppearanceChangeLeavesEmptyFields',
                     'TestHistoryLineIsColouredAsTyped'):
            self.assertIn('\non %s\n' % name, test)


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


class ProjectBrowserRefresh(unittest.TestCase):
    """The Project Browser's Refresh button showed a corner of the splash's
    art in the web IDE, and its tooltip named the Application Browser
    (littlenemo, openxtalk.org; 0.2.7-rc.6.19). The splash's image took
    revIcons' ID, which is the ID of revIcons' "dark-refresh", the
    button's icon, and the web IDE keeps the splash in memory. Both tours'
    project-browser steps check the button in the IDE (tourRefreshProblem);
    these hold the pieces to each other."""

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read().lstrip('\ufeff')

    def test_both_tours_check_the_button(self):
        for name in ('web-ide-tour.livecodescript', 'ui-tour.livecodescript'):
            tour = self.read('tools', 'ci', name)
            step = tour.split('\non tour_project_browser\n', 1)[1].split('\nend tour_project_browser', 1)[0]
            self.assertIn('put tourRefreshProblem(tStack) into tProblem', step, name)
            self.assertIn('if tProblem is not empty then throw tProblem', step, name)
            check = tour.split('\nfunction tourRefreshProblem pStack\n', 1)[1].split('\nend tourRefreshProblem', 1)[0]
            self.assertIn('"Refresh the Project Browser"', check, name)
            # the release's binary stack (the screenshot jobs' IDE) has the
            # old tooltip: recorded, not failed; any other text fails
            self.assertIn('if the toolTip of tButton is "Refresh the Application Browser" then\n      tourRecord "INFO', check, name)
            self.assertIn('else if the toolTip of tButton is not "Refresh the Project Browser" then\n      return', check, name)
            # every stack in memory but revIcons, substacks too
            self.assertIn('repeat for each line tMain in the mainStacks', check, name)
            self.assertIn('the substacks of stack tMain', check, name)
            self.assertIn('if there is an image id tIcon of stack tSub then', check, name)

    def test_the_splash_takes_no_icons_id(self):
        script = self.read('ide', 'Toolset', 'palettes', 'splash', 'revsplashstackbehavior.livecodescript')
        self.assertIn('set the id of image "Splash" to splashImageId()', script)
        self.assertNotIn('set the id of image "Splash" to the id of stack "revIcons"', script)
        taken = script.split('\nprivate function splashIdIsTaken pId\n', 1)[1].split('\nend splashIdIsTaken', 1)[0]
        self.assertIn('repeat for each item tStack in "revIcons,revGeneralIcons"', taken)
        self.assertIn('if there is an image id pId of stack tStack then return true', taken)
        pick = script.split('\nprivate function splashImageId\n', 1)[1].split('\nend splashImageId', 1)[0]
        # it starts where it did, at revIcons' ID, and steps past what is taken
        self.assertIn('put the id of stack "revIcons" into tId', pick)
        self.assertIn('repeat while splashIdIsTaken(tId)', pick)

    def test_the_tooltip_patch(self):
        patch = self.read('tools', 'oxt', 'ide-stack-patches', 'project-browser-refresh-tooltip.txt')
        self.assertIn('file: Toolset/palettes/project browser/revideprojectbrowser.livecode', patch)
        self.assertIn('from: Refresh the Application Browser\nto: Refresh the Project Browser\n', patch)
        with open(os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'project browser',
                               'revideprojectbrowser.livecode'), 'rb') as f:
            stack = f.read()
        self.assertIn(b'Refresh the Project Browser', stack)
        self.assertNotIn(b'Refresh the Application Browser', stack)


class HilitedNames(unittest.TestCase):
    """White names on a selected row of the Project Browser and the App
    Browser, in the web IDE (littlenemo, openxtalk.org p=26169; seth's
    decision of 2026-11-08): the Project Browser's were the accentColor, a
    blue, on its blue hilite, and the App Browser painted its selected
    controls' names black (its cSuspended, saved true, cleared only on
    Windows). The web tour's project-browser step checks both in the IDE;
    these hold the pieces to each other. Since 0.2.7-rc.6.19 the Project
    Browser's names are white on its blue on macOS and Windows too, and
    black on a light hilite everywhere but Linux, which keeps its own rule
    (test_project_browser_hilite); the App Browser's desktops are as
    before."""

    LIBRARY = ('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read().lstrip('\ufeff')

    def handler(self, kind, name):
        text = self.read(*self.LIBRARY)
        return text.split('\n%s %s ' % (kind, name), 1)[1].split('\nend %s' % name, 1)[0]

    def test_white_on_the_web(self):
        body = self.handler('function', 'revIDEHilitedTextColor')
        self.assertIn('put revEnvironmentIsWeb() is true into pWeb', body)
        # a colour given by name: white on the web, the desktops' as before
        self.assertIn('if pWeb then return "255,255,255"\n      return revIDEColor("dataView_TextHiliteColor")', body)
        # the web takes the rule of macOS and Windows, white on the blue
        # and black on a light hilite, never Linux's
        linux = body.index('if pPlatform is "Linux" and not pWeb then')
        self.assertIn('if tLuminance > 0.5 then return "0,0,0"\n   return "255,255,255"', body[linux:])

    def test_the_app_browser_on_the_web_only(self):
        body = self.handler('command', 'revIDEAppBrowserHilitedNames')
        self.assertIn('if not pWeb then\n      exit revIDEAppBrowserHilitedNames', body)
        self.assertIn('ends with "/App Browser.livecode"', body)
        self.assertIn('set the cSuspended of stack pStack to false', body)
        self.assertLess(body.index('lock messages'), body.index('set the cSuspended'))
        opener = self.handler('on', 'revIDEOpenPlugin')
        self.assertIn('revIDEAppBrowserHilitedNames tStackPath', opener)
        self.assertLess(opener.index('revIDEAppBrowserHilitedNames tStackPath'), opener.index('go invisible stack'))

    def test_the_web_tour_checks_both(self):
        tour = self.read('tools', 'ci', 'web-ide-tour.livecodescript')
        step = tour.split('\non tour_project_browser\n', 1)[1].split('\nend tour_project_browser', 1)[0]
        self.assertIn('revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor")) is not "255,255,255"', step)
        self.assertIn('revIDEHilitedTextColor("212,212,212") is not "0,0,0"', step)
        self.assertIn('if the cSuspended of stack "App Browser" is true then', step)
        self.assertIn('close stack "App Browser"', step)

    def test_the_ide_tests(self):
        hilite = self.read('ide', 'tests', 'projectbrowser', 'hilite.livecodescript')
        self.assertIn('on TestHilitedNamesAreWhiteOnTheWeb', hilite)
        self.assertIn('on TestHilitedNamesAreWhiteOnMacAndWindows', hilite)
        self.assertIn('on TestHilitedNamesOnLinuxAreAsBefore', hilite)
        self.assertIn('on TestAppBrowserHilitedNamesOnTheWeb',
                      self.read('ide', 'tests', 'appbrowser', 'updates.livecodescript'))


class ExtensionStacksNotTheUsers(unittest.TestCase):
    """The stacks the IDE loads from its own Extensions folder are its own:
    until rc.6.18 the web IDE's Project Browser and App Browser listed the
    layout guides' library, community.ferruslogic.plugin.devguides, first
    among the user's stacks (LittleNemo, openxtalk.org p=26169). With the
    guides off the library closes itself, which leaves a library the IDE
    never opened in memory, and its name neither begins with "rev" nor is
    the name the IDE loaded it by. The web tour's project-browser step
    failed on rc.6.17's web IDE and passes with the library marking itself
    the IDE's; the desktop tour's App Browser step checks its list too."""

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def handler(self, text, kind, name):
        return text.split('\n%s %s' % (kind, name), 1)[1].split('\nend %s\n' % name, 1)[0]

    def test_the_web_tour_checks_after_the_project_browser(self):
        tour = self.read('tools', 'ci', 'web-ide-tour.livecodescript')
        step = self.handler(tour, 'on', 'tour_project_browser')
        self.assertIn('tourExtensionStacksNotUsers', step)
        self.assertLess(step.index('close stack tStack'), step.index('tourExtensionStacksNotUsers'))
        check = self.handler(tour, 'command', 'tourExtensionStacksNotUsers')
        self.assertIn('put revFilterStacksList(the mainStacks) into tUsers', check)
        self.assertIn('put revIDESpecialFolderPath("extensions") & slash into tExtensions', check)
        self.assertIn('if the effective filename of stack tStackName begins with tExtensions then', check)
        self.assertIn('throw "the IDE lists its own extensions\' stacks among the user\'s stacks:"', check)

    def test_the_desktop_tour_checks_the_app_browsers_list(self):
        tour = self.read('tools', 'ci', 'ui-tour.livecodescript')
        step = self.handler(tour, 'on', 'tour_app_browser')
        call = step.index('get tourExtensionStacksListed(tListed)')
        thrown = step.index('throw "the App Browser lists the IDE\'s own extensions\' stacks')
        self.assertLess(call, thrown)
        self.assertLess(step.rindex('close stack tStack', 0, thrown), thrown)
        check = self.handler(tour, 'function', 'tourExtensionStacksListed')
        self.assertIn('put revIDESpecialFolderPath("extensions") & slash into tExtensions', check)
        self.assertIn('the effective filename of stack tStackName begins with tExtensions', check)

    def test_the_guides_library_is_the_ides_with_the_guides_off(self):
        text = self.read('ide', 'Extensions', 'community.ferruslogic.plugin.devguides',
                         'DevGuides.livecodescript')
        start = self.handler(text, 'on', 'extensionInitialize')
        mark = start.index('set the _ideoverride of me to true')
        self.assertLess(mark, start.index('if the cLayoutGuides of stack "revPreferences" is true then'))
        self.assertLess(mark, start.index('close this stack'))


class TooltipText(unittest.TestCase):
    """bwmilby, openxtalk.org p=26171: in a dark browser the web engine drew
    a tooltip's background dark and its text black. The engine now writes
    the text white in the dark appearance only, and the tour's tooltip step
    measures the contrast of a real tooltip in both appearances."""

    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def tour(self):
        return self.read('tools', 'ci', 'web-ide-tour.livecodescript')

    def contrast_js(self):
        line = [line for line in self.tour().splitlines()
                if line.startswith('constant kTooltipContrastJS = ')][0]
        return line.split('"')[1]

    def test_the_tour_has_the_step(self):
        tour = self.tour()
        steps = [line for line in tour.splitlines() if line.startswith('constant kSteps')][0]
        steps = steps.split('"')[1].split(',')
        self.assertIn('tooltip', steps)
        # (after the appearance step, which leaves the page as it started)
        self.assertGreater(steps.index('tooltip'), steps.index('appearance'))
        step = tour.split('on tour_tooltip', 1)[1].split('end tour_tooltip', 1)[0]
        self.assertIn('"light,dark"', step)
        self.assertIn('word -1 of tInfo < 4.5', tour)

    def test_the_engine_writes_white_only_in_the_dark(self):
        theme = self.read('engine', 'src', 'em-theme.cpp')
        body = theme.split('MCEmscriptenThemeGetTooltipTextColor(MCColor& r_color)\n{', 1)[1].split('\n}', 1)[0]
        self.assertIn('if (!em_theme_is_dark())\n\t\treturn false;', body)
        self.assertIn('kMCWebThemeDarkText', body)
        tooltip = self.read('engine', 'src', 'tooltip.cpp')
        render = tooltip.split('void MCTooltip::render', 1)[1].split('\n}', 1)[0]
        guarded = render.split('#if defined(__EMSCRIPTEN__)', 1)[1].split('#endif', 1)
        self.assertIn('MCEmscriptenThemeGetTooltipTextColor(t_text_color)', guarded[0])
        # (every other engine, and the light appearance, keep black)
        self.assertIn('dc -> setforeground(MCscreen -> black_pixel);', guarded[1])

    def run_js(self, back, ink):
        node = shutil.which('node')
        if node is None:
            self.skipTest('no node')
        # a tooltip window 40 x 10 of colour back, its middle row of colour
        # ink, as em-dc.js's canvas (2d context) shows one
        script = """
var W = 40, H = 10, back = %s, ink = %s;
var data = new Uint8ClampedArray(W * H * 4);
for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) {
  var c = (y === 5 && x > 5 && x < 30) ? ink : back, k = (y * W + x) * 4;
  data[k] = c[0]; data[k + 1] = c[1]; data[k + 2] = c[2]; data[k + 3] = 255;
}
var canvas = { width: W, height: H,
  getBoundingClientRect: function () { return { left: 110, top: 216, width: W, height: H }; },
  getContext: function () { return { getImageData: function () { return { data: data }; } }; } };
var element = { querySelector: function () { return canvas; } };
global.document = { querySelectorAll: function () { return [element]; } };
global.getComputedStyle = function () { return { display: 'block' }; };
console.log(eval(%s)(100, 200));
""" % (json.dumps(back), json.dumps(ink), json.dumps(self.contrast_js()))
        return subprocess.run([node, '-e', script], capture_output=True, text=True,
                              check=True).stdout.strip()

    def test_the_contrast_of_rc_6_17_s_dark_tooltip(self):
        info = self.run_js([32, 32, 32], [0, 0, 0])
        self.assertEqual(info, '40x10 back 32,32,32 ink 0,0,0 contrast 1.29')

    def test_the_contrast_of_the_fixed_dark_tooltip(self):
        info = self.run_js([32, 32, 32], [255, 255, 255])
        self.assertEqual(info.split()[:5], ['40x10', 'back', '32,32,32', 'ink', '255,255,255'])
        self.assertGreaterEqual(float(info.split()[-1]), 4.5)

    def test_the_contrast_of_the_light_tooltip(self):
        info = self.run_js([240, 240, 240], [0, 0, 0])
        self.assertEqual(info, '40x10 back 240,240,240 ink 0,0,0 contrast 18.43')


if __name__ == '__main__':
    unittest.main()
