# Needs fontTools and DejaVuSans-Bold.ttf in font/. The OXT-Beyond logo
# (Installer/oxt-beyond/branding/svg/icon.svg) for SVG Lab. The compiler has no
# text element, so its words become paths, from the same DejaVu Sans Bold; the
# effects use a style sheet, awkward ids, opacity, clips and gradients, with
# plain colours underneath for the old compile. beyond-logo.svg is the still;
# beyond-logo-live.svg has @TOKENS@ the stack fills in for every frame.
import math
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


def rays():
    out = []
    for i in range(14):
        a = 2 * math.pi * i / 14
        b = a + math.pi / 28
        p = f'740,300 {740+1100*math.cos(a):.0f},{300+1100*math.sin(a):.0f} {740+1100*math.cos(b):.0f},{300+1100*math.sin(b):.0f}'
        out.append(f'<polygon points="{p}" fill="#FFB347"/>')
    return ''.join(out)


def build(rot, glow, halo, shine, arcs, sparks):
    letters = word('OXT', 512, 640, 330)
    o = []
    a = o.append
    a('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">')
    a('''<style>
.tile { fill: url(#tile-fade); }
.rim { fill: none; stroke: url(#rim.fire); stroke-width: 18; }
.bolt { fill: url(#bolt.gold); stroke: #7A5A00; stroke-width: 3; stroke-linejoin: round; }
.outline { fill: #000000; stroke: #000000; stroke-width: 22; stroke-linejoin: round; }
.oxt { fill: url(#oxt-flame); }
.arc { fill: none; stroke: #BFEFFF; stroke-width: 5; stroke-linejoin: round; stroke-linecap: round; }
.tick { stroke: #8A9099; stroke-width: 3; }
.beyond { fill: #E9ECEF; }
</style>''')
    a(f'''<defs>
<linearGradient id="tile-fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2B2F36"/><stop offset="1" stop-color="#15171A"/></linearGradient>
<linearGradient id="rim.fire" gradientUnits="userSpaceOnUse" x1="64" y1="64" x2="960" y2="960"><stop offset="0" stop-color="#FFC24D"/><stop offset="0.5" stop-color="#FF7700"/><stop offset="1" stop-color="#FF3D00"/></linearGradient>
<linearGradient id="bolt.gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF9C4"/><stop offset="1" stop-color="#FFC92E"/></linearGradient>
<linearGradient id="oxt-flame" gradientUnits="userSpaceOnUse" x1="0" y1="400" x2="0" y2="660"><stop offset="0" stop-color="#FFC04D"/><stop offset="1" stop-color="#FF6A00"/></linearGradient>
<linearGradient id="shine-1" gradientUnits="userSpaceOnUse" x1="-90" y1="0" x2="90" y2="0"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="0.5" stop-color="#FFFFFF"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
<radialGradient id="glow-1" gradientUnits="userSpaceOnUse" cx="740" cy="300" r="620"><stop offset="0" stop-color="#FFB347"/><stop offset="1" stop-color="#FF7700" stop-opacity="0"/></radialGradient>
<radialGradient id="halo-1" gradientUnits="userSpaceOnUse" cx="710" cy="260" r="240"><stop offset="0" stop-color="#FFF4B0"/><stop offset="1" stop-color="#FFD24D" stop-opacity="0"/></radialGradient>
<clipPath id="tile.edge"><rect x="64" y="64" width="896" height="896" rx="200"/></clipPath>
<clipPath id="oxt.letters"><path d="{' '.join(letters)}"/></clipPath>
</defs>''')
    a('<rect class="tile" x="64" y="64" width="896" height="896" rx="200"/>')
    a('<g clip-path="url(#tile.edge)">')
    a(f'<g opacity="0.1" transform="rotate({rot} 740 300)">{rays()}</g>')
    a(f'<rect x="64" y="64" width="896" height="896" fill="url(#glow-1)" opacity="{glow}"/>')
    a('<ellipse cx="400" cy="80" rx="520" ry="210" fill="#FFFFFF" opacity="0.05"/>')
    a('</g>')
    a('<rect class="rim" fill="none" stroke="#FF7700" stroke-width="18" x="64" y="64" width="896" height="896" rx="200"/>')
    a(f'<circle cx="710" cy="260" r="240" fill="url(#halo-1)" opacity="{halo}"/>')
    a('<g transform="translate(600,150) scale(4.2)"><path class="bolt" fill="#FFE14D" stroke="#7A5A00" stroke-width="3" d="M30 0 L0 56 H22 L8 100 L52 36 H28 L44 0 Z"/></g>')
    a(arcs)
    for d in letters:
        a(f'<path class="outline" fill="#000000" stroke="#000000" stroke-width="22" stroke-linejoin="round" d="{d}"/>')
    for d in letters:
        a(f'<path class="oxt" fill="#FF7700" d="{d}"/>')
    a('<g clip-path="url(#oxt.letters)">')
    a(f'<polygon transform="translate({shine} 0)" points="-40,380 130,380 40,680 -130,680" fill="url(#shine-1)" opacity="0.8"/>')
    a('</g>')
    a('<path class="tick" stroke="#8A9099" stroke-width="3" d="M220 740 H804"/>')
    for x in range(228, 787, 18):
        a(f'<path class="tick" stroke="#8A9099" stroke-width="3" d="M{x} 733 L{x+4} 747"/>')
    for d in word('BEYOND', 512, 860, 120):
        a(f'<path class="beyond" fill="#E9ECEF" d="{d}"/>')
    a(sparks)
    a('</svg>')
    return '\n'.join(o) + '\n'


still_arcs = ('<polyline class="arc" stroke="#BFEFFF" stroke-width="5" fill="none" opacity="0.8" points="705,250 650,215 662,180 610,150 622,118"/>'
              '<polyline class="arc" stroke="#BFEFFF" stroke-width="5" fill="none" opacity="0.8" points="790,300 836,272 828,236 878,214 884,180"/>')
still_sparks = ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFF4B0" opacity="{o}"/>' for x, y, r, o in
                       ((850, 150, 7, .9), (640, 120, 5, .8), (890, 330, 6, .7), (560, 200, 4, .7), (800, 90, 4, .9), (900, 240, 3, .8), (600, 300, 3, .6)))
still = build(0, 0.34, 0.6, 620, still_arcs, still_sparks)
live = build('@RAYS@', '@GLOW@', '@HALO@', '@SHINE@', '@ARCS@', '@SPARKS@')
open('beyond-logo.svg', 'w', newline='\n').write(still)
open('beyond-logo-live.svg', 'w', newline='\n').write(live)
print(len(still), len(live))
