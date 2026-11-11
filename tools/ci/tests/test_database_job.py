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
nothing. Its legs are the servers whose default logins the drivers must
manage, and each compares its results with the newest release's.

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

    def step(self, name):
        return [s['run'] for s in self.job['steps'] if s.get('name') == name][0]

    def test_runs_the_database_tests_of_the_x86_64_build(self):
        self.assertEqual(self.job['needs'], 'build')
        self.assertIn("built-x86_64 == 'true'", self.job['if'])
        run = self.step('Database tests')
        self.assertIn('run_engine_tests.py --bin linux-x86_64-bin', run)
        self.assertIn('--output database-tests-output.txt', run)
        pattern = re.search(r"--filter '([^']+)'", run).group(1)
        for test in ('server_databases', 'db_getters'):
            self.assertRegex('lcs: core/database/%s: TestX' % test, pattern)

    def test_starts_the_servers_of_each_leg_with_tls(self):
        run = self.step('Start the database servers')
        self.assertIn('"mirror.gcr.io/library/$MYSQL_IMAGE" $MYSQL_ARGS', run)
        self.assertIn('"mirror.gcr.io/library/$POSTGRES_IMAGE"', run)
        self.assertIn('-c ssl=on', run)
        self.assertIn('-c password_encryption="$POSTGRES_AUTH"', run)
        self.assertIn('ALTER USER', run)
        for name in ('MYSQL_IMAGE', 'MYSQL_ARGS', 'MYSQL_CLIENT', 'POSTGRES_IMAGE', 'POSTGRES_AUTH'):
            self.assertIn(name, self.job['env'])

    def test_every_login_is_a_servers_default_somewhere(self):
        legs = self.job['strategy']['matrix']['include']
        self.assertFalse(self.job['strategy']['fail-fast'])
        images = dict((leg['mysql_image'], leg) for leg in legs)
        # What the clients before 0.2.8 could do, and what scripts met then
        self.assertEqual(images['mysql:8.0']['mysql_args'],
                         '--default-authentication-plugin=mysql_native_password')
        # MySQL 8.4's default login, caching_sha2_password, and MariaDB's
        self.assertEqual(images['mysql:8.4']['mysql_args'], '')
        self.assertEqual(images['mariadb:11.4']['mysql_client'], 'mariadb')
        auth = dict((leg['postgres_image'], leg['postgres_auth']) for leg in legs)
        self.assertEqual(auth, {'postgres:16': 'md5', 'postgres:17': 'scram-sha-256',
                                'postgres:18': 'scram-sha-256'})
        self.assertEqual(len(set(leg['leg'] for leg in legs)), len(legs))
        upload = [s for s in self.job['steps'] if s.get('name') == 'Upload the logs'][0]
        self.assertIn('${{ matrix.leg }}', upload['with']['name'])

    def test_compares_with_the_newest_release(self):
        release = [s for s in self.job['steps'] if s.get('name') == 'Database tests of the newest release'][0]
        # the release's own failures never fail the job
        self.assertTrue(release['continue-on-error'])
        self.assertIn('|| true', release['run'])
        self.assertIn("--pattern '*-linux-x86_64-binaries.tar.xz'", release['run'])
        self.assertIn('--output release-database-tests-output.txt', release['run'])
        compare = self.step('Compare with the newest release')
        self.assertIn('compare_test_output.py release-database-tests-output.txt database-tests-output.txt',
                      compare)
        self.assertNotIn('--fail-on-difference', compare)


class DatabaseTests(unittest.TestCase):
    def test_server_tests_read_the_settings_the_job_sets(self):
        script = read(os.path.join(TESTS, 'server_databases.livecodescript'))
        # __Env builds the names: $OXT_TEST_<driver>_<name>
        self.assertIn('do "return $OXT_TEST_" & toUpper(pDriver) & "_" & pName', script)
        for name in SETTINGS:
            self.assertIn('__Env(pDriver, "%s")' % name, script)
        for driver in ('MySQL', 'PostgreSQL'):
            for test in ('Connect', 'WrongPassword', 'TLS', 'Values', 'Binary', 'Transactions', 'Errors',
                         'CharacterSet', 'NativeText', 'Types', 'NoServer', 'Server'):
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
