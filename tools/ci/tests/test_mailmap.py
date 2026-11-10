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

"""The .mailmap at the root: git itself must read the placeholder identity
"x <x@x>", which the 0.2.7 version branch's commits were made with, as
Seth Morrow. Asked of git (check-mailmap), not of the file's text, so a
line git does not parse fails here too."""

import os
import shutil
import subprocess
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SETH = "Seth Morrow <140758907+SethMorrowSoftware@users.noreply.github.com>"


def mapped(identity):
    return subprocess.run(
        ["git", "-C", ROOT, "check-mailmap", identity],
        check=True, capture_output=True, text=True).stdout.strip()


@unittest.skipUnless(shutil.which("git") and
                     os.path.isdir(os.path.join(ROOT, ".git")),
                     "needs git and a checkout")
class MailmapTest(unittest.TestCase):

    def test_file_is_there(self):
        self.assertTrue(os.path.isfile(os.path.join(ROOT, ".mailmap")))

    def test_placeholder_is_seth(self):
        self.assertEqual(mapped("x <x@x>"), SETH)

    def test_other_identities_unchanged(self):
        # Only the placeholder moves: Claude's own and Seth's stay as they are.
        for who in ("Claude <noreply@anthropic.com>", SETH):
            self.assertEqual(mapped(who), who)


if __name__ == "__main__":
    unittest.main()
