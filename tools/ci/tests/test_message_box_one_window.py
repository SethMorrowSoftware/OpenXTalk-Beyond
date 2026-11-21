"""The Message Box keeps the window it opens with.

A moment after every openStack the Message Box's tWDTroubleshooting gave the
stack the systemWindow of the Troubleshooting preferences. The engine makes a
stack's window again whenever a decoration is set, also to the value it has
(MCStack::SetDecoration), so the Message Box was drawn, taken away and drawn
again each time it opened (bwmilby on the forum, 0.2.8-dp.2 on Ubuntu 26.04:
"Message box still seems to draw twice when opened"), and on Windows, where a
last line then set it to true whatever the preference said, once more.

Measured with the 0.2.8-dp.2 IDE under mutter on Ubuntu 26.04, the window id
of the Message Box as it opened and half a second later: 10486575 then
10486603 with the stack as it was, 10486259 both times with this one. The IDE
tour's step message-box asks the same of every build.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SCRIPT = os.path.join(REPO, 'stack-scripts', 'ide', 'Toolset', 'palettes', 'message box',
                      'revmessagebox.8.rev.bst', 'scripts', 'stack_Message_Box.livecodescript')
PATCHES = os.path.join(REPO, 'tools', 'oxt', 'ide-stack-patches')
TOUR = os.path.join(REPO, 'tools', 'ci', 'ui-tour.livecodescript')

SET = 'set the systemwindow of this stack to'


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
    return [line.strip() for line in body.splitlines()
            if line.strip() and not line.lstrip().startswith('--')]


class TheWindowIsMadeOnce(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.lines = code(handler(read(SCRIPT), 'tWDTroubleshooting'))

    def test_the_system_window_is_set_in_one_place(self):
        self.assertEqual(len([line for line in self.lines if SET in line.lower()]), 1)

    def test_and_only_when_the_stack_has_another(self):
        line = [line for line in self.lines if SET in line.lower()][0]
        self.assertEqual(line, 'if the systemwindow of this stack is not tSystemWindow '
                               'then set the systemwindow of this stack to tSystemWindow')

    def test_its_value_is_the_preference_and_true_on_windows_as_before(self):
        at = self.lines.index('put the cMsgboxSysWin of stack "revPreferences" into tSystemWindow')
        self.assertEqual(self.lines[at + 1], 'if the platform contains "win" then put true into tSystemWindow')
        self.assertIn(SET, self.lines[at + 2].lower())
        # the preference still gets its false when it has no value yet
        self.assertLess(self.lines.index('if the cMsgboxSysWin of stack "revPreferences" is empty then '
                                         'set the cMsgboxSysWin of stack "revPreferences" to false'), at)

    def test_the_stack_still_asks_at_every_open_and_when_the_preference_changes(self):
        opened = code(handler(read(SCRIPT), 'openstack'))
        self.assertIn('send tWDTroubleshooting to this stack in 1 milliseconds', opened)

    def test_both_halves_are_patches(self):
        for name in ('message-box-one-window.txt', 'message-box-one-window-windows.txt'):
            text = read(os.path.join(PATCHES, name))
            self.assertIn('file: Toolset/palettes/message box/revmessagebox.8.rev', text)


class TheTourAsksForOneWindow(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        tour = read(TOUR)
        cls.step = code(handler(tour, 'tour_message_box'))
        cls.check = code(handler(tour, 'tourMessageBoxOneWindow'))

    def test_the_step_checks_before_its_picture(self):
        self.assertLess(self.step.index('tourMessageBoxOneWindow tMB'),
                        self.step.index('tourShotStack tMB, "11-message-box"'))

    def test_it_opens_again_and_compares_the_window_after_the_messages(self):
        order = ['close stack pMB', 'revIDEOpenPalette "message box"',
                 'put the windowId of stack pMB into tOpened', 'tourWait 500',
                 'put the windowId of stack pMB into tSettled', 'if tSettled is not tOpened then']
        self.assertEqual([line for line in self.check if line in order], order)


if __name__ == '__main__':
    unittest.main()
