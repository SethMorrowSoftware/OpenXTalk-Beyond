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

"""The IDE's Android builder (the Android plan's phase 0), read as source:
what Android and Google Play need of the package it makes, and what must
stay as it was for the stacks people have. android.yml builds real packages
with it (tools/ci/android_check.py); these hold the pieces that a build
would not notice going back:

  - the package is aligned before it is signed, signed with apksigner, and
    the signature checked; the passwords never reach a command line;
  - the debug key signs Test builds and "Sign for development only" ones;
  - no shell zip, sh or find (none of them is there on Windows);
  - the push receiver says android:exported;
  - a stack that saved no architecture still builds for armv7 alone (the
    card, not the builder, ticks arm64 for a new one), and the target API
    and the minimum API list stay as they were.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
BUILDER = ('ide-support', 'revsaveasandroidstandalone.livecodescript')
DEPLOY = ('ide-support', 'revdeploylibraryandroid.livecodescript')
CARD = ('ide', 'Toolset', 'palettes', 'standalone settings', 'revstandalonesettingsandroidbehavior.livecodescript')


def read(parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8-sig') as f:
        return f.read()


def code(text):
    """The script without its comment lines and trailing comments (-- and
    //, outside strings), joined across continuation lines"""
    out = []
    for line in text.split('\n'):
        s = line.strip()
        if s.startswith('--') or s.startswith('//') or s.startswith('#'):
            continue
        # a trailing comment outside quotes
        quoted = False
        for i, c in enumerate(line):
            if c == '"':
                quoted = not quoted
            elif not quoted and line.startswith('--', i):
                line = line[:i]
                break
        out.append(line)
    return re.sub(r'\\\s*\n\s*', ' ', '\n'.join(out))


def handler(text, name):
    m = re.search(r'(?ms)^(?:private\s+)?(?:command|function|on)\s+%s\b.*?^end\s+%s\b' % (name, name), text)
    if not m:
        raise AssertionError('no handler %s' % name)
    return m.group(0)


class Signing(unittest.TestCase):
    def setUp(self):
        self.src = code(read(BUILDER))

    def test_zipalign_before_apksigner_and_verify_after(self):
        align = self.src.find('pathToZipAlign(), "-f", "-p", "4"')
        sign = self.src.find('pathToApkSigner(), "sign"')
        verify = self.src.find('pathToApkSigner(), "verify"')
        self.assertGreater(align, 0, 'zipalign -f -p 4')
        self.assertGreater(sign, align, 'apksigner sign after zipalign')
        self.assertGreater(verify, sign, 'apksigner verify after signing')

    def test_no_password_on_a_command_line(self):
        self.assertNotIn('"pass:"', self.src)
        self.assertIn('"--ks-pass", "env:OXT_ANDROID_KS_PASS"', self.src)
        self.assertIn('"--key-pass", "env:OXT_ANDROID_KEY_PASS"', self.src)
        # and emptied again
        self.assertIn('put empty into $OXT_ANDROID_KS_PASS', self.src)
        self.assertIn('put empty into $OXT_ANDROID_KEY_PASS', self.src)

    def test_no_jarsigner(self):
        self.assertNotIn('pathToJarSigner()', self.src)
        self.assertNotIn('SHA1withRSA', self.src)

    def test_who_signs(self):
        main = handler(self.src, 'revSaveAsMobileStandaloneMain')
        # the user's key only for a build with a keystore, nothing for a
        # build without one that is not for development, the debug key
        # for the rest (Test, and "Sign for development only")
        m = re.search(r'if pTarget contains "build" and tUnsigned then\s+if tKey is not empty then\s+'
                      r'put "key" into tSigning\s+else\s+put "none" into tSigning', main)
        self.assertTrue(m, 'the choice of key')
        self.assertRegex(main, r'else\s+put "debug" into tSigning')
        self.assertIn('put pathToDebugKeystore() into tKey', main)
        self.assertIn('put "androiddebugkey" into tKeystoreAlias', main)
        # as before: "Sign for development only" builds are not "unsigned"
        self.assertRegex(main, r'case "sign for development only"\s+put false into tUnsigned')

    def test_debug_keystore_made_as_android_studio_makes_it(self):
        made = handler(self.src, 'ensureDebugKeystore')
        for part in ('"-genkeypair"', '"androiddebugkey"', '"CN=Android Debug,O=Android,C=US"', '"-storepass", "android"'):
            self.assertIn(part, made)

    def test_one_file_out(self):
        self.assertIn('delete file (pApkFile & ".idsig")', self.src)


class JavaForSdkScripts(unittest.TestCase):
    """d8 and apksigner are scripts that run JAVA_HOME's java before the
    PATH's: the JDK of Preferences must reach them through JAVA_HOME too
    (Windows runners: JAVA_HOME at Java 8 made d8 fail), and never replace
    a newer one"""

    def setUp(self):
        self.src = code(read(BUILDER))
        self.shell = handler(self.src, 'doShellCommand')

    def test_java_home_set_around_the_command_and_put_back(self):
        choose = self.shell.find('put androidJavaHomeFor(sJavaRoot, tOldJavaHome) into tJavaHome')
        set_ = self.shell.find('put tJavaHome into $JAVA_HOME')
        run = self.shell.find('get shell(')
        back = self.shell.find('put tOldJavaHome into $JAVA_HOME')
        self.assertGreater(choose, 0)
        self.assertGreater(set_, choose)
        self.assertGreater(run, set_, 'JAVA_HOME is set before the command runs')
        self.assertGreater(back, run, 'and put back after it')
        # only a JAVA_HOME that was changed is put back (an unset one stays unset)
        self.assertRegex(self.shell, r'put tJavaHome is not tOldJavaHome into tSetJavaHome')
        self.assertEqual(len(re.findall(r'if tSetJavaHome then', self.shell)), 2)

    def test_never_an_older_java(self):
        choose = handler(self.src, 'androidJavaHomeFor')
        self.assertRegex(choose, r'if pJdk is empty or pJavaHome is empty then\s+return pJavaHome')
        self.assertRegex(choose, r'if tJdkVersion is empty or tHomeVersion is empty then\s+return pJavaHome')
        self.assertRegex(choose, r'if tJdkVersion >= tHomeVersion then\s+return pJdk\s+end if\s+return pJavaHome')

    def test_version_from_the_release_file(self):
        version = handler(self.src, 'javaMajorVersion')
        self.assertIn('put "/release" after tFile', version)
        self.assertIn('if tLine begins with "JAVA_VERSION=" then', version)
        # 1.8.0_x is 8
        self.assertRegex(version, r'if item 1 of tVersion is "1" then\s+put item 2 of tVersion into tVersion')


class NoShellTools(unittest.TestCase):
    def test_no_zip_sh_or_find(self):
        src = code(read(BUILDER))
        for bad in (r'shell\("find', r'"zip"', r'executeShellCommand "zip"', r'"sh", "-c"', r'"/bin/sh"',
                    r'shell\("zip', r'shell\("cd '):
            self.assertIsNone(re.search(bad, src), bad)
        build = handler(src, 'buildAPK')
        self.assertIn('revZipOpenArchive', build)
        self.assertIn('revZipAddItemWithFile', build)


class Manifest(unittest.TestCase):
    def test_push_receiver_exported(self):
        src = read(BUILDER)
        line = [x for x in src.split('\n') if '"PushReceiver"&quote&"' in x and '<receiver' in x]
        self.assertEqual(len(line), 1)
        self.assertIn('android:exported="&quote&"true"&quote&"', line[0])

    def test_warns_about_merged_components(self):
        src = code(read(BUILDER))
        main = handler(src, 'revSaveAsMobileStandaloneMain')
        self.assertIn('androidComponentsWithoutExported(androidManifestToArray(tManifestFile))', main)
        comps = handler(src, 'androidComponentsWithoutExported')
        self.assertIn('"activity,activity-alias,service,receiver"', comps)


class Compatibility(unittest.TestCase):
    def test_builder_falls_back_to_armv7_alone(self):
        main = handler(code(read(BUILDER)), 'revSaveAsMobileStandaloneMain')
        m = re.search(r'if the number of elements of tArchABIs is 0 then\s+put true into tArchABIs\["armeabi-v7a"\]\s+'
                      r'put true into tArchs\["armv7"\]\s+end if', main)
        self.assertTrue(m, 'a stack with no architecture saved builds for armv7, as before')

    def test_64bit_warnings_only_warn(self):
        src = code(read(BUILDER))
        for name in ('androidWarnMissing64Bit', 'androidWarnMissingExtensionCode'):
            body = handler(src, name)
            self.assertIn('revStandaloneAddWarning', body)
            self.assertNotIn('throw', body)
            self.assertNotRegex(body, r'put .* into (?:p|x)[A-Z]', name + ' changes nothing it is given')

    def test_card_ticks_arm64_with_armv7_only_when_nothing_is_saved(self):
        card = code(read(CARD))
        m = re.search(r'if not tEnabled and tSettings\["android"\] is true then(.*?)end if', card, re.S)
        self.assertTrue(m)
        self.assertIn('put true into tSettings["Android,armv7"]', m.group(1))
        self.assertIn('put true into tSettings["Android,arm64"]', m.group(1))

    def test_target_and_minimum_apis_unchanged(self):
        deploy = code(read(DEPLOY))
        self.assertIn('constant kDeployAndroidTargetSDK = "33"', deploy)
        versions = handler(deploy, 'deployGetVersionsMap')
        apis = sorted(int(x) for x in re.findall(r'into tMap\[(\d+)\]', versions))
        # 21 to 34, as released: no minimum above the target is added in
        # phase 0 (the target moves first)
        self.assertEqual(apis, list(range(21, 35)))

    def test_sdk_check_keeps_its_answer(self):
        deploy = code(read(DEPLOY))
        self.assertRegex(handler(deploy, 'deployIsValidSDK'), r'return deployCheckSDK\(pPath\) is empty')
        check = handler(deploy, 'deployCheckSDK')
        # the old checks, in their order, then apksigner
        order = [check.find(x) for x in ('"platforms"', '"platform-tools"', 'pathToRootPlatform(pPath)',
                                         'pathToRootClasses(pPath)', 'pathToAapt(pPath)', 'pathToAdb(pPath)',
                                         'pathToZipAlign(pPath)', 'pathToDex(pPath)', 'pathToApkSigner(pPath)')]
        self.assertNotIn(-1, order)
        self.assertEqual(order, sorted(order))

    def test_target_platform_first(self):
        root = handler(code(read(DEPLOY)), 'pathToRootPlatform')
        first = root.find('if there is a folder tPath then')
        scan = root.find('repeat for each line tFolder in folders(')
        self.assertGreater(first, 0)
        self.assertGreater(scan, first, 'the target API\'s platform is taken before any newer one')


if __name__ == '__main__':
    unittest.main()
