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

"""Print, or with --set change, the macOS SDK version a Mach-O file records.

    macho_sdk.py FILE [--set VERSION]

AppKit gives an application the behaviour of the SDK its executable records
(LC_BUILD_VERSION, or LC_VERSION_MIN_MACOSX for binaries linked for macOS
10.13 and older): from the 10.14 SDK on, for example, every window is
layer-backed. LiveCode's Mac build records SDK 10.9 (its config/mac.gypi
links with -platform_version macos 10.9 10.9), OXT-Beyond's 11.0.
field-speed.yml uses --set to time a published release as if it recorded
another SDK. Every slice of a universal file is changed, and the file has
to be signed again afterwards (sign_mac_app.py).
"""

import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_macho_floor import (FAT_MAGIC, FAT_MAGIC_64, LC_BUILD_VERSION, LC_VERSION_MIN_MACOSX,  # noqa: E402
                               MH_CIGAM_64, PLATFORM_MACOS, arch_name, parse_version, version_string)


def sdk_fields(data):
    """(architecture, load command, minos, sdk, offset of the sdk field) of
    every macOS version load command of every slice of data."""
    magic, nfat = struct.unpack_from('>II', data, 0)
    if magic in (FAT_MAGIC, FAT_MAGIC_64):
        entry, fmt = (32, '>iiQQ') if magic == FAT_MAGIC_64 else (20, '>iiII')
        offsets = [struct.unpack_from(fmt, data, 8 + i * entry)[2] for i in range(nfat)]
    else:
        offsets = [0]
    fields = []
    for offset in offsets:
        if struct.unpack_from('>I', data, offset)[0] != MH_CIGAM_64:
            raise ValueError('the slice at offset %d is not a 64-bit little-endian Mach-O image' % offset)
        cputype, cpusubtype, _, ncmds = struct.unpack_from('<iiII', data, offset + 4)
        arch = arch_name(cputype, cpusubtype)
        pos = offset + 32
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from('<II', data, pos)
            if cmd == LC_BUILD_VERSION and struct.unpack_from('<I', data, pos + 8)[0] == PLATFORM_MACOS:
                minos, sdk = struct.unpack_from('<II', data, pos + 12)
                fields.append((arch, 'LC_BUILD_VERSION', minos, sdk, pos + 16))
            elif cmd == LC_VERSION_MIN_MACOSX:
                minos, sdk = struct.unpack_from('<II', data, pos + 8)
                fields.append((arch, 'LC_VERSION_MIN_MACOSX', minos, sdk, pos + 12))
            pos += cmdsize
    return fields


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('file', help='a Mach-O file, thin or universal')
    parser.add_argument('--set', metavar='VERSION', help='the SDK version to record, such as 10.9')
    args = parser.parse_args(argv)
    new_sdk = parse_version(args.set) if args.set else None
    with open(args.file, 'rb') as f:
        data = bytearray(f.read())
    fields = sdk_fields(data)
    if not fields:
        print('%s records no macOS version' % args.file)
        return 1
    for arch, cmd, minos, sdk, at in fields:
        line = '%s: %s, minimum macOS %s, SDK %s' % (arch, cmd, version_string(minos), version_string(sdk))
        if new_sdk is not None:
            struct.pack_into('<I', data, at, new_sdk)
            line += ', now SDK %s' % version_string(new_sdk)
        print(line)
    if new_sdk is not None:
        with open(args.file, 'r+b') as f:
            f.write(data)
    return 0


if __name__ == '__main__':
    sys.exit(main())
