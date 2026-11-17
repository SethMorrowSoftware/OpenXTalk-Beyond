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
"""One positionOpenStacksButton waits for the Message Box's card at a time.

Each layout of the card (layoutCard) sent itself one more, "in 0
milliseconds", and the IDE lays the card out each time it hears that its
stacks changed, which the front script says each time a control anywhere is
named (nameChanged, revSetActiveStacks). Making the Tools palette once left
some 17 waiting; the everyday tasks' three checks of a tile, which switch the
palette's look over and over, left 252. On Windows a waiting message due
before a press of the mouse is delivered before it, and on the CI runner the
press of a tile then reached the palette 7.8 s late, with the mouse long up,
so the drag made nothing (#532, measured in #537: 2 waiting, 46 ms; 36, 430
ms; 252, 7.8 s).

The card now cancels the one that waits before it sends the next, as its
field does with its own colouring message (sColorizeMsg). The IDE tour's
step message-box lays the card out three times and counts what waits: on the
IDE as it was 3 ("STEP message-box FAILED after three layouts of the Message
Box's card 3 positionOpenStacksButton messages wait for it, not one"), with
this card 1, light and dark; the picture of the Message Box is the same to
the byte before and after.

  python3 -m unittest discover -s tools/ci/tests
"""

import glob
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
BEHAVIORS = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'message box', 'behaviors')
CARD = os.path.join(BEHAVIORS, 'revmessageboxsinglelinecardbehavior.livecodescript')
TOUR = os.path.join(REPO, 'tools', 'ci', 'ui-tour.livecodescript')

SEND = 'send "positionOpenStacksButton" to me in 0 milliseconds'


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def handler(text, name):
    m = re.search(r'^[ \t]*(?:private[ \t]+)?(?:command|on|function)[ \t]+%s\b(.*?)^[ \t]*end[ \t]+%s\b'
                  % (re.escape(name), re.escape(name)), text, re.M | re.S)
    if m is None:
        raise AssertionError('no handler ' + name)
    return m.group(1)


def code(body):
    return '\n'.join(line for line in body.splitlines() if not line.lstrip().startswith('--'))


class OneWaitsAtATime(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.card = read(CARD)
        cls.layout = code(handler(cls.card, 'layoutCard'))

    def test_the_one_that_waits_is_cancelled_before_the_next_is_sent(self):
        lines = [line.strip() for line in self.layout.splitlines() if line.strip()]
        at = lines.index(SEND)
        self.assertEqual(lines[at - 1], 'cancel sPositionMsg')
        self.assertEqual(lines[at + 1], 'put the result into sPositionMsg')

    def test_its_id_is_kept_from_one_layout_to_the_next(self):
        # a script local, declared before the handler that reads it (a name
        # is resolved by where it stands in the script)
        declared = re.search(r'^local sPositionMsg$', self.card, re.M)
        self.assertIsNotNone(declared)
        self.assertLess(declared.start(), self.card.index('on layoutCard'))
        self.assertNotIn('local sPositionMsg', self.layout)

    def test_no_other_handler_of_the_message_box_sends_one_to_wait(self):
        sends = []
        for path in sorted(glob.glob(os.path.join(BEHAVIORS, '*.livecodescript'))):
            for line in code(read(path)).splitlines():
                if re.search(r'\bsend\b.*positionOpenStacksButton', line):
                    sends.append((os.path.basename(path), line.strip()))
        self.assertEqual(sends, [(os.path.basename(CARD), SEND)])

    def test_the_layout_still_places_the_button_after_itself(self):
        # after the fields have their places, and with messages unlocked
        lines = [line.strip() for line in self.layout.splitlines() if line.strip()]
        self.assertLess(lines.index('unlock messages'), lines.index(SEND))
        self.assertLess(lines.index(SEND), lines.index('unlock screen'))


class TheTourCountsWhatWaits(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.tour = read(TOUR)
        cls.step = code(handler(cls.tour, 'tour_message_box'))
        cls.waiting = code(handler(cls.tour, 'tourMessageBoxWaiting'))

    def test_the_step_lays_the_card_out_three_times_and_asks_for_one(self):
        self.assertIn('put the long id of card "Single Line" of stack tMB into tCard', self.step)
        self.assertRegex(self.step, r'repeat 3 times\s+dispatch "layoutCard" to tCard\s+end repeat')
        self.assertIn('if tWaiting is not 1 then', self.step)
        self.assertIn('positionOpenStacksButton messages wait for it, not one', self.step)

    def test_the_one_that_waits_is_delivered(self):
        counted = self.step.index('if tWaiting is not 1 then')
        waited = self.step.index('tourWait 300', counted)
        self.assertLess(waited, self.step.index('if tWaiting is not 0 then throw'))

    def test_the_count_is_of_the_messages_waiting(self):
        self.assertIn('repeat for each line tLine in the pendingMessages', self.waiting)
        self.assertIn('if item 3 of tLine is "positionOpenStacksButton" then add 1 to tCount', self.waiting)


if __name__ == '__main__':
    unittest.main()
