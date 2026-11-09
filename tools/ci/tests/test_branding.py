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

"""The OXT-Beyond artwork (Installer/oxt-beyond/branding): every drawing
is made from SVG Lab's logo (tools/pages/games/svg-lab/beyond-logo.svg) as
draw_branding.py makes it today, so a logo changed without running it
fails here; the moving logo moves; and every copy elsewhere (the web
pages' brand/ folder, the Stack Player's icon, the web IDE's favicon, the
About window's images) is the file it was made from. Home's sidebar, in
every place, shows that logo as the About window does (TheSideMark). CairoSVG is not
needed: only the drawings are compared, and the PNG files are compared
byte for byte with their copies.

  python3 -m unittest discover -s tools/ci/tests
"""

import base64
import os
import re
import struct
import sys
import unittest
import xml.etree.ElementTree as ET

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
BRANDING = os.path.join(REPO, 'Installer', 'oxt-beyond', 'branding')
sys.path.insert(0, BRANDING)

import draw_branding  # noqa: E402

SVG = '{http://www.w3.org/2000/svg}'


def read(*path, mode='r'):
    with open(os.path.join(REPO, *path), mode, **({} if 'b' in mode else {'encoding': 'utf-8'})) as f:
        return f.read()


def png_size(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    return struct.unpack('>II', data[16:24])


class TheDrawings(unittest.TestCase):

    def test_each_is_as_draw_branding_makes_it(self):
        for name, draw in draw_branding.DRAWINGS.items():
            self.assertEqual(read('Installer', 'oxt-beyond', 'branding', 'svg', name), draw(), name)

    def test_the_icon_is_svg_labs_logo(self):
        self.assertEqual(read('Installer', 'oxt-beyond', 'branding', 'svg', 'icon.svg'),
                         read('tools', 'pages', 'games', 'svg-lab', 'beyond-logo.svg'))

    def test_each_is_svg(self):
        for name in draw_branding.DRAWINGS:
            root = ET.fromstring(read('Installer', 'oxt-beyond', 'branding', 'svg', name))
            self.assertEqual(root.tag, SVG + 'svg', name)

    def test_the_small_icon_leaves_out_the_fine_parts(self):
        small = draw_branding.icon_small()
        for part in ('class="tick"', 'class="beyond"', 'class="arc"', 'fill="#FFF4B0"'):
            self.assertNotIn(part, small)
        for part in ('class="oxt"', 'class="bolt"', 'class="rim"', 'clip-path="url(#oxt.letters)"'):
            self.assertIn(part, small)

    def test_the_moving_logo_moves(self):
        root = ET.fromstring(draw_branding.icon_animated())
        animations = [e for e in root.iter() if e.tag in (SVG + 'animate', SVG + 'animateTransform')]
        moved = {e.get('attributeName') for e in animations}
        self.assertEqual(moved, {'transform', 'opacity', 'points'})
        for e in animations:
            self.assertEqual(e.get('repeatCount'), 'indefinite')
            self.assertRegex(e.get('dur'), r'^\d+(\.\d+)?s$')
        # The rays, the glow, the halo, the shine, two arcs (points and
        # opacity each) and every spark
        self.assertGreaterEqual(len(animations), 4 + 4 + 5)
        # Without the animation it is the still logo
        still = re.sub(r'<animate(Transform)? [^>]*/>', '', draw_branding.icon_animated())
        still = re.sub(r'></(rect|circle|polygon|polyline)>', '/>', still)
        self.assertEqual(still.replace('translate(-200 0)', 'translate(620 0)'), draw_branding.logo())

    def test_a_changed_logo_is_caught(self):
        # draw_branding.py finds the parts it changes, or stops
        here = draw_branding.LOGO
        try:
            draw_branding.LOGO = os.path.join(REPO, 'tools', 'pages', 'games', 'svg-lab', 'sample.svg')
            with self.assertRaises(SystemExit):
                draw_branding.icon_small()
        finally:
            draw_branding.LOGO = here


class TheSplash(unittest.TestCase):
    """The IDE's splash (from 0.2.7-rc.6.14 like the web IDE's loading
    screen): the art and revsplashstackbehavior.livecodescript, which
    writes the version line, the loading bar's fill and the status over
    it, agree on where each goes, and none of them covers another."""

    SCRIPT = ('ide', 'Toolset', 'palettes', 'splash', 'revsplashstackbehavior.livecodescript')

    def script(self):
        return read(*self.SCRIPT).lstrip('\ufeff')

    def test_the_places_follow_one_another(self):
        d = draw_branding
        self.assertLessEqual(d.SPLASH_ART_BOTTOM, d.SPLASH_MOREINFO[1])
        self.assertLessEqual(d.SPLASH_MOREINFO[3], d.SPLASH_TRACK[1])
        self.assertLessEqual(d.SPLASH_TRACK[3], d.SPLASH_STATUS[1])
        self.assertLessEqual(d.SPLASH_STATUS[3], 306)
        for rect in (d.SPLASH_MOREINFO, d.SPLASH_TRACK, d.SPLASH_STATUS):
            # centred on the 591-pixel splash
            self.assertAlmostEqual(rect[0] + rect[2], 591, delta=1)

    def test_the_art_ends_above_the_ides_lines(self):
        bottom = 2 * draw_branding.SPLASH_ART_BOTTOM
        for dark in (True, False):
            art = draw_branding.splash(dark)
            m = re.search(r'<svg x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)"', art)
            self.assertLess(float(m.group(2)) + float(m.group(4)), bottom)
            for y in re.findall(r'<text [^>]*\by="([\d.]+)"', art):
                self.assertLess(float(y), bottom)
            for y, h in re.findall(r'<rect x="[\d.]+" y="([\d.]+)" width="[\d.]+" height="([\d.]+)" rx="15"', art):
                self.assertLess(float(y) + float(h), bottom)

    def test_the_art_draws_the_track(self):
        x1, y1, x2, y2 = (2 * n for n in draw_branding.SPLASH_TRACK)
        for dark in (True, False):
            self.assertIn('<rect x="%d" y="%d" width="%d" height="%d"' % (x1, y1, x2 - x1, y2 - y1),
                          draw_branding.splash(dark))

    def test_the_art_names_the_release(self):
        name = read('ide', '.codename').strip().upper()
        self.assertTrue(name)
        for dark in (True, False):
            self.assertIn('>%s</text>' % name, draw_branding.splash(dark))

    def test_the_art_is_rendered_at_both_sizes(self):
        for base in ('splash', 'splash-light'):
            for suffix, size in (('', (591, 306)), ('@extra-high', (1182, 612))):
                data = read('ide', 'Toolset', 'resources', 'community', 'ideSkin', base + suffix + '.png', mode='rb')
                self.assertEqual(png_size(data), size, base + suffix)

    def test_the_script_writes_where_the_art_leaves_room(self):
        script = self.script()
        open_stack = handler(script, 'on', 'preOpenStack')
        self.assertIn('set the rect of field "moreinfo" of me to %d,%d,%d,%d' % draw_branding.SPLASH_MOREINFO,
                      open_stack)
        self.assertIn('set the rect of field "Status" of me to %d,%d,%d,%d' % draw_branding.SPLASH_STATUS,
                      open_stack)
        for field in ('moreinfo', 'Status'):
            self.assertIn('set the textAlign of field "%s" of me to "center"' % field, open_stack)
            self.assertIn('set the dontWrap of field "%s" of me to true' % field, open_stack)
        # The version, then the release's words: "Thank you, bug hunters!" for
        # 0.2.7 "Make It So" ("Happy hunting!" in its release candidates)
        self.assertIn('put tVersion & "Thank you, bug hunters!" into field "moreinfo" of me', open_stack)
        self.assertIn('hide field "Info" of me', open_stack)
        self.assertLess(open_stack.index('put 0 into sSplashSteps'), open_stack.index('splashProgressBar'))

    def test_the_bar_fills_the_track(self):
        script = self.script()
        x1, y1, x2, y2 = draw_branding.SPLASH_TRACK
        bar = handler(script, 'command', 'splashProgressBar')
        self.assertIn('set the rect of graphic "progress" of me to %d,%d,%d,%d' % (x1, y1, x1 + 3, y2), bar)
        self.assertIn('create invisible graphic "progress"', bar)
        self.assertIn('set the backgroundColor of graphic "progress" of me to 255,119,0', bar)  # ORANGE
        status = handler(script, 'setProp', 'statusMessage')
        self.assertIn('%d, %d, %d + max(3, round(%d * min(sSplashSteps, kSplashSteps) / kSplashSteps)), %d'
                      % (x1, y1, x1, x2 - x1, y2), re.sub(r'\\\s*\n\s*', '', status))
        # The status line is written first, and the bar can never stop the
        # IDE starting: everything it does is inside try
        self.assertLess(status.index('put pMessage into field "status" of me'), status.index('try'))
        for body in (bar, status):
            self.assertLess(body.index('try'), body.index('graphic "progress"'))
            self.assertIn('catch tError', body)

    def test_the_bar_has_a_step_for_each_status(self):
        home = read('ide', 'Toolset', 'home.livecodescript')
        steps = len(re.findall(r'^\s*revInternal__setSplashStatus "', home, re.M))
        self.assertGreater(steps, 10)
        self.assertIn('constant kSplashSteps = %d\n' % steps, self.script())


class TheCopies(unittest.TestCase):

    def test_the_web_pages_logo(self):
        for source, copy in (('icon-small.svg', 'icon.svg'), ('icon.svg', 'logo.svg'),
                             ('icon-animated.svg', 'logo-animated.svg')):
            self.assertEqual(read('tools', 'pages', 'brand', copy),
                             read('Installer', 'oxt-beyond', 'branding', 'svg', source), copy)
        social = read('tools', 'pages', 'brand', 'social.png', mode='rb')
        self.assertEqual(social, read('Installer', 'oxt-beyond', 'branding', 'art', 'oxt-beyond-banner.png', mode='rb'))
        self.assertEqual(png_size(social), (1280, 640))

    def test_the_stack_players_icon(self):
        self.assertEqual(read('tools', 'web-player', 'assets', 'oxt-beyond-128.png', mode='rb'),
                         read('Installer', 'oxt-beyond', 'branding', 'png', 'oxt-beyond-128.png', mode='rb'))

    def test_the_web_ides_favicon(self):
        page = read('tools', 'web-ide', 'index.html')
        icons = re.findall(r'<link rel="icon" href="data:image/svg\+xml;base64,([^"]+)">', page)
        self.assertEqual(len(icons), 1)
        self.assertEqual(base64.b64decode(icons[0]).decode('utf-8'),
                         read('Installer', 'oxt-beyond', 'branding', 'svg', 'icon-small.svg'))

    def test_the_icon_sizes(self):
        for n in draw_branding.ICON_SIZES:
            data = read('Installer', 'oxt-beyond', 'branding', 'png', 'oxt-beyond-%d.png' % n, mode='rb')
            self.assertEqual(png_size(data), (n, n))

    def test_the_about_window_takes_the_icons(self):
        # tools/oxt/ide-stack-patch.sh puts these PNG files into the IDE
        # stack; the images keep their size, so the dialogs keep their layout
        patch = read('tools', 'oxt', 'ide-stack-patches', 'branding-dialog-icons.txt')
        images = re.findall(r'^image: (\S+)$', patch, re.M)
        self.assertEqual(images, ['Installer/oxt-beyond/branding/png/oxt-beyond-32.png',
                                  'Installer/oxt-beyond/branding/png/oxt-beyond-64.png'])
        for image, n in zip(images, (32, 64)):
            self.assertEqual(png_size(read(*image.split('/'), mode='rb')), (n, n))



def handler(text, kind, name):
    """The handler `name` of `text` (from its first line to its end line)."""
    m = re.search(r'^(?:private )?%s %s\b.*?^end %s\b' % (kind, re.escape(name), re.escape(name)),
                  text, re.M | re.S)
    if m is None:
        raise AssertionError('no %s %s' % (kind, name))
    return m.group(0)


class TheSideMark(unittest.TestCase):
    """Home's sidebar, in every place, shows the logo as the About window
    does: a copy of the 64-pixel logo of stack "revGeneralIcons" (the image
    the About window and the answer and ask dialogs show), not the
    orange-to-pink tile with the "layers" icon, which stays only for when
    that stack is missing."""

    HOME = ('ide', 'Toolset', 'palettes', 'web home', 'revwebhome.livecodescript')
    KIT = ('ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
    TOUR = ('tools', 'ci', 'ui-tour.livecodescript')
    LOGO = 'image "oxt-l-64.png" of card "theAlertIcons" of stack "revGeneralIcons"'

    def check_mark(self, mark, glow):
        logo = mark.index('set the text of tObj to the text of ' + self.LOGO)
        # the logo first, and the old mark only when there is none
        self.assertLess(mark.index('there is an ' + self.LOGO + ' then'), logo)
        self.assertLess(mark.index('create image "sideMark"'), logo)
        self.assertIn('set the rect of tObj to "20,22,56,58"', mark)
        self.assertIn('set the resizeQuality of tObj to "best"', mark)
        self.assertIn(glow + ' tObj, "255,122,0", 12, 70', mark)
        self.assertLess(logo, mark.index('exit '))
        self.assertLess(mark.index('exit '), mark.index('"sideMarkIcon", "layers"'))

    def test_homes_own_pages(self):
        home = read(*self.HOME)
        self.check_mark(handler(home, 'command', 'hmSideMark'), 'hmGlow')
        # Home on its own and Home hosting its places draw the mark so,
        # and nothing else draws the old one
        for side in ('hmBuildSide', 'hmBuildHostedSide'):
            self.assertIn('\n   hmSideMark\n', handler(home, 'command', side))
        self.assertEqual(home.count('"sideMarkIcon", "layers"'), 1)

    def test_the_academy_and_learn_in_home(self):
        kit = read(*self.KIT)
        self.check_mark(handler(kit, 'command', 'lkHubMark'), 'lkGlow')
        self.assertIn('\n   lkHubMark\n', handler(kit, 'function', 'lkHubHead'))
        self.assertEqual(kit.count('"sideMarkIcon", "layers"'), 1)

    def test_the_tour_looks_at_it(self):
        tour = read(*self.TOUR)
        check = handler(tour, 'on', 'tourHomeMark')
        self.assertIn('there is a control "sideMarkIcon" of stack pStack or there is a graphic "sideMark" of stack pStack', check)
        self.assertIn('put the text of ' + self.LOGO + ' into tLogo', check)
        self.assertIn('the text of image "sideMark" of stack pStack is not tLogo', check)
        self.assertIn('the rect of image "sideMark" of stack pStack is not "20,22,56,58"', check)
        home = handler(tour, 'on', 'tour_home')
        self.assertLess(home.index('tourShotStack tNew, "24a-home"'), home.index('tourHomeMark tNew, "opened"'))
        self.assertLess(home.index('"24a-home-redrawn"'), home.index('tourHomeMark tNew, "redrawn"'))
        for step, place in (('tour_learn', 'the How-to'), ('tour_academy', 'the Academy')):
            body = handler(tour, 'on', step)
            self.assertIn('if tWin is kHub then tourHomeMark tWin, "%s"' % place, body)
            self.assertIn('if tWin is kHub then tourHomeMark tWin, "%s, redrawn"' % place, body)
        places = handler(tour, 'on', 'tour_home_places')
        self.assertLess(places.index('tourShotStack kHub, "24g-hub-" & tPlace'), places.index('tourHomeMark kHub, tPlace\n'))
        self.assertIn('tourHomeMark kHub, tPlace & ", redrawn"', places)


if __name__ == '__main__':
    unittest.main()
