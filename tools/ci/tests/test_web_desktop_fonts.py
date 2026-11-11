#!/usr/bin/env python3
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License v3 as published by the
# Free Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

"""The web standalones' desktop fonts hold together: the files that
tools/oxt/build_web_desktop_fonts.py writes are the families that the web
engine's table (engine/src/em-font.cpp) names, in their four styles; the
web runtime (tools/ci/build-web.sh), the package (tools/oxt/package.py) and
the builder (revsaveasemscriptenstandalone) carry the same folder; and the
Web pane's value is the one the builder reads. The engine's behaviour is
tested on the web engine itself (tests/lcs/core/interface/
web-desktop-fonts.livecodescript, by tools/ci/web_tests.py)."""

import os
import re
import struct
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
FOLDER = 'emscripten-desktop-fonts'
FONTS = os.path.join(REPO, 'engine', 'rsrc', FOLDER)
STYLES = ('Regular', 'Bold', 'Italic', 'BoldItalic')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def font_names(path, platform=3):
    """{name ID: text} of a TrueType file's Windows Unicode names, or with
    platform 1 its Macintosh Roman (English) ones"""
    with open(path, 'rb') as f:
        data = f.read()
    count = struct.unpack('>H', data[4:6])[0]
    tables = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack('>4sIII', data[12 + 16 * i:28 + 16 * i])
        tables[tag] = (offset, length)
    offset, _ = tables[b'name']
    _, records, strings = struct.unpack('>HHH', data[offset:offset + 6])
    names = {}
    for i in range(records):
        record_platform, encoding, language, name_id, length, at = struct.unpack(
            '>HHHHHH', data[offset + 6 + 12 * i:offset + 18 + 12 * i])
        record = (record_platform, encoding, language)
        start = offset + strings + at
        if platform == 3 and record == (3, 1, 0x409):
            names[name_id] = data[start:start + length].decode('utf-16-be')
        elif platform == 1 and record == (1, 0, 0):
            names[name_id] = data[start:start + length].decode('mac_roman')
    return names


def stand_ins():
    """(name, family) of the engine's table"""
    source = read('engine', 'src', 'em-font.cpp')
    table = source.split('kMCEmscriptenFontStandIns[][2] =', 1)[1].split('};', 1)[0]
    return re.findall(r'\{"([^"]+)", "([^"]+)"\}', table)


class TheFonts(unittest.TestCase):
    def test_the_files_are_the_tables_families(self):
        families = sorted(set(family for _, family in stand_ins()))
        self.assertEqual(families, ['Arimo', 'Cousine', 'Tinos'])
        want = sorted('%s-%s.ttf' % (family, style) for family in families for style in STYLES)
        self.assertEqual(sorted(x for x in os.listdir(FONTS) if not x.startswith('.')), want)

    def test_each_file_is_its_family(self):
        # the engine finds a font by its family name (customfont.cpp), and
        # the style by the subfamily
        for name in os.listdir(FONTS):
            if not name.endswith('.ttf'):
                continue
            family, style = name[:-len('.ttf')].split('-')
            names = font_names(os.path.join(FONTS, name))
            self.assertEqual(names.get(1), family, name)
            self.assertEqual(names.get(2, '').replace(' ', ''), style, name)
            # the licence goes with them: the SIL Open Font License
            self.assertIn('SIL Open Font License', names.get(13, ''), name)
            # the engine skips a file without a Macintosh full name
            # (MCFreeTypeGetFontInfoFromData, engine/src/freetype-font.cpp)
            mac = font_names(os.path.join(FONTS, name), 1)
            self.assertEqual(mac.get(4), names.get(4), name)
            self.assertEqual(mac.get(4), '%s %s' % (family, names.get(2)), name)

    def test_the_engine_reads_the_mac_full_name(self):
        # what test_each_file_is_its_family holds the files to
        source = read('engine', 'src', 'freetype-font.cpp')
        self.assertIn('t_sft_name.name_id == 4 && t_sft_name.platform_id == 1 && '
                      't_sft_name.encoding_id == 0 && t_sft_name.language_id == 0', source)

    def test_the_fonts_keep_their_whole_path(self):
        # a font is read again from its path whenever a font is made from
        # it: the folder's entries are file names alone, and the
        # defaultFolder is seldom the fonts folder by then
        source = read('engine', 'src', 'em-font.cpp')
        callback = source.split('MCEmscriptenCustomFontLoadCallback(void *p_context', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('MCStringFormat(&t_path, "%s/%@", MCEMSCRIPTEN_FONT_FOLDER, p_entry->name)', callback)
        self.assertIn('MCEmscriptenCreateCustomFontFromPath(*t_path,', callback)
        self.assertNotIn('MCEmscriptenCreateCustomFontFromPath(p_entry->name', callback)

    def test_a_desktop_name_falls_back_to_its_family(self):
        source = read('engine', 'src', 'em-font.cpp')
        create = source.split('void* MCEmscriptenFontCreate(', 1)[1].split('\n}\n', 1)[0]
        self.assertLess(create.index('MCSkiaTypefaceCreateWithName(*t_stand_in,'),
                        create.index('MCSkiaTypefaceCreateWithName(p_name,'))

    def test_the_builder_script_makes_these_files(self):
        script = read('tools', 'oxt', 'build_web_desktop_fonts.py')
        sources = re.findall(r'^    "([A-Za-z]+-[A-Za-z]+\.ttf)": "[0-9a-f]{64}",$', script, re.M)
        self.assertEqual(sorted(sources), sorted(x for x in os.listdir(FONTS) if x.endswith('.ttf')))
        self.assertIn('OUT_DIR = os.path.join(ROOT, "engine", "rsrc", "%s")' % FOLDER, script)

    def test_no_name_maps_to_itself_or_twice(self):
        names = [name.lower() for name, _ in stand_ins()]
        self.assertEqual(len(names), len(set(names)))
        families = set(family.lower() for _, family in stand_ins())
        self.assertFalse(families & set(names))

    def test_the_metric_names_have_their_family(self):
        table = dict(stand_ins())
        for name in ('Arial', 'Helvetica', 'Liberation Sans'):
            self.assertEqual(table[name], 'Arimo')
        for name in ('Times New Roman', 'Times', 'Liberation Serif'):
            self.assertEqual(table[name], 'Tinos')
        for name in ('Courier New', 'Courier', 'Liberation Mono'):
            self.assertEqual(table[name], 'Cousine')


class OneFolderAndValue(unittest.TestCase):
    def test_the_runtime_carries_them(self):
        script = read('tools', 'ci', 'build-web.sh')
        self.assertIn('cp -R engine/rsrc/%s "${OUT}/"' % FOLDER, script)
        self.assertIn('-name \'*.ttf\' -type f | wc -l)" -eq 12 ]', script)

    def test_the_package_carries_them(self):
        script = read('tools', 'oxt', 'package.py')
        self.assertIn("WEB_DESKTOP_FONTS_FOLDER = '%s'" % FOLDER, script)
        self.assertIn('os.path.join(web, WEB_DESKTOP_FONTS_FOLDER)', script)

    def test_the_builder_adds_them_when_asked(self):
        script = read('ide-support', 'revsaveasemscriptenstandalone.livecodescript')
        self.assertIn('return mapResPath("%s")' % FOLDER, script)
        self.assertIn('if pSettings["emscripten,fonts"] is "desktop" then\n         storeDesktopFonts tBuildZip',
                      script)
        self.assertIn('revZipAddUncompressedItemWithFile pBuildZip, "boot/standalone/" & tFile', script)

    def test_the_pane_sets_it(self):
        pane = read('ide', 'Toolset', 'palettes', 'standalone settings',
                    'revstandalonesettingsemscriptenbehavior.livecodescript')
        self.assertIn('constant kFontsValues = ",desktop"', pane)
        # as many menu items as values: the menu is the items, a line each
        items = re.search(r'^constant kFontsItems = "([^"]+)"', pane, re.M).group(1).split(',')
        self.assertEqual(len(items), 2)
        self.assertTrue(items[1].startswith('Desktop fonts'))
        self.assertIn('setSetting "emscripten,fonts", item (the menuHistory of the target) of kFontsValues', pane)
        controls = re.search(r'^constant kWebSettingsControls = "([^"]+)"', pane, re.M).group(1).split(',')
        self.assertIn('emscriptenFonts', controls)
        self.assertIn('emscriptenFontsLabel', controls)

    def test_the_player_asks_for_them(self):
        script = read('tools', 'web-player', 'build-player.livecodescript')
        self.assertIn('put "desktop" into pSettings["emscripten,fonts"]', script)

    def test_the_web_tests_get_arimo(self):
        # web_tests.py copies a repository file that a test names this way
        test = read('tests', 'lcs', 'core', 'interface', 'web-desktop-fonts.livecodescript')
        self.assertIn('TestGetEngineRepositoryPath() & "/engine/rsrc/%s/Arimo-Regular.ttf"' % FOLDER, test)


if __name__ == '__main__':
    unittest.main()
