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
"""The Project Browser asks the engine nothing about a stack file no stack has.

A row of the Project Browser keeps the long id of its object, which names a
saved stack by its file. Once the stack is saved under another file name
(File > Save As, `save stack ... as`, and a standalone build, which saves the
stack into the build's folder and puts it back after) no stack in memory has
that file. The browser went on asking the engine about such rows (exists,
there is), the engine read the old file, found a stack of that name in memory
already and sent reloadStack, and the IDE asked "A stack with the same name
as the one you are trying to load is already open". With the browser opened
once (it listens when it is closed too) that came at the next thing it heard,
a control renamed for one.

On Windows a standalone build hands out the IDE's waiting messages one at
each step of the build, so a message from before the build can reach the
browser while the stack is in the build's folder. With a pile of the Message
Box's own messages waiting in front (test_message_box_one_layout_waits.py)
none of the IDE's got its turn during a build; with the pile gone the
everyday tasks' standalone build failed there, light and dark ("the IDE kept
asking during the build", #538). Measured on the Windows runner (#539, run
43962703701): reloadStack for the stack's first file, sent from the
browser's ideNameChanged while the stack was in the build's folder; and the
same tasks passed when the build waited until nothing was due.

Now a long id is asked of the engine only when a stack in memory has its
name or its stack file (pbStackInMemory, pbExists), and rows that name
another are built again from what is in memory (pbRebuildIfStale), keeping
the rows that were open. The everyday task save-as-second-name does it as a
person would: File > Save As under a second name with the browser listing
the stack, then a control renamed. On the IDE as it was that task fails with
the IDE's question; this file holds the script to what keeps it away.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
BROWSER = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'project browser',
                       'revprojectbrowserbehavior.livecodescript')
TASKS = os.path.join(REPO, 'tools', 'ci', 'everyday-tasks.livecodescript')

# Handlers of the browser that are handed a long id from a message, or take
# one from a row, and asked the engine whether it exists
ASKERS = ('ideNewControl', 'ideNewCard', 'ideNewStack', 'ideOpenStack', 'addStackToProjectBrowser',
          'buildProjectView', 'updateListeners', 'refreshChildren')


# How the task's failure begins when the IDE asked something
ASKED = 'throw "after File > Save As under a second name (" & tSettled & ") the IDE asked:"'


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


def lines(body):
    return [line.strip() for line in code(body).splitlines() if line.strip()]


class TheBrowserAsksOnlyAboutStacksInMemory(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.browser = read(BROWSER)

    def test_the_test_loads_nothing(self):
        # Whether a stack is in memory is told from the names and the stack
        # files of the stacks in memory. Nothing in it may ask the engine
        # about the long id itself, which is what reads the file
        body = code(handler(self.browser, 'pbStackInMemory'))
        self.assertNotRegex(body, r'\bexists\s*\(|\bthere is\b|\bthe long id of\b|\bthe short name of\b')
        self.assertIn('the mainStacks', body)
        self.assertIn('the filename of stack tMainStack is tStack', body)
        self.assertIn('the substacks of stack tMainStack', body)

    def test_it_is_false_only_when_that_is_certain(self):
        # What is not plainly stack "<name or file>" at the end of a long id
        # is left to the engine, as before
        body = lines(handler(self.browser, 'pbStackInMemory'))
        at = body.index('if word -2 of pLongID is not "stack" then')
        self.assertEqual(body[at + 1], 'return true')
        at = body.index('if tStack is a number or quote is in tStack or return is in tStack then')
        self.assertEqual(body[at + 1], 'return true')

    def test_exists_is_asked_after_it(self):
        body = lines(handler(self.browser, 'pbExists'))
        self.assertEqual(body[:4], ['pLongID, @xChecked',
                                    'if not pbStackInMemory(pLongID, xChecked) then',
                                    'return false',
                                    'end if'])
        self.assertEqual(body[4], 'return exists(pLongID)')

    def test_no_handler_asks_the_engine_about_a_row_or_a_message_directly(self):
        for name in ASKERS:
            body = code(handler(self.browser, name))
            self.assertNotRegex(body, r'(?<!pb)\bexists\s*\(',
                                '%s asks the engine whether a long id exists without pbExists' % name)
            self.assertIn('pbExists(', body, name)
            self.assertRegex(body, r'(?m)^\s*local\s[^\n]*\btChecked\b', '%s does not declare tChecked' % name)

    def test_get_row_asks_the_engine_only_about_a_stack_in_memory(self):
        body = lines(handler(self.browser, 'getRow'))
        ask = body.index('if there is not a pLongID then')
        guard = body.index('if not pbStackInMemory(pLongID, tChecked) then')
        self.assertLess(guard, ask)
        self.assertEqual(body[guard + 1], 'return empty')
        # and a long id that has its row is never asked about
        self.assertLess(body.index('if sLongIDToRow[pLongID] is not empty then'), guard)

    def test_rows_of_a_stack_saved_elsewhere_are_built_again_before_they_are_used(self):
        body = lines(handler(self.browser, 'refreshProjectView'))
        self.assertEqual(body[:2], ['pbRebuildIfStale', 'if the result is true then exit refreshProjectView'])
        self.assertLess(body.index('pbRebuildIfStale'), body.index('updateListeners'))
        self.assertLess(body.index('pbRebuildIfStale'), body.index('send "RenderView" to group "objectList" of me'))

    def test_the_rebuild_is_from_what_is_in_memory_and_does_not_come_round_again(self):
        body = lines(handler(self.browser, 'pbRebuildIfStale'))
        self.assertIn('buildProjectView true', body)
        # building ends in refreshProjectView, which comes here: once
        first = body.index('if sRebuildingStale is true then')
        self.assertEqual(body[first + 1], 'return false')
        self.assertLess(first, body.index('buildProjectView true'))
        self.assertLess(body.index('put true into sRebuildingStale'), body.index('buildProjectView true'))
        after = body[body.index('buildProjectView true'):]
        self.assertGreaterEqual(after.count('put false into sRebuildingStale'), 2,
                                'the flag is not put back on both ways out of the build')
        self.assertIn('throw tError', after)
        self.assertRegex(self.browser, r'(?m)^local sRebuildingStale$')

    def test_the_rows_that_were_open_follow_the_stack_to_its_new_file(self):
        body = code(handler(self.browser, 'buildProjectView'))
        self.assertIn('put word -1 of the long id of stack tName into tMoved[word -1 of tLongID]', body)
        self.assertIn('tName is among the lines of the mainStacks', body)
        self.assertIn('put tMoved[word -1 of tExpandedControl] into word -1 of tExpandedControl', body)
        moved = body.index('put tMoved[word -1 of tExpandedControl] into word -1 of tExpandedControl')
        self.assertLess(moved, body.index('if pbExists(tExpandedControl, tChecked) then'))

    def test_the_browser_hears_of_a_save_under_another_name(self):
        # File > Save As ends in revIDEAddRecentStack, which sends this
        self.assertIn('revIDESubscribe "ideRecentFilesChanged"', code(self.browser))
        self.assertEqual(lines(handler(self.browser, 'ideRecentFilesChanged')), ['pbRebuildIfStale'])


class TheEverydayTaskDoesItAsAPersonWould(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.tasks = read(TASKS)
        cls.task = code(handler(cls.tasks, 'ed_save_as_second_name'))
        cls.listed = re.search(r'^constant kTasks = "([^"]*)"', cls.tasks, re.M).group(1).split(',')

    def test_it_runs_after_the_stack_has_a_file_and_before_the_builds(self):
        at = self.listed.index('save-as-second-name')
        self.assertGreater(at, self.listed.index('close-reopen'),
                           'the browser has rows that name the file only for a stack opened from it')
        self.assertLess(at, self.listed.index('standalone-built-and-run'))

    def test_it_saves_through_the_file_menu_under_a_second_name(self):
        self.assertIn('edFileDialog kSecondFile, "Save"', self.task)
        self.assertIn('edMenu "File", "Save As..."', self.task)
        second = re.search(r'^constant kSecondFile = "([^"]+)"', self.tasks, re.M).group(1)
        first = re.search(r'^constant kFile = "([^"]+)"', self.tasks, re.M).group(1)
        self.assertNotEqual(second, first)
        # the file the stack left must still be there: it is what was read
        self.assertIn('if there is not a file tOld then throw', self.task)

    def test_the_browser_lists_the_stack_before_the_save(self):
        body = lines(self.task)
        self.assertLess(body.index('revIDEShowInProjectBrowser the long id of card 1 of stack sStack'),
                        body.index('edMenu "File", "Save As..."'))

    def test_a_control_is_renamed_and_the_ide_must_ask_nothing(self):
        body = lines(self.task)
        save = body.index('edMenu "File", "Save As..."')
        rename = body.index('set the name of tControl to "Renamed After Save As"')
        self.assertLess(save, rename)
        # the IDE is given the time to hear of the save, of the new name and
        # of the old one put back (edSettled: until it has nothing due)
        self.assertLess(save, body.index('put "saved," && edSettled(8000) into tSettled'))
        self.assertEqual(body[rename + 1], 'put "; a control renamed," && edSettled(8000) after tSettled')
        back = body.index('set the name of tControl to tName')
        self.assertEqual(body[back + 1], 'put "; named back," && edSettled(8000) after tSettled')
        asked = [i for i, line in enumerate(body) if line == 'if sReport["answer"] is not empty then']
        self.assertTrue(asked)
        self.assertTrue(body[asked[-1] + 1].startswith(ASKED))

    def test_a_question_is_caught_from_the_save_on(self):
        # The question can come at the save itself or at the name: an answer
        # (Cancel, which leaves the stacks as they are) waits for both, so
        # that a question is the task's failure and not a run that stands
        body = lines(self.task)
        save = body.index('edMenu "File", "Save As..."')
        rename = body.index('set the name of tControl to "Renamed After Save As"')
        armed = [i for i, line in enumerate(body) if line.startswith('send "edAnswerWith" && quote & "Cancel,')]
        self.assertEqual(len(armed), 2)
        self.assertLess(body.index('put empty into sReport["answer"]'), armed[0])
        self.assertLess(armed[0], save)
        self.assertLess(save, armed[1])
        self.assertLess(armed[1], rename)
        # the second takes the place of the first
        self.assertEqual(body[armed[1] - 1], 'edCancelPending "edAnswerWith"')

    def test_the_question_is_the_first_thing_it_fails_on(self):
        # so that on an IDE that asks, the failure says what the IDE asked
        body = lines(self.task)
        asked = max(i for i, line in enumerate(body) if line.startswith(ASKED))
        for later in ('if not tListed then',
                      'if edPBRow(tPB, the long id of card 1 of stack sStack) is empty then'):
            self.assertGreater(body.index(later), asked)

    def test_an_answer_that_waits_is_not_left_for_the_next_task(self):
        self.assertIn('edCancelPending "edAnswerWith"', self.task)

    def test_the_stack_stays_the_one_saved_and_the_browser_lists_it(self):
        self.assertIn('if the effective filename of stack sStack is not tPath then', self.task)
        self.assertIn('if not tListed then', self.task)
        self.assertIn('if edPBRow(tPB, the long id of card 1 of stack sStack) is empty then', self.task)


if __name__ == '__main__':
    unittest.main()
