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

"""The Linux engine keeps the desktop's name from Chromium while it starts.

With 0.2.8-dp.2 the IDE ended with "Segmentation fault" as its first
browser was made (the Dictionary, a browser widget) on a desktop named
GNOME (Ubuntu 26.04, bwmilby on the forum; Ubuntu 24.04 the same) or Xfce:
0.2.8-dp.2's standalone with XDG_CURRENT_DESKTOP=ubuntu:GNOME, or XFCE, on
a bare Xvfb screen is enough. Chromium 156 asks for the theme of the
desktop it is named, GTK's on those, and loads GTK 3 (GTK 4 where there is
no 3) for it into the engine's process. The engine is a GTK 2 program:
gtk_settings_get_type of the newer GTK gives no type beside GTK 2's
GtkSettings, and CefInitialize reads the class of none (the fault is in
libcef.so, after g_type_class_ref of libgtk-3's gtk_settings_get_type).
With no name (the CI's screens) or KDE's, Chromium loads no GTK.

libbrowser_cef_desktop_lnx.h takes the four variables Chromium reads the
name from out of the environment for the length of CefInitialize, for the
widget and for revBrowser, and puts them back. The Linux build runs both
browsers on a desktop named GNOME and Xfce (tools/ci/media_check.py
--desktop), where a script must still see the name afterwards.

    python3 -m unittest discover -s tools/ci/tests -p 'test_cef_desktop_name.py'
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import media_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))
HEADER = os.path.join(REPO, 'libbrowser', 'src', 'libbrowser_cef_desktop_lnx.h')
# base/nix/xdg_util.cc, GetDesktopEnvironment: the variables it reads
CHROMIUM_READS = ['XDG_CURRENT_DESKTOP', 'DESKTOP_SESSION', 'GNOME_DESKTOP_SESSION_ID', 'KDE_FULL_SESSION']

PROGRAM = r'''
#include "libbrowser_cef_desktop_lnx.h"
#include <stdio.h>
#include <string.h>

static const char *value(const char *p_name)
{
	const char *t_value = getenv(p_name);
	return t_value != nullptr ? t_value : "(unset)";
}

static void say(const char *p_when)
{
	printf("%s", p_when);
	for (int i = 0; i < MCCefLinuxDesktopNameHider::kCount; i++)
		printf(" %s=%s", MCCefLinuxDesktopNameHider::Name(i), value(MCCefLinuxDesktopNameHider::Name(i)));
	printf(" OTHER=%s\n", value("OXT_TEST_OTHER"));
}

int main(void)
{
	say("before");
	{
		MCCefLinuxDesktopNameHider t_hider;
		say("during");
	}
	say("after");
	return 0;
}
'''


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def code(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return '\n'.join(line for line in text.split('\n') if not line.strip().startswith('//'))


class Sources(unittest.TestCase):
    def test_the_names_are_the_ones_chromium_reads(self):
        names = re.findall(r'^\t\t\t"([A-Z_]+)",$', code(read('libbrowser', 'src', 'libbrowser_cef_desktop_lnx.h')), re.M)
        self.assertEqual(names, CHROMIUM_READS)
        self.assertEqual(list(media_check.DESKTOP_VARIABLES), CHROMIUM_READS)

    def test_cef_starts_with_the_name_hidden_in_both_browsers(self):
        for path in ('libbrowser/src/libbrowser_cef.cpp', 'revbrowser/src/cefbrowser.cpp'):
            text = code(read(*path.split('/')))
            self.assertIn('#if defined(__linux__)\n#include "libbrowser_cef_desktop_lnx.h"\n#endif', text, path)
            block = ('#if defined(__linux__)\n\t\t{\n\t\t\tMCCefLinuxDesktopNameHider t_no_desktop_name;\n'
                     '\t\t\tt_success = CefInitialize(t_args, t_settings, t_app, nil);\n\t\t}\n'
                     '#else\n\t\tt_success = CefInitialize(t_args, t_settings, t_app, nil);\n#endif')
            self.assertIn(block, text, path)
            # nowhere else
            self.assertEqual(text.count('CefInitialize(t_args'), 2, path)


@unittest.skipUnless(sys.platform.startswith('linux') and shutil.which('g++'), 'needs Linux and g++')
class Hider(unittest.TestCase):
    """The header itself, built and run."""

    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.mkdtemp(prefix='oxt-desktop-name-')
        source = os.path.join(cls.work, 'hider.cpp')
        with open(source, 'w') as f:
            f.write(PROGRAM)
        cls.program = os.path.join(cls.work, 'hider')
        subprocess.run(['g++', '-std=c++11', '-Wall', '-Werror', '-I', os.path.dirname(HEADER), source, '-o', cls.program],
                       check=True)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work, ignore_errors=True)

    def run_with(self, variables):
        env = {k: v for k, v in os.environ.items() if k not in CHROMIUM_READS}
        env.update(variables, OXT_TEST_OTHER='kept')
        out = subprocess.run([self.program], env=env, stdout=subprocess.PIPE, universal_newlines=True, check=True).stdout
        lines = dict(line.split(' ', 1) for line in out.splitlines())
        return lines['before'], lines['during'], lines['after']

    def test_a_gnome_session(self):
        before, during, after = self.run_with(media_check.DESKTOPS['gnome'])
        self.assertIn('XDG_CURRENT_DESKTOP=ubuntu:GNOME DESKTOP_SESSION=ubuntu GNOME_DESKTOP_SESSION_ID=this-is-deprecated '
                      'KDE_FULL_SESSION=(unset)', before)
        self.assertEqual(during, ' '.join('%s=(unset)' % n for n in CHROMIUM_READS) + ' OTHER=kept')
        self.assertEqual(after, before)

    def test_every_desktop_of_the_check(self):
        for name, variables in media_check.DESKTOPS.items():
            before, during, after = self.run_with(variables)
            self.assertNotIn('=(unset) ' * 4, before + ' ', name)
            self.assertEqual(during, ' '.join('%s=(unset)' % n for n in CHROMIUM_READS) + ' OTHER=kept', name)
            self.assertEqual(after, before, name)

    def test_a_variable_that_was_not_there_is_not_made(self):
        before, during, after = self.run_with({})
        self.assertEqual(before, during)
        self.assertEqual(after, before)
        self.assertNotIn('DESKTOP_SESSION= ', after)

    def test_an_empty_value_comes_back_empty(self):
        before, during, after = self.run_with({'DESKTOP_SESSION': '', 'XDG_CURRENT_DESKTOP': 'XFCE'})
        self.assertIn('DESKTOP_SESSION= ', before)
        self.assertIn('DESKTOP_SESSION=(unset)', during)
        self.assertEqual(after, before)


class Check(unittest.TestCase):
    def test_the_sessions_are_named_as_they_name_themselves(self):
        self.assertEqual(media_check.DESKTOPS['gnome']['XDG_CURRENT_DESKTOP'], 'ubuntu:GNOME')
        self.assertEqual(media_check.DESKTOPS['xfce']['XDG_CURRENT_DESKTOP'], 'XFCE')
        for variables in media_check.DESKTOPS.values():
            self.assertLessEqual(set(variables), set(CHROMIUM_READS))

    def test_a_check_runs_with_no_name_unless_it_gives_one(self):
        text = read('tools', 'ci', 'media_check.py')
        pop = "for name in DESKTOP_VARIABLES:\n                env.pop(name, None)"
        self.assertIn(pop, text)
        give = "env.update(DESKTOPS[args.desktop])"
        self.assertLess(text.index(pop), text.index(give))
        self.assertIn("env['OXT_MEDIA_DESKTOP'] = DESKTOPS[args.desktop]['XDG_CURRENT_DESKTOP']", text)

    def test_a_script_still_sees_the_name(self):
        script = read('tools', 'ci', 'media-check.livecodescript')
        name = script[script.index('command checkDesktopName pWhat'):script.index('end checkDesktopName')]
        self.assertIn('if $OXT_MEDIA_DESKTOP is empty then exit checkDesktopName', name)
        self.assertIn('$XDG_CURRENT_DESKTOP is $OXT_MEDIA_DESKTOP', name)
        # and a program the engine starts
        self.assertIn('shell("printf %s " & quote & "$XDG_CURRENT_DESKTOP" & quote) is $OXT_MEDIA_DESKTOP', name)
        for handler, what in (('checkWidget', 'browser widget'), ('checkRevBrowser', 'revBrowser')):
            body = script[script.index('command %s pUrl' % handler):script.index('end %s\n' % handler)]
            self.assertIn('checkDesktopName "%s"' % what, body)

    def test_the_linux_build_names_gnome_and_xfce(self):
        workflow = read('.github', 'workflows', 'build-linux.yml')
        step = workflow[workflow.index('- name: Browser check (a desktop named GNOME, then Xfce)'):]
        step = step[:step.index('\n      - name:')]
        for name in ('gnome', 'xfce'):
            self.assertIn('--what widget,revbrowser \\\n            --browser-backend cef --desktop %s ' % name, step)


if __name__ == '__main__':
    unittest.main()
