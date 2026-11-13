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

"""tools/ci/everyday-tasks.livecodescript, read as text. Every task in its
list has a handler, and every handler is in the list, so a task cannot
quietly stop running. Every task asserts something (it throws when what a
person would see is not there) and snapshots what it did, except the first
and the last, which set up and tidy up. It waits for what it asserts
instead of sleeping. And the build workflows run it, light and dark, on
Linux, Windows and macOS. The script itself runs only on an engine
(tools/ci/ui_tour.py --script), in the build workflows.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.join(HERE, '..')
ROOT = os.path.join(CI, '..', '..')
SCRIPT = os.path.join(CI, 'everyday-tasks.livecodescript')
WORKFLOWS = os.path.join(ROOT, '.github', 'workflows')

# Set-up and tidy-up, which assert and snapshot nothing of their own
NOT_TASKS = {'start', 'finish'}


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def tasks(text):
    m = re.search(r'^constant kTasks = "([^"]*)"', text, re.M)
    return m.group(1).split(',') if m else []


def handlers(text):
    """Each handler's name and body, by its on ... end lines."""
    out = {}
    for m in re.finditer(r'^(?:on|command|private command) (\w+)[^\n]*\n(.*?)^end \1\s*$', text, re.M | re.S):
        out[m.group(1)] = m.group(2)
    return out


class EverydayTasksScript(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        cls.tasks = tasks(cls.text)
        cls.handlers = handlers(cls.text)

    def test_script_line(self):
        self.assertTrue(self.text.startswith('script "'), 'the script must start with its script line')

    def test_ascii(self):
        self.text.encode('ascii')

    def test_tasks_listed(self):
        self.assertGreaterEqual(len(self.tasks), 40)
        self.assertEqual(self.tasks[0], 'start')
        self.assertEqual(self.tasks[-1], 'finish')
        self.assertEqual(len(self.tasks), len(set(self.tasks)), 'a task listed twice')

    def test_every_task_has_its_handler(self):
        for task in self.tasks:
            name = 'ed_' + task.replace('-', '_')
            self.assertIn(name, self.handlers, 'no handler %s for the task %s' % (name, task))

    def test_every_handler_is_listed(self):
        listed = {'ed_' + t.replace('-', '_') for t in self.tasks}
        for name in self.handlers:
            if name.startswith('ed_'):
                self.assertIn(name, listed, '%s is not in kTasks, so it never runs' % name)

    def test_every_task_asserts(self):
        for task in self.tasks:
            if task in NOT_TASKS:
                continue
            body = self.handlers['ed_' + task.replace('-', '_')]
            self.assertRegex(body, r'\bthrow\b|"skipped"|\bedMake\b', 'the task %s asserts nothing' % task)

    def test_every_task_is_seen(self):
        # A snapshot of its own, or of the window it worked in (tasks
        # that change something the next task snapshots say so)
        for task in self.tasks:
            if task in NOT_TASKS:
                continue
            body = self.handlers['ed_' + task.replace('-', '_')]
            self.assertRegex(body, r'edShot\w+|edMake\b|edRecord "INFO', 'the task %s leaves nothing to look at' % task)

    def test_no_fixed_sleeps_in_tasks(self):
        # Waits are for a condition (edWaitFor); a fixed wait in a task
        # makes it slow where it passes and flaky where it does not
        for task in self.tasks:
            body = self.handlers['ed_' + task.replace('-', '_')]
            self.assertNotRegex(body, r'^\s*wait \d', 'the task %s sleeps' % task)

    def test_close_reopen_does_not_load_the_stack_it_checks(self):
        # Asking "there is a stack" about a stack that is not in memory
        # makes the engine read it from its file: the check would put back
        # the stack whose removal it checks
        body = self.handlers['ed_close_reopen']
        self.assertIn('edInMemory', body)
        self.assertNotIn('there is not a stack sStack', body)

    def test_app_browser_light_names_are_the_ides(self):
        # appbrowser-names asks, light, for the colour the IDE gives the App
        # Browser's names, read from revIDEAppBrowserAppearance itself: rc.6.17
        # (#372) made it 64,64,64 while the task still asked for the plugin's
        # own 127,127,127, and every Windows build failed on it
        lib = read(os.path.join(ROOT, 'ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript'))
        m = re.search(r'^command revIDEAppBrowserAppearance pDark\n(.*?)^end revIDEAppBrowserAppearance', lib, re.M | re.S)
        self.assertIsNotNone(m, 'revIDEAppBrowserAppearance not found')
        light = re.search(r'else if .*\n\s*set the linkColor of stack tBrowser to "([\d,]+)"', m.group(1))
        self.assertIsNotNone(light, 'its light branch not found')
        body = self.handlers['ed_appbrowser_names']
        self.assertIn('if tLinks is not "%s" then throw' % light.group(1), body)


class EverydayTasksInCI(unittest.TestCase):

    def test_build_workflows_run_it(self):
        for name in ('build-linux.yml', 'build-windows.yml', 'build-macos.yml', 'ui-tour.yml'):
            text = read(os.path.join(WORKFLOWS, name))
            self.assertIn('--script tools/ci/everyday-tasks.livecodescript', text, name)

    def test_linux_runs_light_and_dark(self):
        text = read(os.path.join(WORKFLOWS, 'build-linux.yml'))
        self.assertIn('for appearance in light dark', text)

    def test_windows_runs_light_and_dark(self):
        text = read(os.path.join(WORKFLOWS, 'build-windows.yml'))
        self.assertIn('everyday-light', text)
        self.assertIn('everyday-dark', text)



class MessageBoxKeptLine(unittest.TestCase):
    """The dark run comes after the light one in one Windows profile, and
    the Message Box keeps its last line: the dark run's click put the
    caret inside it, and "put 6 * 7" went into its middle (#363,
    0.2.7-rc.6.16)."""

    def test_the_line_is_typed_over_what_it_kept(self):
        text = read(SCRIPT)
        body = text.split('\non ed_message_box_line', 1)[1].split('\nend ed_message_box_line', 1)[0]
        select = body.index('select text of field "message" of card "Single Line" of stack tMB')
        self.assertLess(select, body.index('edType tMB, "put 6 * 7"'))
        self.assertGreater(select, body.index('edClickAt tMB'))


if __name__ == '__main__':
    unittest.main()


class FindTypingReachesTheEntry(unittest.TestCase):
    """se-find-replace types into the Find dialog's combo boxes. On the Intel
    Mac (main fde49edf) every key was lost with the focus on the combo box
    itself: the engine gives a typed key to a combo box's entry field only
    while that field is its active field (MCField::kdown), and the focus
    (the card's focused control) does not say which field that is. So the
    click is waited for until the entry is the active field, and a miss
    records what would name the cause."""

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        cls.handlers = handlers(cls.text)
        m = re.search(r'^function edEntryActive pCombo\n(.*?)^end edEntryActive', cls.text, re.M | re.S)
        cls.entry_active = m.group(1) if m else ''

    def test_the_click_waits_for_the_entry_to_take_the_keys(self):
        body = self.handlers['edTypeInCombo']
        wait = body.index('edWaitFor("edFocusOn(pAx) and edEntryActive(pAx)"')
        self.assertLess(wait, body.index('edType pStack, "a", "command"'), 'typing before the entry is active')

    def test_entry_active_reads_the_active_fields_chunk(self):
        # an entry's selectedChunk is its button's ("char 0 to 2 of button 1",
        # Find, on Linux); empty when no field is active
        self.assertIn('the selectedChunk', self.entry_active)
        self.assertIn('("button" && the number of pCombo)', self.entry_active)
        self.assertIn('tChunk is not empty', self.entry_active)

    def test_a_miss_says_what_moved(self):
        body = self.handlers['edTypeInCombo']
        throw = body[body.index('put "typing in" && pCombo'):body.index('throw tMiss')]
        for part in ('tBefore', 'tKeysBefore', 'edKeysAt()', 'edSeWaiting()', 'edWatched()',
                     'the focusedObject', 'the topStack', 'the defaultStack'):
            self.assertIn(part, throw, 'the miss does not record %s' % part)
        # and what a repeated click found
        self.assertRegex(body, r'edRecord "INFO click" && tTries .*edKeysAt\(\)')

    def test_where_the_keys_are_names_the_active_field(self):
        m = re.search(r'^function edKeysAt\n(.*?)^end edKeysAt', self.text, re.M | re.S)
        self.assertIsNotNone(m)
        for part in ('the focusedObject', 'the selectedField', 'the selectedChunk', 'the selectedText'):
            self.assertIn(part, m.group(1))

    def test_the_watcher_only_watches(self):
        # a front script sees the focus and card messages of the Find and
        # Script Editor windows and passes every one of them on
        body = self.handlers['edWatchKeys']
        names = re.search(r'repeat for each item tMessage in "([^"]+)"', body)
        self.assertIsNotNone(names)
        for name in ('preOpenCard', 'openField', 'exitField', 'focusIn', 'focusOut', 'suspendStack'):
            self.assertIn(name, names.group(1).split(','))
        self.assertIn('"   pass" && tMessage', body)
        self.assertIn('remove the script of button "oxt_everyday_keys" from front', body)

    def test_the_watcher_is_taken_out_on_every_way_out(self):
        body = self.handlers['edTypeInCombo']
        self.assertEqual(body.count('edWatchKeys true'), 1)
        self.assertEqual(body.count('edWatchKeys false'), 2, 'the miss and the pass each take it out')
        self.assertLess(body.index('edWatchKeys false'), body.index('throw tMiss'))
        self.assertIn('edWatchKeys false', self.handlers['edTidyAfterFailure'])

    def test_find_waits_for_the_script_editor_to_show_the_script(self):
        # the Find dialog takes its word from the editor's selection: it
        # opens once the editor has filled its field, as debug-breakpoint
        body = self.handlers['ed_se_find_replace']
        self.assertLess(body.index('edWaitFor("the text of pAx contains " & quote & "cClicks" & quote, 5000, tField)'),
                        body.index('"Find and Replace..."'))


class DragWaitStartsAtTheRelease(unittest.TestCase):
    """make-label failed on Windows (main 92b1a1d, dark) "made nothing on the
    stack" after 6289 ms, where every other drag took about 2.4 s. The 6 s
    were counted from the drag's launch, and on Windows the drag is a
    PowerShell that compiles its Add-Type before it touches the mouse; the
    record could not say whether the drag had even run. The drag's helper
    now writes when it started, pressed and released, the wait for the
    control starts at the release, and a miss says enough to tell a slow
    helper, a missed tile and a late control apart."""

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        cls.handlers = handlers(cls.text)
        m = re.search(r'^function edDragDone pMilliseconds\n(.*?)^end edDragDone', cls.text, re.M | re.S)
        cls.done = m.group(1) if m else ''

    def test_the_wait_for_the_control_follows_the_release(self):
        body = self.handlers['edMake']
        drag = body.index('edSystemDrag tFrom, tDrop')
        done = body.index('put edDragDone(20000) into tDrag')
        wait = body.index('edWaitFor("the number of controls of card 1 of stack sStack is pAx + 1", 6000, tCount)')
        self.assertLess(drag, done)
        self.assertLess(done, wait)

    def test_every_helper_says_when_it_released(self):
        body = self.handlers['edSystemDrag']
        self.assertIn('put tFile into sKeep["dragFile"]', body)
        self.assertIn('if there is a file tFile then delete file tFile', body)
        self.assertIn("echo up > '\" & tFile & \"')", body)          # macOS
        self.assertIn("mouseup 1; echo up > '\" & tFile & \"')", body)  # Linux
        for step in ("l 'started'", "l 'down'", "l 'up'"):            # Windows
            self.assertIn(step, body)
        # started is written before the Add-Type compiles
        self.assertLess(body.index("l 'started'"), body.index('Add-Type -Namespace OxtEd'))

    def test_the_release_wait_is_bounded_and_says_what_it_saw(self):
        self.assertIn('pMilliseconds, tFile)', self.done)
        self.assertIn('"released"', self.done)
        self.assertIn('"not released"', self.done)
        self.assertIn('sKeep["dragLaunched"]', self.done)

    def test_a_miss_says_enough_to_tell_the_causes_apart(self):
        body = self.handlers['edMake']
        miss = body[body.index('put "the" && pType && "tile made nothing on the stack'):body.index('throw tMiss')]
        for part in ('the rect of tTile', 'edTileShown(', 'tFrom', 'tDrop', 'edToolFilterText()', 'tDrag',
                     'the screenMouseLoc', 'the mouse', 'the tool', 'the topStack', 'the selObj',
                     'a control came', 'none came 3 s later either'):
            self.assertIn(part, miss, 'the miss does not record %s' % part)

    def test_the_filter_says_when_its_tile_did_not_show(self):
        body = self.handlers['edToolFilter']
        self.assertNotIn('get edWaitFor("edTileShown(', body)
        self.assertRegex(body, r'if not edWaitFor\("edTileShown\(.*\n\s+edRecord "INFO the Tools palette\'s filter"')


class ToolTileClickIsWatched(unittest.TestCase):
    """browse-runs-it failed once on macOS Intel (#484's run, dark): the
    Browse tile's click left the tool at the pointer for 3 s, and the
    record said only that. The snapshot showed the Script Editor gone and
    the button still selected (a browse tool chosen and lost would have
    dropped the selection), so the click most likely never reached the
    tile's mouseDown, but nothing recorded what it reached. The click is
    now watched (mouseDown, mouseUp, newTool with their targets), and a
    click that chose nothing is recorded with what was seen and the
    palette's state. It is not made again: the callers' own waits fail
    the step as before, and the record says whether the click reached
    the tile."""

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        cls.handlers = handlers(cls.text)

    def test_the_click_is_watched_from_before_to_after(self):
        body = self.handlers['edToolTile']
        on = body.index('edWatchClicks true')
        click = body.index('edClickAt "revTools", the loc of tTile')
        off = body.index('edWatchClicks false')
        self.assertLess(on, click)
        self.assertLess(click, off)

    def test_the_watch_sees_the_mouse_and_the_tool(self):
        body = self.handlers['edWatchClicks']
        for message in ('mouseDown', 'mouseUp', 'newTool'):
            self.assertIn(message, body)
        self.assertIn('insert the script of button "oxt_everyday_clicks" into front', body)
        self.assertIn('remove the script of button "oxt_everyday_clicks" from front', body)

    def test_a_click_that_chose_nothing_is_recorded_and_not_made_again(self):
        body = self.handlers['edToolTile']
        wait = body.index('if not edWaitFor("word 1 of the tool is pAx", 1500, tTool) then')
        record = body.index('edRecord "INFO the" && tTool && "tile')
        self.assertLess(wait, record)
        # one click only: a miss fails the caller's own wait, as before
        self.assertEqual(body.count('edClickAt '), 1)
        miss = body[record:body.index('edWatchClicks false')]
        for part in ('the tool', 'edWatched()', 'the rect of tTile', 'the visible of tTile',
                     'the mode of stack "revTools"', 'the rect of stack "revTools"',
                     'the topStack', 'the mouseStack', 'edPendingNames()'):
            self.assertIn(part, miss, 'the miss does not record %s' % part)

    def test_the_watcher_is_taken_down_after_a_failure(self):
        self.assertIn('edWatchClicks false', self.handlers['edTidyAfterFailure'])
