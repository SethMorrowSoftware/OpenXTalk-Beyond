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

"""tools/ci/i386-container.sh, the 32-bit Linux build's container: apt
retries each file it fails to download (deb.debian.org reset a connection
in the middle of the download twice on 2026-10-31, failing the job), and
the retries are set before the first download.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'i386-container.sh')


class AptRetries(unittest.TestCase):
    def setUp(self):
        with open(SCRIPT, encoding='utf-8') as f:
            self.script = f.read()
        self.line = [l for l in self.script.splitlines() if 'Acquire::Retries' in l]

    def test_sets_retries_before_the_first_download(self):
        self.assertEqual(len(self.line), 1)
        retries = self.script.index('Acquire::Retries')
        self.assertLess(retries, self.script.index("apt-get update"))
        self.assertLess(retries, self.script.index("apt-get install"))
        self.assertIn('/etc/apt/apt.conf.d/', self.line[0])

    @unittest.skipUnless(os.name == 'posix' and shutil.which('bash'), 'the container script runs on Linux')
    def test_writes_a_line_apt_reads(self):
        # the command run_in hands to bash in the container, run here with
        # the file written to a temporary folder instead
        command = self.line[0].strip()
        self.assertTrue(command.startswith('run_in "') and command.endswith('"'))
        inner = subprocess.run(['bash', '-c', 'printf "%s" ' + command[len('run_in '):]],
                               capture_output=True, text=True, check=True).stdout
        out = os.path.join(tempfile.mkdtemp(), '80-oxt-retries')
        inner = inner.replace('/etc/apt/apt.conf.d/80-oxt-retries', out)
        subprocess.run(['bash', '-c', inner], check=True)
        with open(out, encoding='utf-8') as f:
            self.assertEqual(f.read(), 'Acquire::Retries "5";\n')
        shutil.rmtree(os.path.dirname(out))


if __name__ == '__main__':
    unittest.main()
