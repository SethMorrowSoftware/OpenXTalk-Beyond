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
"""No handler in the tree's xTalk scripts (the IDE's, the script
libraries', the tests', every tracked .livecodescript) uses a script
local or a constant declared further down its script.

A handler sees a script-level declaration only when the declaration is
above it. Below it, with explicitVariables off, the name in the handler
is a new handler local of the same name (a constant's name is its own
spelling): it compiles, and does nothing to the script local. The Mobile
Web library's extensionFinalize cleared sResponsive and sApplied that
way, which kept the stacks mwResponsive laid out across a reload of the
library (reported on the forum, 2026-11-06).

The check reads each script as the engine does for this purpose: block
comments, line comments and string literals are left out, and so is a
"local" inside a handler or inside a /** */ doc block's example. It
runs without an engine:

  python3 -m unittest discover -s tools/ci/tests
"""

import glob
import os
import re
import subprocess
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

HANDLER = re.compile(
    r"^\s*(?:private\s+)?(?:on|command|function|getprop|setprop|before|after)\s+([A-Za-z_]\w*)",
    re.IGNORECASE,
)
DECLARATION = re.compile(r"^(local|constant)\s+(.*)$", re.IGNORECASE)
WORD = re.compile(r"[A-Za-z_]\w*")


def code_lines(text):
    """The script's lines with block comments, line comments and string
    literals blanked (a string's quotes kept), line numbers unchanged."""
    out = []
    in_block = False
    for line in text.split("\n"):
        kept = []
        i = 0
        in_string = False
        while i < len(line):
            c = line[i]
            if in_block:
                if line.startswith("*/", i):
                    in_block = False
                    i += 2
                else:
                    i += 1
                continue
            if in_string:
                if c == '"':
                    in_string = False
                    kept.append(c)
                i += 1
                continue
            if c == '"':
                in_string = True
                kept.append(c)
                i += 1
                continue
            if line.startswith("/*", i):
                in_block = True
                i += 2
                continue
            if line.startswith("--", i) or line.startswith("//", i) or c == "#":
                break
            kept.append(c)
            i += 1
        out.append("".join(kept))
    return out


def late_uses(text):
    """(line, handler, name, declared at) for every use of a script local
    or constant in a handler above its declaration; lines count from 1."""
    lines = code_lines(text)
    declared = {}
    handler = None
    for number, line in enumerate(lines, 1):
        if handler is None:
            match = HANDLER.match(line)
            if match:
                handler = match.group(1)
                continue
            match = DECLARATION.match(line)
            if match:
                for part in match.group(2).split(","):
                    name = part.split("=")[0].strip()
                    if WORD.fullmatch(name):
                        declared.setdefault(name.lower(), number)
        elif re.match(r"^\s*end\s+" + re.escape(handler) + r"\b", line, re.IGNORECASE):
            handler = None
    found = []
    handler = None
    for number, line in enumerate(lines, 1):
        if handler is None:
            match = HANDLER.match(line)
            if match:
                handler = match.group(1)
            continue
        if re.match(r"^\s*end\s+" + re.escape(handler) + r"\b", line, re.IGNORECASE):
            handler = None
            continue
        for word in set(WORD.findall(line)):
            at = declared.get(word.lower())
            if at is not None and at > number:
                found.append((number, handler, word, at))
    return sorted(found)


def tracked_scripts():
    """Every .livecodescript git tracks; without git, every one under the
    tree but the build folders."""
    try:
        listed = subprocess.run(
            ["git", "ls-files", "-z", "*.livecodescript"],
            cwd=ROOT, capture_output=True, check=True,
        ).stdout.decode("utf-8").split("\0")
        paths = [os.path.join(ROOT, p) for p in listed if p]
    except (OSError, subprocess.CalledProcessError):
        paths = [
            p for p in glob.glob(os.path.join(ROOT, "**", "*.livecodescript"), recursive=True)
            if os.sep + "_build" + os.sep not in p and os.sep + ".git" + os.sep not in p
        ]
    return sorted(p for p in paths if os.path.isfile(p))


OLD_FINALIZE = """script "lib"
on extensionFinalize
   put empty into sResponsive
   put "sApplied" into tText -- sApplied
end extensionFinalize

/**
Example:
local sApplied
*/
local sResponsive, sApplied
constant kGap = 12
on resizeStack
   put kGap into sApplied
end resizeStack
"""


class ScannerTests(unittest.TestCase):
    def test_finds_the_mobile_web_finalize_bug(self):
        self.assertEqual(late_uses(OLD_FINALIZE), [(3, "extensionFinalize", "sResponsive", 11)])

    def test_strings_comments_and_doc_examples_are_not_uses_or_declarations(self):
        text = '/*\nlocal sLate\n*/\non a\n   put "sLate" into x -- sLate\nend a\n'
        self.assertEqual(late_uses(text), [])

    def test_a_handler_local_is_not_a_declaration(self):
        text = "on a\n   put 1 into tX\nend a\non b\n   local tX\nend b\n"
        self.assertEqual(late_uses(text), [])

    def test_a_late_constant_is_found(self):
        text = "on a\n   put kGap into x\nend a\nconstant kGap = 1\n"
        self.assertEqual(late_uses(text), [(2, "a", "kGap", 4)])


class TreeTests(unittest.TestCase):
    def test_scripts_are_found(self):
        names = [os.path.relpath(p, ROOT).replace(os.sep, "/") for p in tracked_scripts()]
        self.assertIn("extensions/script-libraries/mobileweb/mobileweb.livecodescript", names)
        self.assertGreater(len(names), 1000)

    def test_no_handler_uses_a_declaration_below_it(self):
        problems = []
        for path in tracked_scripts():
            with open(path, encoding="utf-8", errors="replace") as handle:
                text = handle.read()
            for number, handler, name, at in late_uses(text):
                problems.append(
                    "%s:%d: %s uses %s, declared below it at line %d"
                    % (os.path.relpath(path, ROOT), number, handler, name, at)
                )
        self.assertEqual(problems, [], "\n".join(problems))


if __name__ == "__main__":
    unittest.main()
