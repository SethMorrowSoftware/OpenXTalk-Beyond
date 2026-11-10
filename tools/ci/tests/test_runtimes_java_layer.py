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

"""The runtimes asset with the Android Java layer built from this repository
(make_runtimes_asset.py --android-classes): the jar is checked before it is
taken (only class files, the classes the engines and the builder name,
every PendingIntent saying its mutability) and replaces the carried
Runtime/Android/Classes, and nothing else of the carried Android runtime;
the archive stays reproducible; PROVENANCE.md and the manifest entry say
what was built and what is still carried ("java_layer"); without the
option the asset is what it was. And what reads the entry: package.py
--compare lets that one file differ from 1.15's, runtimes_provenance.py
counts the commits for it, and the "Runtimes asset" workflow builds and
checks the jar as android-java.yml checks a pull request's before it
passes it; README.md and THIRD-PARTY-NOTICES.md say whose Java layer the
pinned asset ships. No JDK, SDK, build or download is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import hashlib
import io
import json
import os
import re
import shutil
import sys
import tempfile
import unittest
import zipfile
from unittest import mock

TESTS = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(TESTS)
REPO = os.path.dirname(os.path.dirname(CI))
OXT = os.path.join(REPO, 'tools', 'oxt')
for p in (TESTS, CI, OXT):
    if p not in sys.path:
        sys.path.insert(0, p)

import android_java as aj  # noqa: E402
import fetch_assets  # noqa: E402
import make_runtimes_asset as mra  # noqa: E402
import package  # noqa: E402
import runtimes_provenance  # noqa: E402
import standalone_check  # noqa: E402
from test_android_java import ClassWriter, ICONST_0, INVOKESTATIC, ARETURN  # noqa: E402

WORKFLOWS = os.path.join(REPO, '.github', 'workflows')
GET = ('ref', 'method', 'android/app/PendingIntent', 'getBroadcast',
       '(Landroid/content/Context;ILandroid/content/Intent;I)Landroid/app/PendingIntent;')
FLAGS = ('ref', 'method', 'com/runrev/android/Utils', 'immutablePendingIntentFlags', '(I)I')


def layer_classes(flags_right=True, leave_out=()):
    """ClassWriters for the classes a Java layer must hold, one of which
    makes a PendingIntent (with Utils's flags, or with a bare 0)."""
    out = []
    for name in mra.JAVA_CLASSES:
        if name in leave_out:
            continue
        w = ClassWriter(name)
        if name.endswith('/Engine'):
            code = [ICONST_0, INVOKESTATIC, FLAGS] if flags_right else [ICONST_0]
            w.method('alarm', '()Landroid/app/PendingIntent;', code=code + [INVOKESTATIC, GET, ARETURN])
        out.append(w)
    return out


def write_jar(path, writers, extra=(), manifest=True):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        if manifest:
            z.writestr('META-INF/MANIFEST.MF', 'Manifest-Version: 1.0\r\n\r\n')
        for w in writers:
            z.writestr(w.name + '.class', w.bytes())
        for name, data in extra:
            z.writestr(name, data)
    return path


def sha256(data):
    return hashlib.sha256(data).hexdigest()


class Temp(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def path(self, *parts):
        p = os.path.join(self.tmp, *parts)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        return p


# ---------------------------------------------------------------------------
# The jar

class JavaLayer(Temp):
    def test_a_java_layer_is_taken_with_the_given_date(self):
        jar = write_jar(self.path('Classes'), layer_classes())
        info, problems = mra.java_layer(jar, 1234567890)
        self.assertEqual(problems, [])
        with open(jar, 'rb') as f:
            data = f.read()
        self.assertEqual(info['path'], 'Runtime/Android/Classes')
        self.assertEqual(info['from'], mra.JAVA_FROM)
        self.assertEqual(info['source'], jar)
        self.assertEqual((info['size'], info['sha256']), (len(data), sha256(data)))
        self.assertEqual(info['mtime'], 1234567890)
        self.assertEqual(info['classes'], len(mra.JAVA_CLASSES))
        self.assertEqual(info['majors'], [52])
        self.assertFalse(info['elf'])

    def test_each_named_class_is_needed(self):
        for name in mra.JAVA_CLASSES:
            jar = write_jar(self.path(name.rsplit('/', 1)[-1], 'Classes'), layer_classes(leave_out=(name,)))
            _, problems = mra.java_layer(jar, 0)
            self.assertEqual(len(problems), 1, problems)
            self.assertIn('lacks %s, so it is not the Java layer' % name, problems[0])

    def test_only_class_files(self):
        jar = write_jar(self.path('Classes'), layer_classes(), extra=[('res/raw/x.png', b'png')])
        _, problems = mra.java_layer(jar, 0)
        self.assertEqual(problems, ['--android-classes %s holds files that are not class files: res/raw/x.png'
                                    % jar])

    def test_a_pending_intent_without_its_mutability(self):
        jar = write_jar(self.path('Classes'), layer_classes(flags_right=False))
        _, problems = mra.java_layer(jar, 0)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('com/runrev/android/Engine.alarm', problems[0])
        self.assertIn('makes a PendingIntent (getBroadcast)', problems[0])

    def test_not_a_jar_of_class_files(self):
        def text(path):
            with open(path, 'w') as f:
                f.write('not a jar')
        for name, write in (('text', text),
                            ('badclass', lambda p: write_jar(p, layer_classes(), extra=[('x/Y.class', b'nope')]))):
            jar = self.path(name, 'Classes')
            write(jar)
            info, problems = mra.java_layer(jar, 0)
            self.assertIsNone(info)
            self.assertEqual(len(problems), 1, problems)
            self.assertIn('is not a jar of class files', problems[0])

    def test_no_such_file(self):
        info, problems = mra.java_layer(self.path('nothing'), 0)
        self.assertIsNone(info)
        self.assertEqual(problems, ['--android-classes %s: no such file' % self.path('nothing')])

    def test_the_classes_it_needs_are_the_ones_named(self):
        # Engine is the class of the engines' JNI functions (android_java's
        # ENGINE_CLASS); the others are what the builder's generated Java
        # extends; and each is built from a source of engine/src/java
        self.assertEqual(mra.JAVA_CLASSES[0], aj.ENGINE_CLASS)
        with open(os.path.join(REPO, 'ide-support', 'revsaveasandroidstandalone.livecodescript'),
                  encoding='utf-8') as f:
            builder = f.read()
        for name in mra.JAVA_CLASSES[1:]:
            self.assertIn('extends %s' % name.rsplit('/', 1)[-1], builder, name)
            self.assertIn('import %s;' % name.replace('/', '.'), builder, name)
        for name in mra.JAVA_CLASSES:
            self.assertTrue(os.path.isfile(os.path.join(REPO, 'engine', 'src', 'java', name + '.java')), name)


class ReplaceJavaLayer(Temp):
    def carried(self, with_classes=True):
        out = [{'path': 'Runtime/Android/Manifest.xml', 'from': mra.CARRY_ASSET['id']},
               {'path': 'Runtime/Android/arm64-v8a/Standalone', 'from': mra.CARRY_ASSET['id']}]
        if with_classes:
            out.insert(0, {'path': 'Runtime/Android/Classes', 'from': mra.CARRY_ASSET['id'], 'sha256': 'c' * 64})
        return out

    def test_the_carried_layer_alone_is_replaced(self):
        jar = write_jar(self.path('Classes'), layer_classes())
        carried, new, old, problems = mra.replace_java_layer(self.carried(), jar, 99)
        self.assertEqual(problems, [])
        self.assertEqual([i['path'] for i in carried],
                         ['Runtime/Android/Manifest.xml', 'Runtime/Android/arm64-v8a/Standalone'])
        self.assertEqual(old['sha256'], 'c' * 64)
        self.assertEqual((new['path'], new['mtime']), ('Runtime/Android/Classes', 99))

    def test_nothing_to_replace(self):
        jar = write_jar(self.path('Classes'), layer_classes())
        carried, new, old, problems = mra.replace_java_layer(self.carried(False), jar, 0)
        self.assertIsNone(old)
        self.assertEqual(problems, ['oxt-runtimes-1.15 has no Runtime/Android/Classes for --android-classes to '
                                    'replace'])

    def test_a_bad_jar_is_a_problem(self):
        jar = write_jar(self.path('Classes'), layer_classes(leave_out=('com/runrev/android/Engine',)))
        _, new, _, problems = mra.replace_java_layer(self.carried(), jar, 0)
        self.assertEqual(len(problems), 1)


# ---------------------------------------------------------------------------
# What the asset says of it

def infos(java=True):
    out = [{'path': 'Runtime/Windows/x86-32/Standalone', 'size': 10, 'sha256': 'a' * 64, 'mtime': 400000000,
            'from': 'win-x86', 'versions': ['9.7.1-BeyondEngine']},
           {'path': 'Runtime/Android/arm64-v8a/Standalone', 'size': 7, 'sha256': 'e' * 64, 'mtime': 300000000,
            'from': mra.CARRY_ASSET['id']}]
    if java:
        out.append({'path': 'Runtime/Android/Classes', 'size': 1234, 'sha256': 'b' * 64, 'mtime': 400000000,
                    'from': mra.JAVA_FROM, 'classes': 321, 'majors': [52]})
    else:
        out.append({'path': 'Runtime/Android/Classes', 'size': 999, 'sha256': 'c' * 64, 'mtime': 300000000,
                    'from': mra.CARRY_ASSET['id']})
    return out


REPLACED = {'path': 'Runtime/Android/Classes', 'size': 999, 'sha256': 'c' * 64}
COMMIT = '7f500a3102507156be0b7abdcc9505df4185d3bc'


class Provenance(unittest.TestCase):
    def test_with_the_java_layer(self):
        text = mra.builds_provenance('oxt-runtimes-x', '9.7.1-BeyondEngine', COMMIT, {}, {}, infos(), REPLACED)
        self.assertIn("## The Android runtime's Java layer", text)
        self.assertIn('321 classes (class file version 52), 1,234 bytes, SHA-256 `%s`.' % ('b' * 64), text)
        self.assertIn("(LiveCode Community 9.6.3's, 999 bytes, SHA-256 `%s`)." % ('c' * 64), text)
        self.assertIn('`tools/ci/android_java.py build`', text)
        self.assertIn('`android_java.py compare`, `jni` and `rules`', text)
        self.assertIn('OXT-Beyond does not build the Android engines yet. The rest of `Runtime/Android`', text)
        self.assertNotIn('does not build the Android runtime yet', text)
        self.assertIn("- The Android runtime's Java layer (`Runtime/Android/Classes`): GNU GPL v3", text)
        self.assertIn('| `Runtime/Android/Classes` | 1234 | `%s` | 1982-09-04 15:06 | android-java |' % ('b' * 64), text)
        self.assertIn("; the Java layer has the builds' newest.", text)
        # the java section comes before the carried one, in the order the
        # archive's reader meets them
        self.assertLess(text.index("## The Android runtime's Java layer"), text.index('## Carried over from'))

    def test_the_engines_lines_still_read(self):
        # standalone_check.py reads each Standalone's versions from these
        # lines of the installed PROVENANCE file
        text = mra.builds_provenance('oxt-runtimes-x', '9.7.1-BeyondEngine', COMMIT, {}, {}, infos(), REPLACED)
        found = [standalone_check.PROVENANCE_VERSIONS_RE.match(x) for x in text.splitlines()]
        self.assertEqual([(m.group(1), m.group(2)) for m in found if m],
                         [('Runtime/Windows/x86-32/Standalone', '`9.7.1-BeyondEngine`.')])

    def test_without_it(self):
        text = mra.builds_provenance('oxt-runtimes-x', '9.7.1-BeyondEngine', COMMIT, {}, {}, infos(False))
        self.assertNotIn("Java layer", text)
        self.assertIn('OXT-Beyond does not build the Android runtime yet. `Runtime/Android` and the', text)
        self.assertIn("- The Android runtime and the timezone library's Android code: see", text)
        self.assertIn('Times are the files\' modification times in the builds or in oxt-runtimes-1.15 (UTC).\n',
                      text)


class ManifestEntry(unittest.TestCase):
    def entry(self, java):
        return mra.builds_manifest_entry('oxt-runtimes-x', 'x', '0' * 64, 5, COMMIT, java_layer=java)

    def test_with_the_java_layer(self):
        e = self.entry(True)
        self.assertEqual(e['java_layer'], 'Runtime/Android/Classes')
        self.assertIn("the Android runtime's Java layer (Runtime/Android/Classes), built from the same source",
                      e['description'])
        self.assertIn('the rest of the Android runtime with the timezone library\'s Android code, carried over '
                      'unchanged from oxt-runtimes-1.15', e['description'])
        self.assertIn('the Android Java layer built from the same commit by tools/ci/android_java.py build',
                      e['source'])
        self.assertIn('the Android Java layer among them', e['licence'])
        fetch_assets.validate_asset(e)

    def test_without_it(self):
        e = self.entry(False)
        self.assertNotIn('java_layer', e)
        self.assertIn('and the Android runtime with the timezone library\'s Android code, carried over unchanged '
                      'from oxt-runtimes-1.15 (OpenXTalk Lite 1.15). See PROVENANCE.md', e['description'])
        self.assertTrue(e['source'].endswith('--builds; the Android parts from oxt-runtimes-1.15'))
        fetch_assets.validate_asset(e)

    def test_the_source_still_names_one_commit(self):
        # runtimes_provenance.py and release_inventory.py read the asset's
        # commit from its source, and refuse one that names two
        for java in (True, False):
            e = self.entry(java)
            self.assertEqual(runtimes_provenance.COMMIT_RE.findall(e['source']), [COMMIT])
            with tempfile.TemporaryDirectory() as d:
                path = os.path.join(d, 'assets.json')
                with open(path, 'w', encoding='utf-8') as f:
                    json.dump({'assets': [e]}, f)
                self.assertEqual(runtimes_provenance.runtimes_asset(path), ('oxt-runtimes-x', COMMIT))
                self.assertEqual(runtimes_provenance.java_layer(path), 'Runtime/Android/Classes' if java else None)


# ---------------------------------------------------------------------------
# The whole tool, on made-up builds and a made-up carried asset

class BuildsBase(Temp):
    """Made-up builds and a made-up carried asset, for the whole tool
    (test_runtimes_android_engine.py runs it on them too)"""

    def setUp(self):
        super().setUp()
        # one file per build, dated (even seconds: a zip's dates have two
        # second steps); the newest is linux-x86_64's
        self.bins = {}
        for n, b in enumerate(mra.BUILDS):
            folder = os.path.dirname(self.path('builds', b, 'x'))
            src = os.path.join(folder, 'Support.txt')
            with open(src, 'w') as f:
                f.write('support of %s\n' % b)
            os.utime(src, (500000000 + 2 * n, 500000000 + 2 * n))
            self.bins[b] = folder
        self.newest = 500000000 + 2 * (len(mra.BUILDS) - 1)
        # the carried asset
        self.carry = self.path('oxt-runtimes-1.15.zip')
        self.old_classes = write_jar(self.path('old', 'Classes'), layer_classes(flags_right=False))
        with open(self.old_classes, 'rb') as f:
            self.old_bytes = f.read()
        top = 'oxt-runtimes-1.15/'
        members = [('PROVENANCE.md', b'# oxt-runtimes-1.15\n'),
                   ('Runtime/Android/Classes', self.old_bytes),
                   ('Runtime/Android/Manifest.xml', b'<manifest/>'),
                   ('Runtime/Android/arm64-v8a/Standalone', b'\x7fELF arm64 engine')]
        members += [(c + 'libtz.so', b'\x7fELF tz') for c in mra.CARRY[1:]]
        with zipfile.ZipFile(self.carry, 'w', zipfile.ZIP_DEFLATED) as z:
            for name, data in members:
                zi = zipfile.ZipInfo(top + name, (2021, 7, 26, 12, 0, 0))
                zi.external_attr = 0o755 << 16
                z.writestr(zi, data)
        with open(self.carry, 'rb') as f:
            data = f.read()
        self.carry_patch = mock.patch.dict(mra.CARRY_ASSET, {'sha256': sha256(data), 'size': len(data)})
        self.carry_patch.start()
        self.addCleanup(self.carry_patch.stop)

        def plan(name, folder):
            src = os.path.join(folder, 'Support.txt')
            target = 'Runtime/%s/Support.txt' % {'win-x86': 'Windows/x86-32', 'win-x86_64': 'Windows/x86-64',
                                                'linux-x86': 'Linux/x86-32', 'linux-x86_64': 'Linux/x86-64'}[name]
            return [package.Item(target, 'build', source=src)], []
        for target, new in (('open_build', lambda name, spec, work: (spec, None)),
                            ('plan_build_parts', plan),
                            ('check_build', lambda name, infos, version: [])):
            p = mock.patch.object(mra, target, new)
            p.start()
            self.addCleanup(p.stop)

    def run_tool(self, out, *extra):
        argv = ['--builds', '--label', 'x', '--out', out, '--carry', self.carry, '--commit', COMMIT]
        for b, folder in self.bins.items():
            argv += ['--bin', '%s=%s' % (b, folder)]
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = mra.main(argv + list(extra))
        return code, buf.getvalue()

    def members(self, out):
        with zipfile.ZipFile(os.path.join(out, 'oxt-runtimes-x.zip')) as z:
            return {i.filename: (z.read(i), i.date_time, i.external_attr >> 16) for i in z.infolist()}


class Builds(BuildsBase):
    def test_the_java_layer_replaces_the_carried_one(self):
        jar = write_jar(self.path('java', 'Classes'), layer_classes())
        with open(jar, 'rb') as f:
            jar_bytes = f.read()
        out = os.path.dirname(self.path('out', 'x'))
        code, log = self.run_tool(out, '--android-classes', jar)
        self.assertEqual(code, 0, log)
        self.assertIn('android-java: Runtime/Android/Classes, 4 classes (SHA-256 %s), in place of the carried one'
                      % sha256(jar_bytes), log)
        m = self.members(out)
        data, when, mode = m['oxt-runtimes-x/Runtime/Android/Classes']
        self.assertEqual(data, jar_bytes)
        self.assertEqual(when, mra.utc(self.newest).timetuple()[:6])
        self.assertEqual(mode & 0o777, 0o644)
        # the rest of the carried Android runtime, as it was
        self.assertEqual(m['oxt-runtimes-x/Runtime/Android/Manifest.xml'][:2], (b'<manifest/>', (2021, 7, 26, 12, 0, 0)))
        self.assertEqual(m['oxt-runtimes-x/Runtime/Android/arm64-v8a/Standalone'][0], b'\x7fELF arm64 engine')
        for c in mra.CARRY[1:]:
            self.assertIn('oxt-runtimes-x/' + c + 'libtz.so', m)
        provenance = m['oxt-runtimes-x/PROVENANCE.md'][0].decode('utf-8')
        self.assertIn("## The Android runtime's Java layer", provenance)
        self.assertIn('SHA-256 `%s`' % sha256(jar_bytes), provenance)
        self.assertIn("(LiveCode Community 9.6.3's, %s bytes, SHA-256 `%s`)"
                      % ('{:,}'.format(len(self.old_bytes)), sha256(self.old_bytes)), provenance)
        with open(os.path.join(out, 'oxt-runtimes-x.manifest.json'), encoding='utf-8') as f:
            entry = json.load(f)
        self.assertEqual(entry['java_layer'], 'Runtime/Android/Classes')
        fetch_assets.validate_asset(entry)
        # what the packages install from it: the new jar at its path
        files, _ = fetch_assets.plan_members(entry, os.path.join(out, 'oxt-runtimes-x.zip'))
        self.assertIn(('Runtime/Android/Classes', 'oxt-runtimes-x/Runtime/Android/Classes'), files)

    def test_the_archive_does_not_depend_on_when_the_jar_was_built(self):
        jar = write_jar(self.path('java', 'Classes'), layer_classes())
        shas = []
        for n, when in enumerate((600000000, 900000000)):
            os.utime(jar, (when, when))
            out = os.path.dirname(self.path('out%d' % n, 'x'))
            code, log = self.run_tool(out, '--android-classes', jar)
            self.assertEqual(code, 0, log)
            with open(os.path.join(out, 'oxt-runtimes-x.manifest.json'), encoding='utf-8') as f:
                shas.append(json.load(f)['sha256'])
        self.assertEqual(shas[0], shas[1])

    def test_without_it_the_carried_layer_stays(self):
        out = os.path.dirname(self.path('out', 'x'))
        code, log = self.run_tool(out)
        self.assertEqual(code, 0, log)
        self.assertNotIn('android-java', log)
        m = self.members(out)
        self.assertEqual(m['oxt-runtimes-x/Runtime/Android/Classes'][:2], (self.old_bytes, (2021, 7, 26, 12, 0, 0)))
        self.assertNotIn('Java layer', m['oxt-runtimes-x/PROVENANCE.md'][0].decode('utf-8'))
        with open(os.path.join(out, 'oxt-runtimes-x.manifest.json'), encoding='utf-8') as f:
            self.assertNotIn('java_layer', json.load(f))

    def test_a_bad_jar_writes_no_archive(self):
        jar = write_jar(self.path('java', 'Classes'), layer_classes(flags_right=False))
        out = os.path.dirname(self.path('out', 'x'))
        with self.assertRaises(SystemExit) as cm:
            self.run_tool(out, '--android-classes', jar)
        self.assertIn('1 problems; no archive written', str(cm.exception))
        self.assertFalse(os.path.exists(os.path.join(out, 'oxt-runtimes-x.zip')))

    def test_update_manifest_pins_the_entry_with_its_java_layer(self):
        jar = write_jar(self.path('java', 'Classes'), layer_classes())
        manifest = self.path('external-assets.json')
        shutil.copy(os.path.join(OXT, 'external-assets.json'), manifest)
        out = os.path.dirname(self.path('out', 'x'))
        code, log = self.run_tool(out, '--android-classes', jar, '--update-manifest', manifest)
        self.assertEqual(code, 0, log)
        assets = fetch_assets.load_manifest(manifest)
        self.assertEqual([a['id'] for a in assets], ['oxt-runtimes-x'])
        self.assertEqual(runtimes_provenance.java_layer(manifest), 'Runtime/Android/Classes')

    def test_only_with_builds(self):
        with self.assertRaises(SystemExit) as cm, contextlib.redirect_stderr(io.StringIO()) as err:
            mra.main([self.tmp, '--out', self.tmp, '--android-classes', 'Classes'])
        self.assertEqual(cm.exception.code, 2)
        self.assertIn('--android-classes and --android-engine go with --builds', err.getvalue())


# ---------------------------------------------------------------------------
# What reads the entry

class Compare(Temp):
    """package.py --compare against an OXT Lite 1.15 install: with a runtimes
    asset whose java_layer names it, Classes may differ; the Android
    engines are still compared byte for byte."""

    def items(self, asset):
        out = []
        for rel, data in (('Runtime/Android/Classes', b'new jar'), ('Runtime/Android/arm64-v8a/Standalone', b'eng')):
            stage = self.path('stage', *rel.split('/'))
            with open(stage, 'wb') as f:
                f.write(data)
            out.append(package.Item(rel, 'asset', member='%s/%s' % (asset['id'], rel), asset=asset))
        return out

    def reference(self, engine=b'eng'):
        for rel, data in (('Runtime/Android/Classes', b'old jar'), ('Runtime/Android/arm64-v8a/Standalone', engine)):
            with open(self.path('ref', *rel.split('/')), 'wb') as f:
                f.write(data)
        return os.path.join(self.tmp, 'ref')

    def compare(self, asset, engine=b'eng'):
        items = self.items(asset)
        report = self.path('report.tsv')
        with contextlib.redirect_stdout(io.StringIO()):
            problems = package.compare(os.path.join(self.tmp, 'stage'), items, self.reference(engine), False,
                                       report=report)
        with open(report, encoding='utf-8') as f:
            rows = {r.split('\t')[1]: r.split('\t')[0] for r in f.read().splitlines()[1:]}
        return problems, rows

    def test_a_java_layer_built_here_may_differ(self):
        problems, rows = self.compare({'id': 'oxt-runtimes-x', 'strip': 1, 'java_layer': 'Runtime/Android/Classes'})
        self.assertEqual(problems, 0)
        self.assertEqual(rows['Runtime/Android/Classes'], 'present (rebuilt)')
        self.assertEqual(rows['Runtime/Android/arm64-v8a/Standalone'], 'present')

    def test_a_carried_one_may_not(self):
        problems, rows = self.compare({'id': 'oxt-runtimes-x', 'strip': 1})
        self.assertEqual(problems, 1)
        self.assertEqual(rows['Runtime/Android/Classes'], 'ERROR content')

    def test_nor_may_1_15s(self):
        problems, rows = self.compare({'id': 'oxt-runtimes-1.15', 'strip': 1, 'java_layer': 'Runtime/Android/Classes'})
        self.assertEqual(rows['Runtime/Android/Classes'], 'ERROR content')

    def test_the_engines_are_still_compared(self):
        problems, rows = self.compare({'id': 'oxt-runtimes-x', 'strip': 1, 'java_layer': 'Runtime/Android/Classes'},
                                      engine=b'another engine')
        self.assertEqual(problems, 1)
        self.assertEqual(rows['Runtime/Android/arm64-v8a/Standalone'], 'ERROR content')


class ProvenanceReport(unittest.TestCase):
    def test_the_java_layer_is_counted(self):
        text = runtimes_provenance.report('oxt-runtimes-x', COMMIT, [], 40, 'Runtime/Android/Classes')
        self.assertIn("The Android runtime's Java layer in the asset (`Runtime/Android/Classes`) was built from "
                      'that commit too', text)
        self.assertIn('The rest of the Android runtime is carried over from oxt-runtimes-1.15', text)

    def test_without_it_nothing_android_is(self):
        text = runtimes_provenance.report('oxt-runtimes-x', COMMIT, [], 40)
        self.assertIn('The Android runtime in the asset is carried over from oxt-runtimes-1.15, not built here: '
                      'not checked.', text)
        self.assertNotIn('Java layer', text)

    def test_main_reads_the_entry(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, 'assets.json')
            entry = mra.builds_manifest_entry('oxt-runtimes-x', 'x', '0' * 64, 5, COMMIT, java_layer=True)
            with open(path, 'w', encoding='utf-8') as f:
                json.dump({'assets': [entry]}, f)
            out = io.StringIO()
            with mock.patch.object(runtimes_provenance, 'commits_since', return_value=[]), \
                    contextlib.redirect_stdout(out), \
                    mock.patch.dict(os.environ, {'GITHUB_ACTIONS': '', 'GITHUB_STEP_SUMMARY': ''}):
                code = runtimes_provenance.main(['--assets', path])
        self.assertEqual(code, 0)
        self.assertIn("The Android runtime's Java layer in the asset", out.getvalue())


class Docs(unittest.TestCase):
    """README.md and THIRD-PARTY-NOTICES.md say where the packages' runtimes
    come from, by the pinned asset: once its entry names a Java layer built
    here, each must say so (the pull request that pins such an asset fails
    here until it does), and not before."""

    def test_the_docs_say_whose_java_layer_the_packages_ship(self):
        java = runtimes_provenance.java_layer(runtimes_provenance.ASSETS)
        for name in ('README.md', 'THIRD-PARTY-NOTICES.md'):
            with open(os.path.join(REPO, name), encoding='utf-8') as f:
                text = f.read()
            if java:
                self.assertIn(java, text, '%s: the pinned runtimes asset\'s Android Java layer (%s) is built from '
                              'this repository; say so where the file says the Android runtime is prebuilt'
                              % (name, java))
            else:
                self.assertNotIn('Runtime/Android/Classes', text, '%s: the pinned runtimes asset carries the Android '
                                 'runtime unchanged, Java layer and all' % name)


# ---------------------------------------------------------------------------
# The workflow

def workflow(name):
    import yaml
    with open(os.path.join(WORKFLOWS, name), encoding='utf-8') as f:
        return yaml.safe_load(f)


def steps_of(job):
    return {s.get('name'): s for s in job['steps']}


def commands(run):
    """The android_java.py command lines of a step, continuations joined."""
    text = re.sub(r'\\\n\s*', '', run)
    return [' '.join(x.split()) for x in text.splitlines() if 'tools/ci/android_java.py' in x]


class Workflow(unittest.TestCase):
    """The jar a runtimes asset ships is built and checked as android-java.yml
    builds and checks a pull request's, before the archive takes it."""

    @classmethod
    def setUpClass(cls):
        try:
            import yaml  # noqa: F401
        except ImportError:
            raise unittest.SkipTest('no PyYAML')
        cls.runtimes = workflow('runtimes.yml')['jobs']['assemble']
        cls.java = workflow('android-java.yml')['jobs']['java']

    def test_the_same_setup(self):
        a = steps_of(self.runtimes)['Set up the JDK and the Android SDK']['run']
        b = steps_of(self.java)['Set up the JDK and the Android SDK']['run']
        self.assertEqual(a, b)

    def test_the_same_checks_before_the_archive(self):
        names = [s.get('name') for s in self.runtimes['steps']]
        mine = []
        for s in self.runtimes['steps'][:names.index('Make the archive')]:
            mine += commands(s.get('run', ''))
        theirs = []
        for s in self.java['steps']:
            if s.get('name') in ('Build the Java layer', 'Compare it with the shipped one',
                                 'Check it against the engine (JNI)', 'Check what Android asks of the code'):
                theirs += commands(s['run'])
        self.assertEqual(len(theirs), 4)
        self.assertEqual(mine, theirs)
        self.assertEqual([c.split()[2] for c in mine], ['build', 'compare', 'jni', 'rules'])

    def test_the_checked_jar_is_the_one_taken(self):
        steps = steps_of(self.runtimes)
        built = re.search(r'--out "([^"]+)"', commands(steps['Build the Java layer']['run'])[0]).group(1)
        make = steps['Make the archive']['run']
        self.assertIn('--android-classes "%s"' % built, make)
        for c in commands(''.join(s.get('run', '') for s in self.runtimes['steps'])):
            if c.split()[2] in ('compare', 'jni', 'rules'):
                self.assertIn('"%s"' % built, c)

    def test_it_runs_where_the_builds_commit_is_checked_out(self):
        names = [s.get('name') for s in self.runtimes['steps']]
        self.assertLess(names.index("Check out the builds' commit"), names.index('Build the Java layer'))
        fetch = steps_of(self.runtimes)['Fetch the runtimes asset pinned at this commit']['run']
        self.assertIn('tools/oxt/fetch_assets.py', fetch)
        self.assertLess(names.index('Fetch the runtimes asset pinned at this commit'),
                        names.index('Compare it with the pinned one'))

    def test_the_release_says_so(self):
        notes = steps_of(workflow('runtimes.yml')['jobs']['publish'])['Create the release and check the upload']['run']
        self.assertIn("the Android runtime's Java layer", notes)
        self.assertIn('rest of the Android runtime carried over from', notes)


if __name__ == '__main__':
    unittest.main()
