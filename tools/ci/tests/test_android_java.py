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

"""tools/ci/android_java.py on made-up class files, jars, ELF files and C++
and LCB sources: its reading of each, its comparison of two jars as the
code means it, its JNI checks and Android's rules, each shown to fail on
what it is for; and that the Java sources, the check's lists and the
workflows agree. No JDK, Android SDK or engine is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import re
import struct
import sys
import tempfile
import unittest
import zipfile

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import android_check as ac  # noqa: E402
import android_java as aj  # noqa: E402


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


# ---------------------------------------------------------------------------
# Made-up class files

class ClassWriter(object):
    """A class file, written as javac writes one, from what a test gives:
    fields, and methods whose code is a list of items, each a byte, or a
    tuple: ('u2', n), ('i4', n), ('ref', 'method'|'imethod'|'field', owner,
    name, descriptor), ('class', name), ('string', text) and ('int', n) as
    a constant pool index (two bytes), ('string1', text) as a one-byte
    index (ldc)."""

    def __init__(self, name, super_name='java/lang/Object', access=0x0021, interfaces=(), major=52,
                 reverse_pool=False):
        self.name = name
        self.super_name = super_name
        self.access = access
        self.interfaces = interfaces
        self.major = major
        self.entries = []
        self.index = {}
        self.fields = []
        self.methods = []
        self.reverse_pool = reverse_pool

    def const(self, key, body):
        if key not in self.index:
            self.entries.append(body)
            self.index[key] = len(self.entries)
        return self.index[key]

    def utf8(self, text):
        data = text.encode('utf-8')
        return self.const(('utf8', text), b'\x01' + struct.pack('>H', len(data)) + data)

    def cls(self, name):
        return self.const(('class', name), b'\x07' + struct.pack('>H', self.utf8(name)))

    def string(self, text):
        return self.const(('string', text), b'\x08' + struct.pack('>H', self.utf8(text)))

    def integer(self, n):
        return self.const(('int', n), b'\x03' + struct.pack('>i', n))

    def nat(self, name, desc):
        return self.const(('nat', name, desc), b'\x0c' + struct.pack('>HH', self.utf8(name), self.utf8(desc)))

    def ref(self, kind, owner, name, desc):
        tag = {'field': 9, 'method': 10, 'imethod': 11}[kind]
        return self.const(('ref', kind, owner, name, desc),
                          bytes([tag]) + struct.pack('>HH', self.cls(owner), self.nat(name, desc)))

    def field(self, name, desc, access=0x0002, value=None):
        self.fields.append((access, name, desc, value))

    def method(self, name, desc, access=0x0001, code=None, handlers=()):
        self.methods.append((access, name, desc, code, handlers))

    def assemble(self, code):
        out = bytearray()
        for item in code:
            if isinstance(item, int):
                out.append(item)
            elif item[0] == 'u2':
                out += struct.pack('>H', item[1])
            elif item[0] == 'i4':
                out += struct.pack('>i', item[1])
            elif item[0] == 'ref':
                out += struct.pack('>H', self.ref(*item[1:]))
            elif item[0] == 'class':
                out += struct.pack('>H', self.cls(item[1]))
            elif item[0] == 'string':
                out += struct.pack('>H', self.string(item[1]))
            elif item[0] == 'string1':
                out.append(self.string(item[1]))
            elif item[0] == 'int':
                out += struct.pack('>H', self.integer(item[1]))
            else:
                raise ValueError(item)
        return bytes(out)

    def bytes(self):
        if self.reverse_pool:
            # the same constants, written in another order (as another
            # compiler might): fill the pool backwards first
            for kind, args in reversed(self.pool_plan()):
                getattr(self, kind)(*args)
        this = self.cls(self.name)
        sup = self.cls(self.super_name) if self.super_name else 0
        ifaces = [self.cls(x) for x in self.interfaces]
        members = []
        for access, name, desc, value in self.fields:
            attrs = b''
            count = 0
            if value is not None:
                attrs = struct.pack('>HIH', self.utf8('ConstantValue'), 2, self.integer(value))
                count = 1
            members.append(('f', struct.pack('>HHHH', access, self.utf8(name), self.utf8(desc), count) + attrs))
        for access, name, desc, code, handlers in self.methods:
            attrs = b''
            count = 0
            if code is not None:
                body = self.assemble(code)
                table = struct.pack('>H', len(handlers)) + b''.join(
                    struct.pack('>HHHH', s, e, h, self.cls(t) if t else 0) for s, e, h, t in handlers)
                inner = struct.pack('>HHI', 10, 10, len(body)) + body + table + struct.pack('>H', 0)
                attrs = struct.pack('>HI', self.utf8('Code'), len(inner)) + inner
                count = 1
            members.append(('m', struct.pack('>HHHH', access, self.utf8(name), self.utf8(desc), count) + attrs))
        fields = [x for k, x in members if k == 'f']
        methods = [x for k, x in members if k == 'm']
        out = b'\xca\xfe\xba\xbe' + struct.pack('>HH', 0, self.major)
        out += struct.pack('>H', len(self.entries) + 1) + b''.join(self.entries)
        out += struct.pack('>HHH', self.access, this, sup)
        out += struct.pack('>H', len(ifaces)) + b''.join(struct.pack('>H', x) for x in ifaces)
        out += struct.pack('>H', len(fields)) + b''.join(fields)
        out += struct.pack('>H', len(methods)) + b''.join(methods)
        out += struct.pack('>H', 0)
        return out

    def pool_plan(self):
        """What the methods' code will put in the pool, in order."""
        plan = []
        for _a, _n, _d, code, _h in self.methods:
            for item in code or ():
                if isinstance(item, tuple) and item[0] == 'ref':
                    plan.append(('ref', item[1:]))
                elif isinstance(item, tuple) and item[0] in ('class', 'string', 'int'):
                    plan.append(({'class': 'cls', 'string': 'string', 'int': 'integer'}[item[0]], item[1:]))
        return plan


def parse(writer):
    return aj.parse_class(writer.bytes())


def listing(writer, name, desc, static=False):
    c = parse(writer)
    m = c.methods[(name, desc)]
    return aj.code_listing(c, m[1], m[2], desc, static)


def jar(path, writers):
    with zipfile.ZipFile(path, 'w') as z:
        for w in writers:
            z.writestr(w.name + '.class', w.bytes())
    return path


# Java's opcodes, for the code the tests write
ICONST_0, ICONST_2, BIPUSH, SIPUSH, LDC, LDC_W = 0x03, 0x05, 0x10, 0x11, 0x12, 0x13
ALOAD_0, ALOAD_1, ALOAD, ASTORE, ASTORE_1, ISTORE, ILOAD = 0x2a, 0x2b, 0x19, 0x3a, 0x4c, 0x36, 0x15
ACONST_NULL, RETURN, ARETURN, IRETURN, POP = 0x01, 0xb1, 0xb0, 0xac, 0x57
GOTO, GOTO_W, IFEQ, IFNULL = 0xa7, 0xc8, 0x99, 0xc6
INVOKEVIRTUAL, INVOKESTATIC, INVOKEINTERFACE, CHECKCAST, GETFIELD = 0xb6, 0xb8, 0xb9, 0xc0, 0xb4
TABLESWITCH, LOOKUPSWITCH = 0xaa, 0xab


class ClassFiles(unittest.TestCase):
    def test_reads_a_class(self):
        w = ClassWriter('a/B', 'a/Base', interfaces=('a/I',))
        w.field('X', 'I', 0x001a, value=7)
        w.method('n', '(Ljava/lang/String;)V', 0x0101)
        w.method('m', '()V', code=[RETURN])
        c = parse(w)
        self.assertEqual((c.name, c.super_name, c.interfaces, c.major), ('a/B', 'a/Base', ['a/I'], 52))
        self.assertEqual(c.pool[c.fields[('X', 'I')][1]], ('int', 7))
        self.assertTrue(c.methods[('n', '(Ljava/lang/String;)V')][0] & aj.ACC_NATIVE)
        self.assertIsNone(c.methods[('n', '(Ljava/lang/String;)V')][1])
        self.assertEqual(c.methods[('m', '()V')][1], bytes([RETURN]))

    def test_not_a_class(self):
        with self.assertRaises(aj.CheckError):
            aj.parse_class(b'PK\x03\x04')

    def test_read_jar(self):
        with tempfile.TemporaryDirectory() as d:
            path = jar(os.path.join(d, 'x.jar'), [ClassWriter('a/A'), ClassWriter('a/B')])
            self.assertEqual(sorted(aj.read_jar(path)), ['a/A', 'a/B'])
            bad = os.path.join(d, 'bad.jar')
            with open(bad, 'wb') as f:
                f.write(b'not a zip')
            with self.assertRaises(aj.CheckError):
                aj.read_jar(bad)

    def test_parameters(self):
        self.assertEqual(aj.parameter_types('(I[JLa/B;[[Ljava/lang/String;D)V'),
                         ['I', '[J', 'La/B;', '[[Ljava/lang/String;', 'D'])
        self.assertEqual(aj.parameter_slots('(IJD)V'), 5)
        with self.assertRaises(aj.CheckError):
            aj.parameter_types('I')


class CodeListing(unittest.TestCase):
    """Two ways of writing the same code list the same; a change does not"""

    def same(self, code_a, code_b, desc='()V', static=False, **kw):
        a = ClassWriter('a/A', **kw)
        a.method('m', desc, code=code_a)
        b = ClassWriter('a/A')
        b.method('m', desc, code=code_b)
        la, lb = listing(a, 'm', desc, static), listing(b, 'm', desc, static)
        return la, lb

    def test_ldc_and_ldc_w(self):
        la, lb = self.same([LDC, ('string1', 'hi'), POP, RETURN], [LDC_W, ('string', 'hi'), POP, RETURN])
        self.assertEqual(la, lb)
        self.assertEqual(la[0], "ldc string 'hi'")

    def test_pool_order_does_not_matter(self):
        code = [ALOAD_0, INVOKEVIRTUAL, ('ref', 'method', 'a/A', 'f', '()V'),
                LDC_W, ('string', 'x'), POP, RETURN]
        a = ClassWriter('a/A')
        a.method('m', '()V', code=code)
        b = ClassWriter('a/A', reverse_pool=True)
        b.method('m', '()V', code=code)
        self.assertNotEqual(a.bytes(), b.bytes())
        self.assertEqual(listing(a, 'm', '()V'), listing(b, 'm', '()V'))

    def test_small_constants_by_value(self):
        la, lb = self.same([ICONST_2, POP, RETURN], [BIPUSH, 2, POP, RETURN])
        self.assertEqual(la, lb)
        la, lc = self.same([ICONST_2, POP, RETURN], [SIPUSH, ('u2', 2), POP, RETURN])
        self.assertEqual(la, lc)
        self.assertEqual(la[0], 'const 2')

    def test_goto_and_goto_w_by_instruction(self):
        # goto +3 (to RETURN) against goto_w +5: the same target
        la, lb = self.same([GOTO, ('u2', 3), RETURN], [GOTO_W, ('i4', 5), RETURN])
        self.assertEqual(la, lb)
        self.assertEqual(la, ['goto L1', 'return'])

    def test_locals_numbered_by_first_use(self):
        # one compiler puts the local in slot 2, another in slot 5
        la, lb = self.same([ACONST_NULL, ASTORE, 2, ALOAD, 2, ARETURN],
                           [ACONST_NULL, ASTORE, 5, ALOAD, 5, ARETURN], desc='()Ljava/lang/Object;')
        self.assertEqual(la, lb)
        self.assertEqual(la, ['aconst_null', 'astore v0', 'aload v0', 'areturn'])

    def test_parameters_keep_their_slots(self):
        la, lb = self.same([ALOAD_1, ARETURN], [ALOAD_0, ARETURN], desc='(Ljava/lang/Object;)Ljava/lang/Object;')
        self.assertEqual(la, ['aload p1', 'areturn'])
        self.assertNotEqual(la, lb)

    def test_object_methods_by_name(self):
        la, lb = self.same(
            [ALOAD_1, INVOKEVIRTUAL, ('ref', 'method', 'java/lang/Object', 'toString', '()Ljava/lang/String;'),
             POP, RETURN],
            [ALOAD_1, INVOKEINTERFACE, ('ref', 'imethod', 'java/util/Set', 'toString', '()Ljava/lang/String;'), 1, 0,
             POP, RETURN], desc='(Ljava/util/Set;)V')
        self.assertEqual(la, lb)
        self.assertEqual(la[1], 'invoke-object toString:()Ljava/lang/String;')

    def test_other_interface_calls_are_kept(self):
        la, lb = self.same(
            [ALOAD_1, INVOKEINTERFACE, ('ref', 'imethod', 'java/util/Set', 'size', '()I'), 1, 0, POP, RETURN],
            [ALOAD_1, INVOKEINTERFACE, ('ref', 'imethod', 'java/util/List', 'size', '()I'), 1, 0, POP, RETURN],
            desc='(Ljava/util/Set;)V')
        self.assertNotEqual(la, lb)

    def test_checkcast_left_out_and_branches_kept(self):
        # ifnull jumps to the checkcast; without it the target is the pop
        la, lb = self.same([ALOAD_1, IFNULL, ('u2', 3), ALOAD_1, CHECKCAST, ('class', 'a/B'), POP, RETURN],
                           [ALOAD_1, IFNULL, ('u2', 3), ALOAD_1, POP, RETURN], desc='(Ljava/lang/Object;)V')
        self.assertEqual(la, lb)

    def test_switches_by_key_and_target(self):
        # tableswitch 0..1 against lookupswitch {0, 1}, both to the same
        # instructions: the opcode is at 2, so one byte pads its operands
        # to 4, and the offsets are from the opcode
        table = [ILOAD, 1, TABLESWITCH, 0, ('i4', 26), ('i4', 0), ('i4', 1), ('i4', 22), ('i4', 24),
                 ICONST_0, IRETURN, ICONST_2, IRETURN, ICONST_0, IRETURN]
        look = [ILOAD, 1, LOOKUPSWITCH, 0, ('i4', 30), ('i4', 2), ('i4', 0), ('i4', 26), ('i4', 1), ('i4', 28),
                ICONST_0, IRETURN, ICONST_2, IRETURN, ICONST_0, IRETURN]
        la, lb = self.same(table, look, desc='(I)I')
        self.assertEqual(la, lb)
        self.assertEqual(la[1], "switch L6 [(0, 'L2'), (1, 'L4')]")

    def test_a_real_change_differs(self):
        la, lb = self.same([ACONST_NULL, ARETURN], [ALOAD_0, ARETURN], desc='()Ljava/lang/Object;')
        self.assertNotEqual(la, lb)

    def test_exception_table(self):
        a = ClassWriter('a/A')
        a.method('m', '()V', code=[ALOAD_0, POP, RETURN, POP, RETURN], handlers=[(0, 2, 3, 'java/lang/Exception')])
        self.assertEqual(listing(a, 'm', '()V')[-1], 'catch java/lang/Exception L0-L2 -> L3')

    def test_unknown_instruction(self):
        a = ClassWriter('a/A')
        a.method('m', '()V', code=[0xfe])
        with self.assertRaises(aj.CheckError):
            listing(a, 'm', '()V')


# ---------------------------------------------------------------------------

def simple(name='a/A', code=(ACONST_NULL, ARETURN), **kw):
    w = ClassWriter(name, **kw)
    w.field('f', 'I')
    w.method('m', '()Ljava/lang/Object;', code=list(code))
    w.method('n', '(I)V', 0x0101)
    return w


class CompareJars(unittest.TestCase):
    def jars(self, old, new):
        return ({w.name: parse(w) for w in old}, {w.name: parse(w) for w in new})

    def test_same(self):
        gone, added = aj.compare_jars(*self.jars([simple()], [simple()]))
        self.assertEqual((gone, added), ([], []))

    def test_class_gone_and_added(self):
        gone, added = aj.compare_jars(*self.jars([simple(), simple('a/Old')], [simple(), simple('a/New')]))
        self.assertEqual([k for k, _ in gone], ['class a/Old'])
        self.assertEqual(added, ['class a/New'])

    def test_member_gone_changed_and_added(self):
        old = simple()
        new = ClassWriter('a/A')
        new.field('f', 'J')
        new.method('m', '()Ljava/lang/Object;', 0x0009, code=[ACONST_NULL, ARETURN])
        new.method('n', '(I)V', 0x0101)
        gone, added = aj.compare_jars(*self.jars([old], [new]))
        keys = [k for k, _ in gone]
        self.assertIn('member a/A.f:I', keys)
        self.assertIn('member a/A.m:()Ljava/lang/Object;', keys)
        self.assertIn('a/A.field f:J (private)', added)
        text = dict(gone)['member a/A.m:()Ljava/lang/Object;']
        self.assertIn('was public, is public static', text)

    def test_constant_value_change(self):
        a = ClassWriter('a/A')
        a.field('V', 'I', 0x001a, value=1)
        b = ClassWriter('a/A')
        b.field('V', 'I', 0x001a, value=3)
        gone, _ = aj.compare_jars(*self.jars([a], [b]))
        self.assertEqual([k for k, _ in gone], ['member a/A.V:I'])
        self.assertIn('was int 1, is int 3', gone[0][1])

    def test_code_change(self):
        gone, _ = aj.compare_jars(*self.jars([simple()], [simple(code=(ALOAD_0, ARETURN))]))
        self.assertEqual([k for k, _ in gone], ['code a/A.m:()Ljava/lang/Object;'])
        self.assertIn('-aconst_null', gone[0][1])
        self.assertIn('+aload p0', gone[0][1])

    def test_class_header(self):
        gone, _ = aj.compare_jars(*self.jars([simple()], [simple(super_name='a/Other')]))
        self.assertEqual([k for k, _ in gone], ['class a/A'])

    def test_anonymous_class_final_is_left_out(self):
        gone, _ = aj.compare_jars(*self.jars([simple('a/A$1', access=0x0030)], [simple('a/A$1', access=0x0020)]))
        self.assertEqual(gone, [])
        gone, _ = aj.compare_jars(*self.jars([simple('a/A', access=0x0031)], [simple('a/A', access=0x0021)]))
        self.assertEqual([k for k, _ in gone], ['class a/A'])

    def test_synthetic_members_are_left_out(self):
        old = simple()
        old.method('access$000', '()V', 0x1008, code=[RETURN])
        new = simple()
        new.method('access$100', '(I)V', 0x1008, code=[RETURN])
        gone, added = aj.compare_jars(*self.jars([old], [new]))
        self.assertEqual((gone, added), ([], []))


class Compare(unittest.TestCase):
    """compare's verdict: EXPECTED by the old jar's SHA-256"""

    def run_compare(self, old, new, expected):
        with tempfile.TemporaryDirectory() as d:
            a = jar(os.path.join(d, 'old.jar'), old)
            b = jar(os.path.join(d, 'new.jar'), new)
            saved = aj.EXPECTED
            aj.EXPECTED = {aj.sha256(a): expected} if expected is not None else {}
            out = io.StringIO()
            try:
                with contextlib.redirect_stdout(out):
                    status = aj.main(['compare', '--old', a, '--new', b])
            finally:
                aj.EXPECTED = saved
        return status, out.getvalue()

    def test_expected_differences_pass(self):
        status, out = self.run_compare([simple()], [simple(code=(ALOAD_0, ARETURN)), simple('a/New')],
                                       {'code a/A.m:()Ljava/lang/Object;': 'meant'})
        self.assertEqual(status, 0, out)
        self.assertIn('EXPECTED: the code of a/A.m:()Ljava/lang/Object; differs', out)
        self.assertIn('because meant', out)
        self.assertIn('  class a/New', out)

    def test_an_unexpected_difference_fails(self):
        status, out = self.run_compare([simple()], [simple(code=(ALOAD_0, ARETURN))], {})
        self.assertEqual(status, 1)
        self.assertIn('PROBLEM: the code of a/A.m:()Ljava/lang/Object; differs', out)

    def test_a_stale_entry_fails(self):
        status, out = self.run_compare([simple()], [simple()], {'code a/A.m:()Ljava/lang/Object;': 'meant'})
        self.assertEqual(status, 1)
        self.assertIn('but it does not differ', out)

    def test_an_unknown_old_jar_fails_on_additions_too(self):
        status, out = self.run_compare([simple()], [simple(), simple('a/New')], None)
        self.assertEqual(status, 1)
        self.assertIn('PROBLEM: only the new jar has class a/New', out)


# ---------------------------------------------------------------------------
# build

class Build(unittest.TestCase):
    def test_sources(self):
        java, aidl = aj.java_sources()
        self.assertGreater(len(java), 40)
        self.assertNotIn('src/java/com/runrev/android/billing/ResponseHandler.java', java,
                         'a source the .gypi comments out')
        for x in java + aidl:
            self.assertTrue(os.path.isfile(os.path.join(aj.ENGINE_DIR, x)), x)
        for x in aidl:
            self.assertTrue(os.path.isfile(os.path.join(aj.ENGINE_DIR, os.path.splitext(x)[0] + '.java')),
                            '%s has no Java beside it' % x)

    def test_gyp_list(self):
        text = "{ 'x': [\n  'a.java',\n  #'b.java',\n  'c.java',\n], 'y': ['d'] }"
        self.assertEqual(aj.gyp_list(text, 'x'), ['a.java', 'c.java'])
        with self.assertRaises(aj.CheckError):
            aj.gyp_list(text, 'z')

    def test_jar_bytes_depend_only_on_the_classes(self):
        with tempfile.TemporaryDirectory() as d:
            classes = os.path.join(d, 'classes', 'a')
            os.makedirs(classes)
            with open(os.path.join(classes, 'B.class'), 'wb') as f:
                f.write(ClassWriter('a/B').bytes())
            with open(os.path.join(classes, 'A.class'), 'wb') as f:
                f.write(ClassWriter('a/A').bytes())
            # the folder the jar goes in is made when it is not there
            one, two = os.path.join(d, 'out', '1.jar'), os.path.join(d, '2.jar')
            self.assertEqual(aj.write_jar(os.path.join(d, 'classes'), one), 2)
            os.utime(os.path.join(classes, 'A.class'), (1, 1))
            aj.write_jar(os.path.join(d, 'classes'), two)
            with open(one, 'rb') as f1, open(two, 'rb') as f2:
                self.assertEqual(f1.read(), f2.read())
            with zipfile.ZipFile(one) as z:
                self.assertEqual(z.namelist(), ['META-INF/MANIFEST.MF', 'a/A.class', 'a/B.class'])

    @unittest.skipIf(os.name == 'nt', 'the stand-in javac is a shell script')
    def test_build_runs_javac_as_the_gyp_build_did(self):
        with tempfile.TemporaryDirectory() as d:
            platform = os.path.join(d, 'sdk', 'platforms', 'android-36')
            os.makedirs(platform)
            open(os.path.join(platform, 'android.jar'), 'wb').close()
            bin_dir = os.path.join(d, 'jdk', 'bin')
            os.makedirs(bin_dir)
            with open(os.path.join(d, 'A.class'), 'wb') as f:
                f.write(ClassWriter('com/runrev/android/A').bytes())
            javac = os.path.join(bin_dir, 'javac')
            with open(javac, 'w') as f:
                f.write('#!/bin/sh\n'
                        'echo "$@" > "%s/args.txt"\n'
                        'while [ "$1" != "-d" ]; do shift; done\n'
                        'mkdir -p "$2/com/runrev/android" && cp "%s/A.class" "$2/com/runrev/android/A.class"\n'
                        % (d, d))
            os.chmod(javac, 0o755)
            # in a folder not made yet, as android.yml gives it
            out = os.path.join(d, 'java', 'Classes')
            log = io.StringIO()
            with contextlib.redirect_stdout(log):
                status = aj.main(['build', '--sdk', os.path.join(d, 'sdk'), '--jdk', os.path.join(d, 'jdk'),
                                  '--out', out])
            self.assertEqual(status, 0, log.getvalue())
            with open(os.path.join(d, 'args.txt')) as f:
                args = f.read().split()
            for flag in ('-source', '-target', '-implicit:none', '-bootclasspath', '-sourcepath'):
                self.assertIn(flag, args)
            self.assertEqual(args[args.index('-source') + 1], '8')
            self.assertEqual(args[args.index('-bootclasspath') + 1], os.path.join(platform, 'android.jar'))
            # the AIDL interfaces' Java first, as config/java.gypi had it
            first = [x for x in args if x.endswith('.java')][0]
            self.assertTrue(first.endswith('IInAppBillingService.java'), first)
            self.assertIn('com/runrev/android/A', aj.read_jar(out))

    def test_build_without_the_platform(self):
        with tempfile.TemporaryDirectory() as d:
            log = io.StringIO()
            with contextlib.redirect_stdout(log):
                status = aj.main(['build', '--sdk', d, '--out', os.path.join(d, 'x.jar')])
            self.assertEqual(status, 1)
            self.assertIn('platforms;android-36', log.getvalue())


# ---------------------------------------------------------------------------
# Made-up ELF files

def elf(exports, needed, is64=True, undefined=('memcpy',)):
    """An ELF shared library's bytes with a .dynsym, .dynstr and .dynamic:
    the names it exports (defined), those it imports (undefined) and the
    libraries it needs."""
    end = '<'
    strtab = bytearray(b'\0')

    def s(text):
        at = len(strtab)
        strtab.extend(text.encode() + b'\0')
        return at
    syms = [b'\0' * (24 if is64 else 16)]
    for name, shndx in [(x, 9) for x in exports] + [(x, 0) for x in undefined]:
        if is64:
            syms.append(struct.pack(end + 'IBBHQQ', s(name), 0x12, 0, shndx, 0, 0))
        else:
            syms.append(struct.pack(end + 'IIIBBH', s(name), 0, 0, 0x12, 0, shndx))
    dyn = b''.join(struct.pack(end + ('qQ' if is64 else 'iI'), 1, s(x)) for x in needed)
    dyn += struct.pack(end + ('qQ' if is64 else 'iI'), 0, 0)
    dynsym = b''.join(syms)
    ehsize, shentsize = (64, 64) if is64 else (52, 40)
    body = bytearray()
    off_sym = ehsize
    body += dynsym
    off_str = ehsize + len(body)
    body += strtab
    off_dyn = ehsize + len(body)
    body += dyn
    shoff = ehsize + len(body)

    def sh(sh_type, off, size, link, entsize):
        if is64:
            return struct.pack(end + 'IIQQQQIIQQ', 0, sh_type, 0, 0, off, size, link, 0, 8, entsize)
        return struct.pack(end + 'IIIIIIIIII', 0, sh_type, 0, 0, off, size, link, 0, 4, entsize)
    sections = [sh(0, 0, 0, 0, 0), sh(11, off_sym, len(dynsym), 2, 24 if is64 else 16),
                sh(3, off_str, len(strtab), 0, 0), sh(6, off_dyn, len(dyn), 2, 16 if is64 else 8)]
    ident = b'\x7fELF' + bytes([2 if is64 else 1, 1, 1]) + b'\0' * 9
    if is64:
        header = ident + struct.pack(end + 'HHIQQQIHHHHHH', 3, 183, 1, 0, 0, shoff, 0, ehsize, 0, 0, shentsize,
                                     len(sections), 0)
    else:
        header = ident + struct.pack(end + 'HHIIIIIHHHHHH', 3, 40, 1, 0, 0, shoff, 0, ehsize, 0, 0, shentsize,
                                     len(sections), 0)
    return header + bytes(body) + b''.join(sections)


class Elf(unittest.TestCase):
    def test_64_and_32_bits(self):
        for is64 in (True, False):
            exports, needed = aj.elf_dynamic(elf(['Java_a_B_n', 'other'], ['libGLESv1_CM.so', 'libc.so'], is64))
            self.assertEqual(exports, {'Java_a_B_n', 'other'}, is64)
            self.assertEqual(needed, ['libGLESv1_CM.so', 'libc.so'], is64)

    def test_not_elf(self):
        with self.assertRaises(aj.CheckError):
            aj.elf_dynamic(b'MZ')


# ---------------------------------------------------------------------------
# jni

# OpenGLView.startGLES(int) as this tree's javac writes it: the context of
# the version asked for from OpenGL ES 2 on, else one with no attributes
#   if (p > 1) m_egl_context = eglCreateContext(..., new int[] {
#       EGL_CONTEXT_CLIENT_VERSION, p, EGL_NONE}); else ...(null)
STARTGLES_CODE = [0x1b, 0x04, 0xa4, ('u2', 26), 0x06, 0xbc, 10, 0x59, ICONST_0, SIPUSH, ('u2', 0x3098), 0x4f,
                  0x59, 0x04, 0x1b, 0x4f, 0x59, ICONST_2, SIPUSH, ('u2', 0x3038), 0x4f, 0x4d, GOTO, ('u2', 5),
                  ACONST_NULL, 0x4d, RETURN]


def engine_classes(extra_natives=(), gles=None, delegate=None):
    """A made-up Java layer: an Engine with natives and methods the engine
    calls, an OpenGLView, and a listener interface. The view's start()
    makes its context (with gles, of that version) or, with delegate, calls
    startGLES(delegate)."""
    e = ClassWriter('com/runrev/android/Engine', 'android/view/View')
    e.method('doProcess', '(Z)V', 0x010a)
    e.method('doName_x', '(Ljava/lang/String;)V', 0x0101)
    for name, desc in extra_natives:
        e.method(name, desc, 0x0101)
    e.method('getEngine', '()Lcom/runrev/android/Engine;', 0x0009, code=[ACONST_NULL, ARETURN])
    e.method('current', '()Ljava/lang/Object;', 0x0009, code=[ACONST_NULL, ARETURN])
    e.method('showAlert', '(Ljava/lang/String;I)V', code=[RETURN])
    e.method('pick', '(Ljava/lang/String;)Ljava/lang/String;', code=[ACONST_NULL, ARETURN])
    v = ClassWriter('com/runrev/android/OpenGLView', 'android/view/SurfaceView')
    if delegate is not None:
        v.method('start', '()V', code=[ALOAD_0, BIPUSH, delegate, INVOKEVIRTUAL,
                                       ('ref', 'method', 'com/runrev/android/OpenGLView', 'startGLES', '(I)V'),
                                       RETURN])
        v.method('startGLES', '(I)V', code=STARTGLES_CODE)
    elif gles is None:
        v.method('start', '()V', code=[ALOAD_0, ACONST_NULL, POP, POP, RETURN])
    else:
        # new int[] {EGL_CONTEXT_CLIENT_VERSION, gles, EGL_NONE}
        v.method('start', '()V', code=[0x06, 0xbc, 10, 0x59, ICONST_0, SIPUSH, ('u2', 0x3098), 0x4f,
                                       0x59, 0x04, BIPUSH, gles, 0x4f, 0x59, ICONST_2, SIPUSH, ('u2', 0x3038), 0x4f,
                                       ASTORE_1, RETURN])
    i = ClassWriter('com/runrev/android/Engine$Listener', access=0x0601)
    return [e, v, i]


def android_jar(path):
    """A stand-in android.jar: View, with setVisibility, above Engine, and
    Object at the top (without it every lookup that reaches the top is one
    that cannot be answered)."""
    top = ClassWriter('java/lang/Object', None)
    view = ClassWriter('android/view/View')
    view.method('setVisibility', '(I)V', code=[RETURN])
    sv = ClassWriter('android/view/SurfaceView', 'android/view/View')
    obj = ClassWriter('java/lang/Boolean')
    obj.method('booleanValue', '()Z', code=[ICONST_0, IRETURN])
    return jar(path, [top, view, sv, obj])


class RepoPath(unittest.TestCase):
    def test_in_and_out_of_the_checkout(self):
        self.assertEqual(aj.repo_path(os.path.join(REPO, 'tools', 'ci', 'x.py')), 'tools/ci/x.py')
        saved = os.path.relpath
        try:
            def other_drive(path, start=None):
                raise ValueError('path is on mount C:, start on mount D:')
            os.path.relpath = other_drive
            self.assertEqual(aj.repo_path(os.path.join('elsewhere', 'x.cpp')), 'elsewhere/x.cpp')
        finally:
            os.path.relpath = saved


class Mangle(unittest.TestCase):
    def test_names(self):
        self.assertEqual(aj.jni_mangle('com/runrev/android/Engine'), 'com_runrev_android_Engine')
        self.assertEqual(aj.jni_mangle('do_it'), 'do_1it')
        self.assertEqual(aj.jni_mangle('a$B'), 'a_00024B')
        self.assertEqual(aj.jni_mangle('[Ljava/lang/String;'), '_3Ljava_lang_String_2')
        self.assertEqual(aj.jni_names('a/B', 'n', '(ILa/C;)V'), ('Java_a_B_n', 'Java_a_B_n__ILa_C_2'))


class Exports(unittest.TestCase):
    def setUp(self):
        self.saved = aj.UNEXPORTED
        aj.UNEXPORTED = {}

    def tearDown(self):
        aj.UNEXPORTED = self.saved

    def classes(self, *extra):
        return {w.name: parse(w) for w in engine_classes(extra)}

    def test_every_native_exported(self):
        engines = {'arm64-v8a': {'Java_com_runrev_android_Engine_doProcess', 'Java_com_runrev_android_Engine_doName_1x',
                                 'JNI_OnLoad'}}
        problems, lines = aj.check_exports(self.classes(), engines)
        self.assertEqual(problems, [])
        self.assertIn('arm64-v8a: 2 Java_* exports, 2 native methods, 0 of them not in the engine', lines[0])

    def test_overloaded_name(self):
        engines = {'x86': {'Java_com_runrev_android_Engine_doProcess__Z', 'Java_com_runrev_android_Engine_doName_1x'}}
        self.assertEqual(aj.check_exports(self.classes(), engines)[0], [])

    def test_a_native_with_no_function(self):
        engines = {'x86': {'Java_com_runrev_android_Engine_doProcess'}}
        problems, _ = aj.check_exports(self.classes(), engines)
        self.assertEqual(problems, ['x86: the native method com/runrev/android/Engine.doName_x:(Ljava/lang/String;)V '
                                    'has no function in the engine'])
        aj.UNEXPORTED = {'com/runrev/android/Engine.doName_x:(Ljava/lang/String;)V': 'never called'}
        self.assertEqual(aj.check_exports(self.classes(), engines)[0], [])

    def test_an_export_with_no_native(self):
        engines = {'x86': {'Java_com_runrev_android_Engine_doProcess', 'Java_com_runrev_android_Engine_doName_1x',
                           'Java_com_runrev_android_Engine_doGone'}}
        problems, _ = aj.check_exports(self.classes(), engines)
        self.assertEqual(len(problems), 1)
        self.assertIn('exports Java_com_runrev_android_Engine_doGone, which no native method', problems[0])

    def test_a_stale_unexported_entry(self):
        aj.UNEXPORTED = {'com/runrev/android/Engine.doProcess:(Z)V': 'was missing once'}
        engines = {'x86': {'Java_com_runrev_android_Engine_doProcess', 'Java_com_runrev_android_Engine_doName_1x'}}
        problems, _ = aj.check_exports(self.classes(), engines)
        self.assertEqual(len(problems), 1)
        self.assertIn('UNEXPORTED names com/runrev/android/Engine.doProcess:(Z)V', problems[0])


CPP = r'''
// MCAndroidEngineRemoteCall("commented", "v", nil);
/* MCAndroidEngineCall("alsoCommented", "v", nil); */
void f()
{
    const char *s = "not // a comment";
    MCAndroidEngineRemoteCall("showAlert", "vxi", nil, p_message, 3);
    MCAndroidEngineCall("pick", "x@", &r, p_value);
    MCAndroidObjectRemoteCall(t_view, "setVisibility", "vi", nil, 1);
    MCAndroidObjectRemoteCall(get(view), "missing", "v", nil);
    MCAndroidStaticRemoteCall("com/runrev/android/Engine", "current", "o", &r);
    jclass t_boolean_class = env->FindClass("java/lang/Boolean");
    s_boolean_class = (jclass)env->NewGlobalRef(t_boolean_class);
    s_value = env->GetMethodID(s_boolean_class, "booleanValue", "()Z");
    s_other = env->GetMethodID(env->GetObjectClass(view), "nowhere", "(IZ)V");
}
'''


class Calls(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cpp = os.path.join(self.tmp.name, 'made_up_calls.cpp')
        with open(self.cpp, 'w') as f:
            f.write(CPP)
        self.file = aj.repo_path(self.cpp)
        self.android = android_jar(os.path.join(self.tmp.name, 'android.jar'))

    def tearDown(self):
        self.tmp.cleanup()

    def calls(self):
        return {c.name: c for c in aj.source_calls([self.cpp])}

    def test_reads_the_calls(self):
        calls = self.calls()
        self.assertNotIn('commented', calls)
        self.assertNotIn('alsoCommented', calls)
        self.assertEqual(sorted(calls), ['booleanValue', 'current', 'missing', 'nowhere', 'pick', 'setVisibility',
                                         'showAlert'])
        self.assertEqual(calls['showAlert'].cls, 'com/runrev/android/Engine')
        self.assertTrue(re.match(calls['showAlert'].pattern, '(Ljava/lang/String;I)V'))
        self.assertIsNone(calls['setVisibility'].cls)
        self.assertEqual(calls['current'].cls, 'com/runrev/android/Engine')
        self.assertTrue(calls['current'].static)
        self.assertEqual(calls['booleanValue'].cls, 'java/lang/Boolean', 'through NewGlobalRef')
        self.assertIsNone(calls['nowhere'].cls)
        self.assertEqual(calls['showAlert'].where, self.file + ':7')
        self.assertEqual(calls['showAlert'].file, self.file)

    def test_signature_letters(self):
        self.assertTrue(re.match(aj.signature_pattern('x@'), '(Ljava/lang/Object;)Ljava/lang/String;'))
        self.assertTrue(re.match(aj.signature_pattern('x@'), '(I)Ljava/lang/String;'))
        self.assertTrue(re.match(aj.signature_pattern('@'), '()Ljava/lang/Object;'))
        self.assertFalse(re.match(aj.signature_pattern('vi'), '(J)V'))
        with self.assertRaises(aj.CheckError):
            aj.signature_pattern('vq')

    def check(self, strings=None, known=None):
        jarred = {w.name: parse(w) for w in engine_classes()}
        classes = aj.Classes(jarred, self.android)
        return aj.check_calls(aj.source_calls([self.cpp]), classes, strings, known or {})

    def test_found_and_not_found(self):
        problems, lines = self.check()
        self.assertEqual(len(problems), 2, problems)
        self.assertIn('calls missing with the signature v', problems[0])
        self.assertIn('calls nowhere with the signature (IZ)V', problems[1])
        self.assertIn('7 calls into Java checked', lines[-1])

    def test_not_in_the_engine_is_listed_only(self):
        strings = b'\0showAlert\0pick\0setVisibility\0current\0booleanValue\0nowhere\0'
        problems, lines = self.check(strings)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('nowhere', problems[0])
        self.assertTrue(any(x.startswith("not in the runtime's engine:") and 'missing' in x for x in lines))

    def test_known_calls(self):
        f = self.file
        known = {(f, 'missing', 'v'): 'never worked', (f, 'nowhere', '(IZ)V'): 'never worked'}
        problems, lines = self.check(known=known)
        self.assertEqual(problems, [])
        self.assertTrue(any(x.startswith('KNOWN:') for x in lines))
        known[(f, 'showAlert', 'vxi')] = 'once missing'
        known[(f, 'gone', 'v')] = 'no longer made'
        problems, _ = self.check(known=known)
        self.assertEqual(len(problems), 2, problems)
        self.assertIn('which finds its method now', problems[0])
        self.assertIn('which the source no longer makes', problems[1])

    def test_the_return_type_is_exact(self):
        # 'o' asks JNI for ()Ljava/lang/Object; and nothing else: a method
        # that returns an Engine is not found by it, as on a device
        call = aj.Call('x.cpp:1', 'static', 'com/runrev/android/Engine', 'getEngine', aj.signature_pattern('o'),
                       True, 'o')
        jarred = {w.name: parse(w) for w in engine_classes()}
        problems, _ = aj.check_calls([call], aj.Classes(jarred, self.android), None, {})
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('calls getEngine with the signature o', problems[0])

    def test_without_android_jar(self):
        jarred = {w.name: parse(w) for w in engine_classes()}
        problems, lines = aj.check_calls(aj.source_calls([self.cpp]), aj.Classes(jarred), None, {})
        self.assertTrue(any(x.startswith('cannot say (no android.jar)') and 'booleanValue' in x for x in lines))

    def test_the_real_sources_are_read(self):
        calls = aj.source_calls([os.path.join(REPO, 'engine', 'src', 'mblandroidnotification.cpp')])
        self.assertIn(('createLocalNotification', 'jxxxibi'), [(c.name, c.text) for c in calls])


class Bindings(unittest.TestCase):
    LCB = '''
foreign handler _A() returns JObject binds to "java:com.runrev.android.Engine>getEngine()Lcom/runrev/android/Engine;!static"
foreign handler _B() returns JObject binds to "java:com.runrev.android.Engine$Listener>interface()"
foreign handler _C() returns nothing binds to "java:com.runrev.android.Engine>showAlert(Ljava/lang/String;I)V"
foreign handler _D() returns nothing binds to "java:android.widget.Button>new(Landroid/content/Context;)"
'''

    def bindings(self, text):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'x.lcb'), 'w') as f:
                f.write(text)
            return aj.lcb_bindings(d)

    def check(self, text, with_android=True):
        with tempfile.TemporaryDirectory() as d:
            android = android_jar(os.path.join(d, 'android.jar')) if with_android else None
            classes = aj.Classes({w.name: parse(w) for w in engine_classes()}, android)
            try:
                return aj.check_bindings(self.bindings(text), classes)
            finally:
                if classes.android is not None:
                    classes.android.close()

    def test_read(self):
        # in the order of the source (the Button is not the Java layer's)
        b = self.bindings(self.LCB)
        self.assertEqual([(x[0].rsplit(':', 1)[1], x[1], x[2], x[5]) for x in b],
                         [('2', 'com/runrev/android/Engine', 'getEngine', 'static'),
                          ('3', 'com/runrev/android/Engine$Listener', 'interface', 'instance'),
                          ('4', 'com/runrev/android/Engine', 'showAlert', 'instance')])
        self.assertEqual(b[2][3:5], ('Ljava/lang/String;I', 'V'))

    def test_lines_in_number_order(self):
        b = self.bindings('\n'.join('binds to "java:com.runrev.android.Engine>m%d()V"' % i for i in range(12)))
        self.assertEqual([x[2] for x in b], ['m%d' % i for i in range(12)])

    def test_good(self):
        problems, lines = self.check(self.LCB)
        self.assertEqual(problems, [])
        self.assertEqual(lines, ['3 LCB bindings to the Java layer checked'])

    def test_bad(self):
        problems, _ = self.check('binds to "java:com.runrev.android.Engine>interface()"\n'
                                 'binds to "java:com.runrev.android.Engine>showAlert(Ljava/lang/String;)V"\n'
                                 'binds to "java:com.runrev.android.Engine>showAlert(Ljava/lang/String;I)V!static"\n'
                                 'binds to "java:com.runrev.android.Gone>x()V"\n'
                                 'binds to "java:com.runrev.android.Engine>x()V!special"\n')
        self.assertEqual(len(problems), 5, problems)
        self.assertIn(':1 binds to com/runrev/android/Engine as an interface, which it is not', problems[0])
        self.assertIn(':2 binds to com/runrev/android/Engine.showAlert:(Ljava/lang/String;)V (instance)', problems[1])
        self.assertIn(':3 binds to com/runrev/android/Engine.showAlert:(Ljava/lang/String;I)V (static)', problems[2])
        self.assertIn(':4 binds to com/runrev/android/Gone, which the jar does not have', problems[3])
        self.assertIn(':5: a binding of the call type special', problems[4])

    def test_new(self):
        problems, _ = self.check('binds to "java:com.runrev.android.Engine>new(I)"\n')
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('Engine.<init>:(I)V', problems[0])

    def test_without_android_jar_it_says_so(self):
        # a lookup that reaches classes it cannot read is not a pass
        problems, lines = self.check('binds to "java:com.runrev.android.Engine>showAlert(Ljava/lang/String;)V"\n',
                                     with_android=False)
        self.assertEqual(problems, [])
        self.assertTrue(any(x.startswith('cannot say (no android.jar):') for x in lines), lines)

    def test_the_real_bindings(self):
        b = aj.lcb_bindings(os.path.join(REPO, 'extensions'))
        self.assertIn('getEngine', [x[2] for x in b])


class Named(unittest.TestCase):
    def test_comment_lines_are_left_out(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'Manifest.xml'), 'w') as f:
                f.write('<receiver android:name="com.runrev.android.PushReceiver"/>')
            saved = aj.BUILDER
            aj.BUILDER = os.path.join(d, 'b.livecodescript')
            with open(aj.BUILDER, 'w') as f:
                f.write('put "import com.runrev.android.LiveCodeService;" after x\n'
                        '      --  put "import com.runrev.android.billing.BillingService;" after x\n')
            try:
                named = aj.named_classes(d)
            finally:
                aj.BUILDER = saved
        self.assertEqual(named, [('Manifest.xml', 'com/runrev/android/PushReceiver'),
                                 ('b.livecodescript', 'com/runrev/android/LiveCodeService')])
        classes = aj.Classes({w.name: parse(w) for w in engine_classes()})
        problems, _ = aj.check_named(named, classes)
        self.assertEqual(len(problems), 2)

    def builder(self, d, text, manifest=''):
        """named_classes and looked_for_classes of a builder of text (and a
        runtime whose manifest is manifest) in d."""
        with open(os.path.join(d, 'Manifest.xml'), 'w') as f:
            f.write(manifest)
        saved = aj.BUILDER
        aj.BUILDER = os.path.join(d, 'revsaveasandroidstandalone.livecodescript')
        with open(aj.BUILDER, 'w') as f:
            f.write(text)
        try:
            return aj.named_classes(d), aj.looked_for_classes()
        finally:
            aj.BUILDER = saved

    # As the builder declares RelaunchActivity: only where the jar has it
    LOOKS_FOR = ('constant kRelaunchClass = "com/runrev/android/RelaunchActivity.class"\n'
                 'put "  <activity android:name=" & quote & "com.runrev.android.RelaunchActivity" & quote after x\n'
                 'put "import com.runrev.android.LiveCodeService;" after x\n')

    def test_a_class_named_only_where_the_jar_has_it(self):
        # a release's jar without RelaunchActivity (LiveCode Community
        # 9.6.3's): said, and no problem; asked of every named class (this
        # checkout's jar), a problem
        classes = aj.Classes({w.name: parse(w) for w in engine_classes()})
        with tempfile.TemporaryDirectory() as d:
            named, looked_for = self.builder(d, self.LOOKS_FOR)
        self.assertEqual(looked_for, {'com/runrev/android/RelaunchActivity'})
        problems, lines = aj.check_named(named, classes, looked_for)
        self.assertEqual(problems, ['revsaveasandroidstandalone.livecodescript names '
                                    'com/runrev/android/LiveCodeService, which the jar does not have'])
        self.assertIn('revsaveasandroidstandalone.livecodescript names com/runrev/android/RelaunchActivity '
                      'only where the jar has it, and this jar has not', lines)
        problems, _ = aj.check_named(named, classes)
        self.assertEqual(len(problems), 2)
        self.assertTrue(any(x.endswith('com/runrev/android/RelaunchActivity, which the jar does not have')
                            for x in problems), problems)

    def test_a_jar_with_the_class_says_nothing_of_it(self):
        relaunch = ClassWriter('com/runrev/android/RelaunchActivity', 'android/app/Activity')
        service = ClassWriter('com/runrev/android/LiveCodeService', 'android/app/Service')
        classes = aj.Classes({w.name: parse(w) for w in engine_classes() + [relaunch, service]})
        with tempfile.TemporaryDirectory() as d:
            named, looked_for = self.builder(d, self.LOOKS_FOR)
        for kept in (looked_for, ()):
            problems, lines = aj.check_named(named, classes, kept)
            self.assertEqual(problems, [])
            self.assertEqual(lines, ['2 classes named by the manifest and the builder checked'])

    def test_the_manifest_naming_it_is_still_a_problem(self):
        # the runtime's manifest declares what it names whatever the jar
        # has: only the builder looks in the jar first
        classes = aj.Classes({w.name: parse(w) for w in engine_classes()})
        with tempfile.TemporaryDirectory() as d:
            named, looked_for = self.builder(
                d, 'constant k = "com/runrev/android/RelaunchActivity.class"\n',
                manifest='<activity android:name="com.runrev.android.RelaunchActivity"/>')
        self.assertEqual(named, [('Manifest.xml', 'com/runrev/android/RelaunchActivity')])
        problems, _ = aj.check_named(named, classes, looked_for)
        self.assertEqual(problems, ['Manifest.xml names com/runrev/android/RelaunchActivity, '
                                    'which the jar does not have'])

    def test_a_look_in_a_comment_is_no_look(self):
        # the builder's old code, kept as comments, looks for nothing
        classes = aj.Classes({w.name: parse(w) for w in engine_classes()})
        with tempfile.TemporaryDirectory() as d:
            named, looked_for = self.builder(
                d, '-- constant kRelaunchClass = "com/runrev/android/RelaunchActivity.class"\n'
                   'put "com.runrev.android.RelaunchActivity" after x\n')
        self.assertEqual(looked_for, set())
        problems, _ = aj.check_named(named, classes, looked_for)
        self.assertEqual(len(problems), 1)

    def test_the_real_builder(self):
        # the builder names RelaunchActivity, and looks for it in the jar
        # first; LiveCodeActivity it names whatever the jar has
        named = [cls for where, cls in aj.named_classes(os.path.join(REPO, 'no-runtime'))]
        looked_for = aj.looked_for_classes()
        self.assertIn('com/runrev/android/RelaunchActivity', named)
        self.assertIn('com/runrev/android/RelaunchActivity', looked_for)
        self.assertIn('com/runrev/android/LiveCodeActivity', named)
        self.assertNotIn('com/runrev/android/LiveCodeActivity', looked_for)

    def test_meta_data_is_no_class(self):
        # the builder writes com.runrev.android.EDGE_TO_EDGE as meta-data
        # (META_DATA), which no jar has as a class: said, not looked for;
        # the manifest naming it is still a problem, as is a name of the
        # builder's that META_DATA does not keep
        classes = aj.Classes({w.name: parse(w) for w in engine_classes()})
        with tempfile.TemporaryDirectory() as d:
            named, looked_for = self.builder(
                d, 'constant kEdgeToEdge = "com.runrev.android.EDGE_TO_EDGE"\n'
                   'constant kOther = "com.runrev.android.OTHER_KEY"\n',
                manifest='<meta-data android:name="com.runrev.android.EDGE_TO_EDGE"/>')
        self.assertEqual(named, [('Manifest.xml', 'com/runrev/android/EDGE_TO_EDGE'),
                                 ('revsaveasandroidstandalone.livecodescript', 'com/runrev/android/EDGE_TO_EDGE'),
                                 ('revsaveasandroidstandalone.livecodescript', 'com/runrev/android/OTHER_KEY')])
        for kept in (looked_for, ()):
            problems, lines = aj.check_named(named, classes, kept)
            self.assertEqual(problems, ['Manifest.xml names com/runrev/android/EDGE_TO_EDGE, which the jar does not '
                                        'have', 'revsaveasandroidstandalone.livecodescript names '
                                        'com/runrev/android/OTHER_KEY, which the jar does not have'])
            self.assertEqual(lines, ['revsaveasandroidstandalone.livecodescript names com/runrev/android/EDGE_TO_EDGE, '
                                     'meta-data and no class: ' + aj.META_DATA['com/runrev/android/EDGE_TO_EDGE'],
                                     '2 classes named by the manifest and the builder checked'])

    def test_meta_data_the_builder_writes_and_the_java_layer_reads(self):
        # every name META_DATA keeps is one the real builder names and the
        # Java layer reads as meta-data, so that the list keeps no stale name
        named = [cls for where, cls in aj.named_classes(os.path.join(REPO, 'no-runtime'))]
        activity = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'LiveCodeActivity.java')
        self.assertEqual(sorted(aj.META_DATA), ['com/runrev/android/EDGE_TO_EDGE'])
        for name in aj.META_DATA:
            self.assertIn(name, named)
            constant = re.search(r'public static final String (\w+) = "%s";' % re.escape(name.replace('/', '.')),
                                 activity).group(1)
            self.assertIn('t_meta_data.getBoolean(%s, false)' % constant, activity)

    def run_jni(self, *flags):
        """jni's status and output for a jar without RelaunchActivity, with
        a builder that names it only where the jar has it, the other checks
        stubbed (each has its own tests)"""
        names = ('check_exports', 'source_calls', 'check_calls', 'lcb_bindings', 'check_bindings', 'check_gles')
        saved = {x: getattr(aj, x) for x in names}
        with tempfile.TemporaryDirectory() as d:
            classes = jar(os.path.join(d, 'Classes'), engine_classes())
            runtime = os.path.join(d, 'Android')
            os.makedirs(os.path.join(runtime, 'arm64-v8a'))
            with open(os.path.join(runtime, 'arm64-v8a', aj.ENGINE_NAME), 'wb') as f:
                f.write(elf([], ['libGLESv1_CM.so']))
            builder = self.LOOKS_FOR.replace('put "import com.runrev.android.LiveCodeService;" after x\n', '')
            saved_builder = aj.BUILDER
            aj.BUILDER = os.path.join(d, 'revsaveasandroidstandalone.livecodescript')
            with open(aj.BUILDER, 'w') as f:
                f.write(builder)
            out = io.StringIO()
            try:
                for x in names:
                    found = x in ('source_calls', 'lcb_bindings')
                    setattr(aj, x, (lambda *a: []) if found else (lambda *a: ([], [])))
                with contextlib.redirect_stdout(out):
                    status = aj.main(['jni', '--classes', classes, '--runtime', runtime] + list(flags))
            finally:
                aj.BUILDER = saved_builder
                for x in names:
                    setattr(aj, x, saved[x])
        return status, out.getvalue()

    def test_jni_with_and_without_every_named(self):
        status, out = self.run_jni()
        self.assertEqual(status, 0, out)
        self.assertIn('RelaunchActivity only where the jar has it, and this jar has not', out)
        status, out = self.run_jni('--every-named')
        self.assertEqual(status, 1, out)
        self.assertIn('PROBLEM: revsaveasandroidstandalone.livecodescript names '
                      'com/runrev/android/RelaunchActivity, which the jar does not have', out)

    def test_the_workflow_asks_every_class_of_this_checkouts_jar(self):
        # --every-named on the jar built here, not on the release's
        workflow = read('.github', 'workflows', 'android-java.yml')
        built = re.search(r'jni --classes "\$RUNNER_TEMP/java/Classes"[^\n]*\n[^\n]*', workflow).group(0)
        shipped = re.search(r'jni --classes "\$RUNTIME/Classes"[^\n]*\n[^\n]*', workflow).group(0)
        self.assertIn('--every-named', built)
        self.assertNotIn('--every-named', shipped)


class Gles(unittest.TestCase):
    def classes(self, gles=None, delegate=None):
        return aj.Classes({w.name: parse(w) for w in engine_classes(gles=gles, delegate=delegate)})

    def test_no_attributes_is_es_1(self):
        self.assertEqual(aj.gles_version(self.classes(None)), 1)
        problems, lines = aj.check_gles(self.classes(None), {'arm64-v8a': ['libGLESv1_CM.so', 'libc.so']})
        self.assertEqual(problems, [])
        self.assertIn('OpenGLView.start() makes OpenGL ES 1 contexts', lines)
        self.assertIn('arm64-v8a: it calls OpenGLView.start(), which makes OpenGL ES 1 contexts', lines)

    def test_es_3_context_with_an_es_1_engine(self):
        self.assertEqual(aj.gles_version(self.classes(3)), 3)
        problems, _ = aj.check_gles(self.classes(3), {'arm64-v8a': ['libGLESv1_CM.so']})
        self.assertEqual(problems, ['arm64-v8a: the engine draws with OpenGL ES 1 (libGLESv1_CM.so), and '
                                    'OpenGLView.start() makes OpenGL ES 3 contexts'])
        self.assertEqual(aj.check_gles(self.classes(3), {'arm64-v8a': ['libGLESv3.so', 'libEGL.so']})[0], [])

    def test_no_view(self):
        self.assertEqual(aj.check_gles(aj.Classes({}), {})[0], ['the jar has no com/runrev/android/OpenGLView.start'])

    def test_start_calls_startgles(self):
        """This tree's view: start() calls startGLES(1), which makes its
        context with no attributes for 1 and of the version for more."""
        classes = self.classes(delegate=1)
        self.assertEqual(aj.gles_contexts(classes), (1, None))
        self.assertEqual(aj.gles_contexts(classes, 3), (1, 3))
        self.assertEqual(aj.gles_contexts(classes, 2), (1, 2))
        self.assertEqual(aj.gles_contexts(self.classes(delegate=3)), (3, None))
        # what this check cannot read: a start() that passes startGLES a
        # value from elsewhere, or a startGLES without the version it asks
        view = ClassWriter('com/runrev/android/OpenGLView', 'android/view/SurfaceView')
        view.method('start', '()V', code=[ALOAD_0, ALOAD_0, GETFIELD,
                                          ('ref', 'field', 'com/runrev/android/OpenGLView', 'm_version', 'I'),
                                          INVOKEVIRTUAL,
                                          ('ref', 'method', 'com/runrev/android/OpenGLView', 'startGLES', '(I)V'),
                                          RETURN])
        view.method('startGLES', '(I)V', code=STARTGLES_CODE)
        self.assertEqual(aj.gles_contexts(aj.Classes({view.name: parse(view)}), 3), (0, 3))
        view = ClassWriter('com/runrev/android/OpenGLView', 'android/view/SurfaceView')
        view.method('start', '()V', code=[ALOAD_0, ICONST_2, INVOKEVIRTUAL,
                                          ('ref', 'method', 'com/runrev/android/OpenGLView', 'startGLES', '(I)V'),
                                          RETURN])
        view.method('startGLES', '(I)V', code=[0x06, 0xbc, 10, 0x59, ICONST_0, SIPUSH, ('u2', 0x3098), 0x4f,
                                               0x59, ICONST_0, 0x1b, 0x4f, 0x4d, RETURN])
        self.assertEqual(aj.gles_contexts(aj.Classes({view.name: parse(view)}), 3), (0, 0))
        problems, _ = aj.check_gles(aj.Classes({view.name: parse(view)}), {'x86': ['libGLESv3.so']}, 3)
        self.assertEqual(problems, ['com/runrev/android/OpenGLView.start asks for an OpenGL ES version this check '
                                    'cannot read',
                                    'x86: OpenGLView.startGLES(3) asks for an OpenGL ES version this check cannot '
                                    'read'])

    def test_both_engines_with_this_trees_view(self):
        """One Java layer, two engines: 9.6.3's (libGLESv1_CM) calls start()
        and gets OpenGL ES 1; one built from this tree (libGLESv3) calls
        startGLES with the source's version and gets OpenGL ES 3."""
        classes = self.classes(delegate=1)
        old = {'arm64-v8a': ['libGLESv1_CM.so', 'libc.so']}
        new = {'arm64-v8a': ['libGLESv3.so', 'libEGL.so'], 'x86': ['libGLESv3.so']}
        problems, lines = aj.check_gles(classes, old, 3)
        self.assertEqual(problems, [])
        self.assertIn('arm64-v8a: it calls OpenGLView.start(), which makes OpenGL ES 1 contexts', lines)
        problems, lines = aj.check_gles(classes, new, 3)
        self.assertEqual(problems, [])
        self.assertIn('arm64-v8a: it calls OpenGLView.startGLES(3), which makes OpenGL ES 3 contexts', lines)
        self.assertIn('x86: it calls OpenGLView.startGLES(3), which makes OpenGL ES 3 contexts', lines)
        # the engine of this tree, had its source kept calling start()
        self.assertEqual(aj.check_gles(classes, new, None)[0],
                         ['arm64-v8a: the engine draws with OpenGL ES 3 (libGLESv3.so), and OpenGLView.start() '
                          'makes OpenGL ES 1 contexts',
                          'x86: the engine draws with OpenGL ES 3 (libGLESv3.so), and OpenGLView.start() makes '
                          'OpenGL ES 1 contexts'])
        # or asked for a version the library is not
        self.assertEqual(aj.check_gles(classes, {'x86': ['libGLESv3.so']}, 2)[0],
                         ['x86: the engine draws with OpenGL ES 3 (libGLESv3.so), and OpenGLView.startGLES(2) '
                          'makes OpenGL ES 2 contexts'])
        # and a source this check cannot read
        self.assertEqual(aj.check_gles(classes, {'x86': ['libGLESv3.so']}, 0)[0],
                         ['x86: engine/src/mblandroiddc.cpp asks OpenGLView for an OpenGL ES version this check '
                          'cannot read'])

    def test_the_config_can_make_the_context(self):
        """The view's source: for OpenGL ES 1, the config LiveCode's Java
        always chose (findConfig of four sizes, which says nothing of the
        renderable type); from OpenGL ES 2 on, one that says it can make
        that version's context, or none so that the next sizes are tried
        (the EGL default, OpenGL ES 1 alone, may give a config that cannot
        make an OpenGL ES 3 context first)"""
        src = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'OpenGLView.java')
        four = re.search(r'(?s)private EGLConfig findConfig\(int r, int g, int b, int a\)\s*\{(.*?)\n\t\}', src)
        self.assertNotIn('RENDERABLE', four.group(1))
        self.assertIn('return t_configs[0];', four.group(1))
        five = re.search(r'(?s)private EGLConfig findConfig\(int r, int g, int b, int a, int p_gles_version\)\s*'
                         r'\{(.*?)\n\t\}', src).group(1)
        self.assertRegex(five, r'^\s*if \(p_gles_version <= 1\)\s+return findConfig\(r, g, b, a\);')
        self.assertIn('EGL_RENDERABLE_TYPE, p_gles_version >= 3 ? EGL_OPENGL_ES3_BIT_KHR : EGL_OPENGL_ES2_BIT,', five)
        self.assertEqual(five.count('return null;'), 2)
        # EGL's values (EGL 1.5 and EGL_KHR_create_context)
        for name, value in (('EGL_RENDERABLE_TYPE', '0x3040'), ('EGL_OPENGL_ES2_BIT', '0x0004'),
                            ('EGL_OPENGL_ES3_BIT_KHR', '0x0040')):
            self.assertIn('private static final int %s = %s;' % (name, value), src)
        start = re.search(r'(?s)public void startGLES\(int p_gles_version\)\s*\{(.*?)\n\t\}', src).group(1)
        sizes = re.findall(r'findConfig\((\d+, \d+, \d+, \d+)(, p_gles_version)?\)', start)
        self.assertEqual(sizes, [(x, ', p_gles_version') for x in ('8, 8, 8, 8', '5, 6, 5, 0', '5, 5, 5, 0',
                                                                     '4, 4, 4, 4', '0, 0, 0, 0')])
        self.assertRegex(src, r'public void start\(\)\s*\{\s*startGLES\(1\);\s*\}')

    def test_the_shipped_view_with_each_engine(self):
        """LiveCode 9.6.3's view has no startGLES: right for its own engine,
        and an engine built from this tree could not draw with it."""
        classes = self.classes(None)
        self.assertEqual(aj.check_gles(classes, {'x86': ['libGLESv1_CM.so']}, 3)[0], [])
        self.assertEqual(aj.check_gles(classes, {'x86': ['libGLESv3.so']}, 3)[0],
                         ['x86: the engine calls OpenGLView.startGLES(3) (engine/src/mblandroiddc.cpp), which the '
                          'jar does not have'])

    def test_the_source_reader(self):
        call = ('static const jint kMCAndroidOpenGLESVersion = 3;\n'
                's_openglview_start_method = env -> GetMethodID(t_view_class, "startGLES", "(I)V");\n'
                's_java_env -> CallVoidMethod(s_android_opengl_view, s_openglview_start_method, '
                'kMCAndroidOpenGLESVersion);\n')
        self.assertEqual(aj.source_gles_version(call), 3)
        self.assertEqual(aj.source_gles_version(call.replace('= 3;', '= 2;')), 2)
        # LiveCode's own call
        self.assertIsNone(aj.source_gles_version(
            's_openglview_start_method = env -> GetMethodID(t_view_class, "start", "()V");\n'
            's_java_env -> CallVoidMethod(s_android_opengl_view, s_openglview_start_method);\n'))
        # what it cannot read: no version, or one not passed
        self.assertEqual(aj.source_gles_version(call.replace('kMCAndroidOpenGLESVersion = 3', 'kOther = 3')), 0)
        self.assertEqual(aj.source_gles_version(call.replace(', kMCAndroidOpenGLESVersion)', ', 3)')), 0)
        self.assertEqual(aj.source_gles_version('nothing'), 0)
        # and the tree's
        self.assertEqual(aj.source_gles_version(), 3)


class Rules(unittest.TestCase):
    GET = ('ref', 'method', 'android/app/PendingIntent', 'getBroadcast',
           '(Landroid/content/Context;ILandroid/content/Intent;I)Landroid/app/PendingIntent;')

    def classes(self, flags):
        w = ClassWriter('com/runrev/android/NotificationModule')
        w.method('make', '(Landroid/content/Context;Landroid/content/Intent;)V', 0x0009,
                 code=[ALOAD_0 + 0, ICONST_0, ALOAD_1] + flags + [INVOKESTATIC, self.GET, POP, RETURN])
        return {w.name: parse(w)}

    def test_flags_from_utils(self):
        flags = [ICONST_0, INVOKESTATIC, ('ref', 'method', 'com/runrev/android/Utils', 'immutablePendingIntentFlags',
                                          '(I)I')]
        problems, lines = aj.check_pending_intents(self.classes(flags))
        self.assertEqual(problems, [])
        self.assertEqual(lines, ['1 PendingIntent.get* calls checked'])

    def test_bare_flags(self):
        problems, _ = aj.check_pending_intents(self.classes([ICONST_0]))
        self.assertEqual(len(problems), 1)
        self.assertIn('(the instruction before: const 0)', problems[0])


# ---------------------------------------------------------------------------

def glob_regex(pattern):
    """GitHub's path filter glob: * and ? stop at /, ** does not."""
    out = []
    i = 0
    while i < len(pattern):
        if pattern.startswith('**', i):
            out.append('.*')
            i += 2
            continue
        out.append({'*': '[^/]*', '?': '[^/]'}.get(pattern[i], re.escape(pattern[i])))
        i += 1
    return re.compile('^' + ''.join(out) + '$')


def workflow_paths(workflow, anchor):
    """The paths list a workflow anchors as &anchor."""
    block = re.search(r'(?s)paths: &%s\n(.*?)\n  \w+:' % anchor, workflow).group(1)
    return [line.strip()[2:].strip().strip("'") for line in block.splitlines() if line.strip().startswith('- ')]


def starts(paths, rel):
    return any(glob_regex(p).match(rel) for p in paths)


class OneSystem(unittest.TestCase):
    """The Java sources, the check's lists and the workflows agree"""

    def test_every_pending_intent_says_its_mutability(self):
        root = os.path.join(REPO, 'engine', 'src', 'java')
        calls = 0
        for folder, _dirs, names in os.walk(root):
            if os.sep + 'sample' in folder:
                continue
            for name in names:
                if not name.endswith('.java'):
                    continue
                with open(os.path.join(folder, name), encoding='utf-8') as f:
                    text = f.read()
                for m in re.finditer(r'PendingIntent\.get(?:Activity|Activities|Broadcast|Service|ForegroundService)'
                                     r'\(([^;]*)\);', text):
                    calls += 1
                    self.assertRegex(m.group(1), r'Utils\.(im)?mutablePendingIntentFlags\(',
                                     '%s: %s' % (name, m.group(0)))
        self.assertGreaterEqual(calls, 5)

    def test_notifications_ask_to_post_only_when_declared(self):
        # Android 13 shows an app's notifications only once the user lets it
        # post them: scheduling one asks, once a run, and only an app whose
        # manifest declares POST_NOTIFICATIONS (one that does not is never
        # asked, as before); the notification is scheduled either way
        java = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'NotificationModule.java')
        create = re.search(r'(?s)public long createLocalNotification\(.*?\n    }\n', java).group(0)
        self.assertRegex(create, r'resetTimer\(m_engine\.getContext\(\)\);\s*requestPostNotifications\(\);\s*'
                                 r'return t_row_id;\s*}\n$')
        self.assertEqual(java.count('requestPostNotifications()'), 2)
        self.assertIn('public static final String POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS";',
                      java)
        ask = re.search(r'(?s)protected void requestPostNotifications\(\)\n    {\n(.*?)\n    }\n', java).group(1)
        guard = ask.index('return;')
        for part in ('Build.VERSION.SDK_INT < 33 || s_asked_to_post',
                     't_context.checkSelfPermission(POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED ||',
                     '!Utils.declaresPermission(t_context, POST_NOTIFICATIONS) || !(t_context instanceof Activity)'):
            self.assertIn(part, ask)
        # every return comes before it is marked asked, and that before it asks
        asked = ask.index('s_asked_to_post = true;')
        request = ask.index('((Activity)t_context).requestPermissions(new String[] {POST_NOTIFICATIONS},\n'
                            '                                                 Engine.POST_NOTIFICATIONS_REQUEST_CODE);')
        self.assertLess(guard, asked)
        self.assertLess(ask.rindex('return;'), asked)
        self.assertLess(asked, request)
        self.assertEqual(ask.count('requestPermissions('), 1)
        # never initialised in <clinit>: compare would see a new class initialiser
        self.assertIn('protected static boolean s_asked_to_post;\n', java)
        # the engine: its own request code answers androidRequestPermission,
        # and nothing else does
        engine = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'Engine.java')
        codes = dict(re.findall(r'public static final int (\w+_REQUEST_CODE) = (\d+);', engine))
        self.assertEqual(codes, {'PERMISSION_REQUEST_CODE': '1', 'POST_NOTIFICATIONS_REQUEST_CODE': '2'})
        result = re.search(r'(?s)public void onRequestPermissionsResult\(int requestCode, String\[\] permissions, '
                           r'int\[\] grantResults\)\n    {\n(.*?)\n    }\n', engine).group(1)
        self.assertEqual(result.split(), (
            'if (requestCode != PERMISSION_REQUEST_CODE) return; onAskPermissionDone(grantResults.length > 0 && '
            'grantResults[0] == PackageManager.PERMISSION_GRANTED);').split())
        self.assertIn('t_activity.requestPermissions(new String[]{p_permission}, PERMISSION_REQUEST_CODE);', engine)
        # what the manifest declares, as Android reads it
        utils = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'Utils.java')
        declares = re.search(r'(?s)public static boolean declaresPermission\(Context p_context, String '
                             r'p_permission\)\n    {\n(.*?)\n    }\n', utils).group(1)
        for part in ('getPackageInfo(p_context.getPackageName(),', 'PackageManager.GET_PERMISSIONS',
                     'if (t_info.requestedPermissions != null)', 'if (p_permission.equals(t_permission))',
                     'return true;', 'catch (PackageManager.NameNotFoundException e)'):
            self.assertIn(part, declares)
        self.assertTrue(declares.rstrip().endswith('return false;'))
        # and both changes are named, with their reasons, against the
        # shipped jar
        for key in ('code com/runrev/android/NotificationModule.createLocalNotification:(Ljava/lang/String;'
                    'Ljava/lang/String;Ljava/lang/String;JZI)J',
                    'code com/runrev/android/Engine.onRequestPermissionsResult:(I[Ljava/lang/String;[I)V'):
            self.assertTrue([sha for sha, entries in aj.EXPECTED.items() if key in entries], key)

    def test_write_external_storage_on_android_13(self):
        # Android 13 and newer refuse WRITE_EXTERNAL_STORAGE without asking,
        # and it gives an app that targets API 30 or newer nothing: for an
        # app that declares it, it counts as granted there, without asking,
        # so what the engine asks for it first works. Only that permission,
        # only there, only declared; everything else is asked as before
        engine = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'Engine.java')
        self.assertIn('public static final String WRITE_EXTERNAL_STORAGE = '
                      '"android.permission.WRITE_EXTERNAL_STORAGE";', engine)
        rule = re.search(r'(?s)protected boolean grantedWithoutAsking\(String p_permission\)\n    {\n(.*?)\n    }\n',
                         engine).group(1)
        self.assertEqual(rule.split(), (
            'return Build.VERSION.SDK_INT >= 33 && WRITE_EXTERNAL_STORAGE.equals(p_permission) && '
            'getContext().getApplicationInfo().targetSdkVersion >= 30 && '
            'Utils.declaresPermission(getContext(), p_permission);').split())
        # asking: granted at once, as for one already granted, and nothing
        # is requested; else as before
        ask = re.search(r'(?s)public boolean askPermission\(String p_permission\)\n    {\n(.*?)\n    }\n',
                        engine).group(1)
        self.assertTrue(ask.lstrip().startswith('if (grantedWithoutAsking(p_permission))\n'
                                                '            onAskPermissionDone(true);\n'
                                                '        else if (Build.VERSION.SDK_INT >= 23 && '
                                                'getContext().checkSelfPermission(p_permission)'), ask)
        self.assertEqual(ask.count('requestPermissions('), 1)
        self.assertEqual(ask.count('onAskPermissionDone(true);'), 2)
        self.assertTrue(ask.rstrip().endswith('return true;'))
        # androidHasPermission: the same answer
        has = re.search(r'(?s)public boolean checkHasPermissionGranted\(String p_permission\)\n    {\n(.*?)\n    }\n',
                        engine).group(1)
        self.assertTrue(has.lstrip().startswith('if (grantedWithoutAsking(p_permission))\n'
                                                '            return true;\n'
                                                '        if (Build.VERSION.SDK_INT >= 23)'), has)
        self.assertEqual(engine.count('grantedWithoutAsking('), 3)
        for key in ('code com/runrev/android/Engine.askPermission:(Ljava/lang/String;)Z',
                    'code com/runrev/android/Engine.checkHasPermissionGranted:(Ljava/lang/String;)Z'):
            self.assertTrue([sha for sha, entries in aj.EXPECTED.items() if key in entries], key)

    def test_export_to_album_through_media_store(self):
        # Android 10 and newer: the picture goes into the shared Pictures
        # folder through MediaStore, by the name and type the older code
        # gave the file, answered as it answered; Android 9 and older write
        # the file as before
        engine = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'Engine.java')
        export = re.search(r'(?s)public String exportImageToAlbum \(byte\[\] t_image_data, String t_file_name, '
                           r'String t_file_type\)\n    {\n(.*?)\n    }\n', engine).group(1)
        branch = export.index('if (Build.VERSION.SDK_INT >= 29)\n'
                              '                return exportImageToMediaStore(t_image_data, t_filename, t_file_type);')
        # after the name is made (as before), before any file is written
        self.assertLess(export.rindex('t_filename = t_file_name + t_file_type;'), branch)
        self.assertLess(export.index('t_filename = "I" + t_uuid.toString().substring(0,7) + t_file_type;'), branch)
        self.assertLess(branch, export.index('new FileOutputStream(t_file)'))
        self.assertLess(export.index('if (t_image_data == null)\n            return "export failed";'), branch)
        store = re.search(r'(?s)protected String exportImageToMediaStore\(byte\[\] p_data, String p_filename, '
                          r'String p_file_type\)\n    {\n(.*?)\n    }\n', engine).group(1)
        for part in ('MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)',
                     'String t_folder = Environment.DIRECTORY_PICTURES + "/";',
                     'Uri t_uri = ownPicture(t_resolver, t_collection, p_filename, t_folder);',
                     't_values.put(MediaStore.MediaColumns.DISPLAY_NAME, p_filename);',
                     't_values.put(MediaStore.MediaColumns.MIME_TYPE, imageMimeType(p_file_type));',
                     't_values.put(MediaStore.MediaColumns.RELATIVE_PATH, t_folder);',
                     't_values.put(MediaStore.MediaColumns.IS_PENDING, 1);',
                     't_uri = t_resolver.insert(t_collection, t_values);',
                     'if (t_uri == null)\n                    return "export failed";',
                     'OutputStream t_out = t_resolver.openOutputStream(t_uri, "wt");',
                     't_out.write(p_data, 0, p_data.length);',
                     't_values.put(MediaStore.MediaColumns.IS_PENDING, 0);',
                     't_resolver.update(t_uri, t_values, null, null);',
                     'catch (IOException | RuntimeException e)',
                     't_resolver.delete(t_uri, null, null);',
                     'return e.toString();'):
            self.assertIn(part, store)
        # the stream is closed however the write ends; only a picture this
        # call inserted is marked done, or deleted when the write fails
        self.assertRegex(store, r'(?s)try\s*{\s*t_out\.write\(.*?\}\s*finally\s*{\s*t_out\.close\(\);')
        self.assertEqual(store.count('if (t_inserted)'), 2)
        self.assertLess(store.index('t_inserted = true;'), store.index('openOutputStream'))
        # null is success, as the older code answered
        self.assertTrue(store.rstrip().endswith('return null;'))
        # an existing picture is written over only when this app added it
        own = re.search(r'(?s)protected Uri ownPicture\(ContentResolver p_resolver, Uri p_collection, String '
                        r'p_filename, String p_folder\)\n    {\n(.*?)\n    }\n', engine).group(1)
        for part in ('MediaStore.MediaColumns.OWNER_PACKAGE_NAME',
                     'MediaStore.MediaColumns.DISPLAY_NAME + "=? AND " +',
                     'MediaStore.MediaColumns.RELATIVE_PATH + "=?"', 'new String[] {p_filename, p_folder}',
                     'if (getContext().getPackageName().equals(t_cursor.getString(1)))',
                     'return ContentUris.withAppendedId(p_collection, t_cursor.getLong(0));',
                     't_cursor.close();'):
            self.assertIn(part, own)
        self.assertTrue(own.rstrip().endswith('return null;'))
        # the engine's three types (exec-misc.cpp: ".png", ".gif", ".jpg")
        types = re.findall(r'"(\.\w+)\\n"', read('engine', 'src', 'exec-misc.cpp'))
        self.assertEqual(sorted(set(types)), ['.gif', '.jpg', '.png'])
        mime = re.search(r'(?s)protected static String imageMimeType\(String p_file_type\)\n    {\n(.*?)\n    }\n',
                         engine).group(1)
        self.assertEqual(mime.split(), ('if (".png".equalsIgnoreCase(p_file_type)) return "image/png"; '
                                        'if (".gif".equalsIgnoreCase(p_file_type)) return "image/gif"; '
                                        'return "image/jpeg";').split())
        # no new class initialiser: the new fields are constants
        self.assertNotIn('static {', engine)
        key = ('code com/runrev/android/Engine.exportImageToAlbum:([BLjava/lang/String;Ljava/lang/String;)'
               'Ljava/lang/String;')
        self.assertTrue([sha for sha, entries in aj.EXPECTED.items() if key in entries], key)

    def test_back_reaches_backkey_through_the_back_callback(self):
        # Android 16 and newer call only the window's back callback for an
        # app that targets API 36: it does what onBackPressed does, which
        # is what it did; registered from Android 13 on (where Android
        # ignores it below target 36, and calls onBackPressed as before)
        activity = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'LiveCodeActivity.java')
        create = re.search(r'(?s)protected void onCreate\(Bundle p_saved_state\)\n\t{\n(.*?)\n\t}\n', activity).group(1)
        self.assertRegex(create, r'if \(Build\.VERSION\.SDK_INT >= 33\)\s+registerBackCallback\(\);')
        register = re.search(r'(?s)protected void registerBackCallback\(\)\n    {\n(.*?)\n    }\n', activity).group(1)
        self.assertEqual(register.split(), (
            'getOnBackInvokedDispatcher().registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, '
            'new BackCallback(this));').split())
        invoked = re.search(r'(?s)protected static class BackCallback implements OnBackInvokedCallback\n    {\n(.*?)'
                            r'\n    }\n', activity).group(1)
        self.assertRegex(invoked, r'public void onBackInvoked\(\)\s*{\s*m_activity\.onBackPressed\(\);\s*}')
        # onBackPressed is the stack's backKey, as before, in an activity
        # that started the engine (one that started the app again in a new
        # process has none to pass it to)
        self.assertRegex(activity, r'public void onBackPressed\(\)\s*{\s*if \(!m_engine_started\)\s+return;\s*'
                                   r's_main_view\.onBackPressed\(\);\s*}')
        # the busy indicator's dialog: its key listener and its callback do
        # one thing, what the listener did
        busy = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'BusyIndicator.java')
        show = re.search(r'(?s)public void showBusyIndicator\(String p_label\)\n    {\n(.*?)\n    }\n', busy).group(1)
        self.assertRegex(show, r'event\.getRepeatCount\(\) == 0\)\s*{\s*backPressed\(\);\s*return true;\s*}')
        self.assertRegex(show, r'if \(Build\.VERSION\.SDK_INT >= 33\)\s+registerBackCallback\(t_dialog\);')
        self.assertLess(show.index('setOnKeyListener'), show.index('registerBackCallback(t_dialog)'))
        pressed = re.search(r'(?s)protected void backPressed\(\)\n    {\n(.*?)\n    }\n', busy).group(1)
        self.assertEqual(pressed.split(), 'for (ProgressDialog t_dialog : m_dialog) t_dialog.dismiss(); '
                                          'm_engine.doBackPressed();'.split())
        self.assertIn('p_dialog.getOnBackInvokedDispatcher().registerOnBackInvokedCallback('
                      'OnBackInvokedDispatcher.PRIORITY_DEFAULT,', busy)
        self.assertRegex(busy, r'public void onBackInvoked\(\)\s*{\s*m_indicator\.backPressed\(\);\s*}')
        for key in ('code com/runrev/android/LiveCodeActivity.onCreate:(Landroid/os/Bundle;)V',
                    'code com/runrev/android/BusyIndicator.showBusyIndicator:(Ljava/lang/String;)V',
                    'code com/runrev/android/BusyIndicator$1.onKey:(Landroid/content/DialogInterface;ILandroid/view/'
                    'KeyEvent;)Z'):
            self.assertTrue([sha for sha, entries in aj.EXPECTED.items() if key in entries], key)

    def test_the_activity_without_an_engine_is_a_recorded_change(self):
        # each LiveCodeActivity method that now does nothing without an
        # engine (test_android_builder pins which) differs on purpose, and
        # compare says why: from 9.6.3's Classes (oxt-runtimes-1.15's) and
        # from the first one built here (oxt-runtimes-0.2.7-rc.6.18b's,
        # which the runtimes asset of 0.2.7-rc.6.18 carries) alike
        keys = ['code com/runrev/android/LiveCodeActivity.' + sig for sig in (
            'onRestart:()V', 'onResume:()V', 'onPause:()V', 'onNewIntent:(Landroid/content/Intent;)V',
            'onLowMemory:()V', 'onConfigurationChanged:(Landroid/content/res/Configuration;)V',
            'onBackPressed:()V', 'onKeyDown:(ILandroid/view/KeyEvent;)Z',
            'onActivityResult:(IILandroid/content/Intent;)V', 'onRequestPermissionsResult:(I[Ljava/lang/String;[I)V')]
        self.assertEqual(sorted(aj.RELAUNCH_GUARDS), sorted(keys))
        configuration = 'code com/runrev/android/LiveCodeActivity.onConfigurationChanged:' \
                        '(Landroid/content/res/Configuration;)V'
        for sha in ('c10841215d429fdc084025805c1abfcaef2e2f8086da4af9cf5935f36159dbc0',
                    'e28f35a674222e798ed824ab2a22b0c6370dc37e86573a34565af0dbd6050360'):
            for key in keys:
                if key == configuration:
                    # and the bars' icons of a stack drawn edge to edge
                    # (test_edge_to_edge_when_the_app_asks)
                    self.assertEqual(aj.EXPECTED[sha][key], aj.RELAUNCH_GUARDS[key] + '. And ' +
                                     aj.EDGE_TO_EDGE_ON_CONFIGURATION, (sha, key))
                else:
                    self.assertEqual(aj.EXPECTED[sha][key], aj.RELAUNCH_GUARDS[key], (sha, key))
        # the first Classes built here differs in nothing else, bar the
        # engine finishing what it drew (test_the_engine_finishes_drawing_first)
        # and a stack drawn edge to edge (test_edge_to_edge_when_the_app_asks)
        self.assertEqual(aj.EXPECTED['e28f35a674222e798ed824ab2a22b0c6370dc37e86573a34565af0dbd6050360'],
                         dict(aj.RELAUNCH_GUARDS, **aj.FINISH_DRAWING, **aj.EDGE_TO_EDGE, **{
                             'code com/runrev/android/LiveCodeActivity.onDestroy:()V':
                                 aj.FINISH_DRAWING_ON_DESTROY,
                             'code com/runrev/android/LiveCodeActivity.onCreate:(Landroid/os/Bundle;)V':
                                 aj.EDGE_TO_EDGE_ON_CREATE,
                             configuration: aj.RELAUNCH_GUARDS[configuration] + '. And ' +
                                 aj.EDGE_TO_EDGE_ON_CONFIGURATION}))

    def test_the_engine_finishes_drawing_first(self):
        # Android 16 made the activity again for a density change while the
        # engine, having drawn into the bitmap, had yielded to Android's
        # thread with a wake-up due at once to show it; onDestroy cleared
        # that wake-up, and LiveCode 9.6.3's engine, resumed once as it is
        # destroyed, went on from the drawing only to yield again from its
        # wait while Android's thread joined it: hung for good, the screen
        # black (runs 42558963677 and 42593463112). So onDestroy first runs
        # the wake-up the engine asked for as it drew, as the handler would
        # have, until it yields without drawing, at most eight times
        engine = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'Engine.java')
        self.assertIn('    private volatile boolean m_wake_after_drawing;\n', engine)
        self.assertIn('    private static final int FINISH_DRAWING_WAKE_UPS = 8;\n', engine)
        # scheduling a wake-up says the engine has not drawn (yet)...
        schedule = re.search(r'(?s)public synchronized void scheduleWakeUp\(int p_in_time, boolean p_any_event\)\n\t{\n(.*?)\n\t}\n',
                             engine).group(1)
        self.assertTrue(' '.join(schedule.split()).endswith(
            'm_wake_scheduled = true; m_wake_on_event = p_any_event; m_wake_after_drawing = false; '
            'm_handler . sendEmptyMessageDelayed(0, p_in_time);'), schedule)
        self.assertEqual(engine.count('m_wake_after_drawing = false;'), 1)
        # ...and invalidating the bitmap, which comes after it, that it has
        invalidate = re.search(r'(?s)public void invalidateBitmap\(int l, int t, int r, int b\)\n\t{\n(.*?)\n\t}\n',
                               engine).group(1)
        self.assertRegex(invalidate, r'^\s*(?://[^\n]*\s+)*m_wake_after_drawing = true;\s+'
                                     r'if \(m_bitmap_view != null && m_bitmap_view\.getVisibility\(\) == View\.VISIBLE\)')
        self.assertEqual(engine.count('m_wake_after_drawing = true;'), 1)
        # the engine's side, in this tree as in 9.6.3's: as it yields to
        # Android, the wake-up is scheduled first and the bitmap invalidated
        # after; and only the bitmap's drawing fills the dirty region, whose
        # updatewindow then yields with a wake-up due at once
        native = read('engine', 'src', 'mblandroiddc.cpp')
        to_engine = re.search(r'(?s)static void co_yield_to_engine\(void\)\n{\n(.*?)\n}\n', native).group(1)
        self.assertLess(to_engine.index('CallVoidMethod(s_android_view, s_schedule_wakeup_method,'),
                        to_engine.index('MCAndroidInvalidateBitmapRegion(s_android_bitmap_dirty_region);'))
        self.assertEqual(native.count('MCAndroidInvalidateBitmapRegion(s_android_bitmap_dirty_region);'), 1)
        self.assertEqual(len(re.findall(r'MCGRegionAdd\w+\(s_android_bitmap_dirty_region,', native)), 2)
        update = re.search(r'(?s)void MCStack::view_device_updatewindow\(MCRegionRef p_region\)\n{\n(.*?)\n}\n',
                           native).group(1)
        bitmap = update.split('\n\telse\n')[0]
        self.assertIn('if (s_updatewindow_callback != nil || !s_android_opengl_enabled)', bitmap)
        self.assertTrue(bitmap.rstrip().endswith('co_yield_to_android_and_wait(0.0, true);\n\t}'), bitmap[-200:])
        self.assertEqual(native.count('co_yield_to_android_and_wait(0.0, true);'), 1)
        # finishDrawing runs the wake-up that is scheduled while it is one
        # the engine asked for as it drew, as the handler runs it
        finish = re.search(r'(?s)public void finishDrawing\(\)\n    {\n(.*?)\n    }\n', engine).group(1)
        self.assertEqual(finish.split(), (
            'int t_wake_ups = 0; '
            'while (t_wake_ups < FINISH_DRAWING_WAKE_UPS && m_wake_scheduled && m_wake_after_drawing) { '
            'm_handler . removeMessages(0); m_wake_scheduled = false; t_wake_ups += 1; doProcess(true); } '
            'if (t_wake_ups > 0) Log.i(TAG, "finishDrawing: the engine finished what it drew before the activity '
            'went (" + t_wake_ups + " wake-up(s))");').split())
        # the line the device check looks for
        self.assertIn('"%s ' % ac.FINISHED_DRAWING, finish)
        self.assertEqual(re.search(r'public static final String TAG = "([^"]+)";', engine).group(1),
                         'revandroid.Engine')
        handler = re.search(r'(?s)public void handleMessage\(Message p_message\) {\n(.*?)\n\t\t\t}', engine).group(1)
        self.assertEqual(handler.split(), 'm_wake_scheduled = false; doProcess(true);'.split())
        # in onDestroy, of an activity that started the engine, before the
        # wake-up is cleared and the engine destroyed
        activity = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'LiveCodeActivity.java')
        destroy = re.search(r'(?s)protected void onDestroy\(\)\n\t{\n(.*?)\n\t}\n', activity).group(1)
        code = [x.strip() for x in destroy.splitlines() if x.strip() and not x.strip().startswith('//')]
        self.assertEqual(code[:6], ['super.onDestroy();', 'if (!m_engine_started)', 'return;',
                                    's_main_view.finishDrawing();', 's_main_view.clearWakeUp();',
                                    's_main_view.onDestroy();'])
        self.assertEqual(activity.count('finishDrawing()'), 1)
        self.assertEqual(engine.count('finishDrawing()'), 1)
        # named, with its reason, against every Classes compare knows
        for sha, entries in aj.EXPECTED.items():
            for key in aj.FINISH_DRAWING:
                self.assertEqual(entries[key], aj.FINISH_DRAWING[key], (sha, key))
            self.assertIn(aj.FINISH_DRAWING_ON_DESTROY, entries['code com/runrev/android/LiveCodeActivity.onDestroy:()V'])
        # rc.6.19's (the runtimes asset pinned now) differs in nothing else,
        # bar a stack drawn edge to edge (test_edge_to_edge_when_the_app_asks)
        self.assertEqual(aj.EXPECTED['328a531ae3d1f5845fbaa4174760187f2e7435855a5481541f9f8927880e414d'],
                         dict(aj.FINISH_DRAWING, **aj.EDGE_TO_EDGE, **{
                             'code com/runrev/android/LiveCodeActivity.onDestroy:()V': aj.FINISH_DRAWING_ON_DESTROY,
                             'code com/runrev/android/LiveCodeActivity.onCreate:(Landroid/os/Bundle;)V':
                                 aj.EDGE_TO_EDGE_ON_CREATE,
                             'code com/runrev/android/LiveCodeActivity.onConfigurationChanged:'
                             '(Landroid/content/res/Configuration;)V': aj.EDGE_TO_EDGE_ON_CONFIGURATION}))

    def test_edge_to_edge_keeps_the_stack_out_of_the_bars(self):
        # an app that targets API 35 or newer is drawn edge to edge on
        # Android 15 and newer: the view that holds the stack (and the
        # native controls' layers, its children) is padded by the bars, the
        # cutout and, while the window is to resize for it, the keyboard;
        # an app that targets less is laid out as before
        activity = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'LiveCodeActivity.java')
        create = re.search(r'(?s)protected void onCreate\(Bundle p_saved_state\)\n\t{\n(.*?)\n\t}\n', activity).group(1)
        self.assertRegex(create, r'if \(Build\.VERSION\.SDK_INT >= 35 && getApplicationInfo\(\)\.targetSdkVersion >= '
                                 r'35\)\s+keepOutOfSystemBars\(\);')
        self.assertLess(create.index('setContentView('), create.index('keepOutOfSystemBars();'))
        self.assertIn('s_main_layout.setOnApplyWindowInsetsListener(new SystemBarsPadding(this));', activity)
        pad = re.search(r'(?s)public WindowInsets onApplyWindowInsets\(View p_view, WindowInsets p_insets\)\n'
                        r'        {\n(.*?)\n        }\n', activity).group(1)
        self.assertEqual(pad.split(), (
            'int t_types = WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout(); '
            'if ((m_activity.getWindow().getAttributes().softInputMode & '
            'WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST) == WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE) '
            't_types |= WindowInsets.Type.ime(); '
            'Insets t_bars = p_insets.getInsets(t_types); '
            'p_view.setPadding(t_bars.left, t_bars.top, t_bars.right, t_bars.bottom); '
            'return WindowInsets.CONSUMED;').split())
        # the window resizes for the keyboard unless the stack says "pan"
        self.assertIn('getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);', activity)
        # everything the stack shows is a child of that view, filling it
        engine = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'Engine.java')
        self.assertIn('new NativeControlModule(this, ((LiveCodeActivity)getContext()).s_main_layout)', engine)
        self.assertIn('t_main_view.addView(m_view_layout, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.'
                      'MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));', engine)
        native = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'nativecontrol', 'NativeControlModule.java')
        self.assertRegex(native, r'm_parent \. addView\(m_layout,\s*new FrameLayout\.LayoutParams\(FrameLayout\.'
                                 r'LayoutParams\.MATCH_PARENT,\s*FrameLayout\.LayoutParams\.MATCH_PARENT\)\);')
        self.assertRegex(activity, r's_main_layout \. addView\(s_main_view,\s*new FrameLayout\.LayoutParams\('
                                   r'FrameLayout\.LayoutParams\.MATCH_PARENT,\s*FrameLayout\.LayoutParams\.MATCH_PARENT\)\);')

    def test_edge_to_edge_when_the_app_asks(self):
        # a stack can ask to be drawn edge to edge (the Android card's "Edge
        # to edge", the stack's "android,edge to edge"), which the builder
        # writes into the manifest as meta-data of the application
        # (test_android_builder's EdgeToEdge): on Android 11 and newer the
        # activity then draws it so, under the see-through bars and into the
        # cutout, whatever API the app targets; an app that does not ask is
        # laid out as before (test_edge_to_edge_keeps_the_stack_out_of_the_bars)
        activity = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'LiveCodeActivity.java')
        builder = read('ide-support', 'revsaveasandroidstandalone.livecodescript')
        key = re.search(r'public static final String EDGE_TO_EDGE = "([^"]+)";', activity).group(1)
        self.assertEqual(key, 'com.runrev.android.EDGE_TO_EDGE')
        self.assertIn('constant kEdgeToEdge = "%s"\n' % key, builder)
        # the class the builder looks for before it asks: the layer's own
        self.assertIn('constant kEdgeToEdgeClass = "com/runrev/android/LiveCodeActivity$EdgeToEdge.class"\n', builder)
        self.assertIn('    protected static class EdgeToEdge implements View.OnApplyWindowInsetsListener\n', activity)
        create = re.search(r'(?s)protected void onCreate\(Bundle p_saved_state\)\n\t{\n(.*?)\n\t}\n', activity).group(1)
        self.assertRegex(create, r'if \(Build\.VERSION\.SDK_INT >= 30 && asksForEdgeToEdge\(\)\)\s+drawEdgeToEdge\(\);\s+'
                                 r'else if \(Build\.VERSION\.SDK_INT >= 35 && getApplicationInfo\(\)\.targetSdkVersion '
                                 r'>= 35\)\s+keepOutOfSystemBars\(\);')
        self.assertLess(create.index('setContentView('), create.index('drawEdgeToEdge();'))
        self.assertEqual(activity.count('drawEdgeToEdge();'), 1)
        # it asks the manifest, and an app without the meta-data does not ask
        asks = re.search(r'(?s)protected boolean asksForEdgeToEdge\(\)\n    {\n(.*?)\n    }\n', activity).group(1)
        self.assertEqual(asks.split(), (
            'try { Bundle t_meta_data = getPackageManager().getApplicationInfo(getPackageName(), '
            'PackageManager.GET_META_DATA).metaData; '
            'return t_meta_data != null && t_meta_data.getBoolean(EDGE_TO_EDGE, false); } '
            'catch (PackageManager.NameNotFoundException e) { return false; }').split())
        # drawn so: the window under the bars, which are see-through, and
        # into the cutout; the view padded by the insets' listener
        draw = re.search(r'(?s)protected void drawEdgeToEdge\(\)\n    {\n(.*?)\n    }\n', activity).group(1)
        self.assertEqual(draw.split(), (
            'Window t_window = getWindow(); '
            't_window.setDecorFitsSystemWindows(false); '
            't_window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS | '
            'WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION); '
            't_window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS); '
            't_window.setStatusBarColor(Color.TRANSPARENT); '
            't_window.setNavigationBarColor(Color.TRANSPARENT); '
            't_window.setStatusBarContrastEnforced(false); '
            'WindowManager.LayoutParams t_attributes = t_window.getAttributes(); '
            't_attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS; '
            't_window.setAttributes(t_attributes); '
            's_edge_to_edge = new EdgeToEdge(this); '
            's_main_layout.setOnApplyWindowInsetsListener(s_edge_to_edge); '
            'showBarsForAppearance(getResources().getConfiguration());').split())
        self.assertEqual(activity.count('s_edge_to_edge = '), 1)
        # padded by the keyboard only, while the window resizes for it; the
        # bars, the cutout and the keyboard are what the stack is told of
        pad = re.search(r'(?s)class EdgeToEdge .*?public WindowInsets onApplyWindowInsets\(View p_view, WindowInsets '
                        r'p_insets\)\n        {\n(.*?)\n        }\n', activity).group(1)
        self.assertEqual(pad.split(), (
            'Insets t_keyboard = p_insets.getInsets(WindowInsets.Type.ime()); '
            'm_covered = Insets.max(p_insets.getInsets(WindowInsets.Type.systemBars() | '
            'WindowInsets.Type.displayCutout()), t_keyboard); '
            'int t_bottom = 0; '
            'if ((m_activity.getWindow().getAttributes().softInputMode & WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST) == '
            'WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE) t_bottom = t_keyboard.bottom; '
            'p_view.setPadding(0, 0, 0, t_bottom); '
            'return WindowInsets.CONSUMED;').split())
        # the part of the engine's view they leave, in the screen's pixels;
        # nothing until the window has had insets
        area = re.search(r'(?s)public boolean uncoveredArea\(View p_view, Rect r_area\)\n        {\n(.*?)\n        }\n',
                         activity).group(1)
        self.assertEqual(area.split(), (
            'if (m_covered == null || s_main_layout == null) return false; '
            'int[] t_origin = new int[2]; '
            's_main_layout.getLocationOnScreen(t_origin); '
            'Rect t_uncovered = new Rect(t_origin[0] + m_covered.left, t_origin[1] + m_covered.top, '
            't_origin[0] + s_main_layout.getWidth() - m_covered.right, '
            't_origin[1] + s_main_layout.getHeight() - m_covered.bottom); '
            'p_view.getLocationOnScreen(t_origin); '
            'Rect t_view = new Rect(t_origin[0], t_origin[1], t_origin[0] + p_view.getWidth(), '
            't_origin[1] + p_view.getHeight()); '
            'if (!t_uncovered.intersect(t_view)) t_uncovered.set(t_view.left, t_view.top, t_view.left, t_view.top); '
            'r_area.set(t_uncovered); '
            'return true;').split())
        self.assertRegex(activity, r'public static boolean edgeToEdgeUncoveredArea\(View p_view, Rect r_area\)\s*{\s*'
                                   r'return s_edge_to_edge != null && s_edge_to_edge\.uncoveredArea\(p_view, r_area\);\s*}')
        # which the effective working screenRect gives a script; for any
        # other stack, the visible display frame, as before
        engine = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'Engine.java')
        work = re.search(r'(?s)private Rect getEffectiveWorkarea\(\)\n\t{\n(.*?)\n\t}\n', engine).group(1)
        code = ' '.join(x.strip() for x in work.splitlines() if x.strip() and not x.strip().startswith('//'))
        self.assertEqual(code.split(), (
            'Rect t_workrect = new Rect(); '
            'if (LiveCodeActivity.edgeToEdgeUncoveredArea(this, t_workrect)) return t_workrect; '
            'getWindowVisibleDisplayFrame(t_workrect); '
            'return t_workrect;').split())
        native = read('engine', 'src', 'mblandroiddc.cpp')
        self.assertIn('"getEffectiveWorkareaAsString"', native)
        # the bars' icons dark over the light appearance, light over the
        # dark, from the start and as night mode changes
        bars = re.search(r'(?s)protected void showBarsForAppearance\(Configuration p_config\)\n    {\n(.*?)\n    }\n',
                         activity).group(1)
        self.assertEqual(bars.split(), (
            'int t_light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS | '
            'WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS; '
            'boolean t_dark = (p_config.uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES; '
            'WindowInsetsController t_controller = getWindow().getInsetsController(); '
            'if (t_controller != null) t_controller.setSystemBarsAppearance(t_dark ? 0 : t_light, t_light);').split())
        changed = re.search(r'(?s)public void onConfigurationChanged\(Configuration p_new_config\)\n\t{\n(.*?)\n\t}\n',
                            activity).group(1)
        code = [x.strip() for x in changed.splitlines() if x.strip() and not x.strip().startswith('//')]
        self.assertEqual(code, ['super.onConfigurationChanged(p_new_config);', 'if (!m_engine_started)', 'return;',
                                'if (s_edge_to_edge != null)', 'showBarsForAppearance(p_new_config);',
                                's_main_view.onConfigurationChanged(p_new_config);'])
        # named, with its reason, against every Classes compare knows
        create_key = 'code com/runrev/android/LiveCodeActivity.onCreate:(Landroid/os/Bundle;)V'
        changed_key = 'code com/runrev/android/LiveCodeActivity.onConfigurationChanged:(Landroid/content/res/Configuration;)V'
        for sha, entries in aj.EXPECTED.items():
            for key in aj.EDGE_TO_EDGE:
                self.assertEqual(entries[key], aj.EDGE_TO_EDGE[key], (sha, key))
            self.assertTrue(entries[create_key].endswith(aj.EDGE_TO_EDGE_ON_CREATE), sha)
            self.assertTrue(entries[changed_key].endswith(aj.EDGE_TO_EDGE_ON_CONFIGURATION), sha)

    def test_opengl_view_serves_both_engines(self):
        # the runtime's engine is LiveCode Community 9.6.3's, which draws
        # with OpenGL ES 1 and calls start() (android-java.yml's jni checks
        # it on the engine): while the runtimes asset carries that engine,
        # start() makes the context it made, with no attributes
        java = read('engine', 'src', 'java', 'com', 'runrev', 'android', 'OpenGLView.java')
        self.assertRegex(java, r'public void start\(\)\s*{\s*startGLES\(1\);\s*}')
        self.assertIn('public void startGLES(int p_gles_version)', java)
        self.assertRegex(java, r'if \(p_gles_version > 1\)\s*{\s*int\[\] t_attr = new int\[\] {\s*'
                               r'EGL_CONTEXT_CLIENT_VERSION, p_gles_version,\s*EGL10.EGL_NONE,\s*};\s*'
                               r'm_egl_context = m_egl \. eglCreateContext\(m_egl_display, m_egl_config, '
                               r'EGL10 \. EGL_NO_CONTEXT, t_attr\);\s*}\s*else\s*m_egl_context = m_egl \. '
                               r'eglCreateContext\(m_egl_display, m_egl_config, EGL10 \. EGL_NO_CONTEXT, null\);')
        self.assertNotIn('GLES_VERSION', java)
        # an engine built from this tree draws with OpenGL ES 3, which it
        # links, and asks startGLES for that (android-engine.yml's jni
        # checks it on the engine built)
        self.assertEqual(aj.source_gles_version(), 3)
        kernel = read('engine', 'kernel.gyp')
        self.assertIn("'-lGLESv3',", kernel)
        self.assertNotIn("'-lGLESv1_CM',", kernel)
        self.assertNotIn('"start", "()V"', read('engine', 'src', 'mblandroiddc.cpp'))
        import json
        assets = json.loads(read('tools', 'oxt', 'external-assets.json'))
        runtimes = [a for a in assets['assets'] if a['id'].startswith('oxt-runtimes-')]
        self.assertEqual(len(runtimes), 1)
        self.assertIn('Android runtime', runtimes[0]['description'])
        self.assertIn('oxt-runtimes-1.15', runtimes[0]['source'])

    def test_expected_and_known_entries_are_well_formed(self):
        for sha, entries in aj.EXPECTED.items():
            self.assertRegex(sha, r'^[0-9a-f]{64}$')
            for key, reason in entries.items():
                self.assertRegex(key, r'^(class|member|code) [\w/$]+(\.[\w$<>]+:\S+)?$', key)
                self.assertTrue(reason.strip())
        for key, reason in aj.UNEXPORTED.items():
            self.assertRegex(key, r'^[\w/$]+\.\w+:\(.*\)\S+$')
            self.assertTrue(reason.strip())
        for (path, name, sig), reason in aj.KNOWN_CALLS.items():
            self.assertTrue(os.path.isfile(os.path.join(REPO, path)), path)
            self.assertIn('"%s", "%s"' % (name, sig), read(*path.split('/')))
            self.assertTrue(reason.strip())

    def test_native_sources_exist(self):
        import glob
        for pattern in aj.NATIVE_SOURCES:
            self.assertTrue(glob.glob(os.path.join(REPO, pattern)), pattern)

    def test_java_workflow_runs_every_check(self):
        workflow = read('.github', 'workflows', 'android-java.yml')
        for command in ('build', 'compare', 'jni', 'rules'):
            self.assertIn('android_java.py %s ' % command, workflow)
        paths = workflow_paths(workflow, 'java-paths')
        for rel in ('tools/ci/android_java.py', 'engine/src/java/x/Y.java', 'engine/engine-sources.gypi',
                    '.github/workflows/android-java.yml', 'tools/oxt/external-assets.json',
                    'ide-support/revsaveasandroidstandalone.livecodescript'):
            self.assertTrue(starts(paths, rel), rel)

    def test_a_change_to_a_call_starts_the_check(self):
        # every source the jni check finds a call into Java in, and every
        # LCB binding to the jar, is one whose change starts it (a new file
        # with calls in it fails here until the paths name it)
        import glob
        paths = workflow_paths(read('.github', 'workflows', 'android-java.yml'), 'java-paths')
        sources = []
        for pattern in aj.NATIVE_SOURCES:
            sources += glob.glob(os.path.join(REPO, pattern))
        files = sorted({c.file for c in aj.source_calls(sources)})
        files += sorted({b[0].rsplit(':', 1)[0] for b in aj.lcb_bindings(os.path.join(REPO, aj.LCB_SOURCES))})
        self.assertGreater(len(files), 30)
        for rel in files:
            self.assertTrue(starts(paths, rel), rel)
        self.assertTrue(starts(paths, 'engine/src/mblandroidnew.cpp'))
        self.assertFalse(starts(paths, 'engine/src/mcstring.cpp'))

    def test_builder_workflow_runs_the_java_layer(self):
        workflow = read('.github', 'workflows', 'android.yml')
        self.assertIn('android_java.py build', workflow)
        self.assertIn('overlay --root "$JAVA_IDE" --classes', workflow)
        self.assertIn('--probe java', workflow)
        paths = workflow_paths(workflow, 'android-paths')
        for rel in ('tools/ci/android_java.py', 'engine/src/java/com/runrev/android/Utils.java',
                    'engine/engine-sources.gypi'):
            self.assertTrue(starts(paths, rel), rel)


if __name__ == '__main__':
    unittest.main()
