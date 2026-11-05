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

"""The action .github/actions/install-playwright, which fetches the
browsers' system packages with a time limit and from the cache before
Playwright installs them (the action says why).

It checks that every job whose browsers include WebKit installs Playwright
through the action, at the Playwright version its workflow pins elsewhere;
that the action reads the package list from Playwright's dry run as the
pinned version prints it, run as root and through sudo, and reads none
(so the install runs as before) from anything else; that a fetch that does
not finish never stops the job before Playwright's own install; and that
web-ide.yml starts on a change to the action.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import subprocess
import unittest

import yaml

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
ACTION_DIR = os.path.join('.github', 'actions', 'install-playwright')
ACTION = os.path.join(REPO, ACTION_DIR, 'action.yml')
WORKFLOWS = os.path.join(REPO, '.github', 'workflows')

# What Playwright 1.56.0's `install-deps --dry-run webkit` printed, as root
# and as a user with sudo (the runner's), cut to a few packages
DRY_RUN_ROOT = ('sh -c "apt-get update&& apt-get install -y --no-install-recommends '
                'gstreamer1.0-libav libicu74 libwoff1 fonts-freefont-ttf"\n')
DRY_RUN_SUDO = ('sudo -- sh -c "apt-get update&& apt-get install -y --no-install-recommends '
                'gstreamer1.0-libav libicu74 libwoff1 fonts-freefont-ttf"\n')
PACKAGES = ['gstreamer1.0-libav', 'libicu74', 'libwoff1', 'fonts-freefont-ttf']


def load(path):
    with open(path, encoding='utf-8') as f:
        return yaml.safe_load(f)


def install_step(action):
    steps = [s for s in action['runs']['steps'] if s.get('id') == 'install']
    assert len(steps) == 1, 'one step with the id install'
    return steps[0]


def browsers(job):
    matrix = (job.get('strategy') or {}).get('matrix') or {}
    found = list(matrix.get('browser') or [])
    for extra in matrix.get('include') or []:
        if 'browser' in extra:
            found.append(extra['browser'])
    return found


def playwright_steps(job):
    """The job's steps that install Playwright, by their name."""
    return [s for s in job.get('steps') or []
            if str(s.get('name', '')).startswith('Install Playwright')]


class TheAction(unittest.TestCase):

    def setUp(self):
        self.action = load(ACTION)
        self.script = install_step(self.action)['run']

    def test_composite_with_its_inputs(self):
        self.assertEqual(self.action['runs']['using'], 'composite')
        self.assertEqual(sorted(self.action['inputs']), ['browsers', 'venv', 'version'])
        for name, spec in self.action['inputs'].items():
            self.assertTrue(spec.get('required'), name)

    def test_cache_restored_and_saved_under_one_key(self):
        steps = self.action['runs']['steps']
        restore = [s for s in steps if str(s.get('uses', '')).startswith('actions/cache/restore@')]
        save = [s for s in steps if str(s.get('uses', '')).startswith('actions/cache/save@')]
        self.assertEqual(len(restore), 1)
        self.assertEqual(len(save), 1)
        self.assertEqual(restore[0]['with']['key'], save[0]['with']['key'])
        self.assertEqual(restore[0]['with']['path'], save[0]['with']['path'])
        # saved only when the install says so, and a failed save is no failure
        self.assertEqual(save[0]['if'], "steps.install.outputs.save == 'true'")
        self.assertTrue(save[0].get('continue-on-error'))
        # the key names the runner image, the version and the browsers
        key_step = [s for s in steps if s.get('id') == 'key'][0]['run']
        for part in ('ImageOS', 'ImageVersion', 'VERSION', 'uname -m', 'names'):
            self.assertIn(part, key_step)

    def sed_expression(self):
        m = re.search(r"\| sed -n '([^']*)'", self.script)
        self.assertIsNotNone(m, 'the dry run is read with sed -n')
        return m.group(1)

    @unittest.skipUnless(shutil.which('sed') and shutil.which('bash'), 'needs sed and bash')
    def test_reads_the_dry_run(self):
        expression = self.sed_expression()
        for text in (DRY_RUN_ROOT, DRY_RUN_SUDO):
            out = subprocess.run(['sed', '-n', expression], input=text, text=True,
                                 capture_output=True, check=True).stdout
            self.assertEqual(out.split(), PACKAGES, text)
        # A dry run printed another way names nothing, and the install
        # then runs as before (no fetch)
        for text in ('Missing system dependencies (82):\n  libicu74\n', '', 'apt-get install x\n'):
            out = subprocess.run(['sed', '-n', expression], input=text, text=True,
                                 capture_output=True, check=True).stdout
            self.assertEqual(out.strip(), '', text)

    def test_fetch_is_bounded_and_never_fatal(self):
        s = self.script
        # every apt-get of the fetch has a time limit, and is tried 3 times
        fetch = s[s.index('for i in 1 2 3; do'):s.index('done', s.index('for i in 1 2 3; do'))]
        self.assertEqual(fetch.count('timeout 300 "${apt[@]}"'), 2)
        self.assertIn('--download-only', fetch)
        # the loop is an if, so a try that fails does not end the step
        self.assertIn('if timeout 300', fetch)
        # Playwright's own install comes after the fetch, with --with-deps,
        # whatever the fetch did
        self.assertGreater(s.index('-m playwright install --with-deps "${browsers[@]}"'),
                           s.index('for i in 1 2 3; do'))
        # nothing stops the install itself
        self.assertNotIn('timeout 300 "$VENV/bin/python" -m playwright install', s)

    def test_saves_only_a_finished_fetch_on_a_miss(self):
        s = self.script
        self.assertIn('if [ "$fetched" = true ] && [ "$HIT" != true ]; then', s)
        self.assertIn('echo "save=true" >> "$GITHUB_OUTPUT"', s)


class TheWorkflows(unittest.TestCase):

    def test_every_webkit_job_uses_the_action(self):
        found = 0
        for name in sorted(os.listdir(WORKFLOWS)):
            if not name.endswith('.yml'):
                continue
            workflow = load(os.path.join(WORKFLOWS, name))
            for job_id, job in (workflow.get('jobs') or {}).items():
                if 'webkit' not in browsers(job):
                    continue
                steps = playwright_steps(job)
                if not steps:
                    continue
                found += 1
                for step in steps:
                    where = '%s: %s' % (name, job_id)
                    self.assertEqual(step.get('uses'), './' + ACTION_DIR.replace(os.sep, '/'), where)
                    self.assertEqual(step['with']['browsers'], '${{ matrix.browser }}', where)
                    self.assertEqual(step['with']['venv'], '${{ runner.temp }}/playwright', where)
                    self.assertEqual(str(step['with']['version']), '1.56.0', where)
        # web.yml's check, the web IDE's soak and its xTalk Suite
        self.assertEqual(found, 3)

    def test_web_ide_starts_on_a_change_to_the_action(self):
        workflow = load(os.path.join(WORKFLOWS, 'web-ide.yml'))
        on = workflow.get('on', workflow.get(True))
        for event in ('push', 'pull_request'):
            self.assertIn('.github/actions/install-playwright/**', on[event]['paths'], event)


if __name__ == '__main__':
    unittest.main()
