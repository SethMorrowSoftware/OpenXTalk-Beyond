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

"""tools/ci/runtimes_provenance.py, over a made-up repository: the commits
since the runtimes asset's that change the engine's source are listed and
the others are not; the report is a warning (exit 0) unless
--fail-on-stale, which fails a stale record and passes a current one; and
an asset record it cannot read, or a commit not in the history, is an
error (exit 2). And "Tag a release" runs it with --fail-on-stale over a
full history before it tags (seth's decision MOD-D1: every release
rebuilds the asset), while the CI checks only report.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import runtimes_provenance  # noqa: E402

GIT = shutil.which('git')


@unittest.skipIf(GIT is None, 'no git')
class Provenance(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.repo, ignore_errors=True)
        self.git('init', '-q')
        self.git('config', 'user.email', 'ci@example.invalid')
        self.git('config', 'user.name', 'CI')
        self.git('config', 'commit.gpgsign', 'false')
        self.built = self.commit('engine/src/a.cpp', 'the runtimes are built from this')
        self.assets = os.path.join(self.repo, 'assets.json')

    def git(self, *args):
        return subprocess.run(['git', '-C', self.repo] + list(args), check=True, capture_output=True,
                              text=True).stdout.strip()

    def commit(self, path, message):
        full = os.path.join(self.repo, *path.split('/'))
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, 'a', encoding='utf-8') as f:
            f.write(message + '\n')
        self.git('add', path)
        self.git('commit', '-q', '-m', message)
        return self.git('rev-parse', 'HEAD')

    def record(self, commit, ident='oxt-runtimes-9.9'):
        with open(self.assets, 'w', encoding='utf-8') as f:
            json.dump({'assets': [{'id': ident, 'source': 'CI builds of commit %s, and Android' % commit}]}, f)

    def run_main(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out), \
                mock.patch.dict(os.environ, {'GITHUB_ACTIONS': '', 'GITHUB_STEP_SUMMARY': ''}):
            code = runtimes_provenance.main(['--repo', self.repo, '--assets', self.assets] + list(argv))
        return code, out.getvalue()

    def test_current_record(self):
        self.commit('docs/notes.md', 'docs only')
        self.record(self.built)
        code, out = self.run_main('--fail-on-stale')
        self.assertEqual(code, 0, out)
        self.assertIn('the runtimes are current', out)

    def test_stale_record_is_reported_not_failed(self):
        self.commit('libfoundation/b.cpp', 'a foundation change')
        self.commit('docs/notes.md', 'docs only')
        self.commit('engine/src/c.cpp', 'an engine change')
        self.record(self.built)
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn('2 commits since then', out)
        self.assertIn('an engine change', out)
        self.assertIn('a foundation change', out)
        self.assertNotIn('docs only', out)

    def test_fail_on_stale(self):
        self.commit('thirdparty/x.c', 'a library change')
        self.record(self.built)
        code, out = self.run_main('--fail-on-stale')
        self.assertEqual(code, 1, out)

    def test_short_commit_and_list_limit(self):
        for n in range(3):
            self.commit('engine/src/n%d.cpp' % n, 'change %d' % n)
        self.record(self.built[:12])
        code, out = self.run_main('--list', '1')
        self.assertEqual(code, 0, out)
        self.assertIn('3 commits since then', out)
        self.assertIn('and 2 more', out)

    def test_unknown_commit(self):
        self.record('0' * 40)
        code, out = self.run_main()
        self.assertEqual(code, 2)
        self.assertIn('not in the history', out)

    def test_no_asset(self):
        self.record(self.built, ident='something-else')
        code, out = self.run_main()
        self.assertEqual(code, 2)
        self.assertIn('0 oxt-runtimes- assets', out)

    def test_real_record_names_one_commit(self):
        ident, commit = runtimes_provenance.runtimes_asset(runtimes_provenance.ASSETS)
        self.assertTrue(ident.startswith('oxt-runtimes-'))
        self.assertRegex(commit, r'^[0-9a-f]{12,40}$')


REPO = os.path.dirname(os.path.dirname(CI))
WORKFLOWS = os.path.join(REPO, '.github', 'workflows')


def workflow(name):
    import yaml
    with open(os.path.join(WORKFLOWS, name), encoding='utf-8') as f:
        return yaml.safe_load(f)


class ReleaseRefusesStaleRuntimes(unittest.TestCase):
    """Every release rebuilds the runtimes asset: the tag is refused while
    the pinned asset is older than the engine's source."""

    def setUp(self):
        self.steps = workflow('tag-release.yml')['jobs']['tag']['steps']

    def step(self, name):
        found = [s for s in self.steps if s.get('name') == name]
        self.assertEqual(len(found), 1, name)
        return found[0]

    def test_check_step_fails_on_stale_runtimes(self):
        run = self.step('Check the version, the tag and the builds')['run']
        lines = [l.strip() for l in run.splitlines()]
        call = [i for i, l in enumerate(lines) if 'tools/ci/runtimes_provenance.py' in l]
        self.assertEqual(len(call), 1, run)
        line = lines[call[0]]
        self.assertIn('--fail-on-stale', line)
        # Its failure stops the step: the call is followed by "|| fail"
        # (a bare call would be ignored after "fail()" is defined, since
        # the step's shell carries on unless told otherwise)
        self.assertTrue(line.endswith('||'), line)
        self.assertTrue(lines[call[0] + 1].startswith('fail '), lines[call[0] + 1])
        self.assertIn('Runtimes asset', lines[call[0] + 1])
        # Before the tag is made, and before any build is started
        self.assertLess(call[0], next(i for i, l in enumerate(lines) if 'gh workflow run' in l))

    def test_checkout_has_the_whole_history(self):
        # A shallow clone cannot reach the asset's commit: exit 2, refused
        # for the wrong reason
        checkout = self.step('Check out main')
        self.assertTrue(checkout['uses'].startswith('actions/checkout@'))
        self.assertEqual(checkout.get('with', {}).get('fetch-depth'), 0)

    def test_check_runs_before_the_tag_is_pushed(self):
        names = [s.get('name') for s in self.steps]
        self.assertLess(names.index('Check the version, the tag and the builds'),
                        names.index('Make and push the tag'))

    def test_ci_checks_only_report(self):
        # The pull request checks warn and never fail on it: an engine
        # change must not turn every pull request red
        steps = [s for job in workflow('ci-checks.yml')['jobs'].values() for s in job.get('steps', [])
                 if 'runtimes_provenance.py' in str(s.get('run', ''))]
        self.assertTrue(steps)
        for s in steps:
            self.assertNotIn('--fail-on-stale', s['run'])


if __name__ == '__main__':
    unittest.main()
