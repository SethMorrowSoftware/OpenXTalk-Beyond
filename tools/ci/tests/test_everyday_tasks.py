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


if __name__ == '__main__':
    unittest.main()
