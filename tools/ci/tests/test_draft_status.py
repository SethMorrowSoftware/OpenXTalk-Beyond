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

"""Draft status (draft-status.yml): a draft pull request's newest commit
carries a PENDING status "Platform builds", so a draft whose platform
builds were skipped never shows all green, and a ready one carries
SUCCESS. The draft state and the commit are asked of GitHub now, never
read from the event (see test_draft_builds.py for why); a status that
cannot be written warns and passes.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import shutil
import subprocess
import tempfile
import unittest

import yaml

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'draft-status.yml')
SHA = '0123456789abcdef0123456789abcdef01234567'

# `gh` as the step calls it: each call takes the next line of
# $STATE/answers (`fail` is a call GitHub did not answer)
FAKE_GH = r"""#!/bin/bash
echo "$*" >> "$STATE/calls"
n=$(wc -l < "$STATE/calls")
answer=$(sed -n "${n}p" "$STATE/answers")
if [ -z "$answer" ]; then answer=$(tail -n 1 "$STATE/answers"); fi
if [ "$answer" = fail ]; then
  echo "gh: HTTP 403" >&2
  exit 1
fi
echo "$answer"
"""
FAKE_SLEEP = '#!/bin/bash\necho "$1" >> "$STATE/sleeps"\n'
FAKE_TIMEOUT = '#!/bin/bash\nshift\nexec "$@"\n'


def load():
    with open(WORKFLOW, encoding='utf-8') as f:
        data = yaml.safe_load(f)
    return data, data.get('on', data.get(True))


class Workflow(unittest.TestCase):

    def test_events(self):
        _, on = load()
        self.assertEqual(list(on), ['pull_request'])
        self.assertEqual(set(on['pull_request']['types']),
                         {'opened', 'synchronize', 'reopened', 'ready_for_review',
                          'converted_to_draft'})

    def test_only_the_job_writes_and_only_statuses(self):
        data, _ = load()
        self.assertEqual(data['permissions'], {'contents': 'read'})
        job = data['jobs']['status']
        self.assertEqual(job['permissions'], {'statuses': 'write', 'pull-requests': 'read'})
        # nothing checked out, nothing from the pull request run
        self.assertEqual(len(job['steps']), 1)
        self.assertNotIn('uses', job['steps'][0])
        self.assertNotIn('${{', job['steps'][0]['run'])

    def test_nothing_reads_the_events_copy(self):
        with open(WORKFLOW, encoding='utf-8') as f:
            code = [line for line in f if not line.lstrip().startswith('#')]
        self.assertEqual([line for line in code if 'pull_request.draft' in line], [])

    def test_no_build_waits_for_it(self):
        # it writes and builds nothing: a change to it starts no build
        for wf in ('build-windows.yml', 'build-linux.yml', 'build-macos.yml'):
            with open(os.path.join(REPO, '.github', 'workflows', wf), encoding='utf-8') as f:
                self.assertIn("- '.github/workflows/draft-status.yml'", f.read(), wf)


@unittest.skipUnless(os.name == 'posix' and shutil.which('bash'), 'the step runs in bash on Linux')
class Step(unittest.TestCase):

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
            f.write(load()[0]['jobs']['status']['steps'][0]['run'])

    def run_step(self, answers):
        with open(os.path.join(self.state, 'answers'), 'w', encoding='utf-8') as f:
            f.write(''.join(a + '\n' for a in answers))
        env = {'PATH': os.path.join(self.state, 'bin') + os.pathsep + os.environ['PATH'],
               'STATE': self.state, 'GH_TOKEN': 't', 'REPO': 'owner/repo',
               'PR_NUMBER': '540', 'RUN_URL': 'https://example.invalid/run'}
        p = subprocess.run(['bash', '--noprofile', '--norc', '-eo', 'pipefail', self.script],
                           env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stdout)
        path = os.path.join(self.state, 'calls')
        calls = []
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                calls = f.read().splitlines()
        return calls, p.stdout

    def test_a_draft_is_pending(self):
        calls, _ = self.run_step(['true ' + SHA, '{}'])
        self.assertEqual(len(calls), 2)
        self.assertIn('repos/owner/repo/pulls/540', calls[0])
        self.assertIn('-X POST repos/owner/repo/statuses/' + SHA, calls[1])
        self.assertIn('state=pending', calls[1])
        self.assertIn('context=Platform builds', calls[1])

    def test_a_ready_pull_request_is_success(self):
        calls, _ = self.run_step(['false ' + SHA, '{}'])
        self.assertIn('state=success', calls[1])
        self.assertIn('statuses/' + SHA, calls[1])

    def test_no_answer_writes_nothing_and_warns(self):
        calls, said = self.run_step(['fail'])
        self.assertEqual(len(calls), 3)
        self.assertFalse([c for c in calls if 'POST' in c])
        self.assertIn('::warning::', said)

    def test_an_odd_answer_writes_nothing(self):
        for answer in ('null null', 'true not-a-sha', '{"message":"Not Found"}'):
            with self.subTest(answer=answer):
                if os.path.exists(os.path.join(self.state, 'calls')):
                    os.remove(os.path.join(self.state, 'calls'))
                calls, said = self.run_step([answer])
                self.assertFalse([c for c in calls if 'POST' in c])
                self.assertIn('::warning::', said)

    def test_a_status_that_cannot_be_written_passes(self):
        # a pull request from a fork: its token cannot write statuses
        calls, said = self.run_step(['true ' + SHA, 'fail'])
        self.assertEqual(len(calls), 2)
        self.assertIn('::warning::Could not write the status', said)


if __name__ == '__main__':
    unittest.main()
