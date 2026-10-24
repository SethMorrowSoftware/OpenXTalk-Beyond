#!/usr/bin/env python3
"""Write the synthetic resource forks in forks/.

The HyperCard import test (tests/lcs/core/interface/hypercard-import.
livecodescript) needs stacks that carry a resource fork, and no stack whose
fork we may redistribute has one, so the forks are made here from nothing:
every byte below is written by this script. Run it from anywhere after
changing it, and commit what it writes:

    python3 tests/lcs-input-files/hypercard/make-forks.py

forks/Synthetic.rsrc        a raw resource fork (Inside Macintosh: More
                            Macintosh Toolbox, 1-121): ICON 128, CURS 129,
                            snd 130, PICT 131, XCMD 132, XFCN 133
forks/Synthetic.appledouble the same fork in an AppleDouble file (RFC 1740),
                            as macOS writes "._Name"
forks/Empty.appledouble     an AppleDouble file whose fork holds nothing, as
                            macOS writes for a file with Finder info only
forks/Clash.rsrc            ids that collide: ICON 129 and CURS 129, ICON 2842
                            (card 1's id in TestCardsBackgrounds.stack), and
                            ICON 30000, above every object id of that stack
forks/Sounds.rsrc           the sound headers beyond the standard one: snd 200
                            "Stereo 16" (extended, 16-bit stereo), 201 "Mono 8
                            Extended", 202 "IMA" (compressed, IMA 4:1 stereo),
                            203 "MACE" (compressed, MACE 3:1: logged only);
                            and two standard ones whose first command is a
                            nullCmd, as SoundEdit wrote them: 204 "After
                            NullCmd" (format 2) and 205 "After NullCmd 1"
                            (format 1)
forks/Pictures.rsrc         PICT 300 "Colour" (version 2: colour shapes, an
                            8-bit PackBitsRect, a 32-bit DirectBitsRect, a
                            BitsRect and a line) and PICT 301 (version 1,
                            unnamed: an oval and a PackBitsRect), drawn as
                            the test expects pixel by pixel, and PLTE 300
                            "Test Palette" on PICT 300 with two buttons
forks/AddColor.rsrc         AddColor's colours for TestButtonProperties.stack:
                            HCbg 2670 (button 1 red with a bevel, button 2
                            green but hidden, a blue rectangle) and HCcd 2883
                            (a yellow rectangle, PICT 300 "Colour" drawn
                            transparent, a picture file, which is not drawn),
                            and HCcd 9999, for a card the stack does not have
forks/Stacks.hfs            a plain HFS volume (Inside Macintosh: Files, chapter
                            2), "Old Disk": Stacks:Synthetic Stack (STAK,
                            ../TestCardsBackgrounds.stack with Synthetic.rsrc
                            as its fork, both fragmented, the fork's fourth
                            extent in the extents tree), Stacks:More:Lost Type
                            (a stack whose type is "????") and Read Me (TEXT),
                            its catalog in two leaf nodes
forks/Stacks.dc42           the volume as a DiskCopy 4.2 image
forks/Stacks.apm            the volume behind an Apple partition map, as on CDs
forks/TestCardsBackgrounds.applesingle
                            ../TestCardsBackgrounds.stack and the fork in one
                            AppleSingle file, named "Synthetic Stack"
"""

import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "forks")


def icon():
    # 32x32, 1 bit: a frame with a diagonal, so that a wrong row stride or
    # bit order shows
    rows = []
    for y in range(32):
        row = 0
        for x in range(32):
            if x in (0, 31) or y in (0, 31) or x == y:
                row |= 1 << (31 - x)
        rows.append(struct.pack(">I", row))
    return b"".join(rows)


def cursor():
    # 16x16 image, 16x16 mask, hot spot (v, h) = (8, 4)
    image = b"".join(struct.pack(">H", 0x8000 >> (y % 16)) for y in range(16))
    mask = b"\xff\xff" * 16
    return image + mask + struct.pack(">hh", 8, 4)


def sound(samples):
    # format 2 'snd ': one bufferCmd (0x8051, the data offset flag set)
    # pointing at a standard sound header, 8-bit unsigned, 22254 Hz
    header_at = 2 + 2 + 2 + 8
    out = struct.pack(">HHH", 2, 0, 1)
    out += struct.pack(">HHI", 0x8051, 0, header_at)
    out += struct.pack(">IIIII", 0, len(samples), 0x56EE8BA3, 0, 0)
    out += bytes([0, 0x3C])
    return out + samples


def sound_after_nullcmd(samples, fmt):
    # a nullCmd (its param1 'ST', as SoundEdit's) before the bufferCmd: the
    # header is the bufferCmd's param2. Format 1 lists one synthesizer
    # first (sampledSynth, 5, initMono, 0x80).
    if fmt == 1:
        out = struct.pack(">HHHI", 1, 1, 5, 0x80)
    else:
        out = struct.pack(">HH", 2, 0)
    header_at = len(out) + 2 + 2 * 8
    out += struct.pack(">H", 2)
    out += struct.pack(">HHI", 0x0000, 0x5354, 0)
    out += struct.pack(">HHI", 0x8051, 0, header_at)
    out += struct.pack(">IIIII", 0, len(samples), 0x56EE8BA3, 0, 0)
    out += bytes([0, 0x3C])
    return out + samples


def extended_sound(channels, bits, frames, encode=0xFF, fmt=b"\0\0\0\0",
                   compression=0, samples=b""):
    # format 2, one bufferCmd, then a 64-byte extended (0xFF) or compressed
    # (0xFE) sound header and the samples
    header_at = 2 + 2 + 2 + 8
    out = struct.pack(">HHH", 2, 0, 1)
    out += struct.pack(">HHI", 0x8051, 0, header_at)
    head = struct.pack(">IIIII", 0, channels, 0x56EE8BA3, 0, 0)
    head += bytes([encode, 0x3C]) + struct.pack(">I", frames)
    head += b"\0" * 10  # the AIFF sample rate, unused
    if encode == 0xFF:
        head += struct.pack(">IIIHHIII", 0, 0, 0, bits, 0, 0, 0, 0)
    else:
        head += struct.pack(">I", 0) + fmt + struct.pack(">IIIhHHH", 0, 0, 0,
                                                          compression, 0, 0, bits)
    assert len(head) == 64, len(head)
    return out + head + samples


def pict():
    # a version 1 PICT that draws nothing: size, frame, version, end
    return struct.pack(">Hhhhh", 10, 0, 0, 32, 32) + b"\x11\x01\xff"


def packbits_row(row):
    # literal runs only: valid PackBits, if not the smallest
    out = b""
    for i in range(0, len(row), 128):
        chunk = row[i:i + 128]
        out += bytes([len(chunk) - 1]) + chunk
    return out


def packed_rows(rows, rowbytes):
    out = b""
    for row in rows:
        packed = packbits_row(row)
        out += (struct.pack(">H", len(packed)) if rowbytes > 250 else bytes([len(packed)])) + packed
    return out


def rect(top, left, bottom, right):
    return struct.pack(">hhhh", top, left, bottom, right)


def pict_v2():
    # 64 x 48: red square, blue oval, black frame on the top row; an 8-bit
    # indexed PackBitsRect (green | yellow), a 32-bit DirectBitsRect
    # (#123456) and a 1-bit BitsRect (black top half) below; a line
    w, h = 64, 48
    ops = b""

    def op(code, data=b""):
        nonlocal ops
        ops += struct.pack(">H", code) + data
        if len(ops) % 2:
            ops += b"\0"

    op(0x0011, b"\x02\xff")
    op(0x0C00, struct.pack(">hHII", -2, 0, 0x00480000, 0x00480000) + rect(0, 0, h, w) + b"\0" * 4)
    op(0x001E)
    op(0x0001, struct.pack(">H", 10) + rect(0, 0, h, w))
    op(0x001A, struct.pack(">HHH", 0xFFFF, 0, 0))
    op(0x0031, rect(0, 0, 16, 16))
    op(0x001A, struct.pack(">HHH", 0, 0, 0xFFFF))
    op(0x0051, rect(0, 16, 16, 32))
    op(0x001A, struct.pack(">HHH", 0, 0, 0))
    op(0x0030, rect(0, 32, 16, 48))
    # 8-bit indexed, 16 x 16: index 0 green on the left, 1 yellow on the right
    pixmap = struct.pack(">H", 0x8000 | 16) + rect(0, 0, 16, 16)
    pixmap += struct.pack(">HHIIIHHHHIII", 0, 0, 0, 0x00480000, 0x00480000, 0, 8, 1, 8, 0, 0, 0)
    ctab = struct.pack(">IHH", 0, 0x8000, 1)
    ctab += struct.pack(">HHHH", 0, 0, 0xFFFF, 0) + struct.pack(">HHHH", 1, 0xFFFF, 0xFFFF, 0)
    rows = [bytes([0] * 8 + [1] * 8) for _ in range(16)]
    op(0x0098, pixmap + ctab + rect(0, 0, 16, 16) + rect(16, 0, 32, 16) + struct.pack(">H", 0)
       + packed_rows(rows, 16))
    # 32-bit, packType 4, 3 components, 16 x 16 of #123456
    pixmap = struct.pack(">IH", 0xFF, 0x8000 | 64) + rect(0, 0, 16, 16)
    pixmap += struct.pack(">HHIIIHHHHIII", 0, 4, 0, 0x00480000, 0x00480000, 16, 32, 3, 8, 0, 0, 0)
    rows = [bytes([0x12] * 16 + [0x34] * 16 + [0x56] * 16) for _ in range(16)]
    op(0x009A, pixmap + rect(0, 0, 16, 16) + rect(16, 16, 32, 32) + struct.pack(">H", 0)
       + packed_rows(rows, 64))
    # 1-bit bitmap, unpacked, 16 x 16: the top 8 rows black
    bitmap = struct.pack(">H", 2) + rect(0, 0, 16, 16)
    bits = b"\xff\xff" * 8 + b"\0\0" * 8
    op(0x0090, bitmap + rect(0, 0, 16, 16) + rect(32, 0, 48, 16) + struct.pack(">H", 0) + bits)
    op(0x0020, struct.pack(">hhhh", 40, 20, 40, 60))
    op(0x00FF)
    body = rect(0, 0, h, w) + ops
    return struct.pack(">H", (2 + len(body)) & 0xFFFF) + body


def pict_v1():
    # 32 x 32, version 1: a painted oval in the top half, a PackBitsRect
    # bitmap (black bottom-right quarter) below
    ops = b"\x11\x01"
    ops += b"\x51" + rect(0, 0, 16, 32)
    bitmap = struct.pack(">H", 2) + rect(0, 0, 16, 16)
    rows = [b"\x00\xff" if y >= 8 else b"\x00\x00" for y in range(16)]
    # rowBytes 2 is under 8: rows are stored unpacked
    ops += b"\x98" + bitmap + rect(0, 0, 16, 16) + rect(16, 16, 32, 32) + struct.pack(">H", 0) + b"".join(rows)
    ops += b"\xff"
    body = rect(0, 0, 32, 32) + ops
    return struct.pack(">H", 2 + len(body)) + body


def plte(pict_id, origin, buttons):
    """buttons: [((top, left, bottom, right), message)]; the rectangles are
    in the picture's coordinates, origin its frame's (v, h)"""
    out = struct.pack(">HHIh", 0, 0x0806, 1, pict_id) + struct.pack(">hh", *origin)
    out += b"\0" * 8 + struct.pack(">H", len(buttons))
    for (top, left, bottom, right), message in buttons:
        raw = message.encode("mac_roman")
        entry = rect(top, left, bottom, right) + b"\0\0" + bytes([len(raw)]) + raw
        if len(entry) % 2:
            entry += b"\0"
        out += entry
    return out


def addcolor(entries):
    """entries: AddColor's records, each (kind, hidden, ...): ("button" or
    "field", hidden, id, bevel, (r, g, b)), ("rect", hidden, (top, left,
    bottom, right), bevel, (r, g, b)), ("picture" or "file", hidden, (top,
    left, bottom, right), transparent, name); colour components are 16-bit"""
    out = b""
    for entry in entries:
        kind, hidden = entry[0], entry[1]
        code = {"button": 1, "field": 2, "rect": 3, "picture": 4, "file": 5}[kind]
        out += bytes([code | (0x80 if hidden else 0)])
        if kind in ("button", "field"):
            out += struct.pack(">hh3H", entry[2], entry[3], *entry[4])
        elif kind == "rect":
            out += rect(*entry[2]) + struct.pack(">h3H", entry[3], *entry[4])
        else:
            raw = entry[4].encode("mac_roman")
            out += rect(*entry[2]) + bytes([1 if entry[3] else 0, len(raw)]) + raw
    return out


def resource_fork(resources):
    """resources: [(type, id, name or None, data)], grouped by type in order"""
    data = b""
    offsets = []
    for _type, _id, _name, body in resources:
        offsets.append(len(data))
        data += struct.pack(">I", len(body)) + body
    types = []
    for rtype, _id, _name, _body in resources:
        if rtype not in types:
            types.append(rtype)
    names = b""
    name_offsets = []
    for _type, _id, name, _body in resources:
        if name is None:
            name_offsets.append(0xFFFF)
        else:
            raw = name.encode("mac_roman")
            name_offsets.append(len(names))
            names += bytes([len(raw)]) + raw
    type_list = struct.pack(">H", len(types) - 1)
    ref_lists = b""
    ref_base = 2 + 8 * len(types)
    for rtype in types:
        members = [i for i, r in enumerate(resources) if r[0] == rtype]
        type_list += rtype.encode("ascii") + struct.pack(
            ">HH", len(members) - 1, ref_base + len(ref_lists))
        for i in members:
            ref_lists += struct.pack(">hHI", resources[i][1], name_offsets[i],
                                     offsets[i] & 0xFFFFFF) + b"\0\0\0\0"
    data_offset = 256
    map_offset = data_offset + len(data)
    types_offset = 28
    names_offset = types_offset + len(type_list) + len(ref_lists)
    map_size = names_offset + len(names)
    header = struct.pack(">IIII", data_offset, map_offset, len(data), map_size)
    # the map: a copy of the header, a handle and a file reference (both
    # zero on disk), attributes, then the offsets of the type and name lists
    rmap = header + struct.pack(">IHHHH", 0, 0, 0, types_offset, names_offset)
    assert len(rmap) == types_offset
    rmap += type_list + ref_lists + names
    return header + b"\0" * (data_offset - 16) + data + rmap


def applefile(magic, entries):
    """entries: [(id, bytes)]"""
    out = struct.pack(">II", magic, 0x00020000) + b"\0" * 16
    out += struct.pack(">H", len(entries))
    offset = len(out) + 12 * len(entries)
    table = b""
    body = b""
    for entry_id, data in entries:
        table += struct.pack(">III", entry_id, offset + len(body), len(data))
        body += data
    return out + table + body


FINDER_INFO = b"STAKWILD" + b"\0" * 24
APPLESINGLE = 0x00051600
APPLEDOUBLE = 0x00051607


# An HFS volume, written from nothing: 512-byte allocation blocks
# starting at sector 4 (boot blocks 0-1, the master directory block 2, the
# volume bitmap 3), B-tree nodes of 512 bytes
HFS_BLOCK = 512


def hfs_node(kind, height, records, flink=0):
    """a B-tree node: its descriptor, its records, their offsets from the
    end of the node backwards (with the free space's after them)"""
    body = b""
    offsets = []
    for record in records:
        offsets.append(14 + len(body))
        body += record
    offsets.append(14 + len(body))
    node = struct.pack(">IIbBHH", flink, 0, kind, height, len(records), 0) + body
    tail = b"".join(struct.pack(">H", o) for o in reversed(offsets))
    assert len(node) + len(tail) <= HFS_BLOCK, "a node overflows"
    return node + b"\0" * (HFS_BLOCK - len(node) - len(tail)) + tail


def hfs_header_node(root, leaf_records, first_leaf, last_leaf, max_key, total, depth):
    header = struct.pack(">HIIIIHHII", depth, root, leaf_records, first_leaf,
                         last_leaf, HFS_BLOCK, max_key, total, 0) + b"\0" * 76
    # the header record, the user record, the map record (all nodes used)
    bitmap = bytes([0xFF] * (total // 8) + ([(0xFF << (8 - total % 8)) & 0xFF] if total % 8 else []))
    room = HFS_BLOCK - 14 - len(header) - 128 - 8
    return hfs_node(1, 0, [header, b"\0" * 128, bitmap.ljust(room, b"\0")])


def hfs_key(parent, name):
    raw = name.encode("mac_roman")
    key = bytes([6 + len(raw), 0]) + struct.pack(">I", parent) + bytes([len(raw)]) + raw
    return key + (b"\0" if len(key) % 2 else b"")


def hfs_extents(extents):
    extents = list(extents) + [(0, 0)] * (3 - len(extents))
    return b"".join(struct.pack(">HH", start, count) for start, count in extents)


def hfs_volume(name, folders, files):
    """folders: [(id, parent, name)]; files: [(id, parent, name, type,
    creator, data, rsrc, data_runs, rsrc_runs)], each *_runs a list of
    block counts the fork is cut into, laid out with a free block between
    them so that each run is its own extent"""
    blocks = []                          # allocation block contents

    def allocate(data, runs):
        data += b"\0" * (-len(data) % HFS_BLOCK)
        extents = []
        at = 0
        for count in runs:
            blocks.append(b"\0" * HFS_BLOCK)        # the gap
            extents.append((len(blocks), count))
            for i in range(count):
                blocks.append(data[at:at + HFS_BLOCK].ljust(HFS_BLOCK, b"\0"))
                at += HFS_BLOCK
        assert at >= len(data), "runs too short for the fork"
        return extents

    # the trees go first: blocks 0-1 the extents tree, 2-4 the catalog
    blocks.extend([b""] * 5)
    catalog = []
    overflow = []
    catalog.append(((1, name), struct.pack(">bbHHI", 1, 0, 0, len([f for f in folders if f[1] == 2]) +
                                           len([f for f in files if f[1] == 2]), 2) + b"\0" * 60))
    catalog.append(((2, ""), struct.pack(">bb8sI", 3, 0, b"", 1) + bytes([len(name)]) +
                    name.encode("mac_roman").ljust(31, b"\0")))
    for fid, parent, fname in folders:
        catalog.append(((parent, fname), struct.pack(">bbHHI", 1, 0, 0, 0, fid) + b"\0" * 60))
    for fid, parent, fname, ftype, creator, data, rsrc, data_runs, rsrc_runs in files:
        dext = allocate(data, data_runs) if data else []
        rext = allocate(rsrc, rsrc_runs) if rsrc else []
        for fork, ext in ((0, dext), (255, rext)):
            if len(ext) > 3:
                overflow.append((fork, fid, sum(c for _, c in ext[:3]), ext[3:6]))
        record = struct.pack(">bbBB", 2, 0, 0, 0) + ftype + creator + b"\0" * 8
        record += struct.pack(">IHIIHIIIII", fid, 0, len(data), len(data) + (-len(data) % HFS_BLOCK),
                              0, len(rsrc), len(rsrc) + (-len(rsrc) % HFS_BLOCK), 0, 0, 0)
        record += b"\0" * 16 + struct.pack(">H", 0) + hfs_extents(dext[:3]) + hfs_extents(rext[:3])
        record += b"\0" * 4
        assert len(record) == 102
        catalog.append(((parent, fname), record))
    catalog.sort(key=lambda r: (r[0][0], r[0][1].lower()))
    records = [hfs_key(*key) + data for key, data in catalog]
    half = len(records) // 2
    # the catalog: header (block 2), leaves 1 and 2 (blocks 3 and 4),
    # linked forward; no index node, as the depth is 1 and the root a leaf
    blocks[2] = hfs_header_node(1, len(records), 1, 2, 37, 3, 1)
    blocks[3] = hfs_node(-1, 1, records[:half], flink=2)
    blocks[4] = hfs_node(-1, 1, records[half:])
    # the extents tree: header (block 0), one leaf (block 1)
    xrecords = [bytes([7, fork]) + struct.pack(">IH", fid, start) + hfs_extents(ext)
                for fork, fid, start, ext in overflow]
    if xrecords:
        blocks[0] = hfs_header_node(1, len(xrecords), 1, 1, 7, 2, 1)
        blocks[1] = hfs_node(-1, 1, xrecords)
    else:
        blocks[0] = hfs_header_node(0, 0, 0, 0, 7, 2, 0)
        blocks[1] = b"\0" * HFS_BLOCK
    mdb = b"BD" + struct.pack(">IIHHHHHIIHIH", 0, 0, 0x0100, len([f for f in files if f[1] == 2]),
                              3, 0, len(blocks), HFS_BLOCK, HFS_BLOCK * 4, 4, 100, 0)
    mdb += bytes([len(name)]) + name.encode("mac_roman").ljust(27, b"\0")
    mdb = mdb.ljust(130, b"\0")
    mdb += struct.pack(">I", 2 * HFS_BLOCK) + hfs_extents([(0, 2)])
    mdb += struct.pack(">I", 3 * HFS_BLOCK) + hfs_extents([(2, 3)])
    assert len(mdb) == 162
    bitmap = bytes([0xFF] * (len(blocks) // 8) + ([(0xFF << (8 - len(blocks) % 8)) & 0xFF] if len(blocks) % 8 else []))
    return (b"\0" * 1024 + mdb.ljust(512, b"\0") + bitmap.ljust(512, b"\0") +
            b"".join(blocks))


def diskcopy42(name, volume):
    # the name as a Pascal string in 64 bytes, the data and tag sizes, their
    # checksums, the format (2: 1440K), the format byte, and 0x0100
    raw = name.encode("mac_roman")
    return (bytes([len(raw)]) + raw.ljust(63, b"\0") +
            struct.pack(">IIIIBBH", len(volume), 0, 0, 0, 3, 0x22, 0x0100) + volume)


def partition_map(volume):
    # block 0 the driver descriptor, blocks 1-2 the map (its own entry and
    # the volume's), the volume from block 64
    def entry(start, count, name, ptype):
        return (b"PM" + struct.pack(">HIII", 0, 2, start, count) +
                name.ljust(32, b"\0") + ptype.ljust(32, b"\0")).ljust(512, b"\0")
    blocks = len(volume) // 512
    ddm = (b"ER" + struct.pack(">HI", 512, 64 + blocks)).ljust(512, b"\0")
    out = ddm + entry(1, 63, b"Apple", b"Apple_partition_map") + \
        entry(64, blocks, b"Old Disk", b"Apple_HFS")
    return out.ljust(64 * 512, b"\0") + volume


def main():
    os.makedirs(OUT, exist_ok=True)
    samples = bytes(128 + (40 if (i // 25) % 2 else -40) for i in range(2000))
    fork = resource_fork([
        ("ICON", 128, "Synth Icon", icon()),
        ("CURS", 129, "Synth Cursor", cursor()),
        ("snd ", 130, "Synth Beep", sound(samples)),
        ("PICT", 131, "Synth Picture", pict()),
        ("XCMD", 132, "PopUpMenu", b"\x4e\x75"),
        ("XFCN", 133, "FileName", b"\x4e\x75"),
    ])
    # macOS's empty fork: a map with no types (the type count field is -1)
    data_offset = 256
    header = struct.pack(">IIII", data_offset, data_offset, 0, 30)
    empty = header + b"\0" * (data_offset - 16) + header + \
        struct.pack(">IHHHHH", 0, 0, 0, 28, 30, 0xFFFF)
    with open(os.path.join(HERE, "TestCardsBackgrounds.stack"), "rb") as f:
        stack = f.read()
    clash = resource_fork([
        ("ICON", 129, "Twin Icon", icon()),
        ("ICON", 2842, "Card Twin", icon()),
        ("ICON", 30000, "High Icon", icon()),
        ("CURS", 129, "Twin Cursor", cursor()),
    ])
    stereo16 = b"".join(struct.pack(">hh", (i * 300) % 30000, -(i * 300) % 30000)
                        for i in range(500))
    mono8 = bytes(128 + (i % 64) for i in range(800))
    # IMA 4:1: two packets per channel, each a predictor of 0 and step
    # index 0 then alternating codes
    ima_packet = b"\0\0" + bytes([0x17, 0x9F] * 16)
    ima = ima_packet * 4
    sounds = resource_fork([
        ("snd ", 200, "Stereo 16", extended_sound(2, 16, 500, samples=stereo16)),
        ("snd ", 201, "Mono 8 Extended", extended_sound(1, 8, 800, samples=mono8)),
        ("snd ", 202, "IMA", extended_sound(2, 16, 2, encode=0xFE, fmt=b"ima4",
                                           compression=-2, samples=ima)),
        ("snd ", 203, "MACE", extended_sound(1, 8, 100, encode=0xFE, fmt=b"MAC3",
                                            compression=3, samples=b"\0" * 200)),
        ("snd ", 204, "After NullCmd", sound_after_nullcmd(bytes(128 + (i % 50) for i in range(600)), 2)),
        ("snd ", 205, "After NullCmd 1", sound_after_nullcmd(bytes(128 - (i % 30) for i in range(700)), 1)),
    ])
    pictures = resource_fork([
        ("PICT", 300, "Colour", pict_v2()),
        ("PICT", 301, None, pict_v1()),
        ("PLTE", 300, "Test Palette", plte(300, (0, 0), [
            ((0, 0, 16, 16), '  hcPaletteTest 3, "a,b"'),
            ((16, 0, 32, 16), '  set the uPaletteSet of this stack to 5'),
        ])),
    ])
    colours = resource_fork([
        ("PICT", 300, "Colour", pict_v2()),
        ("HCbg", 2670, None, addcolor([
            ("button", False, 1, 2, (65535, 0, 0)),
            ("button", True, 2, 0, (0, 65535, 0)),
            ("rect", False, (300, 400, 330, 500), 0, (0, 0, 65535)),
        ])),
        ("HCcd", 2883, None, addcolor([
            ("rect", False, (10, 10, 40, 60), 3, (65535, 65535, 0)),
            ("picture", False, (100, 400, 148, 464), True, "Colour"),
            ("file", False, (0, 0, 10, 10), False, "Sky.pict"),
        ])),
        ("HCcd", 9999, None, addcolor([
            ("rect", False, (0, 0, 10, 10), 0, (0, 65535, 0)),
        ])),
    ])
    volume = hfs_volume("Old Disk", [(16, 2, "Stacks"), (17, 16, "More")], [
        (20, 16, "Synthetic Stack", b"STAK", b"WILD", stack, fork, [10, 6], [2, 2, 1, 1]),
        (21, 17, "Lost Type", b"????", b"????", stack, b"", [16], []),
        (22, 2, "Read Me", b"TEXT", b"ttxt", b"An old disk.\r", b"", [1], []),
    ])
    files = {
        "Stacks.hfs": volume,
        "Stacks.dc42": diskcopy42("Old Disk", volume),
        "Stacks.apm": partition_map(volume),
        "AddColor.rsrc": colours,
        "Synthetic.rsrc": fork,
        "Pictures.rsrc": pictures,
        "Sounds.rsrc": sounds,
        "Clash.rsrc": clash,
        "Synthetic.appledouble": applefile(APPLEDOUBLE, [(9, FINDER_INFO), (2, fork)]),
        "Empty.appledouble": applefile(APPLEDOUBLE, [(9, FINDER_INFO), (2, empty)]),
        "TestCardsBackgrounds.applesingle": applefile(APPLESINGLE, [
            (3, b"Synthetic Stack"), (9, FINDER_INFO), (1, stack), (2, fork)]),
    }
    for name, data in files.items():
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(data)
        print("%-36s %6d bytes" % (name, len(data)))


if __name__ == "__main__":
    main()
