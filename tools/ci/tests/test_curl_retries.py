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

"""Every download with curl in CI tries again after any error, a reset
connection too. curl's --retry tries again after a timeout and an HTTP
408, 429, 500, 502, 503 or 504, and not after a connection that the other
end resets (curl's error 56, "Recv failure: Connection reset by peer"),
which failed the docs job of a pull request on 20 Nov 2026 (the download
of the engine that tools/ci/build_docs.sh pins, from GitHub's releases).
--retry-all-errors (curl 7.71 and newer: ubuntu-24.04's is 8.5, Debian
bookworm's 7.88) tries again after that too. A request to the job's own
server (localhost) is a check, which must fail at once, and is left as it
is.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))

# curl as a command (at the start of a line, or after a pipe, ||, && or
# a parenthesis): not the curl of a list of packages
CURL = re.compile(r'(?:^|[|&;(]\s*|\bif\s+|\|\|\s*)curl\s+-')


def ci_files():
    """The workflows, the composite actions and the shell scripts of
    tools/ci."""
    found = []
    workflows = os.path.join(REPO, '.github', 'workflows')
    found += [os.path.join(workflows, n) for n in sorted(os.listdir(workflows)) if n.endswith('.yml')]
    actions = os.path.join(REPO, '.github', 'actions')
    for name in sorted(os.listdir(actions)):
        path = os.path.join(actions, name, 'action.yml')
        if os.path.isfile(path):
            found.append(path)
    ci = os.path.join(REPO, 'tools', 'ci')
    found += [os.path.join(ci, n) for n in sorted(os.listdir(ci)) if n.endswith('.sh')]
    return found


def curl_commands():
    """(file, line number, the command with its continuation lines) of
    every curl command in them, comment lines left out."""
    found = []
    for path in ci_files():
        with open(path, encoding='utf-8') as f:
            lines = f.read().split('\n')
        for i, line in enumerate(lines):
            if line.lstrip().startswith('#') or not CURL.search(line.strip()):
                continue
            command = line.strip()
            j = i
            while command.endswith('\\') and j + 1 < len(lines):
                j += 1
                command = command[:-1] + ' ' + lines[j].strip()
            found.append((os.path.relpath(path, REPO).replace(os.sep, '/'), i + 1,
                          command[CURL.search(command).start():]))
    return found


def downloads():
    """The curl commands that fetch from another machine."""
    return [(path, n, c) for path, n, c in curl_commands() if 'localhost' not in c]


class CurlRetries(unittest.TestCase):

    def test_the_downloads_are_found(self):
        paths = {path for path, _, _ in downloads()}
        self.assertIn('tools/ci/build_docs.sh', paths)
        self.assertIn('tools/ci/pi_os_check.sh', paths)
        self.assertIn('.github/workflows/ci-checks.yml', paths)
        self.assertIn('.github/workflows/plugin-packages.yml', paths)
        self.assertGreaterEqual(len(downloads()), 7)
        # and the checks of the job's own server are not among them
        self.assertTrue(any('localhost' in c for _, _, c in curl_commands()))

    def test_every_download_tries_again(self):
        for path, n, command in downloads():
            self.assertRegex(command, r'--retry \d', '%s:%d: %s' % (path, n, command))

    def test_every_download_tries_again_after_a_reset_connection(self):
        for path, n, command in downloads():
            self.assertIn('--retry-all-errors', command, '%s:%d: %s' % (path, n, command))

    def test_every_download_goes_into_a_file(self):
        # (curl starts an -o file again for a try after a partial one; a
        # pipe or a > keeps what the failed try sent, and gets the whole
        # again after it: the Raspberry Pi archive's key went through a
        # pipe to gpg --dearmor, which refuses that; #599's review)
        for path, n, command in downloads():
            self.assertRegex(command, r'\s-o\s', '%s:%d: %s' % (path, n, command))
            self.assertIsNone(re.search(r'(?<![|])[|>](?![|])', command), '%s:%d: %s' % (path, n, command))

    def test_an_error_page_is_an_error(self):
        # (-f: an HTTP error is curl's error, not a file of its page, so it
        # is tried again and then fails the step)
        for path, n, command in downloads():
            flags = command.split()[1]
            self.assertTrue(flags.startswith('-') and not flags.startswith('--') and 'f' in flags,
                            '%s:%d: %s' % (path, n, command))


if __name__ == '__main__':
    unittest.main()
