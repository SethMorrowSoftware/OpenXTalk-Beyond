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

"""Learn Box2D grabs the body where the mouse was pressed, read from its
builder (tools/examples/learn-box2d.livecodescript).

A press is handled a moment after it is made. Until 0.2.7-rc.6.17 the Lab
(and the Dragging, Rays and Terrain cards) looked for a body under the
mouse as it was when the press was handled, the mouseLoc, which the engine
asks the screen for there and then. On a busy machine the mouse had moved
on by then: the press grabbed nothing, and "a dragged body follows the
mouse" failed now and then in the Linux package job (Hinges, Bodies). They
now use the clickLoc, kept from the press itself. The real-mouse check in
tools/examples/learn-box2d-clicks.py holds the engine while it presses and
drags (its "pressed while the window is busy" checks), which fails every
time without this; this catches the code going back on every pull request,
without an engine.

  python3 -m unittest discover -s tools/ci/tests
"""

import importlib.util
import os
import re
import unittest

EXAMPLES = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'examples')


def read(name):
    with open(os.path.join(EXAMPLES, name), encoding='utf-8') as f:
        return f.read()


def driver():
    """learn-box2d-clicks.py as a module (its name has dashes)"""
    spec = importlib.util.spec_from_file_location('learn_box2d_clicks', os.path.join(EXAMPLES, 'learn-box2d-clicks.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def handlers(script, name):
    """Every handler of that name (a card's own script has its own
    mouseDown), each from its first line to its end line."""
    found = re.findall(r'^(?:private )?(?:on|command|function) %s\b.*?^end %s$' % (name, name), script, re.M | re.S)
    if not found:
        raise AssertionError('no handler %s' % name)
    return found


class WhereThePressWas(unittest.TestCase):
    def setUp(self):
        self.script = read('learn-box2d.livecodescript')

    def test_the_click_in_metres(self):
        self.assertIn('function labClickX\n   return labMX(the clickH)\nend labClickX', self.script)
        self.assertIn('function labClickY\n   return labMY(the clickV)\nend labClickY', self.script)

    def test_the_labs_grab(self):
        grab = handlers(self.script, 'labGrab')[0]
        self.assertIn('put labClickX() into tX\n   put labClickY() into tY', grab)
        self.assertNotIn('labMouseX', grab)
        self.assertNotIn('labMouseY', grab)

    def test_every_press_in_the_court(self):
        # the Lab's mouseDown and the cards' own: none asks where the
        # mouse is now, and each that asks about the court or a body asks
        # where the press was
        downs = handlers(self.script, 'mouseDown')
        self.assertGreaterEqual(len(downs), 4)
        lab = [d for d in downs if 'labGrab' in d]
        self.assertEqual(len(lab), 1)
        self.assertIn('and the clickLoc is within the rect of graphic "Court" then\n      labGrab', lab[0])
        for down in downs:
            self.assertNotIn('the mouseLoc is within the rect of graphic "Court"', down)
            self.assertNotIn('labMouseX', down)
            self.assertNotIn('labMouseY', down)
        asks = [d for d in downs if 'b2BodyAtPoint' in d]
        # Dragging, Rays and Terrain
        self.assertEqual(len(asks), 3)
        for down in asks:
            self.assertIn('labClickX()', down)
            self.assertIn('labClickY()', down)

    def test_a_drag_still_follows_the_mouse(self):
        # where the mouse is NOW is still the target of a drag
        self.assertIn('b2MouseSetTarget sDrag, labMouseX(), labMouseY()', handlers(self.script, 'labDrag')[0])
        self.assertIn('b2MouseSetTarget sGrab, labMouseX(), labMouseY()', self.script)


class TheCheck(unittest.TestCase):
    def setUp(self):
        self.driver = read('learn-box2d-clicks.py')
        self.probe = read('learn-box2d-clicks.livecodescript')

    def test_the_probe_holds_the_engine(self):
        self.assertIn('if there is a file (sOut & ".hold") then\n      clicksHold', self.probe)
        hold = handlers(self.probe, 'clicksHold')[0]
        # a loop that handles no event, not a wait that might
        self.assertIn('repeat until the milliseconds >= tEnd\n   end repeat', hold)
        self.assertNotIn('with messages', hold)
        self.assertLess(hold.index('put "busy" into URL'), hold.index('repeat until'))
        self.assertLess(hold.index('end repeat'), hold.index('delete file (sOut & ".busy")'))

    def test_the_driver_presses_during_the_hold(self):
        late = self.driver.split('def late_drag(', 1)[1].split('\ndef ', 1)[0]
        self.assertIn('run.hold(2000)', late)
        self.assertLess(late.index('run.hold(2000)'), late.index("run.xdo('mousedown', 1)"))
        # the drag is over before the engine is let go, or the try does
        # not count
        self.assertIn('held = run.busy()', late)
        self.assertIn("why.append('the drag took longer than the hold')", late)
        # the same test of following as a drag on an idle window
        self.assertIn('if moved > 30 and near < moved:', late)

    def test_on_the_labs_grab_and_the_dragging_cards(self):
        self.assertIn("if name in ('Bodies', 'Dragging'):\n        time.sleep(0.5)\n        late_drag(run, name)",
                      self.driver)


class World:
    """A stand-in for the engine, the Lab and the probe, on a clock of its
    own: the bodies where they are on the screen, the engine held or not, a
    press made while it is held handled where it was made once the hold is
    over, and the body it grabbed pulled toward the mouse 20 pixels a step
    (a step is 0.05 s). A body riding the platform goes 1 pixel a step
    to and fro between x 380 and 580 until it is grabbed; a body under the
    platform, grabbed, cannot rise above its line until the platform has
    passed, so many seconds after the grab."""

    COURT = (275, 162, 685, 602)

    def __init__(self, bodies, riding=(), under=None, grabs=True):
        self.clock = 0.0
        self.last = 0.0
        self.bodies = {name: list(where) for name, where in bodies}
        self.riding = {name: 1 for name in riding}
        self.under = dict(under or {})
        self.grabs = grabs
        self.mouse = (0, 0)
        self.held_until = -1.0
        self.press = None
        self.grab = None
        self.grabbed_at = 0.0
        self.pressed = []

    # (the driver's clock: the module's time)
    def time(self):
        return self.clock

    def sleep(self, seconds):
        self.clock += seconds

    def at(self, point):
        near = [(((x - point[0]) ** 2 + (y - point[1]) ** 2) ** 0.5, name) for name, (x, y) in self.bodies.items()]
        near = [n for n in near if n[0] <= 12]
        return min(near)[1] if near and self.grabs else None

    def advance(self):
        while self.last + 0.05 <= self.clock:
            self.last += 0.05
            if self.last < self.held_until:
                continue
            if self.press is not None:
                self.grab, self.grabbed_at, self.press = self.at(self.press), self.last, None
            for name, way in self.riding.items():
                if name != self.grab:
                    body = self.bodies[name]
                    body[0] += way
                    if not 380 <= body[0] <= 580:
                        self.riding[name] = -way
            if self.grab:
                body = self.bodies[self.grab]
                dx, dy = self.mouse[0] - body[0], self.mouse[1] - body[1]
                d = (dx * dx + dy * dy) ** 0.5
                if d:
                    body[0] += dx * min(d, 20) / d
                    body[1] += dy * min(d, 20) / d
                if self.grab in self.under:
                    line, passes = self.under[self.grab]
                    if self.last - self.grabbed_at < passes:
                        body[1] = max(body[1], line)


class StandIn:
    """The driver's Run, over a World"""

    def __init__(self, world):
        self.world = world
        self.results = []

    def check(self, ok, what, detail=''):
        self.results.append((ok, what, detail))
        return ok

    def state(self):
        w = self.world
        w.advance()
        return {'court': '%d,%d,%d,%d' % w.COURT,
                'dynamic': ''.join('%s:%d,%d;' % (n, x, y) for n, (x, y) in w.bodies.items()),
                'free': ','.join(w.bodies) + ','}

    def hold(self, ms):
        self.world.advance()
        self.world.held_until = self.world.clock + ms / 1000.0
        return True

    def busy(self):
        return self.world.clock < self.world.held_until

    def move(self, x, y):
        self.world.mouse = (x, y)

    def xdo(self, *words):
        w = self.world
        w.advance()
        if words[0] == 'mousedown':
            w.pressed.append(w.mouse)
            w.press = w.mouse
        elif words[0] == 'mouseup':
            w.grab = None


class LateDrag(unittest.TestCase):
    """late_drag, run against a stand-in: a body that follows only once
    Bodies' platform has passed over it, a body riding the platform, up to
    six tries, and a press that grabs nothing still failing"""

    LABEL = 'Bodies: a body pressed while the window is busy follows the mouse'

    def run_it(self, world):
        module = driver()
        module.time = world
        run = StandIn(world)
        module.late_drag(run, 'Bodies')
        return run, [r for r in run.results if r[1] == self.LABEL]

    def test_a_box_under_the_platform_follows_once_it_has_passed(self):
        # (as in the package job: pulled up from under it, the box stops
        # 1.4 m up for 2 seconds; the try used to look after 1)
        world = World([('a', (560, 587))], under={'a': (532, 2.0)})
        run, result = self.run_it(world)
        self.assertEqual(result, [(True, self.LABEL, '')])
        self.assertEqual(len(world.pressed), 1)

    def test_a_box_held_down_longer_is_not_followed(self):
        world = World([('a', (560, 587))], under={'a': (532, 99)})
        run, result = self.run_it(world)
        self.assertFalse(result[0][0])
        self.assertIn('a from 560,587 toward 420,322: now', result[0][2])

    def test_a_box_riding_the_platform_is_pressed_where_it_is(self):
        # the first try's box never gets past the platform; the second,
        # riding it, has moved on by then, and is pressed where it is now
        world = World([('a', (560, 587)), ('b', (400, 491))], riding=['b'], under={'a': (532, 99)})
        run, result = self.run_it(world)
        self.assertEqual(result, [(True, self.LABEL, '')])
        self.assertEqual(len(world.pressed), 2)
        self.assertNotEqual(world.pressed[1], (400, 491))

    # (boxes on the floor under the platform, each within 140 pixels
    # across of where it is pulled to, so that what it moves across alone
    # does not pass)
    def floor(self, count):
        return [('h%d' % i, (400 + 25 * i, 587)) for i in range(count)]

    def test_up_to_six_bodies(self):
        held = self.floor(5)
        world = World(held + [('g', (550, 590))], under={n: (532, 99) for n, _ in held})
        run, result = self.run_it(world)
        self.assertEqual(result, [(True, self.LABEL, '')])
        self.assertEqual(len(world.pressed), 6)

    def test_no_more_than_six(self):
        held = self.floor(7)
        world = World(held, under={n: (532, 99) for n, _ in held})
        run, result = self.run_it(world)
        self.assertFalse(result[0][0])
        self.assertEqual(len(world.pressed), 6)
        self.assertEqual(result[0][2].count(' from '), 6)

    def test_a_press_that_grabs_nothing_fails(self):
        world = World([('a', (560, 587)), ('b', (400, 491))], grabs=False)
        run, result = self.run_it(world)
        self.assertFalse(result[0][0])
        self.assertIn('a from 560,587 toward 420,322: now 560,587', result[0][2])
        self.assertIn('b from 400,491 toward 540,322: now 400,491', result[0][2])


class Drag(unittest.TestCase):
    """drag, a body dragged on an idle window, against the same stand-in.
    Until November 2026 it read where the bodies were once, before its
    first try, and looked at each dragged body once, 0.8 s after the drag:
    on a loaded machine Bodies failed it in two runs of six, the floor's
    box stopped under the platform (as in late_drag's package job runs)
    and the box riding the platform pressed where it had been 1.7 s
    before. It now reads the places before each try and gives a grabbed
    body the 4 seconds late_drag gives it; a press that grabs nothing
    still fails, and without the wait."""

    LABEL = 'Bodies: a dragged body follows the mouse'

    def run_it(self, world):
        module = driver()
        module.time = world
        run = StandIn(world)
        module.drag(run, 'Bodies')
        return run, [r for r in run.results if r[1] == self.LABEL]

    def test_a_box_on_the_floor_follows_at_once(self):
        world = World([('a', (560, 587))])
        run, result = self.run_it(world)
        self.assertEqual(result, [(True, self.LABEL, '')])
        self.assertEqual(world.pressed, [(560, 587)])
        # (the quarter second that finds it still, the drag, and the
        # first looks at it)
        self.assertLess(world.clock, 2.5)

    def test_a_box_under_the_platform_follows_once_it_has_passed(self):
        world = World([('a', (560, 587))], under={'a': (532, 2.0)})
        run, result = self.run_it(world)
        self.assertEqual(result, [(True, self.LABEL, '')])
        self.assertEqual(len(world.pressed), 1)

    def test_a_box_held_down_longer_is_not_followed(self):
        world = World([('a', (560, 587))], under={'a': (532, 99)})
        run, result = self.run_it(world)
        self.assertFalse(result[0][0])
        self.assertIn('a from 560,587 toward 420,322: now', result[0][2])

    def test_a_box_riding_the_platform_is_pressed_where_it_is(self):
        # the first try's box never gets past the platform; the second,
        # riding it, has moved on by then, and is pressed where it is now
        world = World([('a', (560, 587)), ('b', (400, 491))], riding=['b'], under={'a': (532, 99)})
        run, result = self.run_it(world)
        self.assertEqual(result, [(True, self.LABEL, '')])
        self.assertEqual(len(world.pressed), 2)
        self.assertNotEqual(world.pressed[1], (400, 491))

    def floor(self, count):
        return [('h%d' % i, (400 + 25 * i, 587)) for i in range(count)]

    def test_up_to_six_bodies(self):
        held = self.floor(5)
        world = World(held + [('g', (550, 590))], under={n: (532, 99) for n, _ in held})
        run, result = self.run_it(world)
        self.assertEqual(result, [(True, self.LABEL, '')])
        self.assertEqual(len(world.pressed), 6)

    def test_no_more_than_six(self):
        held = self.floor(7)
        world = World(held, under={n: (532, 99) for n, _ in held})
        run, result = self.run_it(world)
        self.assertFalse(result[0][0])
        self.assertEqual(len(world.pressed), 6)
        self.assertEqual(result[0][2].count(' from '), 6)

    def test_a_press_that_grabs_nothing_fails_without_the_wait(self):
        world = World([('a', (560, 587)), ('b', (400, 491))], grabs=False)
        run, result = self.run_it(world)
        self.assertFalse(result[0][0])
        self.assertIn('a from 560,587 toward 420,322: now 560,587', result[0][2])
        self.assertIn('b from 400,491 toward 540,322: now 400,491', result[0][2])
        self.assertEqual(len(world.pressed), 2)
        # each try: the places read, the drag, a second for the body to
        # move at all, and the release; not late_drag's 4 seconds a body
        self.assertLess(world.clock, 2 * 2.5 + 1)


if __name__ == '__main__':
    unittest.main()
