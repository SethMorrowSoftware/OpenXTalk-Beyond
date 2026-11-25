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

"""The Windows builds get Python 2.7 from tools/ci/install-python27.ps1,
which takes the Python Software Foundation's python2 package from
nuget.org, pinned by SHA-256, and falls back to Chocolatey. On 25 Nov 2026
Chocolatey's community feed answered 503 and 504 for an hour, and every
Windows build on main failed at "Install Python 2.7", because Chocolatey
was its only source.

Set OXT_CHECK_PYTHON27_PIN=1 to also download the package and check the
pin against it.

  python3 -m unittest discover -s tools/ci/tests
"""

import hashlib
import os
import re
import unittest
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
SCRIPT = os.path.join(REPO, 'tools', 'ci', 'install-python27.ps1')
WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'build-windows.yml')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def script_value(name):
    m = re.search(r"^\$%s = '([^']*)'$" % re.escape(name), read(SCRIPT), re.M)
    return m.group(1) if m else None


def python_steps():
    """The body of every "Install Python 2.7" step of build-windows.yml,
    up to the next step."""
    text = read(WORKFLOW)
    steps = []
    for m in re.finditer(r'^(\s*)- name: Install Python 2\.7\n', text, re.M):
        indent = m.group(1)
        end = re.compile(r'^%s- name: ' % re.escape(indent), re.M).search(text, m.end())
        steps.append(text[m.end():end.start() if end else len(text)])
    return steps


class Python27Install(unittest.TestCase):

    def test_every_windows_build_uses_the_script(self):
        steps = python_steps()
        # the x86_64 build and the x86 build
        self.assertEqual(len(steps), 2, 'expected two "Install Python 2.7" steps')
        for body in steps:
            self.assertIn('run: ./tools/ci/install-python27.ps1', body)
            self.assertNotIn('choco install', body, 'Chocolatey is the fallback inside the script, not a second path')

    def test_no_other_place_installs_python2_with_chocolatey(self):
        self.assertNotIn('choco install python2', read(WORKFLOW))

    def test_package_is_the_psf_python2_2_7_18_from_nuget(self):
        url = script_value('NuGetUrl')
        self.assertEqual(url, 'https://api.nuget.org/v3-flatcontainer/python2/2.7.18/python2.2.7.18.nupkg')

    def test_package_is_pinned(self):
        sha = script_value('NuGetSha256')
        self.assertIsNotNone(sha)
        self.assertRegex(sha, r'^[0-9a-f]{64}$')
        text = read(SCRIPT)
        self.assertIn('Get-FileHash -Algorithm SHA256', text)
        self.assertRegex(text, r'if \(\$sha -ne \$NuGetSha256\) \{ throw ')

    def test_download_retries_after_any_error(self):
        line = next(l for l in read(SCRIPT).splitlines() if 'curl.exe' in l and '$NuGetUrl' in l)
        words = line.split()
        # -f: an HTTP error is a failure, not a saved error page
        self.assertTrue(any(re.match(r'^-[a-zA-Z]*f', w) for w in words), line)
        for flag in ('--retry', '--retry-all-errors'):
            self.assertIn(flag, words)

    def test_falls_back_to_chocolatey(self):
        text = read(SCRIPT)
        self.assertIn('choco install python2 -y --no-progress', text)
        # NuGet first, then Chocolatey
        self.assertLess(text.index('\n    Install-FromNuGet\n'), text.index('\n    Install-FromChocolatey\n'))

    def test_the_interpreter_must_answer_2_7(self):
        text = read(SCRIPT)
        self.assertIn("StartsWith('2.7')", text)
        self.assertIn("$Target = 'C:\\Python27'", text)
        # the build looks for it there
        self.assertIn("'C:\\Python27\\python.exe'", read(os.path.join(REPO, 'tools', 'ci', 'build-windows.ps1')))

    def test_script_is_ascii(self):
        read(SCRIPT).encode('ascii')

    @unittest.skipUnless(os.environ.get('OXT_CHECK_PYTHON27_PIN') == '1', 'set OXT_CHECK_PYTHON27_PIN=1 to download the package')
    def test_pin_matches_the_package(self):
        with urllib.request.urlopen(script_value('NuGetUrl'), timeout=120) as r:
            data = r.read()
        self.assertEqual(hashlib.sha256(data).hexdigest(), script_value('NuGetSha256'))


if __name__ == '__main__':
    unittest.main()
