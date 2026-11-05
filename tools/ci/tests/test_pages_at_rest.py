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

"""The site's other pages at rest, as its front page is (test_pages_front.py,
StillAtRest): the web stacks gallery (tools/pages/games/index.html), the
Stack Player's home (tools/web-player/index.html) and the codebase map
(tools/codebase-map/template.html).

Measured on rc.6.14's site in Chromium without a GPU (Linux), from the
browser's own processes, at rest: the gallery kept 233% of a core busy, the
Stack Player's home 233% and the map 56%. The gallery and the player turned
their rays, ran a fire rim around every card and flowed their flames (and
the gallery moved its logo) without end; the map drew its whole canvas
every frame for as long as it was open, sparks or none, less motion asked
for or not, each frame reading its colours from the style sheet and
blurring every big star's glow again. Now nothing moves without end unless
it is pointed at or has the keyboard's focus, and the map draws only while
something changes: 0% of a core for the gallery and the player at rest.
tools/pages/check_site_rest.py measures the browser itself.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
PAGES = os.path.join(REPO, 'tools', 'pages')
sys.path.insert(0, PAGES)


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def css_rules(text):
    """Each innermost rule of the page's first style sheet, as (selector,
    body), comments left out (a rule inside @media is read with its own
    selector)."""
    css = text[text.index('<style>'):text.index('</style>')]
    css = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    return [(m.group(1).strip(), m.group(2)) for m in re.finditer(r'([^{}]+)\{([^{}]*)\}', css)]


def endless(text):
    return [(selector, body) for selector, body in css_rules(text)
            if re.search(r'animation:[^;]*\binfinite\b', body)]


class TheGallery(unittest.TestCase):

    def setUp(self):
        self.text = read('tools', 'pages', 'games', 'index.html')
        self.rules = css_rules(self.text)

    def test_nothing_moves_without_end_at_rest(self):
        found = endless(self.text)
        self.assertTrue(found)
        for selector, body in found:
            for part in selector.split(','):
                self.assertRegex(part, r':hover|:focus-visible',
                                 'moves without end at rest: %s { %s }' % (selector, body.strip()))

    def test_the_rims_run_only_around_the_stack_pointed_at(self):
        rules = dict(self.rules)
        self.assertNotIn('animation', rules['.stack::before'])
        self.assertIn('animation: spin 2.2s linear infinite;', rules['.stack:hover::before, .stack:focus-visible::before'])

    def test_the_rays_are_still_and_the_flame_flows_twice(self):
        rules = dict(self.rules)
        self.assertNotIn('animation', rules['.sky::after'])
        self.assertNotIn('@keyframes rays', self.text)
        self.assertIn('animation: flow 6s ease-in-out 2 alternate;', rules['.flame'])
        self.assertIn('animation: flow 6s ease-in-out infinite alternate;', rules['.hero h1:hover .flame'])

    def test_the_logo_moves_as_the_page_opens(self):
        self.assertIn(('.hero-logo .moving', ' display: none; '), self.rules)
        self.assertIn(('.opening .hero-logo .moving, .hero-logo:hover .moving', ' display: block; '), self.rules)
        self.assertIn(('.opening .hero-logo .still, .hero-logo:hover .still', ' display: none; '), self.rules)
        self.assertIn('<img class="still" src="../brand/logo.svg"', self.text)
        self.assertIn('<img class="moving" src="../brand/logo-animated.svg"', self.text)
        script = self.text[self.text.index('<script>'):self.text.index('</script>')]
        self.assertIn("root.classList.add('opening');", script)
        self.assertIn("setTimeout(function () { root.classList.remove('opening'); }, 6000);", script)
        # less motion: the still logo, whatever the page is doing
        reduce = self.text[self.text.index('@media (prefers-reduced-motion: reduce)'):]
        self.assertIn('.hero-logo .moving { display: none !important; }', reduce)


class ThePlayer(unittest.TestCase):

    # Moving without end only while the engine loads or the player is busy:
    # #loading goes once the engine is up, .track.wait while a stack
    # downloads and #busy while it opens
    WHILE_LOADING = {'#loading img', '.track.wait i', '.spin'}

    def setUp(self):
        self.text = read('tools', 'web-player', 'index.html')
        self.rules = css_rules(self.text)

    def test_nothing_moves_without_end_at_rest(self):
        found = endless(self.text)
        self.assertTrue(found)
        for selector, body in found:
            if selector in self.WHILE_LOADING:
                continue
            for part in selector.split(','):
                self.assertRegex(part, r':hover|:focus-visible',
                                 'moves without end at rest: %s { %s }' % (selector, body.strip()))

    def test_the_rims_run_only_around_the_stack_pointed_at(self):
        rules = dict(self.rules)
        self.assertNotIn('animation', rules['.feature::before'])
        self.assertIn('animation:spin 2.2s linear infinite', rules['.feature:hover::before,.feature:focus-visible::before'])

    def test_the_rays_are_still_the_flame_and_the_logo_move_twice(self):
        # (each selector's first rule: a phone's @media rule comes later)
        rules = {}
        for selector, body in self.rules:
            rules.setdefault(selector, body)
        self.assertNotIn('animation', rules['.hero::after'])
        self.assertNotIn('@keyframes rays', self.text)
        self.assertIn('animation:flow 6s ease-in-out 2 alternate', rules['.flame'])
        self.assertIn('animation:flow 6s ease-in-out infinite alternate', rules['h1:hover .flame'])
        self.assertIn('animation:bob 5s ease-in-out 2', rules['.hero>img'])
        self.assertIn('animation:bob 5s ease-in-out infinite', rules['.hero>img:hover'])


class TheMap(unittest.TestCase):

    def setUp(self):
        text = read('tools', 'codebase-map', 'template.html')
        start = text.index('function constellation(host){')
        self.sky = text[start:text.index('\n}\n', start)]
        self.draw = self.sky[self.sky.index('function draw(){'):self.sky.index('function frame(){')]
        self.frame = self.sky[self.sky.index('function frame(){'):self.sky.index('  // (changed:')]

    def test_a_frame_is_asked_for_in_one_place(self):
        # request() alone asks for a frame, and only one at a time
        self.assertEqual(self.sky.count('requestAnimationFrame('), 1)
        self.assertIn('function request(changed){if(changed!==false)stale=true;if(!raf)raf=requestAnimationFrame(frame)}', self.sky)
        self.assertNotIn('running', self.sky)

    def test_a_frame_asks_for_the_next_only_while_sparks_are_in_flight(self):
        self.assertTrue(self.frame.rstrip().endswith('if(onScreen&&sparks.length)request(false)}'), self.frame)
        self.assertEqual(self.frame.count('request('), 1)

    def test_a_frame_of_sparks_alone_copies_the_lines_and_the_stars(self):
        # the layers are drawn again only when something else changed
        self.assertIn('if(stale||!back||back.o.width!==cv.width||back.o.height!==cv.height)', self.draw)
        self.assertIn('ctx=back.x;drawLines();ctx=front.x;drawStars();ctx=main;stale=false', self.draw)
        self.assertLess(self.draw.index('drawImage(back.o'), self.draw.index('drawSparks();'))
        self.assertLess(self.draw.index('drawSparks();'), self.draw.index('drawImage(front.o'))

    def test_the_sparks_flow_as_it_opens_and_while_pointed_at(self):
        self.assertIn('const SPARK_SECONDS=12;', self.sky)
        self.assertIn("const flowing=()=>mode==='on'||(mode==='auto'&&(pointedAt||performance.now()<awakeUntil));", self.sky)
        self.assertIn('awakeUntil=performance.now()+SPARK_SECONDS*1000', self.sky)
        self.assertIn("cv.addEventListener('pointerenter',()=>{pointedAt=true;request()});", self.sky)
        self.assertIn("pointedAt=false;", self.sky)
        # new sparks only while they flow; less motion: none at all until asked
        self.assertIn('if(flowing()&&sparks.length<140', self.frame)
        self.assertIn("mode=reduce?'off':'auto'", self.sky)

    def test_what_changes_the_picture_asks_for_a_frame(self):
        self.assertIn("sim.on('tick',request);", self.sky)
        self.assertIn('if(n!==hover){hover=n;request()}', self.sky)
        self.assertIn('function select(n){sel=n;request();', self.sky)
        self.assertIn("b.setAttribute('aria-pressed',on[k]);request()", self.sky)

    def test_a_frame_reads_no_style_and_blurs_nothing(self):
        # the colours are read once (and again when the theme changes), and
        # a big star's glow is drawn once into a canvas of its own
        self.assertNotIn('getPropertyValue', self.draw)
        self.assertNotIn('col(', self.draw)
        self.assertNotIn('shadowBlur', self.draw)
        self.assertNotIn('createRadialGradient', self.draw)
        self.assertIn('glows.get(k)', self.sky)
        self.assertIn("attributeFilter:['data-theme']", self.sky)


class TheRestCheck(unittest.TestCase):
    """check_site_rest.py: its pages and budgets."""

    @classmethod
    def setUpClass(cls):
        import check_site_rest
        cls.check = check_site_rest

    def test_the_pages(self):
        folders = [p[1] for p in self.check.PAGES]
        self.assertEqual(folders, ['games/', 'extensions/', 'player/', 'play/', 'map/'])

    def test_the_budgets(self):
        import check_front_page
        self.assertEqual(self.check.REST_CPU, check_front_page.REST_CPU)
        self.assertEqual(self.check.REST_GROWTH_MB, check_front_page.REST_GROWTH_MB)
        self.assertGreaterEqual(self.check.REST_SECONDS, 10)
        self.assertLessEqual(self.check.REST_FRAMES, 2)
        # the gallery's logo, which moves while pointed at, is let through
        self.assertGreaterEqual(self.check.BIG_AREA, 190 * 190)
        self.assertLess(self.check.BIG_AREA, 300 * 300)
        # measured once the map's sparks have landed
        self.assertGreater(self.check.REST_SETTLE, 12 + 4)
        self.assertIn('window.__restFrames++', self.check.COUNT_FRAMES)
        self.assertIn("classList.contains('opening')", self.check.SETTLED)


if __name__ == '__main__':
    unittest.main()
