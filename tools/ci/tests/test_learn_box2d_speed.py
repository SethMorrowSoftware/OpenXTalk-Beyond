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

"""What keeps the two Box2D Learn stacks cheap to run, read from their
builders (tools/examples/learn-box2d.livecodescript and
learn-box2dxt-kit.livecodescript): Learn Box2D draws nothing while paused,
draws a body only when it moved, asks Box2D for a joint's anchors once,
leaves a line or dot that did not change alone, and both stacks wait while
their window is hidden or made an icon. tools/examples/perf-learn-box2d.py
measures them on a real engine; this catches the code that undoes them on
every pull request, without one.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

EXAMPLES = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'examples')


def read(name):
    with open(os.path.join(EXAMPLES, name), encoding='utf-8') as f:
        return f.read()


def handler(script, name):
    """The handler name's text, from its first line to its end line."""
    m = re.search(r'^(?:private )?(?:on|command|function) %s\b.*?^end %s$' % (name, name), script, re.M | re.S)
    if not m:
        raise AssertionError('no handler %s' % name)
    return m.group(0)


def branches(text):
    """The text of an if/else whose condition is 'not sPaused', split at
    its else."""
    m = re.search(r'if not sPaused then\n(.*?)\n\s*else\n(.*?)\n\s*end if', text, re.S)
    if not m:
        raise AssertionError('no "if not sPaused" in the tick')
    return m.group(1), m.group(2)


class LearnBox2D(unittest.TestCase):
    def setUp(self):
        self.script = read('learn-box2d.livecodescript')

    def test_paused_draws_nothing_and_ticks_slower(self):
        tick = handler(self.script, 'labTick')
        running, paused = branches(tick)
        self.assertIn('labStepOnce', running)
        self.assertNotIn('labDraw', paused)
        self.assertIn('in 50 milliseconds', tick)

    def test_a_button_pressed_while_paused_draws_what_it_changed(self):
        run = handler(self.script, 'labRun')
        self.assertRegex(run, r'if sPaused .*\n\s*labDraw')

    def test_the_window_hidden_holds_the_world(self):
        for name, tick in (('labTick', handler(self.script, 'labTick')),
                           ('frontTick', handler(self.script, 'frontTick'))):
            hidden = tick.index('the iconic of stack sStack')
            self.assertLess(hidden, tick.index('lock screen'), name)
            self.assertIn('in 250 milliseconds', tick, name)

    def test_a_body_is_drawn_only_when_it_moved(self):
        draw = handler(self.script, 'labDrawBody')
        self.assertIn('b2BodyIsAwake', draw)
        self.assertIn('tPose is sPose[pBody]', draw)
        self.assertIn('tPixels is not sDrawn[tId]', draw)
        # (a body's type is not asked every frame: a static one is never
        # awake, and a shelf made dynamic must still fall)
        self.assertNotIn('b2BodyType', draw)
        self.assertNotIn('sStill', self.script)

    def test_a_joints_anchors_are_asked_for_once(self):
        self.assertNotIn('b2JointLocalAnchor', handler(self.script, 'labDrawJoint'))
        self.assertIn('b2JointLocalAnchorAX', handler(self.script, 'labShowJoint'))

    def test_lines_and_dots_that_did_not_change_are_left_alone(self):
        for name in ('labLine', 'labDot'):
            text = handler(self.script, name)
            self.assertIn('sDrawn["mark" & tId]', text, name)
            self.assertLess(text.index('exit ' + name), text.index('set the'), name)
        self.assertIn('put "new" into sDrawn["mark" & tId]', handler(self.script, 'labMark'))

    def test_the_toys_sleeping_bodies_are_not_drawn(self):
        self.assertIn('b2BodyIsAwake', handler(self.script, 'frontDraw'))

    def test_the_switches_are_found_once(self):
        self.assertIn('labSwitchLights', handler(self.script, 'labStepOnce'))
        self.assertNotIn('labShowButtons', handler(self.script, 'labStepOnce'))


class LearnBox2DxtKit(unittest.TestCase):
    def setUp(self):
        self.script = read('learn-box2dxt-kit.livecodescript')

    def test_the_window_hidden_holds_the_game(self):
        frame = handler(self.script, 'b2kFrame')
        self.assertLess(frame.index('the iconic of stack sStack'), frame.index('dispatch "labStep"'))
        self.assertIn('b2kPause', frame)
        watch = handler(self.script, 'labWatch')
        self.assertIn('b2kResume', watch)
        # (a game Pause held is not set going when the window is back)
        self.assertIn('not sPaused', watch)
        self.assertIn('add 1 to sWatch', handler(self.script, 'labClose'))

    def test_the_switches_are_found_once(self):
        frame = handler(self.script, 'b2kFrame')
        self.assertIn('labSwitchLights', frame)
        self.assertNotIn('labShowButtons', frame)


if __name__ == '__main__':
    unittest.main()
