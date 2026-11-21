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
"""The web workers check (tools/ci/web_workers_check.py) held to the
pieces it works with, without a browser or an engine:

- the cases it expects are the ones its probe stack
  (web-workers-probe.livecodescript) says, but for the two the probe
  says only when something went wrong, and its measurements are the
  probe's
- the workflow runs it in every browser of the check's matrix
- the libraries it builds into the standalone are there, and the deploy
  script makes the "workers" kind with them
- in the Background Workers library, the page's script and a web
  worker's call nothing of each other's that is not there: the bridge's
  functions, and the handlers each side lets JavaScript call

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
import web_workers_check as wwc  # noqa: E402

WORKER = os.path.join(REPO, 'extensions', 'script-libraries', 'worker', 'worker.livecodescript')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def handlers(script):
    """The names of the handlers a script defines"""
    return set(re.findall(r'(?m)^(?:private\s+)?(?:on|command|function)\s+([A-Za-z_][A-Za-z0-9_]*)', script))


class Probe(unittest.TestCase):

    def test_the_cases_are_the_probes(self):
        said = set(re.findall(r'(?m)^\s*say\s+"([a-z0-9-]+)"', read(wwc.PROBE_SCRIPT)))
        self.assertEqual(set(wwc.CASES) - said, set(), 'cases the probe never says')
        self.assertEqual(said - set(wwc.CASES), {'timeout', 'unknown-answer'},
                         'the probe says cases the check does not expect')

    def test_each_case_once(self):
        self.assertEqual(len(wwc.CASES), len(set(wwc.CASES)))

    def test_the_measurements_are_the_probes(self):
        measured = set(re.findall(r'(?m)^\s*info\s+"([a-z0-9-]+)"', read(wwc.PROBE_SCRIPT)))
        self.assertEqual(set(wwc.MEASURES) - measured, set())

    def test_the_probes_handlers_are_there(self):
        probe = read(wwc.PROBE_SCRIPT)
        defined = handlers(probe)
        for name in re.findall(r'send\s+"([A-Za-z_][A-Za-z0-9_]*)[^"]*"\s+to\s+me', probe):
            self.assertIn(name, defined)


class Workflow(unittest.TestCase):

    def test_every_browser(self):
        web = read(os.path.join(REPO, '.github', 'workflows', 'web.yml'))
        self.assertIn('browser: [chromium, firefox, webkit]', web)
        step = web[web.index('- name: Check the Background Workers library'):]
        step = step[:step.index('\n      - name:', 10)]
        self.assertNotIn('if:', step)
        self.assertIn('tools/ci/web_workers_check.py', step)
        self.assertIn('--browser "$BROWSER"', step)
        self.assertIn('--engine-cache', step)
        self.assertNotIn('--expect-unsupported', step)
        # after the runtime's own check, which says first whether the
        # runtime works at all
        self.assertLess(web.index('- name: Check the runtime in'), web.index('- name: Check the Background Workers library'))


class Standalone(unittest.TestCase):

    def test_the_libraries_are_there(self):
        for path in wwc.LIBRARIES:
            self.assertTrue(os.path.isfile(path), path)
            self.assertRegex(read(path).split('\n', 1)[0], r'^script "[^"]+"')

    def test_the_deploy_script_makes_the_workers_kind(self):
        deploy = read(os.path.join(CI, 'web-deploy.livecodescript'))
        self.assertIn('"workers"', deploy)
        self.assertIn('OXT_WEB_LIBRARIES', deploy)
        self.assertIn('auxiliary_stackfiles', deploy)
        self.assertIn('revInternal__LoadLibrary', deploy)


class Bridge(unittest.TestCase):

    def setUp(self):
        self.library = read(WORKER)

    def test_the_bridge_has_what_the_worker_calls(self):
        made = re.search(r'self\.oxtWorkerBridge = \{(.*?)\n\s*put "  \};"', self.library, re.S)
        self.assertIsNotNone(made, 'the library makes no oxtWorkerBridge')
        functions = set(re.findall(r'"\s+([a-z]+): function', made.group(1)))
        called = set(re.findall(r'oxtWorkerBridge\.([a-z]+)\(', self.library))
        self.assertTrue(called)
        self.assertEqual(called - functions, set())

    def test_javascript_calls_only_handlers_it_may(self):
        defined = handlers(self.library)
        allowed = set()
        for names in re.findall(r'set the cJavascriptHandlers of me to "([^"]*)"', self.library):
            allowed.update(names.split(','))
        called = set(re.findall(r'h\.(__worker[A-Za-z]+)\(', self.library))
        self.assertEqual(called, {'__workerWebEvent', '__workerWebRequest'})
        self.assertEqual(called - allowed, set())
        self.assertEqual(allowed - defined, set())


if __name__ == '__main__':
    unittest.main()
