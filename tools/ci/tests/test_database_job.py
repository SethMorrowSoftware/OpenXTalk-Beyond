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

"""build-linux.yml's Databases job and the database tests it runs
(modernization plan MOD-06): the tests read their servers from the
environment and are skipped without one, so a job that set a different
name, or ran a filter that matched none of them, would pass having tested
nothing.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

import yaml

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'build-linux.yml')
TESTS = os.path.join(REPO, 'tests', 'lcs', 'core', 'database')
DRIVERS = ('MYSQL', 'POSTGRESQL')
SETTINGS = ('HOST', 'DATABASE', 'USER', 'PASSWORD', 'TLS')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class DatabasesJob(unittest.TestCase):
    def setUp(self):
        self.job = yaml.safe_load(read(WORKFLOW))['jobs']['databases']

    def test_sets_every_server_setting(self):
        for driver in DRIVERS:
            for name in SETTINGS:
                self.assertIn('OXT_TEST_%s_%s' % (driver, name), self.job['env'])
        self.assertEqual(self.job['env']['OXT_TEST_MYSQL_TLS'], 'true')
        self.assertEqual(self.job['env']['OXT_TEST_POSTGRESQL_TLS'], 'true')

    def test_runs_the_database_tests_of_the_x86_64_build(self):
        self.assertEqual(self.job['needs'], 'build')
        self.assertIn("built-x86_64 == 'true'", self.job['if'])
        run = [s['run'] for s in self.job['steps'] if s.get('name') == 'Database tests'][0]
        self.assertIn('run_engine_tests.py --bin linux-x86_64-bin', run)
        pattern = re.search(r"--filter '([^']+)'", run).group(1)
        for test in ('server_databases', 'db_getters'):
            self.assertRegex('lcs: core/database/%s: TestX' % test, pattern)

    def test_starts_both_servers_with_tls(self):
        run = [s['run'] for s in self.job['steps'] if s.get('name') == 'Start the database servers'][0]
        self.assertIn('mirror.gcr.io/library/mysql:8.0', run)
        self.assertIn('mirror.gcr.io/library/postgres:16', run)
        self.assertIn('-c ssl=on', run)
        # The bundled clients' authentication (see the job's comment)
        self.assertIn('--default-authentication-plugin=mysql_native_password', run)
        self.assertIn('password_encryption=md5', run)
        self.assertIn('ALTER USER', run)


class DatabaseTests(unittest.TestCase):
    def test_server_tests_read_the_settings_the_job_sets(self):
        script = read(os.path.join(TESTS, 'server_databases.livecodescript'))
        # __Env builds the names: $OXT_TEST_<driver>_<name>
        self.assertIn('do "return $OXT_TEST_" & toUpper(pDriver) & "_" & pName', script)
        for name in SETTINGS:
            self.assertIn('__Env(pDriver, "%s")' % name, script)
        for driver in ('MySQL', 'PostgreSQL'):
            for test in ('Connect', 'WrongPassword', 'TLS', 'Values', 'Binary', 'Transactions', 'Errors'):
                self.assertIn('\non Test%s%s\n' % (driver, test), script)

    def test_skipped_without_a_server(self):
        script = read(os.path.join(TESTS, 'server_databases.livecodescript'))
        self.assertIn('throw "SKIP no" && pDriver && "server: OXT_TEST_"', script)
        getters = read(os.path.join(TESTS, 'db_getters.livecodescript'))
        self.assertIn('if $OXT_TEST_MYSQL_HOST is empty then', getters)
        for name in ('HOST', 'DATABASE', 'USER', 'PASSWORD'):
            self.assertIn('$OXT_TEST_MYSQL_%s' % name, getters)


if __name__ == '__main__':
    unittest.main()
