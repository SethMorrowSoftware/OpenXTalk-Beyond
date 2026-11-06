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

"""The heavy build workflows skip draft pull requests and run when one is
marked ready.

Each workflow of HEAVY starts on pull requests of the types opened,
synchronize, reopened and ready_for_review (the last is what runs the build
once a draft is marked ready; GitHub's default list leaves it out), and
every one of its jobs carries `github.event.pull_request.draft != true` in
its `if:`. Every job, not only the first: a job whose `if:` says
!cancelled() or always() runs even when the job it needs was skipped, so a
job without the condition could start a packaging or test job on a draft
with nothing to package. The expression is evaluated here the way Actions
does for the events that matter, so a typo such as `draft == false` (which
is false for a push, whose event has no pull request) fails too.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

import yaml

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
WORKFLOWS = os.path.join(REPO, '.github', 'workflows')
HEAVY = ('build-windows.yml', 'build-linux.yml', 'build-macos.yml', 'web-ide.yml')
CONDITION = 'github.event.pull_request.draft != true'
TYPES = {'opened', 'synchronize', 'reopened', 'ready_for_review'}


def load(name):
    with open(os.path.join(WORKFLOWS, name), encoding='utf-8') as f:
        data = yaml.safe_load(f)
    # PyYAML reads the key `on` as True
    return data, data.get('on', data.get(True))


def draft_term(event):
    """CONDITION as Actions evaluates it: a missing property is null, and
    null != true."""
    pr = event.get('pull_request')
    draft = pr.get('draft') if isinstance(pr, dict) else None
    return draft is not True


class DraftBuilds(unittest.TestCase):

    def test_pull_request_types(self):
        for name in HEAVY:
            with self.subTest(workflow=name):
                _, on = load(name)
                self.assertEqual(set(on['pull_request'].get('types', [])), TYPES)
                # push and workflow_call are not filtered by draft state
                self.assertNotIn('types', on.get('push') or {})

    def test_every_job_skips_drafts(self):
        for name in HEAVY:
            data, _ = load(name)
            for job, spec in data['jobs'].items():
                with self.subTest(workflow=name, job=job):
                    cond = str(spec.get('if', ''))
                    self.assertIn(CONDITION, cond)
                    # ANDed with the rest, never ORed: `x || draft != true`
                    # would let x start the job on a draft
                    inner = re.sub(r'^\$\{\{\s*|\s*\}\}$', '', cond.strip())
                    self.assertTrue(inner == CONDITION or inner.endswith('&& ' + CONDITION),
                                    'the draft condition must be the last ANDed term: ' + cond)
                    self.assertNotIn('||' + ' ' + CONDITION, inner)

    def test_condition_by_event(self):
        # a draft is skipped; a ready pull request, a push, a dispatch and
        # release.yml's call (the caller's tag push) are not
        self.assertFalse(draft_term({'pull_request': {'draft': True}}))
        self.assertTrue(draft_term({'pull_request': {'draft': False}}))
        self.assertTrue(draft_term({'ref': 'refs/heads/main'}))
        self.assertTrue(draft_term({'inputs': {}}))
        self.assertTrue(draft_term({'ref': 'refs/tags/v0.2.7'}))

    def test_release_calls_these_workflows(self):
        # the reason push and workflow_call must stay unaffected: release.yml
        # builds through three of them, and a skipped job would leave a
        # release without that platform
        with open(os.path.join(WORKFLOWS, 'release.yml'), encoding='utf-8') as f:
            release = yaml.safe_load(f)
        called = {os.path.basename(j['uses']) for j in release['jobs'].values() if 'uses' in j}
        self.assertTrue(called & set(HEAVY))
        for name in called & set(HEAVY):
            _, on = load(name)
            self.assertIn('workflow_call', on)


if __name__ == '__main__':
    unittest.main()
