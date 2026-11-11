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

"""The runtimes asset with OXT-Beyond's own Android engine beside LiveCode
9.6.3's (make_runtimes_asset.py --android-engine): the runtime folder that
android_engine.py merge made is checked before it is taken (android_engine.py
check for every architecture, nothing else in it, this tree's version in
every engine) and goes in as Runtime/Android/Beyond, where the Android
builder takes it for a stack whose "android,engine" is "beyond", the carried
runtime untouched; the archive stays reproducible; PROVENANCE.md and the
manifest entry say what was built ("android_engine"); without the option
the asset is what it was. And what reads the entry: package.py --compare
takes its files as additions, runtimes_provenance.py counts the commits for
it, and the "Runtimes asset" workflow takes it from a passing "Android
engine" run of the builds' commit, merged as that run's emulator job merged
it. No NDK, build or download is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from unittest import mock

import test_runtimes_java_layer as tj
from test_runtimes_java_layer import COMMIT, REPO, Temp, layer_classes, write_jar, workflow, steps_of  # noqa: F401
import test_android_engine as te

mra = tj.mra
ae = te.ae
package = tj.package
fetch_assets = tj.fetch_assets
runtimes_provenance = tj.runtimes_provenance

VERSION = '9.7.1-BeyondEngine'
BEYOND = 'Runtime/Android/Beyond'


def make_engine(folder, version=VERSION.encode(), skip=(), machine=None):
    """A runtime folder as android_engine.py merge writes it: every ABI's
    engine (with version in it) and externals, small ELF files that pass
    android_engine.py check, and the files beside them"""
    for abi in sorted(te.ABI_ELF):
        for name in (ae.ENGINE,) + ae.EXTERNALS:
            if '%s/%s' % (abi, name) in skip:
                continue
            kw = dict(te.ABI_ELF[abi])
            if name != ae.ENGINE:
                kw.update(project=None, exports=('getXtable',))
            elif machine and abi in machine:
                kw.update(machine=machine[abi])
            data = te.elf(**kw)
            if name == ae.ENGINE:
                data += b'\0engine ' + version + b'\0'
            te.touch(os.path.join(folder, abi, name), data)
    for name in ae.TOP_FILES:
        if name not in skip:
            te.touch(os.path.join(folder, name), te.jar() if name == 'Classes' else name.encode())
    return folder


def rels():
    out = ['%s/%s' % (abi, n) for abi in sorted(ae.ABIS) for n in (ae.ENGINE,) + ae.EXTERNALS]
    return out + list(ae.TOP_FILES)


# ---------------------------------------------------------------------------
# The folder

class EngineRuntime(Temp):
    def test_every_file_under_beyond_with_the_given_date(self):
        folder = make_engine(self.path('engine', 'x').rsplit(os.sep, 1)[0])
        infos, problems = mra.engine_runtime(folder, 1234567890, VERSION)
        self.assertEqual(problems, [])
        self.assertEqual([i['path'] for i in infos], ['%s/%s' % (BEYOND, r) for r in rels()])
        self.assertEqual(len(infos), 4 * 8 + 6)
        for i in infos:
            self.assertEqual(i['from'], mra.ENGINE_FROM)
            self.assertEqual(i['mtime'], 1234567890)
            self.assertEqual(i['source'], os.path.join(folder, *i['path'][len(BEYOND) + 1:].split('/')))
            with open(i['source'], 'rb') as f:
                data = f.read()
            self.assertEqual((i['size'], i['sha256']), (len(data), tj.sha256(data)))
            # the libraries are ELF files (0755 in the archive), the rest not
            self.assertEqual(i['elf'], '/' in i['path'][len(BEYOND) + 1:], i['path'])
            # every engine's versions, for PROVENANCE.md's list of engines
            self.assertEqual('versions' in i, i['path'].endswith('/Standalone'), i['path'])
            if 'versions' in i:
                self.assertEqual(i['versions'], [VERSION])

    def test_what_check_finds_is_a_problem(self):
        folder = make_engine(os.path.join(self.tmp, 'engine'), skip=('x86/RevZip', 'notify_icon.png'),
                             machine={'arm64-v8a': 62})
        infos, problems = mra.engine_runtime(folder, 0, VERSION)
        what = '--android-engine %s: ' % folder
        self.assertIn(what + '%s has no x86/RevZip' % folder, problems)
        self.assertIn(what + '%s has no notify_icon.png (or it is empty)' % folder, problems)
        self.assertTrue([p for p in problems if p.startswith(what) and 'arm64-v8a/Standalone is for machine 62' in p],
                        problems)
        self.assertEqual(len(infos), 4 * 8 + 6 - 2)

    def test_every_architecture(self):
        folder = make_engine(os.path.join(self.tmp, 'engine'))
        shutil.rmtree(os.path.join(folder, 'x86'))
        _, problems = mra.engine_runtime(folder, 0, VERSION)
        self.assertIn('--android-engine %s: %s has no x86 folder' % (folder, folder), problems)

    def test_nothing_else(self):
        # an artifact as a build job uploads it, with its unstripped copies:
        # not the merged runtime
        folder = make_engine(os.path.join(self.tmp, 'engine'))
        te.touch(os.path.join(folder, 'debug', 'x86', 'Standalone'), b'unstripped')
        _, problems = mra.engine_runtime(folder, 0, VERSION)
        self.assertEqual(problems, ['--android-engine %s holds files that are not the runtime\'s: '
                                    'debug/x86/Standalone' % folder])

    def test_this_trees_version(self):
        folder = make_engine(os.path.join(self.tmp, 'engine'), version=b'9.7.1-OXT')
        _, problems = mra.engine_runtime(folder, 0, VERSION)
        self.assertEqual(len(problems), 4, problems)
        self.assertIn('--android-engine %s: arm64-v8a/Standalone does not carry the engine version %s (found: '
                      '9.7.1-OXT)' % (folder, VERSION), problems)

    def test_no_such_folder(self):
        missing = os.path.join(self.tmp, 'none')
        self.assertEqual(mra.engine_runtime(missing, 0, VERSION), ([], ['--android-engine %s: no such folder'
                                                                        % missing]))

    def test_its_part_of_the_asset(self):
        self.assertEqual(mra.ENGINE_FOLDER, BEYOND)
        self.assertEqual(mra.part_of(BEYOND + '/x86/Standalone'), BEYOND)
        self.assertEqual(mra.part_of(BEYOND + '/Classes'), BEYOND)
        self.assertEqual(mra.part_of('Runtime/Android/x86/Standalone'), 'Runtime/Android')
        self.assertEqual(mra.part_of('Runtime/Android/Classes'), 'Runtime/Android')

    def test_where_the_builder_and_the_check_take_it(self):
        # the folder the builder's androidRuntimeFolder answers for
        # "beyond", and the one android_check.py overlay --beyond makes
        import android_check
        self.assertEqual(mra.ENGINE_FOLDER, 'Runtime/Android/' + android_check.BEYOND)
        with open(os.path.join(REPO, 'ide-support', 'revsaveasandroidstandalone.livecodescript'),
                  encoding='utf-8-sig') as f:
            builder = f.read()
        self.assertIn('return tRuntime & slash & "%s"' % android_check.BEYOND, builder)


# ---------------------------------------------------------------------------
# What the asset says of it

def engine_infos():
    out = []
    for r in rels():
        i = {'path': '%s/%s' % (BEYOND, r), 'size': 100, 'sha256': 'd' * 64, 'mtime': 400000000,
             'from': mra.ENGINE_FROM, 'elf': '/' in r}
        if r.endswith('/Standalone'):
            i['versions'] = [VERSION]
        out.append(i)
    return out


class Provenance(unittest.TestCase):
    def text(self, java=True, runs=None):
        return mra.builds_provenance('oxt-runtimes-x', VERSION, COMMIT, runs or {}, {},
                                     tj.infos(java) + engine_infos(), tj.REPLACED if java else None)

    def test_with_the_engine(self):
        runs = {mra.ENGINE_FROM: 'https://github.com/o/r/actions/runs/42'}
        text = self.text(runs=runs)
        self.assertIn("## OXT-Beyond's own Android engine", text)
        self.assertIn('`%s` is the Android runtime built from OXT-Beyond\'s source at the commit' % BEYOND, text)
        self.assertIn('externals for each of `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`, with the Java layer,', text)
        self.assertIn('makes the four build folders one: 38 files, 3,800 bytes, from '
                      'https://github.com/o/r/actions/runs/42.', text)
        self.assertIn('builds\nwith it only a stack whose "android,engine" standalone setting is "beyond"', text)
        self.assertIn('`android_engine.py check`', text)
        # the order the archive's reader meets them: the Java layer, the
        # engine, then what is carried
        self.assertLess(text.index("## The Android runtime's Java layer"),
                        text.index("## OXT-Beyond's own Android engine"))
        self.assertLess(text.index("## OXT-Beyond's own Android engine"), text.index('## Carried over from'))
        # 9.6.3's engines are carried, the default, bar the Java layer
        self.assertIn("LiveCode Community 9.6.3's Android engines, which stay the default, are carried\n"
                      'over: the rest of `Runtime/Android` (the engines with their externals, the\n'
                      'manifest and the rest, bar the Java layer above)', text)
        self.assertNotIn('does not build the Android engines yet', text)
        self.assertIn("- OXT-Beyond's Android engine (`%s`): GNU GPL v3, with the exception" % BEYOND, text)
        self.assertIn('LLVM libc++', text)
        self.assertIn("; the Java layer and the Android engine's files have the builds' newest.", text)
        self.assertIn('| `%s/x86/Standalone` | 100 | `%s` | 1982-09-04 15:06 | android-engine |'
                      % (BEYOND, 'd' * 64), text)
        self.assertIn('- `%s/x86_64/Standalone` (100 bytes, from `android-engine`): version strings found in the '
                      'file: `%s`.' % (BEYOND, VERSION), text)

    def test_with_the_engine_and_not_the_java_layer(self):
        text = self.text(java=False)
        self.assertNotIn("## The Android runtime's Java layer", text)
        self.assertIn('manifest and the rest, the Java layer among them) and the timezone library\'s', text)
        self.assertIn("- LiveCode Community 9.6.3's Android runtime and the timezone library's Android\n"
                      '  code: see', text)
        self.assertIn("; the Android engine's files have the builds' newest.", text)
        self.assertNotIn('from https://', text)

    def test_without_it_as_before(self):
        for java in (True, False):
            text = mra.builds_provenance('oxt-runtimes-x', VERSION, COMMIT, {}, {}, tj.infos(java),
                                         tj.REPLACED if java else None)
            self.assertNotIn(BEYOND, text)
            self.assertNotIn('own Android engine', text)
            self.assertNotIn('android-engine', text)
        # the Java layer's line, word for word
        self.assertIn("; the Java layer has the builds' newest.", mra.builds_provenance(
            'oxt-runtimes-x', VERSION, COMMIT, {}, {}, tj.infos(True), tj.REPLACED))

    def test_standalone_check_reads_only_its_own_engines(self):
        # standalone_check.py reads the engines' versions by the runtime it
        # deploys; the Android ones are listed, and in no runtime of its
        text = self.text()
        found = [tj.standalone_check.PROVENANCE_VERSIONS_RE.match(x) for x in text.splitlines()]
        paths = [m.group(1) for m in found if m]
        self.assertEqual(len(paths), 5)
        beyond = [p for p in paths if p.startswith(BEYOND + '/')]
        self.assertEqual(len(beyond), 4)
        self.assertFalse(set(beyond) & set(tj.standalone_check.RUNTIMES.values()))


class ManifestEntry(unittest.TestCase):
    def entry(self, java=True, engine=True):
        return mra.builds_manifest_entry('oxt-runtimes-x', 'x', '0' * 64, 5, COMMIT, java_layer=java,
                                         android_engine=engine)

    def test_with_the_engine(self):
        for java in (True, False):
            e = self.entry(java)
            self.assertEqual(e['android_engine'], BEYOND)
            self.assertEqual('java_layer' in e, java)
            self.assertTrue(e['description'].endswith(
                "; and OXT-Beyond's own Android engine (%s), built from the same source, beside LiveCode "
                "Community 9.6.3's, which stays the default. See PROVENANCE.md in the archive." % BEYOND),
                e['description'])
            self.assertTrue(e['source'].endswith(
                '; the Android engine %s from an Android engine run (android-engine.yml) of the same commit, its '
                'four build folders made one by tools/ci/android_engine.py merge' % BEYOND), e['source'])
            fetch_assets.validate_asset(e)

    def test_without_it_as_before(self):
        for java in (True, False):
            self.assertEqual(self.entry(java, False), mra.builds_manifest_entry(
                'oxt-runtimes-x', 'x', '0' * 64, 5, COMMIT, java_layer=java))
            self.assertNotIn('android_engine', self.entry(java, False))

    def test_the_source_still_names_one_commit(self):
        e = self.entry()
        self.assertEqual(runtimes_provenance.COMMIT_RE.findall(e['source']), [COMMIT])
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, 'assets.json')
            with open(path, 'w', encoding='utf-8') as f:
                json.dump({'assets': [e]}, f)
            self.assertEqual(runtimes_provenance.runtimes_asset(path), ('oxt-runtimes-x', COMMIT))
            self.assertEqual(runtimes_provenance.android_engine(path), BEYOND)
            self.assertEqual(runtimes_provenance.java_layer(path), 'Runtime/Android/Classes')


# ---------------------------------------------------------------------------
# The whole tool

class Builds(tj.BuildsBase):
    def engine(self):
        return make_engine(os.path.join(self.tmp, 'android-runtime'))

    def test_beside_the_carried_runtime(self):
        folder = self.engine()
        jar = write_jar(self.path('java', 'Classes'), layer_classes())
        out = os.path.dirname(self.path('out', 'x'))
        code, log = self.run_tool(out, '--android-classes', jar, '--android-engine', folder,
                                  '--run', 'android-engine=https://github.com/o/r/actions/runs/42')
        self.assertEqual(code, 0, log)
        self.assertIn("android-engine: 38 files of OXT-Beyond's Android engine, as %s" % BEYOND, log)
        self.assertIn('     38  %s' % BEYOND, log)
        m = self.members(out)
        for r in rels():
            with open(os.path.join(folder, *r.split('/')), 'rb') as f:
                data = f.read()
            got, when, mode = m['oxt-runtimes-x/%s/%s' % (BEYOND, r)]
            self.assertEqual(got, data, r)
            self.assertEqual(when, mra.utc(self.newest).timetuple()[:6], r)
            self.assertEqual(mode & 0o777, 0o755 if '/' in r else 0o644, r)
        # the carried runtime as it was, the Java layer replaced
        self.assertEqual(m['oxt-runtimes-x/Runtime/Android/Manifest.xml'][:2],
                         (b'<manifest/>', (2021, 7, 26, 12, 0, 0)))
        self.assertEqual(m['oxt-runtimes-x/Runtime/Android/arm64-v8a/Standalone'][0], b'\x7fELF arm64 engine')
        with open(jar, 'rb') as f:
            self.assertEqual(m['oxt-runtimes-x/Runtime/Android/Classes'][0], f.read())
        provenance = m['oxt-runtimes-x/PROVENANCE.md'][0].decode('utf-8')
        self.assertIn("## OXT-Beyond's own Android engine", provenance)
        self.assertIn('from https://github.com/o/r/actions/runs/42.', provenance)
        with open(os.path.join(out, 'oxt-runtimes-x.manifest.json'), encoding='utf-8') as f:
            entry = json.load(f)
        self.assertEqual(entry['android_engine'], BEYOND)
        self.assertEqual(entry['java_layer'], 'Runtime/Android/Classes')
        fetch_assets.validate_asset(entry)
        # what the packages install from it: the engine at the builder's
        # path, beside 9.6.3's
        files, _ = fetch_assets.plan_members(entry, os.path.join(out, 'oxt-runtimes-x.zip'))
        for r in ('x86_64/Standalone', 'Classes', 'arm64-v8a/RevSecurity'):
            self.assertIn(('%s/%s' % (BEYOND, r), 'oxt-runtimes-x/%s/%s' % (BEYOND, r)), files)
        self.assertIn(('Runtime/Android/arm64-v8a/Standalone', 'oxt-runtimes-x/Runtime/Android/arm64-v8a/Standalone'),
                      files)

    def test_the_archive_does_not_depend_on_when_the_engine_was_built(self):
        folder = self.engine()
        shas = []
        for n, when in enumerate((600000000, 900000000)):
            for top, _, names in os.walk(folder):
                for name in names:
                    os.utime(os.path.join(top, name), (when, when))
            out = os.path.dirname(self.path('out%d' % n, 'x'))
            code, log = self.run_tool(out, '--android-engine', folder)
            self.assertEqual(code, 0, log)
            with open(os.path.join(out, 'oxt-runtimes-x.manifest.json'), encoding='utf-8') as f:
                shas.append(json.load(f)['sha256'])
        self.assertEqual(shas[0], shas[1])

    def test_without_it_as_before(self):
        out = os.path.dirname(self.path('out', 'x'))
        code, log = self.run_tool(out)
        self.assertEqual(code, 0, log)
        self.assertNotIn('android-engine', log)
        self.assertFalse([n for n in self.members(out) if 'Beyond' in n])
        with open(os.path.join(out, 'oxt-runtimes-x.manifest.json'), encoding='utf-8') as f:
            self.assertNotIn('android_engine', json.load(f))

    def test_a_bad_engine_writes_no_archive(self):
        folder = make_engine(os.path.join(self.tmp, 'android-runtime'), skip=('x86/Standalone',))
        out = os.path.dirname(self.path('out', 'x'))
        with self.assertRaises(SystemExit) as cm:
            self.run_tool(out, '--android-engine', folder)
        self.assertIn('1 problems; no archive written', str(cm.exception))
        self.assertFalse(os.path.exists(os.path.join(out, 'oxt-runtimes-x.zip')))

    def test_its_run_and_no_other(self):
        out = os.path.dirname(self.path('out', 'x'))
        for bad in ('android-java=https://x', 'android-engine,win-x86=https://x'):
            with self.assertRaises(SystemExit) as cm:
                self.run_tool(out, '--run', bad, '--run', 'win-x86=https://y' if 'win-x86' in bad else 'linux-x86=y')
            self.assertIn('error: --run', str(cm.exception))
        # --bin takes no engine
        with self.assertRaises(SystemExit) as cm:
            self.run_tool(out, '--bin', 'android-engine=%s' % self.tmp)
        self.assertIn('android-engine is not one of win-x86, win-x86_64, linux-x86, linux-x86_64', str(cm.exception))

    def test_only_with_builds(self):
        with self.assertRaises(SystemExit) as cm, contextlib.redirect_stderr(io.StringIO()) as err:
            mra.main([self.tmp, '--out', self.tmp, '--android-engine', self.tmp])
        self.assertEqual(cm.exception.code, 2)
        self.assertIn('--android-classes and --android-engine go with --builds', err.getvalue())


# ---------------------------------------------------------------------------
# What reads the entry

class Compare(Temp):
    """package.py --compare against an OXT Lite 1.15 install, which has no
    Beyond folder: with a runtimes asset whose android_engine names it, its
    files are additions; 9.6.3's engines are still compared byte for byte"""

    def compare(self, asset, engine=b'eng'):
        items = []
        for rel, data in (('Runtime/Android/arm64-v8a/Standalone', b'eng'),
                          (BEYOND + '/arm64-v8a/Standalone', b'beyond'), (BEYOND + '/Classes', b'jar')):
            with open(self.path('stage', *rel.split('/')), 'wb') as f:
                f.write(data)
            items.append(package.Item(rel, 'asset', member='%s/%s' % (asset['id'], rel), asset=asset))
        with open(self.path('ref', 'Runtime', 'Android', 'arm64-v8a', 'Standalone'), 'wb') as f:
            f.write(engine)
        report = self.path('report.tsv')
        with contextlib.redirect_stdout(io.StringIO()):
            problems = package.compare(os.path.join(self.tmp, 'stage'), items, os.path.join(self.tmp, 'ref'), False,
                                       report=report)
        with open(report, encoding='utf-8') as f:
            rows = {}
            for r in f.read().splitlines()[1:]:
                cells = r.split('\t')
                rows[cells[1] or cells[2]] = (cells[0], cells[-1])
        return problems, rows

    def test_the_engine_built_here_is_an_addition(self):
        problems, rows = self.compare({'id': 'oxt-runtimes-x', 'strip': 1, 'android_engine': BEYOND})
        self.assertEqual(problems, 0)
        for rel in (BEYOND + '/arm64-v8a/Standalone', BEYOND + '/Classes'):
            self.assertEqual(rows[rel][0], 'intended addition')
            self.assertIn("OXT-Beyond's Android engine, built from this repository", rows[rel][1])
        self.assertEqual(rows['Runtime/Android/arm64-v8a/Standalone'][0], 'present')

    def test_not_without_the_record(self):
        problems, rows = self.compare({'id': 'oxt-runtimes-x', 'strip': 1})
        self.assertEqual(problems, 2)
        self.assertEqual(rows[BEYOND + '/Classes'][0], 'ERROR extra')

    def test_nor_from_1_15(self):
        problems, rows = self.compare({'id': 'oxt-runtimes-1.15', 'strip': 1, 'android_engine': BEYOND})
        self.assertEqual(problems, 2)

    def test_the_engines_of_9_6_3_are_still_compared(self):
        problems, rows = self.compare({'id': 'oxt-runtimes-x', 'strip': 1, 'android_engine': BEYOND},
                                      engine=b'another engine')
        self.assertEqual(problems, 1)
        self.assertEqual(rows['Runtime/Android/arm64-v8a/Standalone'][0], 'ERROR content')


class ProvenanceReport(unittest.TestCase):
    def test_the_engine_is_counted(self):
        text = runtimes_provenance.report('oxt-runtimes-x', COMMIT, [], 40, 'Runtime/Android/Classes', BEYOND)
        self.assertIn("OXT-Beyond's own Android engine in the asset (`%s`) was built from that commit too, and the "
                      'list counts for it. So was the Java layer of LiveCode Community 9.6.3\'s Android runtime '
                      'beside it (`Runtime/Android/Classes`)' % BEYOND, text)
        self.assertIn("9.6.3's Android engines (the default), is carried over from oxt-runtimes-1.15", text)
        text = runtimes_provenance.report('oxt-runtimes-x', COMMIT, [], 40, None, BEYOND)
        self.assertNotIn('So was', text)

    def test_without_it_as_before(self):
        self.assertEqual(runtimes_provenance.report('oxt-runtimes-x', COMMIT, [], 40, 'Runtime/Android/Classes'),
                         runtimes_provenance.report('oxt-runtimes-x', COMMIT, [], 40, 'Runtime/Android/Classes', None))

    def test_main_reads_the_entry(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, 'assets.json')
            entry = mra.builds_manifest_entry('oxt-runtimes-x', 'x', '0' * 64, 5, COMMIT, java_layer=True,
                                              android_engine=True)
            with open(path, 'w', encoding='utf-8') as f:
                json.dump({'assets': [entry]}, f)
            out = io.StringIO()
            with mock.patch.object(runtimes_provenance, 'commits_since', return_value=[]), \
                    contextlib.redirect_stdout(out), \
                    mock.patch.dict(os.environ, {'GITHUB_ACTIONS': '', 'GITHUB_STEP_SUMMARY': ''}):
                code = runtimes_provenance.main(['--assets', path])
        self.assertEqual(code, 0)
        self.assertIn("OXT-Beyond's own Android engine in the asset (`%s`)" % BEYOND, out.getvalue())


# A gh for the workflow's step: answers the two calls the step makes (a
# run's path, commit and branch; a job's conclusion) from the JSON file
# $FAKE_GH names, {run id: [path, commit, {job name: conclusion}]}
FAKE_GH = r"""
import json, os, re, sys
runs = json.load(open(os.environ['FAKE_GH']))
args = [a for a in sys.argv[1:] if a != '--paginate']
assert args[0] == 'api', args
m = re.match(r'repos/[^/]+/[^/]+/actions/runs/([0-9]+)(/jobs.*)?$', args[1])
if not m or m.group(1) not in runs:
    sys.exit(1)
path, sha, jobs = runs[m.group(1)]
if m.group(2):
    name = re.search(r'select\(\.name == "([^"]*)"\)', args[args.index('--jq') + 1]).group(1)
    if name in jobs:
        print(jobs[name])
else:
    print('%s\t%s\tmain' % (path, sha))
"""


class Workflow(unittest.TestCase):
    """The "Runtimes asset" workflow takes the engine only from an "Android
    engine" run of the builds' commit whose every job passed, makes its four
    folders one runtime as that run's emulator job did, and hands it to the
    archive tool with its run; without the input, as before"""

    @classmethod
    def setUpClass(cls):
        try:
            import yaml  # noqa: F401
        except ImportError:
            raise unittest.SkipTest('no PyYAML')
        cls.wf = workflow('runtimes.yml')
        cls.assemble = cls.wf['jobs']['assemble']
        cls.steps = steps_of(cls.assemble)
        cls.engine = workflow('android-engine.yml')

    def engine_jobs(self):
        """The names the engine workflow's jobs run under"""
        names = []
        for job in self.engine['jobs'].values():
            matrix = job.get('strategy', {}).get('matrix', {}).get('include')
            if matrix:
                names += [job['name'].replace('${{ matrix.arch }}', m['arch']) for m in matrix]
            else:
                names.append(job['name'])
        return names

    def test_an_optional_input(self):
        # PyYAML reads the key "on" as True
        inputs = (self.wf.get('on') or self.wf[True])['workflow_dispatch']['inputs']
        self.assertFalse(inputs['android-engine-run'].get('required'))
        self.assertEqual(inputs['android-engine-run'].get('default'), '')
        self.assertTrue(inputs['windows-run']['required'])
        self.assertEqual(self.assemble['env']['ANDROID_ENGINE_RUN'], '${{ inputs.android-engine-run }}')

    def test_the_engine_steps_only_with_a_run(self):
        names = [s.get('name') for s in self.assemble['steps']]
        for name in ('Download the Android engine', 'Make the four folders one runtime'):
            self.assertEqual(self.steps[name].get('if'), "inputs.android-engine-run != ''")
            self.assertLess(names.index("Check out the builds' commit"), names.index(name))
            self.assertLess(names.index(name), names.index('Make the archive'))
        with_ = self.steps['Download the Android engine']['with']
        self.assertEqual(with_['run-id'], '${{ inputs.android-engine-run }}')
        self.assertEqual(with_['pattern'], 'android-engine-*')
        self.assertNotIn('merge-multiple', with_)

    def test_merged_as_the_emulator_job_merges(self):
        def merge(run):
            text = re.sub(r'\\\n\s*', '', run)
            line = [x for x in text.splitlines() if 'android_engine.py merge' in x]
            self.assertEqual(len(line), 1)
            return line[0].split()[3:]
        mine = merge(self.steps['Make the four folders one runtime']['run'])
        theirs = merge(steps_of(self.engine['jobs']['device'])['Make the four folders one runtime']['run'])
        # the same four folders, in the same order, of each one's download
        self.assertEqual([x.rsplit('/', 1)[1] for x in mine[1:]], [x.rsplit('/', 1)[1] for x in theirs[1:]])
        self.assertEqual([x.rsplit('/', 1)[1].strip('"') for x in mine[1:]],
                         ['android-engine-%s' % a for a in ('arm64-v8a', 'armeabi-v7a', 'x86', 'x86_64')])
        parts = self.steps['Download the Android engine']['with']['path'].replace('${{ runner.temp }}', '$RUNNER_TEMP')
        for x in mine[1:]:
            self.assertTrue(x.strip('"').startswith('$parts/'), x)
        self.assertIn('parts="%s"' % parts, self.steps['Make the four folders one runtime']['run'])
        # and the folder it writes is the one the archive takes
        make = self.steps['Make the archive']['run']
        self.assertIn('--android-engine %s' % mine[0], make)
        self.assertIn('--run "android-engine=$runs/$ANDROID_ENGINE_RUN"', make)
        self.assertIn('"${engine[@]}"', make)

    def test_the_release_says_so(self):
        notes = steps_of(self.wf['jobs']['publish'])['Create the release and check the upload']['run']
        self.assertIn('.get("android_engine", "")', notes)
        self.assertIn("OXT-Beyond's own Android engine in $engine", notes)
        self.assertIn('rest of the Android runtime carried over from', notes)

    def check_step(self, runs, engine_run=''):
        """Runs the step that checks the runs, with a gh that answers from
        runs; (exit code, output, what it wrote to $GITHUB_OUTPUT)"""
        with tempfile.TemporaryDirectory() as d:
            bin_ = os.path.join(d, 'bin')
            os.mkdir(bin_)
            gh = os.path.join(bin_, 'gh')
            with open(gh, 'w', encoding='utf-8') as f:
                f.write('#!%s\n%s' % (sys.executable, FAKE_GH))
            os.chmod(gh, 0o755)
            with open(os.path.join(d, 'runs.json'), 'w', encoding='utf-8') as f:
                json.dump(runs, f)
            script = os.path.join(d, 'step.sh')
            with open(script, 'w', encoding='utf-8') as f:
                f.write(self.steps['Check the label and the runs']['run'])
            out = os.path.join(d, 'output')
            env = dict(os.environ, PATH=bin_ + os.pathsep + os.environ['PATH'], FAKE_GH=os.path.join(d, 'runs.json'),
                       GH_REPO='o/r', LABEL='0.2.8', WINDOWS_RUN='1', LINUX_RUN='2', ANDROID_ENGINE_RUN=engine_run,
                       GITHUB_OUTPUT=out)
            p = subprocess.run(['bash', '--noprofile', '--norc', '-eo', 'pipefail', script], env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
            written = ''
            if os.path.exists(out):
                with open(out, encoding='utf-8') as f:
                    written = f.read()
            return p.returncode, p.stdout, written

    def runs(self, engine_sha=COMMIT, engine_path='.github/workflows/android-engine.yml', failed=None):
        ok = 'success'
        engine = {name: ok for name in self.engine_jobs()}
        if failed:
            engine[failed] = 'failure'
        return {'1': ['.github/workflows/build-windows.yml', COMMIT, {'Build win-x86': ok, 'Build win-x86_64': ok}],
                '2': ['.github/workflows/build-linux.yml', COMMIT, {'Build linux-x86': ok, 'Build linux-x86_64': ok}],
                '3': [engine_path, engine_sha, engine]}

    @unittest.skipIf(shutil.which('bash') is None or os.name == 'nt', 'no bash')
    def test_the_check_step(self):
        # the asset waits for the four builds and the emulator's run of the
        # engine, not for the script tests' job (android_tests.py), whose
        # results are judged against their baselines as evidence for the
        # engine, not a gate on its asset
        self.assertEqual(len(self.engine_jobs()), 6)
        self.assertIn('Script tests on the emulator', self.engine_jobs())
        self.assertNotIn('Script tests on the emulator', self.steps['Check the label and the runs']['run'])
        code, out, written = self.check_step(self.runs())
        self.assertEqual((code, written), (0, 'commit=%s\n' % COMMIT), out)
        self.assertNotIn('run 3', out)
        code, out, written = self.check_step(self.runs(), '3')
        self.assertEqual((code, written), (0, 'commit=%s\n' % COMMIT), out)
        self.assertIn('run 3: android-engine.yml on main at %s' % COMMIT, out)
        for engine_run, runs, error in (
                ('3x', self.runs(), "android-engine-run '3x' is not a run id"),
                ('4', self.runs(), 'cannot read the run 4'),
                ('3', self.runs(engine_sha='0' * 40),
                 "the Android engine run built %s, not the builds' commit %s" % ('0' * 40, COMMIT)),
                ('3', self.runs(engine_path='.github/workflows/android.yml'),
                 'run 3 is of .github/workflows/android.yml, not of .github/workflows/android-engine.yml'),
                ('3', self.runs(failed='Android engine on the emulator'),
                 'job "Android engine on the emulator" of run 3: failure'),
                ('3', self.runs(failed='Android engine (x86)'), 'job "Android engine (x86)" of run 3: failure')):
            code, out, written = self.check_step(runs, engine_run)
            self.assertNotEqual(code, 0, engine_run)
            self.assertIn('::error::' + error, out)
            self.assertEqual(written, '')


class Docs(unittest.TestCase):
    """README.md and THIRD-PARTY-NOTICES.md say where the packages' Android
    runtimes come from, by the pinned asset: once its entry names the
    engine built here, each must say so, and not before"""

    def test_the_docs_say_whose_android_engines_the_packages_ship(self):
        engine = runtimes_provenance.android_engine(runtimes_provenance.ASSETS)
        for name in ('README.md', 'THIRD-PARTY-NOTICES.md'):
            with open(os.path.join(REPO, name), encoding='utf-8') as f:
                text = f.read()
            if engine:
                self.assertIn(engine, text, '%s: the pinned runtimes asset carries OXT-Beyond\'s own Android engine '
                              '(%s); say so where the file says the Android runtime is prebuilt' % (name, engine))
            else:
                self.assertNotIn(BEYOND, text, '%s: the pinned runtimes asset has no Android engine built here'
                                 % name)
