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


class StandaloneBuiltAndRun(unittest.TestCase):
    """standalone-built-and-run builds a stack from the File menu to the
    end, with the builder's dialogs on, and runs the standalone, which
    writes what it finds itself to be and quits. What the task waits for
    is the builder's own: its last word, the two messages it sends a
    stack, its last step and where it puts the standalone. And the stack
    the task makes carries a quit, which must be the standalone's alone."""

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
        self.assertIn('edWatchBuild true\n', full)
        self.assertNotIn('edStopBuildAt', full)

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
        full = self.function('edFullBuild')
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
        full = self.function('edFullBuild')
        self.assertIn('put 0 into sReport["dialogs"]', full)
        self.assertLess(full.index('if sReport["dialogs"] > kBuildDialogs then'), full.index('is not among the lines of tSteps'))

    def test_the_stacks_the_tasks_made_are_taken_away(self):
        for name in ('kMcStack', 'kAppStack'):
            self.assertIn('edRemoveBuiltStack %s' % name, self.handlers['ed_finish'])
        self.assertIn('edRemoveBuiltStack kAppStack', self.handlers['ed_standalone_built_and_run'])

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
        self.assertIn('put pShot into sReport["sayShot"]', self.function('edFullBuild'))
        said = self.handlers['edBuildSaid']
        shot = 'edShotStack tAD, sReport["sayShot"]'
        self.assertIn(shot, said)
        self.assertLess(said.index(shot), said.index('edAnswerWith "OK"'),
                        'the snapshot is after the click that closes the dialog')
        # (the first dialog alone, and a snapshot that fails does not
        # stop the answering: an unanswered dialog holds the build)
        self.assertRegex(said, r'if sReport\["dialogs"\] is 1 and sReport\["sayShot"\] is not empty then\s+try\s+%s\s+catch tError\s+end try' % re.escape(shot))


if __name__ == '__main__':
    unittest.main()
