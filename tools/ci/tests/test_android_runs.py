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

"""tools/ci/android_runs.py, android-engine.yml's gate: what a change needs
of the workflow, and the earlier run whose engine the script tests take
when it builds none. GitHub's API is a made-up one here.

  python3 -m unittest discover -s tools/ci/tests -p test_android_runs.py

Until 0.2.8-dp.2 the workflow started only for the engine's sources, so a
change to the tests alone (#556's six tests of the pointer) never ran them
on Android, and they were first seen failing on main (#567).
"""

import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import android_runs as ar  # noqa: E402

SHA = 'c' * 40
OLD = ['a%039d' % n for n in range(1, 30)]


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


class Patterns(unittest.TestCase):

    def test_as_github_reads_them(self):
        m = ar.matches
        self.assertTrue(m('engine/src/stacke.cpp', ['**']))
        self.assertTrue(m('a.md', ['**.md']))
        self.assertTrue(m('engine/docs/a.md', ['**.md']))
        self.assertFalse(m('engine/docs/a.md', ['*.md']))
        self.assertTrue(m('README.md', ['*.md']))
        self.assertTrue(m('tools/ci/android-tests-baseline-beyond.txt', ['tools/ci/android-tests-baseline-*.txt']))
        self.assertFalse(m('tools/ci/x/android-tests-baseline-b.txt', ['tools/ci/android-tests-baseline-*.txt']))
        # the last pattern that matches says
        self.assertFalse(m('tests/lcs/a.livecodescript', ['**', '!tests/**']))
        self.assertTrue(m('tests/lcs/a.livecodescript', ['**', '!tests/**', 'tests/lcs/**']))
        self.assertFalse(m('ide/x.livecodescript', []))
        self.assertTrue(m('a/b/c.txt', ['**/c.txt']))
        self.assertTrue(m('c.txt', ['**/c.txt']))
        self.assertTrue(m('a.b', ['a.?']))
        self.assertFalse(m('a/b', ['a?b']))

    def test_the_engines_sources_are_what_they_were(self):
        # what started the workflow until 0.2.8-dp.2 is what builds the
        # engine now
        engine = lambda p: ar.matches(p, ar.ENGINE_PATHS)  # noqa: E731
        for path in ('engine/src/stacke.cpp', 'engine/src/em-event.js', 'libfoundation/src/x.cpp',
                     'extensions/libraries/json/json.lcb', 'thirdparty/libz/x.c', 'config/android-ndk-version',
                     'config.py', 'tools/ci/build-android.sh', 'tools/ci/android_engine.py',
                     'tools/ci/android_java.py', 'tools/ci/android_tests.py', 'tools/ci/android-tests.livecodescript',
                     'tools/ci/android-tests-baseline-beyond.txt', 'tools/javac_wrapper.sh', 'tools/pathify.sh',
                     '.github/workflows/android-engine.yml'):
            self.assertTrue(engine(path), path)
        for path in ('ide/Toolset/home.livecodescript', 'ide-support/revliburl.livecodescript', 'docs/x.lcdoc',
                     'tests/lcs/core/a.livecodescript', 'Installer/x', 'changelog/593.md', 'README.md',
                     'engine/README.md', '.github/workflows/web.yml', 'tools/ci/web_check.py',
                     'tools/web-player/stacks/Ember Bricks.oxtstack', 'tools/ci/android_runs.py'):
            self.assertFalse(engine(path), path)


class Deciding(unittest.TestCase):

    def test_a_change_to_the_tests_alone_runs_them(self):
        self.assertEqual(ar.decide(['tests/lcs/webplayer/ember-bricks.livecodescript'])[:2], (False, True))
        self.assertEqual(ar.decide(['tests/_testlib.livecodescript'])[:2], (False, True))

    def test_what_the_tests_read_runs_them(self):
        # the checkout's files that they read, the IDE folders they test,
        # the Android builder of the checkout, and their own scripts
        for path in ('ide-support/revliburl.livecodescript', 'tools/web-player/stacks/Ember Bricks.oxtstack',
                     'ide/Extensions/org.openxtalk.plugin.xtalkassistant/xtalkassistant-core.livecodescript',
                     'ide/Extensions/org.openxtalk.plugin.mcpbridge/mcp/server.js',
                     'ide-support/revsaveasandroidstandalone.livecodescript',
                     'tools/ci/android_check.py', 'tools/ci/android_runs.py', 'tools/ci/run_engine_tests.py'):
            engine, tests, why = ar.decide([path])
            self.assertEqual((engine, tests), (False, True), path)
            self.assertIn(path, why[0])

    def test_the_engine_runs_everything(self):
        engine, tests, why = ar.decide(['engine/src/stacke.cpp', 'docs/x.lcdoc'])
        self.assertEqual((engine, tests), (True, True))
        self.assertIn('engine/src/stacke.cpp', why[0])
        self.assertNotIn('docs/x.lcdoc', why[0])

    def test_nothing_else_runs_anything(self):
        # (not ide/Toolset/home.livecodescript, which a test reads:
        # tests/lcs/ext/folder-externals)
        for path in ('docs/dictionary/command/go.lcdoc',
                     'ide/Toolset/libraries/revinitialisationlibrary.livecodescript',
                     'ide/Toolset/libraries/revbackscriptlibrary.livecodescript',
                     'tools/web-player/ember-bricks/sounds/hit.wav',
                     'tools/ci/web_ide_soak.py', 'README.md', 'changelog/1.md'):
            self.assertEqual(ar.decide([path])[:2], (False, False), path)

    def test_a_folder_a_test_names_a_file_of_as_it_runs_is_read_whole(self):
        # tests/lcs/replicate/padlocks reads "/Toolset/palettes/" & pFile
        # (replicate.oxtstack, revreplicate.rev), and the copy files take
        # ide/Toolset/palettes whole; the pattern was
        # ide/Toolset/palettes//**, which took nothing
        for path in ('ide/Toolset/palettes/revreplicate.rev', 'ide/Toolset/palettes/replicate.oxtstack',
                     'ide/Toolset/palettes/web home/revwebhome.livecodescript'):
            self.assertEqual(ar.decide([path])[:2], (False, True), path)
        self.assertNotIn('ide/Toolset/palettes//**', ar.tests_inputs())

    def test_a_file_the_tests_read_that_the_change_deletes_runs_them(self):
        # (#595's review: the tests' inputs were the files there, so a
        # change that deleted or moved one of them ran nothing, and the
        # tests that read it failed on main)
        with tempfile.TemporaryDirectory() as repo:
            os.makedirs(os.path.join(repo, 'tests', 'lcs', 'x'))
            os.makedirs(os.path.join(repo, 'ide-support'))
            with open(os.path.join(repo, 'tests', 'lcs', 'x', 'x.livecodescript'), 'w') as f:
                f.write('on TestX\n'
                        '   get TestGetEngineRepositoryPath() & "/ide-support/kept.livecodescript"\n'
                        '   get TestGetEngineRepositoryPath() & "/ide-support/gone.livecodescript"\n'
                        '   get TestGetIDERepositoryPath() & "/Extensions/org.x.gone"\n'
                        '   get TestGetIDERepositoryPath() & "/Toolset/gone/"\n'
                        'end TestX\n')
            with open(os.path.join(repo, 'ide-support', 'kept.livecodescript'), 'w') as f:
                f.write('')
            for path in ('ide-support/kept.livecodescript', 'ide-support/gone.livecodescript',
                         'ide/Extensions/org.x.gone', 'ide/Extensions/org.x.gone/x.livecodescript',
                         'ide/Toolset/gone/x.rev'):
                engine, tests, why = ar.decide([path], repo=repo)
                self.assertEqual((engine, tests), (False, True), path)
                self.assertIn(path, why[0])
            self.assertEqual(ar.decide(['ide-support/other.livecodescript'], repo=repo)[:2], (False, False))

    def test_the_tests_inputs_are_found_in_the_tests(self):
        # (not a list kept by hand: android_tests finds them)
        inputs = ar.tests_inputs()
        self.assertIn('tests/**', inputs)
        self.assertIn('ide-support/revliburl.livecodescript', inputs)
        self.assertIn('ide/Extensions/org.openxtalk.plugin.mcpbridge/**', inputs)
        for path in ('ide-support/revsaveasandroidstandalone.livecodescript',
                     'ide-support/revdeploylibraryandroid.livecodescript'):
            self.assertIn(path, inputs)


class TheTrigger(unittest.TestCase):
    """The workflow starts for every file the gate could want: its paths
    take each file of the checkout that the engine is built from or that
    the tests read."""

    @classmethod
    def setUpClass(cls):
        try:
            import yaml
        except ImportError:
            raise unittest.SkipTest('no PyYAML')
        cls.wf = yaml.safe_load(read('.github', 'workflows', 'android-engine.yml'))

    def test_every_file_the_gate_may_want_starts_it(self):
        try:
            files = subprocess.run(['git', 'ls-files'], cwd=REPO, capture_output=True, text=True,
                                   check=True).stdout.splitlines()
        except (OSError, subprocess.CalledProcessError):
            self.skipTest('not a git checkout')
        paths = self.wf[True]['pull_request']['paths']
        self.assertEqual(paths, self.wf[True]['push']['paths'])
        inputs = ar.tests_inputs()
        wanted = [p for p in files
                  if ar.matches(p, ar.ENGINE_PATHS) or any(ar.glob_regex(x).match(p) for x in inputs)]
        self.assertGreater(len(wanted), 1000)
        self.assertTrue(any(p.startswith('tests/lcs/') for p in wanted))
        left = [p for p in wanted if not ar.matches(p, paths)]
        self.assertEqual(left, [])
        # and a test file is one of them (it was not until 0.2.8-dp.2)
        self.assertTrue(ar.matches('tests/lcs/webplayer/ember-bricks.livecodescript', paths))

    def test_the_jobs(self):
        jobs = self.wf['jobs']
        gate = jobs['gate']
        self.assertEqual(set(gate['outputs']), {'engine', 'tests', 'engine_run'})
        run = ' '.join(s.get('run', '') for s in gate['steps']).replace('\\\n', ' ')
        self.assertIn('python3 tools/ci/android_runs.py gate', ' '.join(run.split()))
        for option in ('--event "$EVENT"', '--repo "$REPO"', '--sha "$SHA"', '--pr "$PR"', '--before "$BEFORE"',
                       '--output "$GITHUB_OUTPUT"', '--summary "$GITHUB_STEP_SUMMARY"'):
            self.assertIn(option, run)
        env = [s for s in gate['steps'] if s.get('id') == 'decide'][0]['env']
        self.assertEqual(env['SHA'], '${{ github.sha }}')
        self.assertEqual(env['GH_TOKEN'], '${{ github.token }}')
        self.assertEqual(jobs['build']['needs'], 'gate')
        self.assertEqual(jobs['build']['if'], "needs.gate.outputs.engine == 'true'")
        # the device job runs the engine built here, so only where one is
        self.assertEqual(jobs['device']['needs'], 'build')
        self.assertEqual(jobs['tests']['needs'], ['gate', 'build'])
        # nothing is written anywhere
        self.assertEqual(self.wf['permissions'], {'contents': 'read', 'actions': 'read'})


class FakeGitHub(object):
    """Answers to GET paths: a pull request's files, comparisons, the runs
    on main, their jobs and artifacts."""

    def __init__(self, pr_files=(), runs=(), compare=None):
        self.pr_files = list(pr_files)
        self.runs = list(runs)
        self.compare = dict(compare or {})
        self.asked = []

    def __call__(self, path):
        self.asked.append(path)
        if '/pulls/' in path:
            page = int(path.rsplit('page=', 1)[1])
            return [{'filename': f} for f in self.pr_files[(page - 1) * 100:page * 100]]
        if '/compare/' in path:
            base, head = path.split('/compare/', 1)[1].split('...')
            files = self.compare.get((base, head))
            if files is None:
                return None
            return {'files': [{'filename': f} for f in files]}
        if '/workflows/android-engine.yml/runs' in path:
            return {'workflow_runs': [{'id': r['id'], 'head_sha': r['sha']} for r in self.runs]}
        for r in self.runs:
            if '/runs/%s/jobs' % r['id'] in path:
                return {'jobs': [{'name': n, 'conclusion': 'success' if n not in r.get('failed', ()) else 'failure'}
                                 for n in ar.BUILD_JOBS + ('Script tests on the emulator',)]}
            if '/runs/%s/artifacts' % r['id'] in path:
                return {'artifacts': [{'name': n, 'expired': n in r.get('expired', ())}
                                      for n in ar.ENGINE_ARTIFACTS + ('android-script-tests',)]}
        return None


class Gating(unittest.TestCase):

    def gate(self, api, event='pull_request', before=None):
        out = tempfile.NamedTemporaryFile('w+', delete=False)
        out.close()
        summary = out.name + '.md'
        try:
            args = ar.argparse.Namespace(event=event, repo='o/r', sha=SHA, pr='7', before=before,
                                         output=out.name, summary=summary)
            with mock.patch.object(ar, 'log'):
                self.assertEqual(ar.gate(args, api), 0)
            with open(out.name) as f:
                said = dict(line.split('=', 1) for line in f.read().split())
            with open(summary) as f:
                self.summary = f.read()
            return said
        finally:
            os.unlink(out.name)
            if os.path.exists(summary):
                os.unlink(summary)

    def same(self, sha, files=()):
        """Comparisons both ways between SHA and sha, naming files."""
        return {(sha, SHA): list(files), (SHA, sha): []}

    def test_the_tests_alone_take_an_earlier_runs_engine(self):
        api = FakeGitHub(['tests/lcs/a.livecodescript'], runs=[{'id': 11, 'sha': OLD[0]}],
                         compare=self.same(OLD[0], ['tests/lcs/a.livecodescript', 'ide/x.livecodescript']))
        self.assertEqual(self.gate(api), {'engine': 'false', 'tests': 'true', 'engine_run': '11'})
        self.assertIn('the engine of run 11 on main', self.summary)

    def test_a_run_whose_engine_sources_differ_is_passed_over(self):
        # either way: this change's side, or main's since they parted
        runs = [{'id': 13, 'sha': OLD[0]}, {'id': 12, 'sha': OLD[1]}, {'id': 11, 'sha': OLD[2]}]
        compare = {}
        compare.update({(OLD[0], SHA): ['engine/src/stacke.cpp'], (SHA, OLD[0]): []})
        compare.update({(OLD[1], SHA): [], (SHA, OLD[1]): ['libfoundation/src/a.cpp']})
        compare.update(self.same(OLD[2], ['tests/lcs/a.livecodescript']))
        api = FakeGitHub(['tests/lcs/a.livecodescript'], runs=runs, compare=compare)
        self.assertEqual(self.gate(api)['engine_run'], '11')

    def test_a_run_without_its_engine_is_passed_over(self):
        runs = [{'id': 14, 'sha': OLD[0], 'failed': ('Android engine (x86)',)},
                {'id': 13, 'sha': OLD[1], 'expired': ('android-engine-x86_64',)},
                {'id': 12, 'sha': OLD[2]}]
        compare = {}
        for sha in OLD[:3]:
            compare.update(self.same(sha))
        api = FakeGitHub(['tests/lcs/a.livecodescript'], runs=runs, compare=compare)
        self.assertEqual(self.gate(api)['engine_run'], '12')
        # (no comparison was asked for the runs without an engine)
        self.assertFalse(any(OLD[0] in p or OLD[1] in p for p in api.asked if '/compare/' in p))

    def test_a_comparison_that_may_leave_files_out_is_not_taken(self):
        compare = {(OLD[0], SHA): ['tests/x%d' % n for n in range(ar.COMPARE_FILES)], (SHA, OLD[0]): []}
        api = FakeGitHub(['tests/lcs/a.livecodescript'], runs=[{'id': 11, 'sha': OLD[0]}], compare=compare)
        self.assertEqual(self.gate(api), {'engine': 'true', 'tests': 'true', 'engine_run': ''})

    def test_with_no_engine_to_take_the_engine_is_built(self):
        api = FakeGitHub(['tests/lcs/a.livecodescript'], runs=[])
        self.assertEqual(self.gate(api), {'engine': 'true', 'tests': 'true', 'engine_run': ''})
        self.assertIn('the engine is built', self.summary)

    def test_the_engine_is_built_for_its_sources(self):
        api = FakeGitHub(['engine/src/stacke.cpp', 'tests/lcs/a.livecodescript'], runs=[{'id': 11, 'sha': OLD[0]}])
        self.assertEqual(self.gate(api), {'engine': 'true', 'tests': 'true', 'engine_run': ''})
        # (no earlier run is looked for)
        self.assertFalse(any('/runs' in p for p in api.asked))

    def test_nothing_for_a_change_neither_reads(self):
        api = FakeGitHub(['docs/x.lcdoc', 'tools/ci/web_check.py'])
        self.assertEqual(self.gate(api), {'engine': 'false', 'tests': 'false', 'engine_run': ''})

    def test_every_page_of_a_pull_requests_files(self):
        files = ['docs/x%d.lcdoc' % n for n in range(250)] + ['tests/lcs/a.livecodescript']
        api = FakeGitHub(files, runs=[{'id': 11, 'sha': OLD[0]}], compare=self.same(OLD[0]))
        self.assertEqual(self.gate(api)['tests'], 'true')
        self.assertEqual(len([p for p in api.asked if '/pulls/' in p]), 3)
        # as many as GitHub lists at most: some may be left out, so build
        api = FakeGitHub(['docs/x%d.lcdoc' % n for n in range(ar.PR_FILES)])
        self.assertEqual(self.gate(api), {'engine': 'true', 'tests': 'true', 'engine_run': ''})

    def test_a_push_compares_with_the_commit_before(self):
        compare = self.same(OLD[0])
        compare[(OLD[5], SHA)] = ['tests/lcs/a.livecodescript']
        api = FakeGitHub(runs=[{'id': 11, 'sha': OLD[0]}], compare=compare)
        self.assertEqual(self.gate(api, event='push', before=OLD[5]),
                         {'engine': 'false', 'tests': 'true', 'engine_run': '11'})
        # a new branch has no commit before: build
        api = FakeGitHub()
        self.assertEqual(self.gate(api, event='push', before='0' * 40)['engine'], 'true')

    def test_by_hand_everything(self):
        api = FakeGitHub()
        self.assertEqual(self.gate(api, event='workflow_dispatch'),
                         {'engine': 'true', 'tests': 'true', 'engine_run': ''})
        self.assertEqual(api.asked, [])

    def test_an_unreadable_change_builds(self):
        self.assertEqual(self.gate(lambda path: None)['engine'], 'true')


if __name__ == '__main__':
    unittest.main()
