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
marked ready, and what decides it is the pull request as it is now.

Each workflow of GATED starts on pull requests of the types opened,
synchronize, reopened and ready_for_review (the last is what runs the build
once a draft is marked ready; GitHub's default list leaves it out). Its
first job, `gate`, asks GitHub whether the pull request is a draft now, and
every other job needs the gate and carries
`needs.gate.outputs.build != 'false'` in its `if:`. Every job, not only the
first: a job whose `if:` says !cancelled() or always() runs even when the
job it needs was skipped, so a job without the condition could start a
packaging or test job on a draft with nothing to package.

Until 2026-11-12 the condition read the event's own copy,
`github.event.pull_request.draft`. A push to a draft that is marked ready a
moment later sends a synchronize event that still says draft, and GitHub
can start that event's run after the ready_for_review run (one second after
it on #478): the late run cancelled the ready one and skipped every job,
so nothing was built, nothing was red, and the pull request waited for
required checks that no run was going to report. So nothing here may read
that copy any more, and the gate's step is run below, with a `gh` that
answers as GitHub would, for the events that matter: the late run of a
pull request that is ready by now must build.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import subprocess
import tempfile
import unittest

import yaml

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
WORKFLOWS = os.path.join(REPO, '.github', 'workflows')
HEAVY = ('build-windows.yml', 'build-linux.yml', 'build-macos.yml', 'web-ide.yml')
# web-host.yml builds nothing that ships and nothing waits on it, but it
# skips drafts the same way, so it asks the same way
GATED = HEAVY + ('web-host.yml',)
CONDITION = "needs.gate.outputs.build != 'false'"
STALE = 'github.event.pull_request.draft'
TYPES = {'opened', 'synchronize', 'reopened', 'ready_for_review'}

# `gh` as the gate calls it. Each call takes the next line of $STATE/answers
# (the last line again once they run out): `fail` is a call GitHub did not
# answer, anything else is printed as the answer.
FAKE_GH = r"""#!/bin/bash
echo "$*" >> "$STATE/calls"
n=$(wc -l < "$STATE/calls")
answer=$(sed -n "${n}p" "$STATE/answers")
if [ -z "$answer" ]; then answer=$(tail -n 1 "$STATE/answers"); fi
if [ "$answer" = fail ]; then
  echo "gh: HTTP 502" >&2
  exit 1
fi
echo "$answer"
"""
FAKE_SLEEP = '#!/bin/bash\necho "$1" >> "$STATE/sleeps"\n'
# `timeout` as the gate calls it: it notes the limit and runs the command
# (a Mac has no timeout of its own, and the limit is not waited out here)
FAKE_TIMEOUT = '#!/bin/bash\necho "$1" >> "$STATE/limits"\nshift\nexec "$@"\n'


def load(name):
    with open(os.path.join(WORKFLOWS, name), encoding='utf-8') as f:
        data = yaml.safe_load(f)
    # PyYAML reads the key `on` as True
    return data, data.get('on', data.get(True))


def needs(spec):
    value = spec.get('needs', [])
    return [value] if isinstance(value, str) else list(value)


def top_level_or(expression):
    """Whether `||` appears outside every pair of parentheses."""
    depth = 0
    for i, c in enumerate(expression):
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        elif depth == 0 and expression.startswith('||', i):
            return True
    return False


def gate_term(output):
    """CONDITION as Actions evaluates it. The output of a gate that failed
    before it wrote one is the empty string, which is not 'false'."""
    return output != 'false'


class DraftBuilds(unittest.TestCase):

    def test_pull_request_types(self):
        for name in GATED:
            with self.subTest(workflow=name):
                _, on = load(name)
                self.assertEqual(set(on['pull_request'].get('types', [])), TYPES)
                # push and workflow_call are not filtered by draft state
                self.assertNotIn('types', on.get('push') or {})

    def test_every_job_waits_for_the_gate(self):
        for name in GATED:
            data, _ = load(name)
            self.assertEqual(list(data['jobs'])[0], 'gate', name)
            for job, spec in data['jobs'].items():
                if job == 'gate':
                    continue
                with self.subTest(workflow=name, job=job):
                    # without the gate among its needs, the job's
                    # needs.gate is empty and the condition always true
                    self.assertIn('gate', needs(spec))
                    cond = str(spec.get('if', ''))
                    inner = re.sub(r'^\$\{\{\s*|\s*\}\}$', '', cond.strip())
                    self.assertTrue(inner == CONDITION or inner.endswith(' && ' + CONDITION),
                                    'the gate must be the last ANDed term: ' + cond)
                    # ANDed with the rest, never ORed: `x || gate` would let
                    # x start the job on a draft
                    rest = inner[:-len(CONDITION)]
                    self.assertFalse(top_level_or(rest), cond)
                    self.assertEqual(rest.count('('), rest.count(')'), cond)

    def test_nothing_reads_the_events_copy(self):
        # not a job's `if:`, not a step's, not an expression in a script:
        # the copy is as old as the event (comments may still name it)
        for name in GATED:
            with self.subTest(workflow=name):
                with open(os.path.join(WORKFLOWS, name), encoding='utf-8') as f:
                    code = [line for line in f if not line.lstrip().startswith('#')]
                self.assertEqual([line for line in code if STALE in line], [])

    def test_top_level_or(self):
        # the helper itself: a blind helper would pass any condition
        self.assertTrue(top_level_or('x || '))
        self.assertTrue(top_level_or('(a && b) || c && '))
        self.assertFalse(top_level_or('(a || b) && '))
        self.assertFalse(top_level_or('(!cancelled() && (a || b || c)) && '))

    def test_the_gate_is_one_job_in_every_workflow(self):
        first = load(GATED[0])[0]['jobs']['gate']
        for name in GATED:
            with self.subTest(workflow=name):
                gate = load(name)[0]['jobs']['gate']
                self.assertEqual(gate, first)
        # it always runs: no condition of its own, nothing to wait for
        self.assertNotIn('if', first)
        self.assertNotIn('needs', first)
        # release.yml calls four of these workflows, and a called workflow
        # may not ask for more than its caller grants: the gate reads the
        # pull request with what the workflow already has
        self.assertNotIn('permissions', first)
        # a gate that failed must not fail the run or stop the builds
        self.assertIs(first['continue-on-error'], True)
        self.assertEqual(first['outputs'], {'build': '${{ steps.ask.outputs.build }}'})
        self.assertEqual(len(first['steps']), 1)
        step = first['steps'][0]
        self.assertEqual((step['id'], step['shell']), ('ask', 'bash'))
        self.assertNotIn('uses', step)
        self.assertEqual(step['env'], {
            'GH_TOKEN': '${{ github.token }}',
            'EVENT_NAME': '${{ github.event_name }}',
            'PR_NUMBER': '${{ github.event.pull_request.number }}',
            'REPO': '${{ github.repository }}',
        })
        # the script takes everything from that environment: an expression
        # in it would be text GitHub pastes into the script
        self.assertNotIn('${{', step['run'])

    def test_condition_by_gate_output(self):
        # only the answer "draft" stops a job
        self.assertFalse(gate_term('false'))
        self.assertTrue(gate_term('true'))
        self.assertTrue(gate_term(''))

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


# The step runs on an Ubuntu runner; it is run here only where bash is
POSIX = unittest.skipUnless(os.name == 'posix' and shutil.which('bash'), 'the step runs in bash on Linux')


@POSIX
class GateStep(unittest.TestCase):
    """The gate's step, run as Actions runs it, with `gh` and `sleep` of
    this test first on the PATH."""

    def setUp(self):
        self.state = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.state)
        bindir = os.path.join(self.state, 'bin')
        os.mkdir(bindir)
        for tool, text in (('gh', FAKE_GH), ('sleep', FAKE_SLEEP), ('timeout', FAKE_TIMEOUT)):
            path = os.path.join(bindir, tool)
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(text)
            os.chmod(path, 0o755)
        self.script = os.path.join(self.state, 'step.sh')
        with open(self.script, 'w', encoding='utf-8', newline='\n') as f:
            f.write(load('build-windows.yml')[0]['jobs']['gate']['steps'][0]['run'])
        self.env = {
            'PATH': bindir + os.pathsep + os.environ['PATH'],
            'STATE': self.state,
            'GITHUB_OUTPUT': os.path.join(self.state, 'output'),
            'GH_TOKEN': 'token',
            'REPO': 'owner/repo',
        }

    def lines(self, name):
        path = os.path.join(self.state, name)
        if not os.path.exists(path):
            return []
        with open(path, encoding='utf-8') as f:
            return f.read().splitlines()

    def ask(self, event, answers=(), number='478'):
        """Runs the step; returns its output `build` and what it printed."""
        with open(os.path.join(self.state, 'answers'), 'w', encoding='utf-8') as f:
            f.write(''.join(a + '\n' for a in answers))
        # the shell line of a step that says `shell: bash`
        p = subprocess.run(['bash', '--noprofile', '--norc', '-eo', 'pipefail', self.script],
                           env=dict(self.env, EVENT_NAME=event, PR_NUMBER=number),
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stdout)
        output = self.lines('output')
        self.assertEqual(len(output), 1, output)
        self.assertRegex(output[0], r'^build=(true|false)$')
        return output[0][len('build='):], p.stdout

    def test_no_pull_request_builds_without_asking(self):
        # a push to main, a tag's push (which is also what release.yml's
        # call looks like to the called workflow) and a dispatch
        for event in ('push', 'workflow_dispatch', 'workflow_call'):
            with self.subTest(event=event):
                build, said = self.ask(event, number='')
                self.assertEqual(build, 'true')
                self.assertTrue(gate_term(build))
                self.assertEqual(self.lines('calls'), [])
                self.assertEqual(self.lines('limits'), [])
                self.assertIn('No pull request (%s)' % event, said)
                os.remove(self.env['GITHUB_OUTPUT'])

    def test_a_draft_builds_nothing(self):
        build, said = self.ask('pull_request', ['true'])
        self.assertEqual(build, 'false')
        self.assertFalse(gate_term(build))
        # one question, of this pull request, for its draft state alone
        self.assertEqual(self.lines('calls'), ['api repos/owner/repo/pulls/478 --jq .draft'])
        # and a call that hangs is given up after half a minute
        self.assertEqual(self.lines('limits'), ['30'])
        # said as a notice, which the run's page shows: the run itself ends
        # as passed, with nothing built
        self.assertIn('::notice::Pull request #478 is a draft: this run builds nothing', said)
        self.assertEqual(self.lines('sleeps'), [])

    def test_a_ready_pull_request_builds(self):
        # This is also the late run of 2026-11-11: its event was a push made
        # while the pull request was a draft, and by the time the run
        # starts the pull request is ready. The step is not given the
        # event's draft state at all, so GitHub's answer decides.
        build, said = self.ask('pull_request', ['false'])
        self.assertEqual(build, 'true')
        self.assertTrue(gate_term(build))
        self.assertEqual(len(self.lines('calls')), 1)
        self.assertIn('#478 is ready for review', said)
        self.assertNotIn('::warning::', said)

    def test_no_answer_builds_and_says_so(self):
        build, said = self.ask('pull_request', ['fail'])
        self.assertEqual(build, 'true')
        # asked three times, with a wait between the calls and none after
        self.assertEqual(len(self.lines('calls')), 3)
        self.assertEqual(self.lines('limits'), ['30', '30', '30'])
        self.assertEqual(self.lines('sleeps'), ['5', '10'])
        self.assertIn('::warning::GitHub did not say whether pull request #478 is a draft', said)
        # and the log keeps gh's own words for why
        self.assertEqual(said.count('gh: HTTP 502'), 3)

    def test_an_answer_that_is_neither_builds_and_says_so(self):
        # an error page, or `null`: nothing but the word true is a draft
        for answer in ('null', '{"message":"Not Found"}', 'True'):
            with self.subTest(answer=answer):
                build, said = self.ask('pull_request', [answer])
                self.assertEqual(build, 'true')
                self.assertIn('::warning::', said)
                os.remove(self.env['GITHUB_OUTPUT'])

    def test_a_later_answer_counts(self):
        # GitHub fails once, then answers: the answer is used, either way
        build, said = self.ask('pull_request', ['fail', 'true'])
        self.assertEqual(build, 'false')
        self.assertEqual(len(self.lines('calls')), 2)
        self.assertEqual(self.lines('sleeps'), ['5'])
        self.assertNotIn('::warning::', said)
        os.remove(self.env['GITHUB_OUTPUT'])
        for name in ('calls', 'sleeps'):
            os.remove(os.path.join(self.state, name))
        build, said = self.ask('pull_request', ['fail', 'fail', 'false'])
        self.assertEqual(build, 'true')
        self.assertEqual(len(self.lines('calls')), 3)
        self.assertEqual(self.lines('sleeps'), ['5', '10'])
        self.assertNotIn('::warning::', said)


if __name__ == '__main__':
    unittest.main()
