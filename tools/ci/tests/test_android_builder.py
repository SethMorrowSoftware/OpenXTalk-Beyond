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
    card, not the builder, ticks arm64 for a new one), and the minimum API
    list stays as it was;
  - the target API: 33, as before, with a runtime whose Java layer is not
    ready for newer, 36 with one that is (known by the classes it has for
    it), or the stack's pin from 33 to 36; and at 36 the manifest keeps the
    stack's orientation on large screens;
  - the App Bundle: only for a build whose stack asks for one, from the
    package's files before zipalign, signed with the package's key after
    the package (jarsigner, the passwords never on a command line); the
    bundletool it runs is checked against its pinned SHA-256 before it is
    kept or used, and a download that fails is tried again, the second
    time through the JDK's own HTTP client; and an SDK without aapt2 still
    builds packages;
  - the Android card's "App Bundle" box stores the setting the builder
    reads, and shows it; a stack that never ticks it has no bundle;
  - the engine runs once in a process: the manifest lists the
    configuration changes the app goes on through (LiveCode's four first),
    and declares the activity that starts it again in a new process only
    where the runtime's Java layer has it;
  - every class it compiles is compiled for Java 8, the R classes of an
    extension's .aar too, which javac 9 and newer refused at 1.5;
  - the engine: LiveCode 9.6.3's, as before, unless the stack's
    "android,engine" is "beyond", OXT-Beyond's own, which the runtimes
    carry as Runtime/Android/Beyond; every file of the runtime's that the
    build takes comes from the one the stack picked.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import subprocess
import tempfile
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
        # apksigner alone signs the package; jarsigner signs only the App
        # Bundle (which apksigner cannot), never with SHA1
        self.assertNotIn('SHA1withRSA', self.src)
        main = handler(self.src, 'revSaveAsMobileStandaloneMain')
        self.assertNotIn('pathToJarSigner()', main)
        uses = [m.start() for m in re.finditer(r'pathToJarSigner\(\)', self.src)]
        bundle = handler(self.src, 'androidSignBundle')
        start = self.src.index(bundle)
        self.assertTrue(uses)
        for at in uses:
            self.assertTrue(start <= at < start + len(bundle), 'jarsigner outside androidSignBundle')

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


class JavaSource(unittest.TestCase):
    """The builder compiles its classes for Java 8, the R classes of an
    extension's .aar too. Those were compiled with -source 1.5 -target 1.5,
    which every javac since JDK 9 refuses ("Source option 5 is no longer
    supported"), while the SDK's d8 needs a newer Java than 8 (#353): an app
    with an extension that ships an .aar could not be built with any JDK."""

    def setUp(self):
        self.src = code(read(BUILDER))

    def test_every_javac_call_compiles_for_java_8(self):
        options = re.findall(r'-target (\S+) -source (\S+)', self.src)
        self.assertGreaterEqual(len(options), 6)
        self.assertEqual(set(options), {('8', '8')})

    def test_the_r_classes_compile_with_a_current_javac(self):
        # with the builder's own options, as aapt writes an R class: the
        # JDK of JAVA_HOME (the runners' 17), or the PATH's
        home = os.environ.get('JAVA_HOME', '')
        javac = shutil.which('javac', path=os.path.join(home, 'bin')) if home else None
        javac = javac or shutil.which('javac')
        if not javac or subprocess.run([javac, '-version'], stdout=subprocess.DEVNULL,
                                       stderr=subprocess.DEVNULL).returncode != 0:
            self.skipTest('no JDK (javac) here')
        params = re.search(r'put "(-target [^"]+)" into tParams\s+split tParams by space', self.src)
        self.assertTrue(params, "the R classes' javac options")
        with tempfile.TemporaryDirectory() as tmp:
            source = os.path.join(tmp, 'gen', 'com', 'example', 'R.java')
            os.makedirs(os.path.dirname(source))
            with open(source, 'w') as f:
                f.write('package com.example;\n'
                        'public final class R {\n'
                        '    public static final class string {\n'
                        '        public static final int app_name = 0x7f010000;\n'
                        '    }\n'
                        '}\n')
            classes = os.path.join(tmp, 'classes')
            os.makedirs(classes)
            done = subprocess.run([javac] + params.group(1).split(' ') + [classes, source],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
            self.assertEqual(done.returncode, 0, done.stdout)
            with open(os.path.join(classes, 'com', 'example', 'R$string.class'), 'rb') as f:
                head = f.read(8)
            # class file version 52: Java 8
            self.assertEqual(int.from_bytes(head[6:8], 'big'), 52)


JAVA = ('engine', 'src', 'java', 'com', 'runrev', 'android')
UNITS = ('tools', 'ci', 'android-check.livecodescript')


class AppBundle(unittest.TestCase):
    """The App Bundle (androidBuildBundle and its helpers). The IDE units
    (unitAppBundle in tools/ci/android-check.livecodescript) run the
    helpers on made-up files; android.yml builds a bundle, checks it
    (android_check.py verify) and installs it on the emulators as Google
    Play would"""

    def setUp(self):
        self.src = code(read(BUILDER))
        self.main = handler(self.src, 'revSaveAsMobileStandaloneMain')

    def test_only_when_the_stack_asks_and_never_for_test(self):
        self.assertRegex(self.main, r'if pTarget contains "build" and pSettings\["android,app bundle"\] is true then\s+'
                                    r'put androidBundlePath\(pApkFile\) into tBundleFile')
        # every other use waits for tBundleFile
        for m in re.finditer(r'(androidBuildBundle|androidSignBundle) ', self.main):
            before = self.main[:m.start()]
            self.assertGreater(before.rfind('if tBundleFile is not empty then'), before.rfind('end if'), m.group(1))

    def test_from_the_unsigned_package_before_zipalign(self):
        built = self.main.find('buildAPK tUnalignedApkFile, tAssetArchive, tClassesFile, tLibsBuildFolder')
        bundle = self.main.find('androidBuildBundle tUnalignedApkFile, tUnsignedBundleFile, tBuildFolder, '
                                'androidBundletoolForBuild()')
        align = self.main.find('pathToZipAlign(), "-f", "-p", "4"')
        self.assertGreater(built, 0)
        self.assertGreater(bundle, built)
        self.assertGreater(align, bundle)

    def test_signed_with_the_packages_key_after_the_package(self):
        verify = self.main.find('pathToApkSigner(), "verify", pApkFile')
        sign = self.main.find('androidSignBundle tUnsignedBundleFile, tBundleFile, tKey, tKeystoreAlias')
        self.assertGreater(verify, 0)
        self.assertGreater(sign, verify)
        part = self.main[sign - 300:sign + 400]
        self.assertIn('put tKeystorePassword into $OXT_ANDROID_KS_PASS', part)
        self.assertIn('put empty into $OXT_ANDROID_KS_PASS', part)
        self.assertIn('put empty into $OXT_ANDROID_KEY_PASS', part)
        # unsigned when the package is
        self.assertRegex(self.main, r'else if tBundleFile is not empty then\s+'
                                    r'put url \("binfile:" & tUnsignedBundleFile\) into url \("binfile:" & tBundleFile\)')
        signer = handler(self.src, 'androidSignBundle')
        self.assertIn('"-storepass:env", "OXT_ANDROID_KS_PASS", "-keypass:env", "OXT_ANDROID_KEY_PASS"', signer)
        # jarsigner answers 0 for an unsigned jar: its words decide, in English
        self.assertIn('not (tResult contains "jar verified")', signer)
        self.assertEqual(signer.count('"-J-Duser.language=en"'), 2)
        self.assertNotIn('"-strict"', signer)

    def test_warns_when_play_would_refuse_it(self):
        self.assertRegex(self.main, r'if tBundleFile is not empty and tSigning is "debug" then\s+revStandaloneAddWarning')
        self.assertRegex(self.main, r'else if tBundleFile is not empty and tSigning is "none" then\s+'
                                    r'revStandaloneAddWarning')

    def test_its_files_go(self):
        self.assertIn('if tUnsignedBundleFile is not empty and there is a file tUnsignedBundleFile then '
                      'delete file tUnsignedBundleFile', self.main)
        build = handler(self.src, 'androidBuildBundle')
        for f in ('tProtoFile', 'tModuleFile', 'tConfigFile'):
            self.assertIn('if there is a file %s then delete file %s' % (f, f), build)
        # a bundle cut short is not left behind
        self.assertRegex(build, r'if tError is not empty then\s+if there is a file pBundleFile then delete file '
                                r'pBundleFile\s+throw tError')

    def test_the_steps(self):
        build = handler(self.src, 'androidBuildBundle')
        steps = ['pathToAapt2(), "convert", "--output-format", "proto", "-o", tProtoFile, pApkFile',
                 'put androidBundleModulePath(tItem) into tPath',
                 'revZipAddUncompressedItemWithData tModuleFile, tPath, "tData"',
                 'put textEncode(androidBundleConfig(), "UTF-8") into url ("binfile:" & tConfigFile)',
                 r'pathToJava\(\), "-jar", pBundletool, "build-bundle", "--modules", tModuleFile,\s+'
                 r'"--config", tConfigFile, "--output", pBundleFile']
        at = [build.find(x) for x in steps[:-1]]
        last = re.search(steps[-1], build)
        at.append(last.start() if last else -1)
        self.assertNotIn(-1, at, steps)
        self.assertEqual(at, sorted(at))

    def test_bundletool_pinned_and_checked(self):
        self.assertIn('constant kBundletoolVersion = "1.18.3"', self.src)
        self.assertIn('constant kBundletoolURL = "https://github.com/google/bundletool/releases/download/1.18.3/'
                      'bundletool-all-1.18.3.jar"', self.src)
        self.assertRegex(self.src, r'constant kBundletoolSHA256 = "[0-9a-f]{64}"')
        # the constants come before their uses (a constant used above its
        # line is read as its own name)
        for name in ('kBundletoolVersion', 'kBundletoolURL', 'kBundletoolSHA256', 'kBundletoolTries'):
            declared = self.src.index('constant %s = ' % name)
            uses = [m.start() for m in re.finditer(r'\b%s\b' % name, self.src)
                    if not self.src.startswith('constant ', m.start() - len('constant '))]
            self.assertTrue(uses, name)
            self.assertLess(declared, min(uses), name)
            self.assertNotIn(name, self.main)
        tool = handler(self.src, 'androidBundletool')
        # the Preferences' copy as it is; the cached one only with the
        # SHA-256; a download checked before it is kept
        pref = tool.find('if pPreference is not empty then')
        cached = tool.find('if androidFileSHA256(pCacheFile) is pSHA256 then')
        fetch = tool.find('put url pURL into tData')
        check = tool.find('if tHex is not pSHA256 then')
        keep = tool.find('put tData into url ("binfile:" & pCacheFile)')
        self.assertNotIn(-1, (pref, cached, fetch, check, keep))
        self.assertLess(pref, cached)
        self.assertLess(cached, fetch)
        self.assertLess(fetch, check)
        self.assertLess(check, keep)
        self.assertIn('the socketTimeoutInterval', tool)

    def test_a_failed_download_is_tried_again(self):
        # Android builder run 42315551744: one "socket timeout" on the
        # redirect to GitHub's release assets failed the build, where the
        # run before had downloaded the same file
        self.assertIn('constant kBundletoolTries = 3', self.src)
        tool = handler(self.src, 'androidBundletool')
        loop = re.search(r'(?ms)^\s*repeat kBundletoolTries times\n(.*?)^\s*end repeat', tool)
        self.assertTrue(loop, tool)
        body = loop.group(1)
        # each try after the first waits 2 seconds, letting messages
        # through; each starts empty, and the first that brings data ends
        # the tries
        self.assertRegex(body, r'if tTries > 1 then\s+wait 2 seconds with messages')
        start = [body.find(x) for x in ('put empty into tData', 'put empty into tResult', 'put url pURL into tData')]
        self.assertNotIn(-1, start)
        self.assertEqual(start, sorted(start))
        self.assertRegex(body, r'if tResult is empty and tData is empty then\s+put "nothing came" into tResult')
        self.assertRegex(body, r'if tResult is empty then\s+exit repeat')
        # the download is tried only in the loop; the timeout is put back
        # after it, and the SHA-256 is checked after it
        self.assertEqual(tool.count('put url pURL into tData'), 1)
        after = tool[loop.end():]
        self.assertIn('set the socketTimeoutInterval to tTimeout', after)
        self.assertIn('if tHex is not pSHA256 then', after)
        self.assertRegex(after, r'put " \(tried" && tTries && "times\)" after tResult')

    def test_every_second_try_goes_through_the_jdk(self):
        # Android builder run 42321580394: libURL's download stalled three
        # times in a row on the macOS runner, where gh had fetched the
        # release from the same host in seconds; so a try that follows a
        # failed one is made with the JDK's own HTTP client, the JDK the
        # build runs bundletool with
        self.assertIn('androidBundletoolCacheFile(), kBundletoolURL, kBundletoolSHA256, pathToJava())',
                      handler(self.src, 'androidBundletoolForBuild'))
        tool = handler(self.src, 'androidBundletool')
        self.assertTrue(tool.startswith('function androidBundletool pPreference, pCacheFile, pURL, pSHA256, pJava\n'),
                        tool[:80])
        loop = re.search(r'(?ms)^\s*repeat kBundletoolTries times\n(.*?)^\s*end repeat', tool)
        self.assertTrue(loop, tool)
        body = loop.group(1)
        # the JDK on the second try (and the fourth, ...), libURL on the
        # others; the JDK's file read, and gone, whatever it held
        self.assertRegex(body, r'if tTries mod 2 is 0 and pJava is not empty then\s+'
                               r'put androidDownloadWithJava\(pJava, pURL, tPart\) into tResult\s+'
                               r'put tResult into tJavaResult\s+'
                               r'if tResult is empty then\s+put url \("binfile:" & tPart\) into tData\s+end if\s+'
                               r'if there is a file tPart then\s+delete file tPart\s+end if\s+'
                               r'else\s+try\s+put url pURL into tData')
        # each try starts empty, before either way of downloading
        self.assertLess(body.index('put empty into tResult'), body.index('if tTries mod 2 is 0'))
        self.assertEqual(tool.count('androidDownloadWithJava('), 1)
        # its file is named in the temporary folder before the tries
        self.assertIn('put specialFolderPath("temporary") & "/oxt-bundletool-" & the milliseconds & ".part" into tPart',
                      tool[:loop.start()])
        # when libURL had the last try, what the JDK said is in the error
        # too, before the count
        after = tool[loop.end():]
        self.assertRegex(after, r'if tJavaResult is not empty and tJavaResult is not tResult then\s+'
                                r'put "; and" && tJavaResult after tResult')
        self.assertLess(after.index('"; and"'), after.index('" (tried"'))

    def test_the_jdk_download(self):
        java = handler(self.src, 'androidDownloadWithJava')
        # the program goes to a file in the temporary folder; java runs it
        # with the system's proxies; its exit status and its file decide,
        # and the program's file goes either way
        steps = ['put specialFolderPath("temporary") & "/oxt-download-" & the milliseconds & ".java" into tSource',
                 'put textEncode(androidDownloadJavaSource(), "UTF-8") into url ("binfile:" & tSource)',
                 'if there is a file pFile then',
                 'executeShellCommand pJava, "-Djava.net.useSystemProxies=true", tSource, pURL, pFile',
                 'put the result into tOutput',
                 'put sShellStatus into tStatus',
                 'delete file tSource',
                 'if (tStatus is not empty and tStatus is not 0) or there is no file pFile then']
        at = [java.find(x) for x in steps]
        self.assertNotIn(-1, at, [s for s, a in zip(steps, at) if a < 0])
        self.assertEqual(at, sorted(at))
        self.assertRegex(java, r'if the result is not empty then\s+return "could not write" && tSource')
        # a failure leaves no file, and says what java printed
        self.assertRegex(java, r'or there is no file pFile then\s+if there is a file pFile then\s+delete file pFile\s+'
                               r'end if\s+return "the JDK could not download it:" && androidToolError\(tOutput\)')
        self.assertTrue(java.rstrip().endswith('return empty\nend androidDownloadWithJava'), java[-80:])

    def test_the_jdk_download_program(self):
        source = handler(self.src, 'androidDownloadJavaSource')
        m = re.search(r'(?s)put (.*) into tLines', source)
        self.assertTrue(m, source)
        # the program as the builder writes it: its strings, quote and lf
        parts = re.findall(r'"[^"]*"|\bquote\b|\blf\b|&|\S+', m.group(1))
        self.assertEqual(set(p for p in parts if not p.startswith('"')) - {'quote', 'lf', '&'}, set(), parts)
        program = ''.join({'quote': '"', 'lf': '\n', '&': ''}.get(p, p[1:-1]) for p in parts)
        self.assertTrue(program.endswith('}\n'), program)
        # it gives up on a server that sends nothing for 60 seconds (as
        # libURL does here), takes only a 200, and any failure prints one
        # line with "Error:" in it, which androidToolError picks out, and
        # exits 1
        for line in ('URLConnection connection = new URL(args[0]).openConnection();',
                     'connection.setConnectTimeout(60000);',
                     'connection.setReadTimeout(60000);',
                     'if (http.getResponseCode() != 200) {',
                     'throw new IOException(http.getResponseCode() + " " + http.getResponseMessage() + " from " + '
                     'http.getURL());',
                     'Files.copy(in, Paths.get(args[1]), StandardCopyOption.REPLACE_EXISTING);',
                     '} catch (Exception e) {',
                     'System.err.println("Error: " + e);',
                     'System.exit(1);'):
            self.assertIn('\n' + line + '\n', '\n' + '\n'.join(x.strip() for x in program.split('\n')) + '\n', line)
        # nothing turns redirects off (HttpURLConnection follows them by
        # default; GitHub answers the release URL with one)
        self.assertNotIn('setInstanceFollowRedirects', program)
        self.assertNotIn('setFollowRedirects', program)
        # balanced braces and parentheses, one class, no package (java
        # runs the file as it is)
        self.assertEqual(program.count('{'), program.count('}'))
        self.assertEqual(program.count('('), program.count(')'))
        self.assertEqual(len(re.findall(r'\bclass\b', program)), 1)
        self.assertNotIn('package ', program)

    def test_an_sdk_without_aapt2_still_builds_packages(self):
        # aapt2 is asked for only by a bundle build, not by the SDK check
        deploy = code(read(DEPLOY))
        self.assertNotIn('aapt2', handler(deploy, 'deployCheckSDK'))
        self.assertRegex(handler(deploy, 'pathToAapt2'), r'return pathToPlatformTool\(pRoot, executableName\("aapt2"\)\)')
        self.assertRegex(handler(self.src, 'androidBuildBundle'), r'if there is no file pathToAapt2\(\) then\s+throw ')

    def test_the_settings_keep_what_the_engine_reads(self):
        config = handler(self.src, 'androidBundleConfig')
        self.assertIn('quote & "uncompressNativeLibraries" & quote & ": { " & quote & "enabled" & quote & ": false }"',
                      config)
        self.assertIn('quote & "uncompressedGlob" & quote & ": [ " & quote & "assets/**" & quote & " ]"', config)
        # the assets the bundle keeps stored are the ones the package stores
        assets = handler(self.src, 'addAssetsToArchive')
        self.assertIn('revZipAddUncompressedItemWithFile pArchive, "assets/" & tFile["name"]', assets)
        self.assertNotRegex(assets, r'revZipAddItemWith')

    def test_units_run(self):
        units = read(UNITS)
        self.assertIn('unitAppBundle tWork', handler(units, 'androidUnits'))
        body = handler(units, 'unitAppBundle')
        for case in ('bundle-path', 'bundle-module-', 'bundle-config', 'bundle-sha256', 'bundletool-preference',
                     'bundletool-preference-missing', 'bundletool-download', 'bundletool-cached',
                     'bundletool-cached-wrong', 'bundletool-download-wrong', 'bundletool-no-download',
                     'bundletool-download-again', 'bundletool-java-download', 'bundletool-java-no-download',
                     'bundletool-download-java', 'bundletool-no-download-java', 'bundletool-cache-file'):
            self.assertIn('"%s' % case, body)
        # the download that works the second time: its file appears while
        # the builder pauses between the tries, from a message sent before
        # the call, to a handler that writes what the unit's SHA-256 is of
        again = body.index('"bundletool-download-again"')
        send = body.index('send "unitBundletoolAppears" to me in 500 milliseconds')
        call = body.rindex('builderCall("androidBundletool", empty, tCache, "binfile:" & tSource, tSHA)', 0, again)
        self.assertLess(body.rindex('delete file tSource', 0, send), send)
        self.assertLess(send, call)
        self.assertIn('tError contains "(tried 3 times)"', body)
        appears = handler(units, 'unitBundletoolAppears')
        self.assertIn('put "abc" into url ("binfile:" & sBundletoolSource)', appears)
        self.assertFalse(appears.startswith('private'))
        # the script local is declared above its first use (a variable
        # used above its line is another, empty one)
        uses = [m.start() for m in re.finditer(r'\bsBundletoolSource\b', units)]
        self.assertEqual(units[uses[0] - len('local '):uses[0]], 'local ')
        self.assertEqual(len(uses), 3)
        # the JDK's download, with this check's JDK: a file: URL, one that
        # is not there, and through androidBundletool a jar: URL (which
        # libURL cannot fetch, so the second try, the JDK's, brings it), and
        # one that is not there, three times
        self.assertIn('put deployCall("pathToJava", $OXT_ANDROID_JDK) into tJava', body)
        self.assertIn('builderCall("androidDownloadWithJava", tJava, fileURL(tSource), tPart)', body)
        self.assertIn('builderCall("androidDownloadWithJava", tJava, fileURL(tFolder & "/none.jar"), tPart)', body)
        self.assertIn('builderCall("androidBundletool", empty, tCache, "jar:" & fileURL(tZip) & "!/source.jar", tSHA, '
                      'tJava)', body)
        self.assertIn('builderCall("androidBundletool", empty, tCache, "jar:" & fileURL(tFolder & "/none.zip") & '
                      '"!/source.jar", tSHA, tJava)', body)
        self.assertIn('tError contains "the JDK could not download it:" and tError contains "(tried 3 times)"', body)
        # the cache the earlier units made goes first (a cached file would
        # answer without a download)
        cleared = body.find('delete file tCache', body.index('"bundletool-download-again"'))
        self.assertGreater(cleared, 0)
        self.assertLess(cleared, body.index('"bundletool-java-download"'))
        # the check's builderCall passes a fifth argument on
        call = handler(units, 'builderCall')
        self.assertIn('pArg1, pArg2, pArg3, pArg4, pArg5\n', call)
        self.assertIn('with pArg1, pArg2, pArg3, pArg4, pArg5', call)
        self.assertRegex(handler(units, 'fileURL'), r'if char 1 of pPath is slash then\s+return "file://" & pPath\s+'
                                                    r'end if\s+return "file:///" & pPath')


PATCHES = ('tools', 'oxt', 'ide-stack-patches')
SCRIPTS = ('stack-scripts', 'ide', 'Toolset', 'palettes', 'standalone settings', 'revstandalonesettings.8.rev.bst',
           'scripts')
TOUR = ('tools', 'ci', 'ui-tour.livecodescript')


def patch_lines(name):
    """A patch file's lines, without its comments"""
    return [line for line in read(PATCHES + (name,)).split('\n') if line and not line.startswith('#')]


def targets_group_rects():
    """The build targets' group's rectangle in the stack file and as the
    patches leave it ([left, top, right, bottom] each): one patch declares
    it, android-card-targets-group.txt, as the patch tool takes a patch of a
    property as applied only at its from: or to: value"""
    declaring = []
    for name in sorted(os.listdir(os.path.join(REPO, *PATCHES))):
        if not name.endswith('.txt'):
            continue
        lines = patch_lines(name)
        if 'object: group "Android Targets" of card "Android"' in lines and 'property: rect' in lines:
            declaring.append(name)
    if declaring != ['android-card-targets-group.txt']:
        raise AssertionError('the targets group\'s rect is declared by %s' % declaring)
    lines = patch_lines('android-card-targets-group.txt')
    at = lines.index('property: rect')
    return ([int(x) for x in lines[at + 1][len('from:'):].split(',')],
            [int(x) for x in lines[at + 2][len('to:'):].split(',')])


class AppBundleBox(unittest.TestCase):
    """The Android card's "App Bundle" box, made by the IDE stack patches
    android-card-app-bundle-*.txt (a copy of "Android x86_64" at the end of
    the build targets' row, and the row's script storing it; the row grown
    to hold it, which android-card-targets-group.txt declares) and shown by the
    card's behaviour. Its setting must be the
    one the builder reads, a click on it must not be taken for an
    architecture, and a stack that never ticks it must build as before. The
    UI tour clicks it in the IDE (tourAndroidAppBundle); the patch tool
    checks the stack (tools/oxt/ide-stack-patch.sh --check)."""

    def test_the_box_is_a_copy_of_a_box_without_a_script(self):
        lines = patch_lines('android-card-app-bundle-1.txt')
        self.assertIn('object: button "Android x86_64" of group "Android Targets" of card "Android"', lines)
        self.assertIn('clone: App Bundle', lines)
        self.assertEqual(lines[lines.index('property: label') + 1], 'to: App Bundle')
        self.assertIn('.aab', lines[lines.index('property: toolTip') + 1])
        # its source's script is empty, so a click goes to the row's group
        # as the architectures' do, and the copy (whose script the patch
        # tool holds to its source's) has none either
        source = read(SCRIPTS + ('stack_revStandaloneSettings_button_id_31520.livecodescript',))
        self.assertIn('> button "Android x86_64" (id 31520)', source)
        self.assertEqual(code(source).split('script "', 1)[1].split('\n', 1)[1].strip(), '')
        names = [n for n in os.listdir(os.path.join(REPO, *SCRIPTS))
                 if '> button "App Bundle" (id ' in read(SCRIPTS + (n,))]
        self.assertEqual(len(names), 1, names)
        self.assertEqual(code(read(SCRIPTS + (names[0],))).split('\n', 1)[1].strip(), '')

    def test_the_box_is_right_of_x86_64_inside_the_row(self):
        box = [int(x) for x in patch_lines('android-card-app-bundle-1.txt')[-1][3:].split(',')]
        before, after = targets_group_rects()
        # x86_64 ends at 625 (the stack's dump); the box after it on its row
        self.assertEqual(before, [111, 70, 629, 99])
        self.assertGreater(box[0], 625)
        self.assertEqual((box[1], box[3]), (75, 95))
        # the row grows to the right by the engine's margins of 4, and
        # stays inside the window (754 wide)
        self.assertEqual(after[:3], before[:2] + [box[2] + 4])
        self.assertLessEqual(after[2], 754)

    def test_a_click_stores_the_setting_the_builder_reads(self):
        lines = patch_lines('android-card-app-bundle-2.txt')
        self.assertIn('object: group "Android Targets" of card "Android"', lines)
        new = '\n'.join(line[1:-1] for line in lines[lines.index('with:') + 1:])
        box = new.index('if tTarget is "App Bundle" then')
        self.assertIn('storeSetting "app bundle", the hilite of the target', new)
        self.assertLess(box, new.index('exit mouseUp'))
        # before the architectures' line, which would take "Bundle" for one
        self.assertLess(new.index('exit mouseUp'), new.index('updateAndroidArch word 2 of tTarget'))
        # the card stores a setting under "android," and its name, and the
        # builder makes a bundle when that one is true
        self.assertIn('setSetting "android," & pName, pValue', handler(code(read(CARD)), 'storeSetting'))
        self.assertIn('pSettings["android,app bundle"] is true', code(read(BUILDER)))
        # the row's script in the stack is the patched one
        row = read(SCRIPTS + ('stack_revStandaloneSettings_group_id_31523.livecodescript',))
        self.assertIn(new, row)

    def test_the_card_shows_the_setting_and_enables_the_box_with_android(self):
        card = code(read(CARD))
        settings = handler(card, 'updateSettings')
        self.assertRegex(settings, r'set the hilited of button "App Bundle" of group "Android targets" of me to\s+'
                                   r'\(tSettings\["android,app bundle"\] is true\)')
        state = handler(card, 'updateAndroidSettingState')
        self.assertIn('set the enabled of button "App Bundle" of group "Android targets" of me to tEnabled', state)
        self.assertLess(state.index('put true into tEnabled'), state.index('"App Bundle"'))
        # an IDE whose stack has no such box opens the card as before
        for body in (settings, state):
            self.assertIn('if there is a button "App Bundle" of group "Android targets" of me then', body)

    def test_the_tour_clicks_it(self):
        tour = read(TOUR)
        step = handler(tour, 'tour_standalone_settings')
        self.assertRegex(step, r'if tCard is "Android" then\s+put tourAndroidAppBundle\(tStack\) after tFails')
        self.assertIn('throw "the Android card is not shown, so its App Bundle, engine and edge to edge boxes were not '
                      'checked"', step)
        check = handler(tour, 'tourAndroidAppBundle')
        for part in ('dispatch "mouseUp" to tBox with 1', 'dispatch "updateSettings" to tCard',
                     'the cRevStandaloneSettings["android,app bundle"] of stack kSample is not true',
                     'the cRevStandaloneSettings["android,app bundle"] of stack kSample is not false',
                     'set the customProperties["cRevStandaloneSettings"] of stack kSample to tWas',
                     'the enabled of tBox is not the enabled of group "Android Settings" of tCard'):
            self.assertIn(part, check)


class EngineBox(unittest.TestCase):
    """The Android card's "OXT-Beyond engine" box ("OXT-Beyond engine
    (preview)" until 0.2.8), made by the IDE
    stack patches android-card-engine-*.txt (a copy of "Android x86_64" in
    the build targets' group, put in the right-hand column's free row under
    the device table; the group grown to hold it; the group's script
    storing it) and shown by the card's behaviour. Ticked, the stack's
    "android,engine" setting is beyond, with which the builder takes
    OXT-Beyond's own engine; unticked it is empty, LiveCode 9.6.3's, as
    for a stack that never had the box. The UI tour clicks it in the IDE
    and checks that the group, grown over the card, takes no click from
    the controls under it (tourAndroidEngine); the patch tool checks the
    stack (tools/oxt/ide-stack-patch.sh --check)."""

    def box(self):
        lines = patch_lines('android-card-engine-1.txt')
        return [int(x) for x in lines[lines.index('property: rect') + 1][len('to:'):].split(',')]

    def test_the_box_is_a_copy_of_a_box_without_a_script(self):
        lines = patch_lines('android-card-engine-1.txt')
        self.assertIn('object: button "Android x86_64" of group "Android Targets" of card "Android"', lines)
        self.assertIn('clone: Beyond Engine', lines)
        self.assertEqual(lines[lines.index('property: label') + 1], 'to: OXT-Beyond engine')
        tip = lines[lines.index('property: toolTip') + 1]
        self.assertIn("OXT-Beyond's own Android engine", tip)
        self.assertIn("LiveCode 9.6.3's", tip)
        # a unique id of its own, as the IDE gives a new object
        ids = {}
        for name in os.listdir(os.path.join(REPO, *PATCHES)):
            if name.endswith('.txt'):
                for line in patch_lines(name):
                    if line.startswith('unique-id:'):
                        ids.setdefault(line, []).append(name)
        unique = [line for line in patch_lines('android-card-engine-1.txt') if line.startswith('unique-id:')]
        self.assertEqual(len(unique), 1)
        self.assertRegex(unique[0], r'^unique-id: \d{13}$')
        self.assertEqual(ids[unique[0]], ['android-card-engine-1.txt'])
        # its source's script is empty, so a click goes to the targets
        # group's script, and the copy (whose script the patch tool holds
        # to its source's) has none either
        names = [n for n in os.listdir(os.path.join(REPO, *SCRIPTS))
                 if '> button "Beyond Engine" (id ' in read(SCRIPTS + (n,))]
        self.assertEqual(len(names), 1, names)
        self.assertIn('> group "Android Targets" (id 31523) > button "Beyond Engine"', read(SCRIPTS + (names[0],)))
        self.assertEqual(code(read(SCRIPTS + (names[0],))).split('\n', 1)[1].strip(), '')

    def test_the_box_is_in_the_free_row_of_the_right_column(self):
        left, top, right, bottom = self.box()
        # the stack's dump: the device table's last row (Multitouch
        # Jazzhand) ends at 490, the permissions' boxes start at 418 and
        # the "Application Permissions" group, whose title is its first
        # line, at 516 (android-card-post-notifications-2.txt's from:)
        self.assertGreaterEqual(top, 490)
        self.assertEqual(left, 418)
        grown = patch_lines('android-card-post-notifications-2.txt')
        at = grown.index('object: group "Application Permissions" of group "Android Settings" of card "Android"')
        permissions = [int(x) for x in grown[at + 2][len('from:'):].split(',')]
        self.assertEqual(permissions[1], 516)
        self.assertLessEqual(bottom, permissions[1])
        # as tall as the other boxes of the card (20), and inside the
        # permissions' column and the window (754 wide); 240 wide for its
        # words, which need 190 to 211 in Linux's fonts
        self.assertEqual(bottom - top, 20)
        self.assertLessEqual(right, permissions[2])
        self.assertGreaterEqual(right - left, 230)

    def test_the_group_grows_to_hold_the_boxes(self):
        before, after = targets_group_rects()
        bundle = [int(x) for x in patch_lines('android-card-app-bundle-1.txt')[-1][3:].split(',')]
        box = self.box()
        edge = EdgeToEdgeBox.box()
        # as the engine makes it: margins of 4 past the boxes (the App
        # Bundle's right, the lowest box's bottom: the Edge to edge box's),
        # nothing else
        self.assertEqual(before, [111, 70, 629, 99])
        self.assertGreater(edge[3], box[3])
        self.assertEqual(after, [before[0], before[1], bundle[2] + 4, edge[3] + 4])
        self.assertLessEqual(after[2], 754)
        # the patch files around it in their order: the copies first, so
        # that the group has grown when its rect is declared; and the copies
        # in the order they were made, so that each gets the id it has
        names = sorted(n for n in os.listdir(os.path.join(REPO, *PATCHES)) if n.startswith('android-card-'))
        for copy in ('android-card-app-bundle-1.txt', 'android-card-engine-1.txt', 'android-card-status-bar-edge-1.txt'):
            self.assertLess(names.index(copy), names.index('android-card-targets-group.txt'))
        self.assertLess(names.index('android-card-app-bundle-1.txt'), names.index('android-card-engine-1.txt'))
        self.assertLess(names.index('android-card-engine-1.txt'), names.index('android-card-status-bar-edge-1.txt'))
        self.assertEqual(names[-1], 'android-card-targets-group.txt')
        self.assertNotIn('android-card-app-bundle-3.txt', names)
        self.assertNotIn('android-card-engine-3.txt', names)

    def test_a_click_stores_the_setting_the_builder_reads(self):
        lines = patch_lines('android-card-engine-2.txt')
        self.assertIn('object: group "Android Targets" of card "Android"', lines)
        old = '\n'.join(line[1:-1] for line in lines[lines.index('replace:') + 1:lines.index('with:')])
        new = '\n'.join(line[1:-1] for line in lines[lines.index('with:') + 1:])
        self.assertEqual(old, 'on mouseUp\n   if word 1 of the target is not "button" then')
        self.assertTrue(new.startswith('on mouseUp\n'))
        self.assertTrue(new.endswith('\n   if word 1 of the target is not "button" then'))
        # the text it replaces is not in what replaces it, so that a second
        # run finds the patch applied
        self.assertNotIn(old, new)
        self.assertRegex(code(new), r'if word 1 of the target is "button" and the short name of the target is '
                                    r'"Beyond Engine" then\s+if the hilite of the target then\s+'
                                    r'storeSetting "engine", "beyond"\s+else\s+storeSetting "engine", empty\s+'
                                    r'end if\s+exit mouseUp\s+end if')
        # the row's script in the stack is patched by both, the box's
        # branch before the architectures' line, which would take its
        # second word ("Engine") for one, and before "App Bundle"'s
        row = read(SCRIPTS + ('stack_revStandaloneSettings_group_id_31523.livecodescript',))
        self.assertIn(new, row)
        bundle = patch_lines('android-card-app-bundle-2.txt')
        self.assertIn('\n'.join(line[1:-1] for line in bundle[bundle.index('with:') + 1:]), row)
        body = code(row)
        self.assertLess(body.index('"Beyond Engine"'), body.index('if tTarget is "App Bundle" then'))
        self.assertLess(body.index('"Beyond Engine"'), body.index('updateAndroidArch word 2 of tTarget'))
        # the card stores a setting under "android," and its name; the
        # builder takes OXT-Beyond's engine for beyond and 9.6.3's for empty
        self.assertIn('setSetting "android," & pName, pValue', handler(code(read(CARD)), 'storeSetting'))
        choose = handler(code(read(BUILDER)), 'androidRuntimeFolder')
        self.assertRegex(choose, r'case empty\s+case "9.6.3"\s+return tRuntime')
        self.assertRegex(choose, r'case "beyond"\s+if there is not a folder \(tRuntime & slash & "Beyond"\) then')

    def test_the_card_shows_the_setting_and_enables_the_box_with_android(self):
        card = code(read(CARD))
        settings = handler(card, 'updateSettings')
        self.assertRegex(settings, r'set the hilited of button "Beyond Engine" of group "Android targets" of me to\s+'
                                   r'\(tSettings\["android,engine"\] is "beyond"\)')
        state = handler(card, 'updateAndroidSettingState')
        self.assertIn('set the enabled of button "Beyond Engine" of group "Android targets" of me to tEnabled', state)
        self.assertLess(state.index('put true into tEnabled'), state.index('"Beyond Engine"'))
        # an IDE whose stack has no such box opens the card as before
        for body in (settings, state):
            self.assertIn('if there is a button "Beyond Engine" of group "Android targets" of me then', body)

    def test_the_tour_clicks_it(self):
        tour = read(TOUR)
        step = handler(tour, 'tour_standalone_settings')
        self.assertRegex(step, r'if tCard is "Android" then\s+put tourAndroidAppBundle\(tStack\) after tFails\s+'
                               r'put tourAndroidEngine\(tStack\) after tFails')
        self.assertIn('throw "the Android card is not shown, so its App Bundle, engine and edge to edge boxes were not '
                      'checked"', step)
        check = handler(tour, 'tourAndroidEngine')
        for part in ('dispatch "mouseUp" to tBox with 1', 'dispatch "updateSettings" to tCard',
                     'set the cRevStandaloneSettings["android,engine"] of stack kSample to "beyond"',
                     'set the cRevStandaloneSettings["android,engine"] of stack kSample to "9.6.3"',
                     'set the cRevStandaloneSettings["android,engine"] of stack kSample to empty',
                     'the cRevStandaloneSettings["android,engine"] of stack kSample is not "beyond"',
                     'the cRevStandaloneSettings["android,engine"] of stack kSample is not empty',
                     'the cRevStandaloneSettings["android,app bundle"] of stack kSample is not tWas["android,app bundle"]',
                     'set the customProperties["cRevStandaloneSettings"] of stack kSample to tWas',
                     'the enabled of tBox is not the enabled of tSettings',
                     'put controlAtLoc(the loc of button tRow of tSettings) into tHit',
                     'set the enabled of tBox to tBoxEnabledWas',
                     'set the enabled of tSettings to tEnabledWas'):
            self.assertIn(part, check)
        # the clicks are looked at with the box enabled, as for a stack
        # built for Android (a disabled control takes none)
        self.assertLess(check.index('set the enabled of tBox to true'), check.index('controlAtLoc('))


class FirstTargetEngine(unittest.TestCase):
    """The engine a stack has once the Android card ticks its first
    architecture: OXT-Beyond's own for a stack set up for Android now, when
    the runtimes carry it, and the box ticked to show it; every stack set up
    for Android before, or that names an engine, keeps what it has, so it is
    built as before (androidEngineOnFirstTarget in the builder, from the
    settings as they were before the tick; updateAndroidArch on the card).
    The Android check's units run the handler (unitFirstTargetEngine), and
    the UI tour ticks a first architecture in the IDE for a new stack, one
    set up before and one that names 9.6.3
    (tourAndroidFirstTargetEngine)."""

    def setUp(self):
        self.builder = handler(code(read(BUILDER)), 'androidEngineOnFirstTarget')
        self.card = handler(code(read(CARD)), 'updateAndroidArch')

    def test_a_stack_set_up_before_keeps_its_engine(self):
        # an engine named, or the "android" setting (on or off), or any
        # architecture saved (ticked or not) answers what the stack has,
        # before the runtimes are looked at
        self.assertRegex(self.builder, r'^function androidEngineOnFirstTarget pSettings\s+'
                                       r'local tArch, tRuntime, tError\s+'
                                       r'if pSettings\["android,engine"\] is not empty or "android" is among the keys '
                                       r'of pSettings then\s+return pSettings\["android,engine"\]\s+end if\s+'
                                       r'repeat for each item tArch in revSBPlatformArchitectures\("Android"\)\s+'
                                       r'if \("Android," & tArch\) is among the keys of pSettings then\s+'
                                       r'return pSettings\["android,engine"\]\s+end if\s+end repeat\s+')
        # not the settings the card saves for any stack that opens it
        self.assertNotIn('billingProvider', self.builder)
        self.assertNotIn('begins with', self.builder)

    def test_a_new_stack_gets_the_engine_the_runtimes_carry(self):
        # the folder androidRuntimeFolder takes for beyond, of the runtimes
        # the build takes; without it, or without the builder's runtime
        # path, 9.6.3's (empty), so that the build does not stop
        self.assertRegex(self.builder, r'try\s+put revMobileRuntimeFolder\("build"\) into tRuntime\s+'
                                       r'catch tError\s+return empty\s+end try\s+'
                                       r'if tRuntime is not empty and there is a folder \(tRuntime & slash & "Beyond"\) then\s+'
                                       r'return "beyond"\s+end if\s+return empty\s+end androidEngineOnFirstTarget$')
        choose = handler(code(read(BUILDER)), 'androidRuntimeFolder')
        self.assertIn('there is not a folder (tRuntime & slash & "Beyond")', choose)
        self.assertIn('put revMobileRuntimeFolder(pTarget) into tRuntime', choose)
        self.assertEqual(self.builder.count('return "beyond"'), 1)

    def test_the_card_asks_before_it_saves_the_tick(self):
        # from the settings before the architecture is saved, only for a
        # tick, and with the builder's answer only when it can be had
        self.assertRegex(self.card, r'put getSettings\(\) into tSettingsA\s+'
                                    r'put tSettingsA\["android,engine"\] into tEngine\s+'
                                    r'if pBuild is true then\s+try\s+'
                                    r'put androidEngineOnFirstTarget\(tSettingsA\) into tEngine\s+'
                                    r'catch tError\s+put tSettingsA\["android,engine"\] into tEngine\s+end try\s+end if\s+'
                                    r'if tEngine is not tSettingsA\["android,engine"\] then\s+'
                                    r'put tEngine into tSettingsA\["android,engine"\]\s+end if\s+'
                                    r'put pBuild into tSettingsA\["Android",pArch\]')
        self.assertIn('local tSettingsA, tEngine, tError', self.card)
        # the box shows it once the settings are saved
        saved = self.card.index('setSettings tSettingsA')
        shown = self.card.index('set the hilited of button "Beyond Engine" of group "Android targets" of me to')
        self.assertLess(saved, shown)
        self.assertRegex(self.card[saved:], r'if there is a button "Beyond Engine" of group "Android targets" of me then\s+'
                                            r'set the hilited of button "Beyond Engine" of group "Android targets" of me to\s+'
                                            r'\(tSettingsA\["android,engine"\] is "beyond"\)\s+end if')
        # the card's first pick for a stack with Android on and no
        # architecture (initialize) saves architectures, not an engine
        self.assertNotIn('android,engine', handler(code(read(CARD)), 'initialize'))
        # the builder is in the IDE's back scripts, so the card reaches it
        home = read(('ide', 'Toolset', 'home.livecodescript'))
        self.assertIn('put return & "revsaveasandroidstandalone" after tBackList', home)

    def test_the_units_run_it(self):
        units = read(UNITS)
        body = handler(units, 'androidUnits')
        self.assertRegex(body, r'unitEngine\s+unitFirstTargetEngine\s+')
        unit = handler(units, 'unitFirstTargetEngine')
        for case in ('"first-engine-no-beyond"', '"first-engine-new"', '"first-engine-new-card-settings"',
                     '"first-engine-had-" & tArch & "-" & tEngine', '"first-engine-android-" & tEngine',
                     '"first-engine-names-" & tEngine', '"first-engine-had-armv7-names-" & tEngine'):
            self.assertIn('androidUnit ' + case, unit)
        self.assertIn('repeat for each item tArch in "armv7,arm64,x86,x86_64"', unit)
        self.assertIn('repeat for each item tEngine in "9.6.3,beyond"', unit)
        # a Beyond folder it made, it takes away; one there before, it leaves
        self.assertRegex(unit, r'put there is not a folder tBeyond into tMade\s+if tMade then')
        self.assertRegex(unit, r'if tMade then\s+removeTree tBeyond\s+end if\s+end unitFirstTargetEngine')
        self.assertEqual(unit.count('removeTree'), 1)

    def test_the_tour_ticks_a_first_architecture(self):
        tour = read(TOUR)
        engine = handler(tour, 'tourAndroidEngine')
        self.assertRegex(engine, r'put tourAndroidFirstTargetEngine\(tCard, tTargets, tBox, tWas\) after tFails\s+'
                                 r'return tFails\s+end tourAndroidEngine')
        check = handler(tour, 'tourAndroidFirstTargetEngine')
        self.assertIn('repeat for each item tCase in "new,set up before,names 9.6.3"', check)
        self.assertIn('put there is a folder (tRuntime & "/Beyond") into tBeyond', check)
        for part in ('put false into tSettings["Android,armv7"]',
                     'put "9.6.3" into tSettings["android,engine"]',
                     'dispatch "mouseUp" to button "Android arm64" of pTargets with 1',
                     'if the hilited of pBox is not (tWant is "beyond") then',
                     'set the customProperties["cRevStandaloneSettings"] of stack kSample to pWas',
                     'dispatch "updateAndroidSettingState" to pCard'):
            self.assertIn(part, check)
        # each case starts from the sample without any Android setting
        self.assertRegex(check, r'if tKey is "android" or tKey begins with "android," then\s+'
                                r'delete variable tSettings\[tKey\]')


class EdgeToEdgeBox(unittest.TestCase):
    """The Android card's "Edge to edge" box, made by the IDE stack patches
    android-card-status-bar-edge-*.txt (a copy of "Android x86_64" in the
    build targets' group, put at the end of the User Interface Options'
    Status Bar row; the group grown to hold it, which
    android-card-targets-group.txt declares; the group's script storing it)
    and shown by the card's behaviour. Ticked, the stack's "android,edge to
    edge" setting is true, with which the builder asks the Java layer to
    draw the app edge to edge (EdgeToEdge above); unticked it is false, and
    a stack that never had the box is laid out as before. The UI tour clicks
    it in the IDE (tourAndroidEdgeToEdge, and tourAndroidEngine for the
    clicks of what the grown group covers); the patch tool checks the stack
    (tools/oxt/ide-stack-patch.sh --check)."""

    @staticmethod
    def box():
        lines = patch_lines('android-card-status-bar-edge-1.txt')
        return [int(x) for x in lines[lines.index('property: rect') + 1][len('to:'):].split(',')]

    def test_the_box_is_a_copy_of_a_box_without_a_script(self):
        lines = patch_lines('android-card-status-bar-edge-1.txt')
        self.assertIn('object: button "Android x86_64" of group "Android Targets" of card "Android"', lines)
        self.assertIn('clone: Edge To Edge', lines)
        self.assertEqual(lines[lines.index('property: label') + 1], 'to: Edge to edge')
        tip = lines[lines.index('property: toolTip') + 1]
        for words in ('Android 11 and newer', 'status and navigation bars', 'effective working screenRect'):
            self.assertIn(words, tip)
        # a unique id of its own, as the IDE gives a new object
        ids = {}
        for name in os.listdir(os.path.join(REPO, *PATCHES)):
            if name.endswith('.txt'):
                for line in patch_lines(name):
                    if line.startswith('unique-id:'):
                        ids.setdefault(line, []).append(name)
        unique = [line for line in lines if line.startswith('unique-id:')]
        self.assertEqual(len(unique), 1)
        self.assertRegex(unique[0], r'^unique-id: \d{13}$')
        self.assertEqual(ids[unique[0]], ['android-card-status-bar-edge-1.txt'])
        # its source's script is empty, so a click goes to the targets
        # group's script, and the copy has none either
        names = [n for n in os.listdir(os.path.join(REPO, *SCRIPTS))
                 if '> button "Edge To Edge" (id ' in read(SCRIPTS + (n,))]
        self.assertEqual(len(names), 1, names)
        self.assertIn('> group "Android Targets" (id 31523) > button "Edge To Edge"', read(SCRIPTS + (names[0],)))
        self.assertEqual(code(read(SCRIPTS + (names[0],))).split('\n', 1)[1].strip(), '')

    def test_the_box_is_at_the_end_of_the_status_bar_row(self):
        left, top, right, bottom = self.box()
        # the stack's dump, as standalone-settings-fit-linux.txt leaves the
        # row: the Status Bar group ends at 270, its radio buttons run from
        # 561 to 584; the box comes after them, in their middle
        fit = patch_lines('standalone-settings-fit-linux.txt')
        at = fit.index('object: group id 2246 of card "Android"')
        status = [int(x) for x in fit[at + 3][len('to:'):].split(',')]
        at = fit.index('object: button id 2248 of card "Android"')
        hidden = [int(x) for x in fit[at + 3][len('to:'):].split(',')]
        self.assertEqual((status[2], hidden[1], hidden[3]), (270, 561, 584))
        self.assertGreater(left, status[2])
        self.assertLessEqual(hidden[1], (top + bottom) / 2)
        self.assertLessEqual((top + bottom) / 2, hidden[3])
        # as tall as the other boxes of the card (20), 120 wide for its
        # words (they need 105 in Linux's DejaVu Sans, the UI tour's
        # tourButtonsWhole), before the "Application Permissions" group
        # (398, android-card-post-notifications-2.txt's from:), whose
        # boxes start at 418, and inside the window (754 wide)
        self.assertEqual(bottom - top, 20)
        self.assertEqual(right - left, 120)
        grown = patch_lines('android-card-post-notifications-2.txt')
        at = grown.index('object: group "Application Permissions" of group "Android Settings" of card "Android"')
        permissions = [int(x) for x in grown[at + 2][len('from:'):].split(',')]
        self.assertEqual(permissions[0], 398)
        self.assertLess(right, permissions[0])

    def test_a_click_stores_the_setting_the_builder_reads(self):
        lines = patch_lines('android-card-status-bar-edge-2.txt')
        self.assertIn('object: group "Android Targets" of card "Android"', lines)
        old = '\n'.join(line[1:-1] for line in lines[lines.index('replace:') + 1:lines.index('with:')])
        new = '\n'.join(line[1:-1] for line in lines[lines.index('with:') + 1:])
        self.assertEqual(old, '   \n   local tTarget')
        self.assertTrue(new.endswith('\n   local tTarget'))
        # the text it replaces is not in what replaces it, so that a second
        # run finds the patch applied
        self.assertNotIn(old, new)
        self.assertRegex(code(new), r'if the short name of the target is "Edge To Edge" then\s+'
                                    r'storeSetting "edge to edge", the hilite of the target\s+exit mouseUp\s+end if')
        # the row's script in the stack is patched by all three, the box's
        # branch after the engine box's and the check that the target is a
        # button, before the architectures' line, which would take its
        # second word ("To") for one, and before "App Bundle"'s
        row = read(SCRIPTS + ('stack_revStandaloneSettings_group_id_31523.livecodescript',))
        self.assertIn(new, row)
        for name in ('android-card-engine-2.txt', 'android-card-app-bundle-2.txt'):
            other = patch_lines(name)
            self.assertIn('\n'.join(line[1:-1] for line in other[other.index('with:') + 1:]), row)
        body = code(row)
        self.assertLess(body.index('"Beyond Engine"'), body.index('"Edge To Edge"'))
        self.assertLess(body.index('if word 1 of the target is not "button" then'), body.index('"Edge To Edge"'))
        self.assertLess(body.index('"Edge To Edge"'), body.index('if tTarget is "App Bundle" then'))
        self.assertLess(body.index('"Edge To Edge"'), body.index('updateAndroidArch word 2 of tTarget'))
        # the card stores a setting under "android," and its name; the
        # builder asks the Java layer for edge to edge when it is true
        self.assertIn('setSetting "android," & pName, pValue', handler(code(read(CARD)), 'storeSetting'))
        self.assertIn('if pSettings["android,edge to edge"] is not true then',
                      handler(code(read(BUILDER)), 'androidAskForEdgeToEdge'))

    def test_the_card_shows_the_setting_and_enables_the_box_with_android(self):
        card = code(read(CARD))
        settings = handler(card, 'updateSettings')
        self.assertRegex(settings, r'set the hilited of button "Edge To Edge" of group "Android targets" of me to\s+'
                                   r'\(tSettings\["android,edge to edge"\] is true\)')
        state = handler(card, 'updateAndroidSettingState')
        self.assertIn('set the enabled of button "Edge To Edge" of group "Android targets" of me to tEnabled', state)
        self.assertLess(state.index('put true into tEnabled'), state.index('"Edge To Edge"'))
        # an IDE whose stack has no such box opens the card as before
        for body in (settings, state):
            self.assertIn('if there is a button "Edge To Edge" of group "Android targets" of me then', body)

    def test_the_tour_clicks_it(self):
        tour = read(TOUR)
        step = handler(tour, 'tour_standalone_settings')
        self.assertRegex(step, r'if tCard is "Android" then\s+put tourAndroidAppBundle\(tStack\) after tFails\s+'
                               r'put tourAndroidEngine\(tStack\) after tFails\s+'
                               r'put tourAndroidEdgeToEdge\(tStack\) after tFails')
        check = handler(tour, 'tourAndroidEdgeToEdge')
        for part in ('dispatch "mouseUp" to tBox with 1', 'dispatch "updateSettings" to tCard',
                     'set the cRevStandaloneSettings["android,edge to edge"] of stack kSample to true',
                     'set the cRevStandaloneSettings["android,edge to edge"] of stack kSample to false',
                     'set the cRevStandaloneSettings["android,edge to edge"] of stack kSample to empty',
                     'the cRevStandaloneSettings["android,edge to edge"] of stack kSample is not true',
                     'the cRevStandaloneSettings["android,edge to edge"] of stack kSample is not false',
                     'repeat for each item tArch in "app bundle,engine"',
                     'set the customProperties["cRevStandaloneSettings"] of stack kSample to tWas',
                     'the enabled of tBox is not the enabled of tSettings',
                     'item 1 of the rect of tBox < item 3 of the rect of tStatus',
                     'item 3 of the rect of tBox > item 1 of the rect of group "Application Permissions" of tSettings'):
            self.assertIn(part, check)


class TargetAPI(unittest.TestCase):
    """The API a package targets (androidTargetAPI). The IDE units
    (unitTargetAPI in tools/ci/android-check.livecodescript) run these
    handlers on made-up runtimes; android.yml builds and runs a package of
    each kind"""

    def setUp(self):
        self.src = code(read(BUILDER))
        self.deploy = code(read(DEPLOY))

    def test_oldest_and_newest(self):
        self.assertIn('constant kDeployAndroidTargetSDK = "33"', self.deploy)
        self.assertIn('constant kDeployAndroidNewestTargetSDK = "36"', self.deploy)
        self.assertRegex(handler(self.deploy, 'deployNewestTargetSdkVersion'),
                         r'return kDeployAndroidNewestTargetSDK\s+end')
        self.assertRegex(handler(self.src, 'newestTargetSDKVersion'),
                         r'dispatch function "deployNewestTargetSdkVersion" to stack kDeployLibrary\s+'
                         r'return the result')

    def test_the_manifest_takes_it(self):
        main = handler(self.src, 'revSaveAsMobileStandaloneMain')
        choose = main.find('put androidTargetAPI(pSettings, tRuntime) into tTargetAPI')
        use = main.find('replace "${TARGET_SDK_VERSION}" with tTargetAPI in tManifest')
        large = main.find('put androidKeepLargeScreenLayout(tManifest, tTargetAPI) into tManifest')
        saved = main.find('put tManifest into url ("binfile:" & tManifestFile)')
        self.assertGreater(choose, 0)
        self.assertGreater(use, choose)
        self.assertGreater(large, use)
        self.assertGreater(saved, large, 'the property is in the manifest that is saved')
        self.assertNotIn('with targetSDKVersion() in tManifest', main)

    def test_the_choice(self):
        choose = handler(self.src, 'androidTargetAPI')
        # a pin first: an integer from the oldest to the newest, else an
        # error that stops the build; then the newest for a ready Java
        # layer, else the oldest, as before
        self.assertRegex(choose, r'put pSettings\["android,target sdk"\] into tPin\s+if tPin is not empty then\s+'
                                 r'if tPin is not an integer or tPin < targetSDKVersion\(\) or '
                                 r'tPin > newestTargetSDKVersion\(\) then\s+throw ')
        self.assertRegex(choose, r'return tPin \+ 0\s+end if\s+'
                                 r'if androidJavaLayerIsReady\(pRuntimeFolder\) then\s+'
                                 r'return newestTargetSDKVersion\(\)\s+end if\s+return targetSDKVersion\(\)\s+end')

    def test_ready_is_known_by_classes_the_java_layer_has(self):
        # the names the builder looks for are classes of this checkout's
        # Java layer (LiveCodeActivity's back callback and its padding of
        # the stack inside the system bars): renamed, the builder would
        # quietly target 33 again
        names = re.search(r'constant kJavaLayerReady = "([^"]+)"', self.src).group(1).split(',')
        self.assertEqual(len(names), 2)
        activity = read(JAVA + ('LiveCodeActivity.java',))
        for name in names:
            m = re.match(r'^com/runrev/android/LiveCodeActivity\$(\w+)\.class$', name)
            self.assertTrue(m, name)
            self.assertRegex(activity, r'(?m)^\s+(?:protected |private |public )?static class %s\b' % m.group(1))
        ready = handler(self.src, 'androidJavaLayerIsReady')
        self.assertRegex(ready, r'^function androidJavaLayerIsReady pRuntimeFolder\s+'
                                r'return androidJavaLayerHas\(pRuntimeFolder, kJavaLayerReady\)\s+end')
        has = handler(self.src, 'androidJavaLayerHas')
        self.assertIn('put mapFilePath(pRuntimeFolder & slash & "Classes") into tJar', has)
        self.assertRegex(has, r'if there is no file tJar then\s+return false')
        self.assertRegex(has, r'repeat for each item tEntry in pClasses\s+'
                              r'if byteOffset\(textEncode\(tEntry, "UTF-8"\), tJar\) is 0 then\s+return false')

    def test_large_screens_only_at_36(self):
        keep = handler(self.src, 'androidKeepLargeScreenLayout')
        self.assertIn('constant kRestrictedResizability = '
                      '"android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"', self.src)
        self.assertRegex(keep, r'^function androidKeepLargeScreenLayout pManifest, pTargetAPI\s+'
                               r'if pTargetAPI < 36 then\s+return pManifest\s+end if')
        self.assertIn('replace "</application>" with tProperty & "  </application>" in pManifest', keep)

    def test_units_run(self):
        units = read(UNITS)
        body = handler(units, 'androidUnits')
        self.assertIn('unitTargetAPI tWork', body)
        target = handler(units, 'unitTargetAPI')
        for case in ('target-no-java-layer', 'target-java-layer-not-ready', 'target-java-layer-ready',
                     'target-pinned-', 'target-pin-refused-', 'large-screen-below-36', 'large-screen-36'):
            self.assertIn(case, target)


class Relaunch(unittest.TestCase):
    """The engine runs once in a process (RelaunchActivity in the Java layer
    says why). The manifest lists the configuration changes the app goes on
    through, LiveCode's four first, as before, and not the screen's density,
    for which it starts again; the activity that starts it again in a new
    process is declared where the runtime's Java layer has it, and only
    there (LiveCode Community 9.6.3's has not, and its app is built as
    before); and the Java layer starts the engine once in a process"""

    def setUp(self):
        self.src = code(read(BUILDER))

    # every android:configChanges value Android 12L (API 32) knows, below
    # the oldest target the builder makes (33): one Android added later
    # would not link against an older target's platform
    KNOWN = {'mcc', 'mnc', 'locale', 'touchscreen', 'keyboard', 'keyboardHidden', 'navigation', 'screenLayout',
             'fontScale', 'uiMode', 'orientation', 'screenSize', 'smallestScreenSize', 'layoutDirection',
             'colorMode', 'density', 'fontWeightAdjustment'}

    def test_config_changes(self):
        values = re.search(r'constant kConfigChanges = "([^"]+)"', self.src).group(1).split('|')
        # LiveCode's four, as before, first
        self.assertEqual(values[:4], ['keyboardHidden', 'orientation', 'uiMode', 'screenSize'])
        self.assertEqual(len(values), len(set(values)), values)
        self.assertLessEqual(set(values), self.KNOWN)
        # the changes that were stopped on Android 11 and newer: the font
        # size and weight, the language, a resized window, a keyboard
        for value in ('fontScale', 'fontWeightAdjustment', 'locale', 'layoutDirection', 'smallestScreenSize',
                      'screenLayout', 'keyboard', 'navigation'):
            self.assertIn(value, values)
        # the density the engine reads as it starts: the app starts again
        self.assertNotIn('density', values)
        self.assertRegex(handler(self.src, 'androidConfigChanges'),
                         r'^function androidConfigChanges\s+return kConfigChanges\s+end')
        main = handler(self.src, 'revSaveAsMobileStandaloneMain')
        self.assertRegex(main, r'put androidConfigChanges\(\) into tConfigChangesProp\s+'
                               r'replace "\$\{CONFIG_CHANGES\}" with tConfigChangesProp in tManifest')
        self.assertNotIn('"keyboardHidden|orientation|uiMode|screenSize"', main)

    def test_relaunch_declared_where_the_java_layer_has_it(self):
        declare = handler(self.src, 'androidDeclareRelaunch')
        self.assertIn('constant kRelaunchClass = "com/runrev/android/RelaunchActivity.class"', self.src)
        # nothing at all without the class: the manifest as it was
        self.assertRegex(declare, r'^function androidDeclareRelaunch pManifest, pRuntimeFolder\s+'
                                  r'if not androidJavaLayerHas\(pRuntimeFolder, kRelaunchClass\) then\s+'
                                  r'return pManifest\s+end if')
        for attr in ('android:name=" & quote & "com.runrev.android.RelaunchActivity" & quote',
                     # a process of its own, which outlives the app's
                     'android:process=" & quote & ":relaunch" & quote',
                     # no window to see, nothing in the recents list, and
                     # no other app can start it
                     'android:theme=" & quote & "@android:style/Theme.Translucent.NoTitleBar" & quote',
                     'android:excludeFromRecents=" & quote & "true" & quote',
                     'android:noHistory=" & quote & "true" & quote',
                     'android:exported=" & quote & "false" & quote'):
            self.assertIn(attr, declare)
        self.assertNotIn('intent-filter', declare)
        self.assertIn('replace "</application>" with tActivity & "  </application>" in pManifest', declare)
        # the class it names is the Java layer's
        java = read(JAVA + ('RelaunchActivity.java',))
        self.assertIn('package com.runrev.android;', java)
        self.assertRegex(java, r'public class RelaunchActivity extends Activity\b')
        # declared with the runtime the package is built with, before the
        # manifest is written
        main = handler(self.src, 'revSaveAsMobileStandaloneMain')
        declared = main.find('put androidDeclareRelaunch(tManifest, tRuntime) into tManifest')
        self.assertGreater(declared, main.find('put androidKeepLargeScreenLayout(tManifest, tTargetAPI) into tManifest'))
        self.assertLess(declared, main.find('put tManifest into url ("binfile:" & tManifestFile)'))

    def test_the_java_layer_builds_it(self):
        gyp = read(('engine', 'engine-sources.gypi'))
        self.assertIn("'src/java/com/runrev/android/RelaunchActivity.java',", gyp)

    def test_the_engine_starts_once_in_a_process(self):
        activity = read(JAVA + ('LiveCodeActivity.java',))
        create = re.search(r'(?s)protected void onCreate\(Bundle p_saved_state\)\s*\{(.*?)\n\t\}', activity).group(1)
        # the check comes first, before the engine's view is made; without
        # the declaration (relaunch answers false) it goes on as before
        self.assertRegex(create, r'^\s*super\.onCreate\(p_saved_state\);\s+(?://[^\n]*\s+)*'
                                 r'if \(s_engine_ran && RelaunchActivity\.relaunch\(this\)\)\s+return;\s+'
                                 r's_engine_ran = true;\s+m_engine_started = true;\s+'
                                 r's_main_layout = new FrameLayout\(this\);')
        destroy = re.search(r'(?s)protected void onDestroy\(\)\s*\{(.*?)\n\t\}', activity).group(1)
        # an activity that started no engine has none to finish
        # (and the engine finishes showing what it drew, see
        # test_android_java's test_the_engine_finishes_drawing_first)
        self.assertRegex(destroy, r'^\s*super\.onDestroy\(\);\s+(?://[^\n]*\s+)*if \(!m_engine_started\)\s+'
                                  r'return;\s+(?://[^\n]*\s+)*s_main_view\.finishDrawing\(\);\s+'
                                  r's_main_view\.clearWakeUp\(\);')
        # the process ends after the engine, only when the activity is
        # finishing and not for a configuration change
        self.assertRegex(destroy, r's_main_view = null;\s+(?://[^\n]*\s+)*'
                                  r'if \(isFinishing\(\) && !isChangingConfigurations\(\)\)\s+endProcess\(\);\s*$')
        end = re.search(r'(?s)protected static void endProcess\(\)\s*\{(.*?)\n    \}', activity).group(1)
        # after onDestroy has returned to Android, on the main thread
        self.assertIn('new Handler(Looper.getMainLooper()).post(', end)
        self.assertIn('android.os.Process.killProcess(android.os.Process.myPid());', end)

    def test_an_activity_without_an_engine_passes_nothing_to_it(self):
        # the activity that started the app again in a new process has no
        # engine (s_main_view is null), and Android can still call it before
        # it is destroyed: run 42430696858's probe crashed in
        # onConfigurationChanged, given the density's return after the
        # density change it was made again for. Every method that goes to
        # the engine, bar onCreate (which makes it), checks m_engine_started
        # first, after the super call Android requires
        activity = read(JAVA + ('LiveCodeActivity.java',))
        # the class's own methods (not those of the classes inside it and
        # inside onCreate, which only an activity with an engine makes)
        methods, end = {}, 0
        for m in re.finditer(r'\n[ \t]*(?:public|protected) [\w.]+ (\w+) ?\([^)]*\)\s*\{', activity):
            if m.start() < end or re.search(r'\bclass \w+[^{]*\{[^}]*$', activity[end:m.start()]):
                continue
            depth, i = 1, m.end()
            while depth:
                depth += {'{': 1, '}': -1}.get(activity[i], 0)
                i += 1
            methods[m.group(1)], end = activity[m.end():i - 1], i
        to_engine = sorted(n for n, body in methods.items() if 's_main_view.' in body and n != 'onCreate')
        self.assertEqual(to_engine, ['onActivityResult', 'onBackPressed', 'onConfigurationChanged', 'onDestroy',
                                     'onKeyDown', 'onLowMemory', 'onNewIntent', 'onPause',
                                     'onRequestPermissionsResult', 'onRestart', 'onResume'])
        for name in to_engine:
            body = re.sub(r'//[^\n]*', '', methods[name])
            guard = re.search(r'if \(!m_engine_started\)\s+return\b', body)
            self.assertTrue(guard, '%s goes to the engine without checking m_engine_started' % name)
            self.assertLess(guard.start(), body.index('s_main_view.'), name)
            # Android's own handling first, as before
            sup = body.find('super.%s(' % name)
            if name not in ('onBackPressed', 'onKeyDown', 'onNewIntent', 'onActivityResult'):
                self.assertTrue(0 <= sup < guard.start(), name)
        # the key Android handles itself when there is no engine
        self.assertRegex(methods['onKeyDown'], r'^\s*if \(!m_engine_started\)\s+return super\.onKeyDown\(keyCode, '
                                               r'event\);')
        # an activity that started the engine goes on as before
        # (the bars' icons of a stack drawn edge to edge between: an engine's
        # activity, test_android_java's test_edge_to_edge_when_the_app_asks)
        self.assertRegex(methods['onConfigurationChanged'],
                         r'super\.onConfigurationChanged\(p_new_config\);\s+if \(!m_engine_started\)\s+return;\s+'
                         r'(?://[^\n]*\n\s+)?(?:if \(s_edge_to_edge != null\)\s+showBarsForAppearance\(p_new_config\);\s+)?'
                         r's_main_view\.onConfigurationChanged\(p_new_config\);')

    def test_relaunch_activity(self):
        java = read(JAVA + ('RelaunchActivity.java',))
        relaunch = re.search(r'(?s)public static boolean relaunch\(Activity p_activity\)\s*\{(.*?)\n    \}',
                             java).group(1)
        # nothing at all where the manifest does not declare it
        self.assertRegex(relaunch, r'^\s*if \(!isDeclared\(p_activity\)\)\s+return false;')
        for part in ('t_intent.putExtra(EXTRA_INTENT, new Intent(p_activity.getIntent()));',
                     't_intent.putExtra(EXTRA_PID, android.os.Process.myPid());',
                     'p_activity.startActivity(t_intent);', 'p_activity.finish();', 'return true;'):
            self.assertIn(part, relaunch)
        create = re.search(r'(?s)protected void onCreate\(Bundle p_saved_state\)\s*\{(.*?)\n    \}', java).group(1)
        # the app's process first, never its own; then the app's Intent as
        # it was started, in a new task; then its own process ends
        kill = create.find('android.os.Process.killProcess(t_pid);')
        start = create.find('startActivity(t_start);')
        exit_ = create.find('Runtime.getRuntime().exit(0);')
        self.assertTrue(0 < kill < start < exit_, create)
        self.assertIn('if (t_pid != 0 && t_pid != android.os.Process.myPid())', create)
        self.assertIn('t_start = new Intent(t_app_intent);', create)
        self.assertIn('t_start.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);', create)
        declared = re.search(r'(?s)public static boolean isDeclared\(Context p_context\)\s*\{(.*?)\n    \}',
                             java).group(1)
        self.assertIn('getActivityInfo(new ComponentName(p_context, RelaunchActivity.class), 0)', declared)
        self.assertRegex(declared, r'catch \(PackageManager\.NameNotFoundException e\)\s*\{\s*return false;')

    def test_units_run(self):
        units = read(UNITS)
        self.assertIn('unitRelaunch tWork', handler(units, 'androidUnits'))
        relaunch = handler(units, 'unitRelaunch')
        for case in ('config-changes', 'relaunch-no-java-layer', 'relaunch-java-layer-without-it',
                     'relaunch-declared'):
            self.assertIn('"%s"' % case, relaunch)


class EdgeToEdge(unittest.TestCase):
    """A stack can ask to be drawn edge to edge (its "android,edge to edge"
    setting, the Android card's "Edge to edge"): the manifest then asks the
    Java layer for it with one meta-data of the application, where the
    runtime's layer can draw it so; where it cannot (LiveCode Community
    9.6.3's), the build stops instead of making an app that is not what the
    stack asks for; and any other stack's manifest is left as it was"""

    def setUp(self):
        self.src = code(read(BUILDER))

    def test_asked_only_where_the_stack_asks(self):
        ask = handler(self.src, 'androidAskForEdgeToEdge')
        self.assertIn('constant kEdgeToEdge = "com.runrev.android.EDGE_TO_EDGE"', self.src)
        self.assertIn('constant kEdgeToEdgeClass = "com/runrev/android/LiveCodeActivity$EdgeToEdge.class"', self.src)
        # a stack that does not ask: the manifest as it was, whatever the
        # runtime; then the Java layer, before anything is written
        self.assertRegex(ask, r'^function androidAskForEdgeToEdge pManifest, pSettings, pRuntimeFolder\s+'
                              r'if pSettings\["android,edge to edge"\] is not true then\s+'
                              r'return pManifest\s+end if\s+'
                              r'if not androidJavaLayerHas\(pRuntimeFolder, kEdgeToEdgeClass\) then\s+'
                              r'throw "[^"]+Java" &&\s+"layer cannot draw it so: update the runtimes, or untick '
                              r'Edge to edge on the Android card"\s+end if')
        # one meta-data of the application, which the Java layer reads
        self.assertRegex(ask, r'put "  <meta-data android:name=" & quote & kEdgeToEdge & quote &&\s+'
                              r'"android:value=" & quote & "true" & quote && "/>" & return into tMetaData')
        self.assertIn('replace "</application>" with tMetaData & "  </application>" in pManifest', ask)
        self.assertEqual(ask.count('replace '), 1)
        java = read(JAVA + ('LiveCodeActivity.java',))
        self.assertIn('public static final String EDGE_TO_EDGE = "com.runrev.android.EDGE_TO_EDGE";', java)
        self.assertIn('t_meta_data.getBoolean(EDGE_TO_EDGE, false)', java)
        # with the runtime the package is built with, after the relaunch
        # activity and before the manifest is written
        main = handler(self.src, 'revSaveAsMobileStandaloneMain')
        asked = main.find('put androidAskForEdgeToEdge(tManifest, pSettings, tRuntime) into tManifest')
        self.assertGreater(asked, main.find('put androidDeclareRelaunch(tManifest, tRuntime) into tManifest'))
        self.assertLess(asked, main.find('put tManifest into url ("binfile:" & tManifestFile)'))
        self.assertEqual(main.count('androidAskForEdgeToEdge('), 1)
        # the build's error reaches whoever built it, as the builder's
        # other refusals do
        self.assertRegex(main, r'(?s)\btry\b.*?androidAskForEdgeToEdge\(.*?\bcatch\b')

    def test_the_guide_says_how(self):
        # the setting as the builder reads it, and what a script then finds
        guide = read(('ide', 'Documentation', 'guides', 'Deploying Your Application.md'))
        self.assertIn('    set the cRevStandaloneSettings["android,edge to edge"] of stack "My App" to true\n', guide)
        self.assertIn('android,edge to edge', handler(self.src, 'androidAskForEdgeToEdge'))
        flat = ' '.join(guide.split())
        self.assertIn('`the effective working screenRect` the part of it that the bars, the cutout and the keyboard '
                      'leave uncovered', flat)
        # the screenRect is the window's (Engine.getViewport), and both
        # rects are where they are on the screen, as the Java layer gives
        # them (test_android_java's test_edge_to_edge_when_the_app_asks)
        self.assertIn('`the screenRect` is then the whole of the application\'s window (the whole screen, unless it '
                      'shares the screen with another application)', flat)
        self.assertIn('both where they are on the screen, as the stack\'s own rect is', flat)
        self.assertIn('with earlier ones the build stops and says so. A stack without the setting is laid out as '
                      'before.', flat)

    def test_the_java_layer_has_the_class_it_looks_for(self):
        java = read(JAVA + ('LiveCodeActivity.java',))
        self.assertIn('package com.runrev.android;', java)
        self.assertRegex(java, r'public class LiveCodeActivity extends Activity\b')
        self.assertIn('    protected static class EdgeToEdge implements View.OnApplyWindowInsetsListener\n', java)
        gyp = read(('engine', 'engine-sources.gypi'))
        self.assertIn("'src/java/com/runrev/android/LiveCodeActivity.java',", gyp)

    def test_units_run(self):
        units = read(UNITS)
        androidunits = handler(units, 'androidUnits')
        self.assertIn('unitEdgeToEdge tWork', androidunits)
        self.assertGreater(androidunits.index('unitEdgeToEdge tWork'), androidunits.index('unitRelaunch tWork'))
        edge = handler(units, 'unitEdgeToEdge')
        for case in ('edge-not-asked', 'edge-unticked', 'edge-asked', 'edge-asked-as-stored'):
            self.assertIn('"%s"' % case, edge)
        self.assertIn('androidUnit "edge-java-layer-" & tAnswer,', edge)
        self.assertIn('repeat for each item tAnswer in "none,without"', edge)


class Engine(unittest.TestCase):
    """The Android engine a build takes (androidRuntimeFolder): LiveCode
    9.6.3's, Runtime/Android, as before, for a stack whose "android,engine"
    is empty or "9.6.3"; OXT-Beyond's own, which the runtimes carry beside
    it as Runtime/Android/Beyond, for one whose setting is "beyond"; and
    for runtimes without it, or a name it does not know, the build stops.
    Every file of the runtime's the build takes comes from the one folder,
    so a package never mixes the two engines. The IDE units (unitEngine)
    run the handler; android-engine.yml builds both probes through it"""

    def setUp(self):
        self.text = read(BUILDER)
        self.src = code(self.text)

    def test_the_choice(self):
        choose = handler(self.src, 'androidRuntimeFolder')
        self.assertRegex(choose, r'^function androidRuntimeFolder pTarget, pSettings\s+local tRuntime\s+'
                                 r'put revMobileRuntimeFolder\(pTarget\) into tRuntime\s+'
                                 r'switch pSettings\["android,engine"\]\s+')
        # a stack that never names one, or names 9.6.3's: the runtime as
        # before, the same folder revMobileRuntimeFolder answers
        self.assertRegex(choose, r'case empty\s+case "9\.6\.3"\s+return tRuntime\s+case "beyond"')
        # OXT-Beyond's: the folder beside it, and only when it is there
        self.assertRegex(choose, r'case "beyond"\s+if there is not a folder \(tRuntime & slash & "Beyond"\) then\s+'
                                 r'throw "[^"\n]*these runtimes do not have it:" && tRuntime & slash & "Beyond"\s+'
                                 r'end if\s+return tRuntime & slash & "Beyond"\s+default')
        # any other name stops the build, and says which it was
        self.assertRegex(choose, r'default\s+throw "Unknown Android engine" && quote & pSettings\["android,engine"\] '
                                 r'& quote && "[^"\n]*"\s+end switch\s+end androidRuntimeFolder')
        self.assertEqual(choose.count('return '), 2)

    def test_every_runtime_file_comes_from_it(self):
        main = handler(self.src, 'revSaveAsMobileStandaloneMain')
        chosen = main.find('put androidRuntimeFolder(pTarget, pSettings) into tRuntime')
        self.assertGreater(chosen, 0)
        self.assertEqual(main.count('into tRuntime'), 1)
        # before its first use, and nothing in the build asks for the
        # runtime folder any other way
        self.assertLess(chosen, main.find('tRuntime &'))
        self.assertNotIn('revMobileRuntimeFolder', main)
        self.assertNotIn('RuntimePath()', main)
        # the engines, the externals, the Java layer, the manifest and the
        # files beside them: every file the build takes of the runtime's
        uses = re.findall(r'tRuntime & slash & (?:tArch & slash & )?("[^"]+"|tEntry)', main)
        self.assertEqual(sorted(set(uses)), sorted({
            '"notify_icon.png"', '"Manifest.xml"', '"Classes"', '"livecode_inputcontrol.xml"',
            '"nfc_tech_filter.xml"', '"file_provider_paths.xml"', '"Standalone"', '"revsecurity"', 'tEntry'}))
        # ten files (the externals' two lists share a line's shape), and
        # the three functions that read its Java layer: every use there is
        self.assertEqual(len(uses), 10)
        self.assertEqual(main.count('tRuntime'), 2 + len(uses) + 3)
        # the target API, the relaunch activity and whether a stack can be
        # drawn edge to edge are read from its Java layer, the one the
        # package is built with
        self.assertIn('put androidTargetAPI(pSettings, tRuntime) into tTargetAPI', main)
        self.assertIn('put androidDeclareRelaunch(tManifest, tRuntime) into tManifest', main)
        self.assertIn('put androidAskForEdgeToEdge(tManifest, pSettings, tRuntime) into tManifest', main)

    def test_the_runtime_folder_itself_unchanged(self):
        # revMobileRuntimeFolder answers what it did, for its other callers
        # (the device configuration file, and anyone's script)
        folder = handler(self.src, 'revMobileRuntimeFolder')
        self.assertRegex(folder, r'^function revMobileRuntimeFolder pTarget\s')
        self.assertRegex(folder, r'return revEnvironmentRuntimePath\(\) & slash & "Android"\s+end revMobileRuntimeFolder$')
        self.assertIn('put mapFIlePath(revMobileRuntimeFolder() & slash & "lc_device_config.txt") into tConfigFile',
                      self.src)
        self.assertNotIn('Beyond', folder)

    def test_the_folder_name_matches_the_check(self):
        # the folder overlay --beyond makes is the one the builder reads
        import sys
        sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))
        import android_check as ac
        self.assertEqual(ac.BEYOND, 'Beyond')
        self.assertIn('tRuntime & slash & "%s"' % ac.BEYOND, handler(self.src, 'androidRuntimeFolder'))

    def test_units_run(self):
        units = read(UNITS)
        body = handler(units, 'androidUnits')
        self.assertIn('unitEngine\n', body)
        self.assertLess(body.find('unitRelaunch tWork'), body.find('unitEngine\n'))
        engine = handler(units, 'unitEngine')
        for case in ('engine-default', 'engine-9.6.3', 'engine-beyond-missing', 'engine-beyond'):
            self.assertIn('"%s"' % case, engine)
        self.assertIn('androidUnit "engine-unknown-" & tName', engine)
        self.assertIn('repeat for each item tName in "beyond2,9.6,oxt-beyond"', engine)
        # a Beyond folder it made, it takes away; one there before, it leaves
        self.assertRegex(engine, r'put there is not a folder tBeyond into tMade\s+if tMade then')
        self.assertRegex(engine, r'if tMade then\s+removeTree tBeyond\s+end if')
        self.assertEqual(engine.count('removeTree'), 1)

    def test_the_probe_asks_for_it(self):
        # ide --android-engine beyond builds the probe with the setting; a
        # check without it builds the probe as a stack that names none
        units = read(UNITS)
        settings = handler(units, 'buildSettings')
        self.assertRegex(settings, r'if \$OXT_ANDROID_ENGINE is not empty then\s+'
                                   r'put \$OXT_ANDROID_ENGINE into tSettings\["android,engine"\]\s+end if')


class AdaptiveIcon(unittest.TestCase):
    """A stack can have an adaptive launcher icon (Android 8.0 and newer),
    a themed one with a monochrome image (Android 13 and newer): the
    "android,adaptive icon" settings. The build reads them before it starts
    (androidAdaptiveIcon: the images found and PNG files, the colour read,
    or it stops saying why), the adaptive icon takes the name of the icon
    the manifest names, and a stack that names no foreground is built as
    before. android-check.livecodescript's unitAdaptiveIcon runs the
    handlers in the IDE, and the edge probe's package is read by
    android_check.py verify --adaptive-icon"""

    def setUp(self):
        self.src = code(read(BUILDER))
        self.main = handler(self.src, 'revSaveAsMobileStandaloneMain')

    def test_the_settings(self):
        self.assertIn('constant kAdaptiveIcon = "android,adaptive icon"', self.src)
        self.assertIn('constant kAdaptiveIconBackground = "android,adaptive icon background"', self.src)
        self.assertIn('constant kThemedIcon = "android,themed icon"', self.src)

    def test_none_unless_the_stack_names_a_foreground(self):
        h = handler(self.src, 'androidAdaptiveIcon')
        self.assertRegex(h, r'if pSettings\[kAdaptiveIcon\] is empty then\s+'
                            r'if pSettings\[kThemedIcon\] is not empty then\s+throw "a themed icon[^\n]*\n'
                            r'\s+end if\s+return empty\s+end if')

    def test_read_before_the_build(self):
        # after the icon's path, before anything is built
        read_at = self.main.index('put androidAdaptiveIcon(pSettings, tBaseFolder) into tAdaptiveIcon')
        self.assertLess(self.main.index('put tBaseFolder & slash before tIcon'), read_at)
        self.assertLess(read_at, self.main.index('create folder tBuildFolder'))

    def test_the_images(self):
        h = handler(self.src, 'androidAdaptiveIcon')
        self.assertIn('if pathIsRelative(tPath) then', h)
        self.assertIn('put pBaseFolder & slash before tPath', h)
        self.assertIn('throw "the adaptive icon\'s" && tKey && "image is not there:" && tPath', h)
        self.assertIn('numToByte(137) & "PNG" & numToByte(13) & numToByte(10) & numToByte(26) & numToByte(10)', h)
        self.assertIn('put androidIconColour(pSettings[kAdaptiveIconBackground]) into tIcon["background"]', h)

    def test_the_colour(self):
        h = handler(self.src, 'androidIconColour')
        self.assertIn('return "#FFFFFFFF"', h)
        self.assertIn('matchText(tHex, "^([0-9A-F]{6}|[0-9A-F]{8})$")', h)
        self.assertIn('format("%02X", tPart)', h)
        self.assertIn('give it as #RRGGBB, #AARRGGBB or r,g,b', h)

    def test_the_manifest_names_the_same_icon(self):
        self.assertIn('if there is a file tIcon or tAdaptiveIcon is an array then\n'
                      '         replace "${ICON}" with "android:icon=" & quote & "@drawable/icon" & quote in tManifest',
                      self.main)

    def test_the_resources(self):
        # the stack's icon as before; the foreground before Android 8.0
        # when there is none; then the adaptive icon
        self.assertRegex(self.main, r'if there is a file tIcon then\s+put url \("binfile:" & tIcon\) into url '
                                    r'\("binfile:" & tDrawableResBuildFolder & slash & "icon.png"\)')
        self.assertRegex(self.main, r'else if tAdaptiveIcon is an array then\s+put url \("binfile:" & '
                                    r'tAdaptiveIcon\["foreground"\]\) into url \("binfile:" & '
                                    r'tDrawableResBuildFolder & slash & "icon.png"\)')
        self.assertRegex(self.main, r'if tAdaptiveIcon is an array then\s+'
                                    r'androidAddAdaptiveIcon tAdaptiveIcon, tResBuildFolder\s+'
                                    r'put the result after tAssetFiles\s+end if')
        add = handler(self.src, 'androidAddAdaptiveIcon')
        for path in ('"/drawable-nodpi/icon_" & tKey & ".png"', '"/drawable-anydpi-v26/icon.xml"',
                     '"/values/oxt_icon_background.xml"'):
            self.assertIn(path, add)
        # each file it writes is named in what it returns
        self.assertEqual(add.count('put tFile & return after tWritten'), 3)
        self.assertEqual(add.count('into url ("binfile:" & tFile)'), 3)
        self.assertRegex(add, r'return tWritten\s+end androidAddAdaptiveIcon\s*$')

    def test_the_build_folder_is_cleared(self):
        # the files go with the build's other files, then their folders,
        # before the res folder they are in
        clear = self.main.index('repeat for each item tFolder in "drawable-nodpi,drawable-anydpi-v26,values"')
        self.assertLess(self.main.index('if there is a file tFile then delete file tFile'), clear)
        self.assertLess(clear, self.main.index('if there is a folder tResBuildFolder then delete folder tResBuildFolder'))
        self.assertIn('delete folder (tResBuildFolder & slash & tFolder)', self.main[clear:])
        # the unit checks what it names
        check = read(('tools', 'ci', 'android-check.livecodescript'))
        unit = handler(check, 'unitAdaptiveIcon')
        self.assertIn('put the result into tWritten', unit)
        self.assertIn('androidUnit "icon-written", tWritten is', unit)
        xml = handler(self.src, 'androidAdaptiveIconXML')
        for layer in ('background android:drawable=" & quote & "@color/oxt_icon_background"',
                      'foreground android:drawable=" & quote & "@drawable/icon_foreground"',
                      'monochrome android:drawable=" & quote & "@drawable/icon_monochrome"'):
            self.assertIn(layer, xml)
        self.assertRegex(xml, r'if pIcon\["monochrome"\] is not empty then\s+put "    <monochrome')

    def test_the_check_runs_it(self):
        check = read(('tools', 'ci', 'android-check.livecodescript'))
        self.assertIn('   unitAdaptiveIcon tWork\n', check)
        unit = handler(check, 'unitAdaptiveIcon')
        for name in ('androidAdaptiveIcon', 'androidIconColour', 'androidAddAdaptiveIcon', 'androidAdaptiveIconXML'):
            self.assertIn('"%s"' % name, unit)
            # public, so that the check can call it
            self.assertRegex(self.src, r'(?m)^(?:function|command) %s\b' % name)
        # the edge probe's settings name the builder's
        probe = handler(check, 'buildSettings')
        for key in ('android,adaptive icon', 'android,themed icon', 'android,adaptive icon background'):
            self.assertIn('tSettings["%s"]' % key, probe)


if __name__ == '__main__':
    unittest.main()
