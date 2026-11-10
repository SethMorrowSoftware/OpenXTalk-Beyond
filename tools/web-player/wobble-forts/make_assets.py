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

"""Make Wobble Forts' pictures, sounds and font from Kenney's packs.

  python3 tools/web-player/wobble-forts/make_assets.py --kenney DIR [--check]

DIR holds Kenney's packs as they come (CC0, https://kenney.nl), unzipped
into folders of these names:

  physicspack              Physics Assets
  gameicons                Game Icons
  particlePack_1.1         Particle Pack
  kenney_fontpackage       Kenney Fonts
  kenney_impactsounds      Impact Sounds
  kenney_interfacesounds   Interface Sounds
  kenney_digitalaudio      Digital Audio
  kenney_musicjingles      Music Jingles

The committed results are in art/, sounds/ and fonts/ beside this script,
with each pack's licence in licenses/ and SOURCES.md, which names the file
of the pack that each one comes from. Nothing here runs in CI: the game's
builder (tools/web-player/wobble-forts.livecodescript) reads the committed
files. This script is how they were made, so that they can be made again.

Pictures. The blocks, the aliens, the stars and the scenery are Physics
Assets'. A pack's PNGs are drawn for a screen of one pixel to a point, and
a phone has two or three; the game draws its world a little smaller than
that, so each picture is drawn again at SCALE times from the pack's own
vector sheets: a sheet is rendered by Chromium (Playwright) at the pack's
size and at SCALE times it, the PNG is found on the first by normalized
cross-correlation (numpy and scipy), and the same place is cut out of the
second. The result must look like the PNG when made small again, or the
script stops. The blocks come in three looks (whole, chipped and cracked),
which the pack numbers in no order a name says: a block's PNG is found by
its size and its shape (a solid rectangle, a ring, a triangle...), and the
three solid rectangles of a size, in the pack's order, are the three looks.

The backdrops are the pack's 1024 x 1024 PNGs, two side by side and made
smaller (they are soft gradients and hills; they fill the window behind
the world). The icons are Game Icons' white PNGs at 2x; the puffs and
sparkles Particle Pack's, made smaller.

art.txt lists each picture: its name in the game, its file, and the size
of the pack's PNG, which is its size in the game's world (a block is 70
units across, a metre of the physics): the game draws it smaller or larger
from there, never from the number of pixels in the file.

The title is drawn here from Kenney Blocks, in two colours with a dark rim
and a shadow (LOGOS).

Sounds. Kenney's are Ogg Vorbis, which Safari on older iPhones cannot
decode. Each is made a mono 22050 Hz 16-bit WAV with ffmpeg, its silence
at the end cut off, and the longer ones faded out.

--check makes everything in a temporary folder and compares it with the
committed files (the pictures by their pixels, within a small tolerance,
as another Chromium may draw an edge a little differently).
"""

import argparse
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

SCALE = 2
PHYSICS = 'physicspack'
ICONS = 'gameicons'
PARTICLES = 'particlePack_1.1'
FONTPACK = 'kenney_fontpackage'
IMPACT = 'kenney_impactsounds'
INTERFACE = 'kenney_interfacesounds'
DIGITAL = 'kenney_digitalaudio'
JINGLES = 'kenney_musicjingles'

# The materials of the blocks: (name in the game, folder of the pack, file
# prefix, vector sheet)
MATERIALS = [
    ('wood', 'Wood elements', 'elementWood', 'Vector/vector_materialWood.svg'),
    ('glass', 'Glass elements', 'elementGlass', 'Vector/vector_materialGlass.svg'),
    ('stone', 'Stone elements', 'elementStone', 'Vector/vector_materialStone.svg'),
    ('metal', 'Metal elements', 'elementMetal', 'Vector/vector_materialMetal.svg'),
    ('tnt', 'Explosive elements', 'elementExplosive', 'Vector/vector_materialExplosive.svg'),
]
# The block shapes: (name, width, height). A block is <material>-<shape>-<look>
SHAPES = [('cube', 70, 70), ('plank', 140, 70), ('beam', 220, 70), ('post', 70, 140),
          ('pillar', 70, 220), ('slab', 140, 140)]
# The explosive crates come in two shapes only
TNT_SHAPES = ['cube', 'plank']
LOOKS = ['whole', 'chipped', 'cracked']
# Pictures named here: (name in the game, folder in the pack, file, sheet)
OTHERS = 'Vector/vector_others.svg'
NAMED = [
    ('bloop-yellow', 'PNG/Aliens', 'alienYellow_round.png', OTHERS),
    ('bloop-blue', 'PNG/Aliens', 'alienBlue_round.png', OTHERS),
    ('bloop-pink', 'PNG/Aliens', 'alienPink_round.png', OTHERS),
    ('bloop-green', 'PNG/Aliens', 'alienGreen_round.png', OTHERS),
    ('bloop-beige', 'PNG/Aliens', 'alienBeige_round.png', OTHERS),
    ('grump-green', 'PNG/Aliens', 'alienGreen_square.png', OTHERS),
    ('grump-blue', 'PNG/Aliens', 'alienBlue_square.png', OTHERS),
    ('grump-pink', 'PNG/Aliens', 'alienPink_square.png', OTHERS),
    ('grump-beige', 'PNG/Aliens', 'alienBeige_square.png', OTHERS),
    ('boss-green', 'PNG/Aliens', 'alienGreen_suit.png', OTHERS),
    ('boss-blue', 'PNG/Aliens', 'alienBlue_suit.png', OTHERS),
    ('boss-pink', 'PNG/Aliens', 'alienPink_suit.png', OTHERS),
    ('boss-yellow', 'PNG/Aliens', 'alienYellow_suit.png', OTHERS),
    ('star-gold', 'PNG/Other', 'starGold.png', OTHERS),
    ('star-silver', 'PNG/Other', 'starSilver.png', OTHERS),
    ('star-bronze', 'PNG/Other', 'starBronze.png', OTHERS),
    ('coin-gold', 'PNG/Other', 'coinGold.png', OTHERS),
    ('flag-red', 'PNG/Other', 'flagRed.png', OTHERS),
    ('flag-yellow', 'PNG/Other', 'flagYellow.png', OTHERS),
    ('flag-green', 'PNG/Other', 'flagGreen.png', OTHERS),
    ('bush', 'PNG/Other', 'bush.png', OTHERS),
    ('cactus', 'PNG/Other', 'cactus.png', OTHERS),
    ('rock', 'PNG/Other', 'rock.png', OTHERS),
    ('ground-grass', 'PNG/Other', 'grass.png', OTHERS),
    ('ground-sand', 'PNG/Other', 'sand.png', OTHERS),
    ('ground-dirt', 'PNG/Other', 'dirt.png', OTHERS),
    ('debris-wood1', 'PNG/Debris', 'debrisWood_1.png', 'Vector/vector_materialWood.svg'),
    ('debris-wood2', 'PNG/Debris', 'debrisWood_2.png', 'Vector/vector_materialWood.svg'),
    ('debris-wood3', 'PNG/Debris', 'debrisWood_3.png', 'Vector/vector_materialWood.svg'),
    ('debris-glass1', 'PNG/Debris', 'debrisGlass_1.png', 'Vector/vector_materialGlass.svg'),
    ('debris-glass2', 'PNG/Debris', 'debrisGlass_2.png', 'Vector/vector_materialGlass.svg'),
    ('debris-glass3', 'PNG/Debris', 'debrisGlass_3.png', 'Vector/vector_materialGlass.svg'),
    ('debris-stone1', 'PNG/Debris', 'debrisStone_1.png', 'Vector/vector_materialStone.svg'),
    ('debris-stone2', 'PNG/Debris', 'debrisStone_2.png', 'Vector/vector_materialStone.svg'),
    ('debris-stone3', 'PNG/Debris', 'debrisStone_3.png', 'Vector/vector_materialStone.svg'),
    ('debris-metal1', 'PNG/Metal elements', 'elementMetal046.png', 'Vector/vector_materialMetal.svg'),
    ('debris-metal2', 'PNG/Metal elements', 'elementMetal047.png', 'Vector/vector_materialMetal.svg'),
    ('debris-metal3', 'PNG/Metal elements', 'elementMetal048.png', 'Vector/vector_materialMetal.svg'),
    ('debris-tnt1', 'PNG/Explosive elements', 'elementExplosive046.png',
     'Vector/vector_materialExplosive.svg'),
    ('debris-tnt2', 'PNG/Explosive elements', 'elementExplosive047.png',
     'Vector/vector_materialExplosive.svg'),
    ('debris-tnt3', 'PNG/Explosive elements', 'elementExplosive048.png',
     'Vector/vector_materialExplosive.svg'),
]
# The backdrops: (name, file in the pack), each two of the PNG side by
# side, BACKDROP_HEIGHT pixels high
BACKDROPS = [('sky-meadow', 'PNG/Backgrounds/colored_grass.png'),
             ('sky-dunes', 'PNG/Backgrounds/colored_desert.png'),
             ('sky-shroom', 'PNG/Backgrounds/colored_shroom.png')]
BACKDROP_HEIGHT = 720
# Game Icons' white PNGs at 2x (100 pixels, drawn 50 points)
ICON_FILES = ['pause', 'return', 'home', 'menuGrid', 'next', 'audioOn', 'audioOff', 'locked',
              'star', 'larger', 'smaller', 'question', 'gear', 'right', 'left']
# Particle Pack's puffs and sparkles, made PARTICLE_SIZE pixels square
PARTICLES_USED = [('puff', 'smoke_04.png'), ('puff2', 'smoke_07.png'), ('sparkle', 'star_06.png'),
                  ('ring', 'circle_05.png'), ('flash', 'light_01.png')]
PARTICLE_SIZE = 160

# Pictures drawn here from Kenney's fonts: (name, word, font file, points,
# colour). Drawn LOGO_SCALE times, from LOGO_SCALE * 4 times made smaller
LOGO_SCALE = 3
LOGOS = [('logo-wobble', 'WOBBLE', 'Fonts/Kenney Blocks.ttf', 54, (0xFF, 0xCC, 0x2E)),
         ('logo-forts', 'FORTS', 'Fonts/Kenney Blocks.ttf', 54, (0xFF, 0xFF, 0xFF))]
LOGO_RIM = (0x3A, 0x22, 0x10)

# The sounds: (name in the game, pack, file, seconds kept at most or None)
SOUNDS = [
    ('click', INTERFACE, 'Audio/click_002.ogg', None),
    ('stretch', INTERFACE, 'Audio/pluck_001.ogg', None),
    ('launch', INTERFACE, 'Audio/pluck_002.ogg', None),
    ('wood', IMPACT, 'Audio/impactWood_medium_001.ogg', 0.4),
    ('wood-break', IMPACT, 'Audio/impactWood_heavy_002.ogg', 0.6),
    ('glass', IMPACT, 'Audio/impactGlass_light_002.ogg', 0.4),
    ('glass-break', IMPACT, 'Audio/impactGlass_heavy_000.ogg', 0.8),
    ('stone', IMPACT, 'Audio/impactMining_001.ogg', 0.4),
    ('stone-break', IMPACT, 'Audio/impactMining_004.ogg', 0.7),
    ('metal', IMPACT, 'Audio/impactMetal_medium_002.ogg', 0.5),
    ('thud', IMPACT, 'Audio/impactSoft_heavy_001.ogg', 0.4),
    ('grump', IMPACT, 'Audio/impactPunch_medium_001.ogg', 0.4),
    ('pop', DIGITAL, 'Audio/pepSound2.ogg', None),
    ('boom', DIGITAL, 'Audio/spaceTrash1.ogg', 1.0),
    ('dash', DIGITAL, 'Audio/phaserUp3.ogg', None),
    ('split', DIGITAL, 'Audio/zapTwoTone2.ogg', None),
    ('slam', DIGITAL, 'Audio/lowDown.ogg', None),
    ('star1', INTERFACE, 'Audio/confirmation_001.ogg', None),
    ('star2', INTERFACE, 'Audio/confirmation_002.ogg', None),
    ('star3', INTERFACE, 'Audio/confirmation_003.ogg', None),
    ('start', JINGLES, 'Audio/Pizzicato jingles/jingles_PIZZI04.ogg', None),
    ('clear', JINGLES, 'Audio/Pizzicato jingles/jingles_PIZZI02.ogg', None),
    ('fail', JINGLES, 'Audio/Pizzicato jingles/jingles_PIZZI14.ogg', None),
    ('unlock', JINGLES, 'Audio/Pizzicato jingles/jingles_PIZZI15.ogg', None),
]
FONTS = [('kenney_future_narrow.ttf', FONTPACK, 'Fonts/Kenney Future Narrow.ttf')]
LICENSES = {
    PHYSICS: 'license.txt', ICONS: 'license.txt', PARTICLES: 'License.txt', FONTPACK: 'License.txt',
    IMPACT: 'License.txt', INTERFACE: 'License.txt', DIGITAL: 'License.txt', JINGLES: 'License.txt',
}
PACK_NAMES = {
    PHYSICS: 'Physics Assets', ICONS: 'Game Icons', PARTICLES: 'Particle Pack',
    FONTPACK: 'Kenney Fonts', IMPACT: 'Impact Sounds', INTERFACE: 'Interface Sounds',
    DIGITAL: 'Digital Audio', JINGLES: 'Music Jingles',
}

# How each picture was made, for SOURCES.md: name -> (pack, file, how)
MADE = {}


def render_sheet(svg, scale, work):
    """The vector sheet as RGBA pixels at scale, by Chromium. Physics
    Assets' sheets say 550 x 400 but draw far outside it: the picture is
    the box of everything drawn, from the top left corner."""
    from playwright.sync_api import sync_playwright
    from PIL import Image
    out = os.path.join(work, 'sheet-%s-%s.png' % (os.path.basename(svg), scale))
    if os.path.isfile(out):
        return Image.open(out).convert('RGBA')
    with open(svg, encoding='utf-8') as f:
        text = f.read()
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={'width': 800, 'height': 600})
        page.set_content('<html><body style="margin:0">' + text + '</body></html>')
        box = page.evaluate('() => { const b = document.querySelector("svg").getBBox(); '
                            'return [b.x, b.y, b.width, b.height]; }')
        width, height = int(math.ceil(box[0] + box[2])) + 2, int(math.ceil(box[1] + box[3])) + 2
        text = re.sub(r'width="[^"]*" height="[^"]*" viewBox="[^"]*"',
                      'width="%dpx" height="%dpx" viewBox="0 0 %d %d"' % (width, height, width, height),
                      text, count=1)
        page.close()
        page = browser.new_page(viewport={'width': width, 'height': height}, device_scale_factor=scale)
        page.set_content('<html><body style="margin:0;background:transparent">' + text + '</body></html>')
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


def shape_of(img):
    """What a block PNG is: 'rect' (solid), 'ring' (a hollow rectangle or
    circle), 'ball', 'triangle' or 'other', by where it is opaque."""
    w, h = img.size
    alpha = img.getchannel('A')

    def at(x, y):
        return alpha.getpixel((min(w - 1, max(0, int(x))), min(h - 1, max(0, int(y)))))
    centre = at(w / 2, h / 2) > 60
    corners = [at(8, 8), at(w - 9, 8), at(8, h - 9), at(w - 9, h - 9)]
    if all(c > 200 for c in corners):
        return 'rect' if centre else 'ring'
    if w == h and centre and all(c < 40 for c in corners):
        return 'ball'
    if not all(c < 40 for c in corners) and not all(c > 200 for c in corners):
        return 'triangle'
    return 'other'


def block_files(kenney):
    """{(material, shape, look): (folder, file, sheet)} of the blocks."""
    from PIL import Image
    found = {}
    for material, folder, prefix, sheet in MATERIALS:
        path = os.path.join(kenney, PHYSICS, 'PNG', folder)
        names = sorted(n for n in os.listdir(path) if n.startswith(prefix) and n.endswith('.png'))
        by_size = {}
        balls = []
        for n in names:
            img = Image.open(os.path.join(path, n)).convert('RGBA')
            kind = shape_of(img)
            if kind == 'rect':
                by_size.setdefault(img.size, []).append(n)
            elif kind == 'ball':
                balls.append(n)
        shapes = SHAPES if material != 'tnt' else [s for s in SHAPES if s[0] in TNT_SHAPES]
        for shape, w, h in shapes:
            files = by_size.get((w, h), [])
            if len(files) != 3:
                raise SystemExit('%s: %d solid %dx%d blocks, not 3: %s' % (material, len(files), w, h, files))
            for look, n in zip(LOOKS, files):
                found[(material, shape, look)] = ('PNG/' + folder, n, sheet)
        if material in ('wood', 'stone'):
            if len(balls) != 3:
                raise SystemExit('%s: %d balls, not 3: %s' % (material, len(balls), balls))
            for look, n in zip(LOOKS, balls):
                found[(material, 'ball', look)] = ('PNG/' + folder, n, sheet)
    return found


def picture_list(kenney):
    """[(name, folder, file, sheet)] of every picture drawn from a sheet."""
    items = []
    blocks = block_files(kenney)
    for (material, shape, look) in sorted(blocks, key=lambda k: (
            [m[0] for m in MATERIALS].index(k[0]), k[1], LOOKS.index(k[2]))):
        folder, n, sheet = blocks[(material, shape, look)]
        items.append(('%s-%s-%s' % (material, shape, look), folder, n, sheet))
    items += NAMED
    return items


def make_pictures(kenney, target, work):
    from PIL import Image
    import numpy as np
    os.makedirs(target, exist_ok=True)
    sheets = {}
    lines = []
    for name, folder, path, sheet in picture_list(kenney):
        sprite = Image.open(os.path.join(kenney, PHYSICS, folder, path)).convert('RGBA')
        if sheet not in sheets:
            svg = os.path.join(kenney, PHYSICS, sheet)
            sheets[sheet] = (render_sheet(svg, 1, work), render_sheet(svg, SCALE, work))
        small_sheet, big_sheet = sheets[sheet]
        x, y, score = find(small_sheet, sprite)
        cut = big_sheet.crop((x * SCALE, y * SCALE, (x + sprite.width) * SCALE, (y + sprite.height) * SCALE))
        again = cut.resize(sprite.size, Image.LANCZOS)
        diff = difference(again, sprite)
        stray = (np.asarray(again.getchannel('A'), dtype=np.float64)
                 - np.asarray(sprite.getchannel('A'), dtype=np.float64)) / 255.0
        how = 'drawn again at %dx from `%s`' % (SCALE, sheet)
        if score < 0.9 or diff > 0.06 or stray.max() > 0.6:
            # not on the sheet as the PNG is (or a neighbour reaches into
            # its box): the PNG made larger, as smoothly as it goes
            cut = sprite.resize((sprite.width * SCALE, sprite.height * SCALE), Image.LANCZOS)
            how = 'the PNG enlarged %dx (not on the vector sheet as it is)' % SCALE
            print('  %-22s %-28s %dx%d -> %dx%d (enlarged: match %.3f, difference %.3f)' % (
                name, path, sprite.width, sprite.height, cut.width, cut.height, score, diff))
        else:
            print('  %-22s %-28s %dx%d -> %dx%d (match %.3f, difference %.3f)' % (
                name, path, sprite.width, sprite.height, cut.width, cut.height, score, diff))
        cut.save(os.path.join(target, name + '.png'), optimize=True)
        lines.append('%s\t%s.png\t%d\t%d' % (name, name, sprite.width, sprite.height))
        MADE[name] = (PHYSICS, folder + '/' + path, how)
    for name, path in BACKDROPS:
        tile = Image.open(os.path.join(kenney, PHYSICS, path)).convert('RGB')
        wide = Image.new('RGB', (tile.width * 2, tile.height))
        wide.paste(tile, (0, 0))
        wide.paste(tile, (tile.width, 0))
        k = BACKDROP_HEIGHT / tile.height
        wide = wide.resize((round(wide.width * k), BACKDROP_HEIGHT), Image.LANCZOS)
        wide.save(os.path.join(target, name + '.png'), optimize=True)
        lines.append('%s\t%s.png\t%d\t%d' % (name, name, wide.width, wide.height))
        MADE[name] = (PHYSICS, path, 'two side by side, made %d pixels high' % BACKDROP_HEIGHT)
    for name in ICON_FILES:
        path = 'PNG/White/2x/%s.png' % name
        icon = Image.open(os.path.join(kenney, ICONS, path)).convert('RGBA')
        out = 'icon-' + re.sub(r'([A-Z])', lambda m: '-' + m.group(1).lower(), name)
        icon.save(os.path.join(target, out + '.png'), optimize=True)
        lines.append('%s\t%s.png\t%d\t%d' % (out, out, icon.width // 2, icon.height // 2))
        MADE[out] = (ICONS, path, 'copied (drawn at half its pixels)')
    for name, file in PARTICLES_USED:
        path = 'PNG (Transparent)/' + file
        img = Image.open(os.path.join(kenney, PARTICLES, path)).convert('RGBA')
        img = img.resize((PARTICLE_SIZE, PARTICLE_SIZE), Image.LANCZOS)
        img.save(os.path.join(target, name + '.png'), optimize=True)
        lines.append('%s\t%s.png\t%d\t%d' % (name, name, PARTICLE_SIZE // 2, PARTICLE_SIZE // 2))
        MADE[name] = (PARTICLES, path, 'made %d pixels square' % PARTICLE_SIZE)
    lines += make_logos(kenney, target)
    with open(os.path.join(target, 'art.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('# name<TAB>file<TAB>width<TAB>height: its size in the world (a block is 70 across), '
                'or on the screen in points\n')
        f.write('\n'.join(lines) + '\n')


def draw_logo(font_file, word, points, colour):
    """word in the font, points high, LOGO_SCALE times, with a dark rim and
    a shadow below it. Returns the picture and its size in points."""
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    big = LOGO_SCALE * 4
    font = ImageFont.truetype(font_file, points * big)
    left, top, right, bottom = font.getbbox(word)
    rim = max(2, round(points * big * 0.07))
    drop = round(points * big * 0.08)
    pad = rim + drop + 4
    width, height = right - left + 2 * pad, bottom - top + 2 * pad
    size = (math.ceil(width / big), math.ceil(height / big))
    canvas = Image.new('RGBA', (size[0] * big, size[1] * big), (0, 0, 0, 0))
    mask = Image.new('L', canvas.size, 0)
    ImageDraw.Draw(mask).text((pad - left, pad - top), word, font=font, fill=255)
    outer = mask.filter(ImageFilter.MaxFilter(2 * (rim // 2) + 1))
    for _ in range(2):
        outer = outer.filter(ImageFilter.MaxFilter(2 * (rim // 4) + 1))
    shadow = Image.new('L', canvas.size, 0)
    shadow.paste(outer, (0, drop))
    canvas.paste(Image.new('RGBA', canvas.size, LOGO_RIM + (110,)), (0, 0), shadow)
    canvas.paste(Image.new('RGBA', canvas.size, LOGO_RIM + (255,)), (0, 0), outer)
    canvas.paste(Image.new('RGBA', canvas.size, colour + (255,)), (0, 0), mask)
    # a light band across the top half of the letters
    shine = Image.new('L', canvas.size, 0)
    ImageDraw.Draw(shine).rectangle([0, 0, canvas.width, pad + (bottom - top) * 0.42], fill=60)
    from PIL import ImageChops
    shine = ImageChops.multiply(shine, mask)
    canvas.paste(Image.new('RGBA', canvas.size, (255, 255, 255, 255)), (0, 0), shine)
    picture = canvas.resize((size[0] * LOGO_SCALE, size[1] * LOGO_SCALE), Image.LANCZOS)
    return picture, size


def make_logos(kenney, target):
    """The LOGOS, their lines for art.txt"""
    lines = []
    for name, word, font, points, colour in LOGOS:
        picture, size = draw_logo(os.path.join(kenney, FONTPACK, font), word, points, colour)
        picture.save(os.path.join(target, name + '.png'), optimize=True)
        lines.append('%s\t%s.png\t%d\t%d' % (name, name, size[0], size[1]))
        MADE[name] = (FONTPACK, font, '"%s" drawn in the font at %dx, with a rim and a shadow' % (
            word, LOGO_SCALE))
        print('  %-22s %-28s %dx%d' % (name, '"%s"' % word, picture.width, picture.height))
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
        print('  %-12s %-45s %d bytes' % (name, path, os.path.getsize(out)))


def make_fonts(kenney, target):
    os.makedirs(target, exist_ok=True)
    for name, pack, path in FONTS:
        shutil.copyfile(os.path.join(kenney, pack, path), os.path.join(target, name))


def make_licenses(kenney, target):
    os.makedirs(target, exist_ok=True)
    for pack, name in LICENSES.items():
        shutil.copyfile(os.path.join(kenney, pack, name), os.path.join(target, pack + '.txt'))


def write_sources(target):
    rows = ['| File here | Kenney pack | File in the pack | Made by |', '| --- | --- | --- | --- |']
    for name in sorted(MADE):
        pack, path, how = MADE[name]
        rows.append('| `art/%s.png` | %s | `%s` | %s |' % (name, PACK_NAMES[pack], path, how))
    for name, pack, path, keep in SOUNDS:
        rows.append('| `sounds/%s.wav` | %s | `%s` | WAV, mono 22050 Hz%s |' % (
            name, PACK_NAMES[pack], path, ', cut to %g s' % keep if keep else ''))
    for name, pack, path in FONTS:
        rows.append('| `fonts/%s` | %s | `%s` | copied |' % (name, PACK_NAMES[pack], path))
    text = ['# Wobble Forts: where its pictures, sounds and font come from', '',
            'Every file in `art/`, `sounds/` and `fonts/` is Kenney\'s (https://kenney.nl),',
            'CC0 1.0 (public domain); each pack\'s own licence is in `licenses/`.',
            '`make_assets.py` made them from the packs, as the last column says;',
            'the blocks, aliens and scenery are Kenney\'s own vector sheets drawn',
            'larger, for screens of two or three pixels to a point.', ''] + rows
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
                if name.endswith('.txt') or name.endswith('.md'):
                    first, second = first.replace(b'\r\n', b'\n'), second.replace(b'\r\n', b'\n')
                if first != second:
                    problems.append('%s differs' % rel)
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--kenney', required=True, help="the folder of Kenney's packs")
    ap.add_argument('--check', action='store_true', help='compare with the committed files')
    args = ap.parse_args(argv)
    work = tempfile.mkdtemp(prefix='wobble-forts-assets-')
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
