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

"""The script tests on Android (tools/ci/android_tests.py): what prepare
puts beside the tests' stack, the app's lines in the device's log, the run
that follows the app through a crash, a test that never ends and a lost
END (a stand-in device that plays the app's script), the results against
a baseline and the two engines' comparison; the tests' standalone in
tools/ci/android-check.livecodescript and its script,
tools/ci/android-tests.livecodescript; and the job in android-engine.yml.
No Android SDK, device or engine is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import json
import os
import re
import sys
import tempfile
import unittest
from unittest import mock

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import android_check  # noqa: E402
import android_tests as at  # noqa: E402
import run_engine_tests  # noqa: E402


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def line(text, pid=4321, level='I'):
    """A line of the device's log (logcat -v brief) of the app's put."""
    return '%s/LiveCode(%5d): OXTTESTS %s\n' % (level, pid, text)


class Says(unittest.TestCase):

    def test_the_apps_lines(self):
        self.assertEqual(at.says(line('BEGIN 3')), 'BEGIN 3')
        self.assertEqual(at.says(line('TAP 3 1 ok - script compiles  ')), 'TAP 3 1 ok - script compiles')
        self.assertEqual(at.says('W/LiveCode(  12): OXTTESTS END\r\n'), 'END')

    def test_not_the_apps(self):
        self.assertIsNone(at.says('I/LiveCode( 4321): OXT-Beyond probe: copy file x'))
        self.assertIsNone(at.says('I/ActivityManager( 500): OXTTESTS BEGIN 3'))
        self.assertIsNone(at.says('I/LiveCode( 4321): something OXTTESTS BEGIN 3'))


class RunLines(unittest.TestCase):

    def test_a_test_from_begin_to_done(self):
        r = at.Run()
        for text in ('COUNT 2', 'BEGIN 1', 'TAP 1 1 ok - script compiles', 'TAP 1 2 ok - it works',
                     'DONE 1'):
            r.said(text, 10)
        self.assertEqual(r.count, 2)
        self.assertEqual(r.done, {1})
        self.assertIsNone(r.current)
        self.assertEqual(r.tap[1], ['ok - script compiles', 'ok - it works'])
        outcome, counts, text, details, failures = at.result_of(r, 1)
        self.assertEqual(outcome, 'pass')
        self.assertEqual(counts['pass'], 2)
        self.assertEqual(details, [])

    def test_two_same_lines_are_both_counted(self):
        # the place in the output keeps them apart in the log, and both
        # count
        r = at.Run()
        for text in ('BEGIN 1', 'TAP 1 1 not ok - same', 'TAP 1 2 not ok - same', 'DONE 1'):
            r.said(text)
        outcome, counts, _, _, failures = at.result_of(r, 1)
        self.assertEqual((outcome, counts['fail']), ('fail', 2))
        self.assertEqual(failures, ['not ok - same', 'not ok - same'])

    def test_a_skip_and_a_quit(self):
        r = at.Run()
        for text in ('BEGIN 1', 'TAP 1 1 ok - script compiles', 'TAP 1 2 ok # SKIP needs the IDE', 'DONE 1',
                     'BEGIN 2', 'QUIT 2', 'TAP 2 1 ok - x', 'DONE 2'):
            r.said(text)
        self.assertEqual(at.result_of(r, 1)[0], 'skip')
        outcome, _, _, details, _ = at.result_of(r, 2)
        self.assertEqual(outcome, 'fail')
        self.assertIn('the test quit', details[0])

    def test_not_begun_and_not_ended(self):
        r = at.Run()
        r.said('BEGIN 1')
        self.assertEqual(at.result_of(r, 1)[3], ['the test did not end'])
        self.assertEqual(at.result_of(r, 2)[3], ['the test did not begin'])
        r.stopped('the app stopped')
        self.assertIsNone(r.current)
        self.assertEqual(at.result_of(r, 1), ('fail', at.result_of(r, 1)[1], '', ['the app stopped'], []))

    def test_resume_end_and_error(self):
        r = at.Run()
        for text in ('RESUME 7', 'END', 'ERROR cannot read oxt-tests/x'):
            r.said(text)
        self.assertEqual(r.resumed, [7])
        self.assertTrue(r.ended)
        self.assertEqual(r.error, 'cannot read oxt-tests/x')


class FakeDevice:
    """The tests' app on a stand-in device: it plays the tests (behaviour:
    {line: 'pass', 'fail', 'crash', 'hang', 'quit' (the runner cancels it,
    the test passes) or 'quit-ends'}) as the runner
    script does, resuming after the last test that began, one test each
    time it is asked for its lines; a clock moves with the check's sleep.
    Started with tests to run again (start(again)), it says AGAIN and runs
    those alone (again_behaviour: how they go then), then END, unless it
    ignores_again. lose: {start: {line: 'all', 'after-begin', 'begin' or
    'done'}}, the lines of a test that the device's log loses in that start
    (all of them, all but its BEGIN, its BEGIN or its DONE), while the app
    goes on."""

    def __init__(self, count, behaviour=None, lose_end=False, crash_at_start=0, lose=None,
                 again_behaviour=None, ignores_again=False, lose_again_said=False):
        self.count = count
        self.behaviour = behaviour or {}
        self.again_behaviour = again_behaviour or {}
        self.lose_end = lose_end
        self.crash_at_start = crash_at_start
        self.lose = lose or {}
        self.ignores_again = ignores_again
        self.lose_again_said = lose_again_said
        self.now = 0.0
        self.progress = None
        self.running = False
        self.next = None
        self.queue = None
        self.pending = []
        self.starts = 0
        self.stops = 0
        self.hung = False
        self.agains = []
        self.dropped_lines = []

    def clock(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds

    def start(self, again=None):
        if self.running:
            # am start brings a running app to the front: its script does
            # not start again (after its END, the app is still running)
            return
        self.starts += 1
        if again is not None:
            self.agains.append(list(again))
        if self.starts <= self.crash_at_start:
            self.running = False
            return
        self.running = True
        self.hung = False
        self.pending.append(line('COUNT %d' % self.count))
        self.queue = None
        if again is not None and not self.ignores_again:
            self.queue = list(again)
            if not self.lose_again_said:
                self.pending.append(line(('AGAIN ' + ','.join(str(n) for n in again)).rstrip()))
            return
        self.next = 1
        if self.progress is not None:
            self.pending.append(line('RESUME %d' % self.progress))
            self.next = self.progress + 1

    def take(self):
        out, self.pending = self.pending, []
        if not (self.running and not self.hung and not out):
            return out
        if self.queue is not None:
            if not self.queue:
                self.queue = None
                self.next = self.count + 2
                return [line('END')]
            n = self.queue.pop(0)
            what = self.again_behaviour.get(n, 'pass')
        else:
            if self.next > self.count:
                if not self.lose_end:
                    out.append(line('END'))
                self.running = self.running and not self.lose_end
                self.next += 1
                return out
            n = self.next
            what = self.behaviour.get(n, 'pass')
            self.next += 1
        self.progress = n
        said = [line('BEGIN %d' % n)]
        if what == 'crash':
            self.running = False
        elif what == 'hang':
            self.hung = True
        elif what == 'quit-ends':
            said.append(line('QUIT %d' % n))
            self.running = False
        else:
            if what == 'quit':
                said.append(line('QUIT %d' % n))
            said.append(line('TAP %d 1 ok - script compiles' % n))
            said.append(line('TAP %d 2 %s - test %d' % (n, 'ok' if what == 'pass' else 'not ok', n)))
            said.append(line('DONE %d' % n))
        lost = self.lose.get(self.starts, {}).get(n)
        if lost == 'all':
            said = []
        elif lost == 'after-begin':
            said = said[:1]
        elif lost == 'begin':
            said = said[1:]
        elif lost == 'done':
            said = [x for x in said if ' DONE ' not in x]
        return out + said

    def pid(self):
        return '4321' if self.running else ''

    def stop(self):
        self.stops += 1
        self.running = False

    def last_words(self, pid):
        return ['F/libc    ( %s): Fatal signal 11 (SIGSEGV)' % pid]

    def dropped(self):
        return self.dropped_lines


def follow(device, count, timeout=60, restarts=5, start_timeout=120, **kw):
    reported = []
    with contextlib.redirect_stdout(io.StringIO()):
        r = at.run_tests(device, count, timeout, restarts, start_timeout=start_timeout, clock=device.clock,
                         sleep=device.sleep, report=lambda n, result: reported.append((n, result[0])), **kw)
    return r, reported


class RunTests(unittest.TestCase):

    def test_every_test_in_one_start(self):
        d = FakeDevice(3, {2: 'fail'})
        r, reported = follow(d, 3)
        self.assertTrue(r.ended)
        self.assertEqual(r.starts, 1)
        self.assertEqual(reported, [(1, 'pass'), (2, 'fail'), (3, 'pass')])
        self.assertEqual(d.stops, 0)

    def test_a_crash_is_a_failure_and_the_run_goes_on(self):
        d = FakeDevice(4, {2: 'crash'})
        r, reported = follow(d, 4)
        self.assertTrue(r.ended)
        self.assertEqual(r.starts, 2)
        self.assertEqual(r.resumed, [2])
        self.assertEqual(dict(reported), {1: 'pass', 2: 'fail', 3: 'pass', 4: 'pass'})
        details = at.result_of(r, 2)[3]
        self.assertTrue(details[0].startswith('the app stopped'))
        self.assertIn('Fatal signal 11', details[0])

    def test_a_test_that_never_ends_is_stopped(self):
        d = FakeDevice(3, {1: 'hang'})
        r, reported = follow(d, 3, timeout=30)
        self.assertTrue(r.ended)
        self.assertEqual(d.stops, 1)
        self.assertEqual(dict(reported), {1: 'fail', 2: 'pass', 3: 'pass'})
        self.assertIn('did not end within 30 seconds', at.result_of(r, 1)[3][0])

    def test_a_quit_that_ends_the_app(self):
        d = FakeDevice(2, {1: 'quit-ends'})
        r, reported = follow(d, 2)
        self.assertTrue(r.ended)
        outcome, _, _, details, _ = at.result_of(r, 1)
        self.assertEqual(outcome, 'fail')
        self.assertIn('the test quit', details[0])
        self.assertEqual(dict(reported)[2], 'pass')

    def test_the_end_lost_after_the_last_test(self):
        d = FakeDevice(2, lose_end=True)
        r, reported = follow(d, 2)
        self.assertFalse(r.ended)
        self.assertEqual(r.starts, 1)
        self.assertEqual(dict(reported), {1: 'pass', 2: 'pass'})

    def test_an_app_that_begins_nothing_twice(self):
        d = FakeDevice(2, crash_at_start=5)
        with self.assertRaises(android_check.CheckError) as e:
            follow(d, 2)
        self.assertIn('began no test in two starts', str(e.exception))

    def test_one_start_that_begins_nothing_is_started_again(self):
        d = FakeDevice(2, crash_at_start=1)
        r, reported = follow(d, 2)
        self.assertTrue(r.ended)
        self.assertEqual(r.starts, 2)
        self.assertEqual(dict(reported), {1: 'pass', 2: 'pass'})

    def test_restarts_are_counted(self):
        d = FakeDevice(6, {1: 'crash', 2: 'crash', 3: 'crash', 4: 'crash'})
        r, reported = follow(d, 6, restarts=2)
        self.assertFalse(r.ended)
        self.assertEqual(r.starts, 3)
        self.assertEqual(dict(reported), {1: 'fail', 2: 'fail', 3: 'fail'})
        self.assertEqual(at.result_of(r, 5)[3], ['the test did not begin'])

    def test_lines_the_log_lost_are_run_again(self):
        # run 43093019217: BEGIN of a test, then nothing of it or of the
        # next three while the app went on, so the four "did not end" and
        # "did not begin" though they ran; they are run again, alone, and
        # their results are those of that run
        d = FakeDevice(7, lose={1: {2: 'after-begin', 3: 'all', 4: 'all', 5: 'all'}})
        r, reported = follow(d, 7)
        self.assertTrue(r.ended)
        self.assertEqual(r.starts, 2)
        self.assertEqual(d.agains, [[2, 3, 4, 5]])
        # stopped after its END, or am start would not start its script
        self.assertEqual(d.stops, 1)
        self.assertEqual(r.again, [2, 3, 4, 5])
        self.assertEqual(dict(reported), dict((n, 'pass') for n in range(1, 8)))
        for n in range(1, 8):
            outcome, counts, _, details, _ = at.result_of(r, n)
            self.assertEqual((n, outcome, counts['pass']), (n, 'pass', 2))
        self.assertIn('run again', at.result_of(r, 2)[3][0])
        self.assertEqual(at.result_of(r, 1)[3], [])

    def test_a_test_run_again_keeps_only_its_new_output(self):
        r = at.Run()
        for text in ('BEGIN 1', 'TAP 1 1 not ok - half of it', 'AGAIN 1', 'BEGIN 1', 'TAP 1 1 ok - all of it',
                     'DONE 1'):
            r.said(text)
        self.assertEqual(r.tap[1], ['ok - all of it'])
        self.assertEqual(r.again_said, [1])
        self.assertEqual(at.result_of(r, 1)[0], 'pass')

    def test_the_last_test_run_again_after_its_done_was_lost(self):
        # the app said END after it: the test it last began is not taken
        # for the one running when it is started again, whose time limit
        # would have run out long since
        d = FakeDevice(3, lose={1: {3: 'after-begin'}})
        r, reported = follow(d, 3, timeout=0)
        self.assertEqual(d.agains, [[3]])
        self.assertEqual(d.stops, 1)
        self.assertEqual(dict(reported), {1: 'pass', 2: 'pass', 3: 'pass'})
        self.assertEqual(at.result_of(r, 3)[3], [at.AGAIN_NOTE])

    def test_a_test_run_again_keeps_none_of_its_first_output(self):
        # the DONE of its first run was lost, and the BEGIN of its run
        # again: its output is that of the run again alone
        d = FakeDevice(3, {2: 'fail'}, lose={1: {2: 'done'}, 2: {2: 'begin'}})
        r, reported = follow(d, 3)
        self.assertEqual(d.agains, [[2]])
        self.assertEqual(r.tap[2], ['ok - script compiles', 'ok - test 2'])
        self.assertEqual(dict(reported), {1: 'pass', 2: 'pass', 3: 'pass'})
        self.assertEqual(at.result_of(r, 2)[1], at.analyse_tap('ok\nok')[0])

    def test_the_check_of_the_way_back_in_takes_a_lost_begin(self):
        # the test the check runs again said DONE, its BEGIN lost: it ran
        d = FakeDevice(3, lose={2: {1: 'begin'}})
        r, reported = follow(d, 3, again_check=True)
        self.assertEqual(d.agains, [[1]])
        self.assertEqual(dict(reported), {1: 'pass', 2: 'pass', 3: 'pass'})

    def test_a_test_run_again_keeps_no_quit_of_its_first_run(self):
        # it quit in its first run, whose DONE was lost, and not in its
        # run again: its result is that of the run again
        d = FakeDevice(3, {2: 'quit'}, lose={1: {2: 'done'}})
        r, reported = follow(d, 3)
        self.assertEqual(d.agains, [[2]])
        self.assertEqual(dict(reported), {1: 'pass', 2: 'pass', 3: 'pass'})
        self.assertEqual(at.result_of(r, 2)[3], [at.AGAIN_NOTE])
        # and one that quits in its run again too fails
        d = FakeDevice(3, {2: 'quit'}, lose={1: {2: 'done'}}, again_behaviour={2: 'quit'})
        r, reported = follow(d, 3)
        self.assertEqual(dict(reported), {1: 'pass', 2: 'fail', 3: 'pass'})

    def test_the_check_of_the_way_back_in_keeps_the_first_result_of_a_quit(self):
        # the test the check runs again quits that time: its result is
        # still that of its first run
        d = FakeDevice(3, again_behaviour={1: 'quit-ends'})
        r, reported = follow(d, 3, again_check=True)
        self.assertEqual(d.agains, [[1]])
        self.assertEqual(dict(reported), {1: 'pass', 2: 'pass', 3: 'pass'})
        self.assertEqual([at.result_of(r, n)[0] for n in (1, 2, 3)], ['pass'] * 3)
        self.assertEqual(at.result_of(r, 1)[3], [])

    def test_a_test_run_again_that_stops_the_app_fails_with_why(self):
        d = FakeDevice(4, lose={1: {2: 'all'}}, again_behaviour={2: 'crash'})
        r, reported = follow(d, 4)
        self.assertEqual(d.agains, [[2]])
        self.assertEqual(dict(reported), {1: 'pass', 2: 'fail', 3: 'pass', 4: 'pass'})
        details = at.result_of(r, 2)[3]
        self.assertTrue(details[0].startswith('the app stopped'), details)
        self.assertEqual(r.starts, 2)

    def test_lines_lost_again_are_run_again_a_few_times_at_most(self):
        lose = dict((start, {2: 'all'}) for start in range(1, 10))
        d = FakeDevice(3, lose=lose)
        r, reported = follow(d, 3, again_starts=3)
        self.assertEqual(d.agains, [[2], [2], [2]])
        self.assertEqual(r.starts, 4)
        outcome, _, _, details, _ = at.result_of(r, 2)
        self.assertEqual(outcome, 'fail')
        self.assertEqual(details[0], 'the test did not begin')
        self.assertIn('run again', details[1])

    def test_an_app_that_ignores_the_tests_to_run_again(self):
        # the way back in must work: a run that cannot run them again says
        # so, rather than taking an app that resumed for one that ran them
        d = FakeDevice(3, lose={1: {2: 'all'}}, ignores_again=True)
        with self.assertRaises(android_check.CheckError) as e:
            follow(d, 3)
        self.assertIn('did not take the tests to run again', str(e.exception))
        self.assertIn('it resumed', str(e.exception))

    def test_a_lost_again_line_is_no_failure(self):
        # the app's AGAIN is a line of the log too: the tests it runs say
        # that it took them
        d = FakeDevice(3, lose={1: {2: 'all'}}, lose_again_said=True)
        r, reported = follow(d, 3)
        self.assertEqual(d.agains, [[2]])
        self.assertEqual(dict(reported), {1: 'pass', 2: 'pass', 3: 'pass'})

    def test_the_check_of_the_way_back_in(self):
        # again_check: with nothing lost, the app is started once more to
        # run again the first test that passed, which must begin and end;
        # the results stay those of the first run, even when it fails then
        d = FakeDevice(3, {1: 'fail'}, again_behaviour={2: 'fail'})
        r, reported = follow(d, 3, again_check=True)
        self.assertTrue(r.ended)
        self.assertEqual(r.starts, 2)
        self.assertEqual(d.agains, [[2]])
        self.assertEqual(r.again, [])
        self.assertEqual(dict(reported), {1: 'fail', 2: 'pass', 3: 'pass'})
        self.assertEqual([at.result_of(r, n)[0] for n in (1, 2, 3)], ['fail', 'pass', 'pass'])
        self.assertEqual(at.result_of(r, 2)[3], [])
        # it must take them
        d = FakeDevice(3, ignores_again=True)
        with self.assertRaises(android_check.CheckError):
            follow(d, 3, again_check=True)
        # and run the test
        d = FakeDevice(3, lose={2: {1: 'all'}})
        with self.assertRaises(android_check.CheckError) as e:
            follow(d, 3, again_check=True)
        self.assertIn('did not run it', str(e.exception))
        # a run with no test that passed: none to run, and END
        d = FakeDevice(2, {1: 'fail', 2: 'fail'})
        r, reported = follow(d, 2, again_check=True)
        self.assertEqual(d.agains, [[]])
        self.assertEqual(r.starts, 2)

    def test_tests_after_the_last_start_gave_up_are_not_run_again(self):
        # they did not run: no line of theirs was lost
        d = FakeDevice(6, {1: 'crash', 2: 'crash', 3: 'crash', 4: 'crash'})
        r, reported = follow(d, 6, restarts=2)
        self.assertEqual(d.agains, [])
        self.assertEqual(r.again, [])

    def test_the_apps_error_stops_the_run(self):
        d = FakeDevice(2)
        d.take = lambda: [line('ERROR the package has no oxt-tests/files.txt')]
        with self.assertRaises(android_check.CheckError) as e:
            follow(d, 2)
        self.assertIn('files.txt', str(e.exception))


class Results(unittest.TestCase):

    def test_judge(self):
        results = {'lcs: a: TestA': 'fail', 'lcs: b: TestB': 'fail', 'lcs: c: TestC': 'pass',
                   'lcs: d: TestD': 'pass', 'lcs: e: TestE': 'skip'}
        known = {'lcs: a: TestA': False, 'lcs: c: TestC': False, 'lcs: d: TestD': True, 'lcs: e: TestE': False}
        failing, new, fixed = at.judge(results, known)
        self.assertEqual(failing, ['lcs: a: TestA', 'lcs: b: TestB'])
        self.assertEqual(new, ['lcs: b: TestB'])
        # a "?" entry that passed, and a skip, are not fixed
        self.assertEqual(fixed, ['lcs: c: TestC'])

    def test_write_baseline_keeps_comments_and_maybes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, 'b.txt')
            with open(path, 'w', encoding='utf-8') as f:
                f.write('# old\nlcs: a: TestA  # why a\n? lcs: m: TestM  # sometimes\nlcs: gone: TestG\n')
            at.write_baseline(path, 'beyond', ['lcs: a: TestA', 'lcs: n: TestN'],
                              run_engine_tests.baseline_entries(path))
            text = open(path, encoding='utf-8').read()
        self.assertIn('built with the beyond engine', text)
        self.assertIn('lcs: a: TestA  # why a\n', text)
        self.assertIn('? lcs: m: TestM  # sometimes\n', text)
        self.assertIn('lcs: n: TestN\n', text)
        self.assertNotIn('TestG', text)

    def test_differences(self):
        old = {'lcs: a: A': 'pass', 'lcs: b: B': 'fail', 'lcs: c: C': 'skip', 'lcs: d: D': 'fail',
               'lcs: e: E': 'pass'}
        new = {'lcs: a: A': 'fail', 'lcs: b: B': 'pass', 'lcs: c: C': 'fail', 'lcs: d: D': 'fail',
               'lcs: e: E': 'pass'}
        worse, better = at.differences(old, new)
        self.assertEqual(worse, ['lcs: a: A'])
        self.assertEqual(better, ['lcs: b: B'])

    def test_compare_decides_only_when_strict(self):
        with tempfile.TemporaryDirectory() as tmp:
            old, new = os.path.join(tmp, 'old.json'), os.path.join(tmp, 'new.json')
            with open(old, 'w') as f:
                json.dump({'engine': '9.6.3', 'results': {'lcs: a: A': 'pass'}}, f)
            with open(new, 'w') as f:
                json.dump({'engine': 'beyond', 'results': {'lcs: a: A': 'fail'}}, f)
            out = io.StringIO()
            with contextlib.redirect_stdout(out), mock.patch.dict(os.environ, {'GITHUB_STEP_SUMMARY': ''}):
                self.assertEqual(at.main(['compare', '--old', old, '--new', new]), 0)
                self.assertEqual(at.main(['compare', '--old', old, '--new', new, '--strict']), 1)
        self.assertIn('1 test(s) fail with beyond and pass with 9.6.3', out.getvalue())

    def test_run_command_judges_against_the_engines_baseline(self):
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, at.TESTS_JSON), 'w') as f:
                json.dump(['x: TestOne', 'x: TestTwo', 'x: TestThree'], f)
            os.makedirs(os.path.join(tmp, 'out'))
            open(os.path.join(tmp, 'out', 'debug.apk'), 'wb').close()
            baseline = os.path.join(tmp, 'baseline.txt')
            with open(baseline, 'w') as f:
                f.write('lcs: x: TestTwo\nlcs: x: TestThree\n')
            d = FakeDevice(3, {1: 'fail', 2: 'fail'})
            d.install = lambda apk: None
            d.listen = d.close = lambda: None

            real = at.run_tests

            def runs(device, count, timeout, restarts, report=None, **kw):
                return real(device, count, timeout, restarts, clock=d.clock, sleep=d.sleep, report=report, **kw)
            out = io.StringIO()
            with mock.patch.object(at, 'Device', lambda adb, serial: d), \
                    mock.patch.object(at, 'adb_path', lambda sdk: '/adb'), \
                    mock.patch.object(at, 'run_tests', runs), \
                    mock.patch.dict(os.environ, {'GITHUB_STEP_SUMMARY': '', 'GITHUB_ACTIONS': ''}), \
                    contextlib.redirect_stdout(out):
                status = at.main(['run', '--work', tmp, '--serial', 'emulator-5554', '--sdk', tmp,
                                  '--engine', 'beyond', '--baseline', baseline])
            with open(os.path.join(tmp, 'android-tests-beyond.json')) as f:
                results = json.load(f)
            log = open(os.path.join(tmp, 'android-tests-beyond.log')).read()
        self.assertEqual(status, 1)
        self.assertEqual(results['engine'], 'beyond')
        self.assertEqual(results['results'], {'lcs: x: TestOne': 'fail', 'lcs: x: TestTwo': 'fail',
                                              'lcs: x: TestThree': 'pass'})
        text = out.getvalue()
        self.assertIn('NEW   lcs: x: TestOne', text)
        self.assertIn('FIXED lcs: x: TestThree', text)
        self.assertIn('### FAIL lcs: x: TestOne\n', log)
        self.assertIn('### FAIL lcs: x: TestTwo (in the baseline)', log)


    def test_run_command_says_what_was_run_again(self):
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, at.TESTS_JSON), 'w') as f:
                json.dump(['x: TestOne', 'x: TestTwo', 'x: TestThree'], f)
            os.makedirs(os.path.join(tmp, 'out'))
            open(os.path.join(tmp, 'out', 'debug.apk'), 'wb').close()
            baseline = os.path.join(tmp, 'baseline.txt')
            open(baseline, 'w').close()
            d = FakeDevice(3, lose={1: {2: 'after-begin'}})
            d.dropped_lines = ['I/liblog  (    0): 12']
            d.install = lambda apk: None
            d.listen = d.close = lambda: None
            real = at.run_tests
            seen = {}

            def runs(device, count, timeout, restarts, report=None, **kw):
                seen.update(kw)
                return real(device, count, timeout, restarts, clock=d.clock, sleep=d.sleep, report=report, **kw)
            out = io.StringIO()
            summary = os.path.join(tmp, 'summary.md')
            with mock.patch.object(at, 'Device', lambda adb, serial: d), \
                    mock.patch.object(at, 'adb_path', lambda sdk: '/adb'), \
                    mock.patch.object(at, 'run_tests', runs), \
                    mock.patch.dict(os.environ, {'GITHUB_STEP_SUMMARY': summary, 'GITHUB_ACTIONS': ''}), \
                    contextlib.redirect_stdout(out):
                status = at.main(['run', '--work', tmp, '--serial', 'emulator-5554', '--sdk', tmp,
                                  '--engine', 'beyond', '--baseline', baseline, '--again-check'])
            log = open(os.path.join(tmp, 'android-tests-beyond.log')).read()
            md = open(summary).read()
        self.assertEqual(status, 0)
        self.assertEqual(seen, {'again_starts': at.AGAIN_STARTS, 'again_check': True})
        self.assertEqual(d.agains, [[2]])
        text = out.getvalue()
        self.assertIn('  AGAIN lcs: x: TestTwo: pass', text)
        self.assertIn("The device's log on the lines it dropped: I/liblog  (    0): 12", text)
        self.assertIn("Run again (the device's log lost their lines): x: TestTwo\n", log)
        self.assertIn('I/liblog', log)
        self.assertIn('lcs: x: TestTwo: pass', md)


class Prepare(unittest.TestCase):

    def make_ide(self, tmp, extensions=('com.livecode.library.json',), toolchain=False):
        ide = os.path.join(tmp, 'ide')
        for name in extensions:
            os.makedirs(os.path.join(ide, 'Extensions', name, 'resources'))
            with open(os.path.join(ide, 'Extensions', name, 'module.lcm'), 'wb') as f:
                f.write(b'lcm')
            with open(os.path.join(ide, 'Extensions', name, 'resources', 'r.txt'), 'w') as f:
                f.write('r')
        if toolchain:
            os.makedirs(os.path.join(ide, 'Toolchain', 'modules', 'lci'))
            open(os.path.join(ide, 'Toolchain', 'lc-compile'), 'w').close()
        return ide

    def make_repo(self, tmp):
        repo = os.path.join(tmp, 'repo')
        os.makedirs(os.path.join(repo, 'tests', 'lcs', 'core'))
        os.makedirs(os.path.join(repo, 'engine', 'src'))
        os.makedirs(os.path.join(repo, 'ide', 'Toolset', 'libraries'))
        for name in at.ERROR_FILES:
            with open(os.path.join(repo, *name.split('/')), 'w') as f:
                f.write('// errors\n')
        with open(os.path.join(repo, 'tests', '_testlib.livecodescript'), 'w') as f:
            f.write('script "_testlib"\n')
        with open(os.path.join(repo, 'tests', 'lcs', 'core', 'one.livecodescript'), 'w') as f:
            f.write('script "one"\non TestSetup\nend TestSetup\non TestOne\n'
                    '   TestLoadExtension "com.livecode.library.json"\n'
                    '   get TestGetIDERepositoryPath() & "/Toolset/libraries/lib a.livecodescript"\n'
                    'end TestOne\non TestTwo\nend TestTwo\n')
        with open(os.path.join(repo, 'ide', 'Toolset', 'libraries', 'lib a.livecodescript'), 'w') as f:
            f.write('script "lib a"\n')
        return repo

    def test_prepare(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, ide = self.make_repo(tmp), self.make_ide(tmp)
            work = os.path.join(tmp, 'work')
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(at.main(['prepare', '--work', work, '--ide', ide, '--repo', repo]), 0)
            files = open(os.path.join(work, 'oxt-tests', 'files.txt')).read().splitlines()
            listing = open(os.path.join(work, 'oxt-tests', 'android-tests.txt')).read()
            tests = json.load(open(os.path.join(work, at.TESTS_JSON)))
            self.assertTrue(os.path.isfile(os.path.join(work, at.SCRIPT_NAME)))
            self.assertTrue(os.path.isfile(os.path.join(
                work, 'packaged_extensions', 'com.livecode.library.json', 'module.lcm')))
            self.assertTrue(os.path.isfile(os.path.join(
                work, 'packaged_extensions', 'com.livecode.library.json', 'resources', 'r.txt')))
            # every file listed is there, in oxt-tests
            for name in files:
                self.assertTrue(os.path.isfile(os.path.join(work, 'oxt-tests', *name.split('/'))), name)
        self.assertEqual(listing, 'tests/lcs/core/one.livecodescript\tTestOne\n'
                                  'tests/lcs/core/one.livecodescript\tTestTwo\n')
        self.assertEqual(tests, ['core/one: TestOne', 'core/one: TestTwo'])
        self.assertIn('tests/_testlib.livecodescript', files)
        self.assertIn('engine/src/executionerrors.h', files)
        self.assertIn('ide/Toolset/libraries/lib a.livecodescript', files)
        self.assertEqual(files[-1], 'android-tests.txt')
        self.assertNotIn('files.txt', files)

    def test_a_font_file_is_not_copied(self):
        # the Android builder moves a copied font into assets/fonts/, where
        # the runner does not look: the app stopped on it before any test
        with tempfile.TemporaryDirectory() as tmp:
            repo, ide = self.make_repo(tmp), self.make_ide(tmp)
            os.makedirs(os.path.join(repo, 'engine', 'rsrc', 'fonts'))
            for name in ('A.ttf', 'B.otf', 'C.ttc', 'D.txt'):
                with open(os.path.join(repo, 'engine', 'rsrc', 'fonts', name), 'w') as f:
                    f.write('x')
            with open(os.path.join(repo, 'tests', 'lcs', 'core', 'fonts.livecodescript'), 'w') as f:
                f.write('script "fonts"\non TestFonts\n' + ''.join(
                    '   get TestGetEngineRepositoryPath() & "/engine/rsrc/fonts/%s"\n' % n
                    for n in ('A.ttf', 'B.otf', 'C.ttc', 'D.txt')) + 'end TestFonts\n')
            work = os.path.join(tmp, 'work')
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(at.main(['prepare', '--work', work, '--ide', ide, '--repo', repo]), 0)
            files = open(os.path.join(work, 'oxt-tests', 'files.txt')).read().splitlines()
        self.assertIn('engine/rsrc/fonts/D.txt', files)
        for name in ('A.ttf', 'B.otf', 'C.ttc'):
            self.assertNotIn('engine/rsrc/fonts/' + name, files)

    def test_the_font_test_is_the_builders(self):
        # the builder's own test, which the check follows
        source = open(os.path.join(at.REPO,
                                   'ide-support', 'revsblibrary.livecodescript'), encoding='utf-8').read()
        self.assertIn('return (pFile ends with ".ttf" or pFile ends with ".ttc" or pFile ends with ".otf")', source)

    def test_an_extension_the_ide_lacks(self):
        # said, and the tests that load it fail on the device
        with tempfile.TemporaryDirectory() as tmp:
            repo, ide = self.make_repo(tmp), self.make_ide(tmp, extensions=())
            work = os.path.join(tmp, 'w')
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(at.main(['prepare', '--work', work, '--ide', ide, '--repo', repo]), 0)
            self.assertFalse(os.path.exists(os.path.join(work, 'packaged_extensions', 'com.livecode.library.json')))
        self.assertIn('NOTE: the tests load extensions that the IDE does not have', out.getvalue())
        self.assertIn('com.livecode.library.json', out.getvalue())

    def test_the_filter(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, ide = self.make_repo(tmp), self.make_ide(tmp)
            work = os.path.join(tmp, 'work')
            with contextlib.redirect_stdout(io.StringIO()):
                at.main(['prepare', '--work', work, '--ide', ide, '--repo', repo, '--filter', 'TestTwo'])
            self.assertEqual(json.load(open(os.path.join(work, at.TESTS_JSON))), ['core/one: TestTwo'])

    def test_find_ide_tools(self):
        with tempfile.TemporaryDirectory() as tmp:
            ide = self.make_ide(tmp, toolchain=True)
            found = at.find_ide_tools(ide)
            self.assertEqual(found['lc-compile'], os.path.join(ide, 'Toolchain', 'lc-compile'))
            self.assertEqual(found['modules'], os.path.join(ide, 'Toolchain', 'modules', 'lci'))
            self.assertEqual(found['extensions'], os.path.join(ide, 'Extensions'))
            self.assertEqual(at.find_ide_tools(os.path.join(tmp, 'nothing')),
                             {'lc-compile': None, 'modules': None, 'extensions': None})

    def test_the_tests_of_the_checkout(self):
        # the checkout's own tests: each listed once, and every file
        # files.txt names copied, with no IDE (no extensions)
        with tempfile.TemporaryDirectory() as tmp:
            work = os.path.join(tmp, 'work')
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(at.main(['prepare', '--work', work, '--ide', tmp]), 0)
            files = open(os.path.join(work, 'oxt-tests', 'files.txt')).read().splitlines()
            tests = json.load(open(os.path.join(work, at.TESTS_JSON)))
            for name in files:
                self.assertTrue(os.path.isfile(os.path.join(work, 'oxt-tests', *name.split('/'))), name)
        self.assertEqual(len(tests), len(set(tests)))
        self.assertGreater(len(tests), 1000)
        self.assertIn('tests/_testrunnerbehavior.livecodescript', files)
        self.assertIn('tests/_testlib.livecodescript', files)
        self.assertIn('tests/_inputlib.livecodescript', files)


class Standalone(unittest.TestCase):
    """The tests' standalone, as android-check.livecodescript makes it, and
    its script."""

    @classmethod
    def setUpClass(cls):
        cls.check = read('tools', 'ci', 'android-check.livecodescript')
        cls.runner = read('tools', 'ci', 'android-tests.livecodescript')

    def constant(self, name):
        m = re.search(r'(?m)^constant %s = "([^"]*)"' % name, self.check)
        self.assertTrue(m, name)
        return m.group(1)

    def test_names_agree(self):
        self.assertEqual(self.constant('kTestsScript'), at.SCRIPT_NAME)
        self.assertEqual(self.constant('kTestsFiles').split(','), [at.TESTS_FOLDER, at.EXTENSIONS_FOLDER])
        self.assertEqual(self.constant('kTestsIdentifier'), at.IDENTIFIER)
        self.assertEqual(android_check.PROBES['tests'], 'StandaloneTestRunnerMainstack.livecode')
        self.assertIn('return "StandaloneTestRunnerMainstack"', self.check)
        self.assertEqual(os.path.basename(at.RUNNER_SCRIPT), at.SCRIPT_NAME)
        # the stack's name tells the test library that it runs in a
        # standalone
        self.assertIn('"StandaloneTestRunnerMainstack" is among the lines of the mainstacks',
                      read('tests', '_testlib.livecodescript'))

    def test_the_build_settings(self):
        block = self.check[self.check.index('if probeName() is "StandaloneTestRunnerMainstack" then\n'
                                            '      put kTestsIdentifier'):]
        block = block[:block.index('end if')]
        self.assertIn('["android,application permissions"]["INTERNET"]', block)
        self.assertIn('put kTestsFiles into tSettings["files"]', block)

    def test_the_runner_says_what_the_check_reads(self):
        said = re.findall(r'androidSay "([A-Z]+)"', self.runner)
        self.assertEqual(set(said), {'COUNT', 'RESUME', 'AGAIN', 'BEGIN', 'TAP', 'DONE', 'END', 'ERROR'})
        self.assertIn('constant kPrefix = "OXTTESTS"', self.runner)
        # QUIT from its backscript
        self.assertIn('kPrefix && "QUIT "', self.runner)
        self.assertIn('androidSay "TAP" && sIndex && tPlace && tLine', self.runner)
        # a put with no container: the engine's log line on Android
        self.assertIn('put kPrefix && pLine\n', self.runner)
        self.assertIn('constant kFolder = "%s"' % at.TESTS_FOLDER, self.runner)
        self.assertIn('android-tests.txt', self.runner)
        self.assertIn('files.txt', self.runner)

    def test_the_runner_runs_only_in_the_app(self):
        block = self.runner[self.runner.index('on openStack'):self.runner.index('end openStack')]
        self.assertIn('the environment is not "mobile"', block)

    def test_the_runner_resumes_after_the_last_test_begun(self):
        start = self.runner[self.runner.index('on androidTestsStart'):self.runner.index('end androidTestsStart')]
        self.assertIn('androidSay "RESUME" && tLast', start)
        self.assertIn('put tLast + 1 into sIndex', start)
        step = self.runner[self.runner.index('on androidTestsNext'):self.runner.index('end androidTestsNext')]
        # the progress is written before the test begins
        self.assertLess(step.index('kProgressFile'), step.index('androidSay "BEGIN"'))
        self.assertLess(step.index('androidSay "BEGIN"'), step.index('TestRunnerInvokeTestCommand'))

    def test_the_runner_runs_again_the_tests_it_is_given(self):
        # the launch's extra that run gives it, read with
        # mobileGetLaunchData(), which LiveCode 9.6.3's engine has too
        self.assertIn('constant kAgainExtra = "%s"' % at.AGAIN_EXTRA, self.runner)
        self.assertIn('constant kAgainNone = "%s"' % at.AGAIN_NONE, self.runner)
        lines = self.runner[self.runner.index('private function androidAgainLines'):
                            self.runner.index('end androidAgainLines')]
        self.assertIn('mobileGetLaunchData()', lines)
        self.assertIn('tData["extras"][kAgainExtra]', lines)
        start = self.runner[self.runner.index('on androidTestsStart'):self.runner.index('end androidTestsStart')]
        # it says so before any test, and does not resume then
        self.assertLess(start.index('androidSay "COUNT"'), start.index('androidAgainLines()'))
        self.assertLess(start.index('androidSay "AGAIN" && tAgain'), start.index('kProgressFile'))
        self.assertIn('exit androidTestsStart', start[start.index('androidSay "AGAIN"'):start.index('kProgressFile')])
        step = self.runner[self.runner.index('on androidTestsNext'):self.runner.index('end androidTestsNext')]
        self.assertIn('put item 1 of sAgain into sIndex', step)
        # the item delimiter is still the comma there
        self.assertLess(step.index('item 1 of sAgain'), step.index('set the itemDelimiter to tab'))
        self.assertIn('if sAgainMode is not true then\n      add 1 to sIndex', step)
        self.assertEqual(step.count('androidSay "END"'), 2)

    def test_the_scripts_declare_their_variables(self):
        # every t* variable a handler uses is declared in it (a script set by
        # the IDE may be compiled with explicit variables)
        for text in (self.runner,):
            for m in re.finditer(r'(?ms)^(?:private )?(?:on|command|function) (\w+)(.*?)^end \1', text):
                body = m.group(2)
                declared = set()
                for d in re.findall(r'(?m)^\s*local ([^\n]+)', body):
                    declared.update(x.strip() for x in d.split(','))
                params = set(x.strip() for x in body.split('\n', 1)[0].split(',') if x.strip())
                used = set(re.findall(r'\bt[A-Z]\w*', body))
                self.assertFalse(used - declared - params, '%s: %s' % (m.group(1), used - declared - params))


class Workflow(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            import yaml
        except ImportError:
            raise unittest.SkipTest('no PyYAML')
        cls.text = read('.github', 'workflows', 'android-engine.yml')
        cls.wf = yaml.safe_load(cls.text)
        cls.job = cls.wf['jobs']['tests']
        cls.steps = dict((s.get('name'), s) for s in cls.job['steps'])

    def test_runs_after_the_build(self):
        self.assertEqual(self.job['needs'], 'build')
        self.assertIn('android-engine-*', self.steps['Download the runtime']['with']['pattern'])

    def test_both_engines_are_built(self):
        run = self.steps['Build the tests\' standalone with each engine']['run']
        self.assertIn('for engine in 9.6.3 beyond', run)
        self.assertIn('android_tests.py prepare --work "$WORK/tests-$engine" --ide "$IDE"', run)
        self.assertIn('--probe tests', run)
        self.assertIn('--builds debug', run)
        self.assertIn('flag=(--android-engine beyond)', run)
        self.assertIn('overlay --root "$WORK/ide" --beyond "$WORK/engine"',
                      self.steps['Unpack the IDE, and put this builder and the runtime into it']['run'])

    def test_both_engines_run_then_compare(self):
        run = self.steps['Run the tests with each engine']['run']
        self.assertIn('--engine 9.6.3', run)
        self.assertIn('--engine beyond', run)
        self.assertIn('--check-engine "$WORK/engine"', run)
        # each run shows that the tests whose lines the log lost can be
        # run again
        self.assertEqual(run.count('--again-check'), 2)
        self.assertLess(run.index('--engine 9.6.3'), run.index('--engine beyond'))
        self.assertLess(run.index('--engine beyond'), run.index('android_tests.py compare'))
        # neither run stops the other or the comparison
        self.assertEqual(run.count('|| status=1'), 2)
        self.assertTrue(run.rstrip().endswith('exit $status'))

    def test_the_emulator_is_awake_and_settled(self):
        run = self.steps['Wait for the emulator']['run']
        self.assertIn('--awake --settle', run)
        self.assertIn('system-images;android-33;google_apis;x86_64',
                      self.steps['Set up the JDK and the Android SDK']['run'])

    def test_the_files_that_start_it(self):
        paths = self.wf[True]['pull_request']['paths']
        for name in ('tools/ci/android_tests.py', 'tools/ci/android-tests.livecodescript',
                     'tools/ci/android-tests-baseline-*.txt'):
            self.assertIn(name, paths)

    def test_the_baselines_are_there(self):
        for engine in at.ENGINES:
            self.assertTrue(os.path.isfile(at.baseline_path(engine)), engine)

    def test_every_baseline_entry_is_a_test_there_is(self):
        # Each entry names a handler of a file of tests/lcs, so that one
        # left behind by a renamed or removed test is found here, not by a
        # baseline that silently stops meaning anything; the files are as
        # write_baseline writes them (its header, then sorted entries)
        for engine in at.ENGINES:
            path = at.baseline_path(engine)
            with open(path, encoding='utf-8') as f:
                text = f.read()
            self.assertTrue(text.startswith(at.BASELINE_HEADER % engine), engine)
            entries = run_engine_tests.baseline_entries(path)
            self.assertTrue(entries, engine)
            idents = [line.split(' #', 1)[0].strip().lstrip('? ')
                      for line in text.splitlines() if line.strip() and not line.startswith('#')]
            self.assertEqual(idents, sorted(set(idents)), engine)
            for ident in entries:
                m = re.match(r'^lcs: (.+): (\w+)$', ident)
                self.assertTrue(m, '%s: %s' % (engine, ident))
                source = os.path.join(REPO, 'tests', 'lcs', m.group(1) + '.livecodescript')
                self.assertTrue(os.path.isfile(source), '%s: %s' % (engine, ident))
                with open(source, encoding='utf-8', errors='replace') as f:
                    self.assertRegex(f.read(), r'(?im)^on %s\b' % m.group(2), '%s: %s' % (engine, ident))

    def test_the_logs_are_kept(self):
        step = self.steps['Upload the results and logs']
        self.assertEqual(step['if'], 'always()')
        self.assertIn('android-tests-*.log', step['with']['path'])


if __name__ == '__main__':
    unittest.main()
