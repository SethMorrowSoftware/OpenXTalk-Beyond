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

"""tools/ci/ui_tour.py's macOS crash reports, with made-up ones: which it
finds, when it waits for one, and what it logs of one (a .ips as macOS 12
and later write it, and a .crash); and the crash dialog it keeps off CI's
screen. And the tour's macOS system-switch step, read from the tour
script: how it posts the switch, and that it still checks the message.
And its log, on a console that cannot show every character.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import json
import os
import shutil
import signal
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import ui_tour  # noqa: E402

ENGINE = '/Users/runner/oxt-test/OXT-Beyond.app/Contents/MacOS/OXT-Beyond'

# A report as ReportCrash writes it: a line about it, then the report
HEADER = {'app_name': 'OXT-Beyond', 'bug_type': '309', 'name': 'OXT-Beyond'}
REPORT = {
    'procName': 'OXT-Beyond',
    'pid': 4532,
    'procPath': ENGINE,
    'captureTime': '2026-10-25 02:23:54.1234 +0000',
    'exception': {'type': 'EXC_BAD_ACCESS', 'signal': 'SIGSEGV',
                  'subtype': 'KERN_INVALID_ADDRESS at 0x0000000000000010'},
    'termination': {'namespace': 'SIGNAL', 'indicator': 'Segmentation fault: 11'},
    'asi': {'libsystem_c.dylib': ['abort() called']},
    'faultingThread': 2,
    'threads': [
        {'queue': 'com.apple.main-thread',
         'frames': [{'imageOffset': 0x1000, 'imageIndex': 0},
                    {'imageOffset': 0x2a0, 'symbol': 'exit', 'symbolLocation': 32, 'imageIndex': 1}]},
        {'frames': [{'imageOffset': 0x10, 'imageIndex': 1}]},
        {'triggered': True, 'name': 'worker',
         'frames': [{'imageOffset': 0x4321, 'imageIndex': 0},
                    {'imageOffset': 0x8, 'symbol': '__pthread_kill', 'symbolLocation': 8, 'imageIndex': 1},
                    {'imageOffset': 0x99, 'imageIndex': 7}]},
    ],
    'usedImages': [
        {'base': 0x100000000, 'name': 'OXT-Beyond', 'path': ENGINE, 'arch': 'arm64'},
        {'base': 0x180000000, 'name': 'libsystem_kernel.dylib', 'path': '/usr/lib/system/libsystem_kernel.dylib',
         'arch': 'arm64e'},
    ],
}


# (macOS's crash reports, read on the Mac only: they reason about POSIX
# signals, which Windows' signal module does not have)
@unittest.skipUnless(hasattr(signal, 'SIGKILL'), 'no POSIX signals here (macOS crash reports)')
class CrashReports(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        patcher = mock.patch.object(ui_tour, 'MAC_CRASH_DIRS', (self.tmp, os.path.join(self.tmp, 'none')))
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, name, text, age=0):
        path = os.path.join(self.tmp, name)
        with open(path, 'w') as f:
            f.write(text)
        if age:
            when = time.time() - age
            os.utime(path, (when, when))
        return path

    def logged(self, fn, *args, **kw):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            result = fn(*args, **kw)
        return result, out.getvalue().splitlines()

    def test_finds_the_engines_reports_since_the_run_started(self):
        since = time.time() - 60
        new = self.write('OXT-Beyond-2026-10-25-022355.ips', '{}\n{}')
        crash = self.write('OXT-Beyond_2026-10-25-022355_runner.crash', 'Process: OXT-Beyond')
        self.write('OXT-Beyond-2026-10-24-120000.ips', '{}\n{}', age=3600)
        self.write('OXT-BeyondHelper-2026-10-25-022355.ips', '{}\n{}')
        self.write('Finder-2026-10-25-022355.ips', '{}\n{}')
        self.write('OXT-Beyond-2026-10-25-022355.txt', '')
        self.assertEqual(sorted(ui_tour.mac_crash_reports('OXT-Beyond', since)), sorted([new, crash]))

    def test_logs_what_a_report_says(self):
        path = self.write('OXT-Beyond-2026-10-25-022355.ips', json.dumps(HEADER) + '\n' + json.dumps(REPORT))
        with mock.patch.object(ui_tour.shutil, 'which', return_value=None):
            _, lines = self.logged(ui_tour.mac_crash_report, path, 4532)
        self.assertEqual(lines[0], '::group::A crash report: OXT-Beyond-2026-10-25-022355.ips')
        self.assertIn("Process     : OXT-Beyond [4532] (this run's engine)", lines)
        self.assertIn('Path        : %s' % ENGINE, lines)
        self.assertIn('Exception   : EXC_BAD_ACCESS SIGSEGV KERN_INVALID_ADDRESS at 0x0000000000000010', lines)
        self.assertIn('Termination : Segmentation fault: 11', lines)
        self.assertIn('It said     : libsystem_c.dylib: abort() called', lines)
        # the thread that crashed, then the main thread
        crashed = lines.index('Thread 2 (crashed), worker:')
        main = lines.index('Thread 0 (the main thread), com.apple.main-thread:')
        self.assertLess(crashed, main)
        self.assertEqual(lines[crashed + 1].split(), ['0', 'OXT-Beyond', '0x100004321', '+', '0x4321'])
        self.assertEqual(lines[crashed + 2].split(), ['1', 'libsystem_kernel.dylib', '0x180000008',
                                                      '__pthread_kill', '+', '8'])
        # an image the report does not list
        self.assertEqual(lines[crashed + 3].split(), ['2', '???', '0x99', '+', '0x99'])
        self.assertEqual(lines[main + 2].split(), ['1', 'libsystem_kernel.dylib', '0x1800002a0', 'exit', '+', '32'])
        self.assertEqual(lines[-1], '::endgroup::')

    def test_another_process_and_an_uncaught_exception(self):
        report = dict(REPORT, pid=99, faultingThread=0,
                      lastExceptionBacktrace=[{'imageOffset': 0x77, 'symbol': 'objc_exception_throw',
                                               'symbolLocation': 4, 'imageIndex': 1}])
        path = self.write('OXT-Beyond-2026-10-25-022356.ips', json.dumps(HEADER) + '\n' + json.dumps(report))
        with mock.patch.object(ui_tour.shutil, 'which', return_value=None):
            _, lines = self.logged(ui_tour.mac_crash_report, path, 4532)
        self.assertIn('Process     : OXT-Beyond [99]', lines)
        backtrace = lines.index("The uncaught exception's backtrace:")
        self.assertEqual(lines[backtrace + 1].split(), ['0', 'libsystem_kernel.dylib', '0x180000077',
                                                        'objc_exception_throw', '+', '4'])
        # the crashed thread is the main thread: once
        self.assertEqual([x for x in lines if x.startswith('Thread ')],
                         ['Thread 0 (crashed), com.apple.main-thread:'])

    def test_a_text_report_is_logged_as_it_is(self):
        path = self.write('OXT-Beyond_2026-10-25-022355_runner.crash',
                          'Process: OXT-Beyond [4532]\nException Type: EXC_CRASH (SIGABRT)\n')
        _, lines = self.logged(ui_tour.mac_crash_report, path, 4532)
        self.assertEqual(lines[1:3], ['Process: OXT-Beyond [4532]', 'Exception Type: EXC_CRASH (SIGABRT)'])

    def test_waits_for_a_report_only_after_a_crash(self):
        since = time.time()
        for code in (0, 1, -15, -9, None):
            started = time.time()
            count, lines = self.logged(ui_tour.mac_crashes, 'OXT-Beyond', since, 4532, code, wait=3)
            self.assertEqual((count, lines), (0, []), code)
            self.assertLess(time.time() - started, 2, code)
        started = time.time()
        count, lines = self.logged(ui_tour.mac_crashes, 'OXT-Beyond', since, 4532, -11, wait=2)
        self.assertGreaterEqual(time.time() - started, 2)
        self.assertEqual((count, lines), (0, ['(the engine ended on signal 11, and no crash report came in 2 s)']))

    def test_a_report_ends_the_wait(self):
        # (a second early: a file's mtime comes from the kernel's coarse
        # clock, a few milliseconds behind time.time(), so a report written
        # just after since could read as older and the wait ran out)
        since = time.time() - 1
        self.write('OXT-Beyond-2026-10-25-022355.ips', json.dumps(HEADER) + '\n' + json.dumps(REPORT))
        started = time.time()
        with mock.patch.object(ui_tour.shutil, 'which', return_value=None):
            count, lines = self.logged(ui_tour.mac_crashes, 'OXT-Beyond', since, 4532, -6, wait=30)
        self.assertLess(time.time() - started, 5)
        self.assertEqual(count, 1)
        self.assertIn('Termination : Segmentation fault: 11', lines)


class CrashDialog(unittest.TestCase):
    def run_it(self, pkill_status):
        written, ran = [], []
        out = io.StringIO()
        with mock.patch.object(ui_tour, 'mac_defaults', side_effect=lambda *a: written.append(a) or (0, '')), \
                mock.patch.object(ui_tour.shutil, 'which', return_value='/usr/bin/pkill'), \
                mock.patch.object(ui_tour.subprocess, 'run',
                                  side_effect=lambda cmd, **kw: ran.append(cmd) or mock.Mock(returncode=pkill_status)), \
                contextlib.redirect_stdout(out):
            ui_tour.mac_no_crash_dialog()
        return written, ran, out.getvalue().splitlines()

    def test_turned_off_and_one_left_open_is_closed(self):
        written, ran, lines = self.run_it(0)
        self.assertEqual(written, [('write', 'com.apple.CrashReporter', 'DialogType', '-string', 'none'),
                                   ('write', 'com.apple.CrashReporter', 'UseUNC', '-bool', 'true')])
        self.assertEqual(ran, [['pkill', '-x', 'Problem Reporter']])
        self.assertEqual(lines, ['The Mac: no crash dialog (com.apple.CrashReporter DialogType none, UseUNC 1)',
                                 'Closed a crash dialog an earlier run left open (Problem Reporter)'])

    def test_none_left_open(self):
        _, ran, lines = self.run_it(1)
        self.assertEqual(ran, [['pkill', '-x', 'Problem Reporter']])
        self.assertEqual(lines, ['The Mac: no crash dialog (com.apple.CrashReporter DialogType none, UseUNC 1)'])


class TheLog(unittest.TestCase):
    """The tour prints the script's lines, and a line can hold a character
    the console cannot show: the xTalk Assistant's mark is U+2726, and
    Windows' console on CI writes cp1252. On #311's Windows build the tour
    finished every step and print() then raised UnicodeEncodeError, which
    failed both screenshot steps. Such a character is logged escaped."""

    def run_it(self, encoding, msg):
        raw = io.BytesIO()
        out = io.TextIOWrapper(raw, encoding=encoding, newline='\n')
        with mock.patch.object(sys, 'stdout', out):
            ui_tour.log(msg)
        out.flush()
        return raw.getvalue().decode(encoding)

    def test_a_character_the_console_cannot_show(self):
        line = 'INFO xtalk-assistant: field "Mark" (\u2726) whole'
        self.assertEqual(self.run_it('cp1252', line),
                         'INFO xtalk-assistant: field "Mark" (\\u2726) whole\n')

    def test_a_line_the_console_can_show(self):
        self.assertEqual(self.run_it('cp1252', 'STEP icon-chooser ok \u00e9'), 'STEP icon-chooser ok \u00e9\n')
        self.assertEqual(self.run_it('utf-8', 'mark \u2726'), 'mark \u2726\n')

    def test_an_empty_line(self):
        self.assertEqual(self.run_it('cp1252', ''), '\n')


TOUR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ui-tour.livecodescript')


def handler(script, kind, name):
    start = script.index('\n%s %s' % (kind, name))
    return script[start:script.index('\nend %s\n' % name, start)]


class SystemSwitch(unittest.TestCase):
    """A post through osascript never reached an observer on a CI Mac
    (probe, macos-15, 2026-10-31), so the step saw no
    systemAppearanceChanged whatever the engine did: the switch is posted
    by a compiled Swift program, and the step still fails without the
    message."""

    def setUp(self):
        with open(TOUR, encoding='utf-8') as f:
            self.script = f.read()

    def test_posts_with_a_native_program(self):
        set_ = handler(self.script, 'command', 'tourSystemSet')
        self.assertNotIn('osascript', set_)
        self.assertIn('tourThemePoster()', set_)
        self.assertIn('defaults write -g AppleInterfaceStyle Dark', set_)
        self.assertIn('defaults delete -g AppleInterfaceStyle', set_)

    def test_the_poster_posts_the_notification_and_stays_for_it(self):
        poster = handler(self.script, 'function', 'tourThemePoster')
        self.assertIn('xcrun swiftc', poster)
        self.assertIn('DistributedNotificationCenter.default().postNotificationName(', poster)
        self.assertIn('"AppleInterfaceThemeChangedNotification"', poster)
        self.assertIn('deliverImmediately: true', poster)
        self.assertIn('RunLoop.main.run(until:', poster)
        # cannot build it: the step fails, it does not pass having posted nothing
        self.assertIn('throw "could not build the theme poster:"', poster)

    def test_the_step_still_needs_the_message(self):
        step = handler(self.script, 'on', 'tour_system_switch')
        self.assertIn('"no systemAppearanceChanged for the switch to"', step)
        self.assertIn('if tFails is not empty then throw', step)
        self.assertIn('item 1 of tSeen is not tTarget', step)


class GtkTheme(unittest.TestCase):
    """--gtk-theme: the tour under a GTK 2 theme a desktop ships, by its
    name (the menus' marks under MATE's and Yaru's dark themes, tperry2x,
    openxtalk.org p=25972), else Adwaita of the appearance or plain
    colours, as before."""

    def setUp(self):
        self.work = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.work)
        os.makedirs(os.path.join(self.work, 'themes', 'BlackMATE', 'gtk-2.0'))
        with open(os.path.join(self.work, 'themes', 'BlackMATE', 'gtk-2.0', 'gtkrc'), 'w') as f:
            f.write('# a theme\n')
        patch = mock.patch.object(ui_tour, 'THEMES', os.path.join(self.work, 'themes'))
        patch.start()
        self.addCleanup(patch.stop)

    def gtkrc(self, *args):
        with contextlib.redirect_stdout(io.StringIO()):
            return ui_tour.linux_gtkrc(*args)

    def test_a_theme_by_its_name(self):
        self.assertEqual(self.gtkrc('dark', self.work, 'BlackMATE'),
                         os.path.join(self.work, 'themes', 'BlackMATE', 'gtk-2.0', 'gtkrc'))

    def test_a_theme_not_installed_stops_the_run(self):
        with self.assertRaises(ui_tour.rlc.CheckError):
            self.gtkrc('dark', self.work, 'Yaru-dark')

    def test_without_one_as_before(self):
        with mock.patch.object(ui_tour, 'ADWAITA', {'dark': os.path.join(self.work, 'none')}):
            path = self.gtkrc('dark', self.work)
        self.assertEqual(path, os.path.join(self.work, 'gtkrc-dark'))
        with open(path) as f:
            self.assertIn('bg[NORMAL] = "#353535"', f.read())

    def test_the_marks_on_a_windows_own_colours(self):
        # a menu in a window with a colour of its own takes that colour:
        # its marks must stand out from it, dark and light (until rc.6.14
        # they were black on a dark one: tperry2x, p=25972)
        with open(TOUR, encoding='utf-8') as f:
            tour = f.read()
        step = tour.split('on tour_menu_marks', 1)[1].split('end tour_menu_marks', 1)[0]
        self.assertIn('put "48,52,58" & return & "236,236,236" into tColours', step)
        self.assertIn('set the backgroundColor of stack tName to tColour', step)
        self.assertIn('tourMarksCheck("03d-menu-marks-own-colour-" & tPass', step)
        self.assertIn('tourMarksCheck("03b-menu-marks", "03c-menu-no-marks"', step)
        check = tour.split('function tourMarksCheck', 1)[1].split('end tourMarksCheck', 1)[0]
        self.assertIn('if item 6 of tGroup <= 127 then', check)
        self.assertIn('if tMarks < 3 then', check)

    def test_the_linux_package_runs_the_marks_under_them(self):
        repo = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')
        with open(os.path.join(repo, '.github', 'workflows', 'build-linux.yml'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('mate-themes ubuntu-mate-themes yaru-theme-gtk gtk2-engines-murrine', text)
        step = text.split('- name: Menu marks, other dark GTK themes', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn('for theme in Yaru-MATE-dark Yaru-dark HighContrastInverse; do', step)
        self.assertIn('--appearance dark --gtk-theme "$theme" --only menu-marks', step)
        self.assertIn('exit 1', step)
        with open(TOUR, encoding='utf-8') as f:
            tour = f.read()
        steps = [line for line in tour.splitlines() if line.startswith('constant kSteps')][0]
        self.assertIn('menu-marks', steps.split('"')[1].split(','))


class InspectorTabClicks(unittest.TestCase):
    """inspector-tabs clicks the icons in the Inspector's header with the
    system's mouse and reads the section shown. It read 1.5 s after each
    click, and on macOS 26 (#340's run 41757813518, 4 November) it read
    "Effects" after the click on Icons. That click came after the step's
    20-second watchdog, whose full-screen shot ran inside the step's
    "wait ... with messages" and used up the wait: the click was handled
    after the read. (The same job passed on a re-run.) The step now waits
    for the section, a quarter second at a time, each time back through
    the event loop, for up to 6 s; a click that never shows its section
    still fails. tourClickWorks waits the same way for its button's
    mouseUp, since a late one there would leave the header unclicked
    without a failure."""

    def setUp(self):
        with open(TOUR, encoding='utf-8-sig') as f:
            self.script = f.read()

    def test_the_step_waits_for_the_section_it_clicked(self):
        step = handler(self.script, 'on', 'tour_inspector_tabs')
        self.assertIn('put tourInspectorSectionAfterClick(tPI, tLabel, 6000) into tShown', step)
        # not a fixed wait and then one read
        self.assertNotIn('dispatch function "inspectorSectionGetName"', step)

    def test_a_click_that_never_shows_its_section_still_fails(self):
        step = handler(self.script, 'on', 'tour_inspector_tabs')
        self.assertIn('if tShown is not tLabel then', step)
        self.assertIn('throw "a click on a section\'s icon in the inspector\'s header did not show it', step)

    def test_the_wait_goes_back_through_the_event_loop_each_time(self):
        wait = handler(self.script, 'function', 'tourInspectorSectionAfterClick')
        loop = wait.split('repeat', 1)[1].split('end repeat', 1)[0]
        self.assertIn('tourWait 250', loop)
        self.assertIn('dispatch function "inspectorSectionGetName" to stack pStack', loop)
        self.assertIn('if tShown is pSection then exit repeat', loop)
        # counted in turns of the loop, not by the clock, which a watchdog
        # inside a turn would run down
        self.assertIn('repeat (pMilliseconds div 250) times', wait)

    def test_the_click_check_waits_for_the_mouseUp(self):
        check = handler(self.script, 'function', 'tourClickWorks')
        after = check.split('tourClick item 1 of tLoc, item 2 of tLoc', 1)[1]
        loop = after.split('end repeat', 1)[0]
        self.assertIn('repeat 24 times', loop)
        self.assertIn('tourWait 250', loop)
        self.assertIn('if the cTourClicked of button "Click" of card 1 of stack tStack is true then exit repeat', loop)


if __name__ == '__main__':
    unittest.main()


class DictionaryPage(unittest.TestCase):
    """LiveCode's Dictionary opened blank on Windows in the dark appearance
    (the tour's 13-dictionary, rc.6.11 to rc.6.15) while the step passed:
    its checks read the page, not the screen. The step now reads the
    page's part of the screen, and fails when it is one colour, after the
    snapshot that shows it."""

    def setUp(self):
        with open(TOUR, encoding='utf-8') as f:
            self.script = f.read()

    def test_the_step_reads_the_screen_and_fails_after_the_snapshot(self):
        step = handler(self.script, 'on', 'tour_dictionary')
        read = step.index('tourDictionaryBlank(tNew, "as it opened")')
        shot = step.index('tourShotStack tNew, "13-dictionary"')
        throw = step.index('if tBlank is not empty then throw tBlank')
        self.assertLess(read, shot)
        self.assertLess(shot, throw)

    def test_one_colour_is_blank(self):
        blank = handler(self.script, 'function', 'tourDictionaryBlank')
        self.assertIn('tourDictionarySpread(pStack)', blank)
        self.assertIn('if tSpread >= 48 then return empty', blank)
        self.assertIn('tourUnlockScreen', blank)

    def test_the_tools_palette_is_left_out(self):
        spread = handler(self.script, 'function', 'tourDictionarySpread')
        self.assertIn('the contentRect of stack pStack', spread)
        self.assertIn('the effective rect of stack "revTools"', spread)
        self.assertIn('import snapshot from rect tRect', spread)


class DictionaryFitsItsPage(unittest.TestCase):
    """The fix for the blank Dictionary: the browser widget, set to
    0,0,0,0 as the window opens, is fitted to the window once it is open,
    not only on a resizeStack or browserNavigateComplete (neither came on
    Windows for a window that opened at the width it had: its widget read
    0,0,1,1, and a resizeStack drew the page)."""

    BEHAVIOR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'ide', 'Toolset',
                            'palettes', 'dictionary', 'behaviors', 'revdictionarybehavior.livecodescript')

    def setUp(self):
        with open(self.BEHAVIOR, encoding='utf-8-sig') as f:
            self.script = f.read()

    def test_open_stack_fits_the_page_once_the_window_is_open(self):
        open_stack = handler(self.script, 'on', 'openStack')
        self.assertIn('set the rect of widget "Dictionary" of me to 0,0,0,0', open_stack)
        fit = open_stack.index('send "dictFitPage" to me in 0 milliseconds')
        self.assertGreater(fit, open_stack.index('unlock screen'))

    def test_the_fit_is_the_resize(self):
        fit = handler(self.script, 'on', 'dictFitPage')
        self.assertIn('if the mode of me is not 0 then', fit)
        self.assertIn('resizeStack', fit)
        self.assertIn('set the rect of widget "Dictionary" of me to the contentRect of me',
                      handler(self.script, 'on', 'resizeStack'))
