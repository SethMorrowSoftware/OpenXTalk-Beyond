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


if __name__ == '__main__':
    unittest.main()
