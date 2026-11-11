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

"""The real-mouse check of Learn Box2D (tools/examples/learn-box2d-clicks.py)
waits for what a click must show, and still fails a click that shows
nothing.

The check reads what the window shows from a file the engine writes ten
times a second, when it is free to. It used to read that file a fixed
moment after each click (0.3 to 0.8 s). On a busy runner the engine had
not handled the click by then, or had not written since, so the check read
the state from BEFORE the click and failed a click that worked: in the
Linux package job of 10 November 2026, "Shapes: clicking b2NewBody
explains it (it says: b2NewWorld(...))", the line clicked just before,
and "Sliders: Scripts opens the drawer" a moment before "Scripts shuts it"
passed. Now a click that must show something is followed by a wait for it
(Run.click_until), up to five seconds; a turn of the wheel by a wait for
the list to scroll; an arrow key by a wait for the card.

These run the driver's own code against a stand-in window that shows what
each click did only some time after it, with the driver's clock, so no
engine and no real time are needed:

  python3 -m unittest discover -s tools/ci/tests
"""

import importlib.util
import os
import unittest

EXAMPLES = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'examples')

NAMES = ['b2NewWorld', 'b2NewBody', 'b2AddBox', 'b2AddCircle', 'b2AddCapsule', 'b2AddPolygon',
         'b2BodyX', 'b2BodyY', 'b2BodyAngle', 'b2Step', 'b2SetGravity', 'b2DeleteWorld']


def read(name):
    with open(os.path.join(EXAMPLES, name), encoding='utf-8') as f:
        return f.read()


def driver():
    """learn-box2d-clicks.py as a module (its name has dashes)"""
    spec = importlib.util.spec_from_file_location('learn_box2d_clicks', os.path.join(EXAMPLES, 'learn-box2d-clicks.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Clock:
    """The driver's clock (the module's time): a sleep is all that passes"""

    def __init__(self):
        self.now = 0.0

    def time(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


class Window:
    """A stand-in for the engine, Learn Box2D and the probe. The engine
    handles a click, a turn of the wheel or a key `lag` seconds after it
    is made, in the order they were made, and the state shows it from
    then on: a busy machine. A click is handled where it was made (the
    clickLoc), against the list as it is scrolled by then.

    The list of calls shows five lines of twelve; a turn of the wheel
    scrolls three lines, and not past either end: its end, 112 pixels
    down, is not a whole number of lines, so the driver counts lines 6 to
    10 as shown there and turns the wheel for the last, as it does in
    every lesson of the real stack. A name in `mute` is a line that
    explains nothing when clicked (the bug the check is for),
    `wheel=False` is a list the wheel does not scroll, and `lose` is how
    many of the wheel's first turns scroll nothing."""

    CALLS = (20, 200, 240, 300)
    HEIGHT, MARGIN = 17, 4
    # (how far down the list's end is, when not where the box's height puts it)
    END = None
    ACTIONS = {'back': (700, 600, 760, 630), 'next': (800, 600, 860, 630), 'scripts': (900, 20, 980, 50)}

    def __init__(self, module, clock, lag, mute=(), wheel=True, lose=0):
        self.module, self.clock, self.lag = module, clock, lag
        self.mute, self.wheel, self.lose = set(mute), wheel, lose
        self.turns = 0
        self.cards = ['Start'] + module.LESSONS
        self.card = 'Start'
        self.scroll = 0
        self.doc = ''
        self.drawer = False
        self.mouse = (0, 0)
        self.due = []
        self.clicked = []

    def made(self, what):
        self.due.append((self.clock.time() + self.lag, what, self.mouse))

    def turn(self, way):
        self.card = self.cards[max(1, min(len(self.cards) - 1, self.cards.index(self.card) + way))]

    def handle(self):
        m = self.module
        while self.due and self.due[0][0] <= self.clock.time():
            _, what, (x, y) = self.due.pop(0)

            def within(r):
                return r[0] <= x <= r[2] and r[1] <= y <= r[3]
            if what in ('wheel down', 'wheel up'):
                self.turns += 1
                if self.wheel and self.turns > self.lose and within(self.CALLS):
                    most = len(NAMES) * self.HEIGHT + 2 * self.MARGIN - (self.CALLS[3] - self.CALLS[1])
                    if self.END is not None:
                        most = self.END
                    step = 3 * self.HEIGHT if what == 'wheel down' else -3 * self.HEIGHT
                    self.scroll = max(0, min(most, self.scroll + step))
            elif what == 'Right':
                self.turn(1)
            elif what == 'Left':
                self.turn(-1)
            elif within(self.CALLS):
                line = int((y - self.CALLS[1] - self.MARGIN + self.scroll) // self.HEIGHT)
                if 0 <= line < len(NAMES):
                    self.clicked.append(NAMES[line])
                    if NAMES[line] not in self.mute:
                        self.doc = NAMES[line] + '(world): what it does'
            elif within(self.ACTIONS['scripts']):
                self.drawer = not self.drawer
            elif within(self.ACTIONS['next']):
                self.turn(1)
            elif within(self.ACTIONS['back']):
                self.turn(-1)
            elif abs(x - m.SIDEBAR_X) < 90:
                line = int(round((y - m.SIDEBAR_Y) / float(m.SIDEBAR_STEP)))
                if 0 <= line < len(self.cards):
                    self.card = self.cards[line]

    def state(self):
        self.handle()
        return {'card': self.card,
                'calls': '%d,%d,%d,%d' % self.CALLS,
                'callsheight': str(self.HEIGHT),
                'callsmargin': str(self.MARGIN),
                'callsscroll': str(self.scroll),
                'callnames': ','.join(NAMES) + ',',
                'calldoc': self.doc,
                'drawer': 'true' if self.drawer else 'false',
                'actions': ''.join('%s:%d,%d,%d,%d;' % ((name,) + r) for name, r in sorted(self.ACTIONS.items()))}


def stand_in(module, window):
    """The driver's own Run (its click, click_until, key and wait_for), with
    the window in place of the screen, the mouse and the state file"""

    class StandIn(module.Run):
        def __init__(self):
            self.fails = 0
            self.dx = self.dy = 0
            self.results = []

        def state(self):
            return window.state()

        def errors(self):
            return ''

        def xdo(self, *words):
            window.handle()
            if words[0] == 'mousemove':
                window.mouse = (words[1], words[2])
            elif words[0] == 'click':
                window.made({1: 'click', 4: 'wheel up', 5: 'wheel down'}[words[1]])
            elif words[0] == 'key':
                window.made(words[1])

        def shot(self, name):
            pass

        def check(self, ok, what, detail=''):
            self.results.append((bool(ok), what, detail))
            return ok

    return StandIn()


class Waits(unittest.TestCase):
    TOTAL = 'Shapes: each of its 12 Box2D calls, clicked, says what it does'

    def a_window(self, lag, **more):
        module = driver()
        clock = Clock()
        module.time = clock
        window = Window(module, clock, lag, **more)
        return module, clock, window, stand_in(module, window)

    # -- a click that works, shown late

    def test_a_list_that_answers_late_passes(self):
        # (1.2 s: later than every fixed moment the check used to read at)
        module, clock, window, run = self.a_window(1.2)
        module.calls(run, 'Shapes')
        self.assertEqual(run.results, [(True, self.TOTAL, '12 of 12')])
        # each line was clicked once, where it was: no turn of the wheel
        # was made on a scroll read too soon (three turns reach the list's
        # end, and two more that scroll nothing find it)
        self.assertEqual(window.clicked, NAMES)
        self.assertEqual(window.turns, 5)

    def test_a_list_that_answers_at_once_is_not_waited_for(self):
        module, clock, window, run = self.a_window(0.05)
        module.calls(run, 'Shapes')
        self.assertEqual(run.results, [(True, self.TOTAL, '12 of 12')])
        self.assertEqual(window.clicked, NAMES)
        # 12 clicks of 0.38 s and a read, three turns of the wheel, and
        # the two at the list's end, waited for: less than the 30 turns
        # (4.5 s) that the last line alone cost before
        self.assertEqual(window.turns, 5)
        self.assertLess(clock.now, 12 * 0.5 + 3 * 0.3 + 2 * (0.15 + module.ANSWER / 2 + 0.1))

    def test_the_lists_end_is_found_once(self):
        # two lines below the lines counted as shown at the list's end,
        # as in the real stack (Shapes: 13 lines, 6 counted as shown, its
        # end 97 pixels down, so lines 5 to 10): the second of them turns
        # the wheel no more
        module, clock, window, run = self.a_window(0.05)
        window.END = 100
        module.calls(run, 'Shapes')
        self.assertEqual(run.results, [(True, self.TOTAL, '12 of 12')])
        self.assertEqual(window.clicked, NAMES)
        self.assertEqual(window.turns, 2 + 2)

    def test_a_turn_of_the_wheel_that_scrolls_nothing_is_made_again(self):
        # (one turn that scrolls nothing is not yet the list's end)
        module, clock, window, run = self.a_window(0.05, lose=1)
        module.calls(run, 'Shapes')
        self.assertEqual(run.results, [(True, self.TOTAL, '12 of 12')])
        self.assertEqual(window.clicked, NAMES)

    def test_a_drawer_that_opens_late(self):
        module, clock, window, run = self.a_window(2.0)
        x, y = module.middle(Window.ACTIONS['scripts'])
        # read a fixed moment after the click, it is the state from before
        self.assertEqual(run.click(x, y, settle=0.6).get('drawer'), 'false')
        clock.sleep(3)
        self.assertEqual(run.state().get('drawer'), 'true')
        # waited for, it is the state the click made
        st = run.click_until(x, y, lambda s: s.get('drawer') == 'false', settle=0.6)
        self.assertEqual(st.get('drawer'), 'false')
        self.assertFalse(window.drawer)

    def test_the_arrow_keys_and_back_and_next_shown_late(self):
        module, clock, window, run = self.a_window(1.2)
        module.keys(run)
        self.assertEqual(run.results, [
            (True, 'the right arrow key goes to the next lesson', 'Shapes'),
            (True, 'the left arrow key goes back', 'Bodies'),
            (True, 'Back and Next are there', ''),
            (True, 'Next goes to the next lesson', 'Shapes'),
            (True, 'Back goes back', 'Bodies')])

    # -- a click that does not work still fails

    def test_a_line_that_explains_nothing_fails(self):
        module, clock, window, run = self.a_window(0.05, mute=['b2AddCircle'])
        module.calls(run, 'Shapes')
        self.assertEqual(run.results, [
            (False, 'Shapes: clicking b2AddCircle explains it', 'it says: b2AddBox(world): what it does'),
            (False, self.TOTAL, '11 of 12')])
        # it had the whole wait, and was clicked once
        self.assertEqual(window.clicked.count('b2AddCircle'), 1)
        self.assertGreater(clock.now, module.ANSWER)

    def test_a_click_that_shows_nothing_has_the_wait_and_no_more(self):
        module, clock, window, run = self.a_window(0.05)
        st = run.click_until(500, 400, lambda s: s.get('drawer') == 'true', settle=0.6)
        self.assertEqual(st.get('drawer'), 'false')
        self.assertGreaterEqual(clock.now, 0.6 + module.ANSWER)
        self.assertLess(clock.now, 0.6 + module.ANSWER + 0.5)

    def test_a_list_that_explains_nothing_fails_in_good_time(self):
        # (193 calls are clicked in a run: were each given five seconds, a
        # stack whose list says nothing would end in the job's time running
        # out, not in its FAIL lines)
        module, clock, window, run = self.a_window(0.05, mute=NAMES)
        module.calls(run, 'Shapes')
        self.assertEqual([r[0] for r in run.results], [False] * 13)
        self.assertEqual(run.results[-1], (False, self.TOTAL, '0 of 12'))
        self.assertEqual(window.clicked, NAMES)
        # two lines had the whole wait, the other ten half a second
        self.assertLess(clock.now, 2 * (module.ANSWER + 0.5) + 10 * 1.0 + 3 * 0.3 + 2 * (0.15 + module.ANSWER / 2 + 0.1))

    def test_a_list_the_wheel_does_not_scroll_fails_in_good_time(self):
        module, clock, window, run = self.a_window(0.05, wheel=False)
        module.calls(run, 'Shapes')
        # the lines in the box are clicked (five, and the top of the
        # sixth); the six below it are not there to click
        self.assertEqual(window.clicked, NAMES[:6])
        self.assertEqual(run.results[-1], (False, self.TOTAL, '6 of 12'))
        self.assertEqual(len(run.results), 7)
        # two turns of the wheel, waited for, and two lines' whole wait
        self.assertEqual(window.turns, 2)
        self.assertLess(clock.now, 2 * (0.15 + module.ANSWER / 2 + 0.1) + 2 * (module.ANSWER + 0.5) + 10 * 1.0)


class TheLesson(unittest.TestCase):
    """What lesson() and front() click, read from the driver: what a click
    must show is waited for, and what it must NOT change is still read a
    fixed moment after it (a wait for "nothing changed" would return at
    once, before the click was handled)"""

    def setUp(self):
        text = read('learn-box2d-clicks.py')
        self.lesson = text.split('\ndef lesson(', 1)[1].split('\ndef ', 1)[0]
        self.front = text.split('\ndef front(', 1)[1].split('\ndef ', 1)[0]

    def test_pause_and_play(self):
        self.assertIn("st = run.click_until(*middle(lab['LabPause']), lambda s: s.get('pause') == 'Play', settle=0.4)\n"
                      "    run.check(st.get('pause') == 'Play', '%s: Pause shows Play' % name", self.lesson)
        self.assertIn("st = run.click_until(*middle(lab['LabPause']), lambda s: s.get('pause') == 'Pause', settle=0.4)\n"
                      "    run.check(st.get('pause') == 'Pause', '%s: Pause again runs it' % name", self.lesson)

    def test_step_keeps_it_paused_after_a_fixed_moment(self):
        self.assertIn("st = run.click(*middle(lab['LabStep']), settle=0.4)\n"
                      "    run.check(st.get('pause') == 'Play', '%s: Step keeps it paused' % name", self.lesson)
        self.assertIn("    before = st.get('dynamic')\n    time.sleep(0.5)\n    st = run.state()\n"
                      "    run.check(st.get('dynamic') == before, '%s: paused, nothing moves' % name)", self.lesson)

    def test_the_scripts_drawer(self):
        self.assertIn("st = run.click_until(*middle(scripts[0]), lambda s: s.get('drawer') == 'true', settle=0.6)\n"
                      "        run.check(st.get('drawer') == 'true', '%s: Scripts opens the drawer' % name)", self.lesson)
        self.assertIn("st = run.click_until(*middle(scripts[0]), lambda s: s.get('drawer') == 'false', settle=0.6)\n"
                      "        run.check(st.get('drawer') == 'false', '%s: Scripts shuts it' % name)", self.lesson)

    def test_reset(self):
        # the two seconds it always had, then the wait, and the same test
        # of "made again" for the wait and the check
        self.assertIn("    st = run.click(*middle(lab['LabReset']), settle=1.0)\n    time.sleep(1.0)\n"
                      "    st = run.wait_for(made_again, ANSWER)\n    run.check(made_again(st),", self.lesson)
        self.assertIn("    def made_again(s):\n        return not stopped(s) and "
                      "abs(int(s.get('bodies', 0)) - start_bodies) <= max(3, start_bodies // 4)\n", self.lesson)

    def test_the_front_pages_tile(self):
        self.assertIn("st = run.click_until(*middle(tiles[5]), lambda s: s.get('card') == 'Hinges', settle=0.6)\n"
                      "        run.check(st.get('card') == 'Hinges', 'Start: the sixth tile goes to Hinges'", self.front)


if __name__ == '__main__':
    unittest.main()
