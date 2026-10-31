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

    def test_check_refuses_what_is_not_a_line(self):
        self.changelog(HEAD + RELEASED)
        self.fragment('a.md', '- Good (#2)\n\n')
        self.assertEqual(changelog.check(self.repo), [])
        for bad in ('## A heading\n', 'Prose\n', '-  \n', '\n\n', '* Star (#3)\n'):
            self.fragment('b.md', bad)
            self.assertEqual(len(changelog.check(self.repo)), 1, repr(bad))

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
            self.fragment(name, '- From %s\n' % name[0])
            self.git('add', '-A')
            self.commit(name, when)
        # old's commit is older than new's, but old's branch is merged
        # (with a merge commit) after new's: merge order wins
        for branch, when in (('old', '1700000300'), ('new', '1700000400')):
            self.git('checkout', '-q', '-b', branch, 'main')
            self.fragment(branch + '.md', '- From %s\n' % branch)
            self.git('add', '-A')
            self.commit(branch, when)
            self.git('checkout', '-q', 'main')
        for branch, when in (('new', '1700000500'), ('old', '1700000600')):
            env = dict(os.environ, GIT_COMMITTER_DATE=when + ' +0000', GIT_AUTHOR_DATE=when + ' +0000')
            subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@t', 'merge', '-q',
                            '--no-ff', '-m', 'merge ' + branch, branch], cwd=self.repo,
                           check=True, env=env, stdout=subprocess.DEVNULL)
        # not committed yet: last
        self.fragment('m.md', '- From m\n')
        self.assertEqual(changelog.fold(self.repo),
                         ['- From z', '- From a', '- From new', '- From old', '- From m'])

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
        self.fragment('b.md', '- B\n')
        self.fragment('a.md', '- A\n')
        self.assertEqual(changelog.fold(self.repo, dry_run=True), ['- A', '- B'])


if __name__ == '__main__':
    unittest.main()
