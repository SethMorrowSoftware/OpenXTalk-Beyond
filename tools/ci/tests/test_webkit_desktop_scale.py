#!/usr/bin/env python3
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

"""The Linux browser widget through WebKitGTK on a scaled desktop.

On a desktop at 200% the engine gives the WebKitGTK helper its scale
(--scale 2, which the helper makes GDK_SCALE). With the scale given, GTK 3
takes the desktop's Xft/DPI for its text and not Gdk/UnscaledDPI, and a
desktop that scales as GNOME does has the scale in Xft/DPI already (192).
WebKitGTK zooms a page by that DPI: with 0.2.8-dp.2 a page was drawn at 4
pixels a point in a view of 2, everything in it double, the Dictionary's
page too (bwmilby on the forum, Ubuntu 26.04 with Externals/CEF renamed).
On an Xvfb screen with xsettingsd publishing GNOME's three settings,
0.2.8-dp.2's standalone and helper gave window.innerWidth 320 in a widget
640 points wide and devicePixelRatio 4; with the helper of this change,
640 and 2, as CEF gives there.

The helper now gives GTK the desktop's unscaled DPI. The Linux build runs
the browser widget on such a desktop (tools/ci/media_check.py
--desktop-scale 2), with WebKitGTK and with CEF.

    python3 -m unittest discover -s tools/ci/tests -p 'test_webkit_desktop_scale.py'
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import hidpi_check  # noqa: E402
import media_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def code(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return '\n'.join(line for line in text.split('\n') if not line.strip().startswith('//'))


class Helper(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = read('libbrowser', 'src', 'libbrowser_webkitprocess_lnx.cpp')
        cls.code = code(cls.text)

    def test_the_text_has_the_desktops_unscaled_dpi(self):
        m = re.search(r'^static void MCUseUnscaledFontDpi\(void\)\n\{.*?^\}', self.code, re.M | re.S)
        self.assertIsNotNone(m)
        body = m.group(0)
        self.assertIn('p_gdk_screen_get_setting(t_screen, "gdk-unscaled-dpi", &t_value)', body)
        self.assertIn('p_g_object_set(t_settings, "gtk-xft-dpi", t_dpi, (void *)nullptr);', body)
        # a desktop that publishes none (Xft.dpi alone, GDK_SCALE) is left
        # as it was: nothing is set but under the setting's own if
        self.assertLess(body.index('if (p_gdk_screen_get_setting('), body.index('p_g_object_set('))
        self.assertIn('if (t_dpi > 0)', body)

    def test_only_with_the_scale_the_engine_gave_and_before_the_view(self):
        main = self.code[self.code.index('int main(int argc, char *argv[])'):]
        call = 'if (t_scale > 1)\n\t\tMCUseUnscaledFontDpi();'
        self.assertEqual(main.count(call), 1)
        self.assertLess(main.index('p_gtk_init_check(nullptr, nullptr)'), main.index(call))
        self.assertLess(main.index(call), main.index('p_webkit_web_view_new_with_user_content_manager('))

    def test_the_functions_are_loaded_with_the_rest(self):
        table = self.text[self.text.index('#define MC_WEBKIT_FUNCTIONS(F)'):]
        table = table[:table.index('\n\n')]
        for line in ('F(void *, gdk_screen_get_default, (void))',
                     'F(gboolean, gdk_screen_get_setting, (void *screen, const gchar *name, MCGValue *value))',
                     'F(void *, gtk_settings_get_default, (void))',
                     'F(void, g_object_set, (gpointer object, const gchar *first_property_name, ...))',
                     'F(MCGValue *, g_value_init, (MCGValue *value, unsigned long type))',
                     'F(int, g_value_get_int, (const MCGValue *value))',
                     'F(void, g_value_unset, (MCGValue *value))'):
            self.assertIn(line, table)

    def test_a_gvalue_is_glibs(self):
        # gobject/gvalue.h: a GType and two unions of 8 bytes; G_TYPE_INT
        # is the sixth fundamental type
        m = re.search(r'struct MCGValue\n\{\n\tunsigned long g_type;\n\tunion\n\t\{(.*?)\} data\[2\];\n\};', self.code, re.S)
        self.assertIsNotNone(m)
        self.assertIn('long long v_int64;', m.group(1))
        self.assertIn('#define MC_G_TYPE_INT (6UL << 2)', self.code)


class Check(unittest.TestCase):
    def test_the_page_says_its_size_before_it_says_it_loaded(self):
        page = media_check.PAGE
        size = "liveCode.oxtReport('size', window.innerWidth + ' ' + window.devicePixelRatio);"
        self.assertIn(size, page)
        self.assertLess(page.index(size), page.index("liveCode.oxtReport('loaded'"))

    def test_the_script_checks_the_page_against_the_widget(self):
        script = read('tools', 'ci', 'media-check.livecodescript')
        widget = script[script.index('command checkWidget pUrl'):script.index('end checkWidget')]
        self.assertIn('checkWidgetScale\n', widget)
        self.assertLess(widget.index('waitFor("oxtReport: loaded", 15)'), widget.index('checkWidgetScale\n'))
        scale = script[script.index('command checkWidgetScale'):script.index('end checkWidgetScale')]
        self.assertIn('if tLine begins with "oxtReport: size " then put word 3 to 4 of tLine into tSize', scale)
        self.assertIn('check "browser widget: the page is as wide as the widget", tWidth is a number and '
                      'abs(tWidth - the width of widget "Browser" of stack "MediaCheck") <= 1', scale)
        self.assertIn('check "browser widget: the page has the screen\'s pixels", tRatio is a number and '
                      'abs(tRatio - tScale) < 0.01', scale)
        self.assertIn('check "browser widget: the engine has the desktop\'s scale", tScale is $OXT_MEDIA_DESKTOP_SCALE', scale)

    def test_the_desktop_is_scaled_as_gnome_scales_one(self):
        text = read('tools', 'ci', 'media_check.py')
        self.assertIn("ap.add_argument('--desktop-scale', type=int, choices=(2, 3)", text)
        self.assertIn('hidpi_check.start_xsettingsd(display, args.desktop_scale, work)', text)
        self.assertIn("env['OXT_MEDIA_DESKTOP_SCALE'] = str(args.desktop_scale)", text)
        self.assertIn("for name in ('GDK_SCALE', 'GDK_DPI_SCALE'):\n                        env.pop(name, None)", text)
        self.assertIn("raise rlc.CheckError('--desktop-scale needs xsettingsd')", text)
        # the three settings: the scale, Xft/DPI with the scale in it and
        # the DPI without
        hidpi = read('tools', 'ci', 'hidpi_check.py')
        self.assertIn("f.write('Gdk/WindowScalingFactor %d\\nGdk/UnscaledDPI %d\\nXft/DPI %d\\n'\n"
                      "                % (scale, 96 * 1024, 96 * 1024 * scale))", hidpi)
        self.assertTrue(callable(hidpi_check.start_xvfb))

    def test_the_linux_build_runs_it_with_both_browsers(self):
        workflow = read('.github', 'workflows', 'build-linux.yml')
        step = workflow[workflow.index('- name: Browser check (a desktop at 200%)'):]
        step = step[:step.index('\n      - name:')] if '\n      - name:' in step else step
        self.assertIn('--browser-backend webkitgtk \\\n            --desktop-scale 2', step)
        self.assertIn('--browser-backend cef \\\n              --desktop-scale 2', step)
        self.assertIn('if [ "$ARCH" = x86_64 ]; then', step)
        self.assertIn('xsettingsd', workflow[:workflow.index('- name: Browser check (a desktop at 200%)')])


if __name__ == '__main__':
    unittest.main()
