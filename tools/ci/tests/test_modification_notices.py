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

"""tools/ci/modification_notices.py, the "Modified from LiveCode Community"
notice of every source file OXT-Beyond changed (GPLv3 5a). A small git
repository is made with an upstream commit, a commit vendoring ide/, and
changes by several authors; the tool must find exactly the changed
LiveCode files, write a notice that names each author with their years
where the language allows a comment without moving the meaning of
anything, keep a byte order mark and CRLF line endings, leave a file with
a notice alone, and check must fail on a changed file with none. And
this repository's own files must all carry theirs, when its history is
here to tell.

  python3 -m unittest discover -s tools/ci/tests
"""

import importlib.util
import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
TOOL = os.path.join(HERE, '..', 'modification_notices.py')

spec = importlib.util.spec_from_file_location('modification_notices', TOOL)
mn = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mn)

HEADER = ('/* Copyright (C) 2003-2015 LiveCode Ltd.\n\n'
          'This file is part of LiveCode.  */\n\n')

UPSTREAM_FILES = {
    'engine/src/a.cpp': HEADER + '#include "a.h"\nint a;\n',
    'engine/src/same.cpp': HEADER + 'int same;\n',
    'engine/src/inline.c': '/* --PATCH-- */ #include <stdio.h>\nint i;\n',
    'engine/src/moved.cpp': HEADER + 'int moved;\n',
    'extensions/w/w.lcb': HEADER + '/**\nDoc\n*/\nmodule w\nend module\n',
    'config.py': '#!/usr/bin/env python\n# Licence\n\nimport sys\n',
    'configure.bat': '@echo off\r\nREM Configures\r\nset X=1\r\n',
    'make.cmd': '@rem Detect\nset Y=1\n',
    'thirdparty/libq/libq.gyp': "{\n  'targets': [],\n}\n",
    'thirdparty/libq/src/q.c': 'int q;\n',
    'docs/dictionary/a.lcdoc': 'Name: a\n',
    'engine/src/b.png': 'not a picture\n',
}
IDE_FILES = {
    'ide/x.livecodescript': '﻿script "x"\r\non mouseUp\r\nend mouseUp\r\n',
    'ide/y.livecodescript': 'on y\nend y\n',
}


def run(cwd, *args, env=None):
    subprocess.run(args, cwd=cwd, check=True, env=env,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class ModificationNotices(unittest.TestCase):

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        run(self.dir, 'git', 'init', '-q')
        run(self.dir, 'git', 'config', 'core.autocrlf', 'false')
        run(self.dir, 'git', 'config', 'user.name', 'LiveCode')
        run(self.dir, 'git', 'config', 'user.email', 'lc@example.com')
        self.write(UPSTREAM_FILES)
        self.upstream = self.commit('LiveCode', 'upstream', '2021-07-26')
        self.write(IDE_FILES)
        self.ide_base = self.commit('Seth Morrow', 'vendor ide', '2026-09-26')

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def write(self, files):
        for path, text in files.items():
            full = os.path.join(self.dir, path)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, 'wb') as f:
                f.write(text.encode('utf-8'))

    def read(self, path):
        with open(os.path.join(self.dir, path), 'rb') as f:
            return f.read().decode('utf-8')

    def append(self, path, text):
        self.write({path: self.read(path) + text})

    def commit(self, author, message, date):
        env = dict(os.environ, GIT_AUTHOR_DATE=date + 'T12:00:00',
                   GIT_COMMITTER_DATE=date + 'T12:00:00')
        run(self.dir, 'git', 'add', '-A')
        run(self.dir, 'git', '-c', 'user.name=' + author, 'commit', '-q',
            '--allow-empty', '-m', message, env=env)
        return subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=self.dir,
                              check=True, stdout=subprocess.PIPE
                              ).stdout.decode().strip()

    def tool(self, command):
        out = io.StringIO()
        with redirect_stdout(out):
            code = mn.main([command, '--repo', self.dir,
                            '--upstream', self.upstream,
                            '--ide-base', self.ide_base])
        return code, out.getvalue()

    def change_everything(self):
        for path in ('engine/src/a.cpp', 'engine/src/inline.c',
                     'extensions/w/w.lcb', 'config.py',
                     'thirdparty/libq/libq.gyp', 'thirdparty/libq/src/q.c',
                     'docs/dictionary/a.lcdoc', 'engine/src/b.png',
                     'make.cmd', 'ide/y.livecodescript'):
            self.append(path, '\n')
        self.write({'configure.bat': UPSTREAM_FILES['configure.bat']
                    + 'set Z=2\r\n',
                    'ide/x.livecodescript': IDE_FILES['ide/x.livecodescript']
                    + '-- more\r\n',
                    'engine/src/new.cpp': 'int ours;\n'})
        run(self.dir, 'git', 'mv', 'engine/src/moved.cpp',
            'engine/src/renamed.cpp')
        self.commit('Claude', 'OXT-Beyond changes', '2026-10-01')
        self.append('engine/src/a.cpp', 'int b;\n')
        self.commit('Tom Perry', 'OpenXTalk Lite change', '2024-03-06')
        self.append('engine/src/a.cpp', 'int c;\n')
        self.commit('sethmorrowsoftware', 'a fix from HyperXTalk\n\n'
                    'Co-authored-by: Emily-Elizabath Howard <e@example.com>\n'
                    'Co-Authored-By: Claude Opus <noreply@anthropic.com>',
                    '2026-11-01')

    def test_scope(self):
        self.change_everything()
        files = dict(mn.changed_files(self.dir, self.upstream, self.ide_base))
        self.assertEqual(sorted(files), [
            'config.py', 'configure.bat', 'engine/src/a.cpp',
            'engine/src/inline.c', 'extensions/w/w.lcb',
            'ide/x.livecodescript', 'ide/y.livecodescript', 'make.cmd',
            'thirdparty/libq/libq.gyp'])
        # a rename alone is not a change, and is followed
        self.assertNotIn('engine/src/renamed.cpp', files)
        self.append('engine/src/renamed.cpp', 'int r;\n')
        files = dict(mn.changed_files(self.dir, self.upstream, self.ide_base))
        self.assertEqual(files['engine/src/renamed.cpp'],
                         'engine/src/moved.cpp')

    def test_credits(self):
        self.change_everything()
        self.assertEqual(
            mn.credits(self.dir, 'engine/src/a.cpp', 'engine/src/a.cpp',
                       self.upstream),
            [('Seth Morrow', 2026, 2026), ('Tom Perry', 2024, 2024),
             ('Emily-Elizabeth Howard', 2026, 2026)])
        # the commit that vendored ide/ changed nothing of LiveCode's
        self.assertEqual(
            mn.credits(self.dir, 'ide/y.livecodescript',
                       'ide/y.livecodescript', self.upstream),
            [('Seth Morrow', 2026, 2026)])

    def test_write_then_check(self):
        self.change_everything()
        code, out = self.tool('check')
        self.assertEqual(code, 1)
        self.assertIn('engine/src/a.cpp', out)
        code, _ = self.tool('write')
        self.assertEqual(code, 0)
        self.assertEqual(self.tool('check')[0], 0)

        a = self.read('engine/src/a.cpp')
        self.assertTrue(a.startswith(HEADER + '/* Modified from LiveCode '
                                     "Community. This copy, OpenXTalk-"
                                     "Beyond's"), a)
        self.assertIn('Seth Morrow (2026), Tom Perry (2024) and', a)
        self.assertIn('Emily-Elizabeth Howard (2026)', a)
        self.assertNotIn('Claude', a)
        self.assertIn('*/\n\n#include "a.h"\nint a;', a)

        # the code after an inline comment does not move into a comment
        self.assertTrue(self.read('engine/src/inline.c').endswith(
            '*/\n\n/* --PATCH-- */ #include <stdio.h>\nint i;\n\n'))
        lcb = self.read('extensions/w/w.lcb')
        self.assertIn('*/\n\n-- Modified from LiveCode Community', lcb)
        self.assertIn('changed.\n\n/**\nDoc\n*/\nmodule w', lcb)
        py = self.read('config.py')
        self.assertTrue(py.startswith('#!/usr/bin/env python\n# Licence\n\n'
                                      '# Modified from LiveCode'), py)
        self.assertIn('changed.\n\nimport sys', py)
        bat = self.read('configure.bat')
        self.assertTrue(bat.startswith('@echo off\r\nREM Modified from'), bat)
        self.assertNotIn('\n', bat.replace('\r\n', ''))
        self.assertTrue(self.read('make.cmd').startswith('@rem Modified '))
        self.assertTrue(self.read('thirdparty/libq/libq.gyp').startswith(
            '# Modified from LiveCode Community'))
        x = self.read('ide/x.livecodescript')
        self.assertTrue(x.startswith('﻿script "x"\r\n-- Modified from '),
                        x)
        self.assertNotIn('\n', x.replace('\r\n', ''))
        self.assertIn('changed.\r\n\r\non mouseUp', x)
        self.assertTrue(self.read('ide/y.livecodescript').startswith(
            '-- Modified from LiveCode Community'))
        for untouched in ('thirdparty/libq/src/q.c', 'engine/src/new.cpp',
                          'docs/dictionary/a.lcdoc', 'engine/src/same.cpp'):
            self.assertNotIn('Modified from', self.read(untouched))

        # a second write changes nothing, and a notice by hand is kept
        before = {p: self.read(p) for p in ('engine/src/a.cpp', 'make.cmd')}
        self.assertEqual(self.tool('write')[0], 0)
        self.assertEqual(before, {p: self.read(p) for p in before})

    def test_lines_stay_whole(self):
        lines = mn.comment_lines('c', mn.notice_text(
            [('Seth Morrow', 2026, 2026), ('Tom Perry', 2024, 2026),
             ('Emily-Elizabeth Howard', 2026, 2026), ('Mark Wieder', 2026,
                                                       2026)]))
        text = '\n'.join(lines)
        for name in ('Seth Morrow (2026)', 'Tom Perry (2024-2026)',
                     'Emily-Elizabeth Howard (2026)', 'Mark Wieder (2026)',
                     mn.URL):
            self.assertIn(name, text)
        self.assertTrue(all(len(l) <= mn.WIDTH for l in lines), lines)

    def test_first_change_needs_its_notice(self):
        self.assertEqual(self.tool('check')[0], 0)
        self.append('engine/src/same.cpp', 'int x;\n')
        code, out = self.tool('check')
        self.assertEqual(code, 1)
        self.assertIn('engine/src/same.cpp', out)

    def test_fails_closed_without_the_start_tree(self):
        out = io.StringIO()
        err = io.StringIO()
        from contextlib import redirect_stderr
        with redirect_stdout(out), redirect_stderr(err):
            code = mn.main(['check', '--repo', self.dir,
                            '--upstream', '0' * 40])
        self.assertEqual(code, 2)


class ThisRepository(unittest.TestCase):

    def test_every_changed_file_has_its_notice(self):
        try:
            subprocess.run(['git', 'cat-file', '-e', mn.UPSTREAM + '^{tree}'],
                           cwd=REPO, check=True, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
        except (subprocess.CalledProcessError, OSError):
            self.skipTest('the history is not here (a shallow clone); '
                          'CI checks runs the check with the whole history')
        out = io.StringIO()
        with redirect_stdout(out):
            code = mn.main(['check', '--repo', REPO])
        self.assertEqual(code, 0, out.getvalue())


if __name__ == '__main__':
    unittest.main()
