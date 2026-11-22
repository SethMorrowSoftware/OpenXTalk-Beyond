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
import shutil
import subprocess
import tempfile
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

    def test_no_else_on_its_own_line_after_a_one_line_if(self):
        # "if A then X" with "else" alone on the next line is one if
        # statement to the engine, and its else runs to the next "end if".
        # Written inside another if it takes that one's else and end if:
        # the script does not compile, no handler of it runs, and a run
        # prints nothing until its time is up. Before an "else" of the
        # enclosing if, a one-line if is written as a block
        found = self.one_line_ifs_before_else(self.text)
        self.assertEqual(found, [])
        # (the scan itself, on the shape that did not compile)
        bad = 'if pHow is "hidden" then\n   if tOne then throw "x"\nelse\n   put 1 into tTwo\nend if\n'
        self.assertEqual(self.one_line_ifs_before_else(bad), ['line 2: if tOne then throw "x"'])
        good = 'if pHow is "hidden" then\n   if tOne then\n      throw "x"\n   end if\nelse\n   put 1 into tTwo\nend if\n'
        self.assertEqual(self.one_line_ifs_before_else(good), [])

    @staticmethod
    def one_line_ifs_before_else(text):
        lines = text.split('\n')
        found = []
        for index in range(len(lines) - 1):
            line = lines[index].strip()
            if lines[index + 1].strip() != 'else' or line.endswith('\\'):
                continue
            if re.match(r'(else )?if .* then \S', line):
                found.append('line %d: %s' % (index + 1, line[:80]))
        return found

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

    def test_a_run_shares_no_file_with_another(self):
        # Linux runs light and dark at once (build-linux.yml). Named by
        # the milliseconds alone, the two runs' work folders were once one
        # (/tmp/oxt-everyday-1794673798576 for both): the dark run's Save
        # As found the light run's stack, the IDE asked whether to replace
        # it until the watchdog closed the dialog 30 s later, and three
        # later tasks failed on what the other run had saved
        start = self.handlers['ed_start']
        named = re.search(r'^\s*put specialFolderPath\("temporary"\) & "/oxt-everyday-" & (.*) into sWork$', start, re.M)
        self.assertIsNotNone(named, 'the work folder is not named in ed_start')
        self.assertIn('the processID', named.group(1), 'two runs that start together would name one folder')
        taken = start.index('if there is a folder sWork or there is a file sWork then throw')
        self.assertLess(start.index(named.group(0).strip()), taken)
        self.assertLess(taken, start.index('create folder sWork'))
        # (and nothing else of a run's is in the folder every run shares:
        # the file a drag says "up" in was)
        self.assertEqual(self.text.count('specialFolderPath("temporary")'), 1)
        self.assertIn('put sWork & "/drag.txt" into tFile', self.handlers['edSystemDrag'])


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


class ReleaseHandledBeforeTheTaskGoesOn(unittest.TestCase):
    """quick-start-dropped-shows failed on both of macOS's test jobs, Intel
    and Apple Silicon (#532, run 43906150245): its first click, the
    engine's on the Run tile, "chose
    nothing ... seen: 0 mouseDown card id 1002 (Tools); 205 mouseRelease
    button id 105962 (Tools)", right after the lesson's drag of a tile by
    the system's mouse and its click on the button made; browse-runs-it
    once lost the same click after drags. Read in the engine: on macOS
    the palette's drag ends when the system says the button is up, which
    can be before the engine has taken the mouse-up from its queue; the
    engine gives a mouse-up to the window pressed only while that window's
    stack is the one it holds the mouse over; and a task's own click
    makes that the stack clicked while it waits. A mouse-up taken from the
    queue then is dropped, the tile dragged goes on holding the press, and
    the palette's next press goes to the card. A drag's wait now handles
    the events for a moment after the helper's release, its record says
    what the engine held the mouse over, and a watched message to the
    Tools palette names the tile it went to."""

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        cls.handlers = handlers(cls.text)
        m = re.search(r'^function edDragDone pMilliseconds\n(.*?)^end edDragDone', cls.text, re.M | re.S)
        cls.done = m.group(1) if m else ''
        m = re.search(r'^function edDragOver\n(.*?)^end edDragOver', cls.text, re.M | re.S)
        cls.over = m.group(1) if m else ''
        m = re.search(r'^function edShortTarget pLongID\n(.*?)^end edShortTarget', cls.text, re.M | re.S)
        cls.short = m.group(1) if m else ''

    def code(self, body):
        return '\n'.join(line for line in body.split('\n') if not line.lstrip().startswith('--'))

    def test_the_events_are_handled_after_the_release_and_before_the_task_goes_on(self):
        done = self.code(self.done)
        up = done.index('edWaitFor("edDragOver() and there is a file pAx')
        handled = done.index('edPause 200')
        self.assertLess(up, handled)
        self.assertLess(handled, done.index('return "released"'))
        # every drag a task makes ends in that wait
        for name in ('edMake', 'edGuideLesson', 'edGuideDropped'):
            body = self.handlers[name]
            self.assertEqual(body.count('edSystemDrag '), body.count('put edDragDone(20000) into tDrag'), name)
            self.assertLess(body.index('edSystemDrag '), body.index('put edDragDone(20000) into tDrag'), name)

    def test_the_engine_is_as_it_was_read(self):
        # the three things the wait rests on; a change to one of them is
        # a reason to read edDragDone's comment again
        source = read(os.path.join(ROOT, 'engine', 'src', 'desktop.cpp'))
        for name in ('MCPlatformHandleMouseUp', 'MCPlatformHandleMouseRelease'):
            m = re.search(r'^void %s\(.*?^}' % name, source, re.M | re.S)
            self.assertTrue(m, 'no %s in desktop.cpp' % name)
            self.assertIn('if (MCmousestackptr.IsBoundTo(t_stack) || t_menu != nil)', m.group(0), name)
        source = read(os.path.join(ROOT, 'engine', 'src', 'mac-core.mm'))
        m = re.search(r'^bool MCPlatformGetMouseButtonState\(.*?^}', source, re.M | re.S)
        self.assertTrue(m, 'no MCPlatformGetMouseButtonState in mac-core.mm')
        self.assertIn('[NSEvent pressedMouseButtons]', m.group(0))
        source = read(os.path.join(ROOT, 'engine', 'src', 'exec-interface.cpp'))
        m = re.search(r'^void MCInterfaceExecClickCmd\(.*?^}', source, re.M | re.S)
        self.assertTrue(m, 'no MCInterfaceExecClickCmd in exec-interface.cpp')
        click = m.group(0)
        self.assertLess(click.index('MCscreen->setmouseloc(MCdefaultstackptr, t_view_clickloc);'),
                        click.index('MCscreen->wait(CLICK_INTERVAL, False, False);'))

    def test_a_drags_record_says_what_the_mouse_was_over(self):
        self.assertIn('edWaitFor("edDragOver() and there is a file pAx', self.done)
        self.assertEqual(self.done.count('); the mouse over:" && edDragWasOver()'), 2)   # released, and not
        for part in ('the mouse &&', 'the mouseStack', 'the short name of the mouseControl', 'sKeep["dragLaunched"]'):
            self.assertIn(part, self.over, 'the record does not hold %s' % part)
        # and what it is over once the release is handled
        done = self.code(self.done)
        self.assertLess(done.index('edPause 200'), done.index('get edDragOver()'))
        self.assertLess(done.index('get edDragOver()'), done.index('return "released"'))

    def test_the_record_never_ends_the_wait(self):
        # true whatever it saw: the wait ends on the helper's "up" alone
        returns = re.findall(r'^\s*return [^\n]*', self.over, re.M)
        self.assertEqual([r.strip() for r in returns], ['return true'])

    def test_each_drag_starts_its_own_record(self):
        wait = self.done.index('edWaitFor("edDragOver()')
        for line in ('put empty into sKeep["dragOver"]', 'put empty into sKeep["dragOverNow"]'):
            self.assertIn(line, self.done)
            self.assertLess(self.done.index(line), wait)

    def test_a_drag_that_made_its_control_keeps_its_record_too(self):
        body = self.handlers['edMake']
        made = body.index('edRecord "INFO made"')
        self.assertLess(made, body.index('if sInput is true then edRecord "INFO the drag" && tDrag'))

    def test_a_watched_message_to_the_tools_palette_names_its_tile(self):
        self.assertIn('return tOut && "(Tools," && the short name of pLongID & ")"', self.short)
        # a card or the stack has no tile to name
        self.assertIn('return tOut && "(Tools)"', self.short)


class TheTaskGoesOnWhenTheEngineHasLetGo(unittest.TestCase):
    """quick-start-dropped-shows failed again on macOS Intel, dark (#552,
    run 44126720354), with the moment of 200 ms in place: "the browse
    tile's click chose nothing ... seen: 1 mouseDown card id 1002 (Tools);
    219 mouseRelease button id 105962 (Tools, ...Button)", and the lesson's
    drag before it recorded "the mouse over: 249 up / 785 up revTools
    ...Button" with no third entry: the engine still held the tile when
    the 200 ms were over. In the 24 drags of main's two macOS test jobs at
    c77e5264 (run 44094625493) the third entry, "up revTools", has the
    time of the record's end in every one: the engine let go in those
    200 ms each time and never before them. A wait on macOS takes one
    event at most each time round its loop, after the messages the IDE has
    due, so how many events 200 ms hold depends on how busy the IDE is. On
    macOS a drag's wait now ends when the engine has let go, 5 s at most;
    a press still held then fails the step there."""

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        m = re.search(r'^function edDragDone pMilliseconds\n(.*?)^end edDragDone', cls.text, re.M | re.S)
        cls.done = m.group(1) if m else ''
        m = re.search(r'^function edDragHeld\n(.*?)^end edDragHeld', cls.text, re.M | re.S)
        cls.held = m.group(1) if m else ''

    def code(self, body):
        return '\n'.join(line for line in body.split('\n') if not line.lstrip().startswith('--'))

    def test_on_macos_the_wait_ends_when_the_engine_has_let_go(self):
        done = self.code(self.done)
        up = done.index('edWaitFor("edDragOver() and there is a file pAx')
        mac = done.index('if the platform is "MacOS" then')
        let_go = done.index('if edWaitFor("edDragOver() and not edDragHeld()", 5000) then')
        # after the helper's release, and before the task goes on
        self.assertLess(up, mac)
        self.assertLess(mac, let_go)
        self.assertLess(let_go, done.index('edPause 200'))
        self.assertLess(let_go, done.index('return "released"'))
        # the one wait every drag ends in: no caller has a wait of its own
        self.assertEqual(self.code(self.text).count('edDragHeld()'), 1)

    def test_a_press_still_held_fails_the_step_there(self):
        done = self.code(self.done)
        wait = done.index('if edWaitFor("edDragOver() and not edDragHeld()", 5000) then')
        miss = done[done.index('else', wait):done.index('edPause 200')]
        self.assertIn('throw "the engine still holds the drag\'s press"', miss)
        for part in ('the milliseconds - tAt', 'edDragWasOver()', 'the screenMouseLoc', 'edPendingNames()'):
            self.assertIn(part, miss, 'the miss does not record %s' % part)

    def test_the_record_says_how_long_the_engine_took(self):
        done = self.code(self.done)
        self.assertIn('put "; the release taken" && the milliseconds - tAt && "ms after the helper\'s up" into tTaken', done)
        self.assertRegex(done, r'return "released" [^\n]*\\\n[^\n]*sKeep\["dragSettled"\] & tTaken')
        # counted from when the helper's release was seen
        self.assertLess(done.index('put the milliseconds into tAt'), done.index('if the platform is "MacOS" then'))

    def test_held_is_a_control_of_a_window_the_systems_mouse_has_left(self):
        held = self.code(self.held)
        self.assertIn('put the mouseStack into tStack', held)
        self.assertIn('put the long id of the mouseControl into tControl', held)
        self.assertIn('if tControl is empty then return false', held)
        self.assertIn('return the screenMouseLoc is not within the rect of stack tStack', held)

    def test_the_engine_is_as_it_was_read(self):
        # what the wait rests on; a change to one of them is a reason to
        # read edDragDone's and edDragHeld's comments again
        source = read(os.path.join(ROOT, 'engine', 'src', 'desktop-dc.cpp'))
        m = re.search(r'^Boolean MCScreenDC::wait\(.*?^}', source, re.M | re.S)
        self.assertTrue(m, 'no MCScreenDC::wait in desktop-dc.cpp')
        wait = m.group(0)
        self.assertIn('collect at most one event', wait)
        self.assertLess(wait.index('handlepending(curtime, eventtime, dispatch)'),
                        wait.index('MCPlatformWaitForEvent(t_sleep, dispatch == False)'))
        source = read(os.path.join(ROOT, 'engine', 'src', 'stack.cpp'))
        m = re.search(r'^Boolean MCStack::mup\(.*?^}', source, re.M | re.S)
        self.assertTrue(m, 'no MCStack::mup in stack.cpp')
        mup = m.group(0)
        self.assertLess(mup.index('curcard->mup(which, p_release)'), mup.index('curcard->mfocus(MCmousex, MCmousey)'))
        source = read(os.path.join(ROOT, 'engine', 'src', 'card.cpp'))
        m = re.search(r'^Boolean MCCard::mfocus\(.*?^}', source, re.M | re.S)
        self.assertTrue(m, 'no MCCard::mfocus in card.cpp')
        self.assertIn('!(mgrabbed && mfocused->getref()->mfocus(x, y))', m.group(0))
        source = read(os.path.join(ROOT, 'engine', 'src', 'mac-core.mm'))
        m = re.search(r'^void MCMacPlatformHandleMouseMove\(.*?^}', source, re.M | re.S)
        self.assertTrue(m, 'no MCMacPlatformHandleMouseMove in mac-core.mm')
        self.assertIn('If the mouse is grabbed, the mouse window does not change', m.group(0))
        m = re.search(r'^void MCPlatformGetMousePosition\(.*?^}', source, re.M | re.S)
        self.assertTrue(m, 'no MCPlatformGetMousePosition in mac-core.mm')
        self.assertIn('[NSEvent mouseLocation]', m.group(0))


class TheIdeIsIdleBeforeADrag(unittest.TestCase):
    """The lesson's drag made no button on Windows (#532, run 43906149713),
    in the light and the dark run. Measured there (#537, run 43934646350):
    the tile's mouseDown comes after the messages the IDE has due, and the
    Tools palette starts its drag only if the button is still down then.
    The lesson's three checks of the tile switch the palette's look over
    and over with no event handled between; every tile the palette names
    tells the IDE that its stacks changed, and the Message Box answers
    each with a positionOpenStacksButton sent to itself. With 2 of them
    waiting the mouseDown came 46 ms after the press; with 36, 430 ms;
    with 252, 7.8 s, the mouse long up. A drag now waits first for what
    the IDE has due, and its record says how many that was."""

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        m = re.search(r'^command edSystemDrag pFrom, pTo\n(.*?)^end edSystemDrag', cls.text, re.M | re.S)
        cls.drag = m.group(1) if m else ''
        m = re.search(r'^function edSettled pMilliseconds\n(.*?)^end edSettled', cls.text, re.M | re.S)
        cls.settled = m.group(1) if m else ''
        m = re.search(r'^function edDue\n(.*?)^end edDue', cls.text, re.M | re.S)
        cls.due = m.group(1) if m else ''
        m = re.search(r'^function edDragDone pMilliseconds\n(.*?)^end edDragDone', cls.text, re.M | re.S)
        cls.done = m.group(1) if m else ''

    def code(self, body):
        return '\n'.join(line for line in body.split('\n') if not line.lstrip().startswith('--'))

    def test_a_drag_waits_for_what_the_ide_has_due_before_the_mouse_is_pressed(self):
        drag = self.code(self.drag)
        settled = drag.index('put edSettled(20000) into sKeep["dragSettled"]')
        # before the clock of the drag starts and before any helper is launched
        self.assertLess(settled, drag.index('put the milliseconds into sKeep["dragLaunched"]'))
        self.assertLess(settled, drag.index('switch the platform'))
        self.assertEqual(drag.count('edSettled('), 1)
        # the one wait before a drag is the drag helper's own, which every
        # drag goes through: no handler that drags waits again, and the
        # handlers that use the wait are these (save-as-second-name does
        # no drag: it waits for the IDE to hear of a save and of a name)
        users = set()
        for m in re.finditer(r'^(?:on|command|function|private command|private function) (\w+)\b(.*?)^end \1\b',
                             self.text, re.M | re.S):
            body = self.code(m.group(2))
            if 'edSettled(' in body:
                users.add(m.group(1))
            if m.group(1) != 'edSystemDrag' and 'edSystemDrag' in body:
                self.assertNotIn('edSettled(', body, '%s waits before the drag helper does' % m.group(1))
        self.assertEqual(users, {'edSystemDrag', 'ed_save_as_second_name'})

    def test_the_wait_handles_events_while_messages_are_due(self):
        settled = self.code(self.settled)
        self.assertIn('put edDue() into tFirst', settled)
        loop = re.search(r'repeat while (.*?)\n(.*?)\n   end repeat', settled, re.S)
        self.assertIsNotNone(loop)
        self.assertIn('tLeast > 0', loop.group(1))
        self.assertIn('wait 50 milliseconds with messages', loop.group(2))
        self.assertIn('put edDue() into tNow', loop.group(2))

    def test_the_wait_ends(self):
        # at most the time given, and no longer than the number goes on
        # falling: a message that sends itself again is always due
        loop = re.search(r'repeat while (.*?)\n', self.code(self.settled)).group(1)
        self.assertIn('the milliseconds - tStart < pMilliseconds', loop)
        self.assertIn('the milliseconds - tLeastAt < 1500', loop)
        self.assertEqual(loop.count(' and '), 2)
        self.assertNotIn(' or ', loop)

    def test_only_messages_whose_time_has_come_are_counted(self):
        # a task's own watchdog waits 30 seconds, and the IDE keeps
        # messages for later (its preferences' save): neither is due
        due = self.code(self.due)
        self.assertIn('put the long seconds into tNow', due)
        self.assertIn('repeat for each line tLine in the pendingMessages', due)
        self.assertIn('item 2 of tLine <= tNow then add 1 to tCount', due)

    def test_a_drags_record_says_what_was_due_before_it(self):
        self.assertIn('"messages due," && tLeast && "left after"', self.code(self.settled))
        done = self.code(self.done)
        self.assertEqual(done.count('"; before it" && sKeep["dragSettled"]'), 2,
                         'released or not, the record ends with what the IDE had due')

    def test_the_lessons_drags_keep_their_record_when_they_work(self):
        # so that a run on Windows says how many messages its drags waited for
        hs = handlers(self.text)
        lesson = hs['edGuideLesson']
        made = lesson.index('edWaitFor("the number of buttons of pAx is 2", 6000, tCard)')
        self.assertLess(made, lesson.index('if sInput is true then edRecord "INFO the lesson\'s drag" && tDrag'))
        dropped = hs['edGuideDropped']
        made = dropped.index('edWaitFor("the number of controls of pAx is pBx + 1", 6000, tCard, tCount)')
        self.assertLess(made, dropped.index('if sInput is true then edRecord "INFO the drag of the" && tType && tDrag'))


class StandaloneBuildStopped(unittest.TestCase):
    """standalone-stopped-build and standalone-mc-stack-file stop a build
    with an error at a step the builder reports (revStandaloneProgress)
    and ask that the stack is as it was (openxtalk.org p=26321: a build
    that stopped left the IDE's Answer and Ask dialogs in the stack). The
    steps, the menu item and the targets are the builder's and the IDE's
    own words: one of them reworded there would leave the task failing in
    every build for a reason it cannot name, so the words are checked
    here, where the difference is said."""

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        cls.handlers = handlers(cls.text)
        cls.builder = read(os.path.join(ROOT, 'ide-support', 'revsaveasstandalone.livecodescript'))
        cls.library = read(os.path.join(ROOT, 'ide-support', 'revsblibrary.livecodescript'))
        cls.menubar = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript'))

    @staticmethod
    def code(text):
        """The lines of a handler that are not comments."""
        return '\n'.join(line for line in text.split('\n') if not line.lstrip().startswith(('--', '#', '//')))

    def handler(self, kind, name):
        m = re.search(r'^%s %s\b.*?^end %s\s*$' % (kind, name, name), self.builder, re.M | re.S)
        self.assertIsNotNone(m, 'the builder has no %s' % name)
        return self.code(m.group(0))

    def steps(self):
        found = []
        for task in ('ed_standalone_stopped_build', 'ed_standalone_mc_stack_file'):
            m = re.search(r'edStoppedBuild\(\w+, "([^"]+)"\)', self.handlers[task])
            self.assertIsNotNone(m, '%s stops no build' % task)
            found.append(m.group(1))
        return found

    def test_the_steps_are_ones_the_builder_reports(self):
        for step in self.steps():
            self.assertIn('revStandaloneProgress "%s"' % step, self.builder,
                          'the builder reports no step "%s"' % step)

    def test_the_first_stop_is_after_the_stack_is_changed_and_before_it_is_saved(self):
        # revCopyResources: the dialogs go into the stack, then it is
        # closed and saved into the build folder (revSaveStackFile, which
        # reports the step first); stopped between the two the stack keeps
        # its own file name, where a Save reaches its file
        copy = self.handler('private command', 'revCopyResources')
        self.assertLess(copy.index('put "answer dialog"&cr after tCopyFiles'), copy.index('close stack pStack'))
        self.assertLess(copy.index('close stack pStack'), copy.index('revSaveStackFile(pStack'))
        save = self.handler('private function', 'revSaveStackFile')
        step = 'revStandaloneProgress "%s"' % self.steps()[0]
        self.assertLess(save.index(step), save.index('revSaveToFolder('))

    def test_the_second_stop_is_after_the_copy_is_saved_under_its_name(self):
        # revStandaloneDeployWithParams saves the build's copy by the name
        # revStandalonePreBuild gave it: a stack file whose copy has
        # another name (.mc before the fix) does not get past that save
        body = self.handler('command', 'revStandaloneDeployWithParams')
        step = 'revStandaloneProgress "%s"' % self.steps()[1]
        self.assertLess(body.index('save stack pStackFilePath'), body.index(step))
        self.assertLess(body.index(step), body.index('_internal deploy'))

    def test_the_mc_file_is_one_the_ide_opens_and_the_builder_renames(self):
        m = re.search(r'^constant kMcFile = "[^"]*\.(\w+)"', self.text, re.M)
        self.assertIsNotNone(m)
        extension = m.group(1)
        ide = read(os.path.join(ROOT, 'ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript'))
        # (revIDELiveCodeFileExtensions is revIDEAcceptedTypes("stack"))
        self.assertIn('return revIDEAcceptedTypes("stack")', ide)
        opened = re.search(r'^\s*case "stack"\n(?:\s*--[^\n]*\n)*\s*return "([^"]*)"', ide, re.M)
        self.assertIsNotNone(opened, 'the extensions the IDE opens as stacks not found')
        self.assertIn(extension, opened.group(1).split(','))
        rule = self.handler('private function', 'revStandaloneSavedFileName')
        self.assertNotIn('".%s"' % extension, rule, 'the builder keeps .%s: the task tests nothing' % extension)

    def test_one_rule_names_the_builds_copy(self):
        # the name the copy is saved under (revSaveToFolder) and the name
        # the steps after look for (revStandalonePreBuild)
        for kind, name in (('private on', 'revStandalonePreBuild'), ('private function', 'revSaveToFolder')):
            body = self.handler(kind, name)
            self.assertIn('revStandaloneSavedFileName(', body, name)
            self.assertNotIn('revIDELiveCodeFileExtensions', body, name)
            self.assertNotIn('".oxtstack"', body, name)

    def test_the_menu_item_is_the_file_menus(self):
        items = re.findall(r'edMenu "File", "([^"]*Standalone[^"]*)"', self.text)
        # (a build that stops, and one that goes to its end)
        self.assertGreaterEqual(len(items), 2)
        picks = [p.lower() for p in re.findall(r'case "([^"]*)"', self.menubar)]
        for item in items:
            self.assertIn('enableMenuItem("%s"' % item, self.menubar)
            self.assertIn(item.lower(), picks, 'no menuPick case for it')

    def test_the_targets_are_the_builders(self):
        m = re.search(r'^constant kDesktopTargets = "([^"]*)"', self.library, re.M)
        self.assertIsNotNone(m)
        desktop = m.group(1).split(',')
        body = re.search(r'^function edBuildTarget\n(.*?)^end edBuildTarget', self.text, re.M | re.S).group(1)
        named = re.findall(r'return "([^"]+)"', body)
        self.assertGreaterEqual(len(named), 5)
        for target in named:
            self.assertIn(target, desktop)
        settings = re.search(r'repeat for each item tTarget in "([^"]*)"', self.handlers['edBuildSettings'])
        self.assertIsNotNone(settings)
        for target in desktop:
            self.assertIn(target, settings.group(1).split(','), 'edBuildSettings leaves %s as the stack has it' % target)

    def test_the_builder_puts_the_stack_back_before_it_aborts(self):
        body = self.handler('command', 'revDoSaveAsStandalone')
        catch = body.split('\n   catch tError', 1)[1]
        self.assertIn('__PutStackBackAfterFailedBuild', catch, 'a build that stops leaves the stack as the builder changed it')
        self.assertLess(catch.index('__PutStackBackAfterFailedBuild'), catch.index('revAbort'))


class BuildTasks:
    """What the tasks that build a standalone with the builder's dialogs
    on are read from: the script, its handlers, and the builder."""

    @classmethod
    def setUpClass(cls):
        cls.text = read(SCRIPT)
        cls.handlers = handlers(cls.text)
        cls.builder = read(os.path.join(ROOT, 'ide-support', 'revsaveasstandalone.livecodescript'))

    def function(self, name):
        m = re.search(r'^function %s\b[^\n]*\n(.*?)^end %s\s*$' % (name, name), self.text, re.M | re.S)
        self.assertIsNotNone(m, 'the script has no function %s' % name)
        return '\n'.join(line for line in m.group(1).split('\n') if not line.lstrip().startswith('--'))

    def constant(self, name):
        m = re.search(r'^constant %s = "([^"]*)"' % name, self.text, re.M)
        self.assertIsNotNone(m, 'no constant %s' % name)
        return m.group(1)


class StandaloneBuiltAndRun(BuildTasks, unittest.TestCase):
    """standalone-built-and-run builds a stack from the File menu to the
    end, with the builder's dialogs on, and runs the standalone, which
    writes what it finds itself to be and quits. What the task waits for
    is the builder's own: its last word, the two messages it sends a
    stack, its last step and where it puts the standalone. And the stack
    the task makes carries a quit, which must be the standalone's alone."""

    def app_script(self):
        """The stack script edAppScript puts together, as the engine gets
        it: its lines, with the quotes it is written with."""
        body = self.function('edAppScript')
        lines = re.findall(r'^\s*(?:put )?"([^"]*)" & return', body, re.M) + re.findall(r'^\s*"([^"]*)" into tScript', body, re.M)
        self.assertGreaterEqual(len(lines), 20, 'edAppScript is not read as it is written')
        self.assertIn('replace "\'" with quote in tScript', body)
        return '\n'.join(lines).replace("'", '"')

    def test_the_task_builds_to_the_end_and_runs_what_it_built(self):
        body = self.handlers['ed_standalone_built_and_run']
        self.assertLess(body.index('edFullBuild('), body.index('edFindStandalone('))
        self.assertLess(body.index('edFindStandalone('), body.index('shell('))
        self.assertLess(body.index('shell('), body.index('edShotStack'))
        # (no stop in it: the build of this task goes to its end)
        self.assertNotIn('edStoppedBuild', body)
        full = self.function('edFullBuild')
        build = self.handlers['edBuildWithDialogs']
        self.assertIn('edBuildWithDialogs pShot\n', full)
        self.assertIn('edWatchBuild true\n', build)
        self.assertNotIn('edStopBuildAt', full + build)

    def test_the_last_word_is_the_builders(self):
        said = self.constant('kBuildSaved')
        self.assertIn('answer information "%s"' % said, self.builder,
                      'the builder no longer says "%s" at the end of a build' % said)
        full = self.function('edFullBuild')
        self.assertIn('line 1 of tSaid is not kBuildSaved', full)

    def test_the_messages_are_the_ones_the_builder_sends_a_stack(self):
        script = self.app_script()
        for message in ('savingStandalone', 'standaloneSaved'):
            self.assertIn('dispatch "%s" to stack pStack' % message, self.builder)
            self.assertRegex(script, r'(?m)^on %s\b' % message)
            self.assertIn('with "%s"' % message, script)
        self.assertIn('dispatch "edBuildMessage" to stack "oxt_everyday"', script)
        self.assertIn('edBuildMessage', self.handlers)
        # (the folder standaloneSaved comes with is the one the standalone must be in)
        self.assertIn('dispatch "standaloneSaved" to stack pStack with pFolder', self.builder)
        self.assertIn('if not (tExe begins with sReport["built"]) then throw', self.handlers['ed_standalone_built_and_run'])

    def test_the_last_step_is_one_the_builder_reports(self):
        full = self.function('edFullBuild')
        m = re.search(r'if "([^"]+)" is not among the lines of tSteps', full)
        self.assertIsNotNone(m)
        self.assertIn('revStandaloneProgress "%s"' % m.group(1), self.builder)
        deploy = re.search(r'^command revStandaloneDeployWithParams\b.*?^end revStandaloneDeployWithParams', self.builder, re.M | re.S).group(0)
        self.assertLess(deploy.index('revStandaloneProgress "%s"' % m.group(1)), deploy.index('_internal deploy'))

    def test_the_quit_is_the_standalones_alone(self):
        # the stack is opened in the IDE too: a quit there ends the tasks
        script = self.app_script()
        opened = re.search(r'^on openStack\n(.*?)^end openStack', script, re.M | re.S)
        self.assertIsNotNone(opened)
        lines = [line.strip() for line in opened.group(1).split('\n') if line.strip()]
        self.assertEqual(lines[0], 'if the environment is not "standalone application" then pass openStack')
        self.assertEqual(script.count('quit'), 1)
        self.assertIn('quit', opened.group(1))

    def test_what_the_standalone_must_report_is_what_its_script_writes(self):
        body = self.handlers['ed_standalone_built_and_run']
        wanted = re.search(r'repeat for each line tWant in (.*?)\n\s*if tWant is not among the lines of tReport', body, re.S)
        self.assertIsNotNone(wanted)
        labels = re.findall(r'"([A-Za-z ]+:)', wanted.group(1))
        self.assertEqual(len(labels), 7, labels)
        script = self.app_script()
        for label in labels:
            self.assertIn('"%s "' % label, script, 'the standalone writes no line "%s"' % label)
        self.assertIn('"EVERYDAY APP RAN"', wanted.group(1))
        self.assertIn('"EVERYDAY APP RAN"', script)
        # (and it writes them where the task reads them)
        self.assertIn('the cEverydayRan of me', script)
        self.assertIn('set the cEverydayRan of stack kAppStack to tRan', body)
        self.assertLess(body.index('set the cEverydayRan of stack kAppStack'), body.index('edSaveForBuild kAppStack'))

    def test_the_builders_dialogs_are_on_for_the_build_alone(self):
        full = self.handlers['edBuildWithDialogs']
        off = 'dispatch "revSetTestEnvironment" to stack "Home" with false'
        on = 'dispatch "revSetTestEnvironment" to stack "Home" with true'
        self.assertLess(full.index(off), full.index('edMenu "File"'))
        after = full.split('edMenu "File"', 1)[1]
        self.assertLess(after.index('finally'), after.index(on), 'the dialogs must go off again whatever the build did')
        self.assertLess(after.index(on), after.index('end try'))
        self.assertIn(on, self.handlers['ed_finish'])

    def test_the_standalone_is_looked_for_as_the_builder_names_it(self):
        find = self.function('edFindStandalone')
        self.assertIn('pName & ".app/Contents/MacOS/" & pName', find)
        self.assertIn('sStandaloneSettingsA["name"] & ".app/Contents/MacOS/"', self.builder)
        self.assertIn('pName & ".exe"', find)
        self.assertIn('put ".exe" after tStandalonePath', self.builder)
        # (the name the task gives the standalone is the one it looks for)
        body = self.handlers['ed_standalone_built_and_run']
        self.assertIn('edBuildSettings kAppStack, kAppName', body)
        self.assertIn('edFindStandalone(edBuildFolder(kAppName), kAppName', body)
        settings = self.handlers['edBuildSettings']
        self.assertIn('set the cRevStandaloneSettings["name"] of stack pStack to pName', settings)
        # (and the folder it is looked for in is the one it is built into)
        self.assertIn('put edBuildFolder(pName) into tFolder', settings)
        self.assertIn('set the cRevStandaloneSettings["defaultBuildFolder"] of stack pStack to tFolder', settings)

    def test_the_app_file_is_a_stack_file_people_bring(self):
        m = re.search(r'\.(\w+)$', self.constant('kAppFile'))
        self.assertIsNotNone(m)
        ide = read(os.path.join(ROOT, 'ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript'))
        opened = re.search(r'^\s*case "stack"\n(?:\s*--[^\n]*\n)*\s*return "([^"]*)"', ide, re.M)
        self.assertIsNotNone(opened, 'the extensions the IDE opens as stacks not found')
        self.assertIn(m.group(1), opened.group(1).split(','))

    def test_no_build_over_a_stack_a_build_left_broken(self):
        # 0.2.8-dp.1: over the stack a stopped build left (the IDE's
        # Answer dialog in it) the next build's dialogs did not end
        body = self.handlers['ed_standalone_built_and_run']
        self.assertIn('if edDialogCopies() is not empty then throw', body)
        self.assertLess(body.index('if edDialogCopies() is not empty then throw'), body.index('create stack kAppStack'))

    def test_a_build_that_keeps_asking_is_stopped(self):
        limit = int(re.search(r'^constant kBuildDialogs = (\d+)', self.text, re.M).group(1))
        # (the build has one thing to say; some room, and an end)
        self.assertGreaterEqual(limit, 2)
        self.assertLessEqual(limit, 10)
        said = self.handlers['edBuildSaid']
        self.assertIn('add 1 to sReport["dialogs"]', said)
        self.assertRegex(said, r'if sReport\["dialogs"\] > kBuildDialogs then\s+set the cEdStopBuild of stack "oxt_everyday" to ')
        # (and it gives up answering: its time is bounded)
        self.assertIn('if the milliseconds > pUntil then exit edBuildSaid', said)
        watch = self.handlers['edWatchBuild']
        self.assertIn('set the cEdStopBuild of stack "oxt_everyday" to empty', watch)
        self.assertIn('is not empty then throw the cEdStopBuild of stack', watch)
        self.assertLess(watch.index('is not empty then throw the cEdStopBuild of stack'), watch.index('pass revStandaloneProgress'))
        self.assertIn('put 0 into sReport["dialogs"]', self.handlers['edBuildWithDialogs'])
        full = self.function('edFullBuild')
        self.assertLess(full.index('if sReport["dialogs"] > kBuildDialogs then'), full.index('is not among the lines of tSteps'))

    def test_the_stacks_the_tasks_made_are_taken_away(self):
        for name in ('kMcStack', 'kAppStack'):
            self.assertIn('edRemoveBuiltStack %s' % name, self.handlers['ed_finish'])
        self.assertIn('edRemoveBuiltStack kAppStack', self.handlers['ed_standalone_built_and_run'])

    def test_a_mac_builds_for_its_own_processor(self):
        # The task runs what it builds. The Standalone Settings' "MacOS ARM
        # 64 native" (MacOSX x64-ARM64) is built with the arm64 code alone:
        # on an Intel Mac that standalone ended with 126, "Bad CPU type in
        # executable". There the task builds "MacOS Intel 64-bit"
        body = self.function('edBuildTarget')
        mac = re.search(r'if the platform is "MacOS" then\n(.*?)\n   end if', body, re.S)
        self.assertIsNotNone(mac, 'no target for a Mac')
        lines = [line.strip() for line in mac.group(1).split('\n')]
        self.assertEqual(lines, ['if the processor is "x86_64" then return "MacOSX x86-64"', 'return "MacOSX x64-ARM64"'])
        # (one architecture each, as the builder hands them to the deploy)
        self.assertIn('if sStandaloneSettingsA["MacOSX x86-64"] then put "x86-64," after tArchitectures', self.builder)
        self.assertIn('if sStandaloneSettingsA["MacOSX x64-ARM64"] then put "arm64," after tArchitectures', self.builder)
        self.assertIn('put tArchitectures into tDeployInfo["architectures"]', self.builder)
        # (and both Macs run the tasks)
        mac_workflow = read(os.path.join(WORKFLOWS, 'build-macos.yml'))
        self.assertIn('macos-15-intel', mac_workflow)
        # (the builder's own limit is the ARM 64 target's alone)
        skip = self.function('edBuildSkip')
        self.assertIn('if edBuildTarget() is "MacOSX x64-ARM64" then', skip)
        self.assertRegex(self.builder, r'if tSettings\["MacOSX x64-ARM64"\] then\n\s*if the platform contains "Mac" then\n(?:.*\n){3}\s*if mysys <14 then')

    def test_the_dialog_the_build_ends_on_is_in_the_pictures(self):
        # (what the IDE says at the end of a build is a window a person
        # sees: it is snapshot under a name of the task's, before the
        # click that closes it)
        body = self.handlers['ed_standalone_built_and_run']
        m = re.search(r'edFullBuild\(kAppStack, "(\d\d-[a-z-]+)"\)', body)
        self.assertIsNotNone(m, 'the task names no snapshot for the dialog its build ends on')
        own = re.search(r'edShotStack kAppStack, "(\d\d-[a-z-]+)"', body)
        self.assertIsNotNone(own)
        self.assertLess(m.group(1), own.group(1), 'the dialog comes before the stack in the pictures')
        self.assertIn('put pShot into sReport["sayShot"]', self.handlers['edBuildWithDialogs'])
        said = self.handlers['edBuildSaid']
        shot = 'edShotStack tAD, sReport["sayShot"]'
        self.assertIn(shot, said)
        self.assertLess(said.index(shot), said.index('edAnswerWith "OK"'),
                        'the snapshot is after the click that closes the dialog')
        # (the first dialog alone, and a snapshot that fails does not
        # stop the answering: an unanswered dialog holds the build)
        self.assertRegex(said, r'if sReport\["dialogs"\] is 1 and sReport\["sayShot"\] is not empty then\s+try\s+%s\s+catch tError\s+end try' % re.escape(shot))

    def test_no_two_snapshots_share_a_name(self):
        # (the second would take the place of the first in the pictures)
        names = re.findall(r'"(\d\d-[a-z0-9-]+)"', self.text)
        self.assertGreater(len(names), 40)
        twice = sorted(set(name for name in names if names.count(name) > 1))
        self.assertEqual(twice, [], 'snapshots named twice')


class StandaloneEngineMissing(BuildTasks, unittest.TestCase):
    """standalone-engine-missing has the builder refuse a build, with its
    dialogs on, and reads what it tells a person. Up to 0.2.8-dp.1 the
    dialog had lost the first word of the builder's sentence: the builder
    took "Standalone:" off its error, and then a word more off what it
    showed. What the task waits for is the sentence the builder throws,
    and the engine is taken away the builder's own way, for the build
    alone."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.home = read(os.path.join(ROOT, 'ide', 'Toolset', 'home.livecodescript'))

    def test_the_builder_says_its_whole_error(self):
        do = re.search(r'^command revDoSaveAsStandalone\b.*?^end revDoSaveAsStandalone', self.builder, re.M | re.S)
        self.assertIsNotNone(do)
        caught = do.group(0).split('catch tError', 1)[1]
        strip = 'put word 2 to -1 of tError into tError'
        self.assertEqual(caught.count(strip), 1)
        after = caught.split(strip, 1)[1]
        # (what it shows is what is left of the error: all of it)
        self.assertRegex(after, r'^\s*if not revSBSuppressDialogs\(\) then\n(?:\s*--[^\n]*\n)*\s*answer error tError\n\s*end if\n')
        self.assertNotIn('answer error word 2 to -1 of tError', self.builder)
        # (and what a script gets back is that same text, as before)
        self.assertIn('return tError', after)

    def test_the_sentence_is_the_builders(self):
        said = self.constant('kBuildNoEngine')
        throws = re.findall(r'throw "Standalone: ([^"]*)" \\\n\s*& return & tEngineSourceFile', self.builder)
        self.assertEqual(len(throws), 3, 'the Mac, the Windows and the Linux builder each say it')
        for thrown in throws:
            self.assertEqual(thrown.strip(), said)
        refused = self.function('edRefusedBuild')
        self.assertIn('if word 1 to -1 of line 1 of tSaid is not kBuildNoEngine then', refused)
        # (and the file it looked for, on the line after)
        self.assertIn('if word 1 to -1 of line 2 of tSaid is not pEngine then', refused)
        self.assertIn('if the number of lines of tSaid > 2 then return', refused)

    def test_the_engine_is_taken_away_the_builders_own_way(self):
        checks = list(re.finditer(r'if there is not a file tEngineSourceFile then\n\s*throw "Standalone:', self.builder))
        self.assertEqual(len(checks), 3)
        for check in checks:
            self.assertIn('put revOverrideRuntimePath() into tEngineSourceFile', self.builder[check.start() - 300:check.start()])
        self.assertRegex(self.home, r'(?m)^\s*command revSetOverrideRuntimePath pPath$')
        self.assertRegex(self.home, r'(?m)^\s*function revOverrideRuntimePath$')
        refused = self.function('edRefusedBuild')
        self.assertIn('dispatch "revSetOverrideRuntimePath" to stack "Home" with pEngine', refused)
        # (a file there would be attached as the engine)
        body = self.handlers['ed_standalone_engine_missing']
        self.assertIn('if there is a file tEngine then throw', body)
        self.assertLess(body.index('if there is a file tEngine then throw'), body.index('edRefusedBuild('))

    def test_the_engine_is_away_for_the_build_alone(self):
        # (left set, every later build of the IDE would be refused)
        refused = self.function('edRefusedBuild')
        away = 'dispatch "revSetOverrideRuntimePath" to stack "Home" with pEngine'
        back = 'dispatch "revSetOverrideRuntimePath" to stack "Home" with empty'
        self.assertLess(refused.index(away), refused.index('edBuildWithDialogs pShot'))
        after = refused.split('edBuildWithDialogs pShot', 1)[1]
        self.assertLess(after.index('finally'), after.index(back), 'the engine must be back whatever the build did')
        self.assertLess(after.index(back), after.index('end try'))
        self.assertIn(back, self.handlers['ed_finish'])

    def test_the_build_is_the_file_menus_with_the_dialogs_on(self):
        refused = self.function('edRefusedBuild')
        self.assertIn('edBuildWithDialogs pShot\n', refused)
        build = self.handlers['edBuildWithDialogs']
        self.assertIn('edMenu "File", "Save as Standalone Application..."', build)
        self.assertIn('dispatch "revSetTestEnvironment" to stack "Home" with false', build)

    def test_a_refused_build_leaves_the_ide_as_it_was(self):
        refused = self.function('edRefusedBuild')
        self.assertLess(refused.index('put edBuildState(pStack) into tBefore'), refused.index('edBuildWithDialogs pShot'))
        self.assertLess(refused.index('put URL ("binfile:" & tPath) into tBytes'), refused.index('edBuildWithDialogs pShot'))
        self.assertIn('if "Attaching engine..." is among the lines of tSteps then', refused)
        self.assertIn('if sReport["dialogs"] > kBuildDialogs then', refused)
        self.assertIn('if edOpen("revStandaloneProgress") then return', refused)
        self.assertIn('return edBuildLeft(pStack, tBefore, tBytes, ', refused)

    def test_no_build_over_a_stack_a_build_left_broken(self):
        body = self.handlers['ed_standalone_engine_missing']
        guard = 'if edDialogCopies() is not empty then throw'
        self.assertIn(guard, body)
        self.assertLess(body.index(guard), body.index('edBuildSettings'))

    def test_the_dialog_is_in_the_pictures(self):
        body = self.handlers['ed_standalone_engine_missing']
        m = re.search(r'edRefusedBuild\(sStack, tEngine, "(\d\d-[a-z-]+)"\)', body)
        self.assertIsNotNone(m, 'the task names no snapshot for the dialog its build stops on')
        own = re.search(r'edShotStack sStack, "(\d\d-[a-z-]+)"', body)
        self.assertIsNotNone(own)
        self.assertLess(m.group(1), own.group(1), 'the dialog comes before the stack in the pictures')


class MessageBoxShortcut(BuildTasks, unittest.TestCase):
    """message-box-shortcut presses the Message Box's shortcut with the
    Tools palette closed. A newcomer wrote that "when the Tools Palette is
    not yet visible, Ctrl-M only opens the Tools Palette" (openxtalk.org
    p=26390). In 0.2.8-dp.1 on Linux it opens the Message Box and leaves
    the Tools palette closed; the task holds Windows and macOS to that
    too, with the system's keyboard where its keys reach the IDE, so that
    the menu bar's accelerator answers as it answers a person."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.menubar = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript'))
        cls.body = cls.handlers['ed_message_box_shortcut']

    def test_the_task_follows_the_message_boxs_own(self):
        names = tasks(self.text)
        self.assertEqual(names.index('message-box-shortcut'), names.index('message-box-lines') + 1)
        # (which leaves the Message Box closed)
        self.assertRegex(self.handlers['ed_message_box_lines'], r'close stack tMB\s*$')

    def test_the_letter_is_the_menu_items(self):
        m = re.search(r'toggleMenuItem\("&Message Box/(\w)", revIDEPaletteIsVisible\("message box"\)\)', self.menubar)
        self.assertIsNotNone(m, 'Tools > Message Box has no shortcut')
        letter = m.group(1).lower()
        self.assertEqual(self.body.count('edShortcut("%s")' % letter), 2, 'pressed to open it, and again to close it')
        self.assertIn('put edShortcutName("%s") into tKeys' % letter, self.body)
        # (the Tools palette's own shortcut is another letter)
        tools = re.search(r'toggleMenuItem\("&Tools Palette/(\w)", revIDEPaletteIsVisible\("tools"\)\)', self.menubar)
        self.assertIsNotNone(tools, 'Tools > Tools Palette has no shortcut')
        self.assertNotEqual(tools.group(1).lower(), letter)

    def test_the_tools_palette_is_closed_first_by_its_menu_item(self):
        close = self.body.index('if revIDEPaletteIsVisible("tools") then edMenu "Tools", "Tools Palette"')
        closed = self.body.index('if not edWaitFor("not revIDEPaletteIsVisible(pAx)", 3000, "tools") then throw')
        self.assertLess(close, closed)
        self.assertLess(closed, self.body.index('edShortcut("m")'))
        # (and the Message Box is closed before the keys: they must open it)
        self.assertLess(self.body.index('if edOpen(tMB) then close stack tMB'), self.body.index('edShortcut("m")'))

    def test_a_tools_palette_the_keys_showed_fails_the_task(self):
        after = self.body.split('put edShortcut("m") into tVia', 1)[1]
        self.assertIn('if not edWaitFor("edOpen(pAx)", 5000, tMB) then', after)
        # (once after the keys that open the Message Box, once after the
        # keys that close it)
        self.assertEqual(after.count('else if revIDEPaletteIsVisible("tools") then'), 2)
        self.assertIn('if not edWaitFor("not edOpen(pAx)", 5000, tMB) then', after)
        # (those four, and a key the system still holds after them)
        self.assertEqual(after.count('into tMiss'), 5)
        self.assertIn('if tMiss is not empty then throw tMiss', after)

    def test_the_tools_palette_is_back_whatever_happened(self):
        after = self.body.split('put edShortcut("m") into tVia', 1)[1]
        back = after.index('edToolsBack tMB')
        self.assertNotIn('throw', after[:back], 'a throw here would leave the Tools palette closed for the tasks after')
        self.assertLess(back, after.index('if tMiss is not empty then throw tMiss'))
        tools_back = self.handlers['edToolsBack']
        self.assertIn('if pMB is not empty and edOpen(pMB) then close stack pMB', tools_back)
        self.assertIn('if not revIDEPaletteIsVisible("tools") then revIDEOpenPalette "tools"', tools_back)

    def test_the_keys_are_the_systems_where_they_reach(self):
        shortcut = self.function('edShortcut')
        self.assertRegex(shortcut, r'^\s*if edKeysWork\(\) then\n\s*edSystemShortcut pLetter\n\s*return "the system\'s keyboard"\n\s*end if\n'
                                   r'\s*edType the short name of the topStack, pLetter, "command"\n\s*return "the engine\'s own keys')
        # (a miss by the system's keys says whether the engine's own open
        # it: keys that went elsewhere, or a shortcut that opens nothing)
        miss = self.body.split('if not edWaitFor("edOpen(pAx)", 5000, tMB) then', 1)[1].split('else if', 1)[0]
        self.assertRegex(miss, r'if tVia is "the system\'s keyboard" then\n(?:\s*--[^\n]*\n)*\s*edType sStack, "m", "command"\n'
                               r'\s*put "; typed by the engine it opened one:" && edWaitFor\("edOpen\(pAx\)", 3000, tMB\) after tMiss')

    def test_each_system_presses_its_own_keys(self):
        keys = self.handlers['edSystemShortcut']
        mac = keys.split('case "MacOS"', 1)[1].split('case "Win32"', 1)[0]
        self.assertIn('function key(k, d, f) { var e = $.CGEventCreateKeyboardEvent(null, k, d); ', mac)
        self.assertIn('$.CGEventSetFlags(e, f); $.CGEventPost(0, e);', mac)
        win = keys.split('case "Win32"', 1)[1].split('default', 1)[0]
        self.assertIn('[System.Windows.Forms.SendKeys]::SendWait(\'^" & toLower(pLetter) & "\')', win)
        self.assertIn('xdotool key ctrl+" & toLower(pLetter)', keys.split('default', 1)[1])
        codes = self.function('edMacKeyCode')
        # (kVK_ANSI_M and kVK_ANSI_X)
        self.assertRegex(codes, r'case "m"\n\s*return 46\n')
        self.assertRegex(codes, r'case "x"\n\s*return 7\n')
        name = self.function('edShortcutName')
        self.assertIn('if the platform is "MacOS" then return "Cmd+" & toUpper(pLetter)', name)
        self.assertIn('return "Ctrl+" & toUpper(pLetter)', name)

    def test_a_mac_presses_the_command_key_itself_and_lets_it_go(self):
        # macOS's first run of the task left Command held for every click
        # after it (the App Browser's next click added to its selection):
        # the letter's two events had the Command flag, and no event said
        # that Command was up. The keys in the order a hand presses them:
        # Command (key 55) down, the letter down and up with Command
        # held (kCGEventFlagMaskCommand), Command up with no flag
        keys = self.handlers['edSystemShortcut']
        mac = keys.split('case "MacOS"', 1)[1].split('case "Win32"', 1)[0]
        code = '\n'.join(line for line in mac.split('\n') if not line.lstrip().startswith('--'))
        order = ['key(55, true, 1048576); ',
                 'key(" & edMacKeyCode(pLetter) & ", true, 1048576); ',
                 'key(" & edMacKeyCode(pLetter) & ", false, 1048576); ',
                 'key(55, false, 0);']
        at = [code.index(part) for part in order]
        self.assertEqual(at, sorted(at))
        self.assertEqual(code.count('key(55, '), 2)
        self.assertNotIn('forEach', code)

    def test_the_keys_must_be_let_go(self):
        held = self.function('edKeysHeld')
        self.assertIn('if edWaitFor("the commandKey is up and the controlKey is up and the optionKey is up and the shiftKey is up", 3000) then return empty', held)
        self.assertIn('return "after" && pKeys && "was pressed, the system still holds a key down:" & tHeld', held)
        # the shortcut's task asks after both presses, with the miss kept
        # until the Tools palette is back
        after = self.body.split('get edShortcut("m")', 1)[1]
        asked = after.index('if tMiss is empty then put edKeysHeld(tKeys) into tMiss')
        self.assertLess(asked, after.index('edToolsBack tMB'))
        # and the lesson's, before its click on the Message Box's field
        lesson = self.handlers['edGuideLesson']
        opened = lesson.index('put edShortcut("m") into tVia')
        asked = lesson.index('get edKeysHeld(tKeys)', opened)
        self.assertIn('if it is not empty then throw it', lesson[asked:asked + 80])
        self.assertLess(asked, lesson.index('edClickAt tMB,', opened))

    def test_the_keys_are_checked_with_a_letter_in_a_field_of_the_tasks_own(self):
        works = self.function('edKeysWork')
        # (asked once in a run)
        self.assertRegex(works, r'^\s*local [^\n]*\n\s*if sKeep\["keysWork"\] is not empty then return sKeep\["keysWork"\]\n')
        self.assertIn('put tWorks into sKeep["keysWork"]', works)
        typed = works.index('edSystemKeys "x"')
        self.assertLess(works.index('choose browse tool'), typed)
        self.assertLess(works.index('select after text of field "Keys" of card 1 of stack tStack'), typed)
        self.assertLess(typed, works.index('put field "Keys" of card 1 of stack tStack is "x" into tWorks'))
        # (its stack is gone, and the stack that was in front is in front
        # again, before the keys that follow)
        gone = works.rindex('delete stack tStack')
        self.assertLess(typed, gone)
        self.assertLess(gone, works.index('go stack tTop'))
        self.assertIn('edRecord "INFO the system\'s keyboard reaches the IDE:" && tWorks', works)


class ShortcutCopyPaste(BuildTasks, unittest.TestCase):
    """shortcut-copy-paste presses Cmd+C and Cmd+V (Ctrl on Windows and
    Linux), each once. On macOS 15.2 a person found that the two "don't
    work the first time. The second time I do this it works fine"
    (CamelCaps, openxtalk.org p=26676, in 0.2.7 and 0.2.8-dp.2). The menu
    bar built its menus a millisecond after the mouseDown the engine sends
    it before an accelerator, and the engine picks the item as soon as
    that mouseDown returns: Copy was still disabled as the last build left
    it. The menu bar now builds at once for the mouseDown sent to its group
    itself (revmenubar.livecodescript, generateMenuGroup)."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.menubar = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript'))
        cls.body = cls.handlers['ed_shortcut_copy_paste']
        # (its code alone: a comment of it says what the task asks)
        cls.code = '\n'.join(line for line in cls.body.split('\n') if not line.lstrip().startswith('--'))

    def test_the_task_follows_copy_paste(self):
        names = tasks(self.text)
        self.assertEqual(names.index('shortcut-copy-paste'), names.index('copy-paste') + 1)
        # (duplicate, after it, works on the button copy-paste pasted, so
        # the task takes away only what its own keys pasted)
        self.assertEqual(names.index('duplicate'), names.index('shortcut-copy-paste') + 1)
        self.assertIn('put the number of buttons of card 1 of stack sStack into tCount', self.code)
        self.assertIn('repeat while the number of buttons of card 1 of stack sStack > tCount\n'
                      '      delete last button of card 1 of stack sStack\n', self.code)

    def test_the_letters_are_the_menu_items(self):
        copy = re.search(r'enableMenuItem\("&Copy" && tSelectionLabel & "/(\w)\|copy"', self.menubar)
        paste = re.search(r'enableMenuItem\("&Paste"&& tClipboardLabel & "/(\w)\|paste"', self.menubar)
        self.assertIsNotNone(copy, 'Edit > Copy has no shortcut')
        self.assertIsNotNone(paste, 'Edit > Paste has no shortcut')
        c, v = copy.group(1).lower(), paste.group(1).lower()
        # a button, then text in a field
        self.assertEqual(self.code.count('edPressedOnce("%s",' % c), 2)
        self.assertEqual(self.code.count('edPressedOnce("%s",' % v), 2)
        # and no other key: each press is one the task asks about
        self.assertEqual(self.code.count('edShortcut('), 0)
        self.assertEqual(self.code.count('edPressedOnce('), 4)

    def test_a_mac_presses_c_and_v(self):
        codes = self.function('edMacKeyCode')
        # (kVK_ANSI_C and kVK_ANSI_V)
        self.assertRegex(codes, r'case "c"\n\s*return 8\n')
        self.assertRegex(codes, r'case "v"\n\s*return 9\n')

    def test_each_key_must_work_the_first_time(self):
        once = self.function('edPressedOnce')
        first = once.index('put edShortcut(pLetter) into tVia')
        done = once.index('if edWaitFor(pTrue, 3000, pAx, pBx) then return empty')
        self.assertLess(first, done)
        # a miss is a miss of the first press, whatever a second does
        missed = once.index('&& pDid && "the first time it was pressed" into tMiss')
        self.assertLess(done, missed)
        second = once.index('get edShortcut(pLetter)')
        self.assertLess(missed, second)
        self.assertIn('put "; pressed a second time, it did" after tMiss', once)
        self.assertIn('put "; nor did a second press" after tMiss', once)
        self.assertRegex(once, r'\n\s*return tMiss\n\s*$')
        # (the task throws what the presses missed)
        self.assertIn('if tMiss is not empty then throw tMiss', self.code)

    def test_what_each_key_did_is_asked(self):
        # the button: Copy put objects on the clipboard over text the task
        # put there, and Paste made one copy of the button, not two
        self.assertLess(self.code.index('set the clipboardData["text"] to "OXT Everyday clipboard"'),
                        self.code.index('edPressedOnce("c", "with the button selected'))
        self.assertIn('"the clipboard is " & quote & "objects" & quote) into tMiss', self.code)
        self.assertIn('if the number of buttons of card 1 of stack sStack is not tCount + 1 then', self.code)
        self.assertIn('if the label of last button of card 1 of stack sStack is not the label of tButton then', self.code)
        # the field: Copy copied its text, and Paste put it after the text
        self.assertIn('"the clipboardData[" & quote & "text" & quote & "] is pAx", tFirst) into tMiss', self.code)
        self.assertIn('"the text of pAx is pBx", tField, tFirst & tFirst) into tMiss', self.code)

    def test_the_button_is_the_copy_on_top(self):
        # copy-paste's paste lies over the button it copied: a click there
        # is on the paste, so the task selects the paste
        self.assertIn('put the long id of last button of card 1 of stack sStack into tButton\n', self.code)
        self.assertLess(self.code.index('into tButton'), self.code.index('edSelect tButton'))

    def test_the_fields_keys_find_their_items_disabled(self):
        # A click in a field and a selection of its text build nothing: the
        # menus are as the last build left them. Before each of the field's
        # keys they are built with nothing selected, so that the item is
        # disabled in them, and the key must find it enabled all the same
        copy_built = self.code.index('put edMenusBuiltBare("Copy") into tMiss')
        copy_pressed = self.code.index('edPressedOnce("c", "with the field\'s text selected')
        self.assertLess(copy_built, self.code.index('select text of tField'))
        self.assertLess(self.code.index('select text of tField'), copy_pressed)
        paste_built = self.code.index('put edMenusBuiltBare("Paste") into tMiss')
        self.assertLess(copy_pressed, paste_built)
        self.assertLess(paste_built, self.code.index('select after text of tField'))
        self.assertLess(self.code.index('select after text of tField'), self.code.index('edPressedOnce("v", "did not paste'))
        # (in Run mode, where a person types and selects text)
        self.assertLess(self.code.index('edToolTile "com.livecode.tool.Browse"'), copy_built)
        bare = self.function('edMenusBuiltBare')
        for step in ('select empty', 'revIDEDeselectAll', 'focus on nothing'):
            self.assertLess(bare.index(step), bare.index('send "revMenubarBuildMenus" to stack "revMenuBar"'))
        self.assertIn('if edWaitFor("edBuiltOff(pAx)", 3000, pItem) then return empty', bare)
        # disabled is how the menu bar writes it: the item in parentheses
        enable = re.search(r'^function enableMenuItem pItem, pEnabled\n(.*?)^end enableMenuItem', self.menubar, re.M | re.S)
        self.assertIsNotNone(enable)
        self.assertIn('return "(" & pItem', enable.group(1))
        self.assertIn('return ("(&" & pItem) is in the text of button "Edit" of group "revMenuBar" of stack "revMenuBar"',
                      self.function('edBuiltOff'))

    def test_the_stack_and_the_tool_are_as_they_were(self):
        kept = self.code.index('put the text of tField into tKept')
        self.assertLess(kept, self.code.index('set the text of tField to tFirst'))
        throw = self.code.index('if tMiss is not empty then throw tMiss')
        tail = self.code[self.code.index('edShotStack sStack, "22c-shortcut-pasted-text"'):throw]
        for step in ('select empty', 'if tField is not empty then set the text of tField to tKept',
                     'edToolTile "com.livecode.tool.Pointer"',
                     'get edWaitFor("the tool is " & quote & "pointer tool" & quote, 3000)'):
            self.assertIn(step, tail)
        self.assertNotIn('throw', tail, 'a throw here would leave the field and the tool for the tasks after')
        # (and no key held for the clicks after)
        self.assertIn('if tMiss is empty then put edKeysHeld(edShortcutName("v")) into tMiss', tail)

    def test_the_menu_bar_builds_at_once_for_its_groups_own_mousedown(self):
        group = re.search(r'^on generateMenuGroup\n(.*?)^end generateMenuGroup', self.menubar, re.M | re.S)
        self.assertIsNotNone(group, 'generateMenuGroup not found')
        script = group.group(1)
        down = script.index('put "on mouseDown" & return &')
        built = script.index('"if the long id of the target is the long id of me then" & return &', down)
        now = script.index('"revMenubarBuildMenus true" & return &', built)
        later = script.index('"else" & return &', now)
        sent = script.index('"send revMenubarBuildMenus to this stack in 1 millisecond" & return &', later)
        ended = script.index('"end if" & return &', sent)
        self.assertLess(ended, script.index('"pass mousedown" & return &', down))
        # and a build for it is not skipped for one already waiting, which
        # would build later; every other build still is
        build = re.search(r'^command revMenubarBuildMenus pNow\n(.*?)^end revMenubarBuildMenus', self.menubar, re.M | re.S)
        self.assertIsNotNone(build, 'revMenubarBuildMenus takes no pNow')
        self.assertRegex(build.group(1), r'^\s*if pNow is not true and the pendingmessages contains "revMenubarBuildMenus" '
                                         r'then exit revMenubarBuildMenus')
        # (pNow is passed by the group alone: the other builds wait their turn)
        self.assertEqual(self.menubar.count('revMenubarBuildMenus true'), 1)


class ImportImageSystemDialog(BuildTasks, unittest.TestCase):
    """import-image-system-dialog picks File > Import As Control > Image
    File... with the system's own file dialog and a lot of windows open,
    on macOS, where a person found that "with a lot of windows/stacks
    open" the dialog "does not always open" (CamelCaps, openxtalk.org
    p=26676). The dialog holds the IDE while it is open, so a watcher
    started before the item is picked (osascript, in the background) lists
    the system's windows, writes what it found and presses Escape."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.body = cls.handlers['ed_import_image_system_dialog']
        cls.code = '\n'.join(line for line in cls.body.split('\n') if not line.lstrip().startswith('--'))
        cls.watcher = cls.handlers['edDialogWatcher']

    def watcher_script(self):
        """The watcher's JavaScript as the shell gets it, the IDE's process
        ID and the file put in."""
        expr = self.watcher.split('put "', 1)[1].split(' into tScript', 1)[0]
        expr = '"' + expr.replace('& \\\n', '&')
        parts = []
        for text, name in re.findall(r'"([^"]*)"|& (the processID|pFile) &', expr):
            parts.append({'the processID': '1234', 'pFile': '/tmp/dialog.txt'}.get(name, text))
        return ''.join(parts)

    def test_the_task_is_the_last_before_finish(self):
        # a dialog that held the IDE for good holds no task after it
        names = tasks(self.text)
        self.assertEqual(names[-2:], ['import-image-system-dialog', 'finish'])

    def test_it_is_macos_s(self):
        self.assertRegex(self.code, r'^\s*local [^\n]*\n\s*if the platform is not "MacOS" then\n[^\n]*\n\s*return "skipped"\n')

    def test_the_systems_dialog_with_a_lot_of_windows_open(self):
        made = self.code.index('repeat with i = 1 to 12')
        self.assertIn('create stack tName', self.code[made:])
        self.assertIn('revIDEOpenPalette "message box"', self.code)
        self.assertIn('revIDEOpenPalette "project browser"', self.code)
        on = self.code.index('set the systemFileSelector to true')
        self.assertLess(made, on)
        self.assertLess(on, self.code.index('repeat for each item tRound in "the stack,a palette,a new stack"'))

    def test_the_watcher_starts_before_the_item_is_picked(self):
        started = self.code.index('edDialogWatcher tFile')
        listed = self.code.index('if not edWaitFor("there is a file pAx", 15000, tFile & ".base") then')
        picked = self.code.index('edMenu "File", "Import As Control|image"')
        self.assertLess(started, listed)
        self.assertLess(listed, picked)
        # (and what it wrote is read once the dialog has closed)
        self.assertLess(picked, self.code.index('put textDecode(URL ("binfile:" & tFile), "UTF-8") into tFound'))

    def test_each_round_has_its_own_files(self):
        # "the stack" and "a new stack" once both wrote dialog-stack.txt:
        # the third round found the first's files already there, so it
        # picked the item before its own watcher had listed a window and
        # read the first round's record (#623's Intel Mac: the same windows
        # at the same milliseconds both times)
        loop = self.code[self.code.index('repeat for each item tRound in'):]
        loop = loop[:loop.index('end repeat')]
        named = re.search(r'put sWork & "/dialog-" & (.+?) & "\.txt" into tFile', loop)
        self.assertIsNotNone(named)
        self.assertEqual(named.group(1), 'tN')
        self.assertEqual(loop.count('add 1 to tN'), 1)
        self.assertLess(loop.index('add 1 to tN'), named.start())
        self.assertRegex(self.code, r'^\s*local [^\n]*\btN\b')
        # (and nothing in their place before the watcher starts)
        started = loop.index('edDialogWatcher tFile')
        for gone in ('if there is a file tFile then delete file tFile',
                     'if there is a file (tFile & ".base") then delete file (tFile & ".base")'):
            self.assertLess(named.end(), loop.index(gone))
            self.assertLess(loop.index(gone), started)

    def test_each_round_asks_for_the_dialog_in_front_and_closed(self):
        for line in ('if line 1 of tFound is not "opened" then',
                     'else if line 2 of tFound is not "in front" then',
                     'else if line 3 of tFound is not "closed" then'):
            self.assertIn(line, self.code)
        # (each round's record, whatever it found)
        self.assertIn('edRecord "INFO import-image-system-dialog, after" && tRound & ":" && edJoin(tFound)', self.code)

    def test_the_ide_is_as_it_was_before_the_throw(self):
        throw = self.code.index('if tMiss is not empty then throw')
        self.assertEqual(self.code.count('throw'), 2, 'a throw before the rounds end would leave the stacks and the dialog setting')
        tail = self.code[self.code.index('end repeat\n   set the systemFileSelector to false'):throw]
        self.assertIn('if there is a stack tName then delete stack tName', tail)
        # (a cancelled dialog imports nothing)
        self.assertIn('if the number of images of card 1 of stack sStack is not tCount then', tail)

    def test_the_watcher_reaches_osascript_as_written(self):
        # one argument in double quotes to the shell: no double quote,
        # backslash or backtick in it, and no $ the shell would expand
        script = self.watcher_script()
        self.assertTrue(script.startswith("ObjC.import('CoreGraphics');"), script[:60])
        for char in '"\\`':
            self.assertNotIn(char, script)
        self.assertIsNone(re.search(r'\$[A-Za-z_{(]', script))
        self.assertIn('get shell("osascript -l JavaScript -e " & quote & tScript & quote & " >/dev/null 2>&1 &")', self.watcher)

    def test_the_watcher_lists_before_it_looks_and_presses_escape(self):
        script = self.watcher_script()
        self.assertIn('var pid = 1234;', script)
        base = script.index("write(path + '.base', 'listed');")
        self.assertLess(script.index('all().forEach(function (w) { before[w.kCGWindowNumber] = true; });'), base)
        self.assertLess(base, script.index('var found = null;'))
        # (Escape is key 53, kVK_Escape, down and up)
        self.assertIn('$.CGEventCreateKeyboardEvent(null, 53, d)', script)
        self.assertLess(script.index('var found = null;'), script.index('esc(); delay(1.5);'))
        self.assertIn("lines.push(gone ? 'closed' : 'still open after Escape four times');", script)
        self.assertIn("write(path, lines.join(String.fromCharCode(10)));", script)

    def test_the_dialog_is_the_new_window_on_the_screen(self):
        # The first run on an Intel Mac (#623, 2026-11-22) took the first
        # new window for the dialog: after a palette, the Open and Save
        # Panel Service's own window, never on the screen, while the panel
        # the IDE showed (its layer 8 window, 800 x 448 in the middle of
        # the screen) was in front; after a stack, a 0 x 0 window of the
        # IDE's, one second before the panel was looked for again. The
        # dialog is now the new window ON the screen, the highest layer
        # and then the largest, of the IDE or the panel service
        script = self.watcher_script()
        self.assertIn("function ours(w) { return (w.kCGWindowOwnerPID == pid || /Open|Panel/.test(w.kCGWindowOwnerName || '')) && !before[w.kCGWindowNumber] && w.kCGWindowLayer >= 0 && w.kCGWindowLayer < 20; }", script)
        self.assertIn("var on = shown().filter(function (w) { return ours(w) && w.kCGWindowBounds.Width > 1 && w.kCGWindowBounds.Height > 1; });", script)
        self.assertIn("on.sort(function (a, b) { return (b.kCGWindowLayer - a.kCGWindowLayer) || (area(b) - area(a)); });", script)
        # (eight seconds more for it to show, once a new window is there:
        # a dialog that never shows is the report's)
        self.assertIn('for (var j = 0; j < 32 && order.length && !found; j++) { delay(0.25); found = look(); }', script)
        self.assertIn("else if (!found) { lines.push('opened, but not on the screen in eight seconds'); lines.push(''); }", script)
        # (every new window is written, with when it came)
        self.assertIn("lines.push('new windows: ' + ", script)
        self.assertIn("seen[w.kCGWindowNumber] = Date.now() - t0;", script)

    @unittest.skipUnless(shutil.which('node'), 'node runs the watcher against the windows macOS listed')
    def test_the_watcher_reads_what_the_intel_mac_listed(self):
        # The watcher's script run against CGWindowListCopyWindowInfo as it
        # answered on the Mac runners (#623's first runs), and as it would
        # for a dialog that shows late, never shows, or shows behind another
        # window
        mock = r"""
const src = require('fs').readFileSync(process.argv[2], 'utf8');
const W = (n, pid, owner, layer, x, y, w, h, on) => ({ kCGWindowNumber: n, kCGWindowOwnerPID: pid, kCGWindowOwnerName: owner, kCGWindowLayer: layer, kCGWindowBounds: { X: x, Y: y, Width: w, Height: h }, kCGWindowIsOnscreen: on });
const panel = W(9, 1234, 'OXT-Beyond', 8, 560, 156, 800, 448, true);
const service = W(8, 77, 'Open and Save Panel Service', 0, 100, 532, 800, 448, false);
const zero = W(7, 1234, 'OXT-Beyond', 0, 0, 0, 0, 0, false);
const finder = W(5, 55, 'Finder', 0, 0, 0, 1440, 900, true);
const grown = W(7, 1234, 'OXT-Beyond', 8, 112, 84, 800, 448, true);
const cases = { 'a palette': [[1, service], [1.25, panel]], 'grows': [[1, zero], [1.25, grown]], 'late': [[1, zero], [3.5, panel]], 'never shown': [[1, zero]],
                'behind': [[1, panel], [1, finder]], 'none': [] };
const out = {};
for (const name of Object.keys(cases)) {
  let t = 0, closed = false, file = '';
  const base = [W(1, 1234, 'OXT-Beyond', 0, 100, 100, 400, 300, true), W(3, 99, 'Dock', 20, 0, 0, 1920, 1080, true)];
  // (a window listed again later is the same window, changed: the last listing of each number wins)
  const list = (o) => { const by = new Map(); if (!closed) cases[name].filter(a => t >= a[0]).forEach(a => { by.delete(a[1].kCGWindowNumber); by.set(a[1].kCGWindowNumber, a[1]); }); let l = Array.from(by.values()).reverse().concat(base); return o === 17 ? l.filter(w => w.kCGWindowIsOnscreen) : l; };
  const $ = { CGWindowListCopyWindowInfo: list, CGEventCreateKeyboardEvent: (n, k, d) => ({ k, d }),
              CGEventPost: (p, e) => { if (e.k === 53 && e.d) closed = true; },
              NSString: { alloc: { initWithUTF8String: (s) => ({ writeToFileAtomicallyEncodingError: (p) => { if (p === '/tmp/dialog.txt') file = s; } }) } } };
  new Function('ObjC', '$', 'delay', 'Date', src)({ import() {}, deepUnwrap: x => x, castRefToObject: x => x }, $, (s) => { t += s; }, { now: () => Math.round(t * 1000) });
  out[name] = file.split(String.fromCharCode(10));
}
console.log(JSON.stringify(out));
"""
        import json
        with tempfile.TemporaryDirectory() as work:
            with open(os.path.join(work, 'watcher.js'), 'w') as f:
                f.write(self.watcher_script())
            with open(os.path.join(work, 'mock.js'), 'w') as f:
                f.write(mock)
            run = subprocess.run(['node', os.path.join(work, 'mock.js'), os.path.join(work, 'watcher.js')],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=60)
        self.assertEqual(run.returncode, 0, run.stderr)
        found = json.loads(run.stdout)
        # (after a palette on the Intel Mac: the service's window a poll
        # before the panel, and the dialog is the panel)
        self.assertEqual(found['a palette'][:3], ['opened', 'in front', 'closed'])
        self.assertEqual(found['a palette'][3], 'the dialog: OXT-Beyond 1234 layer 8 at 560,156,800,448')
        self.assertIn('Open and Save Panel Service 77 layer 0 at 100,532,800,448 (not on the screen) at 1000 ms', found['a palette'][4])
        self.assertIn('OXT-Beyond 1234 layer 8 at 560,156,800,448 at 1250 ms', found['a palette'][4])
        # (after a stack on the Apple Silicon Mac: the IDE's new window is
        # 0 x 0 and off the screen, and a poll later the same window is the
        # panel, at layer 8 in the middle of the screen)
        self.assertEqual(found['grows'][:3], ['opened', 'in front', 'closed'])
        self.assertEqual(found['grows'][3], 'the dialog: OXT-Beyond 1234 layer 8 at 112,84,800,448')
        self.assertEqual(found['grows'][4], 'new windows: OXT-Beyond 1234 layer 0 at 0,0,0,0 (not on the screen) at 1000 ms')
        # (a panel that shows two and a half seconds after the first window)
        self.assertEqual(found['late'][:3], ['opened', 'in front', 'closed'])
        self.assertIn('OXT-Beyond 1234 layer 8 at 560,156,800,448 at 3500 ms', found['late'][4])
        # (one that never shows, as CamelCaps found)
        self.assertEqual(found['never shown'][:3], ['opened, but not on the screen in eight seconds', '', 'closed'])
        self.assertEqual(found['never shown'][3], 'the dialog: none on the screen')
        self.assertEqual(found['behind'][:2], ['opened', 'Finder 55 layer 0 at 0,0,1440,900'])
        self.assertEqual(found['none'][:2], ['no new window of the IDE in ten seconds', ''])


class QuickStartFirstLesson(BuildTasks, unittest.TestCase):
    """quick-start-first-lesson does the Quick Start Guide's first lesson
    as its notes say: the first example Learn offers. A newcomer could not
    do it from the notes (openxtalk.org p=26390): they do not say that
    "the stack" is the lesson's own window ("the lesson skips to say:
    Create a new stack"), and "Ctrl-M or Tools > Message Box" reads as
    something in the Tools palette to put on the card. The builder now
    says both, the stack is built from it, and the task reads the words in
    the stack the IDE installs before it does what they say."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.guide = read(os.path.join(ROOT, 'tools', 'examples', 'quick-start.livecodescript'))
        cls.learn = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript'))
        cls.lesson = cls.handlers['edGuideLesson']
        with open(os.path.join(ROOT, 'ide', 'Resources', 'Examples', 'Remastered', 'Quick Start Guide.oxtstack'), 'rb') as f:
            cls.stack = f.read()
        with open(os.path.join(ROOT, 'tools', 'examples', 'originals', 'Quick Start.oxtstack'), 'rb') as f:
            cls.original = f.read()

    def changes(self):
        """What lessonText changes in Terry Little's words: (from, to)"""
        m = re.search(r'^private function lessonText\b.*?^end lessonText', self.guide, re.M | re.S)
        self.assertIsNotNone(m)
        body = m.group(0).replace('\\\n', ' ')
        found = re.findall(r'^\s*textChange tText, "([^"]*)",\s+"([^"]*)"$', body, re.M)
        self.assertEqual(len(found), len(re.findall(r'^\s*textChange ', body, re.M)), 'a change that is not two plain texts')
        return found

    def test_the_guide_is_learns_first_example(self):
        first = self.learn.split('private function leExampleTable', 1)[1].split('return after tTable', 1)[0]
        self.assertIn('|Resources/%s|%s"' % (self.constant('kGuideFile'), self.constant('kGuideStack')), first)
        self.assertTrue(os.path.isfile(os.path.join(ROOT, 'ide', 'Resources', self.constant('kGuideFile'))))
        self.assertIn(self.constant('kGuideLesson'), re.search(r'^constant kLessons = "([^"]*)"', self.guide, re.M).group(1).split(',')[0])

    def test_it_is_opened_as_learn_opens_an_example(self):
        opened = self.learn.split('private command leOpenExample', 1)[1].split('end leOpenExample', 1)[0]
        self.assertLess(opened.index('choose browse tool'), opened.index('go stack tFile'))
        self.assertLess(self.lesson.index('edToolTile "com.livecode.tool.Browse"'), self.lesson.index('go stack pFile'))
        # (and the lesson by a click on the front page's first tile)
        self.assertIn('edClickAt kGuideStack, the loc of group "tile1" of card 1 of stack kGuideStack', self.lesson)

    def test_the_words_say_what_a_newcomer_could_not_tell(self):
        changes = dict(self.changes())
        self.assertEqual(changes['palette to the stack.'], 'palette to the stack: this window, in its Try It box.')
        self.assertEqual(changes['1. Ctrl-M or Tools > Message Box.'],
                         '1. Ctrl-M (Cmd-M on a Mac) or menu Tools > Message Box: a small window of its own opens.')
        self.assertIn('Do each Try It here: this window is the stack."', self.guide)
        self.assertNotIn('beside this window', self.guide)
        # (and which tile the standard button is: "the top gray button"
        # fits the Tools palette's classic look alone, and a new install
        # shows the modern one, openxtalk.org p=26402. The notes and the
        # narrator have their own words for it, each changed)
        said = "the first one under Controls, which reads OK; in the palette's classic look, the top gray button"
        self.assertEqual(changes['the top gray button (standard button)'], 'a standard button (%s)' % said)
        self.assertEqual(changes['the top gray button, (a standard button),'], 'a standard button, (%s),' % said)
        # (the Try It box says so itself)
        self.assertIn('buildCanvas "TRY IT", "Drag a button here from the Tools palette.", true', self.guide)

    def test_what_is_changed_is_in_his_stack(self):
        # (the build stops where his text no longer has the words: here,
        # before a build)
        for old, new in self.changes():
            self.assertIn(old.lower().encode('ascii'), self.original.lower(), old)
            self.assertNotIn(new.lower().encode('ascii'), self.original.lower(), new)

    def test_a_line_of_the_notes_stays_a_line(self):
        # (lesson 3 has the reader count the lines of the notes)
        for old, new in self.changes():
            self.assertNotRegex(new, r'[\r\n]')
        m = re.search(r'^private function lessonText\b.*?^end lessonText', self.guide, re.M | re.S)
        self.assertNotIn('return', m.group(0).replace('return tText', ''))

    def test_the_stack_installed_is_built_from_these_words(self):
        for old, new in self.changes():
            self.assertIn(new.encode('ascii'), self.stack, 'the stack was not built again after its builder changed: ' + new)
        self.assertIn(b'Do each Try It here: this window is the stack.', self.stack)
        self.assertNotIn(b'1. Ctrl-M or Tools > Message Box.', self.stack)
        self.assertNotIn(b'beside this window', self.stack)

    def test_the_task_reads_those_words_in_the_stack(self):
        changes = dict(self.changes())
        m = re.search(r'put line lineOffset\("from the tools palette to the stack", tNotes\) of tNotes into tLine\n\s*if (.*?) then\n', self.lesson)
        self.assertIsNotNone(m)
        words = re.findall(r'"([^"]+)" is not in tLine', m.group(1))
        self.assertEqual(words, ['this window', 'Try It box'])
        for word in words:
            self.assertIn(word, changes['palette to the stack.'])
            self.assertNotIn(word.encode('ascii'), self.original)
        # (the line is found by words of his that are still in it)
        self.assertIn(b'from the tools palette to the stack', self.original)
        m = re.search(r'\n\s*if ("under Controls" is not in tLine.*?) then\n\s*throw "the notes do not say which tile', self.lesson)
        self.assertIsNotNone(m)
        words = re.findall(r'"([^"]+)" is not in tLine', m.group(1))
        self.assertEqual(words, ['under Controls', 'reads OK', 'classic look'])
        for word in words:
            self.assertIn(word, changes['the top gray button (standard button)'])
            self.assertNotIn(word.encode('ascii'), self.original)
        m = re.search(r'put line lineOffset\("Tools > Message Box", tNotes\) of tNotes into tLine\n\s*if (.*?) then\n', self.lesson)
        self.assertIsNotNone(m)
        words = re.findall(r'"([^"]+)" is not in tLine', m.group(1))
        self.assertEqual(words, ['menu Tools > Message Box', 'window', 'Cmd-M'])
        for word in words:
            self.assertIn(word, changes['1. Ctrl-M or Tools > Message Box.'])
        self.assertIn('if "this window is the stack" is not in field "step2_text" of card 1 of stack kGuideStack then', self.lesson)
        # (read before anything is done: a lesson that does not say it is
        # not done as if it did)
        self.assertLess(self.lesson.index('put line lineOffset("Tools > Message Box", tNotes)'), self.lesson.index('edToolFilter "button"'))

    def test_the_tile_the_notes_name_is_the_palettes_first(self):
        # "under Controls" is the modern look's section of the classic
        # controls, by its title in the palette's own list
        tools = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'tools', 'revtools.livecodescript'))
        sections = re.search(r'^constant kTmSections = "([^"]*)"', tools, re.M).group(1).split('\\n')
        self.assertIn('classic|Controls|classic', sections)
        # and "the first one" is looked for in the palette itself, in both
        # looks, before the tile is used: the topmost shown tile of the
        # classic controls, and of a row the leftmost
        first = self.function('edFirstControlTile')
        self.assertIn('if not (tName begins with "com.livecode.interface.classic.") then next repeat', first)
        self.assertIn('if not the effective visible of tTile then next repeat', first)
        self.assertIn('the top of tTile < tTop - 4 or (abs(the top of tTile - tTop) <= 4 and the left of tTile < tLeft)', first)
        check = self.handlers['edGuideTileIsFirst']
        self.assertIn('repeat for each item tTry in "modern,classic"', check)
        self.assertIn('edWaitFor("edToolsLookOn(pAx) and edFirstControlTile() is pBx", 6000, tTry, "com.livecode.interface.classic.button")', check)
        self.assertLess(self.lesson.index('edGuideTileIsFirst'), self.lesson.index('edToolFilter "button"'))
        # (a section folded or left out would hide the tiles: the modern
        # look is read with its Controls shown and unfolded, as a new
        # install has them, before the first tile is asked for)
        modern = re.search(r'if tTry is "modern" then\n(.*?)\n\s*end if\n\s*if not edWaitFor\("edToolsLookOn\(pAx\) and edFirstControlTile\(\) is pBx"', check, re.S)
        self.assertIsNotNone(modern)
        self.assertRegex(modern.group(1), r'if not edToolsSectionShown\("classic"\) then\n\s*edToolsSection "classic"\n\s*put true into tShown\n\s*end if\n'
                                          r'\s*if edToolsFolded\("classic"\) then\n\s*edToolsCaption "classic"\n\s*put true into tUnfolded\n\s*end if')
        self.assertLess(check.index('if not edWaitFor("edToolsLookOn(pAx)", 6000, tTry) then throw'), modern.start())

    def test_the_palette_is_left_as_it_was(self):
        check = self.handlers['edGuideTileIsFirst']
        loop_end = check.index('end try')
        self.assertIn('put revIDEGetPreference("revTools_look") into tLook', check[:check.index('try')])
        put_back = 'if revIDEGetPreference("revTools_look") is not tLook then revIDESetPreference "revTools_look", tLook'
        # (put back after the try, so also when a look was not as said)
        self.assertGreater(check.index(put_back), loop_end)
        self.assertLess(check.index(put_back), check.index('if tError is not empty then throw tError'))
        self.assertIn('if not edWaitFor("edToolsLookOn(pAx)", 6000, tNow) then', check[check.index(put_back):])
        # what it unfolded is folded again and what it turned on is turned
        # off, in that order and whatever the check found, in the modern
        # look (the classic one has neither), before the look is put back
        mine = check.index('if tUnfolded is true or tShown is true then')
        modern = check.index('if revIDEGetPreference("revTools_look") is "classic" then revIDESetPreference "revTools_look", "modern"', mine)
        fold = check.index('if tUnfolded is true and not edToolsFolded("classic") then edToolsCaption "classic"')
        hide = check.index('if tShown is true and edToolsSectionShown("classic") then edToolsSection "classic"')
        self.assertLess(loop_end, mine)
        self.assertLess(mine, modern)
        self.assertLess(modern, fold)
        self.assertLess(fold, hide)
        self.assertLess(hide, check.index(put_back))
        self.assertRegex(check[mine:], r'catch tAgain\n\s*if tError is empty then put tAgain into tError')
        # No task writes the two settings itself: the palette does not
        # read them again when they change, so what is shown would not be
        # what they say
        code = '\n'.join(line for line in self.text.split('\n') if not line.lstrip().startswith('--'))
        self.assertNotIn('revIDESetPreference "revTools_modernFolded"', code)
        self.assertNotIn('revIDESetPreference "revTools_modernShow"', code)
        on = self.function('edToolsLookOn')
        self.assertIn('if pLook is "classic" then return there is a button "tmModernLook" of card 1 of stack "revTools"', on)
        self.assertIn('return there is a group "tmHeader" of card 1 of stack "revTools"', on)
        tools = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'tools', 'revtools.livecodescript'))
        self.assertIn('create button "tmModernLook" in card 1 of stack "revTools"', tools)
        self.assertIn('if there is a group "tmHeader" of me then tmTeardown', tools)
        # and the look is on again, with the tile, before the tile is dragged
        after = self.lesson[self.lesson.index('edGuideTileIsFirstWhen "hidden"'):]
        self.assertRegex(after, r'edToolFilter "button"\n\s*put edTile\("com.livecode.interface.classic.button"\) into tTile\n\s*if tTile is empty then throw')

    def test_a_folded_controls_section_is_unfolded_by_its_caption(self):
        # The palette keeps what is folded in its own script, and reads
        # the setting only while nothing is folded there: to empty the
        # setting does not unfold a section folded earlier in the session
        # (found in the review of #531). The first tile shown was then a
        # shape's, and the lesson was said to be wrong
        tools = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'tools', 'revtools.livecodescript'))
        self.assertIn('if sTmFolded is empty then put revIDEGetPreference("revTools_modernFolded") into sTmFolded', tools)
        self.assertNotIn('case "revTools_modernFolded"', tools)
        # folded is read from the caption's arrow, as the palette lays it out
        self.assertRegex(tools, r'if tFolded then\n\s*set the icon of button \("tmCapHit:" & tKey\) of me to the id of image "tm.chevRight" of me')
        folded = self.function('edToolsFolded')
        self.assertIn('return the icon of button ("tmCapHit:" & pKey) of stack "revTools" is the id of image "tm.chevRight" of stack "revTools"', folded)
        # and the caption is pressed as the palette takes a press
        self.assertRegex(tools, r'case tName begins with "tmCap"\n\s*tmFold the cTmSection of pTarget')
        self.assertIn('if tmMouseDown(pButton, the long id of the target) then exit mouseDown', tools)
        caption = self.handlers['edToolsCaption']
        self.assertIn('send "mouseDown 1" to button ("tmCapHit:" & pKey) of stack "revTools"', caption)
        self.assertIn('if not edWaitFor("edToolsFolded(pAx) is not pBx", 3000, pKey, tWas) then', caption)

    def test_a_section_left_out_is_turned_on_as_the_palettes_menu_does_it(self):
        # The palette makes its tiles from revTools_modernShow when it
        # builds the look, and is not told when the setting changes: to
        # empty it in the modern look showed nothing more (found in the
        # review of #532). Its menu's command builds the look again
        tools = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'tools', 'revtools.livecodescript'))
        self.assertNotIn('revIDESubscribe "idePreferenceChanged:revTools_modernShow"', tools)
        toggle = re.search(r'^command tmToggleSection pView\n(.*?)^end tmToggleSection', tools, re.M | re.S).group(1)
        self.assertRegex(toggle, r'revIDESetPreference "revTools_modernShow", tShow\n\s*if tmIsModern\(\) then\n\s*lock screen\n\s*tmGenerate\n\s*tmLayout')
        self.assertRegex(tools, r'case "Controls"\n\s*tmToggleSection "classic"')
        self.assertIsNotNone(re.search(r'^function tmShownSections\n', tools, re.M))
        shown = self.function('edToolsSectionShown')
        self.assertRegex(shown, r'dispatch function "tmShownSections" to stack "revTools"\n\s*return pView is among the items of the result')
        section = self.handlers['edToolsSection']
        self.assertIn('dispatch "tmToggleSection" to stack "revTools" with pView', section)
        self.assertIn('if not edWaitFor("edToolsSectionShown(pAx) is not pBx", 3000, pView, tWas) then', section)

    def test_the_tile_is_looked_for_with_the_controls_folded_and_left_out_too(self):
        # (in every run, so that the check is seen to unfold them and to
        # turn them on: with either taken out of it, the lesson's task
        # stops on "the first is com.livecode.interface.classic.FivePointStar",
        # a shape's tile)
        self.assertRegex(self.lesson, r'edGuideTileIsFirst\n\s*edGuideTileIsFirstWhen "folded"\n\s*edGuideTileIsFirstWhen "hidden"\n\s*edToolFilter "button"')
        too = self.handlers['edGuideTileIsFirstWhen']
        run = too.index('edGuideTileIsFirst\n')
        hidden = re.search(r'if pHow is "hidden" then\n\s*if edToolsSectionShown\("classic"\) then\n\s*edToolsSection "classic"\n\s*put true into tDid\n\s*end if\n', too)
        self.assertIsNotNone(hidden)
        fold = too.index('if not edToolsFolded("classic") then\n')
        self.assertLess(hidden.start(), fold)
        self.assertLess(fold, run)
        self.assertRegex(too[fold:run], r'edToolsCaption "classic"\n\s*put true into tDid')
        # folded: the check starts in the look the palette had. Left out:
        # in the modern look, where no change of look builds it again
        classic = too.index('revIDESetPreference "revTools_look", "classic"')
        self.assertLess(fold, classic)
        self.assertLess(classic, run)
        self.assertNotIn('revTools_look', too[hidden.start():hidden.end()])
        # the check must leave them as they were, and the setting saying so
        after = too[run:too.index('catch tError')]
        self.assertIn('if edToolsSectionShown("classic") or edTile(tButton) is not empty then', after)
        self.assertIn('if not edToolsFolded("classic") then throw "the check of the tile left the Controls unfolded, which were folded"', after)
        said = 'if "classic" is not among the items of revIDEGetPreference("revTools_modernFolded") then'
        self.assertEqual(too.count(said), 2)
        self.assertLess(too.index(said), run)
        self.assertLess(run, too.index(said, run))
        # and what this folded or turned off is put back, and the look,
        # after the try: whatever was found
        end = too.index('end try')
        back = too.index('if tDid is true or tShown is true then')
        look = too.index('if revIDEGetPreference("revTools_look") is not tLook then revIDESetPreference "revTools_look", tLook')
        self.assertLess(end, back)
        self.assertRegex(too[back:look], r'if pHow is "hidden" then\n\s*if not edToolsSectionShown\("classic"\) then\n\s*edToolsSection "classic"\n\s*end if\n\s*else\n'
                                         r'\s*if tDid is true and edToolsFolded\("classic"\) then edToolsCaption "classic"\n'
                                         r'\s*if tShown is true and edToolsSectionShown\("classic"\) then edToolsSection "classic"\n')
        self.assertLess(look, too.index('if tError is not empty then throw tError'))

    def test_the_button_made_is_the_notes_button_2(self):
        self.assertEqual(dict(self.changes())['button 3 to'], 'button 2 to')
        self.assertIn('if tCount is not 1 then throw', self.lesson)
        made = self.lesson.index('if not edWaitFor("the number of buttons of pAx is 2", 6000, tCard) then')
        self.assertLess(self.lesson.index('edSystemDrag tFrom, '), made)
        self.assertLess(made, self.lesson.index('put the long id of button 2 of tCard into tNew'))
        self.assertIn('if the long id of the owner of tNew is not tCard then throw', self.lesson)
        # (dropped in the Try It box, where the notes send it)
        self.assertIn('put (the right of image "Canvas" of tCard - 48) & "," & (the bottom of image "Canvas" of tCard - 54) into tDrop', self.lesson)
        self.assertIn('if sInput is true and not (tDrop is within the rect of tNew) then throw', self.lesson)

    def test_it_is_named_in_the_inspector_the_notes_open(self):
        named = self.lesson.index('edTypeInEditor tPI, "name", "Color"')
        self.assertLess(self.lesson.index('edMenu "Object", "Object Inspector"'), named)
        self.assertLess(named, self.lesson.index('edShortcut("m")'))

    def test_the_lessons_own_lines_are_run_in_the_message_box(self):
        # (read from the notes: what a reader types is what is typed)
        colour = self.lesson.index('put line lineOffset("set the backColor of button", tNotes) of tNotes into tCode')
        border = self.lesson.index('put line lineOffset("set the showBorder of button", tNotes) of tNotes into tCode')
        self.assertLess(self.lesson.index('if not edWaitFor("edOpen(pAx)", 5000, tMB) then throw'), colour)
        self.assertLess(colour, border)
        self.assertEqual(self.lesson.count('edType tMB, tCode & return'), 2)
        self.assertEqual(self.lesson.count('if tCode is empty then throw'), 2)
        self.assertIn('if not edWaitFor("the backColor of pAx is " & quote & "red" & quote, 3000, tNew) then', self.lesson)
        self.assertIn('if not edWaitFor("the showBorder of pAx is false", 3000, tNew) then', self.lesson)
        # (and those lines are in the stack as the notes give them)
        self.assertIn(b' the backColor of button ', self.stack)
        self.assertIn(b' the showBorder of button 2 to ', self.stack)

    def test_the_guide_leaves_memory_unsaved_whatever_happened(self):
        body = self.handlers['ed_quick_start_first_lesson']
        done = body.index('edGuideLesson tFile')
        away = body.index('edGuideAway')
        self.assertLess(body.index('try'), done)
        self.assertLess(body.index('catch tError', done), away)
        self.assertNotIn('throw', body[done:away])
        self.assertLess(away, body.index('if tMiss is not empty then throw tMiss'))
        # (and the task says so itself: the run's own Guide must be gone)
        self.assertIn('if edInMemory(kGuideStack) then throw "the Quick Start Guide is still in memory after the lesson"', body[away:])
        self.assertIn('edGuideGone', self.handlers['edGuideAway'])
        self.assertIn('edGuideGone', self.handlers['ed_finish'])
        self.assertIn('edRemoveBuiltStack kGuideStack', self.handlers['edGuideGone'])
        removed = self.handlers['edRemoveBuiltStack']
        self.assertLess(removed.index('revIDESetEdited pStack, false'), removed.index('delete stack pStack'))
        self.assertNotIn('save ', self.lesson)

    def test_a_guide_a_person_has_open_is_left_alone(self):
        body = self.handlers['ed_quick_start_first_lesson']
        self.assertLess(body.index('if edInMemory(kGuideStack) then throw'), body.index('try'))
        # Nor does the end of the run delete it (ed_finish runs whatever
        # tasks ran, the lesson's or not): one handler takes the Guide
        # out of memory, and only when this run opened it, which the
        # handler that opens the file notes as it does
        gone = self.handlers['edGuideGone']
        mine = 'if sKeep["guide"] is not true then exit edGuideGone'
        self.assertLess(gone.index(mine), gone.index('edRemoveBuiltStack kGuideStack'))
        code = '\n'.join(line for line in self.text.split('\n') if not line.lstrip().startswith('--'))
        self.assertEqual(code.count('edRemoveBuiltStack kGuideStack'), 1)
        self.assertNotIn('delete stack kGuideStack', code)
        # (two handlers open the Guide's file, the lesson and the one that
        # drops controls on its Try It box: each notes it on the line
        # before, and nothing else in the tasks does either)
        self.assertEqual(code.count('put true into sKeep["guide"]'), 2)
        self.assertEqual(code.count('go stack pFile'), 2)
        for opener in (self.lesson, self.handlers['edGuideDropped']):
            self.assertEqual(opener.count('put true into sKeep["guide"]'), 1)
            self.assertEqual(opener.count('go stack pFile'), 1)
            self.assertRegex(opener, r'put true into sKeep\["guide"\]\n\s*go stack pFile\n')


class QuickStartDroppedShows(BuildTasks, unittest.TestCase):
    """quick-start-dropped-shows drags a standard button, a label field
    and a check box onto the Try It box of the Quick Start Guide's first
    lesson, and each must be seen there. In the dark look the system draws
    a new control for a dark window, with white words, and the lessons'
    stage stayed light, as the stage of an example with a program does: a
    reader on a Mac, and one on Windows 11, found what they dragged there
    "almost invisible" (openxtalk.org p=26402). The lessons' cards now say
    that their stage follows the look (cStageFollowsLook), the builder
    colours the Try It box, the notes' code and the narrator's words for
    both looks, and the stack is built from it."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.guide = read(os.path.join(ROOT, 'tools', 'examples', 'quick-start.livecodescript'))
        cls.build = read(os.path.join(ROOT, 'tools', 'examples', 'build-examples.livecodescript'))
        cls.kit = read(os.path.join(ROOT, 'ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript'))
        cls.frame = read(os.path.join(ROOT, 'tools', 'examples', 'frame-runtime.livecodescript'))
        cls.task = cls.handlers['ed_quick_start_dropped_shows']
        cls.dropped = cls.handlers['edGuideDropped']
        with open(os.path.join(ROOT, 'ide', 'Resources', 'Examples', 'Remastered', 'Quick Start Guide.oxtstack'), 'rb') as f:
            cls.stack = f.read()

    def guide_part(self, name):
        m = re.search(r'^private (?:command|function) %s\b[^\n]*\n(.*?)^end %s\s*$' % (name, name), self.guide, re.M | re.S)
        self.assertIsNotNone(m, 'the builder has no %s' % name)
        return m.group(1)

    def test_it_runs_after_the_lesson(self):
        listed = tasks(self.text)
        self.assertEqual(listed.index('quick-start-dropped-shows'), listed.index('quick-start-first-lesson') + 1)

    def test_the_lessons_say_that_their_stage_follows_the_look(self):
        build = re.search(r'^command exBuild\b.*?^end exBuild', self.guide, re.M | re.S).group(0)
        said = build.index('set the cStageFollowsLook of card (item tIndex of kLessons) to true')
        self.assertLess(build.index('exAddCards'), said)
        self.assertLess(said, build.index('buildFront'))
        self.assertIn('repeat with tIndex = 1 to the number of items of kLessons', build[build.index('exAddCards'):said])
        # (and no other example's builder says it: their programs were
        # written for a light stage)
        folder = os.path.join(ROOT, 'tools', 'examples')
        for name in sorted(os.listdir(folder)):
            if name.endswith('.livecodescript') and name not in ('quick-start.livecodescript', 'build-examples.livecodescript'):
                self.assertNotIn('cStageFollowsLook', read(os.path.join(folder, name)), name)

    def test_the_build_pairs_the_stage_of_such_a_card(self):
        self.assertIn('if buildIsPage(tObj, the cLayout of tL, the cStageFollowsLook of tL) then', self.build)
        m = re.search(r'^private function buildIsPage pObj, pLayout, pStageToo\n(.*?)^end buildIsPage', self.build, re.M | re.S)
        self.assertIsNotNone(m)
        body = m.group(1)
        # a card with no stage is the page whatever it says; one with a
        # stage is, all of it, when it says so; else only the window's own
        # groups are
        first = body.index('if word 1 of pLayout is not "program" and word 1 of pLayout is not "wide" then')
        too = body.index('if pStageToo is true then')
        own = body.index('return word 1 of tObj is "group" and the short name of tObj is among the items of "Frame,Scripts,Focus"')
        self.assertLess(first, too)
        self.assertLess(too, own)
        self.assertRegex(body[too:own], r'^if pStageToo is true then\n\s*return true\n\s*end if\n')

    def test_the_window_puts_the_look_on_every_control_of_a_card(self):
        # (frameLook asks nothing about the stage: an object that has the
        # two sets gets the one wanted)
        look = re.search(r'^command frameLook\n(.*?)^end frameLook', self.frame, re.M | re.S).group(1)
        self.assertIn('repeat with tCtl = 1 to the number of controls of card tCard of this stack', look)
        self.assertNotIn('cLayout', look)
        self.assertIn('set the uLook of this stack to tWant', look)

    def test_the_try_it_box_is_coloured_for_both_looks(self):
        canvas = self.guide_part('canvasSvg')
        self.assertIn('lkHex(lkDarkLiteral("248,250,252", "fill"))', canvas)
        self.assertNotIn("fill='#f8fafc'", canvas)
        # (the light look's own colours are the ones it had: the light
        # build must come out the same)
        self.assertIn('put "#d5dde7" into tDot', canvas)
        self.assertRegex(canvas, r'if lkDark\(\) then\n\s*put lkHex\(lkColor\("line"\)\) into tDot\n\s*end if')
        literal = re.search(r'^function lkDarkLiteral pColor, pUse\n(.*?)^end lkDarkLiteral', self.kit, re.M | re.S).group(1)
        fill = literal[literal.index('case "fill"'):literal.index('case "ink"')]
        self.assertRegex(fill, r'case "248,250,252"\n\s*case "241,245,249"\n\s*return lkColor\("bg"\)')
        self.assertRegex(fill, r'case "255,255,255"\n\s*return lkColor\("panel"\)')
        self.assertIn('if sDarkMap is not true then\n      return pColor', literal)

    def test_the_notes_code_is_coloured_for_both_looks(self):
        notes = self.guide_part('notesHtml')
        self.assertIn('"<p bgcolor=" & quote & lkHex(lkDarkLiteral("241,245,249", "fill")) & quote', notes)
        self.assertNotIn('#f1f5f9', self.guide)
        code = self.guide_part('notesCodeHtml')
        self.assertIn('codeColor("180,83,9", "252,211,77")', code)
        self.assertIn('codeColor("124,58,237", "196,181,253")', code)
        color = self.guide_part('codeColor')
        self.assertRegex(color, r'if lkDark\(\) then\n\s*return pDark\n\s*end if\n\s*return pLight')
        # (the dark ones are the scripts panel's, which is dark in both)
        self.assertIn('"#fcd34d"', self.frame)
        self.assertIn('"#c4b5fd"', self.frame)
        self.assertEqual('#%02x%02x%02x' % (252, 211, 77), '#fcd34d')
        self.assertEqual('#%02x%02x%02x' % (196, 181, 253), '#c4b5fd')

    def test_what_the_lessons_have_on_the_box_is_coloured_for_both_looks(self):
        # lesson 3's list had the kit's ink on a white written as a number:
        # white words on white, once its card follows the look
        self.assertIn('sTexts["Display"], lkDarkLiteral("255,255,255", "fill"), lkColor("ink"), 12) into tObj', self.guide)
        # lesson 2's field had no colour for its words, on green: the
        # system's, white in the dark look. Black, as its group's script
        # leaves them for Red and Green
        self.assertIn('sTexts["Field Test"], "Green", "black", 14) into tObj', self.guide)
        self.assertIn('else set the textColor of fld "Field Test" to "black"', self.guide)

    def test_the_narrator_words_have_the_looks_colour(self):
        ink = re.search(r'^function narratorInk pReading[^\n]*\n(.*?)^end narratorInk', self.guide, re.M | re.S)
        self.assertIsNotNone(ink)
        self.assertRegex(ink.group(1), r'if the uLook of this stack is "dark" then\n\s*if pReading is true then return "255,255,255"\n\s*return "226,232,240"\n\s*end if\n'
                                       r'\s*if pReading is true then return "15,23,42"\n\s*return "71,85,105"')
        self.assertIn('set the textColor of fld "Said" to narratorInk(false)', self.guide)
        self.assertIn('set the textColor of fld "Said" to narratorInk(true)', self.guide)
        self.assertNotRegex(self.guide, r'set the textColor of fld "Said" to "')
        # (the stack's preOpenCard, which sets them, comes after the
        # group's, which puts the look on and says which in uLook)
        opened = re.search(r'^on preOpenCard\n(.*?)^end preOpenCard', self.frame, re.M | re.S).group(1)
        self.assertLess(opened.index('frameLook'), opened.index('pass preOpenCard'))

    def test_the_stack_installed_is_built_from_it(self):
        self.assertIn(b'cStageFollowsLook', self.stack, 'the stack was not built again after its builder changed')
        self.assertIn(b'narratorInk(false)', self.stack)
        # (the notes' code band in the dark look, in the text kept for it)
        self.assertIn(b'bgcolor="#101624"', self.stack)
        self.assertEqual('#%02x%02x%02x' % (16, 22, 36), '#101624')
        self.assertRegex(self.kit, r'if sDark is true then\n\s*switch pName\n\s*case "bg"\n\s*return "16,22,36"')

    def test_three_kinds_of_control_are_dragged_as_the_lesson_drags_one(self):
        self.assertIn('repeat for each item tType in "Button,LabelField,Checkbox"', self.dropped)
        self.assertIn('put edTile("com.livecode.interface.classic." & tType) into tTile', self.dropped)
        drag = self.dropped.index('edSystemDrag edScreenLoc(tTile, "revTools"), (item 1 of tSpot + the left of stack kGuideStack)')
        self.assertLess(self.dropped.index('if sInput is true then'), drag)
        self.assertLess(drag, self.dropped.index('send "mouseDoubleUp 1" to tTile'))
        # on the box, and clear of what the lesson has on it
        self.assertIn('put the rect of image "Canvas" of tCard into tCanvas', self.dropped)
        self.assertIn('(the bottom of field "Field Test" of tCard + 20) into tSpot', self.dropped)
        self.assertIn('if not (the loc of tNew is within tCanvas) then throw', self.dropped)

    def test_each_must_be_seen(self):
        seen = self.dropped.index('put edSeenPixels(tNew) into tSeen')
        # (as it is when the reader clicks elsewhere: not its handles)
        self.assertLess(self.dropped.index('select empty'), seen)
        self.assertRegex(self.dropped[seen:], r'if tSeen < 30 then\n\s*throw "in the" && tLook && "look the" && tType && "dropped on the Try It box cannot be seen:"')
        self.assertLess(self.dropped.index('if tSeen < 30 then'), self.dropped.index('end repeat'))

    def test_seen_is_what_the_control_changes_of_the_picture(self):
        seen = self.function('edSeenPixels')
        shown = seen.index('set the visible of pObj to true')
        hidden = seen.index('set the visible of pObj to false')
        self.assertLess(shown, seen.index('put edCardPixels(tCard, tRect) into tWith\n'))
        self.assertLess(hidden, seen.index('put edCardPixels(tCard, tRect) into tWithout'))
        self.assertLess(seen.index('put edCardPixels(tCard, tRect) into tWithout'), seen.index('set the visible of pObj to tWas'))
        # brightness, of 255 in thousandths: 80 of it or more is a change
        self.assertIn('299 * byteToNum(byte tIndex + 1 of tWith) + 587 * byteToNum(byte tIndex + 2 of tWith) + 114 * byteToNum(byte tIndex + 3 of tWith)', seen)
        self.assertIn('if abs(tA - tB) >= 80000 then add 1 to tCount', seen)
        self.assertEqual(299 + 587 + 114, 1000)
        self.assertIn('repeat with tIndex = 1 to the number of bytes of tWith step 4', seen)
        # two pictures that do not match are no measure
        self.assertRegex(seen, r'the number of bytes of tWith is not the number of bytes of tWithout then\n\s*throw')

    def test_the_picture_is_the_cards_and_leaves_nothing_behind(self):
        pixels = self.function('edCardPixels')
        self.assertIn('import snapshot from rect pRect of pCard', pixels)
        made = pixels.index('create invisible stack "edPixels"')
        self.assertLess(made, pixels.index('set the defaultStack to "edPixels"'))
        back = pixels.index('set the defaultStack to tDefault')
        self.assertLess(pixels.index('end try'), back)
        self.assertLess(back, pixels.index('delete stack "edPixels"\n   if tError'))

    def test_the_guides_look_is_the_ides(self):
        self.assertIn('if revIDEAppearanceIsDark() is true then put "dark" into tWant', self.dropped)
        self.assertIn('put the uLook of stack kGuideStack into tLook', self.dropped)
        self.assertRegex(self.dropped, r'if tLook is not tWant then throw "the IDE has its"')

    def test_the_guide_is_put_away_unsaved(self):
        self.assertLess(self.task.index('if edInMemory(kGuideStack) then throw'), self.task.index('edGuideDropped tFile'))
        self.assertLess(self.dropped.index('put true into sKeep["guide"]'), self.dropped.index('go stack pFile'))
        away = self.task.index('edGuideAway')
        self.assertLess(self.task.index('end try\n   end try'), away)
        self.assertLess(away, self.task.index('if tMiss is not empty then throw tMiss'))
        self.assertIn('if edInMemory(kGuideStack) then throw "the Quick Start Guide is still in memory after the task"', self.task)

    def test_the_box_is_kept_as_the_engine_draws_it(self):
        self.assertIn('edShotStack kGuideStack, "35d-quick-start-dropped"', self.dropped)
        self.assertIn('export snapshot from rect tCanvas of tCard to file tFile as PNG', self.dropped)
        self.assertIn('edRecord "SHOT everyday-35e-quick-start-try-it-drawn.png" && tCanvas', self.dropped)


if __name__ == '__main__':
    unittest.main()
