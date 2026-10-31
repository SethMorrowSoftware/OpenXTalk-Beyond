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
error (exit 2).

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


if __name__ == '__main__':
    unittest.main()
