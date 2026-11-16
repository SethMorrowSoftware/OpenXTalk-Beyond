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

"""The scripts of the remastered examples, kept as text in stack-scripts/,
are the scripts in the stacks.

An example in ide/Resources/Examples/Remastered is a binary stack built
from its builder in tools/examples, and tools/oxt/stack-scripts.sh writes
the scripts in it to stack-scripts/ so that Git can show them. That step
needs an engine, and only the Linux build checks it ("Binary stack
scripts"): the Quick Start Guide built again for #530 went up with the
window's script of the build before in stack-scripts/, and the build
stopped on it.

This needs no engine. A stack file of the current format holds each
script as its UTF-8 text, so the script in each text file must be in the
bytes of its stack. It does not see a script that has no text file yet;
the build's check does.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
EXAMPLES = os.path.join('ide', 'Resources', 'Examples', 'Remastered')
KEPT = os.path.join(REPO, 'stack-scripts', EXAMPLES)
HOW = 'run tools/oxt/stack-scripts.sh <development engine> and commit the result (CONTRIBUTING.md, "Binary stacks")'


def kept():
    """(the stack's path in the repository, the text file's path) for each
    script of a remastered example kept in stack-scripts/"""
    out = []
    for folder in sorted(os.listdir(KEPT)):
        if not folder.endswith('.bst'):
            continue
        scripts = os.path.join(KEPT, folder, 'scripts')
        for name in sorted(os.listdir(scripts)):
            out.append((os.path.join(EXAMPLES, folder[:-len('.bst')]), os.path.join(scripts, name)))
    return out


def parts(data):
    """A text file's header lines and its script. tools/oxt/stack_scripts.py
    writes the header (the script's name, the stack file, the object, and
    two lines on where the file is from), an empty line, and the script."""
    head, gap, script = data.partition(b'\n\n')
    return head.split(b'\n'), script.rstrip(b'\n')


class ExampleStackScripts(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.kept = kept()
        cls.stacks = {}
        for rel in sorted(set(rel for rel, path in cls.kept)):
            full = os.path.join(REPO, rel)
            if os.path.isfile(full):
                with open(full, 'rb') as f:
                    cls.stacks[rel] = f.read()

    def read(self, path):
        with open(path, 'rb') as f:
            return f.read()

    def test_the_examples_have_scripts_kept(self):
        # (so that the tests below are not about nothing: the Quick Start
        # Guide's window script, the one #530's build stopped on, is one)
        self.assertGreater(len(self.kept), 100)
        guide = os.path.join(EXAMPLES, 'Quick Start Guide.oxtstack')
        names = [os.path.basename(path) for rel, path in self.kept if rel == guide]
        self.assertIn('stack_Quick_Start_Guide_group_id_1003.livecodescript', names)

    def test_each_text_file_is_of_a_stack_here(self):
        for rel, path in self.kept:
            self.assertIn(rel, self.stacks, '%s is kept for a stack that is not in the repository: %s' % (path, HOW))

    def test_each_text_file_has_the_header_this_reads(self):
        # (a header written another way would have the script read from
        # the wrong place, and then found or not found for no reason)
        for rel, path in self.kept:
            head, script = parts(self.read(path))
            self.assertEqual(len(head), 5, path)
            self.assertTrue(head[0].startswith(b'script "'), path)
            self.assertEqual(head[1].decode('utf-8'), '-- Stack file: ' + rel.replace(os.sep, '/'), path)
            self.assertTrue(head[2].startswith(b'-- Object: '), path)
            self.assertTrue(script.strip(), '%s holds no script' % path)

    def test_each_script_kept_is_the_script_in_the_stack(self):
        stale = []
        for rel, path in self.kept:
            head, script = parts(self.read(path))
            if rel in self.stacks and script not in self.stacks[rel]:
                stale.append(os.path.relpath(path, REPO))
        self.assertEqual(stale, [], 'not the script in the stack (was the stack built again?): %s' % HOW)

    def test_a_script_that_differs_is_seen(self):
        # the comparison itself: one letter of a script changed is not in
        # the stack, and the script as kept is
        guide = os.path.join(EXAMPLES, 'Quick Start Guide.oxtstack')
        path = os.path.join(KEPT, 'Quick Start Guide.oxtstack.bst', 'scripts', 'stack_Quick_Start_Guide_group_id_1003.livecodescript')
        head, script = parts(self.read(path))
        self.assertIn(script, self.stacks[guide])
        self.assertIn(b'command frameLook', script)
        self.assertNotIn(script.replace(b'command frameLook', b'command frameLooks', 1), self.stacks[guide])


if __name__ == '__main__':
    unittest.main()
