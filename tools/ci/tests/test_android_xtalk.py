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
from the manifest and the installed extensions (the LCB ones with Android
code, the script libraries over them, the functional tests of
android-xtalk-tests.livecodescript), what it must say, what a package
must hold; that the manifest pins every native member's Android
libraries; that the tests file keeps its own rules as far as its text
shows; and that android.yml runs it on both emulators. No Android SDK or
engine is needed.

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
# thirteen build for Android (the xTalk Suite's docs/ANDROID.md)
NATIVE = {'SodiumXT': 'org.openxtalk.library.sodium', 'TorrentXT': 'org.openxtalk.library.torrent',
          'enetxt': 'org.openxtalk.library.enet', 'dataChannelXT': 'org.openxtalk.library.datachannel',
          'Box2Dxt': 'org.openxtalk.box2dxt', 'CoinXT': 'org.openxtalk.library.coin',
          'curlxt': 'org.openxtalk.library.curl', 'box3dxt': 'org.openxtalk.library.boxthreed',
          'audioxt': 'org.openxtalk.library.audioxt', 'xlsxt': 'org.openxtalk.library.xlsxt',
          'webpxt': 'org.openxtalk.library.webpxt', 'barcodext': 'org.openxtalk.library.barcodext',
          'render3dxt': 'org.openxtalk.library.renderthreed'}
# The bindings that open sockets declare the INTERNET permission
NETWORKING = ('org.openxtalk.library.torrent', 'org.openxtalk.library.enet',
              'org.openxtalk.library.datachannel', 'org.openxtalk.library.curl')
# The script libraries the manifest ships, which an Android app can load:
# each is over a native member with Android code, or over nothing native
SCRIPTS = ['torrentHelpers', 'enetHelpers', 'dataChannelHelpers', 'box2dxt-kit', 'coinxt', 'onionxt',
           'onion-httpd', 'nostrxt', 'nostr-relay', 'curlHelpers', 'tsNetCompat']
# A tests file of two functions, for the records made from made-up
# manifests (the real one is XTALK_TESTS_SCRIPT, held by TheTests)
TESTS_SCRIPT = ('-- prose\n\n%s\n\nfunction xtalkTestFoo\n   return "passed: foo"\nend xtalkTestFoo\n\n'
                'function xtalkTestBar\n   return "passed: bar"\nend xtalkTestBar\n' % ac.XTALK_TESTS_BEGIN)


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
                            'stack': ext_id + 'Helpers', 'main': 'src/h.livecodescript', 'requires': [ext_id],
                            'probe': 'h()', 'expect': '^1$'}]}


def script_member(name, ext_id, requires=()):
    """A member that is script alone: one script library, no library file."""
    return {'name': name, 'files': [{'path': 'src/%s.livecodescript' % ext_id, 'role': 'source'}],
            'extensions': [{'kind': 'lcs', 'id': ext_id, 'folder': ext_id, 'stack': ext_id,
                            'main': 'src/%s.livecodescript' % ext_id, 'requires': list(requires),
                            'probe': '%sVersion()' % ext_id, 'expect': '^[0-9]'}]}


def install(ext_dir, ext_id, token, platforms=ANDROID, metadata=''):
    folder = os.path.join(ext_dir, ext_id)
    for p in platforms:
        os.makedirs(os.path.join(folder, 'code', p), exist_ok=True)
        with open(os.path.join(folder, 'code', p, token + '.so'), 'wb') as f:
            f.write(b'\x7fELF')
    with open(os.path.join(folder, token + '.lcb'), 'w', encoding='utf-8') as f:
        f.write('library %s\n%s\nend library\n' % (ext_id, metadata))
    install_script(ext_dir, ext_id + 'Helpers')


def install_script(ext_dir, stack):
    os.makedirs(os.path.join(ext_dir, stack), exist_ok=True)
    with open(os.path.join(ext_dir, stack, stack + '.livecodescript'), 'w', encoding='utf-8') as f:
        f.write('script "%s"\n' % stack)


def records(manifest, ext_dir, tests=None):
    """xtalk_records without the real functional tests, whose extensions a
    made-up manifest has not."""
    return ac.xtalk_records(manifest, ext_dir, tests=tests or {}, tests_script=TESTS_SCRIPT)


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
            # the LCB extensions, then the script libraries over them
            # (never the desktop-only member's), then the permissions
            self.assertEqual(records(self.manifest, ext), [
                'extension\torg.x.foo\tfooVersion()\t^foo [0-9]',
                'extension\torg.x.bar\tbarLen()\t^32$',
                'extension\torg.x.fooHelpers\th()\t^1$',
                'extension\torg.x.barHelpers\th()\t^1$',
                'permission\tINTERNET',
                'permission\tCAMERA'])

    def test_no_permission_declared(self):
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            install(ext, 'org.x.bar', 'barxt', metadata='-- metadata android.permissions is "INTERNET"')
            self.assertFalse([r for r in records(self.manifest, ext) if r.startswith('permission')])

    def test_an_extension_not_installed(self):
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            with self.assertRaisesRegex(ac.CheckError, 'org.x.bar is not installed'):
                records(self.manifest, ext)

    def test_an_extension_without_its_android_code(self):
        # the release's own extension, which has no Android code: the
        # probe is built from what is installed, so it is refused
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            install(ext, 'org.x.bar', 'barxt', platforms=ANDROID[1:])
            with self.assertRaisesRegex(ac.CheckError, 'org.x.bar has no code/arm64-android/barxt.so'):
                records(self.manifest, ext)

    def test_nothing_to_probe(self):
        with tempfile.TemporaryDirectory() as ext:
            with self.assertRaisesRegex(ac.CheckError, 'no LCB extension with libraries for every Android'):
                records({'members': [member('Desk', 'org.x.desk', 'deskxt', platforms=())]}, ext)

    def test_a_tab_in_a_probe(self):
        self.manifest['members'] = [member('Foo', 'org.x.foo', 'fooxt', probe='a\tb')]
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            with self.assertRaisesRegex(ac.CheckError, 'a tab or a line break'):
                records(self.manifest, ext)

    def test_a_tab_in_a_script_librarys_probe(self):
        self.manifest['members'] = [member('Foo', 'org.x.foo', 'fooxt')]
        self.manifest['members'][0]['extensions'][1]['expect'] = 'a\tb'
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            with self.assertRaisesRegex(ac.CheckError, 'org.x.fooHelpers: a tab or a line break'):
                records(self.manifest, ext)

    def test_script_libraries_an_android_app_can_load(self):
        # over an LCB extension with Android code, over nothing native, or
        # over another script library that is; never over a member whose
        # library has no Android build, nor over a library that is not
        self.manifest['members'] += [script_member('Pure', 'pure'), script_member('Over', 'over', ['pure']),
                                     script_member('Lost', 'lost', ['org.x.deskHelpers']),
                                     script_member('Gone', 'gone', ['no.such.extension'])]
        self.assertEqual([e['id'] for _, e in ac.xtalk_script_extensions(self.manifest)],
                         ['org.x.fooHelpers', 'org.x.barHelpers', 'pure', 'over'])

    def test_a_script_library_that_requires_a_later_one(self):
        # the manifest's order is kept, whatever order they resolve in
        self.manifest['members'] = [script_member('Over', 'over', ['pure']), script_member('Pure', 'pure')]
        self.assertEqual([e['id'] for _, e in ac.xtalk_script_extensions(self.manifest)], ['over', 'pure'])

    def test_a_script_library_not_installed(self):
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt')
            install(ext, 'org.x.bar', 'barxt')
            os.remove(os.path.join(ext, 'org.x.barHelpers', 'org.x.barHelpers.livecodescript'))
            with self.assertRaisesRegex(ac.CheckError, r'org.x.barHelpers is not installed .*org.x.barHelpers.livecodescript'):
                records(self.manifest, ext)

    def test_test_records(self):
        tests = {'test.foo': ('xtalkTestFoo', ('org.x.foo', 'org.x.fooHelpers')),
                 'test.bar': ('xtalkTestBar', ('org.x.bar',))}
        with tempfile.TemporaryDirectory() as ext:
            install(ext, 'org.x.foo', 'fooxt', metadata='metadata android.permissions is "INTERNET"')
            install(ext, 'org.x.bar', 'barxt')
            got = records(self.manifest, ext, tests)
        # after every extension, before the permissions; what a test must
        # answer is what its function returns when it passes
        self.assertEqual(got[4:], ['test\ttest.foo\txtalkTestFoo()\t^passed:',
                                   'test\ttest.bar\txtalkTestBar()\t^passed:',
                                   'permission\tINTERNET'])
        self.assertTrue(re.match(got[4].split('\t')[3], 'passed: foo'))
        self.assertFalse(re.match(got[4].split('\t')[3], 'not passed: foo'))

    def test_a_test_whose_extension_the_probe_has_not(self):
        ids = ['org.x.foo']
        with self.assertRaisesRegex(ac.CheckError, 'the test test.foo needs org.x.fooHelpers, which the probe has not'):
            ac.xtalk_test_records(ids, TESTS_SCRIPT, {'test.foo': ('xtalkTestFoo', ('org.x.foo', 'org.x.fooHelpers'))})

    def test_a_test_whose_function_the_file_has_not(self):
        for script in (TESTS_SCRIPT.replace('function xtalkTestBar\n', 'function xtalkTestBarred\n'),
                       # commented out, or a private one of that name with more after it
                       TESTS_SCRIPT.replace('function xtalkTestBar\n', '-- function xtalkTestBar\n'),
                       # defined above the line the IDE script cuts at
                       'function xtalkTestBar\nend xtalkTestBar\n' +
                       TESTS_SCRIPT.replace('function xtalkTestBar\n', 'function other\n')):
            with self.assertRaisesRegex(ac.CheckError, 'defines no function xtalkTestBar'):
                ac.xtalk_test_records(['org.x.bar'], script, {'test.bar': ('xtalkTestBar', ('org.x.bar',))})

    def test_the_tests_begin_line_once(self):
        for script in (TESTS_SCRIPT.replace(ac.XTALK_TESTS_BEGIN, '-- begin'),
                       TESTS_SCRIPT + '\n%s\n' % ac.XTALK_TESTS_BEGIN,
                       # the words inside a line of prose are not the line
                       TESTS_SCRIPT.replace(ac.XTALK_TESTS_BEGIN, '-- see ' + ac.XTALK_TESTS_BEGIN)):
            with self.assertRaisesRegex(ac.CheckError, 'has not exactly one line'):
                ac.xtalk_test_records([], script, {})

    def test_list_file(self):
        with tempfile.TemporaryDirectory() as work:
            path = os.path.join(work, ac.XTALK_LIST)
            with open(path, 'w', encoding='utf-8') as f:
                f.write('extension\torg.x.foo\tfooVersion()\t^foo\ntest\ttest.foo\txtalkTestFoo()\t^passed:\n'
                        'permission\tINTERNET\n')
            # the probe says the extensions and the tests; the permissions
            # are asked of the package manager
            self.assertEqual(ac.read_xtalk_list(path), ['org.x.foo'])
            self.assertEqual(ac.read_xtalk_list(path, 'test'), ['test.foo'])
            self.assertEqual(ac.read_xtalk_list(path, 'permission'), ['INTERNET'])
            with open(path, 'w', encoding='utf-8') as f:
                f.write('permission\tINTERNET\n')
            with self.assertRaisesRegex(ac.CheckError, 'lists nothing to probe'):
                ac.read_xtalk_list(path)
            with open(path, 'w', encoding='utf-8') as f:
                f.write('extension\torg.x.foo\tfooVersion()\t^foo\n')
            self.assertEqual(ac.read_xtalk_list(path, 'permission'), [])
            self.assertEqual(ac.read_xtalk_list(path, 'test'), [])


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

    def test_a_test_that_did_not_pass(self):
        # a test's answer that is not its "passed:" is said as unexpected
        # by the probe, and one never reached is said nothing of
        said = ['xtalk org.x.foo ok: foo 1.0', 'xtalk test.foo ok: passed: a message crossed',
                'xtalk test.bar unexpected: the loopback stopped at "connecting"']
        self.assertEqual(ac.xtalk_said_problems(said, ['org.x.foo', 'test.foo', 'test.bar', 'test.baz']), [
            'the xTalk probe: test.bar unexpected: the loopback stopped at "connecting"',
            'the xTalk probe said nothing of test.baz'])

    def test_device_wants_every_test_said(self):
        source = read('tools', 'ci', 'android_check.py')
        self.assertIn("xtalk_said_problems(said, read_xtalk_list(args.xtalk) + read_xtalk_list(args.xtalk, 'test'))",
                      source)

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

    def test_the_script_libraries(self):
        self.assertEqual([e['id'] for _, e in ac.xtalk_script_extensions(self.manifest)], SCRIPTS)

    def test_every_tests_extensions_are_in_the_probe(self):
        # the real table over the real manifest and the real tests file:
        # a record for each test, in the table's order
        ids = [e['id'] for _, e, _ in ac.xtalk_android_extensions(self.manifest)] + SCRIPTS
        got = ac.xtalk_test_records(ids, read('tools', 'ci', 'android-xtalk-tests.livecodescript'))
        self.assertEqual([r.split('\t')[1] for r in got], list(ac.XTALK_TESTS))
        # every native member has a test of its own
        tested = {n for _, needs in ac.XTALK_TESTS.values() for n in needs}
        self.assertEqual(set(NATIVE.values()) - tested, set())

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
            # room for the functional tests: each of the four that wait
            # may take its whole deadline before the probe says so
            waits = int(re.search(r'constant kXtalkWait = (\d+)',
                                  read('tools', 'ci', 'android-xtalk-tests.livecodescript')).group(1)) // 1000
            self.assertGreaterEqual(int(re.search(r'--timeout (\d+)', run).group(1)), 4 * waits + 90)
        self.assertIn('screen-api33-java-xtalk.png', runs[0])
        self.assertIn('screen-16k-java-xtalk.png', runs[1])
        step16 = re.search(r'(?s)- name: Run the package with 16 KB pages\n(.*?)\n      - name:',
                           self.workflow).group(1)
        self.assertIn(runs[1], step16)

    def test_a_manifest_change_runs_it(self):
        paths = re.search(r'(?s)paths: &android-paths\n(.*?)\n  push:', self.workflow).group(1)
        self.assertIn('- tools/oxt/xtalk-extensions.json', paths)
        self.assertIn('- tools/oxt/xtalk_extensions.py', paths)
        self.assertIn('- tools/ci/android-xtalk-tests.livecodescript', paths)


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
        # every extension's smoke test, then every test, whatever the
        # file's order; a permission record is neither: device --xtalk
        # asks the package manager (androidHasPermission is empty for
        # INTERNET)
        self.assertIn('repeat for each item tKind in "extension" & tab & "test"', calls)
        self.assertIn('if item 1 of tLine is not tKind then next repeat', calls)
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

    def test_a_thrown_error_is_said_with_its_reason(self):
        # what an extension throws is the error's second line; the first
        # is the engine's own, so one line would say nothing of why
        handlers = self.body('function', 'xtalkHandlers')
        self.assertIn('"      put line 1 to 4 of tError into tError"', handlers)
        self.assertLess(handlers.index('"      replace return with"'), handlers.index('quote & "threw:" & quote'))

    def test_the_tests_are_the_stacks_own(self):
        # the tests' text is appended to the probe's script, after the
        # probe's own handlers, from the same line android_check.py cuts at
        begin = re.search(r'constant kXtalkTestsBegin = "([^"]*)"', self.script).group(1)
        self.assertEqual(begin, ac.XTALK_TESTS_BEGIN)
        tests = self.body('function', 'xtalkTests')
        self.assertIn('$OXT_ANDROID_XTALK_TESTS', tests)
        self.assertIn('line tAt of tText is not kXtalkTestsBegin', tests)
        self.assertIn('return line tAt to -1 of tText', tests)
        script = self.body('function', 'probeScript')
        self.assertLess(script.index('put return & xtalkHandlers() after tScript'),
                        script.index('put return & xtalkTests() after tScript'))
        self.assertLess(script.index('"end openStack" after tScript'),
                        script.index('put return & xtalkTests() after tScript'))
        # only an extension is a setting: a test is no extension's id
        settings = self.body('function', 'buildSettings pName')
        self.assertIn('if item 1 of tLine is "extension" then', settings)
        self.assertNotIn('"test"', settings)

    def test_a_script_that_does_not_compile_stops_the_build(self):
        make = self.body('command', 'makeProbeStack')
        self.assertIn('if tProbe is "AndroidXtalkProbe" and the result is not empty then', make)
        self.assertLess(make.index('set the script of stack tProbe to probeScript()'),
                        make.index('throw "the xTalk probe\'s script does not compile:"'))

    def test_no_extension_is_an_error(self):
        records = self.body('function', 'xtalkRecords')
        self.assertIn('if item 1 of tLine is "test" and the number of items of tLine is 4 then', records)
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
        self.assertIn("OXT_ANDROID_XTALK_TESTS=path(XTALK_TESTS_SCRIPT) if xtalk else ''", source)
        self.assertTrue(os.path.isfile(ac.XTALK_TESTS_SCRIPT))


class TheTests(unittest.TestCase):
    """android-xtalk-tests.livecodescript, held to its header's rules as far
    as its text shows them. What its functions DO is the emulators' to say
    (android.yml); this keeps a later edit from quietly dropping a rule."""

    def setUp(self):
        self.text = read('tools', 'ci', 'android-xtalk-tests.livecodescript')
        self.body = self.text.split('\n' + ac.XTALK_TESTS_BEGIN + '\n', 1)[1]
        self.functions = dict(re.findall(r'(?ms)^function (xtalkTest\w+)\n(.*?)^end \1$', self.body))

    def code(self, text):
        """The lines of text without the comments (a comment may name what
        the code may not)."""
        return '\n'.join(x for x in text.splitlines() if not x.lstrip().startswith('--'))

    def test_every_test_is_in_the_table_and_the_file(self):
        self.assertEqual(sorted(self.functions), sorted(f for f, _ in ac.XTALK_TESTS.values()))

    def test_ascii_and_unix_lines(self):
        self.assertNotIn('\r', self.text)
        self.assertEqual([c for c in self.text if ord(c) > 126 or (ord(c) < 32 and c != '\n')], [])

    def test_each_passes_by_saying_so_once(self):
        for name, body in self.functions.items():
            self.assertEqual(body.count('"%s ' % ac.XTALK_TEST_PASSED), 1, name)
            # and never by falling off its end: the last statement returns
            self.assertTrue(body.rstrip().splitlines()[-1].strip().startswith('return '), name)

    def test_nothing_waits_for_ever(self):
        waited = 0
        for name, body in self.functions.items():
            if 'wait ' not in self.code(body):
                continue
            waited += 1
            # every loop with a wait in it ends at a deadline made from
            # kXtalkWait
            for loop in re.findall(r'(?ms)^   repeat (.*?)\n(.*?)^   end repeat$', self.code(body)):
                if 'wait ' in loop[1]:
                    self.assertIn('the milliseconds > tDeadline', loop[0], name)
            self.assertIn('put the milliseconds + kXtalkWait into tDeadline', body, name)
        # ENet, WebRTC, the torrent session and the request to the app's
        # own server: android.yml's --timeout counts on four
        self.assertEqual(waited, 4)
        self.assertNotIn('wait until', self.code(self.body))
        self.assertNotIn('wait for', self.code(self.body))

    def test_no_host_but_the_loopback(self):
        code = self.code(self.body)
        # 0.0.0.0 is no host: it is the one listener on every address the
        # device has, the torrent session's, whose test is that the
        # library finds those addresses (the next test). Nothing connects
        # to it and nothing is told its port
        self.assertEqual(set(re.findall(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', code)),
                         {'127.0.0.1', '0.0.0.0'})
        self.assertEqual([line.strip() for line in code.splitlines() if '0.0.0.0' in line],
                         ['btSetString tSession, "listen_interfaces", "0.0.0.0:0"'])
        self.assertEqual(set(re.findall(r'[a-z]+://[^" ]*', code)), {'http://127.0.0.1:'})
        # no tracker, no DHT, no discovery on the local network, no port
        # asked of a router
        torrent = self.functions['xtalkTestTorrent']
        for setting in ('enable_dht', 'enable_lsd', 'enable_upnp', 'enable_natpmp'):
            self.assertIn('btSetBool tSession, "%s", false' % setting, torrent)
        self.assertIn('btSetString tSession, "listen_interfaces", "0.0.0.0:0"', torrent)
        self.assertIn('btCreateTorrent(tFolder & "/content.bin", 0, 0, empty)', torrent)
        # no ICE server: the two peers find each other on the device
        self.assertEqual(self.functions['xtalkTestDataChannel'].count('dcCreatePeer(empty)'), 2)

    def test_a_session_born_paused_fails(self):
        # torrentxt built for an Android older than 7.0 gave a session
        # born paused, listening nowhere, on Android 11 and later (the
        # tests file says why). While those libraries were pinned the test
        # resumed the session, listened on the loopback and said that it
        # had to; with the libraries built for API 24 pinned it does
        # neither, so that the old libraries, or the limit come back by
        # another road, fail it
        torrent = self.code(self.functions['xtalkTestTorrent'])
        self.assertNotIn('btSessionResume', torrent)
        self.assertNotIn('KNOWN LIMIT', self.body)
        lines = torrent.splitlines()
        asked = lines.index('   if btSessionIsPaused(tSession) then')
        closed = lines.index('   end if', asked)
        added = [i for i, line in enumerate(lines) if 'put btAddTorrentFile(' in line]
        self.assertEqual(len(added), 1)
        # asked before a torrent is added, and of the session as it was
        # born: nothing between its start and the question starts it
        self.assertLess(closed, added[0])
        started = [i for i, line in enumerate(lines) if 'btStartSession()' in line][0]
        for line in lines[started:asked]:
            self.assertNotRegex(line, r'bt(Session)?(Resume|Pause)\b')
        # and paused is an answer that does not begin "passed:"
        block = [line.strip() for line in lines[asked + 1:closed]]
        returns = [line for line in block if line.startswith('return ')]
        self.assertEqual(len(returns), 1)
        self.assertTrue(returns[0].startswith('return "btStartSession answered a session that is paused'), returns[0])
        # a pass needs a port as well as a seeding torrent, and the
        # address it listens on is every one (test_no_host_but_the_loopback
        # holds the setting): on the loopback alone a library that finds
        # none of the device's addresses passed
        self.assertIn('if tTorrent > 0 and tStatus["isSeeding"] is 1 and tPort > 0 and', torrent)
        self.assertIn('if tStatus["isSeeding"] is 1 and tPort > 0 then exit repeat', torrent)
        self.assertIn('put "the session listens on no port after"', torrent)
        # and what a torrent that never seeds leaves behind: its error, and
        # what the session said while the test waited
        self.assertIn('repeat for each element tEvent in btPoll(tSession)', torrent)
        self.assertIn('pStatus["error"]', self.body)
        self.assertEqual(torrent.count('"; the session said:" && tEvents'), 2)

    def test_files_only_where_the_app_may_write(self):
        code = self.code(self.body)
        # a file: or binfile: URL is of the test's folder, and so is every
        # path a test hands a library (a literal that starts with a slash;
        # the one that does not is the request's path on the app's server)
        for path in re.findall(r'"(?:bin)?file:"\s*&\s*(\S+)', code):
            self.assertEqual(path, 'tFolder')
        # and no path is written into a URL's literal ("binfile:/sdcard/x")
        self.assertEqual(set(re.findall(r'"(?:bin)?file:[^"]*"', code)) - {'"binfile:"', '"file:"'}, set())
        literals = [m for m in re.finditer(r'"/[^"]*"', code) if m.group(0) != '"/xtalk?probe=1"']
        self.assertGreaterEqual(len(literals), 8)
        for m in literals:
            before = code[:m.start()]
            self.assertTrue(before.endswith('tFolder & ') or before.endswith('xtalkTestFolder() & '),
                            code[max(0, m.start() - 40):m.end()])
        # the folder is the app's own on Android, which has no /tmp
        folder = re.search(r'(?s)private function xtalkTestFolder\n(.*?)\nend xtalkTestFolder', self.body).group(1)
        self.assertIn('if the platform is "android" then\n      return specialFolderPath("documents")', folder)
        # and what a test writes it deletes
        made = set(re.findall(r'(?:"binfile:" & )?tFolder & "(/[^"]*)"(?:\) into|, tKey$)', code, re.M))
        # and every file a test writes through a URL
        made |= set(re.findall(r'into url \("binfile:" & tFolder & "(/[^"]*)"\)', code))
        gone = set(re.findall(r'delete file tFolder & "(/[^"]*)"', code))
        self.assertTrue(gone and made <= gone, (made, gone))

    def test_digests_are_compared_as_text(self):
        # a hex digest beside "is" or "=" is compared as a number when it
        # reads as one: every 64-digit literal (and every 40-digit one, a
        # SHA-1 such as the audio test's) is an argument of xtalkSame or a
        # seed handed to a library
        for m in re.finditer(r'"(?:[0-9a-f]{40}|[0-9a-f]{64})"', self.code(self.body)):
            before = self.code(self.body)[:m.start()].rstrip(' \\\n')
            self.assertTrue(before.endswith(',') or before.endswith('(') or before.endswith('&'), before[-60:])
        self.assertIn('return ("x" & pA) is ("x" & pB)', self.body)

    def test_no_one_line_if_above_an_else(self):
        # "if x then y" on one line takes a following "else" as its own,
        # and the block it sat in is then never closed: the file's first
        # version did not compile for that
        lines = self.code(self.body).splitlines()
        for i, line in enumerate(lines[:-1]):
            if re.match(r'\s*if .* then \S', line) and not line.rstrip().endswith('\\'):
                self.assertFalse(re.match(r'\s*else\b', lines[i + 1]), line)

    def test_what_a_test_starts_it_stops(self):
        # the call that starts a library, the one that stops it, and how
        # many returns after the start are the start itself failing (no
        # session, so none to stop); a list of them for a test that starts
        # two things, as xlsxt's writes a workbook and then opens a reader
        # of its file, and webpxt's writes an animation (finishing it
        # closes its writer, whatever comes of that) and then opens a
        # reader of it
        pairs = {'xtalkTestEnet': ('enInitialize()', 'get enDeinitialize()', 0),
                 'xtalkTestDataChannel': ('dcInit()', 'get dcCleanup()', 0),
                 'xtalkTestCurl': ('cuInitialize()', 'get cuCleanup()', 0),
                 'xtalkTestTorrent': ('btStartSession()', 'btStopSession tSession', 1),
                 'xtalkTestAudio': ('auEngineCreateOffline(', 'auShutDown', 1),
                 'xtalkTestXlsx': [('xlWorkbookNew(', 'put xlWorkbookClose(tBook) into tWrote', 1),
                                   ('xlReadOpen(', 'xlReadClose tReader', 0)],
                 'xtalkTestRender3d': ('r3SceneCreate()', 'r3SceneDestroy tScene', 1),
                 'xtalkTestWebp': [('wpAnimEncoderCreate(', 'put wpAnimEncoderFinish(tWriter) into tAnimation', 0),
                                   ('wpAnimOpen(', 'wpAnimClose tAnim', 0)]}
        held = [(name, p) for name, ps in pairs.items() for p in (ps if isinstance(ps, list) else [ps])]
        for name, (start, stop, skipped) in held:
            lines = self.code(self.functions[name]).splitlines()
            at = [i for i, x in enumerate(lines) if start in x]
            self.assertEqual(len(at), 1, name)
            after = lines[at[0] + 1:]
            returns = [i for i, x in enumerate(after) if re.search(r'(^|\bthen )\s*return\b', x)][skipped:]
            # the one at the end, and any that give up early
            self.assertGreaterEqual(len(returns), 1, name)
            self.assertEqual(returns[-1], len(after) - 1, name)
            for i in returns:
                indent = len(after[i]) - len(after[i].lstrip())
                self.assertTrue(after[i].lstrip().startswith('return '), '%s: %s' % (name, after[i].strip()))
                if indent == 3:
                    # the function's last statement: stopped at this depth
                    block = [x for x in after[:i] if len(x) - len(x.lstrip()) == 3]
                else:
                    # inside a block: stopped within it, above the return
                    opener = max(j for j in range(i) if after[j].strip() and
                                 len(after[j]) - len(after[j].lstrip()) < indent)
                    block = after[opener:i]
                self.assertIn(stop, [x.strip() for x in block], '%s: the return on "%s" leaves it started' % (
                    name, after[i].strip()[:50]))
