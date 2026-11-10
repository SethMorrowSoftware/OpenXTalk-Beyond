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
"""A widget installed or uninstalled shows, or goes, in the Tools palette
at once, in either look (bwmilby, forum, 2026-11-07). The palette's
subscription to ideExtensionsChanged was commented out, so it took a
switch of look or a restart. It is subscribed again, as in LiveCode, and
the palette is made again only when the widgets it shows have changed
(a library loaded, or the batch at start-up, leaves it as it is); a palette
closed meanwhile is made again when it opens. The IDE tour's step
tools-widget-install and ide/tests/tools/widgetinstall run it on an engine.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PALETTE = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'tools', 'revtools.livecodescript')
TOUR = os.path.join(REPO, 'tools', 'ci', 'ui-tour.livecodescript')
IDE_TEST = os.path.join(REPO, 'ide', 'tests', 'tools', 'widgetinstall.livecodescript')
EXTENSIONS = os.path.join(REPO, 'ide', 'Toolset', 'libraries', 'revideextensionlibrary.livecodescript')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def handler(text, name):
    m = re.search(r'^[ \t]*(?:private[ \t]+)?(?:command|on|function)[ \t]+%s\b(.*?)^[ \t]*end[ \t]+%s\b'
                  % (re.escape(name), re.escape(name)), text, re.M | re.S)
    if m is None:
        raise AssertionError('no handler ' + name)
    return m.group(1)


def code(body):
    return '\n'.join(line.split('--', 1)[0] for line in body.splitlines())


class WidgetInstallTest(unittest.TestCase):
    def setUp(self):
        self.text = read(PALETTE)

    def test_palette_hears_extensions_changed(self):
        body = code(handler(self.text, 'registerForMessages'))
        self.assertRegex(body, re.compile(r'^\s*revIDESubscribe "ideExtensionsChanged"\s*$', re.M))
        self.assertNotIn('-- revIDESubscribe "ideExtensionsChanged"', handler(self.text, 'registerForMessages'))

    def test_extension_library_still_sends_it(self):
        self.assertIn('ideMessageSend "ideExtensionsChanged"', code(read(EXTENSIONS)))

    def test_rebuilds_only_when_the_widgets_changed(self):
        body = code(handler(self.text, 'ideExtensionsChanged'))
        gate = body.index('if not toolsWidgetsChanged() then exit ideExtensionsChanged')
        self.assertLess(gate, body.index('generatePalette'))
        self.assertLess(body.index('generatePalette'), body.index('layoutPalette'))

    def test_signature_reads_what_the_palette_reads(self):
        sig = code(handler(self.text, 'toolsWidgetSignature'))
        self.assertIn('put revIDEWidgets() into tData', sig)
        self.assertIn('sort lines of tKeys', sig)
        for key in ('version', 'title', 'icon', 'svgicon'):
            self.assertIn('tData[tKey]["%s"]' % key, sig)
        changed = code(handler(self.text, 'toolsWidgetsChanged'))
        self.assertIn('return toolsWidgetSignature() is not sToolsWidgetSig', changed)

    def test_both_looks_record_what_they_were_made_with(self):
        # the classic look, after the modern look's early exit
        classic = code(handler(self.text, 'generatePalette'))
        self.assertLess(classic.index('tmGenerate'), classic.index('put toolsWidgetSignature() into sToolsWidgetSig'))
        modern = code(handler(self.text, 'tmGenerate'))
        self.assertLess(modern.index('put toolsWidgetSignature() into sToolsWidgetSig'), modern.index('put tmViewsData() into tData'))

    def test_reopened_palette_catches_up(self):
        body = code(handler(self.text, 'openStack'))
        self.assertRegex(body, r'if there is a group "contents" of me and toolsWidgetsChanged\(\) then\s+generatePalette')
        self.assertLess(body.index('toolsWidgetsChanged()'), body.index('layoutpalette'))

    def test_script_local_declared_above_its_readers(self):
        decl = self.text.index('local sToolsWidgetSig')
        for name in ('openStack', 'toolsWidgetsChanged', 'generatePalette', 'tmGenerate'):
            self.assertLess(decl, re.search(r'^(?:private )?(?:on|command|function) %s\b' % name, self.text, re.M).start())

    def test_tour_step(self):
        tour = read(TOUR)
        steps = [l for l in tour.splitlines() if l.startswith('constant kSteps')][0].split('"')[1].split(',')
        self.assertEqual(steps.index('tools-widget-install'), steps.index('tools-modern-default') + 1)
        self.assertEqual(steps.index('tools-widget-builder'), steps.index('tools-widget-install') + 1)
        body = handler(tour, 'tour_tools_widget_install')
        for needle in ('revIDEExtensionUnload kTourWidgetID', 'revIDEExtensionReload kTourWidgetID',
                       'repeat for each item tLook in "modern,classic"', 'close stack "revTools"',
                       'kTourWidgetLibrary', 'tourTmFinish "tools-widget-install"', 'tourTmReset'):
            self.assertIn(needle, body)
        # the Spinner is loaded again whatever fails
        after = body.split('end try', 1)[1]
        self.assertIn('revIDEExtensionReload kTourWidgetID', after)

    def test_builder_install_and_manager_uninstall(self):
        # Brian's own way: the Extension Builder's Install button and the
        # Extension Manager's Uninstall, which both end in the extension
        # library's batched ideExtensionsChanged
        lib = read(EXTENSIONS)
        for name in ('revIDEExtensionInstall', 'revIDEExtensionUninstall'):
            self.assertIn('__extensionsChanged', code(handler(lib, name)))
        dev = read(os.path.join(REPO, 'ide', 'Toolset', 'libraries', 'revidedeveloperextensionlibrary.livecodescript'))
        self.assertIn('revIDEExtensionInstall tPackage', code(handler(dev, 'revIDEDeveloperExtensionInstall')))
        tour = read(TOUR)
        body = handler(tour, 'tour_tools_widget_builder')
        for needle in ('revIDEDeveloperExtensionInstall tFolder', 'revIDEExtensionUninstall kTourBuilderWidget',
                       'repeat for each item tLook in "modern,classic"', 'tourTmFinish "tools-widget-builder"'):
            self.assertIn(needle, body)
        self.assertIn('revIDEExtensionUninstall kTourBuilderWidget', body.split('end try', 1)[1])
        ide = read(IDE_TEST)
        body = handler(ide, 'TestBuilderInstallManagerUninstall')
        self.assertIn('revIDEDeveloperExtensionInstall tFolder', body)
        self.assertIn('revIDEExtensionUninstall kBuilt', body)
        self.assertIn('revIDEExtensionUninstall kBuilt', handler(ide, 'TestTeardown'))

    def test_classic_look_shows_widgets_for_its_checks(self):
        # The classic look builds only the sections its Show Sections
        # setting (revTools_show) lists, and Home's default leaves out the
        # widgets: the classic checks turn them on, and the setting is
        # given back whatever fails (tools-modern-check holds it)
        home = read(os.path.join(REPO, 'ide', 'Toolset', 'home.livecodescript'))
        default = re.search(r'put "([^"]*)" into tPropsArray\["revTools_show"\]', home).group(1)
        self.assertNotIn('widget', default.split(','))
        tour = read(TOUR)
        show = code(handler(tour, 'tourClassicShowWidgets'))
        self.assertIn('revIDESetPreference "revTools_show", "widget," & tShow', show)
        self.assertIn('revIDESetPreference "revTools_show", pShow', code(handler(tour, 'tourClassicShowRestore')))
        for step in ('tour_tools_widget_install', 'tour_tools_widget_builder'):
            body = code(handler(tour, step))
            classic = body.index('tourToolsClassic')
            self.assertLess(classic, body.index('put tourClassicShowWidgets() into tShowWas'))
            self.assertIn('tourClassicShowRestore tShowWas', body.split('end try', 1)[1])
        ide = read(IDE_TEST)
        self.assertIn('revIDESetPreference "revTools_show", "widget," & tShow', code(handler(ide, '__SetLook')))
        self.assertIn('revIDESetPreference "revTools_show", sShow', code(handler(ide, 'TestTeardown')))
        self.assertIn('put revIDEGetPreference("revTools_show") into sShow', code(handler(ide, 'TestSetup')))

    def test_ide_test(self):
        text = read(IDE_TEST)
        for name in ('TestModernLook', 'TestClassicLook', 'TestWhileClosed', 'TestLibraryLeavesPalette'):
            handler(text, name)
        self.assertIn('revIDEExtensionReload kWidget', code(handler(text, 'TestTeardown')))


class ExtensionManagerHiliteTest(unittest.TestCase):
    """The Extension Manager's selected row in the dark appearance: the
    edition's light selection colour under the white name was unreadable
    (bwmilby, forum, 2026-11-07, on the Mac); it is darkened there and kept
    in the light appearance."""

    LIST = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'extension manager',
                        'revideextensionmanagerlistbehavior.livecodescript')

    def setUp(self):
        self.text = read(self.LIST)

    def test_list_uses_it(self):
        body = code(handler(self.text, 'setUpExtensionList'))
        self.assertRegex(body, r'viewProp\["hilite color"\][^\n]*to \\\s*extensionsHiliteColor\(ideColorGet\("pb_line_selected"\), revIDEAppearanceIsDark\(\)\)')
        self.assertNotRegex(body, r'viewProp\["hilite color"\][^\n]*to ideColorGet')

    def mirror(self, color, dark):
        # the handler, in Python, checked against its source below
        if not dark:
            return color
        parts = color.split(',')
        if len(parts) != 3 or not all(p.strip().isdigit() for p in parts):
            return color
        return ','.join(str(int(int(p) * 4 / 10 + 0.5)) for p in parts)

    def test_function(self):
        body = code(handler(self.text, 'extensionsHiliteColor'))
        self.assertIn('if pDark is not true then return pColor', body)
        self.assertIn('round(tChannel * 4 / 10)', body)
        for edition in ('240,200,180', '226,238,185', '222,243,255'):
            dark = [int(c) for c in self.mirror(edition, True).split(',')]
            avg = sum(dark) / 3
            self.assertGreater(255 - avg, 150, edition)
            self.assertGreater(avg - 42, 25, edition)
        self.assertEqual(self.mirror('240,200,180', True), '96,80,72')
        self.assertEqual(self.mirror('226,238,185', True), '90,95,74')

    def test_tests(self):
        ide = read(os.path.join(REPO, 'ide', 'tests', 'extensionmanager', 'hilitecolor.livecodescript'))
        self.assertIn('tDark is "96,80,72"', ide)
        tour = handler(read(TOUR), 'tour_extension_manager')
        self.assertIn('viewProp["hilite color"]', tour)


if __name__ == '__main__':
    unittest.main()
