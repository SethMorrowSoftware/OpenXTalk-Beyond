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
