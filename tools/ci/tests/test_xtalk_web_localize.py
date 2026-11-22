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

"""tools/web-ide/xtalk_web_libraries.py localize: an xTalk Suite library's
object is linked into the web engines with its symbols made local, but its
exports table, what Emscripten finds by name, and the symbols of its COMDAT
groups (C++'s inline and template code).

The groups are the reason for this file. barcodext, the first C++ library,
was localized whole: the linker still dropped the copies of a group it had
met elsewhere, and code that called a dropped copy by a now local name
called nothing (a trap; through a pointer, "indirect call to null", which
stopped the web IDE's xTalk Suite check in Firefox). The objects here are
built by hand, in the layout clang and wasm-ld write (the symbol table, then
the groups), and read back by a reader of their own, so the localizer's
reading is not what checks it.
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))

import xtalk_web_libraries as xwl  # noqa: E402

FUNCTION, DATA = 0, 1
WEAK, LOCAL, UNDEFINED = 0x1, 0x2, 0x10
SYMTAB, COMDAT_INFO = 8, 7
GROUP_DATA, GROUP_FUNCTION = 0, 1


# ---------------------------------------------------------------- writing

def uleb(value):
    out = bytearray()
    while True:
        byte = value & 0x7f
        value >>= 7
        out.append(byte | 0x80 if value else byte)
        if not value:
            return bytes(out)


def name(text):
    raw = text.encode('utf-8')
    return uleb(len(raw)) + raw


def subsection(kind, payload):
    return bytes([kind]) + uleb(len(payload)) + payload


def function(flags, index, text=None):
    """A function symbol: its index counts the imported functions first."""
    return bytes([FUNCTION]) + uleb(flags) + uleb(index) + (name(text) if text is not None else b'')


def data(flags, text, segment=0, offset=0, size=4):
    out = bytes([DATA]) + uleb(flags) + name(text)
    if not flags & UNDEFINED:
        out += uleb(segment) + uleb(offset) + uleb(size)
    return out


def symtab(*symbols):
    return subsection(SYMTAB, uleb(len(symbols)) + b''.join(symbols))


def groups(*entries):
    """COMDAT groups: (name, [(GROUP_FUNCTION or GROUP_DATA, index), ...])."""
    out = uleb(len(entries))
    for text, members in entries:
        out += name(text) + uleb(0) + uleb(len(members))
        out += b''.join(bytes([kind]) + uleb(index) for kind, index in members)
    return subsection(COMDAT_INFO, out)


def wasm_object(*subsections):
    """A WebAssembly object holding only its linking section, which is all
    the localizer reads (the sections it does not read are copied)."""
    linking = name('linking') + uleb(2) + b''.join(subsections)
    return xwl.WASM_MAGIC + b'\0' + uleb(len(linking)) + linking


# ---------------------------------------------------------------- reading

def _uleb(raw, pos):
    result = shift = 0
    while True:
        byte = raw[pos]
        pos += 1
        result |= (byte & 0x7f) << shift
        if not byte & 0x80:
            return result, pos
        shift += 7


def subsections(obj):
    """The linking section's subsections, as {kind: payload}."""
    assert obj.startswith(xwl.WASM_MAGIC)
    size, pos = _uleb(obj, 9)
    body = obj[pos:pos + size]
    length, p = _uleb(body, 0)
    assert body[p:p + length] == b'linking'
    _, p = _uleb(body, p + length)
    found = {}
    while p < len(body):
        kind = body[p]
        length, q = _uleb(body, p + 1)
        found[kind] = body[q:q + length]
        p = q + length
    return found


def flags_by_name(obj):
    """Each named symbol's flags, by name (undefined imports have none)."""
    payload = subsections(obj)[SYMTAB]
    count, p = _uleb(payload, 0)
    flags = {}
    for _ in range(count):
        kind = payload[p]
        value, p = _uleb(payload, p + 1)
        text = None
        if kind == FUNCTION:
            _, p = _uleb(payload, p)
            if not value & UNDEFINED:
                length, p = _uleb(payload, p)
                text = payload[p:p + length].decode('utf-8')
                p += length
        else:
            length, p = _uleb(payload, p)
            text = payload[p:p + length].decode('utf-8')
            p += length
            if not value & UNDEFINED:
                for _ in range(3):
                    _, p = _uleb(payload, p)
        if text is not None:
            flags[text] = value
    assert p == len(payload)
    return flags


# ---------------------------------------------------------------- the object

# Function 0 is imported (the engine's malloc, say); 1 to 6 are defined.
# Data segment 0 is the library's own table, 1 a vtable in a group, 2 a
# guard variable in another, with the function it guards.
STRING = '_ZNSt3__212basic_stringIcEC2B9nqe220108IDnEEPKc'
GROUPS = groups(
    (STRING, [(GROUP_FUNCTION, 3)]),
    ('_ZTV4Base', [(GROUP_DATA, 1)]),
    ('_ZZN4ZXing6ReaderEvE5cache', [(GROUP_DATA, 2), (GROUP_FUNCTION, 4)]),
)


def symbols(decode=0, weak_default=WEAK, string=WEAK, reader=WEAK, table=0, vtable=WEAK, guard=WEAK):
    """The symbol table, with the flags of the library's own symbols given
    (the defaults are the compiler's)."""
    return symtab(
        function(UNDEFINED, 0),
        function(decode, 1, 'zx_decode'),
        function(weak_default, 2, 'zx_weak_default'),
        function(string, 3, STRING),
        function(reader, 4, '_ZN4ZXing6ReaderEv'),
        function(0, 5, 'lib_web_exports'),
        function(0, 6, '__em_js__lib_js'),
        function(LOCAL, 6, 'already_local'),
        data(table, 'zx_table', segment=0),
        data(vtable, '_ZTV4Base', segment=1),
        data(guard, '_ZGVZN4ZXing6ReaderEvE5cache', segment=2),
        data(UNDEFINED, 'engine_data'),
    )


SYMBOLS = symbols()


def localize(obj):
    return xwl.localize(obj, ['lib_web_exports'], 'test object')


class ComdatTest(unittest.TestCase):

    def setUp(self):
        self.obj, self.kept, self.localized, self.shared = localize(wasm_object(SYMBOLS, GROUPS))
        self.flags = flags_by_name(self.obj)

    def test_a_group_function_stays_global_and_weak(self):
        self.assertEqual(self.flags[STRING], WEAK)
        self.assertEqual(self.flags['_ZN4ZXing6ReaderEv'], WEAK)

    def test_a_group_data_symbol_stays_global_and_weak(self):
        self.assertEqual(self.flags['_ZTV4Base'], WEAK)
        self.assertEqual(self.flags['_ZGVZN4ZXing6ReaderEvE5cache'], WEAK)

    def test_the_rest_is_made_local_as_before(self):
        self.assertEqual(self.flags['zx_decode'], LOCAL)
        self.assertEqual(self.flags['zx_table'], LOCAL)
        # a weak symbol outside a group is the library's own, and local
        self.assertEqual(self.flags['zx_weak_default'], LOCAL)

    def test_the_table_and_emscriptens_names_stay_global(self):
        self.assertEqual(self.flags['lib_web_exports'], 0)
        self.assertEqual(self.flags['__em_js__lib_js'], 0)
        self.assertEqual(self.kept, ['lib_web_exports', '__em_js__lib_js'])

    def test_undefined_and_local_symbols_are_untouched(self):
        self.assertEqual(self.flags['engine_data'], UNDEFINED)
        self.assertEqual(self.flags['already_local'], LOCAL)

    def test_the_counts(self):
        self.assertEqual((self.localized, self.shared), (3, 4))

    def test_only_the_flags_of_the_librarys_own_symbols_change(self):
        # the whole object, byte for byte: the groups and every other
        # symbol as they were
        self.assertEqual(self.obj, wasm_object(symbols(decode=LOCAL, weak_default=LOCAL, table=LOCAL), GROUPS))

    def test_groups_before_the_symbol_table_are_read_too(self):
        obj = localize(wasm_object(GROUPS, SYMBOLS))[0]
        self.assertEqual(flags_by_name(obj), self.flags)

    def test_a_function_and_a_segment_with_the_same_index_are_not_confused(self):
        # groups holding segment 1 and function 3, and function 0 and segment 3
        obj = localize(wasm_object(SYMBOLS, groups(('g', [(GROUP_DATA, 1), (GROUP_FUNCTION, 3)]),
                                                   ('h', [(GROUP_FUNCTION, 0), (GROUP_DATA, 3)]))))[0]
        flags = flags_by_name(obj)
        self.assertEqual(flags['_ZTV4Base'], WEAK)           # segment 1
        self.assertEqual(flags[STRING], WEAK)                # function 3
        self.assertEqual(flags['zx_decode'], LOCAL)          # function 1, not segment 1
        self.assertEqual(flags['zx_table'], LOCAL)           # segment 0, not function 0
        self.assertEqual(flags['_ZN4ZXing6ReaderEv'], LOCAL)  # function 4: no group holds it now
        self.assertEqual(flags['_ZGVZN4ZXing6ReaderEvE5cache'], LOCAL)

    def test_without_groups_every_symbol_but_the_kept_is_local(self):
        # what every C library is (they have no group): the same as before
        obj, kept, localized, shared = localize(wasm_object(SYMBOLS))
        self.assertEqual(obj, wasm_object(symbols(LOCAL, LOCAL, LOCAL, LOCAL, LOCAL, LOCAL, LOCAL)))
        self.assertEqual((kept, localized, shared), (['lib_web_exports', '__em_js__lib_js'], 7, 0))

    def test_a_group_table_with_bytes_left_over_is_refused(self):
        broken = subsection(COMDAT_INFO, uleb(0) + b'\x01')
        with self.assertRaises(xwl.WebLibraryError):
            localize(wasm_object(SYMBOLS, broken))


if __name__ == '__main__':
    unittest.main()
