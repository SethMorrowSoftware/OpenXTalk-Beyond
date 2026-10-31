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


if __name__ == '__main__':
    unittest.main()
