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

"""The xTalk Suite's Android probe (android_check.py ide --probe xtalk and
device --xtalk; kXtalkSays in android-check.livecodescript): its records
from the manifest and the installed extensions, what it must say, what a
package must hold; that the manifest pins every native member's Android
libraries; and that android.yml runs it on both emulators. No Android SDK
or engine is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import copy
import json
import os
import re
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import android_check as ac  # noqa: E402

ANDROID = ('arm64-android', 'armv7-android', 'x86_64-android', 'x86-android')
# The members whose libraries are native, each with its LCB extension: all
# ten build for Android (the xTalk Suite's docs/ANDROID.md)
NATIVE = {'SodiumXT': 'org.openxtalk.library.sodium', 'TorrentXT': 'org.openxtalk.library.torrent',
          'enetxt': 'org.openxtalk.library.enet', 'dataChannelXT': 'org.openxtalk.library.datachannel',
          'Box2Dxt': 'org.openxtalk.box2dxt', 'CoinXT': 'org.openxtalk.library.coin',
          'curlxt': 'org.openxtalk.library.curl', 'box3dxt': 'org.openxtalk.library.boxthreed',
          'webpxt': 'org.openxtalk.library.webpxt', 'barcodext': 'org.openxtalk.library.barcodext'}
# The bindings that open sockets declare the INTERNET permission
NETWORKING = ('org.openxtalk.library.torrent', 'org.openxtalk.library.enet',
              'org.openxtalk.library.datachannel', 'org.openxtalk.library.curl')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def member(name, ext_id, token, platforms=ANDROID, probe='fooVersion()', expect='^foo [0-9]'):
    files = [{'path': 'src/%s.lcb' % token, 'role': 'source'},
             {'path': 'src/code/x86_64-linux/%s.so' % token, 'role': 'library'}]
    files += [{'path': 'src/code/%s/%s.so' % (p, token), 'role': 'library'} for p in platforms]
    return {'name': name, 'files': files,
            'extensions': [{'kind': 'lcb', 'id': ext_id, 'folder': ext_id, 'main': 'src/%s.lcb' % token,
                            'probe': probe, 'expect': expect},
                           {'kind': 'lcs', 'id': ext_id + 'Helpers', 'folder': ext_id + 'Helpers',
                            'main': 'src/h.livecodescript', 'probe': 'h()', 'expect': '^1$'}]}


def install(ext_dir, ext_id, token, platforms=ANDROID, metadata=''):
    folder = os.path.join(ext_dir, ext_id)
    for p in platforms:
        os.makedirs(os.path.join(folder, 'code', p), exist_ok=True)
        with open(os.path.join(folder, 'code', p, token + '.so'), 'wb') as f:
            f.write(b'\x7fELF')
    with open(os.path.join(folder, token + '.lcb'), 'w', encoding='utf-8') as f:
        f.write('library %s\n%s\nend library\n' % (ext_id, metadata))


class Records(unittest.TestCase):
    def setUp(self):
        self.manifest = {'members': [member('Foo', 'org.x.foo', 'fooxt'),
                                     member('Bar', 'org.x.bar', 'barxt', probe='barLen()', expect='^32$'),
                                     member('Desk', 'org.x.desk', 'deskxt', platforms=())]}

    def test_extensions_with_android_code(self):
        found = ac.xtalk_android_extensions(self.manifest)
        # the LCB extensions of the members with Android code, in order;
        # never a script library, never a desktop-only member
        self.assertEqual([e['id'] for _, e, _ in found], ['org.x.foo', 'org.x.bar'])
        self.assertEqual(list(found[0][2].items()), [(p, 'fooxt.so') for p in ANDROID])

    def test_some_android_platforms_and_not_all_is_an_error(self):
        self.manifest['members'][0] = member('Foo', 'org.x.foo', 'fooxt', platforms=ANDROID[:3])
        with self.assertRaisesRegex(ac.CheckError, 'Foo pins Android libraries for .* and none for x86-android'):
            ac.xtalk_android_extensions(self.manifest)

    def test_records(self):
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt', metadata='metadata android.permissions is "INTERNET"')
            install(ext, 'org.x.bar', 'barxt', metadata='  metadata android.permissions is "INTERNET,CAMERA"')
            self.assertEqual(ac.xtalk_records(self.manifest, ext), [
                'extension\torg.x.foo\tfooVersion()\t^foo [0-9]',
                'extension\torg.x.bar\tbarLen()\t^32$',
                'permission\tINTERNET',
                'permission\tCAMERA'])

    def test_no_permission_declared(self):
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            install(ext, 'org.x.bar', 'barxt', metadata='-- metadata android.permissions is "INTERNET"')
            self.assertFalse([r for r in ac.xtalk_records(self.manifest, ext) if r.startswith('permission')])

    def test_an_extension_not_installed(self):
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            with self.assertRaisesRegex(ac.CheckError, 'org.x.bar is not installed'):
                ac.xtalk_records(self.manifest, ext)

    def test_an_extension_without_its_android_code(self):
        # the release's own extension, which has no Android code: the
        # probe is built from what is installed, so it is refused
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            install(ext, 'org.x.bar', 'barxt', platforms=ANDROID[1:])
            with self.assertRaisesRegex(ac.CheckError, 'org.x.bar has no code/arm64-android/barxt.so'):
                ac.xtalk_records(self.manifest, ext)

    def test_nothing_to_probe(self):
        with tempfile.TemporaryDirectory() as ext:
            with self.assertRaisesRegex(ac.CheckError, 'no LCB extension with libraries for every Android'):
                ac.xtalk_records({'members': [member('Desk', 'org.x.desk', 'deskxt', platforms=())]}, ext)

    def test_a_tab_in_a_probe(self):
        self.manifest['members'] = [member('Foo', 'org.x.foo', 'fooxt', probe='a\tb')]
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            with self.assertRaisesRegex(ac.CheckError, 'a tab or a line break'):
                ac.xtalk_records(self.manifest, ext)

    def test_list_file(self):
        with tempfile.TemporaryDirectory() as work:
            path = os.path.join(work, ac.XTALK_LIST)
            with open(path, 'w', encoding='utf-8') as f:
                f.write('extension\torg.x.foo\tfooVersion()\t^foo\npermission\tINTERNET\n')
            # the probe says only the extensions; the permissions are
            # asked of the package manager
            self.assertEqual(ac.read_xtalk_list(path), ['org.x.foo'])
            self.assertEqual(ac.read_xtalk_list(path, 'permission'), ['INTERNET'])
            with open(path, 'w', encoding='utf-8') as f:
                f.write('permission\tINTERNET\n')
            with self.assertRaisesRegex(ac.CheckError, 'lists nothing to probe'):
                ac.read_xtalk_list(path)
            with open(path, 'w', encoding='utf-8') as f:
                f.write('extension\torg.x.foo\tfooVersion()\t^foo\n')
            self.assertEqual(ac.read_xtalk_list(path, 'permission'), [])


class Permissions(unittest.TestCase):
    # dumpsys package of the probe on Android 13, cut to the part that
    # matters (the form test_android_check's dialog tests use)
    DUMP = ('    requested permissions:\n'
            '      android.permission.INTERNET\n'
            '      android.permission.CAMERA\n'
            '    install permissions:\n'
            '      android.permission.INTERNET: granted=true\n'
            '    User 0: ceDataInode=1 installed=true\n'
            '      runtime permissions:\n'
            '        android.permission.CAMERA: granted=false, flags=[ USER_SENSITIVE_WHEN_GRANTED ]\n')

    def test_held(self):
        self.assertEqual(ac.xtalk_permission_problems(self.DUMP, ['INTERNET']), [])

    def test_asked_for_and_not_held(self):
        self.assertEqual(ac.xtalk_permission_problems(self.DUMP, ['CAMERA']),
                         ['the package asks for android.permission.CAMERA and does not hold it'])

    def test_not_in_the_manifest(self):
        self.assertEqual(ac.xtalk_permission_problems(self.DUMP, ['BLUETOOTH']),
                         ['the package does not ask for android.permission.BLUETOOTH, which an xTalk Suite '
                          'extension declares'])

    def test_device_asks_the_package_manager(self):
        source = read('tools', 'ci', 'android_check.py')
        part = source[source.index("    if getattr(args, 'xtalk', None):\n        # the xTalk"):]
        part = part[:part.index('    if args.within_bars and green:')]
        self.assertIn("read_xtalk_list(args.xtalk, 'permission')", part)
        self.assertIn("a('shell', 'dumpsys', 'package', IDENTIFIER)", part)
        self.assertIn('xtalk_permission_problems(package_dump, wanted)', part)


class Said(unittest.TestCase):
    KEYS = ['org.x.foo', 'org.x.bar', 'org.x.baz']

    def test_all_ok(self):
        said = ['xtalk org.x.foo ok: foo 1.0', 'xtalk org.x.bar ok: 32', 'xtalk org.x.baz ok: true']
        self.assertEqual(ac.xtalk_said_problems(said, self.KEYS), [])

    def test_each_failure_is_named(self):
        said = ['xtalk org.x.foo threw: 219,0,0', 'xtalk org.x.baz unexpected: false', 'something else']
        self.assertEqual(ac.xtalk_said_problems(said, self.KEYS), [
            'the xTalk probe: org.x.foo threw: 219,0,0',
            'the xTalk probe said nothing of org.x.bar',
            'the xTalk probe: org.x.baz unexpected: false'])

    def test_a_key_that_starts_another(self):
        # org.x.foo's line is not org.x.fo's
        self.assertEqual(ac.xtalk_said_problems(['xtalk org.x.foo ok: 1'], ['org.x.fo']),
                         ['the xTalk probe said nothing of org.x.fo'])

    def test_the_probes_lines_as_the_log_says_them(self):
        # what probe_said reads from the device's log is what the IDE
        # script puts: kXtalkSays, then the key
        script = read('tools', 'ci', 'android-check.livecodescript')
        says = re.search(r'constant kXtalkSays = "([^"]*)"', script).group(1)
        self.assertEqual(says, 'OXT-Beyond probe: ' + ac.XTALK_SAYS)
        log = 'I/LiveCode( 4242): %s org.x.foo ok: foo 1.0\n' % says
        self.assertEqual(ac.probe_said(log, ('4242',)), ['xtalk org.x.foo ok: foo 1.0'])


class Package(unittest.TestCase):
    def setUp(self):
        self.manifest = {'members': [member('Foo', 'org.x.foo', 'fooxt'), member('Bar', 'org.x.bar', 'barxt')]}

    def test_every_library_of_every_abi_present(self):
        names = ['lib/%s/lib%s.so' % (abi, t) for abi in ac.ANDROID_PLATFORMS.values()
                 for t in ('fooxt', 'barxt', 'revandroid')]
        self.assertEqual(ac.xtalk_package_problems(names, self.manifest), [])

    def test_only_the_abis_the_package_has(self):
        names = ['lib/x86_64/libfooxt.so', 'lib/x86_64/libbarxt.so', 'classes.dex']
        self.assertEqual(ac.xtalk_package_problems(names, self.manifest), [])

    def test_a_missing_library(self):
        names = ['lib/x86_64/libfooxt.so', 'lib/arm64-v8a/libfooxt.so', 'lib/arm64-v8a/libbarxt.so']
        self.assertEqual(ac.xtalk_package_problems(names, self.manifest),
                         ['org.x.bar: the package has no lib/x86_64/libbarxt.so'])

    def test_the_library_under_its_own_name_is_not_enough(self):
        self.assertEqual(ac.xtalk_package_problems(['lib/x86/fooxt.so', 'lib/x86/libbarxt.so'], self.manifest),
                         ['org.x.foo: the package has no lib/x86/libfooxt.so'])

    def test_no_native_libraries(self):
        self.assertEqual(ac.xtalk_package_problems(['classes.dex'], self.manifest),
                         ['the package has no native libraries (lib/<abi>/)'])


class TheManifest(unittest.TestCase):
    def setUp(self):
        with open(ac.XTALK_MANIFEST, encoding='utf-8') as f:
            self.manifest = json.load(f)

    def test_platforms(self):
        for p in ANDROID:
            self.assertIn(p, self.manifest['platforms'])
        self.assertEqual(list(ac.ANDROID_PLATFORMS), list(ANDROID))

    def test_every_native_member_has_android_code(self):
        found = {m['name']: e['id'] for m, e, _ in ac.xtalk_android_extensions(self.manifest)}
        self.assertEqual(found, NATIVE)

    def test_the_probes_are_the_desktop_checks(self):
        # the probe calls each extension's own smoke test, the one the
        # desktop check runs (run_livecode_check.py), nothing of its own
        for m, e, libs in ac.xtalk_android_extensions(self.manifest):
            self.assertTrue(e['probe'].strip() and e['expect'].strip(), e['id'])
            # each Android library sits beside the member's Linux ones, of
            # the same name
            linux = {f['path'].rsplit('/', 1)[-1] for f in m['files']
                     if f['role'] == 'library' and '/x86_64-linux/' in f['path']}
            self.assertEqual(set(libs.values()), linux, m['name'])

    def test_the_old_shape_is_refused(self):
        # a member that once pinned all four ids and lost one fails loudly
        broken = copy.deepcopy(self.manifest)
        for m in broken['members']:
            if m['name'] == 'SodiumXT':
                m['files'] = [f for f in m['files'] if '/x86-android/' not in f['path']]
        with self.assertRaisesRegex(ac.CheckError, 'SodiumXT pins Android libraries'):
            ac.xtalk_android_extensions(broken)


class Workflow(unittest.TestCase):
    def setUp(self):
        self.workflow = read('.github', 'workflows', 'android.yml')

    def test_built_with_the_suites_android_code(self):
        step = re.search(r"(?s)- name: The xTalk Suite's probe, with this Java layer\n(.*?)\n      - name:",
                         self.workflow).group(1)
        build = step.index('tools/oxt/xtalk_extensions.py build --bin "$JAVA_IDE/Toolchain" '
                           '--out "$JAVA_IDE/Extensions"')
        probe = step.index('--probe xtalk')
        self.assertLess(build, probe)
        self.assertIn('--platforms ' + ','.join(['x86_64-android', 'x86-android', 'arm64-android',
                                                  'armv7-android']), step)
        self.assertIn('--builds debug', step)
        self.assertIn('--work "$WORK/java-xtalk"', step)
        # after every other probe built from the third copy: none of them
        # is built with the suite's extensions in place of the release's
        for other in ('java-new', 'java-app', 'java-busy', 'java-edge'):
            self.assertLess(self.workflow.index('--work "$WORK/%s"' % other),
                            self.workflow.index("- name: The xTalk Suite's probe, with this Java layer"), other)

    def test_run_on_both_emulators(self):
        runs = re.findall(r'android_check\.py device --apk "\$WORK/java-xtalk/out/debug\.apk"[^\n]*\\\n'
                          r'[^\n]*\\\n[^\n]*', self.workflow)
        self.assertEqual(len(runs), 2)
        for run in runs:
            self.assertIn('--xtalk "$WORK/java-xtalk/%s"' % ac.XTALK_LIST, run)
        self.assertIn('screen-api33-java-xtalk.png', runs[0])
        self.assertIn('screen-16k-java-xtalk.png', runs[1])
        step16 = re.search(r'(?s)- name: Run the package with 16 KB pages\n(.*?)\n      - name:',
                           self.workflow).group(1)
        self.assertIn(runs[1], step16)

    def test_a_manifest_change_runs_it(self):
        paths = re.search(r'(?s)paths: &android-paths\n(.*?)\n  push:', self.workflow).group(1)
        self.assertIn('- tools/oxt/xtalk-extensions.json', paths)
        self.assertIn('- tools/oxt/xtalk_extensions.py', paths)


class Script(unittest.TestCase):
    def setUp(self):
        self.script = read('tools', 'ci', 'android-check.livecodescript')

    def body(self, kind, name):
        return re.search(r'(?s)private %s %s\n(.*?)\nend %s' % (kind, name, re.escape(name.split()[0])),
                         self.script).group(1)

    def test_extensions_chosen_not_searched(self):
        body = self.body('function', 'buildSettings pName')
        part = body[body.index('if probeName() is "AndroidXtalkProbe" then'):]
        part = part[:part.index('   end if\n   -- the engine')]
        self.assertIn('put "select" into tSettings["inclusions"]', part)
        self.assertIn('put item 2 of tLine & return after tSettings["extensions"]', part)

    def test_fail_colour_when_any_record_fails(self):
        calls = self.body('function', 'xtalkCalls')
        self.assertIn('"   xtalkProbe"', calls)
        # a permission record is skipped: device --xtalk asks the package
        # manager (androidHasPermission is empty for INTERNET)
        self.assertIn('if item 1 of tLine is not "extension" then next repeat', calls)
        self.assertNotIn('xtalkPermission', self.script)
        self.assertIn('"   if the result is not empty then put true into tFailed"', calls)
        self.assertIn('quote & kFailColor & quote', calls)
        # before the green: openStack's green follows the calls
        script = self.body('function', 'probeScript')
        self.assertLess(script.index('put xtalkCalls() after tScript'),
                        script.index('put "   set the backgroundColor of me to" && quote & kRunColor'))

    def test_handlers_say_each_answer(self):
        handlers = self.body('function', 'xtalkHandlers')
        for word in ('ok:', 'unexpected:', 'threw:'):
            self.assertIn('quote & "%s" & quote' % word, handlers)
        # the smoke test is evaluated inside a try, so a library that does
        # not load is a said failure and not the end of the probe
        self.assertLess(handlers.index('"   try"'), handlers.index('"      do"'))
        self.assertNotIn('androidHasPermission(', handlers)

    def test_no_extension_is_an_error(self):
        records = self.body('function', 'xtalkRecords')
        self.assertIn('throw "OXT_ANDROID_XTALK names no extension:"', records)
        self.assertIn('throw "OXT_ANDROID_XTALK: not a record:"', records)

    def test_quotes_in_a_probe(self):
        # a probe expression with quotes in it ("x" is among ...) becomes a
        # literal the script compiles: each quote "& quote &"
        lit = self.body('function', 'scriptLiteral pText')
        self.assertIn('replace quote with quote & " & quote & " & quote in pText', lit)

    def test_ide_passes_the_list(self):
        source = read('tools', 'ci', 'android_check.py')
        self.assertIn('OXT_ANDROID_XTALK=path(xtalk)', source)
        self.assertIn('$OXT_ANDROID_XTALK', self.script)


if __name__ == '__main__':
    unittest.main()
