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

"""tools/ci/release_assets.py and tools/ci/release_notes.py, the checks
release.yml makes on the packages before it publishes them (whether it built
them or took them from main's builds), on made-up artifacts.

  python3 -m unittest discover -s tools/ci/tests
"""

import hashlib
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import release_assets  # noqa: E402
import release_notes  # noqa: E402

VERSION = '1.2.3-rc.4'


def quiet(*args):
    pass


class ReleaseAssetsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.artifacts = os.path.join(self.tmp, 'artifacts')
        self.out = os.path.join(self.tmp, 'release')
        for artifact, _, names in release_assets.expected(VERSION):
            folder = os.path.join(self.artifacts, artifact)
            os.makedirs(folder)
            for name in names:
                self.write(artifact, name, name.encode() * 3)
            self.write_sums(artifact)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, artifact, name, data):
        with open(os.path.join(self.artifacts, artifact, name), 'wb') as f:
            f.write(data)

    def write_sums(self, artifact):
        folder = os.path.join(self.artifacts, artifact)
        lines = []
        for name in sorted(os.listdir(folder)):
            if name != release_assets.SUMS:
                with open(os.path.join(folder, name), 'rb') as f:
                    lines.append('%s  %s\n' % (hashlib.sha256(f.read()).hexdigest(), name))
        with open(os.path.join(folder, release_assets.SUMS), 'w') as f:
            f.writelines(lines)

    def assemble(self):
        return release_assets.assemble(VERSION, self.artifacts, self.out, log=quiet)

    def test_assembles_every_file_with_one_sums_file(self):
        problems, lines = self.assemble()
        self.assertEqual(list(problems), [])
        self.assertEqual(sorted(os.listdir(self.out)), sorted(release_assets.release_files(VERSION)))
        self.assertEqual(len(lines), len(release_assets.release_files(VERSION)) - 1)
        self.assertEqual(lines, sorted(lines, key=lambda line: line.split('  ', 1)[1]))

    def test_a_missing_file_fails(self):
        name = 'OXT-Beyond-%s-xtalk-sources.zip' % VERSION
        os.remove(os.path.join(self.artifacts, 'OXT-Beyond-win-x86_64', name))
        self.write_sums('OXT-Beyond-win-x86_64')
        problems, _ = self.assemble()
        self.assertTrue(any('%s is missing' % name in p for p in problems), problems)
        self.assertFalse(os.path.exists(self.out))

    def test_an_extra_file_fails(self):
        self.write('OXT-Beyond-linux-arm64', 'stray.txt', b'x')
        self.write_sums('OXT-Beyond-linux-arm64')
        problems, _ = self.assemble()
        self.assertTrue(any('stray.txt is not a file of the release' in p for p in problems), problems)

    def test_a_changed_file_fails(self):
        self.write('OXT-Beyond-mac-universal', 'OXT-Beyond-%s-mac-universal.dmg' % VERSION, b'changed')
        problems, _ = self.assemble()
        self.assertTrue(any('does not match its' in p for p in problems), problems)

    def test_a_file_made_twice_fails(self):
        name = 'OXT-Beyond-%s-xtalk-sources.zip' % VERSION
        self.write('OXT-Beyond-linux-x86_64', name, b'again')
        self.write_sums('OXT-Beyond-linux-x86_64')
        problems, _ = self.assemble()
        self.assertTrue(any(name in p for p in problems), problems)

    def test_a_missing_artifact_fails(self):
        shutil.rmtree(os.path.join(self.artifacts, 'OXT-Beyond-linux-arm64'))
        problems, _ = self.assemble()
        self.assertTrue(any('OXT-Beyond-linux-arm64: not downloaded' in p for p in problems), problems)

    def test_check_uploaded(self):
        problems, _ = self.assemble()
        self.assertEqual(list(problems), [])
        sums = release_assets.read_sums(os.path.join(self.out, release_assets.SUMS),
                                        release_assets.Problems(), 'here')
        sums[release_assets.SUMS] = release_assets.sha256(os.path.join(self.out, release_assets.SUMS))
        rows = ['%s\t%d\tuploaded\tsha256:%s' % (name, os.path.getsize(os.path.join(self.out, name)), digest)
                for name, digest in sums.items()]
        assets = os.path.join(self.tmp, 'assets.tsv')
        with open(assets, 'w') as f:
            f.write('\n'.join(rows) + '\n')
        self.assertEqual(list(release_assets.check_uploaded(self.out, assets, log=quiet)), [])

        # one upload short, and one asset that is not a file of the release
        with open(assets, 'w') as f:
            f.write('\n'.join(rows[1:] + ['other.zip\t1\tuploaded\t']) + '\n')
        problems = release_assets.check_uploaded(self.out, assets, log=quiet)
        self.assertTrue(any('was not uploaded' in p for p in problems), problems)
        self.assertTrue(any('other.zip' in p for p in problems), problems)


class ReleaseNotesTest(unittest.TestCase):
    def test_notes_describe_every_file(self):
        names = release_assets.release_files(VERSION)
        text = release_notes.notes(VERSION, names, commit='0' * 40)
        self.assertIn('from commit ' + '0' * 40, text)
        for name in names:
            self.assertIn(name, text)

    def test_the_update_check_shows_the_opening_lines(self):
        for version in (VERSION, '1.2.3'):
            text = release_notes.notes(version, release_assets.release_files(version))
            self.assertIsNone(release_notes.check_intro(version, text))

    def test_files_that_are_not_the_release_fail(self):
        names = release_assets.release_files(VERSION)[1:]
        with self.assertRaises(release_notes.NotesError):
            release_notes.notes(VERSION, names)


if __name__ == '__main__':
    unittest.main()
