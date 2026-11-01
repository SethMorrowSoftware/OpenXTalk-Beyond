# original art for the public SVG Lab page, made entirely by this script
import random, math
random.seed(61)
W = H = 640
o = []
a = o.append
a(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">')
a('''<style>
.sky { fill: url(#night-sky); }
.sea { fill: url(#sea.glow); }
.far { fill: #24406b; }
.mid { fill: #1b3257; }
.near { fill: #122440; }
.wave { fill: none; stroke: #9fd8ff; stroke-width: 1.5; stroke-linecap: round; }
.white { fill: #f3f1e7; }
.red { fill: #d8432f; }
#frame-line { stroke: #f4d35e; stroke-width: 10; }
</style>''')
a('''<defs>
<linearGradient id="night-sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#090d2b"/><stop offset="0.55" stop-color="#2a2a70"/><stop offset="1" stop-color="#b0507e"/></linearGradient>
<linearGradient id="sea.glow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a4a9a"/><stop offset="1" stop-color="#071230"/></linearGradient>
<linearGradient id="aurora-1" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#29e0a8"/><stop offset="1" stop-color="#a24bff"/></linearGradient>
<linearGradient id="beam-1" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff2a8"/><stop offset="1" stop-color="#fff2a8" stop-opacity="0"/></linearGradient>
<radialGradient id="moon-1" cx="0.35" cy="0.35" r="0.75"><stop offset="0" stop-color="#fffbe6"/><stop offset="0.6" stop-color="#f6dc92"/><stop offset="1" stop-color="#c9963f"/></radialGradient>
<clipPath id="frame"><rect x="16" y="16" width="608" height="608" rx="48"/></clipPath>
<clipPath id="tower.shape"><polygon points="392,250 448,250 470,500 370,500"/></clipPath>
</defs>''')
a('<g clip-path="url(#frame)">')
a(f'<rect class="sky" width="{W}" height="{H}"/>')
for i in range(140):
    a(f'<circle cx="{random.uniform(20,620):.1f}" cy="{random.uniform(20,360):.1f}" r="{random.uniform(.7,2.4):.1f}" fill="#ffffff" opacity="{random.uniform(.3,1):.2f}"/>')
for i in range(6):
    y = 70 + i * 26
    d = f'M-20 {y} C120 {y-70-i*8} 240 {y+60} 360 {y-20} S560 {y-80} 660 {y+10} L660 {y+70} C520 {y+10} 420 {y+110} 300 {y+50} S80 {y+40} -20 {y+90} Z'
    a(f'<path d="{d}" fill="url(#aurora-1)" opacity="{.10+.03*i:.2f}"/>')
a('<circle cx="170" cy="150" r="96" fill="#f6dc92" opacity="0.14"/>')
a('<circle cx="170" cy="150" r="72" fill="#f6dc92" opacity="0.2"/>')
a('<circle cx="170" cy="150" r="52" fill="url(#moon-1)"/>')
for i in range(9):
    a(f'<circle cx="{random.uniform(135,205):.1f}" cy="{random.uniform(115,185):.1f}" r="{random.uniform(3,9):.1f}" fill="#c9963f" opacity="0.28"/>')


def ridge(base, amp, cls, step=22):
    p = [f'M-10 {base}']
    x = -10
    while x < 650:
        x += step
        p.append(f'L{x} {base-amp*abs(math.sin(x/70+base))-random.uniform(0,amp*.5):.1f}')
    p.append('L650 460 L-10 460 Z')
    a(f'<path class="{cls}" d="{" ".join(p)}"/>')


ridge(370, 70, 'far')
ridge(400, 52, 'mid')
ridge(430, 34, 'near')
for i in range(80):
    x = random.uniform(-10, 340)
    y = random.uniform(415, 462)
    h = random.uniform(18, 44)
    w = h * .42
    g = random.choice(['#0d2b33', '#0f3a38', '#14463c', '#0b2230'])
    a(f'<polygon fill="{g}" points="{x:.1f},{y-h:.1f} {x+w:.1f},{y:.1f} {x-w:.1f},{y:.1f}"/>')
a('<rect class="sea" y="455" width="640" height="185"/>')
a('<path d="M60 455 L280 455 L250 640 L90 640 Z" fill="#f6dc92" opacity="0.1"/>')
for i in range(44):
    y = random.uniform(462, 632)
    x = random.uniform(-20, 560)
    s = random.uniform(9, 20)
    q = s * .45
    a(f'<path class="wave" opacity="{random.uniform(.2,.7):.2f}" d="M{x:.1f} {y:.1f} q{s/2:.1f} {-q:.1f} {s:.1f} 0 t{s:.1f} 0 t{s:.1f} 0 t{s:.1f} 0"/>')
# rocks: long polygons, which the library writes as paths
for cx, cy, rx, ry, f in ((420, 520, 130, 44, '#1c2233'), (505, 552, 84, 30, '#141927'), (345, 548, 70, 24, '#171d2c')):
    pts = []
    for i in range(48):
        t = 2 * math.pi * i / 48
        r = random.uniform(.86, 1.05)
        pts.append(f'{cx+rx*r*math.cos(t):.1f},{cy+ry*r*min(.8,abs(math.sin(t)))*(-1 if math.sin(t)<0 else 1):.1f}')
    a(f'<polygon fill="{f}" points="{" ".join(pts)}"/>')
# the beam
a('<polygon points="420,226 640,120 640,250" fill="url(#beam-1)" opacity="0.55"/>')
a('<polygon points="420,226 60,70 40,190" fill="#fff2a8" opacity="0.1"/>')
# the tower, its stripes clipped to its shape
a('<g clip-path="url(#tower.shape)">')
for i in range(6):
    a(f'<rect class="{"white" if i%2==0 else "red"}" x="360" y="{250+i*42}" width="120" height="42"/>')
a('<rect x="420" y="250" width="60" height="252" fill="#000000" opacity="0.22"/>')
a('</g>')
for y in (288, 372, 456):
    a(f'<path d="M412 {y}a8 8 0 1116 0v16h-16z" fill="#233255"/>')
a('<rect x="384" y="236" width="72" height="14" fill="#2b2f45"/>')
a('<rect x="396" y="196" width="48" height="40" rx="4" fill="#fff2a8"/>')
for x in (396, 412, 428, 444):
    a(f'<rect x="{x-1}" y="196" width="2" height="40" fill="#2b2f45"/>')
a('<path d="M390 196 A30 30 0 0 1 450 196 Z" class="red"/>')
a('<circle cx="420" cy="166" r="4" fill="#2b2f45"/>')
a('</g>')
a('<rect id="frame-line" fill="none" x="16" y="16" width="608" height="608" rx="48"/>')
a('</svg>')
s = '\n'.join(o) + '\n'
open('sample.svg', 'w', newline='\n').write(s)
print(len(s), s.count('<'))
