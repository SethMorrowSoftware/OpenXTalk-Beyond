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

"""A real Android library (.aar) in the Android check: android_check.py
ide --aar makes one and builds the app probe with it, verify --aar reads
the package for the library's class, its R class and its string at the id
that R class gives; and the builder makes the libraries' R classes with
the package's ids (one aapt run over the app's resources and the
libraries', --extra-packages). On made-up dex files and a stand-in aapt;
the library itself is made with the JDK when there is one (javac), against
a stand-in android.jar. No Android SDK is needed.

  python3 -m unittest discover -s tools/ci/tests -p test_android_aar.py
"""

import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from unittest import mock

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import android_check as ac  # noqa: E402


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def uleb(value):
    out = bytearray()
    while True:
        b = value & 0x7f
        value >>= 7
        if value:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def encoded_int(value):
    """An encoded_value of VALUE_INT (0x04), as small as it goes"""
    raw = struct.pack('<i', value if value < 0x80000000 else value - 0x100000000)
    while len(raw) > 1 and ((raw[-1] == 0 and raw[-2] < 0x80) or (raw[-1] == 0xff and raw[-2] >= 0x80)):
        raw = raw[:-1]
    return bytes([((len(raw) - 1) << 5) | 0x04]) + raw


def make_dex(classes):
    """A dex file's bytes, as much of one as dex_static_ints reads.
    CLASSES is [(descriptor, [(field, value), ...])]: VALUE is an int, or
    True/False for a boolean, or None for no value (a field after the
    last valued one)"""
    strings, types, fields = [], [], []

    def string(s):
        if s not in strings:
            strings.append(s)
        return strings.index(s)

    def type_(d):
        i = string(d)
        if i not in types:
            types.append(i)
        return types.index(i)
    defs = []
    for descriptor, statics in classes:
        c = type_(descriptor)
        ids = []
        for name, _ in statics:
            fields.append((c, type_('I'), string(name)))
            ids.append(len(fields) - 1)
        defs.append((c, ids, [v for _, v in statics]))
    header = 0x70
    string_ids = header
    type_ids = string_ids + 4 * len(strings)
    field_ids = type_ids + 4 * len(types)
    class_defs = field_ids + 8 * len(fields)
    data = class_defs + 32 * len(defs)
    blob = bytearray()
    string_offsets = []
    for s in strings:
        string_offsets.append(data + len(blob))
        blob += uleb(len(s)) + s.encode('utf-8') + b'\0'
    def_offsets = []
    for c, ids, values in defs:
        class_data = data + len(blob)
        blob += uleb(len(ids)) + uleb(0) + uleb(0) + uleb(0)
        last = 0
        for n, i in enumerate(ids):
            blob += uleb(i - last if n else i) + uleb(0x19)  # public static final
            last = i
        valued = values
        while valued and valued[-1] is None:
            valued = valued[:-1]
        static_values = 0
        if valued:
            static_values = data + len(blob)
            blob += uleb(len(valued))
            for v in valued:
                if v is True or v is False:
                    blob += bytes([(int(v) << 5) | 0x1f])
                else:
                    blob += encoded_int(v)
        def_offsets.append((class_data, static_values))
    out = bytearray(header)
    out[:8] = b'dex\n035\0'
    struct.pack_into('<II', out, 56, len(strings), string_ids)
    struct.pack_into('<II', out, 64, len(types), type_ids)
    struct.pack_into('<II', out, 80, len(fields), field_ids)
    struct.pack_into('<II', out, 96, len(defs), class_defs)
    for o in string_offsets:
        out += struct.pack('<I', o)
    for t in types:
        out += struct.pack('<I', t)
    for c, t, n in fields:
        out += struct.pack('<HHI', c, t, n)
    for (c, _, _), (class_data, static_values) in zip(defs, def_offsets):
        out += struct.pack('<8I', c, 1, 0xffffffff, 0, 0xffffffff, 0, class_data,
                           static_values)
    out += blob
    return bytes(out)


R_STRING = 'L%s/R$string;' % ac.AAR_PACKAGE.replace('.', '/')
LIBRARY = 'L%s/%s;' % (ac.AAR_PACKAGE.replace('.', '/'), ac.AAR_CLASS)


class DexStaticInts(unittest.TestCase):
    def test_reads_a_classes_int_values(self):
        dex = make_dex([('Lcom/example/Other;', [('a', 5)]),
                        (R_STRING, [('app_name', 0x7f030000), (ac.AAR_STRING, 0x7f030001)])])
        self.assertEqual(ac.dex_static_ints(dex, R_STRING), {'app_name': 0x7f030000, ac.AAR_STRING: 0x7f030001})
        self.assertEqual(ac.dex_static_ints(dex, 'Lcom/example/Other;'), {'a': 5})

    def test_small_and_negative_ints(self):
        dex = make_dex([('LX;', [('zero', 0), ('one', 1), ('big', 0x7fffffff), ('minus', -1)])])
        self.assertEqual(ac.dex_static_ints(dex, 'LX;'),
                         {'zero': 0, 'one': 1, 'big': 0x7fffffff, 'minus': 0xffffffff})

    def test_other_kinds_are_passed_over(self):
        dex = make_dex([('LX;', [('flag', True), ('id', 0x7f010000), ('no_value', None)])])
        self.assertEqual(ac.dex_static_ints(dex, 'LX;'), {'id': 0x7f010000})

    def test_no_such_class(self):
        self.assertIsNone(ac.dex_static_ints(make_dex([('LX;', [('a', 1)])]), R_STRING))

    def test_not_a_dex_file(self):
        with self.assertRaises(ac.CheckError):
            ac.dex_static_ints(b'PK\3\4' + b'\0' * 200, R_STRING)


class VerifyLibraryAar(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def package(self, dexes, dump):
        apk = os.path.join(self.tmp.name, 'debug.apk')
        with zipfile.ZipFile(apk, 'w') as z:
            for name, data in dexes:
                z.writestr(name, data)
        with open(os.path.join(self.tmp.name, 'dump.txt'), 'w') as f:
            f.write(dump)
        aapt = os.path.join(self.tmp.name, 'aapt')
        with open(aapt, 'w') as f:
            f.write('#!/bin/sh\ncat "%s"\n' % os.path.join(self.tmp.name, 'dump.txt'))
        os.chmod(aapt, 0o755)
        return apk, aapt

    def dump(self, id_):
        return ('Package Groups (1)\n'
                '      spec resource 0x%08x %s:string/%s: flags=0x00000000\n'
                '        resource 0x%08x %s:string/%s: t=0x03 d=0x00000001 (s=0x0008 r=0x00)\n'
                % (id_, 'com.yourcompany.yourapp', ac.AAR_STRING, id_, 'com.yourcompany.yourapp', ac.AAR_STRING))

    @unittest.skipIf(os.name == 'nt', 'a shell script stands in for aapt')
    def test_the_id_the_r_class_gives(self):
        apk, aapt = self.package([('classes.dex', make_dex([(LIBRARY, []), (R_STRING, [(ac.AAR_STRING, 0x7f050002)])]))],
                                 self.dump(0x7f050002))
        problems, notes = ac.verify_library_aar('debug', apk, aapt)
        self.assertEqual(problems, [])
        self.assertIn('0x7f050002', notes[0])

    @unittest.skipIf(os.name == 'nt', 'a shell script stands in for aapt')
    def test_ids_from_the_librarys_resources_alone(self):
        # what the builder did before: the library's string numbered from
        # the first string id, while the package's has another
        apk, aapt = self.package([('classes.dex', make_dex([(LIBRARY, []), (R_STRING, [(ac.AAR_STRING, 0x7f010000)])]))],
                                 self.dump(0x7f050002))
        problems, _ = ac.verify_library_aar('debug', apk, aapt)
        self.assertEqual(len(problems), 1)
        self.assertIn('0x7f010000', problems[0])
        self.assertIn('0x7f050002', problems[0])

    @unittest.skipIf(os.name == 'nt', 'a shell script stands in for aapt')
    def test_the_class_and_r_class_in_a_second_dex(self):
        apk, aapt = self.package([('classes.dex', make_dex([('LOther;', [])])),
                                  ('classes2.dex', make_dex([(LIBRARY, []), (R_STRING, [(ac.AAR_STRING, 0x7f050002)])]))],
                                 self.dump(0x7f050002))
        self.assertEqual(ac.verify_library_aar('debug', apk, aapt)[0], [])

    @unittest.skipIf(os.name == 'nt', 'a shell script stands in for aapt')
    def test_no_library(self):
        apk, aapt = self.package([('classes.dex', make_dex([('LOther;', [])]))], 'Package Groups (1)\n')
        problems, _ = ac.verify_library_aar('debug', apk, aapt)
        self.assertEqual(len(problems), 3)
        self.assertTrue(any(LIBRARY in p for p in problems))
        self.assertTrue(any(R_STRING in p for p in problems))
        self.assertTrue(any('no string/' in p for p in problems))


class MakeLibraryAar(unittest.TestCase):
    """The library, made with the JDK against a stand-in android.jar"""

    @classmethod
    def setUpClass(cls):
        if not ac.jdk_tool(None, 'javac') or not ac.jdk_tool(None, 'jar'):
            raise unittest.SkipTest('no JDK (javac) here')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        # a stand-in android.jar: android.content.Context.getString(int)
        stub = os.path.join(self.tmp.name, 'stub')
        src = os.path.join(stub, 'android', 'content')
        os.makedirs(src)
        with open(os.path.join(src, 'Context.java'), 'w') as f:
            f.write('package android.content;\npublic abstract class Context {\n'
                    '    public abstract String getString(int p_id);\n}\n')
        subprocess.run([ac.jdk_tool(None, 'javac'), '-d', stub, os.path.join(src, 'Context.java')], check=True)
        self.sdk = os.path.join(self.tmp.name, 'sdk')
        for n in (33, 36):
            os.makedirs(os.path.join(self.sdk, 'platforms', 'android-%d' % n))
        with zipfile.ZipFile(os.path.join(self.sdk, 'platforms', 'android-36', 'android.jar'), 'w') as z:
            z.write(os.path.join(src, 'Context.class'), 'android/content/Context.class')
        self.work = os.path.join(self.tmp.name, 'work')
        os.makedirs(self.work)

    def test_the_newest_platforms_jar(self):
        self.assertEqual(ac.android_jar(self.sdk), os.path.join(self.sdk, 'platforms', 'android-36', 'android.jar'))
        self.assertIsNone(ac.android_jar(os.path.join(self.tmp.name, 'nothing')))

    def test_a_library_as_a_librarys_build_makes_one(self):
        path = ac.make_library_aar(self.work, self.sdk, None)
        self.assertEqual(path, os.path.join(self.work, ac.AAR_NAME))
        with zipfile.ZipFile(path) as z:
            names = set(z.namelist())
            self.assertTrue({'AndroidManifest.xml', 'classes.jar', 'R.txt', 'res/values/values.xml'} <= names)
            self.assertIn('package="%s"' % ac.AAR_PACKAGE, z.read('AndroidManifest.xml').decode())
            self.assertIn('<string name="%s">%s</string>' % (ac.AAR_STRING, ac.AAR_TEXT),
                          z.read('res/values/values.xml').decode())
            self.assertIn('int string %s ' % ac.AAR_STRING, z.read('R.txt').decode())
            inner = z.read('classes.jar')
        jar = os.path.join(self.tmp.name, 'classes.jar')
        with open(jar, 'wb') as f:
            f.write(inner)
        with zipfile.ZipFile(jar) as z:
            classes = [n for n in z.namelist() if n.endswith('.class')]
            folder = ac.AAR_PACKAGE.replace('.', '/')
            # the library's class, not its R classes: those are the app's
            self.assertEqual(classes, ['%s/%s.class' % (folder, ac.AAR_CLASS)])
            code = z.read(classes[0])
        # Java 8 (major 52), and the id read from the R class's field, not
        # a constant javac put in the class
        self.assertEqual(struct.unpack('>H', code[6:8])[0], 52)
        self.assertIn(('%s/R$string' % folder).encode(), code)
        self.assertIn(ac.AAR_STRING.encode(), code)

    def test_again_in_the_same_work_folder(self):
        ac.make_library_aar(self.work, self.sdk, None)
        self.assertTrue(os.path.isfile(ac.make_library_aar(self.work, self.sdk, None)))

    def test_no_android_jar(self):
        shutil.rmtree(os.path.join(self.sdk, 'platforms'))
        with self.assertRaises(ac.CheckError):
            ac.make_library_aar(self.work, self.sdk, None)


def handler(text, kind, name):
    m = re.search(r'^(?:private )?%s %s\b.*?^end %s$' % (kind, name, name), text, re.M | re.S)
    if not m:
        raise AssertionError('no %s %s' % (kind, name))
    return m.group(0)


class BuilderResourceClasses(unittest.TestCase):
    BUILDER = ('ide-support', 'revsaveasandroidstandalone.livecodescript')

    def setUp(self):
        self.builder = read(*self.BUILDER)
        self.body = handler(self.builder, 'command', 'generateResourceClasses')

    def test_one_aapt_run_after_every_library(self):
        # one run with the libraries' packages, after the loop over them,
        # not one per library with its resources alone
        self.assertEqual(self.body.count('executeShellCommand'), 1)
        loop = re.search(r'repeat with x = 1 to the number of lines in xSettings\["aarFiles"\].*?end repeat',
                         self.body, re.S).group(0)
        self.assertNotIn('executeShellCommand', loop)
        self.assertLess(self.body.index(loop), self.body.index('executeShellCommandWithParams pathToAapt(), tParams'))

    def test_the_package_steps_resources_in_its_order(self):
        # the app's manifest and res folder first, then each library's,
        # --auto-add-overlay: as the package step ("Assembling assets")
        self.assertIn('appendToList pManifest, tParams', self.body)
        app_res = self.body.index('appendToList pResBuildFolder, tParams')
        lib_res = self.body.index('appendToList tRes, tParams')
        self.assertLess(app_res, lib_res)
        for flag in ('"--auto-add-overlay"', '"--extra-packages"', '"-J"', '"-m"'):
            self.assertIn('appendToList %s, tParams' % flag, self.body)
        self.assertIn('replace comma with ":" in tExtraPackages', self.body)

    def test_a_library_with_no_package_is_an_error(self):
        self.assertIn('put androidManifestPackage(tManifest) into tPackage', self.body)
        self.assertRegex(self.body, r'if tPackage is empty then\s+return "the library"')

    def test_only_the_libraries_r_classes(self):
        self.assertIn('if tLinePackage is not among the items of tPackages then', self.body)

    def manifest_package(self, xml):
        """androidManifestPackage's pattern, read from the builder, as
        Python reads it (the same in PCRE for this pattern)"""
        line = [x for x in handler(self.builder, 'function', 'androidManifestPackage').splitlines()
                if 'matchText(' in x][0]
        expr = re.search(r'matchText\(tXml, (.*), tPackage\)', line).group(1)
        pattern = ''.join(part.strip()[1:-1] if part.strip().startswith('"') else '"'
                          for part in expr.split('&'))
        m = re.search(pattern, xml.replace('\n', ' '))
        return m.group(1) if m else ''

    def test_the_package_of_a_manifest(self):
        self.assertEqual(self.manifest_package(
            '<?xml version="1.0"?>\n<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    package="org.example.lib">\n</manifest>\n'), 'org.example.lib')
        self.assertEqual(self.manifest_package("<manifest package = 'a.b' >"), 'a.b')
        self.assertEqual(self.manifest_package('<manifest xmlns:android="x">\n<application/>\n</manifest>'), '')
        self.assertEqual(self.manifest_package('<manifest android:package="x"><uses-sdk/></manifest>'), '')


class BuilderShellArguments(unittest.TestCase):
    """An argument with a "$" (an inner class's file, such as a library's
    R$string.class) reaches the program as it is: sh reads the command line
    outside Windows, and put the empty value of $string in its place, so d8
    was given R.class twice"""

    def setUp(self):
        self.body = handler(read(*BuilderResourceClasses.BUILDER), 'command', 'executeShellCommandWithParams')

    def quoted(self, param, platform='linux'):
        """The argument as the handler writes it, mirrored in Python"""
        if platform != 'win32' and '$' in param:
            return "'" + param.replace("'", "'\\''") + "'"
        if ' ' in param and not param.startswith('-'):
            return '"' + param + '"'
        return param

    def test_the_handler_quotes_a_dollar_for_sh(self):
        lines = [x.strip() for x in self.body.splitlines()]
        at = lines.index('if the platform is not "win32" and tParam contains "$" then')
        self.assertEqual(lines[at + 1:at + 4], [
            'replace "\'" with "\'\\\'\'" in tParam',
            'put "\'" & tParam & "\'" into tParam',
            'else if tParam contains space and not (tParam begins with "-") then'])

    @unittest.skipIf(os.name == 'nt', 'sh reads the command line')
    def test_sh_gives_the_program_the_argument_as_it_is(self):
        for param in ('/tmp/x/classes_app/org/example/R$string.class', "/tmp/it's $HOME", '/tmp/a b/R$id.class'):
            out = subprocess.run('printf %s ' + self.quoted(param), shell=True, stdout=subprocess.PIPE,
                                 universal_newlines=True).stdout
            self.assertEqual(out, param)

    def test_others_as_before(self):
        self.assertEqual(self.quoted('/tmp/a b/c.class'), '"/tmp/a b/c.class"')
        self.assertEqual(self.quoted('-target'), '-target')
        self.assertEqual(self.quoted('C:/x/R$string.class', 'win32'), 'C:/x/R$string.class')


class Wiring(unittest.TestCase):
    def test_the_ide_script_builds_with_the_library(self):
        script = read('tools', 'ci', 'android-check.livecodescript')
        body = handler(script, 'function', 'buildSettings')
        self.assertRegex(body, r'if \$OXT_ANDROID_AAR is not empty then\s+'
                               r'put \$OXT_ANDROID_AAR into tSettings\["aarFiles"\]')
        self.assertIn('OXT_ANDROID_AAR', script[:script.index('-- The Java layer')])

    def test_ide_hands_the_library_to_the_ide_script(self):
        self.assertRegex(read('tools', 'ci', 'android_check.py'),
                         r"OXT_ANDROID_AAR=path\(make_library_aar\(work, args\.sdk, args\.jdk\)\) if getattr\(args, 'aar', False\) else ''")

    def test_the_flags(self):
        seen = {}

        def take(name):
            def run(args):
                seen[name] = args.aar
                return []
            return run
        with mock.patch.object(ac, 'ide', take('ide')), mock.patch.object(ac, 'verify', take('verify')), \
                mock.patch.object(ac, 'log'), mock.patch.object(ac, 'summary'):
            ac.main(['ide', '--install', 'x', '--work', 'w', '--aar'])
            ac.main(['verify', '--work', 'w', '--sdk', 's', '--aar'])
            self.assertEqual(seen, {'ide': True, 'verify': True})
            ac.main(['ide', '--install', 'x', '--work', 'w'])
            ac.main(['verify', '--work', 'w', '--sdk', 's'])
            self.assertEqual(seen, {'ide': False, 'verify': False})

    def test_android_yml_builds_and_checks_the_app_probe_with_a_library(self):
        workflow = read('.github', 'workflows', 'android.yml')
        step = re.search(r'- name: The app probe, with this Java layer\n.*?(?=\n      - name:|\n      #)',
                         workflow, re.S).group(0)
        commands = re.findall(r'"\$PY" tools/ci/android_check\.py (\w+)((?:[^\n]*\\\n)*[^\n]*)', step)
        self.assertEqual([c for c, _ in commands], ['ide', 'verify'])
        for _, line in commands:
            self.assertIn('--aar', line.split())


if __name__ == '__main__':
    unittest.main()
