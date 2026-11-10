#!/usr/bin/env python3
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

"""Check an Android runtime folder that tools/ci/build-android.sh wrote (the
Android plan's phase 2: the engine built here with a current NDK), as
Android and the IDE's builder will take it:

  python3 tools/ci/android_engine.py check RUNTIME [--abi ABI ...]
  python3 tools/ci/android_engine.py merge OUT FOLDER [FOLDER ...]

For every ABI folder of RUNTIME (arm64-v8a, armeabi-v7a, x86_64, x86), or
those --abi names (which must then be there):

  - the engine (Standalone) and every external (RevDb, DbSqlite, DbMysql,
    RevXml, RevZip, RevSecurity, RevPdfPrinter) is there, a shared library
    (ELF ET_DYN) for that ABI's machine and word size;
  - the 64-bit ones have every LOAD segment aligned to 16 KB at least:
    Android 15 and later run on devices with 16 KB pages, which load no
    library aligned to less, and Google Play asks it of every app that
    targets Android 15 (the 32-bit ABIs have no such devices);
  - none has text relocations (DT_TEXTREL, or DF_TEXTREL in DT_FLAGS),
    which Android 6.0 and later refuse to load;
  - none has anything writable but RELRO in the pages that RELRO
    (PT_GNU_RELRO) starts and ends in, at the largest page the ABI's
    devices have (16 KB for the 64-bit ABIs, 4 KB for the others):
    Android's loader makes those pages read-only whole once it has
    relocated the library, and the first write to what shares them
    crashes (the engine built with lld and the old linker script died
    so, loading, in a static constructor that writes .data);
  - none needs a library that Android does not have, or one that an app
    would have to carry: only the NDK's stable system libraries
    (SYSTEM_LIBRARIES; never libc++_shared.so, since each library links
    the C++ library into itself);
  - the minimum Android that the NDK wrote into each (its
    .note.android.ident note, which Android's loader reads) is
    MIN_API: a higher one would not load on the devices the engine is
    for;
  - the engine has the section that the IDE's builder writes the stack
    into (.project), as the builder's deploy (engine/src/deploy_linux.cpp,
    MCDeployToELF) requires it: the last section by address, in the last
    LOAD segment, which ends with it; and it exports JNI_OnLoad, which
    Android calls when the Java layer loads it;
  - beside the ABI folders: the Java layer (Classes, a jar) and the files
    the builder puts beside the engine (Manifest.xml and the others of
    TOP_FILES), none empty.

What crosses JNI between the engine and the Java layer is
tools/ci/android_java.py jni's to check, on the same folder.

merge puts the folders that build-android.sh wrote for each ABI (the
artifacts android-engine-<abi> of android-engine.yml) together as one
runtime folder, OUT, which must not be there yet or be empty: every
ABI's engine and externals from the one FOLDER that has that ABI, and
the files beside them from the first FOLDER. Every ABI must be in one
FOLDER and one only, and every FOLDER must have the same files beside
them: the same bytes, and for the Java layer, a jar the javac of each
build wrote apart, the same files in it whatever their dates. Nothing
else goes in (not debug/), and nothing is written when anything is
missing or differs, so that the runtime the emulators run and the one
the runtimes asset carries are made the same way, whichever folder came
down last.

Exit status 0 when every check passed, 1 otherwise. Only the Python 3
standard library is used (3.8 or later).
"""

import argparse
import os
import shutil
import struct
import sys
import zipfile

# Android's name for each architecture -> (ELF e_machine, 64-bit)
ABIS = {
    'arm64-v8a': (183, True),      # EM_AARCH64
    'armeabi-v7a': (40, False),    # EM_ARM
    'x86_64': (62, True),          # EM_X86_64
    'x86': (3, False),             # EM_386
}
ENGINE = 'Standalone'
EXTERNALS = ('RevDb', 'DbSqlite', 'DbMysql', 'RevXml', 'RevZip', 'RevSecurity', 'RevPdfPrinter')
TOP_FILES = ('Classes', 'Manifest.xml', 'livecode_inputcontrol.xml', 'nfc_tech_filter.xml',
             'file_provider_paths.xml', 'notify_icon.png')
# The lowest Android the engine is built for (build-android.sh's
# ANDROID_MIN_API)
MIN_API = 21
PAGE_4K = 4096
PAGE_16K = 16384
# The NDK's stable system libraries (the NDK's "Native APIs"), which every
# Android of MIN_API and later has, or has from the API level that an app
# checks for. libstdc++.so is Android's operator new and delete only.
SYSTEM_LIBRARIES = frozenset((
    'libc.so', 'libm.so', 'libdl.so', 'liblog.so', 'libz.so', 'libstdc++.so',
    'libandroid.so', 'libjnigraphics.so', 'libEGL.so', 'libGLESv1_CM.so', 'libGLESv2.so',
    'libGLESv3.so', 'libOpenSLES.so', 'libOpenMAXAL.so', 'libmediandk.so', 'libvulkan.so',
    'libnativewindow.so', 'libaaudio.so', 'libcamera2ndk.so', 'libsync.so', 'libbinder_ndk.so',
    'libneuralnetworks.so', 'libicu.so',
))

ET_DYN = 3
PT_LOAD = 1
PT_DYNAMIC = 2
PT_GNU_RELRO = 0x6474e552
SHT_NOTE = 7
SHT_NOBITS = 8
SHF_WRITE = 1
SHF_ALLOC = 2
SHF_TLS = 0x400
DT_NULL = 0
DT_NEEDED = 1
DT_STRTAB = 5
DT_STRSZ = 10
DT_TEXTREL = 22
DT_FLAGS = 30
DF_TEXTREL = 4
SHT_DYNSYM = 11
NT_ANDROID_IDENT = 1


class ElfError(Exception):
    pass


class Elf(object):
    """The parts of an ELF file that the checks read."""

    def __init__(self, data):
        if data[:4] != b'\x7fELF':
            raise ElfError('not an ELF file')
        if data[4] not in (1, 2) or data[5] not in (1, 2):
            raise ElfError('unknown ELF class %d or data encoding %d' % (data[4], data[5]))
        self.data = data
        self.is64 = data[4] == 2
        self.e = '<' if data[5] == 1 else '>'
        if self.is64:
            fields = self.unpack('HHIQQQIHHHHHH', 16)
        else:
            fields = self.unpack('HHIIIIIHHHHHH', 16)
        (self.type, self.machine, _, _, phoff, shoff, _, _,
         phentsize, phnum, shentsize, shnum, shstrndx) = fields
        self.segments = []
        for i in range(phnum):
            at = phoff + i * phentsize
            if self.is64:
                p_type, flags, off, vaddr, _, filesz, memsz, align = self.unpack('IIQQQQQQ', at)
            else:
                p_type, off, vaddr, _, filesz, memsz, flags, align = self.unpack('IIIIIIII', at)
            self.segments.append({'type': p_type, 'offset': off, 'vaddr': vaddr, 'filesz': filesz,
                                  'memsz': memsz, 'align': align, 'flags': flags})
        self.sections = []
        for i in range(shnum):
            at = shoff + i * shentsize
            if self.is64:
                name, sh_type, flags, addr, off, size, link, info, align, entsize = \
                    self.unpack('IIQQQQIIQQ', at)
            else:
                name, sh_type, flags, addr, off, size, link, info, align, entsize = \
                    self.unpack('IIIIIIIIII', at)
            self.sections.append({'name_at': name, 'type': sh_type, 'flags': flags, 'addr': addr,
                                  'offset': off, 'size': size, 'link': link, 'entsize': entsize})
        if self.sections and shstrndx < len(self.sections):
            names = self.sections[shstrndx]
            for s in self.sections:
                s['name'] = self.string(names['offset'], names['size'], s['name_at'])
        else:
            for s in self.sections:
                s['name'] = ''

    def unpack(self, fmt, at):
        fmt = self.e + fmt
        size = struct.calcsize(fmt)
        if at < 0 or at + size > len(self.data):
            raise ElfError('truncated at offset %d' % at)
        return struct.unpack_from(fmt, self.data, at)

    def string(self, table_offset, table_size, at):
        if at >= table_size:
            raise ElfError('string offset %d outside its table' % at)
        start = table_offset + at
        end = self.data.find(b'\0', start, table_offset + table_size)
        if end < 0:
            raise ElfError('unterminated string at offset %d' % start)
        return self.data[start:end].decode('ascii', 'replace')

    def file_offset(self, vaddr):
        for s in self.segments:
            if s['type'] == PT_LOAD and s['vaddr'] <= vaddr < s['vaddr'] + s['filesz']:
                return s['offset'] + vaddr - s['vaddr']
        raise ElfError('address 0x%x is not in a loaded segment' % vaddr)

    def dynamic(self):
        """[(tag, value)] of the dynamic segment, to DT_NULL."""
        out = []
        for s in self.segments:
            if s['type'] != PT_DYNAMIC:
                continue
            fmt = 'qQ' if self.is64 else 'iI'
            step = struct.calcsize(self.e + fmt)
            for at in range(s['offset'], s['offset'] + s['filesz'] - step + 1, step):
                tag, value = self.unpack(fmt, at)
                if tag == DT_NULL:
                    break
                out.append((tag, value))
        return out

    def needed(self):
        tags = self.dynamic()
        values = dict((t, v) for t, v in reversed(tags))
        if DT_NEEDED not in values:
            return []
        if DT_STRTAB not in values or DT_STRSZ not in values:
            raise ElfError('DT_NEEDED without a string table')
        strtab = self.file_offset(values[DT_STRTAB])
        return [self.string(strtab, values[DT_STRSZ], v) for t, v in tags if t == DT_NEEDED]

    def text_relocations(self):
        for tag, value in self.dynamic():
            if tag == DT_TEXTREL or (tag == DT_FLAGS and value & DF_TEXTREL):
                return True
        return False

    def exports(self):
        """The names .dynsym defines."""
        out = set()
        for s in self.sections:
            if s['type'] != SHT_DYNSYM or not s['entsize']:
                continue
            strtab = self.sections[s['link']]
            for k in range(1, s['size'] // s['entsize']):
                at = s['offset'] + k * s['entsize']
                if self.is64:
                    name, _, _, shndx = self.unpack('IBBH', at)
                else:
                    name, = self.unpack('I', at)
                    shndx, = self.unpack('H', at + 14)
                if shndx != 0:
                    out.add(self.string(strtab['offset'], strtab['size'], name))
        return out

    def android_api(self):
        """The API level of the .note.android.ident note (the NDK's crtbegin
        writes it), or None."""
        for s in self.sections:
            if s['type'] != SHT_NOTE or s['name'] != '.note.android.ident':
                continue
            at = s['offset']
            end = at + s['size']
            while at + 12 <= end:
                namesz, descsz, n_type = self.unpack('III', at)
                name = self.data[at + 12:at + 12 + namesz].rstrip(b'\0')
                desc_at = at + 12 + ((namesz + 3) & ~3)
                if name == b'Android' and n_type == NT_ANDROID_IDENT and descsz >= 4:
                    return self.unpack('I', desc_at)[0]
                at = desc_at + ((descsz + 3) & ~3)
        return None


def check_library(path, abi, engine=False):
    """The problems of one library of an ABI folder, and what was seen."""
    name = '%s/%s' % (abi, os.path.basename(path))
    machine, is64 = ABIS[abi]
    with open(path, 'rb') as f:
        data = f.read()
    try:
        elf = Elf(data)
        problems = []
        if elf.type != ET_DYN:
            problems.append('%s is not a shared library (ELF type %d)' % (name, elf.type))
        if elf.machine != machine or elf.is64 != is64:
            problems.append('%s is for machine %d (%d-bit), not %s (machine %d, %d-bit)' % (
                name, elf.machine, 64 if elf.is64 else 32, abi, machine, 64 if is64 else 32))
        loads = [s for s in elf.segments if s['type'] == PT_LOAD]
        if not loads:
            problems.append('%s has no LOAD segment' % name)
        if is64:
            small = sorted(set(s['align'] for s in loads if s['align'] < PAGE_16K))
            if small:
                problems.append('%s has LOAD segments aligned to %s, under 16 KB: Android with 16 KB pages '
                                'does not load it' % (name, ', '.join(str(a) for a in small)))
        if elf.text_relocations():
            problems.append('%s has text relocations, which Android 6.0 and later refuse' % name)
        problems += check_relro(elf, name, PAGE_16K if is64 else PAGE_4K)
        needed = elf.needed()
        foreign = [n for n in needed if n not in SYSTEM_LIBRARIES]
        if foreign:
            problems.append('%s needs %s, not a library of Android' % (name, ', '.join(foreign)))
        api = elf.android_api()
        if api is None:
            problems.append('%s has no .note.android.ident (the lowest Android it is for)' % name)
        elif api != MIN_API:
            problems.append('%s is for Android API %d and later, not %d' % (name, api, MIN_API))
        if engine:
            problems += check_project_section(elf, name)
            if 'JNI_OnLoad' not in elf.exports():
                problems.append('%s does not export JNI_OnLoad' % name)
    except ElfError as e:
        return ['%s: %s' % (name, e)], None
    seen = '%s: %d bytes, %d-bit, LOAD aligned to %s, API %s, needs %s' % (
        name, len(data), 64 if elf.is64 else 32,
        '/'.join(str(a) for a in sorted(set(s['align'] for s in loads))) or 'nothing',
        api, ', '.join(needed) or 'nothing')
    relro = ['0x%x to 0x%x' % (s['vaddr'], s['vaddr'] + s['memsz'])
             for s in elf.segments if s['type'] == PT_GNU_RELRO]
    if relro:
        seen += '; RELRO %s' % ', '.join(relro)
    return problems, seen


def check_relro(elf, name, page):
    """What Android's loader does with RELRO (bionic's
    phdr_table_protect_gnu_relro): once it has relocated the library it
    makes read-only every page from the one PT_GNU_RELRO starts in to the
    one it ends in, whole. A writable section that is not RELRO but has
    bytes in those pages goes read-only with it, and the first write to
    it crashes (SIGSEGV, SEGV_ACCERR). `page` is the largest page of the
    ABI's devices; a library that passes at it passes at any smaller one.
    TLS's .tbss is left out: it takes no room in the image (its address
    only says where its template would go)."""
    problems = []
    for r in elf.segments:
        if r['type'] != PT_GNU_RELRO or not r['memsz']:
            continue
        start, end = r['vaddr'], r['vaddr'] + r['memsz']
        first = start - start % page
        last = -(-end // page) * page
        caught = [s['name'] or '(unnamed)' for s in elf.sections
                  if s['flags'] & SHF_ALLOC and s['flags'] & SHF_WRITE and s['size']
                  and not (s['flags'] & SHF_TLS and s['type'] == SHT_NOBITS)
                  and s['addr'] < last and first < s['addr'] + s['size']
                  and not (start <= s['addr'] and s['addr'] + s['size'] <= end)]
        if caught:
            problems.append('%s: RELRO (0x%x to 0x%x) shares its %d KB pages with %s, which is writable and '
                            'not RELRO: Android makes it read-only with RELRO, and the first write to it '
                            'crashes' % (name, start, end, page // 1024, ', '.join(caught)))
    return problems


def check_project_section(elf, name):
    """What MCDeployToELF (engine/src/deploy_linux.cpp) asks of the engine's
    .project section, which the IDE's builder writes the stack into."""
    projects = [s for s in elf.sections if s['name'] == '.project']
    if not projects:
        return ['%s has no .project section, which the builder writes the stack into' % name]
    project = projects[0]
    problems = []
    later = [s['name'] for s in elf.sections if s['flags'] & SHF_ALLOC and s['addr'] > project['addr']]
    if later:
        problems.append('%s has sections after .project in memory (%s): the builder needs it last'
                        % (name, ', '.join(later)))
    loads = [s for s in elf.segments if s['type'] == PT_LOAD]
    holder = [s for s in loads if s['vaddr'] <= project['addr'] and
              project['addr'] + project['size'] <= s['vaddr'] + s['memsz']]
    if not holder:
        problems.append('%s: no LOAD segment holds .project' % name)
    elif holder[0] is not max(loads, key=lambda s: s['vaddr']):
        problems.append('%s: the LOAD segment that holds .project is not the last' % name)
    elif project['type'] != SHT_NOBITS and \
            project['offset'] + project['size'] != holder[0]['offset'] + holder[0]['filesz']:
        problems.append('%s: .project does not end its LOAD segment\'s data' % name)
    return problems


def check(runtime, abis=()):
    """(problems, lines seen) of a runtime folder."""
    problems = []
    seen = []
    if not os.path.isdir(runtime):
        return ['%s is not a folder' % runtime], seen
    present = [a for a in ABIS if os.path.isdir(os.path.join(runtime, a))]
    for a in abis:
        if a not in ABIS:
            problems.append('no Android ABI %s (one of %s)' % (a, ', '.join(ABIS)))
        elif a not in present:
            problems.append('%s has no %s folder' % (runtime, a))
    wanted = [a for a in (abis or present) if a in present]
    if not wanted and not problems:
        problems.append('%s has no ABI folder (%s)' % (runtime, ', '.join(ABIS)))
    for abi in wanted:
        for name in (ENGINE,) + EXTERNALS:
            path = os.path.join(runtime, abi, name)
            if not os.path.isfile(path):
                problems.append('%s has no %s/%s' % (runtime, abi, name))
                continue
            p, s = check_library(path, abi, engine=(name == ENGINE))
            problems += p
            if s:
                seen.append(s)
    for name in TOP_FILES:
        path = os.path.join(runtime, name)
        if not os.path.isfile(path) or os.path.getsize(path) == 0:
            problems.append('%s has no %s (or it is empty)' % (runtime, name))
    with_classes = os.path.join(runtime, 'Classes')
    if os.path.isfile(with_classes):
        with open(with_classes, 'rb') as f:
            if f.read(4) != b'PK\x03\x04':
                problems.append('%s/Classes is not a jar' % runtime)
    return problems, seen


def jar_files(path):
    """{name: bytes} of the files in a jar: what two jars must have the
    same to be the same Java layer, whatever the dates the jar tool gave
    them."""
    with zipfile.ZipFile(path) as z:
        return {i.filename: z.read(i) for i in z.infolist() if not i.filename.endswith('/')}


def same_file(a, b, name):
    """None when the files a and b (both called name) are the same, else
    how they differ."""
    if name == 'Classes':
        try:
            fa, fb = jar_files(a), jar_files(b)
        except (zipfile.BadZipFile, OSError) as e:
            return 'not two jars (%s)' % e
        if fa == fb:
            return None
        diff = sorted(set(fa) ^ set(fb)) + sorted(n for n in set(fa) & set(fb) if fa[n] != fb[n])
        return 'the files %s in them' % ', '.join(diff[:5] + (['...'] if len(diff) > 5 else []))
    with open(a, 'rb') as fa, open(b, 'rb') as fb:
        return None if fa.read() == fb.read() else 'other bytes'


def merge(out, folders):
    """(problems, lines written): see merge in the docstring above."""
    problems = []
    if os.path.isdir(out) and os.listdir(out) or os.path.exists(out) and not os.path.isdir(out):
        problems.append('%s is there already' % out)
    if not folders:
        problems.append('no runtime folder to merge')
    owner = {}
    for folder in folders:
        if not os.path.isdir(folder):
            problems.append('%s is not a folder' % folder)
            continue
        for abi in ABIS:
            if os.path.isdir(os.path.join(folder, abi)):
                if abi in owner:
                    problems.append('%s and %s both have %s' % (owner[abi], folder, abi))
                else:
                    owner[abi] = folder
    copies = []
    for abi in ABIS:
        if abi not in owner:
            problems.append('no folder has %s' % abi)
            continue
        for name in (ENGINE,) + EXTERNALS:
            src = os.path.join(owner[abi], abi, name)
            if os.path.isfile(src):
                copies.append((src, os.path.join(abi, name)))
            else:
                problems.append('%s has no %s/%s' % (owner[abi], abi, name))
    present = [f for f in folders if os.path.isdir(f)]
    for name in TOP_FILES:
        found = [f for f in present if os.path.isfile(os.path.join(f, name))]
        for f in present:
            if f not in found:
                problems.append('%s has no %s' % (f, name))
        if not found or found[0] != (present or [None])[0]:
            continue
        for f in found[1:]:
            why = same_file(os.path.join(found[0], name), os.path.join(f, name), name)
            if why:
                problems.append('%s/%s differs from %s/%s: %s' % (f, name, found[0], name, why))
        copies.append((os.path.join(found[0], name), name))
    if problems:
        return problems, []
    lines = []
    for src, rel in copies:
        dst = os.path.join(out, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        lines.append('%s <- %s' % (rel.replace(os.sep, '/'), src))
    return problems, lines


def annotate(kind, msg):
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        print('::%s::%s' % (kind, msg.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='command', required=True)
    c = sub.add_parser('check')
    c.add_argument('runtime')
    c.add_argument('--abi', action='append', default=[])
    m = sub.add_parser('merge')
    m.add_argument('out')
    m.add_argument('folders', nargs='+')
    args = ap.parse_args(argv)
    if args.command == 'merge':
        problems, lines = merge(args.out, args.folders)
        for line in lines:
            print(line)
        print()
        for p in problems:
            print('PROBLEM: %s' % p)
            annotate('error', 'Android engine merge: %s' % p)
        if problems:
            return 1
        print('One Android runtime in %s, from %s.' % (args.out, ', '.join(args.folders)))
        return 0
    problems, seen = check(args.runtime, args.abi)
    for line in seen:
        print(line)
    print()
    if problems:
        for p in problems:
            print('PROBLEM: %s' % p)
            annotate('error', 'Android engine: %s' % p)
        return 1
    print('The Android runtime in %s passed every check.' % args.runtime)
    return 0


if __name__ == '__main__':
    sys.exit(main())
