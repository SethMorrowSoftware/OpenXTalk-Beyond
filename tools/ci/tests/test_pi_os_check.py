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

"""tools/ci/pi_os_check.sh and .github/workflows/pi-os-check.yml, the
virtual Raspberry Pi of the Linux arm64 package: the GTK 2 package each
Debian release names (the install instructions'), the Raspberry Pi
archive's apt line, the launcher message that means a library is missing
(it must be the launcher's own text, or the check could never fail), the
screenshot printed into the log, and the workflow's CPU models and
triggers.

  python3 -m unittest discover -s tools/ci/tests
"""

import base64
import os
import re
import shutil
import subprocess
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(CI))
SCRIPT = os.path.join(CI, 'pi_os_check.sh')
WORKFLOW = os.path.join(ROOT, '.github', 'workflows', 'pi-os-check.yml')
LAUNCHER = os.path.join(ROOT, 'Installer', 'linux', 'oxt-beyond')

HAVE_BASH = os.name == 'posix' and shutil.which('bash')


def call(function, *args):
    """Run one function of the script (sourced, so main does not run)."""
    # $0 is not the script, so its main does not run
    command = 'script=$1; shift; source "$script"; ' + function + ' "$@"'
    return subprocess.run(['bash', '-c', command, 'test', SCRIPT] + list(args),
                          capture_output=True, text=True)


@unittest.skipUnless(HAVE_BASH, 'the script runs on Linux')
class Functions(unittest.TestCase):
    def test_gtk_package_follows_the_time_t_rename(self):
        for release, package in [('bookworm', 'libgtk2.0-0'), ('bullseye', 'libgtk2.0-0'),
                                 ('trixie', 'libgtk2.0-0t64'), ('forky', 'libgtk2.0-0t64')]:
            result = call('gtk_package', release)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.strip(), package, release)

    def test_pi_repo_line(self):
        line = call('pi_repo_line', 'trixie').stdout.strip()
        self.assertEqual(line, 'deb [signed-by=/usr/share/keyrings/raspberrypi-archive-keyring.asc] '
                               'http://archive.raspberrypi.com/debian/ trixie main')

    def test_package_tarball_is_the_program_folders(self):
        # the package artifact holds the -binaries and -symbols tar.xz too,
        # and they sort before the program folder's (rc.6.12's first run
        # took the -binaries one)
        d = tempfile.mkdtemp()
        try:
            for name in ('OXT-Beyond-0.2.7-rc.6.12-linux-arm64-binaries.tar.xz',
                         'OXT-Beyond-0.2.7-rc.6.12-linux-arm64-symbols.tar.xz',
                         'OXT-Beyond-0.2.7-rc.6.12-linux-arm64.tar.xz', 'notes.txt'):
                open(os.path.join(d, name), 'w').close()
            found = call('package_tarball', d).stdout.strip()
            self.assertEqual(os.path.basename(found), 'OXT-Beyond-0.2.7-rc.6.12-linux-arm64.tar.xz')
            os.remove(found)
            self.assertEqual(call('package_tarball', d).stdout.strip(), '')
        finally:
            shutil.rmtree(d)

    def test_sourcing_runs_nothing(self):
        result = subprocess.run(['bash', '-c', 'source "$1"; echo sourced', 'test', SCRIPT],
                                capture_output=True, text=True)
        self.assertEqual(result.stdout, 'sourced\n')

    def test_usage_without_a_package(self):
        result = subprocess.run(['bash', SCRIPT], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('usage', result.stderr)

    def test_missing_library_message(self):
        d = tempfile.mkdtemp()
        try:
            missing = os.path.join(d, 'missing.txt')
            with open(missing, 'w') as f:
                f.write('OXT-Beyond cannot start: these libraries are missing:\n  libgtk-x11-2.0.so.0\n')
            fine = os.path.join(d, 'fine.txt')
            with open(fine, 'w') as f:
                f.write('Gtk-WARNING **: cannot open display:\n')
            self.assertEqual(call('launcher_missing_libraries', missing).returncode, 0)
            self.assertNotEqual(call('launcher_missing_libraries', fine).returncode, 0)
        finally:
            shutil.rmtree(d)

    @unittest.skipUnless(shutil.which('convert'), "needs ImageMagick's convert")
    def test_print_screenshot_round_trips(self):
        d = tempfile.mkdtemp()
        try:
            png = os.path.join(d, 'ide-end.png')
            subprocess.run(['convert', '-size', '1600x1000', 'xc:#3060a0', png], check=True)
            out = subprocess.run(['bash', SCRIPT, '--print-screenshot', png],
                                 capture_output=True, text=True, check=True).stdout.splitlines()
            self.assertTrue(out[0].startswith('----- BEGIN ide-end '))
            self.assertEqual(out[-1], '----- END ide-end -----')
            self.assertTrue(all(len(l) <= 1000 for l in out[1:-1]))
            jpeg = base64.b64decode(''.join(out[1:-1]))
            self.assertEqual(jpeg[:3], b'\xff\xd8\xff')
            size = subprocess.run(['identify', '-format', '%w', 'jpg:-'], input=jpeg,
                                  capture_output=True, check=True).stdout
            self.assertEqual(size, b'800')
        finally:
            shutil.rmtree(d)


class LauncherText(unittest.TestCase):
    def test_the_message_is_the_launchers(self):
        with open(LAUNCHER, encoding='utf-8') as f:
            launcher = f.read()
        with open(SCRIPT, encoding='utf-8') as f:
            script = f.read()
        phrase = re.search(r"grep -q '([^']+)'", script).group(1)
        self.assertIn(phrase, launcher)


class Workflow(unittest.TestCase):
    def setUp(self):
        with open(WORKFLOW, encoding='utf-8') as f:
            self.text = f.read()

    def test_the_pi_cpus(self):
        # Pi 3 and Zero 2 W, Pi 4 and 400, Pi 5
        for cpu in ('cortex-a53', 'cortex-a72', 'cortex-a76'):
            self.assertIn('cpu: ' + cpu, self.text)
        # the CPU model check: only the A76 has Armv8.1's LSE atomics
        self.assertIn('cortex-a76) want=0', self.text)
        self.assertIn('*) want=132', self.text)

    def test_the_releases(self):
        self.assertIn('release: [ bookworm, trixie ]', self.text)
        self.assertIn('runs-on: ubuntu-24.04-arm', self.text)

    def test_a_change_to_the_scripts_starts_it(self):
        for path in ('.github/workflows/pi-os-check.yml', 'tools/ci/pi_os_check.sh',
                     'tools/ci/linux_ide_start.sh'):
            self.assertIn('      - ' + path + '\n', self.text)

    def test_it_starts_on_no_push(self):
        # a check by hand and on its own pull requests, never on main's builds
        triggers = self.text.split('\non:\n', 1)[1].split('\npermissions:', 1)[0]
        self.assertNotIn('push:', triggers)
        self.assertNotIn('workflow_run:', triggers)

    def test_read_only(self):
        self.assertNotIn('write', re.findall(r'^\s+(?:contents|actions): (\w+)', self.text, re.M))


if __name__ == '__main__':
    unittest.main()
