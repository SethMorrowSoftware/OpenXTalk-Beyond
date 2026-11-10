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

"""Make Nova Rescue's pictures, sounds and font from Kenney's packs.

  python3 tools/web-player/nova-rescue/make_assets.py --kenney DIR [--check]

DIR holds Kenney's packs as they come (CC0, https://kenney.nl), unzipped
into folders of these names:

  spaceshooter                   Space Shooter Redux
  kenney_spaceshooterextension   Space Shooter Extension
  uipack-space                   UI Pack: Space Expansion
  kenney_digitalaudio            Digital Audio
  kenney_interfacesounds         Interface Sounds
  kenney_musicjingles            Music Jingles

The committed results are in art/, sounds/ and fonts/ beside this script,
with each pack's licence in licenses/ and SOURCES.md, which names the file
of the pack that each one comes from. Nothing here runs in CI: the game's
builder (tools/web-player/nova-rescue.livecodescript) reads the committed
files. This script is how they were made, so that they can be made again.

Pictures. A pack's PNGs are drawn for a screen of one pixel to a point, and a
phone has two or three. So each picture is drawn again, larger, from the
pack's own vector sheet: the sheet is rendered by Chromium (Playwright) at
the pack's size and at SCALE times it, the PNG is found on the first by
normalized cross-correlation (numpy and scipy), and the same place is cut
out of the second. The result must look like the PNG when made small again,
or the script stops. art.txt lists each picture: its name in the game, its
file, and the size of the pack's PNG, which is the size the game draws it at
on a screen of one pixel to a point (it draws it smaller or larger from
there, never from the number of pixels in the file). The mothership and
its missile are turned upside down, to fly down the screen at the player.

Sounds. Kenney's are Ogg Vorbis, which Safari on older iPhones cannot
decode. Each is made a mono 22050 Hz 16-bit WAV with ffmpeg, its silence at
the end cut off, and the longer ones faded out.

The font is copied as it is. The title's NOVA is a picture drawn from it
(LOGOS), as KenVector Future draws a V as a U: its V is drawn as a V.

--check makes everything in a temporary folder and compares it with the
committed files (the pictures by their pixels, within a small tolerance, as
another Chromium may draw an edge a little differently).
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

# The pictures: (name in the game, pack, PNG in the pack). Redux's PNGs are
# drawn again at SCALE times from its vector sheet; the extension's from its
# 1x "Sprites", at SCALE * EXTENSION_SCALE (its sprites are drawn smaller)
SCALE = 2
EXTENSION_SCALE = 1.5
REDUX = 'spaceshooter'
EXTENSION = 'kenney_spaceshooterextension'
PICTURES = [
    ('ship', REDUX, 'PNG/playerShip1_orange.png'),
    ('ship-damage1', REDUX, 'PNG/Damage/playerShip1_damage1.png'),
    ('ship-damage2', REDUX, 'PNG/Damage/playerShip1_damage2.png'),
    ('ship-damage3', REDUX, 'PNG/Damage/playerShip1_damage3.png'),
    ('life', REDUX, 'PNG/UI/playerLife1_orange.png'),
    ('flame1', REDUX, 'PNG/Effects/fire13.png'),
    ('flame2', REDUX, 'PNG/Effects/fire03.png'),
    ('shield', REDUX, 'PNG/Effects/shield3.png'),
    ('laser', REDUX, 'PNG/Lasers/laserBlue01.png'),
    ('laser-hit', REDUX, 'PNG/Lasers/laserBlue08.png'),
    ('bolt', REDUX, 'PNG/Lasers/laserRed02.png'),
    ('bolt-hit', REDUX, 'PNG/Lasers/laserRed08.png'),
    ('scout', REDUX, 'PNG/Enemies/enemyRed1.png'),
    ('weaver', REDUX, 'PNG/Enemies/enemyGreen3.png'),
    ('gunship', REDUX, 'PNG/Enemies/enemyBlue4.png'),
    ('ufo', REDUX, 'PNG/ufoYellow.png'),
    ('meteor-big1', REDUX, 'PNG/Meteors/meteorBrown_big1.png'),
    ('meteor-big2', REDUX, 'PNG/Meteors/meteorBrown_big3.png'),
    ('meteor-big3', REDUX, 'PNG/Meteors/meteorGrey_big1.png'),
    ('meteor-med1', REDUX, 'PNG/Meteors/meteorBrown_med1.png'),
    ('meteor-med2', REDUX, 'PNG/Meteors/meteorBrown_med3.png'),
    ('meteor-med3', REDUX, 'PNG/Meteors/meteorGrey_med1.png'),
    ('meteor-small1', REDUX, 'PNG/Meteors/meteorBrown_small1.png'),
    ('meteor-small2', REDUX, 'PNG/Meteors/meteorBrown_small2.png'),
    ('meteor-small3', REDUX, 'PNG/Meteors/meteorGrey_small1.png'),
    ('power-twin', REDUX, 'PNG/Power-ups/powerupBlue_bolt.png'),
    ('power-shield', REDUX, 'PNG/Power-ups/powerupGreen_shield.png'),
    ('power-repair', REDUX, 'PNG/Power-ups/powerupRed_star.png'),
    ('star', REDUX, 'PNG/Power-ups/star_gold.png'),
    ('spark1', REDUX, 'PNG/Effects/star1.png'),
    ('spark2', REDUX, 'PNG/Effects/star2.png'),
    ('spark3', REDUX, 'PNG/Effects/star3.png'),
    ('astronaut1', EXTENSION, 'PNG/Sprites/Astronauts/spaceAstronauts_007.png'),
    ('astronaut2', EXTENSION, 'PNG/Sprites/Astronauts/spaceAstronauts_008.png'),
    ('astronaut3', EXTENSION, 'PNG/Sprites/Astronauts/spaceAstronauts_016.png'),
    ('mothership', EXTENSION, 'PNG/Sprites/Ships/spaceShips_007.png'),
    ('missile', EXTENSION, 'PNG/Sprites/Missiles/spaceMissiles_001.png'),
    ('smoke1', EXTENSION, 'PNG/Sprites/Effects/spaceEffects_009.png'),
    ('smoke2', EXTENSION, 'PNG/Sprites/Effects/spaceEffects_014.png'),
    ('smoke3', EXTENSION, 'PNG/Sprites/Effects/spaceEffects_016.png'),
]
# The pictures that are not on the vector sheet, made larger from the PNG
ENLARGED = set()
# The pictures turned upside down: the mothership and its missiles fly
# down the screen, at the player, and Kenney drew them flying up
FLIPPED = {'mothership', 'missile'}
SHEETS = {REDUX: 'Vector/sheet.svg', EXTENSION: 'Vector/spaceShooter2_vector.svg'}
# Pictures copied as they are (none: Kenney's backdrop, a texture, was
# one, until the game's frames showed that a card's pattern costs most of
# a frame in a phone's browser; the game's space is its colour)
COPIED = []

# Pictures drawn here from Kenney's font: (name in the game, word, size in
# points, colour). The title's NOVA: KenVector Future draws V and U alike
# (a U), so its V is drawn here as a V, a stroke as wide as the font's.
# Drawn LOGO_SCALE times, from LOGO_SCALE * 4 times made smaller.
LOGO_SCALE = 3
LOGOS = [('logo-nova', 'NOVA', 56, (0xFF, 0xB5, 0x2E))]

# The sounds: (name in the game, pack, file, seconds kept at most or None)
SOUNDS = [
    ('shoot', REDUX, 'Bonus/sfx_laser1.ogg', 0.35),
    ('enemy-shot', REDUX, 'Bonus/sfx_laser2.ogg', 0.35),
    ('hit', REDUX, 'Bonus/sfx_lose.ogg', None),
    ('shield-up', REDUX, 'Bonus/sfx_shieldUp.ogg', None),
    ('shield-down', REDUX, 'Bonus/sfx_shieldDown.ogg', None),
    ('warning', REDUX, 'Bonus/sfx_twoTone.ogg', None),
    ('boom', 'kenney_digitalaudio', 'Audio/spaceTrash2.ogg', 0.6),
    ('big-boom', 'kenney_digitalaudio', 'Audio/spaceTrash4.ogg', 1.1),
    ('power', 'kenney_digitalaudio', 'Audio/powerUp2.ogg', None),
    ('click', 'kenney_interfacesounds', 'Audio/select_002.ogg', None),
    ('rescue', 'kenney_musicjingles', 'Audio/8-Bit jingles/jingles_NES09.ogg', None),
    ('start', 'kenney_musicjingles', 'Audio/8-Bit jingles/jingles_NES03.ogg', None),
    ('best', 'kenney_musicjingles', 'Audio/8-Bit jingles/jingles_NES12.ogg', None),
    ('clear', 'kenney_musicjingles', 'Audio/Steel jingles/jingles_STEEL02.ogg', None),
    ('game-over', 'kenney_musicjingles', 'Audio/Steel jingles/jingles_STEEL01.ogg', None),
]
FONTS = [('kenvector_future.ttf', 'uipack-space', 'Fonts/kenvector_future.ttf')]
LICENSES = {
    REDUX: 'license.txt', EXTENSION: 'License.txt', 'uipack-space': 'license.txt',
    'kenney_digitalaudio': 'License.txt', 'kenney_interfacesounds': 'License.txt',
    'kenney_musicjingles': 'License.txt',
}
PACK_NAMES = {
    REDUX: 'Space Shooter Redux', EXTENSION: 'Space Shooter Extension',
    'uipack-space': 'UI Pack: Space Expansion', 'kenney_digitalaudio': 'Digital Audio',
    'kenney_interfacesounds': 'Interface Sounds', 'kenney_musicjingles': 'Music Jingles',
}


def render_sheet(svg, scale, work):
    """The vector sheet as RGBA pixels at scale, by Chromium."""
    from playwright.sync_api import sync_playwright
    from PIL import Image
    out = os.path.join(work, 'sheet-%s-%s.png' % (os.path.basename(svg), scale))
    with open(svg, encoding='utf-8') as f:
        head = f.read(2000)
    import re
    m = re.search(r'viewBox="0 0 (\d+) (\d+)"', head)
    width, height = (int(m.group(1)), int(m.group(2))) if m else (1600, 1300)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={'width': width, 'height': height}, device_scale_factor=scale)
        page.goto('file://' + os.path.abspath(svg))
        page.screenshot(path=out, omit_background=True, clip={'x': 0, 'y': 0, 'width': width, 'height': height})
        browser.close()
    return Image.open(out).convert('RGBA')


def on_grey(img):
    """RGB floats of an RGBA picture over mid grey, the alpha a fourth channel."""
    import numpy as np
    a = np.asarray(img, dtype=np.float64) / 255.0
    alpha = a[..., 3:4]
    rgb = a[..., :3] * alpha + 0.5 * (1 - alpha)
    return np.concatenate([rgb, alpha], axis=2)


def find(sheet, sprite):
    """Where sprite (RGBA) is on sheet (RGBA, the same scale): (x, y, score)."""
    import numpy as np
    from scipy.signal import fftconvolve
    big, small = on_grey(sheet), on_grey(sprite)
    h, w = small.shape[:2]
    total = None
    for c in range(4):
        image = big[..., c]
        t = small[..., c] - small[..., c].mean()
        tn = np.sqrt((t * t).sum())
        if tn < 1e-9:
            continue
        num = fftconvolve(image, t[::-1, ::-1], mode='valid')
        s = np.cumsum(np.cumsum(np.pad(image, ((1, 0), (1, 0))), 0), 1)
        s2 = np.cumsum(np.cumsum(np.pad(image * image, ((1, 0), (1, 0))), 0), 1)
        win = s[h:, w:] - s[:-h, w:] - s[h:, :-w] + s[:-h, :-w]
        win2 = s2[h:, w:] - s2[:-h, w:] - s2[h:, :-w] + s2[:-h, :-w]
        var = np.maximum(win2 - win * win / (h * w), 1e-9)
        score = num / (np.sqrt(var) * tn)
        total = score if total is None else total + score
    y, x = np.unravel_index(np.argmax(total), total.shape)
    return int(x), int(y), float(total[y, x]) / 4


def difference(a, b):
    """Mean difference of two RGBA pictures of one size, 0 to 1."""
    import numpy as np
    return float(np.abs(on_grey(a) - on_grey(b)).mean())


def make_pictures(kenney, target, work):
    from PIL import Image
    os.makedirs(target, exist_ok=True)
    sheets = {}
    lines = []
    for name, pack, path in PICTURES:
        sprite = Image.open(os.path.join(kenney, pack, path)).convert('RGBA')
        base = 1.0
        big = SCALE * (EXTENSION_SCALE if pack == EXTENSION else 1)
        key = (pack, base, big)
        if key not in sheets:
            svg = os.path.join(kenney, pack, SHEETS[pack])
            sheets[key] = (render_sheet(svg, base, work), render_sheet(svg, big, work))
        small_sheet, big_sheet = sheets[key]
        x, y, score = find(small_sheet, sprite)
        if score < 0.9:
            # not on the vector sheet (Redux's damage cracks): the PNG made
            # larger, as smoothly as it goes
            cut = sprite.resize((round(sprite.width * big), round(sprite.height * big)), Image.LANCZOS)
            cut.save(os.path.join(target, name + '.png'), optimize=True)
            lines.append('%s\t%s.png\t%d\t%d' % (name, name, sprite.width, sprite.height))
            ENLARGED.add(name)
            print('  %-14s %-48s %dx%d -> %dx%d (not on the sheet: the PNG enlarged)' % (
                name, path, sprite.width, sprite.height, cut.width, cut.height))
            continue
        # the same place, with the PNG's own margins, so that the picture
        # is the PNG's size times big
        cut = big_sheet.crop((round(x * big), round(y * big),
                              round((x + sprite.width) * big), round((y + sprite.height) * big)))
        again = cut.resize(sprite.size, Image.LANCZOS)
        diff = difference(again, sprite)
        # a part of a neighbour on the sheet, inside the PNG's box but not
        # in the PNG: something drawn where the PNG is clear
        import numpy as np
        stray = (np.asarray(again.getchannel('A'), dtype=np.float64)
                 - np.asarray(sprite.getchannel('A'), dtype=np.float64)) / 255.0
        if stray.max() > 0.6:
            raise SystemExit('%s drawn again has something the PNG %s does not, at %s' % (
                name, path, np.unravel_index(np.argmax(stray), stray.shape)))
        if diff > 0.06:
            raise SystemExit('%s drawn again does not look like %s (difference %.3f)' % (name, path, diff))
        if name in FLIPPED:
            cut = cut.transpose(Image.FLIP_TOP_BOTTOM)
        cut.save(os.path.join(target, name + '.png'), optimize=True)
        lines.append('%s\t%s.png\t%d\t%d' % (name, name, sprite.width, sprite.height))
        print('  %-14s %-48s %dx%d -> %dx%d (match %.3f, difference %.3f)' % (
            name, path, sprite.width, sprite.height, cut.width, cut.height, score, diff))
    for name, pack, path in COPIED:
        source = os.path.join(kenney, pack, path)
        shutil.copyfile(source, os.path.join(target, name + '.png'))
        w, h = Image.open(source).size
        lines.append('%s\t%s.png\t%d\t%d' % (name, name, w, h))
    lines += make_logos(kenney, target)
    with open(os.path.join(target, 'art.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('# name<TAB>file<TAB>width<TAB>height: the size the game draws it at, one pixel to a point\n')
        f.write('\n'.join(lines) + '\n')


def draw_logo(font_file, word, points, colour):
    """word in the font, points high as the font would draw it, LOGO_SCALE
    times; each V a V. Returns the picture and its size in points."""
    import math
    from PIL import Image, ImageDraw, ImageFont
    big = LOGO_SCALE * 4
    font = ImageFont.truetype(font_file, points * big)
    left, top, right, bottom = font.getbbox('N')
    advance = font.getlength('N')
    width, height = right - left, bottom - top
    # (the font's letters are squares, their strokes a fifth as wide)
    stroke = width / 5.0
    pad = points * big * 0.04
    size = (math.ceil((advance * (len(word) - 1) + width + 2 * pad) / big),
            math.ceil((height + 2 * pad) / big))
    mask = Image.new('L', (size[0] * big, size[1] * big), 0)
    draw = ImageDraw.Draw(mask)
    for i, letter in enumerate(word):
        x = pad + i * advance
        if letter != 'V':
            draw.text((x - left, pad - top), letter, font=font, fill=255)
            continue
        # a stroke from each top corner to the middle of the bottom, as
        # wide across as the font's straight strokes
        across = stroke / math.cos(math.atan2((width - stroke) / 2, height))
        middle, y0, y1 = x + width / 2, pad, pad + height
        inner = y0 + height * (width / 2 - across) / (width / 2 - across / 2)
        draw.polygon([(x, y0), (x + across, y0), (middle, inner), (x + width - across, y0),
                      (x + width, y0), (middle + across / 2, y1), (middle - across / 2, y1)], fill=255)
    mask = mask.resize((size[0] * LOGO_SCALE, size[1] * LOGO_SCALE), Image.LANCZOS)
    picture = Image.new('RGBA', mask.size, colour + (255,))
    picture.putalpha(mask)
    return picture, size


def make_logos(kenney, target):
    """The LOGOS, their lines for art.txt"""
    name, pack, path = FONTS[0]
    lines = []
    for name, word, points, colour in LOGOS:
        picture, size = draw_logo(os.path.join(kenney, pack, path), word, points, colour)
        picture.save(os.path.join(target, name + '.png'), optimize=True)
        lines.append('%s\t%s.png\t%d\t%d' % (name, name, size[0], size[1]))
        print('  %-14s %-48s %dx%d' % (name, '"%s" in %s' % (word, path), picture.width, picture.height))
    return lines


def make_sounds(kenney, target):
    os.makedirs(target, exist_ok=True)
    for name, pack, path, keep in SOUNDS:
        source = os.path.join(kenney, pack, path)
        filters = ['silenceremove=stop_periods=-1:stop_duration=0.05:stop_threshold=-55dB']
        if keep:
            filters.append('atrim=0:%s' % keep)
            filters.append('afade=t=out:st=%.3f:d=%.3f' % (keep * 0.6, keep * 0.4))
        out = os.path.join(target, name + '.wav')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', source, '-af', ','.join(filters),
                        '-ac', '1', '-ar', '22050', '-sample_fmt', 's16', '-map_metadata', '-1',
                        '-fflags', '+bitexact', '-flags:a', '+bitexact', out], check=True)
        print('  %-10s %-45s %d bytes' % (name, path, os.path.getsize(out)))


def make_fonts(kenney, target):
    os.makedirs(target, exist_ok=True)
    for name, pack, path in FONTS:
        shutil.copyfile(os.path.join(kenney, pack, path), os.path.join(target, name))


def make_licenses(kenney, target):
    os.makedirs(target, exist_ok=True)
    for pack, name in LICENSES.items():
        shutil.copyfile(os.path.join(kenney, pack, name), os.path.join(target, pack + '.txt'))


def sources_md():
    rows = ['| File here | Kenney pack | File in the pack | Made by |', '| --- | --- | --- | --- |']
    for name, pack, path in PICTURES:
        big = SCALE * (EXTENSION_SCALE if pack == EXTENSION else 1)
        if name in ENLARGED:
            how = 'the PNG enlarged %gx (it is not on the vector sheet)' % big
        else:
            how = 'drawn again at %gx from `%s`' % (big, SHEETS[pack])
        if name in FLIPPED:
            how += ', upside down'
        rows.append('| `art/%s.png` | %s | `%s` | %s |' % (name, PACK_NAMES[pack], path, how))
    for name, pack, path in COPIED:
        rows.append('| `art/%s.png` | %s | `%s` | copied |' % (name, PACK_NAMES[pack], path))
    for name, word, points, colour in LOGOS:
        rows.append('| `art/%s.png` | %s | `%s` | "%s" drawn in the font at %gx, its V drawn as a V |' % (
            name, PACK_NAMES[FONTS[0][1]], FONTS[0][2], word, LOGO_SCALE))
    for name, pack, path, keep in SOUNDS:
        rows.append('| `sounds/%s.wav` | %s | `%s` | WAV, mono 22050 Hz%s |' % (
            name, PACK_NAMES[pack], path, ', cut to %g s' % keep if keep else ''))
    for name, pack, path in FONTS:
        rows.append('| `fonts/%s` | %s | `%s` | copied |' % (name, PACK_NAMES[pack], path))
    return rows


def write_sources(target):
    text = ['# Nova Rescue: where its pictures, sounds and font come from', '',
            'Every file in `art/`, `sounds/` and `fonts/` is Kenney\'s (https://kenney.nl),',
            'CC0 1.0 (public domain); each pack\'s own licence is in `licenses/`.',
            '`make_assets.py` made them from the packs, as the last column says;',
            'the pictures are Kenney\'s own vector sheets drawn larger, for screens',
            'of two or three pixels to a point.', ''] + sources_md()
    with open(os.path.join(target, 'SOURCES.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(text) + '\n')


def make_all(kenney, target, work):
    print('Pictures:')
    make_pictures(kenney, os.path.join(target, 'art'), work)
    print('Sounds:')
    make_sounds(kenney, os.path.join(target, 'sounds'))
    make_fonts(kenney, os.path.join(target, 'fonts'))
    make_licenses(kenney, os.path.join(target, 'licenses'))
    write_sources(target)


def compare(made, committed):
    from PIL import Image
    problems = []
    for root, dirs, names in os.walk(made):
        for name in names:
            rel = os.path.relpath(os.path.join(root, name), made)
            mine = os.path.join(committed, rel)
            if not os.path.isfile(mine):
                problems.append('%s is not committed' % rel)
            elif name.endswith('.png'):
                a, b = Image.open(os.path.join(root, name)).convert('RGBA'), Image.open(mine).convert('RGBA')
                if a.size != b.size or difference(a, b) > 0.01:
                    problems.append('%s differs' % rel)
            else:
                # (a licence with CRLF line endings is LF in git: text=auto)
                with open(os.path.join(root, name), 'rb') as f1, open(mine, 'rb') as f2:
                    first, second = f1.read(), f2.read()
                if name.endswith('.txt'):
                    first, second = first.replace(b'\r\n', b'\n'), second.replace(b'\r\n', b'\n')
                if first != second:
                    problems.append('%s differs' % rel)
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--kenney', required=True, help="the folder of Kenney's packs")
    ap.add_argument('--check', action='store_true', help='compare with the committed files')
    args = ap.parse_args(argv)
    work = tempfile.mkdtemp(prefix='nova-rescue-assets-')
    try:
        if args.check:
            made = os.path.join(work, 'made')
            make_all(args.kenney, made, work)
            problems = compare(made, HERE)
            for p in problems:
                print('  ' + p)
            print('ASSETS DIFFER' if problems else 'ASSETS OK')
            return 1 if problems else 0
        make_all(args.kenney, HERE, work)
        print('ASSETS MADE')
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
