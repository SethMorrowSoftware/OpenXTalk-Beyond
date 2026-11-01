# Needs fontTools and DejaVuSans-Bold.ttf in font/. The OXT-Beyond logo (Installer/oxt-beyond/branding/svg/icon.svg) for SVG Lab.
# The compiler has no text element, so its words become paths, from the same
# DejaVu Sans Bold; the rest uses a style sheet, awkward ids, opacity, clips
# and an off-centre gradient, so the logo shows what the lab shows.
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

font = TTFont('font/DejaVuSans-Bold.ttf')
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
units = font['head'].unitsPerEm


def word(text, cx, baseline, size, sx=0.9):
    """One path for each letter of text, centred on cx, as text-anchor middle."""
    s = size / units
    total = sum(font['hmtx'][cmap[ord(c)]][0] for c in text) * s * sx
    x = cx - total / 2
    out = []
    for c in text:
        name = cmap[ord(c)]
        pen = SVGPathPen(glyphs, ntos=lambda v: f'{v:.1f}'.rstrip('0').rstrip('.'))
        glyphs[name].draw(TransformPen(pen, (s * sx, 0, 0, -s, x, baseline)))
        out.append(pen.getCommands())
        x += font['hmtx'][name][0] * s * sx
    return out


o = []
a = o.append
a('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">')
a('''<style>
.tile { fill: url(#tile-fade); }
.rim { fill: none; stroke: #FF7700; stroke-width: 18; }
.bolt { fill: url(#bolt.gold); stroke: #7A5A00; stroke-width: 3; stroke-linejoin: round; }
.outline { fill: #000000; stroke: #000000; stroke-width: 22; stroke-linejoin: round; }
.oxt { fill: url(#oxt-flame); }
.tick { stroke: #8A9099; stroke-width: 3; }
.beyond { fill: #E9ECEF; }
</style>''')
a('''<defs>
<linearGradient id="tile-fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2B2F36"/><stop offset="1" stop-color="#15171A"/></linearGradient>
<linearGradient id="bolt.gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF08A"/><stop offset="1" stop-color="#FFC92E"/></linearGradient>
<linearGradient id="oxt-flame" gradientUnits="userSpaceOnUse" x1="0" y1="400" x2="0" y2="660"><stop offset="0" stop-color="#FFA640"/><stop offset="1" stop-color="#FF7700"/></linearGradient>
<radialGradient id="glow-1" cx="0.68" cy="0.3" r="0.6"><stop offset="0" stop-color="#FFB347"/><stop offset="1" stop-color="#FF7700" stop-opacity="0"/></radialGradient>
<clipPath id="tile.edge"><rect x="64" y="64" width="896" height="896" rx="200"/></clipPath>
</defs>''')
a('<rect class="tile" x="64" y="64" width="896" height="896" rx="200"/>')
a('<g clip-path="url(#tile.edge)">')
a('<rect x="64" y="64" width="896" height="896" fill="url(#glow-1)" opacity="0.28"/>')
a('<ellipse cx="400" cy="80" rx="520" ry="210" fill="#FFFFFF" opacity="0.05"/>')
a('</g>')
a('<rect class="rim" fill="none" stroke="#FF7700" stroke-width="18" x="64" y="64" width="896" height="896" rx="200"/>')
a('<g transform="translate(600,150) scale(4.2)"><path class="bolt" fill="#FFE14D" stroke="#7A5A00" stroke-width="3" d="M30 0 L0 56 H22 L8 100 L52 36 H28 L44 0 Z"/></g>')
for d in word('OXT', 512, 640, 330):
    a(f'<path class="outline" fill="#000000" stroke="#000000" stroke-width="22" stroke-linejoin="round" d="{d}"/>')
for d in word('OXT', 512, 640, 330):
    a(f'<path class="oxt" fill="#FF7700" d="{d}"/>')
a('<path class="tick" stroke="#8A9099" stroke-width="3" d="M220 740 H804"/>')
for x in range(228, 787, 18):
    a(f'<path class="tick" stroke="#8A9099" stroke-width="3" d="M{x} 733 L{x+4} 747"/>')
for d in word('BEYOND', 512, 860, 120):
    a(f'<path class="beyond" fill="#E9ECEF" d="{d}"/>')
a('</svg>')
s = '\n'.join(o) + '\n'
open('beyond-logo.svg', 'w', newline='\n').write(s)
print(len(s), s.count('<path'))
