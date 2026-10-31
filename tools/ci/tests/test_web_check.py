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


if __name__ == '__main__':
    unittest.main()
