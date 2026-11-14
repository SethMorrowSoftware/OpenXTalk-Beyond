#!/usr/bin/env python3
"""Make the small animated GIFs of animated-gif.livecodescript.

Each GIF is a few pixels, built byte by byte here (a plain LZW encoder, no
image library), so the test can carry it as base64 and so each one holds
exactly the disposal, transparency and frame rectangles it is about. Run
it to print the base64 the test carries; --check fails when the test's
copy is not what this script makes.

Palette of every GIF: 0 red, 1 green, 2 blue, 3 black.
"""
import base64
import os
import re
import struct
import sys

PALETTE = bytes([255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0])


def lzw(pixels, min_size=2):
    clear, eoi = 1 << min_size, (1 << min_size) + 1
    out, acc, nbits = bytearray(), 0, 0

    def emit(code, size):
        nonlocal acc, nbits
        acc |= code << nbits
        nbits += size
        while nbits >= 8:
            out.append(acc & 0xFF)
            acc >>= 8
            nbits -= 8

    size = min_size + 1
    table = {bytes([i]): i for i in range(clear)}
    next_code = eoi + 1
    emit(clear, size)
    w = b""
    for p in pixels:
        wc = w + bytes([p])
        if wc in table:
            w = wc
            continue
        emit(table[w], size)
        if next_code < 4096:
            table[wc] = next_code
            next_code += 1
            if next_code > (1 << size) and size < 12:
                size += 1
        w = bytes([p])
    if w:
        emit(table[w], size)
    emit(eoi, size)
    if nbits:
        out.append(acc & 0xFF)
    data = bytearray([min_size])
    for i in range(0, len(out), 255):
        chunk = out[i:i + 255]
        data += bytes([len(chunk)]) + chunk
    data.append(0)
    return bytes(data)


def gif(width, height, frames):
    """frames: (left, top, w, h, pixels, delay_cs, disposal, transparent)"""
    b = bytearray(b"GIF89a")
    b += struct.pack("<HHBBB", width, height, 0x80 | 0x01, 0, 0)  # 4-colour global table
    b += PALETTE
    # NETSCAPE2.0: loop forever
    b += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"
    for left, top, w, h, px, delay, disposal, transp in frames:
        assert len(px) == w * h
        packed = (disposal << 2) | (1 if transp is not None else 0)
        b += struct.pack("<BBBBHBB", 0x21, 0xF9, 4, packed, delay,
                         transp if transp is not None else 0, 0)
        b += struct.pack("<BHHHHB", 0x2C, left, top, w, h, 0)
        b += lzw(px)
    b.append(0x3B)
    return bytes(b)


R, G, B, K = 0, 1, 2, 3

FIXTURES = {
    # Three frames on a 2x1 canvas, none with a disposal of its own (what
    # most GIF makers write). Frame 2's first pixel is its transparent
    # colour: the red under it stays. Delays 10, 0 and 25 hundredths.
    "kGifHoles": gif(2, 1, [
        (0, 0, 2, 1, [R, B], 10, 0, None),
        (0, 0, 2, 1, [K, G], 0, 0, K),
        (0, 0, 2, 1, [G, G], 25, 0, None),
    ]),
    # A 1x3 canvas (taller than wide). Frame 2 covers the lower two rows
    # and is "restore to previous": frame 3 must find them red again.
    "kGifRestorePrevious": gif(1, 3, [
        (0, 0, 1, 3, [R, R, R], 5, 1, None),
        (0, 1, 1, 2, [G, G], 5, 3, None),
        (0, 0, 1, 1, [B], 5, 1, None),
    ]),
    # A 2x1 canvas. Frame 2 starts at the second pixel and is two wide,
    # one past the canvas: the part on the canvas is drawn.
    "kGifPastCanvas": gif(2, 1, [
        (0, 0, 2, 1, [R, R], 5, 1, None),
        (1, 0, 2, 1, [G, B], 5, 1, None),
    ]),
}

TEST = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "animated-gif.livecodescript")


def main():
    want = {k: base64.b64encode(v).decode() for k, v in FIXTURES.items()}
    if "--check" in sys.argv:
        text = open(TEST, encoding="utf-8").read()
        bad = [k for k, v in want.items()
               if not re.search(r'constant %s = "%s"' % (k, re.escape(v)), text)]
        if bad:
            print("stale in animated-gif.livecodescript: " + ", ".join(bad))
            return 1
        print("OK: %d GIF fixtures match" % len(want))
        return 0
    for k, v in want.items():
        print('constant %s = "%s"' % (k, v))
    return 0


if __name__ == "__main__":
    sys.exit(main())
