#!/usr/bin/env python3
"""Take every HyperCard stack out of a Mac disk image, for a sweep.

    python3 extract.py HyperCard-Stacks.img stacks/

Reads an HFS volume, or a disk image with an Apple partition map (a CD
image), and writes each file of type STAK (or whose data fork says STAK)
as stacks/NNNNN.bin in MacBinary II, both forks, the way File > Import
Stack takes a stack with its resource fork. stacks/index.tsv lists each
one: its number, its path on the volume (folders joined by colons), and
the sizes of its data and resource forks.

Needs the machfs package (pip install machfs).
"""

import os
import struct
import sys

try:
    import machfs
except ImportError:
    sys.exit("extract.py needs machfs: pip install machfs")


def crc16(data):
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return crc


def macbinary(name, file):
    encoded = name.encode("mac_roman", "replace")[:63]
    header = bytearray(128)
    header[1] = len(encoded)
    header[2:2 + len(encoded)] = encoded
    header[65:69] = file.type
    header[69:73] = file.creator
    header[73] = (file.flags >> 8) & 0xFF
    struct.pack_into(">II", header, 83, len(file.data), len(file.rsrc))
    struct.pack_into(">II", header, 91, file.crdate & 0xFFFFFFFF, file.mddate & 0xFFFFFFFF)
    header[101] = file.flags & 0xFF
    header[122] = 129
    header[123] = 129
    struct.pack_into(">H", header, 124, crc16(bytes(header[:124])))

    def pad(data):
        return data + bytes((-len(data)) % 128)

    return bytes(header) + pad(file.data) + pad(file.rsrc)


def hfs_volume(image):
    """The HFS volume of the image: the whole image, or its Apple_HFS
    partition when it starts with a driver descriptor map ("ER")."""
    if image[:2] != b"ER":
        return image
    block = struct.unpack(">H", image[2:4])[0] or 512
    count = None
    entry = 1
    while count is None or entry <= count:
        at = entry * block
        if image[at:at + 2] != b"PM":
            break
        count = struct.unpack(">I", image[at + 4:at + 8])[0]
        start, size = struct.unpack(">II", image[at + 8:at + 16])
        kind = image[at + 48:at + 80].split(b"\0")[0]
        if kind == b"Apple_HFS":
            return image[start * block:(start + size) * block]
        entry += 1
    sys.exit("no Apple_HFS partition in the image")


def files(folder, path):
    for name, item in folder.items():
        if isinstance(item, machfs.Folder):
            yield from files(item, path + (name,))
        else:
            yield path, name, item


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    with open(sys.argv[1], "rb") as handle:
        image = handle.read()
    volume = machfs.Volume()
    volume.read(hfs_volume(image))
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    count = 0
    with open(os.path.join(out, "index.tsv"), "w", encoding="utf-8") as index:
        for path, name, item in files(volume, ()):
            if not isinstance(item, machfs.File):
                continue
            if item.type != b"STAK" and item.data[4:8] != b"STAK":
                continue
            count += 1
            with open(os.path.join(out, "%05d.bin" % count), "wb") as handle:
                handle.write(macbinary(name, item))
            index.write("%05d\t%s\t%d\t%d\n" % (count, ":".join(path + (name,)), len(item.data), len(item.rsrc)))
    print(count, "stacks")


if __name__ == "__main__":
    main()
