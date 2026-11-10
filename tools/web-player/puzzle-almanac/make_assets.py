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

"""Make Puzzle Almanac's pictures, sounds, font and word list.

  python3 tools/web-player/puzzle-almanac/make_assets.py --kenney DIR \\
      --enable FILE --fonts DIR [--check]

--kenney is a folder of Kenney's packs (CC0, https://kenney.nl) as they
come, unzipped into folders of these names (as in the public mirror
https://github.com/ETdoFresh/kenney.nl, which Nova Rescue's came from too):

  assets-lettertiles-0     Letter Tiles
  puzzle-pack-ii           Puzzle Pack 2
  kenney_animalpackredux   Animal Pack Redux
  kenney_rpgaudio          RPG Audio
  kenney_voiceoverpack     Voiceover Pack

--enable is WORD.LST of ENABLE2K, the Enhanced North American Benchmark
LExicon (Alan Beale and M. Cooper, 2000), with its README beside it. Its
README says the list "is placed in the Public Domain for anyone to use as
they see fit". enable2k.zip is kept in SCOWL's repository
(https://github.com/en-wl/wordlist, branch v1, other/enable2k.zip), and
its files are lower case once unzipped with "unzip -LL", as SCOWL does.

--fonts is Google Fonts' folder of Atkinson Hyperlegible
(https://github.com/google/fonts, ofl/atkinsonhyperlegible): the Regular
and Bold TrueType files and OFL.txt. The Braille Institute made it so that
letters that look alike in other fonts (I, l and 1; O and 0) do not; it is
under the SIL Open Font License 1.1, with no Reserved Font Name.

What is made, beside this script:

  art/       the pictures, PNG, and art.txt, which lists each one with the
             size in points that the game draws it at on a screen of one
             pixel to a point (it draws them larger or smaller from there).
             The files have SCALE times as many pixels, so that they are
             sharp on a phone's screen:
               the blank letter tiles, in four finishes, made smaller from
                 the pack's 256-pixel PNGs;
               the thirty round animals (the stickers), as they come;
               a star and two sparkles, made smaller.
  sounds/    WAV files, mono 22050 Hz 16-bit (Kenney's are Ogg Vorbis,
             which Safari on older iPhones cannot decode), each with its
             silence at the end cut off: the pages and the pieces from RPG
             Audio, and the female voice of the Voiceover Pack saying the
             numbers one to nine, "correct" and "congratulations".
  fonts/     Atkinson Hyperlegible, Regular and Bold, with Macintosh name
             records added beside the Windows ones (mac_names), without
             which the web engine cannot load them.
  data/words.txt   every word of ENABLE of four, five or six letters, one a
             line, sorted: the words that a guess may be. (The hidden words
             themselves are in data/answers.txt, written for the game.)
  licenses/  each pack's licence, the font's OFL and ENABLE's README.
  SOURCES.md which file each comes from.

data/numbers.txt is made by make_puzzles.py beside this script.

Nothing here runs in CI: the game's builder
(tools/web-player/puzzle-almanac.livecodescript) reads the committed files.
--check makes everything in a temporary folder and compares it with them.
"""

import argparse
import os
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

TILES = 'assets-lettertiles-0'
PUZZLE = 'puzzle-pack-ii'
ANIMALS = 'kenney_animalpackredux'
RPG = 'kenney_rpgaudio'
VOICE = 'kenney_voiceoverpack'
PACK_NAMES = {
    TILES: 'Letter Tiles',
    PUZZLE: 'Puzzle Pack 2',
    ANIMALS: 'Animal Pack Redux',
    RPG: 'RPG Audio',
    VOICE: 'Voiceover Pack',
}
LICENSES = {TILES: 'License.txt', PUZZLE: 'License.txt', ANIMALS: 'License.txt',
            RPG: 'License.txt', VOICE: 'License.txt'}

# Pixels to a point in the files
SCALE = 3

# (name in the game, pack, file in the pack, width and height in points)
PICTURES = [
    ('tile-marble', TILES, 'PNG/Marble/letter.png', 64, 64),
    ('tile-gold', TILES, 'PNG/Solid/letter.png', 64, 64),
    ('tile-blue', TILES, 'PNG/Blue/letter.png', 64, 64),
    ('tile-stone', TILES, 'PNG/Metal/letter.png', 64, 64),
    ('star', PUZZLE, 'PNG/Particles yellow/particleYellow_3.png', 40, 38),
    ('sparkle-gold', PUZZLE, 'PNG/Particles yellow/particleYellow_1.png', 30, 30),
    ('sparkle-blue', PUZZLE, 'PNG/Particles blue/particleBlue_6.png', 30, 30),
]
# The stickers: Animal Pack Redux's round animals, copied (154 by 132
# pixels, drawn at 77 by 66 points: two pixels to a point)
STICKERS = ['bear', 'buffalo', 'chick', 'chicken', 'cow', 'crocodile', 'dog', 'duck', 'elephant',
            'frog', 'giraffe', 'goat', 'gorilla', 'hippo', 'horse', 'monkey', 'moose', 'narwhal',
            'owl', 'panda', 'parrot', 'penguin', 'pig', 'rabbit', 'rhino', 'sloth', 'snake',
            'walrus', 'whale', 'zebra']
STICKER_SCALE = 2

# (name in the game, pack, file in the pack, gain in dB)
SOUNDS = [
    ('page', RPG, 'Audio/bookFlip2.ogg', 0),
    ('open', RPG, 'Audio/bookOpen.ogg', 0),
    ('close', RPG, 'Audio/bookClose.ogg', 0),
    ('place', RPG, 'Audio/bookPlace1.ogg', 0),
    ('tap', RPG, 'Audio/handleSmallLeather.ogg', 4),
    ('erase', RPG, 'Audio/cloth2.ogg', 0),
    ('nope', RPG, 'Audio/metalLatch.ogg', -4),
    ('reveal', RPG, 'Audio/bookFlip1.ogg', 0),
    ('coins', RPG, 'Audio/handleCoins.ogg', 0),
] + [('say-%d' % n, VOICE, 'Female/%d.ogg' % n, 0) for n in range(1, 10)] + [
    ('say-correct', VOICE, 'Female/correct.ogg', 0),
    ('say-congratulations', VOICE, 'Female/congratulations.ogg', 0),
]

FONTS = [('AtkinsonHyperlegible-Regular.ttf', 'AtkinsonHyperlegible-Regular.ttf'),
         ('AtkinsonHyperlegible-Bold.ttf', 'AtkinsonHyperlegible-Bold.ttf')]

WORD_LENGTHS = (4, 5, 6)


def png_out(img, path):
    # (no time or other text chunks, so that a file made again is the same)
    img.save(path, optimize=True)


def make_pictures(kenney, target):
    from PIL import Image
    os.makedirs(target, exist_ok=True)
    lines = ['# Puzzle Almanac: its pictures. Made by ../make_assets.py; see ../SOURCES.md.',
             '# name<tab>file<tab>width<tab>height: the size in points the game draws it at']
    for name, pack, path, w, h in PICTURES:
        img = Image.open(os.path.join(kenney, pack, path)).convert('RGBA')
        img = img.resize((w * SCALE, h * SCALE), Image.LANCZOS)
        png_out(img, os.path.join(target, name + '.png'))
        lines.append('%s\t%s.png\t%d\t%d' % (name, name, w, h))
    for name in STICKERS:
        img = Image.open(os.path.join(kenney, ANIMALS, 'PNG/Round', name + '.png')).convert('RGBA')
        png_out(img, os.path.join(target, 'animal-' + name + '.png'))
        lines.append('animal-%s\tanimal-%s.png\t%d\t%d' % (name, name, img.size[0] // STICKER_SCALE,
                                                         img.size[1] // STICKER_SCALE))
    with open(os.path.join(target, 'art.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def make_sounds(kenney, target):
    os.makedirs(target, exist_ok=True)
    for name, pack, path, gain in SOUNDS:
        filters = ['silenceremove=stop_periods=-1:stop_duration=0.05:stop_threshold=-55dB']
        if gain:
            filters.append('volume=%ddB' % gain)
        out = os.path.join(target, name + '.wav')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(kenney, pack, path),
                        '-af', ','.join(filters), '-ac', '1', '-ar', '22050', '-sample_fmt', 's16',
                        '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact', out],
                       check=True)


def _checksum(data):
    data = data + b'\0' * (-len(data) % 4)
    return sum(struct.unpack('>%dI' % (len(data) // 4), data)) & 0xFFFFFFFF


def mac_names(font):
    """The font, with Macintosh name records (platform 1, Roman, English)
    beside its Windows ones for the family, the face, the full name and
    the PostScript name, or as it was if it has them already.

    The web engine (and Android's) finds a font file's name only in a
    Macintosh record of name 4 (MCFreeTypeGetFontInfoFromData in
    engine/src/freetype-font.cpp): without one, "start using font file"
    answers "can't load font file". Google Fonts' files have Windows
    records alone. Only the name table and the font's checksums change;
    the OFL lets a modified font keep its name when, as here, it reserves
    none."""
    version, count = struct.unpack('>IH', font[:6])
    tables = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack('>4sIII', font[12 + 16 * i:28 + 16 * i])
        tables[tag] = (offset, length)
    offset, length = tables[b'name']
    name = font[offset:offset + length]
    fmt, n, strings = struct.unpack('>HHH', name[:6])
    if fmt != 0:
        raise ValueError('the font\'s name table is not of format 0')
    records = []
    for i in range(n):
        records.append(struct.unpack('>HHHHHH', name[6 + 12 * i:18 + 12 * i]))
    texts = {}
    for platform, encoding, language, name_id, size, at in records:
        if platform == 1 and encoding == 0 and language == 0 and name_id == 4:
            return font
        if platform == 3 and encoding == 1 and language == 0x409 and name_id in (1, 2, 4, 6):
            texts[name_id] = name[strings + at:strings + at + size].decode('utf-16-be')
    pool = bytearray()
    out = []
    for platform, encoding, language, name_id, size, at in records:
        out.append((platform, encoding, language, name_id, name[strings + at:strings + at + size]))
    for name_id, text in texts.items():
        out.append((1, 0, 0, name_id, text.encode('mac_roman')))
    out.sort(key=lambda r: r[:4])
    head = struct.pack('>HHH', 0, len(out), 6 + 12 * len(out))
    body = b''
    for platform, encoding, language, name_id, data in out:
        at = pool.find(data) if data else 0
        if at < 0:
            at = len(pool)
            pool += data
        body += struct.pack('>HHHHHH', platform, encoding, language, name_id, len(data), at)
    tables_data = {}
    for tag, (offset, length) in tables.items():
        tables_data[tag] = font[offset:offset + length]
    tables_data[b'name'] = head + body + bytes(pool)
    # the tables again, in the order they were in, each on 4 bytes
    order = sorted(tables, key=lambda tag: tables[tag][0])
    head_at = None
    blob = bytearray()
    start = 12 + 16 * count
    entries = {}
    for tag in order:
        data = tables_data[tag]
        if tag == b'head':
            data = data[:8] + b'\0\0\0\0' + data[12:]
            head_at = start + len(blob)
        entries[tag] = (_checksum(data), start + len(blob), len(data))
        blob += data + b'\0' * (-len(data) % 4)
    out_font = bytearray(font[:12])
    for tag in sorted(tables):
        out_font += struct.pack('>4sIII', tag, *entries[tag])
    out_font += blob
    adjust = (0xB1B0AFBA - _checksum(bytes(out_font))) & 0xFFFFFFFF
    out_font[head_at + 8:head_at + 12] = struct.pack('>I', adjust)
    return bytes(out_font)


def make_fonts(fonts, target):
    os.makedirs(target, exist_ok=True)
    for name, source in FONTS:
        with open(os.path.join(fonts, source), 'rb') as f:
            font = f.read()
        with open(os.path.join(target, name), 'wb') as f:
            f.write(mac_names(font))


def make_words(enable, target):
    os.makedirs(target, exist_ok=True)
    with open(enable, encoding='latin-1') as f:
        words = sorted({w.strip() for w in f if w.strip()})
    keep = [w for w in words if len(w) in WORD_LENGTHS and w.isalpha() and w.islower() and w.isascii()]
    with open(os.path.join(target, 'words.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(keep) + '\n')


def make_licenses(kenney, enable, fonts, target):
    os.makedirs(target, exist_ok=True)
    for pack, name in LICENSES.items():
        shutil.copyfile(os.path.join(kenney, pack, name), os.path.join(target, pack + '.txt'))
    shutil.copyfile(os.path.join(fonts, 'OFL.txt'), os.path.join(target, 'atkinson-hyperlegible-OFL.txt'))
    # ENABLE's README is in the PC's old code page: made UTF-8 (its box
    # characters around the title become plain ones)
    with open(os.path.join(os.path.dirname(enable), 'readme'), encoding='cp437') as f:
        text = f.read().replace('\r\n', '\n')
    with open(os.path.join(target, 'enable2k-readme.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def sources_md():
    rows = ['| File here | From | File there | Made by |', '| --- | --- | --- | --- |']
    for name, pack, path, w, h in PICTURES:
        rows.append('| `art/%s.png` | Kenney, %s | `%s` | made %d by %d pixels (%d by %d points) |' % (
            name, PACK_NAMES[pack], path, w * SCALE, h * SCALE, w, h))
    for name in STICKERS:
        rows.append('| `art/animal-%s.png` | Kenney, %s | `PNG/Round/%s.png` | copied |' % (
            name, PACK_NAMES[ANIMALS], name))
    for name, pack, path, gain in SOUNDS:
        rows.append('| `sounds/%s.wav` | Kenney, %s | `%s` | WAV, mono 22050 Hz%s |' % (
            name, PACK_NAMES[pack], path, ', %+d dB' % gain if gain else ''))
    for name, source in FONTS:
        rows.append('| `fonts/%s` | Google Fonts, Atkinson Hyperlegible | `ofl/atkinsonhyperlegible/%s` '
                    '| copied, with Macintosh name records added |' % (name, source))
    rows.append('| `data/words.txt` | ENABLE2K (`enable2k.zip`) | `word.lst` | its words of 4, 5 and 6 letters |')
    return rows


def write_sources(target):
    text = ['# Puzzle Almanac: where its pictures, sounds, font and words come from', '',
            'The pictures and sounds are Kenney\'s (https://kenney.nl), CC0 1.0 (public',
            'domain). The font is Atkinson Hyperlegible, by the Braille Institute of',
            'America, under the SIL Open Font License 1.1. The words that a guess may be',
            'are ENABLE2K\'s, which its README places in the public domain. Each licence',
            'is in `licenses/`. `make_assets.py` made these files, as the last column',
            'says; `make_puzzles.py` made `data/numbers.txt`, and `data/answers.txt`',
            '(the hidden words and what they mean) was written for the game.', ''] + sources_md()
    with open(os.path.join(target, 'SOURCES.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(text) + '\n')


def make_all(kenney, enable, fonts, target):
    make_pictures(kenney, os.path.join(target, 'art'))
    make_sounds(kenney, os.path.join(target, 'sounds'))
    make_fonts(fonts, os.path.join(target, 'fonts'))
    make_words(enable, os.path.join(target, 'data'))
    make_licenses(kenney, enable, fonts, os.path.join(target, 'licenses'))
    write_sources(target)


def compare(made, committed):
    from PIL import Image, ImageChops
    problems = []
    for root, dirs, names in os.walk(made):
        for name in names:
            rel = os.path.relpath(os.path.join(root, name), made)
            mine = os.path.join(committed, rel)
            if not os.path.isfile(mine):
                problems.append('%s is not committed' % rel)
            elif name.endswith('.png'):
                a, b = Image.open(os.path.join(root, name)).convert('RGBA'), Image.open(mine).convert('RGBA')
                if a.size != b.size or ImageChops.difference(a, b).getbbox() is not None:
                    problems.append('%s differs' % rel)
            else:
                with open(os.path.join(root, name), 'rb') as f1, open(mine, 'rb') as f2:
                    first, second = f1.read(), f2.read()
                if name.endswith('.txt') or name.endswith('.md'):
                    first, second = first.replace(b'\r\n', b'\n'), second.replace(b'\r\n', b'\n')
                if first != second:
                    problems.append('%s differs' % rel)
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--kenney', required=True, help="the folder of Kenney's packs")
    ap.add_argument('--enable', required=True, help="ENABLE2K's word.lst, its readme beside it")
    ap.add_argument('--fonts', required=True, help="Google Fonts' ofl/atkinsonhyperlegible folder")
    ap.add_argument('--check', action='store_true', help='compare with the committed files')
    args = ap.parse_args(argv)
    if args.check:
        work = tempfile.mkdtemp(prefix='puzzle-almanac-assets-')
        try:
            make_all(args.kenney, args.enable, args.fonts, work)
            problems = compare(work, HERE)
            for p in problems:
                print('  ' + p)
            print('ASSETS DIFFER' if problems else 'ASSETS OK')
            return 1 if problems else 0
        finally:
            shutil.rmtree(work, ignore_errors=True)
    make_all(args.kenney, args.enable, args.fonts, HERE)
    print('ASSETS MADE')
    return 0


if __name__ == '__main__':
    sys.exit(main())
