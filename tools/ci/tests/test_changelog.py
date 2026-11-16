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

"""tools/ci/changelog.py, the changelog fragments of changelog/: the
check CI makes on them, and folding them into CHANGELOG.md, on made-up
repositories (and the check on this one).

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import changelog  # noqa: E402

HEAD = '# Changelog\n\nWhat changed.\n\n'
RELEASED = '## 0.1.0 (2026-01-01)\n\n- Old (#1)\n'


class ChangelogTest(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.repo, changelog.FRAGMENTS))
        self.fragment('README.md', '# Not a fragment\n\nProse.\n')

    def tearDown(self):
        # (git's objects are read-only, which Windows will not delete
        # until they are made writable)
        def writable(func, path, info):
            os.chmod(path, stat.S_IWRITE)
            func(path)
        shutil.rmtree(self.repo, onerror=writable)

    def changelog(self, text=None):
        path = os.path.join(self.repo, changelog.CHANGELOG)
        if text is not None:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
        with open(path, encoding='utf-8') as f:
            return f.read()

    def fragment(self, name, text):
        with open(os.path.join(self.repo, changelog.FRAGMENTS, name), 'w', encoding='utf-8') as f:
            f.write(text)

    def git(self, *args):
        subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@t'] + list(args),
                       cwd=self.repo, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def test_the_repository_passes_its_own_check(self):
        self.assertEqual(changelog.check(changelog.REPO), [])

    def test_the_newest_release_section_is_the_version_being_released(self):
        # BUILDING.md section 10: the version change makes the folded
        # section the version's, so the first release heading of
        # CHANGELOG.md names ide/.version (a version bumped without its
        # section, or a section left as "Unreleased", fails here)
        import re
        with open(os.path.join(changelog.REPO, 'ide', '.version'), encoding='utf-8') as f:
            version = f.read().strip()
        with open(os.path.join(changelog.REPO, 'CHANGELOG.md'), encoding='utf-8') as f:
            headings = [m.group(1) for m in re.finditer(r'^## (\S+)', f.read(), re.M)]
        released = [h for h in headings if h != 'Unreleased']
        self.assertEqual(released[0], version)

    def test_check_refuses_what_is_not_a_line(self):
        self.changelog(HEAD + RELEASED)
        self.fragment('a.md', '- Good (#2)\n\n')
        self.assertEqual(changelog.check(self.repo), [])
        for bad in ('## A heading\n', 'Prose\n', '-  \n', '\n\n', '* Star (#3)\n'):
            self.fragment('b.md', bad)
            self.assertEqual(len(changelog.check(self.repo)), 1, repr(bad))

    def test_check_refuses_a_fragment_already_folded(self):
        # A fragment whose lines CHANGELOG.md already holds was folded
        # once and came back: the squash of 0.2.7-rc.6.15's version change
        # (#352) took a merge base older than two fragments it had folded
        # and deleted, so main kept changelog/346.md and the MCP Bridge's
        # fragment beside the lines folded from them, and the next fold
        # would have written those lines twice
        self.changelog(HEAD + '## 0.1.1 (2026-01-02)\n\n- Folded (#2)\n\n' + RELEASED)
        self.fragment('a.md', '- New (#3)\n')
        self.assertEqual(changelog.check(self.repo), [])
        self.fragment('b.md', '- New in b (#4)\n- Folded (#2)\n')
        problems = changelog.check(self.repo)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('b.md', problems[0])
        self.assertIn('already', problems[0])
        # the same line in two fragments is not a fold left behind, and
        # neither is a line that only begins like one in CHANGELOG.md
        self.fragment('b.md', '- New (#3)\n- Folded (#2), and more (#5)\n')
        self.assertEqual(changelog.check(self.repo), [])

    def test_a_line_names_its_pull_request_at_its_end(self):
        self.assertEqual(changelog.pull_requests('- One (#168)'), ['168'])
        self.assertEqual(changelog.pull_requests('- Two (#511, #513)  '), ['511', '513'])
        for none in ('- None', '- In the middle (#3) and on', '- A dot after (#3).', '- (#PR)',
                     '- A branch (claude-project-thread-kmsnyl)', '- No hash (168)', '- (#3,#4)',
                     '- A report (issue #518)'):
            self.assertEqual(changelog.pull_requests(none), [], none)

    def test_check_refuses_a_line_without_its_pull_request(self):
        # Every line of CHANGELOG.md ends with its pull request's number,
        # and fold writes a fragment's lines to it as they are. Five lines
        # merged for 0.2.8-dp.2 had none, and before that a fold had
        # "(#PR)" and "(claude-project-thread-kmsnyl)" to put right by hand
        self.changelog(HEAD + RELEASED)
        for good in ('- One (#3)\n', '- Two (#511, #513)\n', '- Spaces after (#3)   \n\n'):
            self.fragment('a.md', good)
            self.assertEqual(changelog.check(self.repo), [], repr(good))
        for bad in ('- No number\n', '- Good (#3)\n- To be filled in (#PR)\n',
                    '- The branch (claude-project-thread-kmsnyl)\n', '- In the middle (#3), and on\n',
                    '- A dot after (#3).\n'):
            self.fragment('a.md', bad)
            problems = changelog.check(self.repo)
            self.assertEqual(len(problems), 1, repr(bad))
            self.assertIn('a.md', problems[0])
            self.assertIn("pull request's number", problems[0])
            with self.assertRaises(changelog.ChangelogError):
                changelog.fold(self.repo, dry_run=True)

    def test_check_refuses_two_unreleased_sections(self):
        self.changelog(HEAD + '## Unreleased\n\n- A\n\n## Unreleased\n\n' + RELEASED)
        self.assertEqual(len(changelog.check(self.repo)), 1)

    def test_fold_appends_to_unreleased(self):
        self.changelog(HEAD + '## Unreleased\n\n- By hand (#2)\n\n' + RELEASED)
        self.fragment('x.md', '- From x (#3)\n- And x (#3)\n')
        self.assertEqual(changelog.fold(self.repo), ['- From x (#3)', '- And x (#3)'])
        self.assertEqual(self.changelog(), HEAD + '## Unreleased\n\n- By hand (#2)\n'
                         '- From x (#3)\n- And x (#3)\n\n' + RELEASED)
        self.assertEqual(changelog.fragment_names(self.repo), [])
        self.assertTrue(os.path.exists(os.path.join(self.repo, changelog.FRAGMENTS, 'README.md')))

    def test_fold_makes_unreleased_above_the_newest_release(self):
        self.changelog(HEAD + RELEASED)
        self.fragment('x.md', '- New (#2)\n')
        changelog.fold(self.repo)
        self.assertEqual(self.changelog(), HEAD + '## Unreleased\n\n- New (#2)\n\n' + RELEASED)

    def test_fold_fills_an_empty_unreleased(self):
        for empty in ('## Unreleased\n\n', '## Unreleased\n'):
            self.changelog(HEAD + empty + RELEASED)
            self.fragment('x.md', '- New (#2)\n')
            changelog.fold(self.repo)
            self.assertEqual(self.changelog(), HEAD + '## Unreleased\n\n- New (#2)\n\n' + RELEASED,
                             repr(empty))

    def test_fold_at_the_end_of_the_file(self):
        self.changelog(HEAD + '## Unreleased\n\n- By hand (#2)\n')
        self.fragment('x.md', '- New (#3)\n')
        changelog.fold(self.repo)
        self.assertEqual(self.changelog(), HEAD + '## Unreleased\n\n- By hand (#2)\n- New (#3)\n')

    def test_dry_run_changes_nothing(self):
        before = HEAD + RELEASED
        self.changelog(before)
        self.fragment('x.md', '- New (#2)\n')
        self.assertEqual(changelog.fold(self.repo, dry_run=True), ['- New (#2)'])
        self.assertEqual(self.changelog(), before)
        self.assertEqual(changelog.fragment_names(self.repo), ['x.md'])

    def test_fold_refuses_a_bad_fragment_and_changes_nothing(self):
        before = HEAD + RELEASED
        self.changelog(before)
        self.fragment('a.md', '- Good (#2)\n')
        self.fragment('b.md', 'Prose\n')
        with self.assertRaises(changelog.ChangelogError):
            changelog.fold(self.repo)
        self.assertEqual(self.changelog(), before)
        self.assertEqual(changelog.fragment_names(self.repo), ['a.md', 'b.md'])

    def commit(self, message, when):
        env = dict(os.environ, GIT_COMMITTER_DATE=when + ' +0000', GIT_AUTHOR_DATE=when + ' +0000')
        subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q',
                        '-m', message], cwd=self.repo, check=True, env=env,
                       stdout=subprocess.DEVNULL)

    def test_fragments_fold_in_the_order_they_were_merged(self):
        self.changelog(HEAD + RELEASED)
        self.git('init', '-q', '-b', 'main')
        self.git('add', '-A')
        self.commit('start', '1700000000')
        # z on main first, then a: the commit order, not the names
        for name, when in (('z.md', '1700000100'), ('a.md', '1700000200')):
            self.fragment(name, '- From %s (#2)\n' % name[0])
            self.git('add', '-A')
            self.commit(name, when)
        # old's commit is older than new's, but old's branch is merged
        # (with a merge commit) after new's: merge order wins
        for branch, when in (('old', '1700000300'), ('new', '1700000400')):
            self.git('checkout', '-q', '-b', branch, 'main')
            self.fragment(branch + '.md', '- From %s (#3)\n' % branch)
            self.git('add', '-A')
            self.commit(branch, when)
            self.git('checkout', '-q', 'main')
        for branch, when in (('new', '1700000500'), ('old', '1700000600')):
            env = dict(os.environ, GIT_COMMITTER_DATE=when + ' +0000', GIT_AUTHOR_DATE=when + ' +0000')
            subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@t', 'merge', '-q',
                            '--no-ff', '-m', 'merge ' + branch, branch], cwd=self.repo,
                           check=True, env=env, stdout=subprocess.DEVNULL)
        # not committed yet: last
        self.fragment('m.md', '- From m (#4)\n')
        self.assertEqual(changelog.fold(self.repo),
                         ['- From z (#2)', '- From a (#2)', '- From new (#3)', '- From old (#3)',
                          '- From m (#4)'])

    def test_check_refuses_a_folder_and_other_files(self):
        self.changelog(HEAD + RELEASED)
        os.makedirs(os.path.join(self.repo, changelog.FRAGMENTS, 'fix'))
        self.fragment(os.path.join('fix', 'menu.md'), '- Nested (#2)\n')
        self.fragment('notes.txt', '- Not markdown (#3)\n')
        problems = changelog.check(self.repo)
        self.assertEqual(len(problems), 2, problems)
        with self.assertRaises(changelog.ChangelogError):
            changelog.fold(self.repo)

    def test_without_git_by_name(self):
        self.changelog(HEAD + RELEASED)
        self.fragment('b.md', '- B (#3)\n')
        self.fragment('a.md', '- A (#2)\n')
        self.assertEqual(changelog.fold(self.repo, dry_run=True), ['- A (#2)', '- B (#3)'])


class LostLines(unittest.TestCase):
    """check --base: no pull request's lines are lost between a commit
    and here. #508 came from a branch whose name #502's had been
    (claude/project-thread-vvfnvp), wrote its fragment under that name,
    and so wrote its two lines over #502's five. Nothing saw it: the
    fragment was well formed. The fold for 0.2.8-dp.2 would have left
    #502 out of CHANGELOG.md and the release notes."""

    # the merge of #508 on main, whose first parent still had #502's lines
    MERGE_OF_508 = '24d0517dc49d4167edf25e94a03791c567b6265c'
    MERGE_OF_502 = '75c0c9342f70139b6fc6c90e08f2a3d1094a741b'

    # the made-up repository of the tests above, and its helpers (not
    # the tests themselves, which a subclass would run again)
    tearDown = ChangelogTest.tearDown
    changelog = ChangelogTest.changelog
    fragment = ChangelogTest.fragment
    git = ChangelogTest.git

    def setUp(self):
        ChangelogTest.setUp(self)
        self.changelog(HEAD + '## Unreleased\n\n- By hand (#2)\n\n' + RELEASED)
        self.git('init', '-q', '-b', 'main')
        self.fragment('claude-thread.md', '- First of three (#3)\n- Second of three (#3)\n- Tests of three (#3)\n')
        self.fragment('4.md', '- Four (#4)\n')
        self.save('main as a pull request finds it')

    def save(self, message):
        self.git('add', '-A')
        self.git('commit', '-q', '-m', message)

    def merged(self, change):
        """change made on a branch and merged with a merge commit, as CI
        checks a pull request out: HEAD^1 is main as it was."""
        self.git('checkout', '-q', '-b', 'work', 'main')
        change()
        self.save('the pull request')
        self.git('checkout', '-q', 'main')
        self.git('merge', '-q', '--no-ff', '-m', 'merge', 'work')
        return changelog.check(self.repo, 'HEAD^1')

    def run_check(self, *args):
        import contextlib
        import io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = changelog.main(['--repo', self.repo, 'check'] + list(args))
        return code, out.getvalue()

    def test_a_fragment_written_over_under_a_name_used_before_is_seen(self):
        # as #508 did to #502
        problems = self.merged(lambda: self.fragment('claude-thread.md', '- Five (#5)\n- Tests of five (#5)\n'))
        self.assertEqual(len(problems), 1, problems)
        for part in ('changelog/claude-thread.md', '3 of the lines', 'HEAD^1', 'First of three', '#3',
                     "the pull request's number"):
            self.assertIn(part, problems[0])
        # the fragment itself is well formed: without the base nothing is
        # compared, which is why the command CI runs has it (below)
        self.assertEqual(changelog.check(self.repo), [])
        code, out = self.run_check('--base', 'HEAD^1')
        self.assertEqual(code, 1)
        self.assertIn('ERROR: changelog/claude-thread.md', out)
        self.assertEqual(self.run_check()[0], 0)

    def test_the_command_says_that_nothing_is_lost(self):
        self.fragment('5.md', '- Five (#5)\n')
        code, out = self.run_check('--base', 'HEAD')
        self.assertEqual(code, 0, out)
        self.assertIn('3 changelog fragment(s), all well formed', out)
        self.assertIn("no line of HEAD's fragments is lost", out)

    def test_a_new_fragment_loses_nothing(self):
        self.assertEqual(self.merged(lambda: self.fragment('5.md', '- Five (#5)\n')), [])

    def test_a_fold_loses_nothing(self):
        # the lines are in CHANGELOG.md, and the fragments deleted: in the
        # working tree as the version's pull request has it, and merged
        folded = changelog.fold(self.repo)
        self.assertEqual(len(folded), 4)
        self.assertEqual(changelog.fragment_names(self.repo), [])
        self.assertEqual(changelog.check(self.repo, 'HEAD'), [])
        self.git('checkout', '-q', '--', '.')
        self.assertEqual(self.merged(lambda: changelog.fold(self.repo)), [])

    def test_a_fragment_deleted_without_a_fold_is_seen(self):
        problems = self.merged(lambda: os.remove(os.path.join(self.repo, changelog.FRAGMENTS, '4.md')))
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('changelog/4.md', problems[0])
        self.assertIn('#4', problems[0])

    def test_a_fragment_given_its_number_for_a_name_loses_nothing(self):
        def rename():
            os.rename(os.path.join(self.repo, changelog.FRAGMENTS, 'claude-thread.md'),
                      os.path.join(self.repo, changelog.FRAGMENTS, '3.md'))
        self.assertEqual(self.merged(rename), [])

    def test_a_line_may_be_reworded_and_one_of_several_removed(self):
        # what is refused is a pull request left with no line at all
        self.assertEqual(self.merged(lambda: self.fragment(
            'claude-thread.md', '- The first of three, said better (#3)\n- Tests of three (#3)\n')), [])

    def test_a_line_of_two_pull_requests_needs_both_named(self):
        self.fragment('67.md', '- Six and seven (#6, #7)\n- Seven alone (#7)\n')
        self.save('two more')
        self.fragment('67.md', '- Seven alone (#7)\n')
        problems = changelog.check(self.repo, 'HEAD')
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('no line is left of #6.', problems[0])
        self.fragment('67.md', '- Seven alone (#7)\n- Six, in other words (#6)\n')
        self.assertEqual(changelog.check(self.repo, 'HEAD'), [])

    def test_each_fragment_that_lost_lines_is_named(self):
        self.fragment('claude-thread.md', '- Five (#5)\n')
        os.remove(os.path.join(self.repo, changelog.FRAGMENTS, '4.md'))
        problems = changelog.check(self.repo, 'HEAD')
        self.assertEqual([p.split(':')[0] for p in problems], ['changelog/4.md', 'changelog/claude-thread.md'])

    def test_a_line_that_named_no_pull_request_may_only_gain_its_number(self):
        # (lines merged before check asked for the number: main had five
        # when this was written, and the change that numbered them had to
        # pass this itself)
        self.fragment('old.md', '- From before\n- And another\n')
        self.save('before the number was asked for')
        self.fragment('old.md', '- From before (#8)\n- And another (#8)\n')
        self.assertEqual(changelog.lost(self.repo, 'HEAD'), [])
        self.fragment('old.md', '- From before (#8)\n- Another, in other words (#8)\n')
        problems = changelog.lost(self.repo, 'HEAD')
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('And another', problems[0])
        self.assertIn('it named no pull request', problems[0])

    def test_a_base_that_cannot_be_read_is_an_error_not_a_pass(self):
        # (a shallow clone has no HEAD^1: CI checks fetches the whole
        # history, and the test below holds it to that)
        problems = changelog.check(self.repo, 'no-such-commit')
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('cannot read the commit no-such-commit', problems[0])
        self.assertEqual(self.run_check('--base', 'no-such-commit')[0], 1)
        # (nor is it read as an option of git's)
        self.assertEqual(len(changelog.check(self.repo, '--all')), 1)
        # the first commit has no parent
        self.assertEqual(len(changelog.check(self.repo, 'HEAD^1')), 1)
        # and a folder that is no repository has no commit at all
        plain = tempfile.mkdtemp()
        try:
            os.makedirs(os.path.join(plain, changelog.FRAGMENTS))
            with open(os.path.join(plain, changelog.CHANGELOG), 'w', encoding='utf-8') as f:
                f.write(HEAD + RELEASED)
            self.assertEqual(changelog.check(plain), [])
            self.assertEqual(len(changelog.check(plain, 'HEAD')), 1)
        finally:
            shutil.rmtree(plain)

    def test_a_push_of_several_commits_is_compared_with_main_before_it(self):
        # HEAD^1 is only the parent of the last commit of a push: a
        # fragment written over by the first of two would pass. On a push
        # CI gives the commit the push replaced (github.event.before)
        before = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=self.repo, check=True,
                                stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()
        self.fragment('claude-thread.md', '- Five (#5)\n')
        self.save('the first of the push writes over a fragment')
        with open(os.path.join(self.repo, 'other.txt'), 'w', encoding='utf-8') as f:
            f.write('something else\n')
        self.save('the second changes something else')
        self.assertEqual(changelog.check(self.repo, 'HEAD^1'), [])
        self.assertEqual(changelog.base_of(self.repo, 'HEAD^1', before), (before, None))
        code, out = self.run_check('--base', 'HEAD^1', '--pushed-over', before)
        self.assertEqual(code, 1, out)
        self.assertIn('ERROR: changelog/claude-thread.md', out)
        self.assertIn(before, out)
        # no push (a pull request's merge commit), and a branch's first
        # push, for which GitHub gives zeros: HEAD^1, and nothing to say
        for none in ('', '0' * 40):
            self.assertEqual(changelog.base_of(self.repo, 'HEAD^1', none), ('HEAD^1', None))
            code, out = self.run_check('--base', 'HEAD^1', '--pushed-over', none)
            self.assertEqual(code, 0, out)
            self.assertNotIn('NOTE', out)
            self.assertIn("no line of HEAD^1's fragments is lost", out)
        # a commit a forced push left behind is not in the history: HEAD^1
        # then, and the run says so
        gone = '1234567890' * 4
        code, out = self.run_check('--base', 'HEAD^1', '--pushed-over', gone)
        self.assertEqual(code, 0, out)
        self.assertIn('NOTE: the commit this push replaced (%s) is not in the history' % gone, out)
        self.assertIn('comparing with HEAD^1', out)
        # (and it is never read as an option of git's)
        self.assertEqual(changelog.base_of(self.repo, 'HEAD^1', '--all')[0], 'HEAD^1')
        # alone it has nothing to fall back on
        import contextlib
        import io
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            changelog.main(['--repo', self.repo, 'check', '--pushed-over', before])

    def test_between_two_commits(self):
        # (how the history is looked through, and the test below)
        self.fragment('claude-thread.md', '- Five (#5)\n')
        self.save('written over')
        self.assertEqual(len(changelog.lost(self.repo, 'HEAD^1', 'HEAD')), 1)
        self.fragment('3.md', '- First of three (#3)\n')
        self.save('put back')
        self.assertEqual(changelog.lost(self.repo, 'HEAD^1', 'HEAD'), [])
        self.assertEqual(changelog.lost(self.repo, 'HEAD~2', 'HEAD'), [])
        self.assertEqual(len(changelog.lost(self.repo, 'HEAD~2', 'HEAD~1')), 1)
        # the working tree is not what is read when a commit is named
        os.remove(os.path.join(self.repo, changelog.FRAGMENTS, '3.md'))
        self.assertEqual(changelog.lost(self.repo, 'HEAD~2', 'HEAD'), [])
        self.assertEqual(len(changelog.lost(self.repo, 'HEAD~2')), 1)

    def test_the_lines_main_lost_are_seen(self):
        # the merge itself, as CI would have checked #508: its first
        # parent against it. Skipped only where the clone has no history
        # (CI checks fetches all of it)
        for sha in (self.MERGE_OF_508, self.MERGE_OF_502):
            if changelog.git_lines(changelog.REPO, 'rev-parse', '--verify', '--quiet',
                                   sha + '^1^{commit}') is None:
                self.skipTest('this clone does not have commit %s and its parent' % sha[:10])
        problems = changelog.lost(changelog.REPO, self.MERGE_OF_508 + '^1', self.MERGE_OF_508)
        self.assertEqual(len(problems), 1, problems)
        for part in ('changelog/claude-project-thread-vvfnvp.md', '5 of the lines', 'popup of a field',
                     'no line is left of #502.'):
            self.assertIn(part, problems[0])
        # and #502's own merge, which brought them, lost nothing
        self.assertEqual(changelog.lost(changelog.REPO, self.MERGE_OF_502 + '^1', self.MERGE_OF_502), [])

    def test_ci_gives_the_base_and_has_the_history_for_it(self):
        # "CI checks" checks out a pull request's merge commit, so HEAD^1
        # is main as the pull request finds it; on a push it gives the
        # commit the push replaced. Without --base nothing is compared,
        # and without the whole history there is no HEAD^1
        import re
        with open(os.path.join(changelog.REPO, '.github', 'workflows', 'ci-checks.yml'), encoding='utf-8') as f:
            text = f.read()
        job = re.search(r'^  checks:\n(.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)', text, re.S | re.M)
        self.assertIsNotNone(job)
        runs = re.findall(r'^\s+run: (python3 tools/ci/changelog\.py check.*)$', job.group(1), re.M)
        self.assertEqual(runs, ['python3 tools/ci/changelog.py check --base HEAD^1 '
                                '--pushed-over "$PUSHED_OVER"'])
        self.assertIn("          PUSHED_OVER: ${{ github.event_name == 'push' && github.event.before || '' }}\n"
                      '        run: ' + runs[0] + '\n', job.group(1))
        checkout = re.search(r'uses: actions/checkout@\S+\n\s+with:\n((?:\s+\S.*\n)+?)\n', job.group(1))
        self.assertIsNotNone(checkout)
        self.assertIn('fetch-depth: 0', checkout.group(1))
        self.assertNotIn('ref:', checkout.group(1))


if __name__ == '__main__':
    unittest.main()
