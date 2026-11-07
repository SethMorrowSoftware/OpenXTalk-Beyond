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

"""The web pages' Fields setting (seth's choice 9A of 2026-10-31): on a
page that asks for it, fields, list fields and combo boxes that set no
colour are drawn in the light appearance in the grey of a card that sets
none, as in the dark one; every other page keeps white fields.

web_check.py checks it in the browser: the probe opens a stack whose
colours are all unset and reads a point of its field and one of its card,
on the page as built (white and grey) and on the page with the setting
(grey and grey). With the IDE (--install, --package) the page with the
setting is the one the IDE's builder writes from the Standalone Settings;
the UI tour picks each of the setting's choices in the HTML5 pane. These
tests hold the pieces to each other: the one name and value that the
builder writes, the engine reads and the check expects. Playwright is not
needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import struct
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import web_check  # noqa: E402

PAGE = ('<!DOCTYPE html>\n<html><head><meta charset="utf-8"><title>WebProbe</title></head>\n'
        '<body><canvas id="canvas"></canvas></body></html>\n')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def livecode_text(expression):
    """The value of a LiveCode Script expression made of string literals
    and quote, joined with & and && (as the builder writes its meta)."""
    value = ''
    for token in re.findall(r'"[^"]*"|&&|&|\bquote\b|\S+', expression):
        if token.startswith('"'):
            value += token[1:-1]
        elif token == 'quote':
            value += '"'
        elif token == '&&':
            value += ' '
        elif token != '&':
            raise ValueError('not a literal: %s' % token)
    return value


class FieldsPageFromIde(unittest.TestCase):
    """fields_page_from_ide: the page that the IDE's builder wrote with the
    setting is the page as built and the meta, and goes beside it."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-web-check-')
        self.site = os.path.join(self.work, 'site')
        self.fields = self.site + '-fields'
        os.makedirs(self.site)
        os.makedirs(self.fields)
        self.write(self.site, PAGE)

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def write(self, folder, text):
        with open(os.path.join(folder, web_check.STACK_NAME + '.html'), 'w', encoding='utf-8') as f:
            f.write(text)

    def test_the_page_with_the_meta(self):
        text = PAGE.replace('</head>', web_check.FIELDS_META + '</head>')
        self.write(self.fields, text)
        line = web_check.fields_page_from_ide(self.site, self.fields)
        self.assertIn(web_check.FIELDS_META, line)
        with open(os.path.join(self.site, web_check.fields_page_name()), encoding='utf-8') as f:
            self.assertEqual(f.read(), text)

    def test_no_page(self):
        with self.assertRaisesRegex(web_check.CheckError, 'wrote no page'):
            web_check.fields_page_from_ide(self.site, self.fields)
        self.assertFalse(os.path.exists(os.path.join(self.site, web_check.fields_page_name())))

    def test_no_meta(self):
        # (the builder left the setting out: the page as built)
        self.write(self.fields, PAGE)
        with self.assertRaisesRegex(web_check.CheckError, 'has not one'):
            web_check.fields_page_from_ide(self.site, self.fields)
        self.assertFalse(os.path.exists(os.path.join(self.site, web_check.fields_page_name())))

    def test_meta_in_the_body(self):
        self.write(self.fields, PAGE.replace('<canvas', web_check.FIELDS_META + '<canvas'))
        with self.assertRaisesRegex(web_check.CheckError, 'has not one'):
            web_check.fields_page_from_ide(self.site, self.fields)

    def test_meta_twice(self):
        self.write(self.fields, PAGE.replace('</head>', web_check.FIELDS_META * 2 + '</head>'))
        with self.assertRaisesRegex(web_check.CheckError, 'has not one'):
            web_check.fields_page_from_ide(self.site, self.fields)

    def test_more_changed(self):
        text = PAGE.replace('</head>', web_check.FIELDS_META + '</head>').replace('WebProbe', 'Other')
        self.write(self.fields, text)
        with self.assertRaisesRegex(web_check.CheckError, 'differs from the page as built'):
            web_check.fields_page_from_ide(self.site, self.fields)

    def test_write_fields_page(self):
        # (built without the IDE, web_check.py writes the page itself)
        page = os.path.join(self.site, web_check.STACK_NAME + '.html')
        web_check.write_fields_page(page)
        with open(os.path.join(self.site, web_check.fields_page_name()), encoding='utf-8') as f:
            self.assertEqual(f.read(), PAGE.replace('</head>', web_check.FIELDS_META + '</head>'))


# getSplashMarkup's answer (ide-support/revsaveasemscriptenstandalone.livecodescript)
# for web-deploy.livecodescript's 24x24 PNG, as the engine gives it:
# tests/lcs/standalonebuilder/web-splash.livecodescript asserts the same text
SPLASH_HEAD = ("<style>.oxt-splash #status{position:fixed;top:0;left:0;right:0;bottom:0;z-index:1;margin:0;box-sizing:border-box;background-color:inherit;padding:0 16px;padding-top:calc(50vh + min(24px,60vh)/2 + 12px);padding-top:calc(50dvh + min(24px,60vh)/2 + 12px)}.oxt-splash #status::before{content:'';position:absolute;left:50%;top:50%;width:24px;height:24px;max-width:calc(100% - 32px);max-height:60%;transform:translate(-50%,-50%);background:url(splash.png) center/contain no-repeat}</style><script>(function(){var r=document.documentElement;r.classList.add('oxt-splash');document.addEventListener('DOMContentLoaded',function(){var s=document.getElementById('status'),o;function done(){if(s&&s.style.display!=='none'){return false;}r.classList.remove('oxt-splash');if(o){o.disconnect();}return true;}if(!done()){o=new MutationObserver(done);o.observe(s,{attributes:true,attributeFilter:['style']});}});})();</script>")


def png(width, height):
    """The start of a PNG of that size: its signature and IHDR."""
    return (b'\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR' + struct.pack('>II', width, height)
            + b'\x08\x06\x00\x00\x00')


class SplashPageFromIde(unittest.TestCase):
    """splash_page_from_ide: the page that the IDE's builder wrote with the
    Splash setting is the page as built and the splash's style and script,
    with the image beside it, and both go beside the page as built."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-web-check-')
        self.site = os.path.join(self.work, 'site')
        self.splash = self.site + '-splash'
        os.makedirs(self.site)
        os.makedirs(self.splash)
        self.write(self.site, PAGE)
        self.image(png(24, 24))

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def write(self, folder, text):
        with open(os.path.join(folder, web_check.STACK_NAME + '.html'), 'w', encoding='utf-8') as f:
            f.write(text)

    def image(self, data):
        with open(os.path.join(self.splash, web_check.SPLASH_IMAGE), 'wb') as f:
            f.write(data)

    def test_the_fixture_is_what_the_check_finds(self):
        self.assertEqual(web_check.SPLASH_HEAD_RE.findall(SPLASH_HEAD), [SPLASH_HEAD])

    def test_the_page_with_the_splash(self):
        text = PAGE.replace('</head>', SPLASH_HEAD + '</head>')
        self.write(self.splash, text)
        line = web_check.splash_page_from_ide(self.site, self.splash)
        self.assertIn(web_check.SPLASH_IMAGE, line)
        with open(os.path.join(self.site, web_check.splash_page_name()), encoding='utf-8') as f:
            self.assertEqual(f.read(), text)
        with open(os.path.join(self.site, web_check.SPLASH_IMAGE), 'rb') as f:
            self.assertEqual(f.read(), png(24, 24))

    def test_no_page(self):
        with self.assertRaisesRegex(web_check.CheckError, 'wrote no page'):
            web_check.splash_page_from_ide(self.site, self.splash)
        self.assertFalse(os.path.exists(os.path.join(self.site, web_check.splash_page_name())))

    def test_no_image(self):
        self.write(self.splash, PAGE.replace('</head>', SPLASH_HEAD + '</head>'))
        os.remove(os.path.join(self.splash, web_check.SPLASH_IMAGE))
        with self.assertRaisesRegex(web_check.CheckError, 'did not copy the splash image'):
            web_check.splash_page_from_ide(self.site, self.splash)

    def test_another_image(self):
        self.write(self.splash, PAGE.replace('</head>', SPLASH_HEAD + '</head>'))
        self.image(png(48, 24))
        with self.assertRaisesRegex(web_check.CheckError, 'not the 24x24 PNG'):
            web_check.splash_page_from_ide(self.site, self.splash)

    def test_no_splash(self):
        # (the builder left the setting out: the page as built)
        self.write(self.splash, PAGE)
        with self.assertRaisesRegex(web_check.CheckError, 'has not one splash'):
            web_check.splash_page_from_ide(self.site, self.splash)
        self.assertFalse(os.path.exists(os.path.join(self.site, web_check.splash_page_name())))

    def test_splash_in_the_body(self):
        self.write(self.splash, PAGE.replace('<canvas', SPLASH_HEAD + '<canvas'))
        with self.assertRaisesRegex(web_check.CheckError, 'has not one splash'):
            web_check.splash_page_from_ide(self.site, self.splash)

    def test_splash_twice(self):
        self.write(self.splash, PAGE.replace('</head>', SPLASH_HEAD * 2 + '</head>'))
        with self.assertRaisesRegex(web_check.CheckError, 'has not one splash'):
            web_check.splash_page_from_ide(self.site, self.splash)

    def test_another_size(self):
        self.write(self.splash, PAGE.replace('</head>', SPLASH_HEAD.replace('24px', '25px') + '</head>'))
        with self.assertRaisesRegex(web_check.CheckError, 'width:24px;height:24px'):
            web_check.splash_page_from_ide(self.site, self.splash)

    def test_more_changed(self):
        text = PAGE.replace('</head>', SPLASH_HEAD + '</head>').replace('WebProbe', 'Other')
        self.write(self.splash, text)
        with self.assertRaisesRegex(web_check.CheckError, 'differs from the page as built'):
            web_check.splash_page_from_ide(self.site, self.splash)


class SplashSeen(unittest.TestCase):
    """splash_seen_problem: the splash over the window while the page
    loads, gone once its stack is open."""

    LOADING = ['oxt-splash', 'fixed', 'url("http://127.0.0.1:8000/splash.png")']
    STARTED = ['', 'none']

    def test_shown_then_gone(self):
        self.assertIsNone(web_check.splash_seen_problem(self.LOADING, self.STARTED))

    def test_never_shown(self):
        for loading in (None, ['', 'static', 'none'], ['oxt-splash', 'static', self.LOADING[2]],
                        ['oxt-splash', 'fixed', 'none']):
            self.assertIn('did not show it', web_check.splash_seen_problem(loading, self.STARTED))

    def test_still_shown(self):
        for started in (None, ['oxt-splash', 'none'], ['', 'block']):
            self.assertIn('still showed it', web_check.splash_seen_problem(self.LOADING, started))

    def test_the_deploy_builds_it_and_the_check_reads_it(self):
        deploy = read('tools', 'ci', 'web-deploy.livecodescript')
        self.assertIn('put $OXT_WEB_OUTPUT & "-splash" into tSplashFolder', deploy)
        self.assertIn('put tSplashFolder & "-image.png" into tSplashSettings["emscripten,splash"]', deploy)
        self.assertIn('with "WebProbe", tSplashFolder, tSplashSettings', deploy)
        check = read('tools', 'ci', 'web_check.py')
        self.assertIn("splash_site = site + '-splash'", check)
        self.assertIn('lines.append(splash_page_from_ide(site, splash_site))', check)
        self.assertIn('tab.add_init_script(SPLASH_SEEN_JS)', check)

    def test_the_pane_sets_it(self):
        pane = read('ide', 'Toolset', 'palettes', 'standalone settings',
                    'revstandalonesettingsemscriptenbehavior.livecodescript')
        self.assertIn('setSetting "emscripten,splash", tFile', pane)
        self.assertIn('setSetting "emscripten,splash", empty', pane)
        controls = re.search(r'^constant kWebSettingsControls = "([^"]+)"', pane, re.M).group(1).split(',')
        for name in ('emscriptenSplashLabel', 'emscriptenSplash', 'emscriptenSplashNone', 'emscriptenSplashChoose'):
            self.assertIn(name, controls)


class OneNameAndValue(unittest.TestCase):
    """The meta that the builder writes is the one the engine reads and the
    check expects, and the setting's value is the pane's."""

    def meta_parts(self):
        m = re.match(r'^<meta name="([^"]+)" content="([^"]+)">$', web_check.FIELDS_META)
        self.assertIsNotNone(m)
        return m.group(1), m.group(2)

    def test_the_builder_writes_it(self):
        script = read('ide-support', 'revsaveasemscriptenstandalone.livecodescript')
        branch = script.split('switch pSettings["emscripten,fieldBackground"]', 1)[1].split('end switch', 1)[0]
        self.assertIn('case empty\n         break', branch)
        put = re.search(r'case "card"\n\s+put (.+) after tHead\n', branch)
        self.assertIsNotNone(put)
        self.assertEqual(livecode_text(put.group(1)), web_check.FIELDS_META)
        self.assertIn('revStandaloneAddWarning "HTML5: unknown background of the page\'s fields:"', branch)

    def test_the_engine_reads_it(self):
        name, value = self.meta_parts()
        js = read('engine', 'src', 'em-dc.js')
        self.assertIn('document.querySelector(\'meta[name="%s"]\')' % name, js)
        self.assertIn("meta.getAttribute('content') === '%s'" % value, js)
        self.assertIn('LiveCodeDC._readFieldBackground();', js.split('_initialised = true;', 1)[0])
        self.assertIn('MCEmscriptenGetFieldsLikeCard: function()', js)

    def test_the_theme_draws_it(self):
        theme = read('engine', 'src', 'em-theme.cpp')
        case = theme.split('case kMCPlatformControlTypeInputField:', 1)[1].split('case kMCPlatformControlTypeOptionMenu:', 1)[0]
        # in the light appearance only, fields, lists and combo boxes take
        # the card's grey; otherwise what they had
        self.assertIn('case kMCPlatformControlTypeList:', case)
        self.assertIn('case kMCPlatformControlTypeComboBox:', case)
        self.assertIn('if (!t_dark && MCEmscriptenGetFieldsLikeCard() != 0)\n'
                      '\t\t\t\treturn em_theme_color(kMCWebThemeFace, r_color);', case)
        self.assertIn('return em_theme_color(t_dark ? kMCWebThemeDarkFace : kMCWebThemeWindow, r_color);', case)
        # menus keep their white
        menus = theme.split('case kMCPlatformControlTypeOptionMenu:', 1)[1].split('default:', 1)[0]
        self.assertNotIn('MCEmscriptenGetFieldsLikeCard', menus)

    def test_the_pane_sets_it(self):
        _, value = self.meta_parts()
        pane = read('ide', 'Toolset', 'palettes', 'standalone settings',
                    'revstandalonesettingsemscriptenbehavior.livecodescript')
        self.assertIn('constant kFieldsItems = "White,The card\'s grey"', pane)
        self.assertIn('constant kFieldsValues = ",%s"' % value, pane)
        self.assertIn('setSetting "emscripten,fieldBackground", item (the menuHistory of the target) of kFieldsValues',
                      pane)
        controls = re.search(r'^constant kWebSettingsControls = "([^"]+)"', pane, re.M).group(1).split(',')
        self.assertIn('emscriptenFields', controls)
        self.assertIn('emscriptenFieldsLabel', controls)

    def test_the_tour_picks_it(self):
        tour = read('tools', 'ci', 'ui-tour.livecodescript')
        self.assertIn('set the menuHistory of button "emscriptenFields" of card "Emscripten" of stack tStack to 2',
                      tour)
        self.assertIn('the cRevStandaloneSettings["emscripten,fieldBackground"] of stack kSample is not "card"',
                      tour)
        self.assertIn('set the menuHistory of button "emscriptenFields" of card "Emscripten" of stack tStack to 1',
                      tour)

    def test_the_ide_builds_it(self):
        _, value = self.meta_parts()
        deploy = read('tools', 'ci', 'web-deploy.livecodescript')
        self.assertIn('put "%s" into tFieldsSettings["emscripten,fieldBackground"]' % value, deploy)
        self.assertIn('put $OXT_WEB_OUTPUT & "-fields" into tFieldsFolder', deploy)
        self.assertIn('with "WebProbe", tFieldsFolder, tFieldsSettings', deploy)
        check = read('tools', 'ci', 'web_check.py')
        self.assertIn("fields_site = site + '-fields'", check)
        self.assertIn('lines.append(fields_page_from_ide(site, fields_site))', check)


class TheColours(unittest.TestCase):
    """What the check expects of a stack whose colours are all unset: on the
    page as built a white field on the card's grey, as on every page before;
    on the page with the setting one grey for both."""

    def parts(self, report):
        size, field, card = report.split(':')
        return size, field, card

    def test_expected(self):
        size, field, card = self.parts(web_check.COLORS_AS_BUILT)
        self.assertEqual(size, '200x100')
        self.assertEqual(field, '255,255,255')
        # (kMCWebThemeFace, 0xF0F0F0)
        self.assertEqual(card, '240,240,240')
        self.assertIn('#define kMCWebThemeFace             0xF0F0F0', read('engine', 'src', 'em-theme.cpp'))
        size2, field2, card2 = self.parts(web_check.COLORS_FIELDS_LIKE_CARD)
        self.assertEqual((size2, card2), (size, card))
        self.assertEqual(field2, card)

    def test_the_probe_reports_them(self):
        probe = read('tools', 'ci', 'web-probe.livecodescript')
        report = probe.split('function probeReport pWhat', 1)[1]
        for what in ('colors-open', 'colors', 'colors-close'):
            self.assertIn('if pWhat is "%s" then' % what, report)
        # the probe's own blue, which a mainstack inherits from the home
        # stack (the standalone's), is off while the stack is open, and put
        # back
        self.assertIn('set the backgroundColor of stack "WebProbe" to empty', probe)
        self.assertIn('set the backgroundColor of stack "WebProbe" to sColorsBack', report)
        self.assertLess(probe.index('local sColorsBack'), probe.index('private function probeColorsOpen'))


class TheCheckBoxes(unittest.TestCase):
    """A check box that sets no colour, on a page that follows a browser set
    to dark: its box was white, as in the light appearance, so an unticked
    one looked ticked on the dark card (found in the web IDE on 2026-10-29;
    promised in the rc.6.11 post for rc.6.12). It is the dark face there,
    with a white tick; on the page as built, which stays light, it is white
    with a black tick, as before. web_check.py reads both in the browser;
    these tests hold what it expects to the engine's colours and the
    probe's report."""

    def parts(self, report):
        size, plain, ticked, tick = report.split(':')
        return size, plain, ticked, tick

    def test_light_is_as_before(self):
        self.assertEqual(self.parts(web_check.CHECKS_LIGHT),
                         ('200x100', '255,255,255', '255,255,255', '0,0,0'))

    def test_dark_is_the_dark_face_with_a_white_tick(self):
        size, plain, ticked, tick = self.parts(web_check.CHECKS_DARK)
        self.assertEqual(size, '200x100')
        # (kMCWebThemeDarkFace, 0x202020), the dark card's colour too
        self.assertEqual(plain, '32,32,32')
        self.assertEqual(ticked, '32,32,32')
        self.assertEqual(tick, '255,255,255')
        self.assertIn('#define kMCWebThemeDarkFace         0x202020', read('engine', 'src', 'em-theme.cpp'))

    def test_the_theme_gives_the_box_its_colour(self):
        theme = read('engine', 'src', 'em-theme.cpp')
        helper = theme.split('MCEmscriptenThemeGetCheckBoxColor(bool p_pressed, MCColor& r_color)\n{', 1)[1]
        helper = helper.split('\n}', 1)[0]
        # only in the dark appearance; the light one keeps its white box
        self.assertIn('if (!em_theme_is_dark())\n\t\treturn false;', helper)
        self.assertIn('p_pressed ? kMCWebThemeDarkHilightEdge : kMCWebThemeDarkFace', helper)

    def test_the_box_takes_it(self):
        draw = read('engine', 'src', 'buttondraw.cpp')
        check = draw.split('void MCButton::drawcheck(', 1)[1].split('\nvoid MCButton::drawradio(', 1)[0]
        win95 = check.split('case LF_WIN95:', 1)[1]
        # a box with no colour of its own asks the web theme first, and is
        # white (grey while pressed) only when the theme has none for it
        asked = win95.index('if (MCEmscriptenThemeGetCheckBoxColor(t_pressed, t_box_color))')
        self.assertLess(asked, win95.index('t_white_box = true;'))
        self.assertLess(win95.index('t_white_box = true;'), win95.index('dc->setforeground(dc->getwhite());'))
        # and a tick in a white box stays black
        self.assertIn('if (t_white_box)\n\t\t\t\t\tt_appearance = kMCSystemAppearanceLight;', win95)

    def test_the_probe_reports_them(self):
        probe = read('tools', 'ci', 'web-probe.livecodescript')
        report = probe.split('function probeReport pWhat', 1)[1]
        self.assertIn('if pWhat is "checks" then\n      return probeCheckBoxColors()', report)
        opened = probe.split('private function probeColorsOpen', 1)[1].split('end probeColorsOpen', 1)[0]
        self.assertIn('probeColorsCheckBox "Plain Check", "10,55,90,75", false', opened)
        self.assertIn('probeColorsCheckBox "Ticked Check", "110,55,190,75", true', opened)
        # the box: CHECK_SIZE points square, as drawcheck places it
        self.assertIn('#define CHECK_SIZE 13', read('engine', 'src', 'button.h'))
        inside = probe.split('private function probeCheckBoxInside pName', 1)[1]
        self.assertIn('((the height of button pName - 13) div 2) + 1 + 2', inside)

    def test_the_check_reads_them_in_a_dark_browser(self):
        check = read('tools', 'ci', 'web_check.py')
        block = check.split("browser_waiting[0] = 'the systemAppearance'", 1)[1].split(
            "browser_waiting[0] = 'the default colours'", 1)[0]
        self.assertIn("dark = browser.new_context(color_scheme='dark')", block)
        self.assertIn("want_boxes = CHECKS_DARK if name == 'following the browser' else CHECKS_LIGHT", block)
        self.assertIn('if not wait_for(boxes_drawn,', block)
        # read before the browser turns light
        self.assertLess(block.index('boxes_drawn'), block.index("tab.emulate_media(color_scheme='light')"))


class TheCardColours(unittest.TestCase):
    """A push button and a tab panel on a card with a colour of its own: the
    web engine has no theme to draw them (em-theme.cpp's MCWebTheme does not
    load), so they were filled with the card's colour, where Windows, the Mac
    and Linux draw their theme's face (TerryL, openxtalk.org p=25957 and
    p=26095, the web IDE on Windows 11). web_check.py reads them in the
    browser on a card coloured 120,170,230; these tests hold what it expects
    to the engine's colours, the probe's report and the engine's rule."""

    def parts(self, report):
        return report.split('|')

    def test_light_is_the_face_where_the_desktop_draws_its_theme(self):
        parts = self.parts(web_check.CARD_COLORS_LIGHT)
        self.assertEqual(len(parts), 1 + len(web_check.CARD_COLOR_NAMES))
        size, push, default, rect, own, white, off, pane, tab, effective = parts
        self.assertEqual(size, '400x180')
        # kMCWebThemeFace, 0xF0F0F0: a card that sets no colour's too
        self.assertIn('#define kMCWebThemeFace             0xF0F0F0', read('engine', 'src', 'em-theme.cpp'))
        for drawn in (push, default, off, pane, tab):
            self.assertEqual(drawn, '240,240,240')
        # as before: Windows' theme has no rectangle button either, a
        # colour of the button's own wins, white words could not be read on
        # the light face, and a script reads the inherited colour
        self.assertEqual(rect, '120,170,230')
        self.assertEqual(own, '255,200,120')
        self.assertEqual(white, '120,170,230')
        self.assertEqual(effective, '120,170,230')

    def test_dark_is_the_dark_face(self):
        size, push, default, rect, own, white, off, pane, tab, effective = self.parts(web_check.CARD_COLORS_DARK)
        self.assertEqual(size, '400x180')
        for drawn in (push, default, white, off, pane, tab):
            # (kMCWebThemeDarkFace, 0x202020): white words read on it
            self.assertEqual(drawn, '32,32,32')
        self.assertEqual((rect, own, effective), ('120,170,230', '255,200,120', '120,170,230'))

    def test_a_problem_names_what_took_the_card_colour(self):
        self.assertIsNone(web_check.card_colors_problem('as built', web_check.CARD_COLORS_LIGHT,
                                                        web_check.CARD_COLORS_LIGHT))
        # what the engine drew before: the card's colour in every one
        before = '400x180|' + '|'.join(['120,170,230'] * 3 + ['255,200,120'] + ['120,170,230'] * 5)
        problem = web_check.card_colors_problem('as built', before, web_check.CARD_COLORS_LIGHT)
        for name in ('push button', 'default button', 'disabled push button', "tab panel's pane",
                     "tab panel's selected tab"):
            self.assertIn('the %s rgb(120,170,230), expected rgb(240,240,240)' % name, problem)
        self.assertNotIn('rectangle button', problem)
        self.assertIn('could not', web_check.card_colors_problem('as built', 'no stack', web_check.CARD_COLORS_LIGHT)
                      .replace('read', 'could not'))

    def test_the_probe_reports_them(self):
        probe = read('tools', 'ci', 'web-probe.livecodescript')
        report = probe.split('function probeReport pWhat', 1)[1]
        self.assertIn('if pWhat is "card-colors-open" then\n      return probeCardColorsOpen()', report)
        self.assertIn('if pWhat is "card-colors" then\n      return probeCardColors()', report)
        opened = probe.split('private function probeCardColorsOpen', 1)[1].split('end probeCardColorsOpen', 1)[0]
        self.assertIn('set the backgroundColor of card 1 of stack "Probe Card Colors" to "120,170,230"', opened)
        for name, rect in (('Push', '10,10,110,36'), ('Default', '130,10,230,36'), ('Rect', '250,10,350,36'),
                           ('Own', '10,50,110,76'), ('White Words', '130,50,230,76'), ('Off', '250,50,350,76')):
            self.assertIn('probeCardButton "%s", "%s"' % (name, rect), opened)
        self.assertIn('set the menuMode of button "Tabs" of stack "Probe Card Colors" to "tabbed"', opened)
        self.assertIn('set the rect of button "Tabs" of stack "Probe Card Colors" to 10,90,250,170', opened)
        # each area is inside its control, clear of its border (4 points in)
        # and of its words (centred)
        read_ = probe.split('private function probeCardColors\n', 1)[1].split('end probeCardColors\n', 1)[0]
        areas = re.search(r'repeat for each item tArea in "([^"]+)"', read_).group(1).split(',')
        self.assertEqual(len(areas), len(web_check.CARD_COLOR_NAMES) - 1)
        rects = [(10, 10, 110, 36), (130, 10, 230, 36), (250, 10, 350, 36), (10, 50, 110, 76),
                 (130, 50, 230, 76), (250, 50, 350, 76)]
        for area, (left, top, right, bottom) in zip(areas, rects):
            x0, y0, x1, y1 = (int(v) for v in area.split())
            self.assertGreaterEqual(x0, left + 4)
            self.assertGreaterEqual(y0, top + 4)
            self.assertLessEqual(y1, bottom - 4)
            self.assertLessEqual(x1, left + 14)

    def test_the_engine_fills_them_with_the_face_on_the_web_only(self):
        draw = read('engine', 'src', 'buttondraw.cpp')
        helper = draw.split('bool MCButton::getwebthemeface(MCContextType p_type, MCColor &r_face)\n{', 1)[1]
        helper = helper.split('\n}\n', 1)[0]
        web, other = helper.split('#else', 1)
        self.assertIn('#ifdef __EMSCRIPTEN__', web)
        self.assertEqual(other.strip().splitlines()[0].strip(), 'return false;')
        # only with no theme, no colour or pattern of its own, words that
        # read on the face; a push button or a tab panel
        self.assertIn('if (MCcurtheme != NULL || MClook == LF_MOTIF || !(flags & F_OPAQUE))', web)
        self.assertIn('if (getcindex(DI_BACK, i) || getpindex(DI_BACK, i))', web)
        self.assertIn('if (MCObjectColorContrast(t_words, t_face) < 4.5)', web)
        # the words read are the enabled ones: getforecolor gives a disabled
        # button or group the theme's grey, which does not read on the dark
        # face (the web check's disabled push button in a dark browser,
        # 0.2.7-rc.6.17), so the words are the first foregroundColor up the
        # chain, else the theme's with the disabled state left out
        self.assertNotIn('getforecolor(', web)
        self.assertIn('t_object -> getcindex(DI_FORE, i)', web)
        self.assertIn('else if (t_object -> getpindex(DI_FORE, i))', web)
        self.assertIn('t_state & ~(kMCPlatformControlStateDisabled | kMCPlatformControlStateSelected)', web)
        self.assertNotIn('F_DISABLED', web)
        self.assertIn('bool t_tabs = t_style == F_MENU && menumode == WM_TOP_LEVEL;', web)
        self.assertNotIn('F_RECTANGLE', web)
        # the fill takes it unless the button is hilited, and so do the tabs
        self.assertIn('if (!t_fill_rev && !t_fill_hilite && getwebthemeface(dc -> gettype(), t_web_face))', draw)
        tabs = draw.split('void MCButton::drawtabs(', 1)[1]
        self.assertIn('if (getwebthemeface(dc -> gettype(), t_web_face))', tabs)

    def test_the_check_reads_them_in_a_dark_browser(self):
        check = read('tools', 'ci', 'web_check.py')
        block = check.split("browser_waiting[0] = 'the systemAppearance'", 1)[1].split(
            "browser_waiting[0] = 'the default colours'", 1)[0]
        self.assertIn("want_cards = CARD_COLORS_DARK if name == 'following the browser' else CARD_COLORS_LIGHT",
                      block)
        self.assertIn("if wait_for(cards_drawn, 'the coloured card of the page %s' % name, 10):", block)
        self.assertLess(block.index('cards_drawn'), block.index("tab.emulate_media(color_scheme='light')"))


class TheSvgCheck(unittest.TestCase):
    """An HTML5 standalone that the IDE builds compiles SVG with the
    drawing library: the builder must carry the library's resources folder,
    which holds the SVG specification that the library reads when it
    starts. The IDE's build names the library (web-deploy), the probe
    compiles an SVG in the browser and must get the desktop's drawing
    (probeDrawing), and web_check.py expects that check, and the file in
    standalone.zip, whenever the IDE had the library."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def zip_with(self, *names):
        import zipfile
        with zipfile.ZipFile(os.path.join(self.tmp, 'standalone.zip'), 'w') as z:
            for name in names:
                z.writestr(name, 'x')
        return self.tmp

    def test_the_check_is_expected_with_the_library(self):
        checks, problems, lines = web_check.expected_checks({}, True, True)
        self.assertIn('svg', checks)
        self.assertIn('browser', checks)
        self.assertEqual(problems, [])
        self.assertEqual(lines, [])

    def test_a_standalone_without_the_library_the_ide_named_fails(self):
        checks, problems, lines = web_check.expected_checks(
            {'drawing-library': 'not loaded', 'extensions': 'com.livecode.widget.browser'}, True, True)
        self.assertNotIn('svg', checks)
        self.assertEqual(problems, ['the standalone has no drawing library: its extension is not loaded (the '
                                    'extensions are com.livecode.widget.browser)'])

    def test_a_standalone_made_without_the_ide_has_none(self):
        for drawing in (None, False):
            checks, problems, lines = web_check.expected_checks({'drawing-library': 'not loaded'}, True, drawing)
            self.assertNotIn('svg', checks)
            self.assertEqual(problems, [])
            self.assertEqual(lines, ['SVG was not checked: the standalone was made without the drawing library'])

    def test_a_probe_that_never_says_still_owes_the_check(self):
        # (an old probe, or one whose probeDrawing never ran: "did not
        # report the check svg")
        checks, problems, lines = web_check.expected_checks({}, None, None)
        self.assertIn('svg', checks)

    def test_the_browser_widget_is_as_before(self):
        checks, problems, lines = web_check.expected_checks({'browser-widget': 'not loaded'}, True, True)
        self.assertNotIn('browser', checks)
        self.assertEqual(problems, ['the standalone has no browser widget: its extension is not loaded (the '
                                    'extensions are none)'])
        checks, problems, lines = web_check.expected_checks({'browser-widget': 'not loaded'}, None, True)
        self.assertEqual(problems, [])
        self.assertEqual(lines, ['the browser widget was not checked: the IDE has none here (no CEF), and so '
                                 'neither has the standalone'])

    def test_the_specification_in_the_zip(self):
        site = self.zip_with('index.html', 'boot/__startup.data',
                             'boot/standalone/extension3/drawing-svg-specification.txt')
        self.assertEqual(web_check.drawing_resources(site),
                         ['boot/standalone/extension3/drawing-svg-specification.txt'])

    def test_no_specification_in_the_zip(self):
        for names in (('boot/__startup.data',),
                      ('boot/standalone/drawing-svg-specification.txt',),
                      ('boot/standalone/extension3/sub/drawing-svg-specification.txt',),
                      ('extension3/drawing-svg-specification.txt',)):
            self.assertEqual(web_check.drawing_resources(self.zip_with(*names)), [], names)

    def test_the_library_reads_that_file(self):
        library = read('extensions', 'script-libraries', 'drawing', 'drawing.livecodescript')
        self.assertIn('slash & "%s"' % web_check.DRAWING_SPEC, library.split('private command svgSpecLoad', 1)[1])
        self.assertTrue(os.path.isfile(os.path.join(REPO, 'extensions', 'script-libraries', 'drawing', 'resources',
                                                    web_check.DRAWING_SPEC)))
        self.assertIn('script "%s"' % web_check.DRAWING_EXTENSION, library)

    def test_the_ide_names_the_library(self):
        deploy = read('tools', 'ci', 'web-deploy.livecodescript')
        build = deploy.split('on webBuild', 1)[1].split('end webBuild', 1)[0]
        self.assertIn('repeat for each item tExtension in "com.livecode.widget.browser,%s"'
                      % web_check.DRAWING_EXTENSION, build)
        self.assertIn('put tExtension after tSettings["extensions"]', build)
        self.assertIn('webLog "INFO drawing-extension-loaded" && \\\n            ("%s" is among the lines of '
                      'the loadedExtensions)' % web_check.DRAWING_EXTENSION, build)
        # ... before the builder runs
        self.assertLess(build.index('INFO drawing-extension-loaded'), build.index('revSaveAsEmscriptenStandalone'))
        check = read('tools', 'ci', 'web_check.py')
        self.assertIn("if line.startswith('INFO drawing-extension-loaded '):", check)

    def test_the_probe_compiles_the_desktop_case(self):
        probe = read('tools', 'ci', 'web-probe.livecodescript')
        run = re.search(r'repeat for each item tCheck in "([^"]+)"', probe.split('on probeRun', 1)[1]).group(1)
        self.assertIn('probeExternals,probeDrawing,', run)
        body = probe.split('command probeDrawing', 1)[1].split('end probeDrawing', 1)[0]
        self.assertIn('if "%s" is not among the lines of tExtensions then\n'
                      '      probeInfo "drawing-library", "not loaded"\n'
                      '      exit probeDrawing' % web_check.DRAWING_EXTENSION, body)
        self.assertIn('probeCheck "svg", tError is empty and tMd5 is ', body)
        self.assertIn('and tSize is "100x100"', body)
        # The SVG and MD5 of the drawing library's own "rect" case, which the
        # desktop library compiles (TestCompileUnchanged)
        tests = read('extensions', 'script-libraries', 'drawing', 'tests', 'drawing.livecodescript')
        case = re.search(r'put "rect\|([^|]+)\|([0-9a-f]{32})"', tests)
        self.assertIsNotNone(case)
        self.assertIn('tMd5 is "%s"' % case.group(2), body)
        # the probe's SVG is _Svg(<the case>), whose size is 100 when none
        # is given
        helper = tests.split('private function _Svg pBody, pSize', 1)[1].split('end _Svg', 1)[0]
        self.assertIn('if pSize is empty then put "100" into pSize', helper)
        self.assertIn('return "<svg xmlns=" & quote & "http://www.w3.org/2000/svg" & quote && "width=" & quote & '
                      'pSize & quote && \\\n         "height=" & quote & pSize & quote & ">" & pBody & "</svg>"',
                      helper)
        svg = re.search(r'\n   put ("<svg.+?) into tSvg\n', body, re.S).group(1).replace('\\\n', ' ')
        self.assertEqual(livecode_text(svg), '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">'
                         + case.group(1) + '</svg>')


if __name__ == '__main__':
    unittest.main()


class FakeError(Exception):
    """Playwright's Error, for the pages below"""


class FakeTimeout(FakeError):
    """Playwright's TimeoutError, a kind of its Error"""


class FakePage:
    """A page that gives the states in turn from evaluate, and crashes
    (its crash handlers, then FakeError) when the next state is 'crash'"""

    def __init__(self, states, message='Target page, context or browser has been closed'):
        self.states = list(states)
        self.message = message
        self.handlers = {}
        self.url = None

    def on(self, event, handler):
        self.handlers.setdefault(event, []).append(handler)

    def goto(self, url):
        self.url = url

    def evaluate(self, js):
        assert js == web_check.PAGE_STATE_JS
        state = self.states.pop(0)
        if state == 'crash':
            for handler in self.handlers.get('crash', []):
                handler(self)
            raise FakeError(self.message)
        return state

    def wait_for_timeout(self, ms):
        pass


class FakeContext:
    def __init__(self, *pages):
        self.pages = list(pages)
        self.opened = []

    def new_page(self):
        page = self.pages.pop(0)
        self.opened.append(page)
        return page


class ExtraPagesInWebKit(unittest.TestCase):
    """The pages opened after the probe's: one more try for a page that
    crashed before its engine started, as WebKit 26.0's did on 3 November,
    and none for anything else"""

    def open(self, context, seconds=120, clock=None):
        self.prepared, self.reopened = [], []
        kwargs = {'clock': clock} if clock else {}
        return web_check.open_ready_page(context, 'http://x/WebProbe.html?tab=colors', 'the page as built', seconds,
                                         lambda page, name: self.prepared.append(name), self.reopened.append,
                                         FakeError, FakeTimeout, **kwargs)

    def test_a_page_that_opens(self):
        page = FakePage(['loading', 'started', 'ready'])
        self.assertIs(self.open(FakeContext(page)), page)
        self.assertEqual(page.url, 'http://x/WebProbe.html?tab=colors')
        self.assertEqual(self.prepared, ['the page as built'])
        self.assertEqual(self.reopened, [])

    def test_a_crash_before_the_engine_started_is_tried_again(self):
        crashed, second = FakePage(['loading', 'crash']), FakePage(['ready'])
        context = FakeContext(crashed, second)
        self.assertIs(self.open(context), second)
        self.assertEqual(context.opened, [crashed, second])
        self.assertEqual(self.prepared, ['the page as built'] * 2)
        self.assertEqual(self.reopened, ['the page as built'])

    def test_a_crash_the_error_names_is_tried_again(self):
        crashed, second = FakePage(['crash'], message='Target crashed'), FakePage(['ready'])
        crashed.handlers = {}
        crashed.on = lambda event, handler: None  # (its crash event never came)
        self.assertIs(self.open(FakeContext(crashed, second)), second)
        self.assertEqual(self.reopened, ['the page as built'])

    def test_a_second_crash_fails(self):
        context = FakeContext(FakePage(['crash']), FakePage(['loading', 'crash']), FakePage(['ready']))
        with self.assertRaises(FakeError):
            self.open(context)
        self.assertEqual(len(context.opened), 2)
        self.assertEqual(self.reopened, ['the page as built'])

    def test_a_crash_after_the_engine_started_fails(self):
        context = FakeContext(FakePage(['loading', 'started', 'crash']), FakePage(['ready']))
        with self.assertRaises(FakeError):
            self.open(context)
        self.assertEqual(len(context.opened), 1)
        self.assertEqual(self.reopened, [])

    def test_an_error_that_is_not_a_crash_fails(self):
        page = FakePage(['loading'])
        page.evaluate = lambda js: (_ for _ in ()).throw(FakeError('Execution context was destroyed'))
        context = FakeContext(page, FakePage(['ready']))
        with self.assertRaises(FakeError):
            self.open(context)
        self.assertEqual(self.reopened, [])

    def test_a_stack_that_never_opens_times_out(self):
        times = iter([0, 1, 2, 200])
        context = FakeContext(FakePage(['started'] * 4), FakePage(['ready']))
        with self.assertRaises(FakeTimeout) as caught:
            self.open(context, seconds=120, clock=lambda: next(times))
        self.assertIn('the page as built did not open its stack within 120 seconds (its engine started)',
                      str(caught.exception))
        self.assertEqual(self.reopened, [])

    def test_every_page_after_the_probes_opens_so(self):
        source = read('tools', 'ci', 'web_check.py')
        self.assertEqual(source.count('open_extra(tabs, '), 1)
        self.assertEqual(source.count('open_extra(profile, '), 1)
        self.assertEqual(source.count('open_extra(dark, '), 1)
        self.assertEqual(source.count('open_extra(light, '), 1)
        # and none waits for its stack in the old way, without the retry
        self.assertNotIn('tab.wait_for_function(', source)
        self.assertNotIn("fresh.goto(url", source)


def _png(width, height, pixel):
    """A PNG of width x height, RGB, each point pixel(x, y), with a
    different filter on each row (0 to 4), as Chromium's screenshots mix
    them"""
    import struct
    import zlib

    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    raw = bytearray()
    previous = bytearray(width * 3)
    for y in range(height):
        line = bytearray()
        for x in range(width):
            line.extend(pixel(x, y))
        kind = y % 5
        out = bytearray()
        for i in range(len(line)):
            left = line[i - 3] if i >= 3 else 0
            up = previous[i]
            corner = previous[i - 3] if i >= 3 else 0
            if kind == 0:
                predict = 0
            elif kind == 1:
                predict = left
            elif kind == 2:
                predict = up
            elif kind == 3:
                predict = (left + up) >> 1
            else:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                predict = left if pa <= pb and pa <= pc else up if pb <= pc else corner
            out.append((line[i] - predict) & 255)
        raw.append(kind)
        raw.extend(out)
        previous = line
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(bytes(raw))) + chunk(b'IEND', b''))


def _list(back, words, hilite=(51, 153, 255), width=120, height=90):
    """A picture of an option menu's list: a 1-point grey border, the first
    line hilited, and a word of each other line drawn as a bar of the words'
    colour at the left"""
    def pixel(x, y):
        if x == 0 or y == 0 or x == width - 1 or y == height - 1:
            return (160, 160, 160)
        if y < 26:
            return hilite if not (6 < x < 40 and 10 < y < 18) else (255, 255, 255)
        line = (y - 26) // 20
        if 6 < x < 30 + 6 * line and 30 + 20 * line < y < 38 + 20 * line:
            return words
        return back
    return _png(width, height, pixel)


class TheMenuLists(unittest.TestCase):
    """The colours of option menus' lists (seth's report of rc.6.12: a web
    app's option menu, light words on a dark button, opened as light grey
    words on white): web_check.py reads a picture of each list's window,
    and must tell a readable list from one that is not, and a plain list
    changed from as it was."""

    def test_png_pixels_reads_every_filter(self):
        data = _png(7, 10, lambda x, y: (x * 30, y * 20, (x * y) % 256))
        width, height, rows = web_check.png_pixels(data)
        self.assertEqual((width, height), (7, 10))
        for y in range(10):
            for x in range(7):
                self.assertEqual(rows[y][x], (x * 30, y * 20, (x * y) % 256))

    def test_a_printed_picture_comes_back_from_the_log(self):
        import contextlib
        import io
        import tempfile
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        import print_images
        data = _png(90, 70, lambda x, y: (x, y, 200))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            web_check.print_image('webkit/menu-list-as-built-plain.png', data)
        self.assertTrue(out.getvalue().startswith('IMAGE webkit/menu-list-as-built-plain.png 1/'))
        with tempfile.TemporaryDirectory() as folder:
            log = os.path.join(folder, 'log.txt')
            with open(log, 'w') as f:
                f.write(''.join('2026-11-05T12:00:00.0Z ' + line + '\n' for line in out.getvalue().splitlines()))
            with contextlib.redirect_stdout(io.StringIO()):
                print_images.main([log, os.path.join(folder, 'out')])
            with open(os.path.join(folder, 'out', 'webkit-menu-list-as-built-plain.png'), 'rb') as f:
                self.assertEqual(f.read(), data)

    def test_png_pixels_refuses_what_it_cannot_read(self):
        with self.assertRaises(ValueError):
            web_check.png_pixels(b'GIF89a')

    def test_light_grey_words_on_white_are_unreadable(self):
        back, words, ratio = web_check.menu_list_colours(*web_check.png_pixels(_list((255, 255, 255), (240, 240, 240))))
        self.assertEqual(back, (255, 255, 255))
        self.assertEqual(words, (240, 240, 240))
        self.assertLess(ratio, 1.2)
        problem = web_check.menu_list_problem('as built', 'light-text', 4.5, None, back, words, ratio)
        self.assertIn('expected a contrast of 4.5 or more', problem)

    def test_black_on_the_dark_list_is_unreadable(self):
        back, words, ratio = web_check.menu_list_colours(*web_check.png_pixels(_list((32, 32, 32), (0, 0, 0))))
        self.assertLess(ratio, 1.5)
        self.assertTrue(web_check.menu_list_problem('following the browser', 'black-text', 4.5, None,
                                                    back, words, ratio))

    def test_the_hilited_line_is_not_read(self):
        # the white words of the hilited first line are not the list's
        back, words, _ = web_check.menu_list_colours(*web_check.png_pixels(_list((48, 52, 62), (230, 230, 235))))
        self.assertEqual((back, words), ((48, 52, 62), (230, 230, 235)))

    def test_readable_lists_pass(self):
        for where, kind, least, want in web_check.MENU_LISTS:
            if kind == 'plain':
                picture = _list(want, (0, 0, 0) if want == (255, 255, 255) else (255, 255, 255))
            else:
                picture = _list((48, 52, 62), (230, 230, 235)) if kind == 'light-text' \
                    else _list((32, 32, 32), (255, 255, 255))
            colours = web_check.menu_list_colours(*web_check.png_pixels(picture))
            self.assertIsNone(web_check.menu_list_problem(where, kind, least, want, *colours), (where, kind))

    def test_a_plain_list_must_stay_as_it_was(self):
        colours = web_check.menu_list_colours(*web_check.png_pixels(_list((48, 52, 62), (230, 230, 235))))
        problem = web_check.menu_list_problem('as built', 'plain', 15.0, (255, 255, 255), *colours)
        self.assertIn('expected the list rgb(255,255,255) as before', problem)

    def test_each_kind_is_one_the_probe_makes(self):
        probe = read('tools', 'ci', 'web-probe.livecodescript')
        for _, kind, _, _ in web_check.MENU_LISTS:
            self.assertIn(kind, web_check.MENU_KINDS)
            if kind != 'plain':
                self.assertIn('pKind is "%s"' % kind, probe)
        self.assertIn('word 1 of pWhat is "menu-colors"', probe)
        self.assertIn('pWhat is "menu-colors-done"', probe)

    def test_both_pages_read_their_lists(self):
        script = read('tools', 'ci', 'web_check.py')
        self.assertEqual(script.count('= read_menu_list(page, where'), 1)
        self.assertEqual(script.count('= read_menu_list(tab, where'), 1)
        self.assertEqual({where for where, _, _, _ in web_check.MENU_LISTS},
                         {'as built', 'following the browser'})
