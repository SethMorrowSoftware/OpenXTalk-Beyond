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

"""The time limits of .github/workflows/ci-checks.yml leave room for the
unit tests it runs, and its actionlint comes through GitHub's API.

In November 2026 tools/ci/tests took 584 s on the Linux job, whose limit
was 10 minutes: run 42451358354 printed "Ran 1716 tests ... OK" and was
cancelled before its next step. macos-15 took 14 of its 15 minutes. A
cancelled run reads as a failure on every pull request, so each limit is
about twice what the job takes.

On 9 November 2026 the release's web address (github.com/rhysd/actionlint/
releases/download/...) answered "504 Gateway Time-out" to all four of
curl's tries in three jobs, which ended each before any check ran, while gh
downloaded releases on other runners. So gh downloads it, through the API,
and the web address is tried only when gh fails; the SHA-256 is checked
whichever brought it.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'ci-checks.yml')


def jobs():
    import yaml
    with open(WORKFLOW, encoding='utf-8') as f:
        return yaml.safe_load(f)['jobs']


class TimeLimits(unittest.TestCase):

    def test_every_job_runs_the_unit_tests(self):
        # The limits below are for jobs that run the whole suite
        for name, job in jobs().items():
            runs = ' '.join(str(s.get('run', '')) for s in job['steps'])
            self.assertIn('unittest discover -s tools/ci/tests', runs, name)

    def test_linux_has_twice_what_the_tests_took(self):
        self.assertGreaterEqual(jobs()['checks']['timeout-minutes'], 20)

    def test_windows_and_macos_have_twice_what_macos_took(self):
        other = jobs()['other-os']
        self.assertEqual(other['strategy']['matrix']['os'], ['windows-latest', 'macos-15'])
        self.assertGreaterEqual(other['timeout-minutes'], 30)

    def test_no_step_has_a_shorter_limit_of_its_own(self):
        for name, job in jobs().items():
            for step in job['steps']:
                self.assertNotIn('timeout-minutes', step, (name, step.get('name')))


def actionlint_step():
    steps = [s for s in jobs()['checks']['steps'] if 'actionlint' in str(s.get('name', ''))]
    assert len(steps) == 1, steps
    return steps[0]


def commands(script):
    """The shell commands of a step's run, as the shell reads them: a line
    ending in a backslash, or in "||", "&&" or "|", goes on in the next."""
    out, part = [], ''
    for line in script.splitlines():
        line = line.strip()
        if line.endswith('\\'):
            part += line[:-1].strip() + ' '
            continue
        if line.endswith(('||', '&&', '|')):
            part += line + ' '
            continue
        part += line
        if part:
            out.append(part)
        part = ''
    if part:
        out.append(part)
    return out


class ActionlintDownload(unittest.TestCase):

    ARCHIVE = '"$RUNNER_TEMP/$archive"'

    def command(self, word):
        found = [i for i, c in enumerate(commands(actionlint_step()['run'])) if word in c]
        self.assertEqual(len(found), 1, (word, found))
        return found[0], commands(actionlint_step()['run'])[found[0]]

    def test_gh_downloads_it_through_the_api(self):
        _, gh = self.command('gh release download')
        self.assertIn('"v$ACTIONLINT_VERSION"', gh)
        self.assertIn('--repo rhysd/actionlint', gh)
        self.assertIn('--pattern "$archive"', gh)
        self.assertIn('--dir "$RUNNER_TEMP"', gh)
        # a file of that name already there (a try cut short) is replaced
        self.assertIn('--clobber', gh)

    def test_gh_has_the_jobs_token(self):
        self.assertEqual(actionlint_step()['env'].get('GH_TOKEN'), '${{ github.token }}')

    def test_the_web_address_only_when_gh_fails(self):
        at, gh = self.command('gh release download')
        curl_at, curl = self.command('curl ')
        # one command: gh's download, or else curl's
        self.assertEqual(curl_at, at, 'curl must follow gh after "||", not run as a command of its own')
        self.assertLess(gh.index('gh release download'), gh.index('||'))
        self.assertLess(gh.index('||'), gh.index('curl '))
        # -f: an error page is an error, not the archive
        flags = curl.split('curl ', 1)[1].split()[0]
        self.assertTrue(flags.startswith('-') and 'f' in flags, flags)
        self.assertIn('--retry', curl)
        self.assertIn('-o %s' % self.ARCHIVE, curl)
        self.assertIn('https://github.com/rhysd/actionlint/releases/download/v$ACTIONLINT_VERSION/$archive', curl)

    def test_the_sha256_is_checked_whichever_brought_it(self):
        lines = commands(actionlint_step()['run'])
        at, _ = self.command('gh release download')
        check_at, check = self.command('sha256sum -c')
        self.assertGreater(check_at, at)
        self.assertIn('"$ACTIONLINT_SHA256  %s"' % self.ARCHIVE.strip('"'), check)
        # and before anything runs the archive's actionlint
        unpack_at, _ = self.command('tar -xzf')
        self.assertLess(check_at, unpack_at)
        runs = [i for i, c in enumerate(lines) if c.startswith('"$RUNNER_TEMP/actionlint"')]
        self.assertTrue(runs)
        self.assertGreater(min(runs), check_at)

    def test_the_token_reads_and_writes_nothing_else(self):
        import yaml
        with open(WORKFLOW, encoding='utf-8') as f:
            self.assertEqual(yaml.safe_load(f)['permissions'], {'contents': 'read'})


if __name__ == '__main__':
    unittest.main()
