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

"""The "Install build tools" steps of the container builds: a failed
apt-get install runs again after a fresh apt-get update and a wait, three
passes in all. Acquire::Retries does not retry a 404, which a mirror in
the middle of a sync gives (security.ubuntu.com's perl, 10 Nov 2026, #383
and #449). The steps' own loop is run here with a fake apt-get and sleep.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
WORKFLOWS = os.path.join(HERE, '..', '..', '..', '.github', 'workflows')
FILES = ('web.yml', 'web-ide.yml', 'build-linux.yml', 'android-engine.yml')

# apt-get that fails "install" the number of times in $FAILS, counting in
# $STATE, and logs every call
FAKE_APT = '''#!/bin/bash
echo "$*" >> "$STATE/calls"
case " $* " in
  *" install "*)
    n=$(cat "$STATE/installs" 2>/dev/null || echo 0)
    echo $((n + 1)) > "$STATE/installs"
    if [ "$n" -lt "$FAILS" ]; then exit 100; fi ;;
esac
exit 0
'''


def loop(name):
    """The retry loop of the workflow's Install build tools step, as bash."""
    with open(os.path.join(WORKFLOWS, name), encoding='utf-8') as f:
        text = f.read()
    m = re.search(r'^( +)for pass in 1 2 3; do\n.*?^\1done\n', text, re.M | re.S)
    if not m:
        return None
    return '\n'.join(line[len(m.group(1)):] for line in m.group(0).splitlines()) + '\n'


class AptRetry(unittest.TestCase):
    def run_loop(self, name, fails, cache_hit):
        state = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, state)
        bin_dir = os.path.join(state, 'bin')
        os.makedirs(bin_dir)
        for tool, body in (('apt-get', FAKE_APT), ('sleep', '#!/bin/bash\necho "$1" >> "$STATE/sleeps"\n')):
            path = os.path.join(bin_dir, tool)
            with open(path, 'w') as f:
                f.write(body)
            os.chmod(path, 0o755)
        env = dict(os.environ, PATH=bin_dir + os.pathsep + os.environ['PATH'], STATE=state,
                   FAILS=str(fails), CACHE_HIT=cache_hit, BUILD_PKGS='gcc make')
        p = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', loop(name)], env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

        def read(what):
            try:
                with open(os.path.join(state, what)) as f:
                    return f.read().split('\n')[:-1]
            except OSError:
                return []
        return p.returncode, read('calls'), read('sleeps')

    def test_every_install_step_has_the_loop(self):
        for name in FILES:
            self.assertIsNotNone(loop(name), name)

    def test_a_first_pass_that_fails_runs_again_after_an_update(self):
        for name in FILES:
            status, calls, sleeps = self.run_loop(name, 1, 'true')
            self.assertEqual(status, 0, name)
            # on a cache hit the first pass does not update; the second does
            self.assertEqual([c.split()[2] for c in calls], ['install', 'update', 'install'], name)
            self.assertEqual(sleeps, ['30'], name)

    def test_without_the_cache_each_pass_updates_first(self):
        status, calls, sleeps = self.run_loop('web.yml', 2, '')
        self.assertEqual(status, 0)
        self.assertEqual([c.split()[2] for c in calls], ['update', 'install'] * 3)
        self.assertEqual(sleeps, ['30', '60'])

    def test_three_failures_fail_the_step(self):
        status, calls, sleeps = self.run_loop('web.yml', 3, 'true')
        self.assertNotEqual(status, 0)
        self.assertEqual(len([c for c in calls if ' install ' in ' %s ' % c]), 3)

    def test_a_pass_that_works_installs_once(self):
        status, calls, sleeps = self.run_loop('build-linux.yml', 0, '')
        self.assertEqual(status, 0)
        self.assertEqual([c.split()[2] for c in calls], ['update', 'install'])
        self.assertEqual(sleeps, [])


if __name__ == '__main__':
    unittest.main()
