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

"""The paths-ignore lists of the three build workflows: a change to a file
that a platform's build uses must start that build.

Each build workflow skips a push or pull request that changes only files of
its paths-ignore list (what only the other platforms use, and what builds
nothing). This checks every list against what the workflow names: the
workflow file itself, every file of tools/ci it names, and every file of
tools/ci that those name in turn (an import, a script it runs, a baseline
it reads), none of which may be in the list. It also checks that push and
pull_request share the list, and that every entry of the list matches a
file, so that a renamed file does not leave a stale entry behind.

  python3 -m unittest discover -s tools/ci/tests
"""

import ast
import os
import re
import unittest

import yaml

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
CI = os.path.join(REPO, 'tools', 'ci')
WORKFLOWS = os.path.join(REPO, '.github', 'workflows')
BUILDS = ('build-windows.yml', 'build-linux.yml', 'build-macos.yml')


def glob_regex(pattern):
    """GitHub's path filter glob: * and ? stop at /, ** does not."""
    out = []
    i = 0
    while i < len(pattern):
        c = pattern[i]
        if pattern.startswith('**', i):
            out.append('.*')
            i += 2
            continue
        out.append({'*': '[^/]*', '?': '[^/]'}.get(c, re.escape(c)))
        i += 1
    return re.compile('^' + ''.join(out) + '$')


def ignored(patterns, path):
    return [p for p in patterns if glob_regex(p).match(path)]


def repo_files():
    out = []
    for top in ('.github', 'tools'):
        for root, dirs, files in os.walk(os.path.join(REPO, top)):
            dirs[:] = [d for d in dirs if d != '__pycache__']
            for f in files:
                out.append(os.path.relpath(os.path.join(root, f), REPO).replace(os.sep, '/'))
    out += [f for f in os.listdir(REPO) if os.path.isfile(os.path.join(REPO, f))]
    return out


def ci_files():
    return sorted(f for f in os.listdir(CI) if os.path.isfile(os.path.join(CI, f)))


def read(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        return f.read()


def named(text, names):
    """The names of tools/ci files that the text mentions."""
    return set(n for n in names if re.search(r'(?<![\w.-])' + re.escape(n) + r'(?![\w-])', text))


def code_of(name):
    """What a file of tools/ci does with other files, without what it only
    says about them: a Python file's imports and its strings other than
    docstrings, another script's lines that are not comments, and nothing
    for a baseline (a list of test names)."""
    path = os.path.join(CI, name)
    text = read(path)
    if name.endswith('.txt'):
        return ''
    if name.endswith('.py'):
        tree = ast.parse(text, path)
        docstrings = set()
        for node in ast.walk(tree):
            if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
                body = node.body
                if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant):
                    docstrings.add(id(body[0].value))
        out = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                out += [a.name + '.py' for a in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                out.append(node.module + '.py')
            elif (isinstance(node, ast.Constant) and isinstance(node.value, str)
                  and id(node) not in docstrings):
                out.append(node.value)
        return '\n'.join(out)
    text = re.sub(r'(?s)<#.*?#>', '', text)          # PowerShell block comments
    return '\n'.join(line for line in text.splitlines()
                     if not line.lstrip().startswith(('#', '--', '//')))


# Names in code that do not make the file used on every platform, so that
# the other platforms' paths-ignore lists may have them: (file, the file it
# names) -> why
ONLY_NAMED = {
    ('run_livecode_check.py', 'ide-compile-check.ps1'):
        'only named in the header of the baseline it writes',
    ('run_engine_tests.py', 'win_crashtrace.py'):
        'run on Windows only (family == "windows")',
}


def without_comments(workflow_text):
    return '\n'.join(line for line in workflow_text.splitlines() if not line.lstrip().startswith('#'))


def without_paths_ignore(workflow_text):
    """The workflow without its paths-ignore lists, which name files
    without using them."""
    return re.sub(r'(?m)^( *)paths-ignore:.*\n(?:\1 .*\n|\s*\n)*', '', workflow_text)


def used_ci_files(workflow_text):
    """The files of tools/ci that the workflow's steps name, and what those
    use in turn, to the end."""
    names = ci_files()
    used = named(without_comments(without_paths_ignore(workflow_text)), names)
    todo = list(used)
    while todo:
        name = todo.pop()
        more = set(n for n in named(code_of(name), names) if (name, n) not in ONLY_NAMED) - used
        used |= more
        todo += more
    return used


def paths_ignore(workflow):
    with open(os.path.join(WORKFLOWS, workflow), encoding='utf-8') as f:
        on = yaml.safe_load(f)[True]   # PyYAML reads the key "on" as True
    return on['push']['paths-ignore'], on['pull_request']['paths-ignore']


class BuildPathsTest(unittest.TestCase):
    def test_push_and_pull_request_share_the_list(self):
        for wf in BUILDS:
            push, pr = paths_ignore(wf)
            self.assertEqual(push, pr, wf)

    def test_every_entry_matches_a_file(self):
        files = repo_files()
        for wf in BUILDS:
            for pattern in paths_ignore(wf)[0]:
                rx = glob_regex(pattern)
                self.assertTrue(any(rx.match(f) for f in files),
                                '%s: the paths-ignore entry %r matches no file' % (wf, pattern))

    def test_a_build_does_not_ignore_what_it_uses(self):
        for wf in BUILDS:
            patterns = paths_ignore(wf)[0]
            self.assertFalse(ignored(patterns, '.github/workflows/' + wf), '%s ignores itself' % wf)
            for name in sorted(used_ci_files(read(os.path.join(WORKFLOWS, wf)))):
                hits = ignored(patterns, 'tools/ci/' + name)
                self.assertFalse(hits, '%s uses tools/ci/%s but its paths-ignore has %s' % (wf, name, hits))

    def test_the_glob(self):
        self.assertTrue(glob_regex('*.md').match('README.md'))
        self.assertFalse(glob_regex('*.md').match('docs/guide.md'))
        self.assertTrue(glob_regex('tools/ci/tests/**').match('tools/ci/tests/a/b.py'))
        self.assertTrue(glob_regex('tools/ci/*.ps1').match('tools/ci/smoke-test.ps1'))
        self.assertFalse(glob_regex('tools/ci/*.ps1').match('tools/ci/x/smoke-test.ps1'))


if __name__ == '__main__':
    unittest.main()
