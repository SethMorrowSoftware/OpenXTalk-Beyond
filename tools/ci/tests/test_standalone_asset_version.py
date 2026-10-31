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

"""standalone_check.py and the version a runtime from the runtimes asset
reports. When the engine's version text changed to 9.7.1-BeyondEngine
(0.2.7-rc.6.12), the Windows x86-32 runtime of the pinned asset, built
before the change, still reported 9.7.1-OXT, and the check failed the
Windows build: a build the "Runtimes asset" workflow needs green before it
makes the asset that would carry the new text. Now such a runtime may report
the version the asset's PROVENANCE file in the layout records for it, which
is reported, not failed; any other version still fails, the layout's own
runtime must still report the engine's, and without the PROVENANCE file
every runtime must. "Tag a release" refuses an asset older than the version
file (runtimes_provenance.py, test_runtimes_provenance.py), so no release
ships one. No engine is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import standalone_check as sc  # noqa: E402

NEW, OLD = '9.7.1-BeyondEngine', '9.7.1-OXT'

# The lines make_runtimes_asset.py wrote in oxt-runtimes-0.2.7-rc.6.11's
# PROVENANCE.md (builds_provenance), as packages install it
PROVENANCE = """# oxt-runtimes-0.2.7-rc.6.11

- Engine version `9.7.1-OXT` (`BUILD_SHORT_VERSION`), found in every `Standalone` engine

- `Runtime/Linux/x86-32/Standalone` (20,339,732 bytes, from `linux-x86`): version strings found in the file: `9.7.1-OXT`.
- `Runtime/Linux/x86-64/Standalone` (19,284,168 bytes, from `linux-x86_64`): version strings found in the file: `9.4.0`, `9.7.1-OXT`.
- `Runtime/Windows/x86-32/Standalone` (14,180,864 bytes, from `win-x86`): version strings found in the file: `9.7.1-OXT`.
- `Runtime/Windows/x86-64/Standalone` (16,252,928 bytes, from `win-x86_64`): version strings found in the file: `9.7.1-OXT`.
"""


class CheckVersion(unittest.TestCase):
    def test_the_engines_version_passes_either_way(self):
        for own in (True, False):
            self.assertEqual(sc.check_version('win-x86', NEW, NEW, own, [OLD]), ([], []))

    def test_asset_runtime_with_its_recorded_version_is_reported(self):
        problems, lines = sc.check_version('win-x86', OLD, NEW, False, [OLD])
        self.assertEqual(problems, [])
        self.assertEqual(len(lines), 1)
        self.assertIn("reports version '9.7.1-OXT'", lines[0])
        self.assertIn("not this engine's '9.7.1-BeyondEngine'", lines[0])
        self.assertIn('reported, not failed', lines[0])

    def test_asset_runtime_with_another_version_fails(self):
        problems, lines = sc.check_version('win-x86', '9.6.3', NEW, False, [OLD])
        self.assertEqual(problems, ["win-x86: the standalone reports version '9.6.3', expected "
                                    "'9.7.1-BeyondEngine' (the runtimes asset records '9.7.1-OXT' for it)"])
        self.assertEqual(lines, [])

    def test_asset_runtime_without_a_record_fails(self):
        # what the check did for every runtime before
        problems, _ = sc.check_version('win-x86', OLD, NEW, False, [])
        self.assertEqual(problems, ["win-x86: the standalone reports version '9.7.1-OXT', expected "
                                    "'9.7.1-BeyondEngine'"])

    def test_own_runtime_must_report_the_engines_version(self):
        # even a version the asset records: the layout's own runtime is built
        # from this commit
        problems, _ = sc.check_version('win-x86_64', OLD, NEW, True, [OLD])
        self.assertEqual(problems, ["win-x86_64: the standalone reports version '9.7.1-OXT', expected "
                                    "'9.7.1-BeyondEngine'"])


class AssetVersions(unittest.TestCase):
    def setUp(self):
        self.tools = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tools, ignore_errors=True)
        self.assets = os.path.join(self.tools, 'assets.json')

    def manifest(self, ident='oxt-runtimes-0.2.7-rc.6.11', rename=True, dest=''):
        asset = {'id': ident, 'dest': dest}
        if rename:
            asset['rename'] = {'PROVENANCE.md': 'PROVENANCE-%s.md' % ident}
        with open(self.assets, 'w', encoding='utf-8') as f:
            json.dump({'assets': [{'id': 'another-asset'}, asset]}, f)

    def provenance(self, name='PROVENANCE-oxt-runtimes-0.2.7-rc.6.11.md', sub=''):
        folder = os.path.join(self.tools, sub)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, name), 'w', encoding='utf-8') as f:
            f.write(PROVENANCE)

    def test_reads_every_runtimes_line(self):
        self.manifest()
        self.provenance()
        found = sc.asset_versions(self.tools, self.assets)
        self.assertEqual(found, {
            'Runtime/Linux/x86-32/Standalone': [OLD],
            'Runtime/Linux/x86-64/Standalone': ['9.4.0', OLD],
            'Runtime/Windows/x86-32/Standalone': [OLD],
            'Runtime/Windows/x86-64/Standalone': [OLD],
        })
        # the paths are the check's own runtime paths
        for tp in ('win-x86', 'win-x86_64', 'linux-x86', 'linux-x86_64'):
            self.assertIn(sc.RUNTIMES[tp], found)

    def test_the_file_under_the_assets_dest(self):
        self.manifest(dest='Docs')
        self.provenance(sub='Docs')
        self.assertIn('Runtime/Windows/x86-32/Standalone', sc.asset_versions(self.tools, self.assets))

    def test_nothing_without_the_file(self):
        self.manifest()
        self.assertEqual(sc.asset_versions(self.tools, self.assets), {})

    def test_nothing_for_another_assets_file(self):
        # an installation that kept an older asset's PROVENANCE file
        self.manifest()
        self.provenance(name='PROVENANCE-oxt-runtimes-0.2.5-rc.2.md')
        self.assertEqual(sc.asset_versions(self.tools, self.assets), {})

    def test_nothing_without_a_rename_or_a_manifest(self):
        self.manifest(rename=False)
        self.provenance()
        self.assertEqual(sc.asset_versions(self.tools, self.assets), {})
        self.assertEqual(sc.asset_versions(self.tools, os.path.join(self.tools, 'missing.json')), {})

    def test_the_real_manifest_names_the_file(self):
        with open(sc.ASSETS, encoding='utf-8') as f:
            ident = [a for a in json.load(f)['assets'] if a['id'].startswith('oxt-runtimes-')][0]['id']
        self.provenance(name='PROVENANCE-%s.md' % ident)
        self.assertEqual(sc.asset_versions(self.tools)['Runtime/Windows/x86-32/Standalone'], [OLD])


class MainPassesTheRecord(unittest.TestCase):
    """main() hands each runtime what the asset's PROVENANCE file records
    for it (check_version disregards it for the layout's own runtime)."""

    def test_targets_all(self):
        tools = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tools, ignore_errors=True)
        for tp in ('win-x86_64', 'win-x86'):
            path = os.path.join(tools, *sc.RUNTIMES[tp].split('/'))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            open(path, 'wb').close()
        with open(sc.ASSETS, encoding='utf-8') as f:
            ident = [a for a in json.load(f)['assets'] if a['id'].startswith('oxt-runtimes-')][0]['id']
        with open(os.path.join(tools, 'PROVENANCE-%s.md' % ident), 'w', encoding='utf-8') as f:
            f.write(PROVENANCE)
        layout = mock.Mock(root=tools, engine=os.path.join(tools, 'OXT-Beyond.exe'), tools=tools)
        calls = []

        def fake_deploy(engine, runtime, tp, work, timeout, expect_version, own=True, recorded=()):
            calls.append((tp, own, list(recorded)))
            return [], []

        with mock.patch.object(sc.rlc, 'find_layout', return_value=layout), \
                mock.patch.object(sc, 'check_runtime_folder', return_value=([], [])), \
                mock.patch.object(sc, 'deploy_and_run', side_effect=fake_deploy), \
                mock.patch.object(sc, 'log'), \
                mock.patch.dict(os.environ, {'GITHUB_ACTIONS': '', 'GITHUB_STEP_SUMMARY': ''}):
            code = sc.main(['--install', tools, '--platform', 'win-x86_64', '--targets', 'all'])
        self.assertEqual(code, 0)
        self.assertEqual(calls, [('win-x86_64', True, [OLD]), ('win-x86', False, [OLD])])


if __name__ == '__main__':
    unittest.main()
