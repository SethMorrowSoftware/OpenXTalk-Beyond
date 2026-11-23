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

"""Which jobs may run on the maintainer's own Linux PC, and only when.

Since 2026-11-21 the short draft-check jobs (the "gate" of each build
workflow, android-engine's "What the change needs" and draft-status's
status) can run on a self-hosted runner on Seth's Linux PC
(BUILDING.md, "Continuous integration"). On 21 November 2026 those few-second jobs waited
15 to 66 minutes for one of GitHub's machines, and every build of a pull
request waited behind them.

This repository is public, and a self-hosted runner runs whatever a
workflow sends it, so the routing is the security boundary. It is held
here by evaluating the runs-on expression the way Actions does, for each
kind of run: a pull request from a fork, or any event but a push, a
dispatch or this repository's own pull request, always gets GitHub's
ubuntu-24.04; so does everything while the repository variable
PC_RUNNERS_LINUX is not 'on'. No other job names a self-hosted runner,
and a routed job needs nothing the PC lacks (no container, no service
containers, no docker, no sudo).

  python3 -m unittest discover -s tools/ci/tests
"""

import glob
import json
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
WORKFLOWS = os.path.join(REPO, '.github', 'workflows')

# workflow file -> job id; adding one is a decision, made here and in the doc
ROUTED = {
    'android-engine.yml': 'gate',
    'build-linux.yml': 'gate',
    'build-macos.yml': 'gate',
    'build-windows.yml': 'gate',
    'draft-status.yml': 'status',
    'web-host.yml': 'gate',
    'web-ide.yml': 'gate',
}
PC = ['self-hosted', 'Linux', 'X64', 'seth-pc']


def load(path):
    import yaml
    with open(path, encoding='utf-8') as f:
        return yaml.safe_load(f)


def evaluate(expression, ctx):
    """Evaluate the one shape of runs-on expression used here, as Actions
    would: && and || return an operand (as in JavaScript, and Python's and
    and or), == compares strings, a missing property is null, fromJSON
    parses its argument. Anything else in the expression is a failure."""
    body = expression.strip()
    if not (body.startswith('${{') and body.endswith('}}')):
        return body
    body = body[3:-2].strip()
    tokens = re.findall(r"fromJSON\('((?:[^']|'')*)'\)|'((?:[^']|'')*)'|(&&|\|\||==|!=|\(|\))"
                        r"|([A-Za-z_][\w.-]*)|(\S)", body)
    out = []
    values = []
    for fj, s, op, name, bad in tokens:
        if bad:
            raise ValueError('unexpected %r in %s' % (bad, expression))
        if fj:
            values.append(json.loads(fj.replace("''", "'")))
            out.append('_v[%d]' % (len(values) - 1))
        elif s or (not op and not name):
            values.append(s.replace("''", "'"))
            out.append('_v[%d]' % (len(values) - 1))
        elif op:
            out.append({'&&': ' and ', '||': ' or '}.get(op, ' %s ' % op))
        else:
            value = ctx
            for part in name.split('.'):
                value = value.get(part) if isinstance(value, dict) else None
            values.append(value)
            out.append('_v[%d]' % (len(values) - 1))
    return eval(''.join(out), {'__builtins__': {}}, {'_v': values})


def context(event, switch, head='SethMorrowSoftware/OpenXTalk-Beyond'):
    pr = {'head': {'repo': {'full_name': head}}} if event in ('pull_request', 'pull_request_target') else None
    return {
        'github': {'event_name': event, 'repository': 'SethMorrowSoftware/OpenXTalk-Beyond',
                   'event': {'pull_request': pr} if pr else {}},
        'vars': {'PC_RUNNERS_LINUX': switch} if switch is not None else {},
    }


class Routing(unittest.TestCase):

    def setUp(self):
        self.files = {os.path.basename(p): p for p in glob.glob(os.path.join(WORKFLOWS, '*.yml'))}

    def runs_on(self, name):
        return load(self.files[name])['jobs'][ROUTED[name]]['runs-on']

    def test_the_evaluator_sees_the_difference(self):
        # a blind evaluator could pass everything below
        unguarded = ("${{ (vars.PC_RUNNERS_LINUX == 'on' && "
                     "fromJSON('[\"self-hosted\",\"Linux\",\"X64\",\"seth-pc\"]')) || 'ubuntu-24.04' }}")
        fork = context('pull_request', 'on', head='someone/OpenXTalk-Beyond')
        self.assertEqual(evaluate(unguarded, fork), PC)
        self.assertEqual(evaluate(unguarded, context('pull_request', None)), 'ubuntu-24.04')

    def test_only_these_jobs_name_a_self_hosted_runner(self):
        found = set()
        for name, path in self.files.items():
            with open(path, encoding='utf-8') as f:
                text = f.read()
            if 'self-hosted' not in text and 'seth-pc' not in text:
                continue
            for job_id, job in load(path)['jobs'].items():
                if 'self-hosted' in json.dumps(job) or 'seth-pc' in json.dumps(job):
                    found.add((name, job_id))
        self.assertEqual(found, set(ROUTED.items()))

    def test_the_pc_only_for_this_repositorys_own_runs_and_only_when_on(self):
        for name in ROUTED:
            ro = self.runs_on(name)
            with self.subTest(workflow=name):
                for event in ('push', 'workflow_dispatch', 'pull_request'):
                    self.assertEqual(evaluate(ro, context(event, 'on')), PC, event)
                    for switch in (None, '', 'off', 'true'):
                        self.assertEqual(evaluate(ro, context(event, switch)), 'ubuntu-24.04',
                                         (event, switch))
                for event in ('pull_request', 'pull_request_target'):
                    fork = context(event, 'on', head='someone/OpenXTalk-Beyond')
                    self.assertEqual(evaluate(ro, fork), 'ubuntu-24.04', 'a fork, ' + event)
                for event in ('pull_request_target', 'workflow_run', 'schedule', 'release',
                              'issue_comment', 'workflow_call'):
                    self.assertEqual(evaluate(ro, context(event, 'on')), 'ubuntu-24.04', event)

    def test_a_routed_job_needs_nothing_the_pc_lacks(self):
        for name, job_id in ROUTED.items():
            job = load(self.files[name])['jobs'][job_id]
            with self.subTest(workflow=name):
                self.assertNotIn('container', job)
                self.assertNotIn('services', job)
                self.assertNotIn('strategy', job)
                for step in job['steps']:
                    run = step.get('run', '')
                    self.assertNotRegex(run, r'(^|\s)(sudo|docker|apt-get)\s', step.get('name'))
                    uses = step.get('uses', '')
                    if uses:
                        self.assertTrue(uses.startswith('actions/checkout@'), uses)

    def test_a_short_job(self):
        # a PC slot that holds a long job becomes the new queue
        for name, job_id in ROUTED.items():
            job = load(self.files[name])['jobs'][job_id]
            with self.subTest(workflow=name):
                self.assertLessEqual(job['timeout-minutes'], 15)


if __name__ == '__main__':
    unittest.main()
