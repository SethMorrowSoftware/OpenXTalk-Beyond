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

import os
import re
import unittest

EXAMPLES = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'examples')


def read(name):
    with open(os.path.join(EXAMPLES, name), encoding='utf-8') as f:
        return f.read()


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


if __name__ == '__main__':
    unittest.main()
