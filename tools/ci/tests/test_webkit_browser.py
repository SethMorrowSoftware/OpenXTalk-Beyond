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

"""The Linux browser widget through WebKitGTK where CEF cannot load
(libbrowser/src/libbrowser_webkitgtk.cpp and its helper process,
libbrowser-webkitprocess): the check that runs that half on its own
(tools/ci/webkit_browser_check.py), the choice of the browser, the build,
the package, the standalone builder, the launcher, the media check's
--browser-backend and the Linux workflow.

  python3 -m unittest discover -s tools/ci/tests

The check itself, which needs X, GTK 2 and WebKitGTK, runs in the Linux
build (build-linux.yml); here it runs only with OXT_WEBKIT_CHECK=1.
"""

import ast
import os
import re
import subprocess
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)
sys.path.insert(0, os.path.join(os.path.dirname(CI), 'oxt'))

import media_check  # noqa: E402
import package  # noqa: E402
import webkit_browser_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))
HELPER = 'libbrowser-webkitprocess'


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class CheckScript(unittest.TestCase):
    def test_builds_libbrowser_with_the_check_and_the_helper_apart(self):
        cmds, check, helper = webkit_browser_check.build_commands('/tmp/w')
        self.assertEqual(len(cmds), 2)
        built = ' '.join(cmds[0])
        for name in ('libbrowser.cpp', 'libbrowser_json.cpp', 'libbrowser_webkitgtk.cpp',
                     'libbrowser_webkitgtk_protocol.cpp', 'webkit-browser-check.cpp', 'core.cpp'):
            self.assertIn(name, built)
        # The helper is built on its own, as the build makes it: no
        # libbrowser, no sanitizer, nothing but -ldl
        self.assertEqual([os.path.basename(x) for x in cmds[1] if x.endswith('.cpp')],
                         ['libbrowser_webkitprocess_lnx.cpp', 'libbrowser_webkitgtk_protocol.cpp'])
        self.assertTrue(helper.endswith('/' + HELPER))
        sanitized, _, _ = webkit_browser_check.build_commands('/tmp/w', sanitize=True)
        self.assertIn('-fsanitize=address,undefined', sanitized[0])
        self.assertNotIn('-fsanitize=address,undefined', sanitized[1])

    def test_a_built_helper_is_used_as_it_is(self):
        cmds, _, helper = webkit_browser_check.build_commands('/tmp/w', helper='/opt/oxt/' + HELPER)
        self.assertEqual(len(cmds), 1)
        self.assertEqual(helper, '/opt/oxt/' + HELPER)

    def test_every_source_is_there(self):
        for path in webkit_browser_check.CHECK_SOURCES + webkit_browser_check.HELPER_SOURCES:
            self.assertTrue(os.path.isfile(path), path)

    def test_runs_each_mode_under_xvfb_without_a_display(self):
        cmds = webkit_browser_check.run_commands('/bin/check', '/bin/helper', '/tmp/w', display=':5')
        self.assertEqual([c[-1] for c in cmds], ['all', 'missing-helper', 'backend-cef'])
        self.assertEqual(cmds[0][:3], ['/bin/check', '--helper', '/bin/helper'])

    def test_counts_passes_and_failures(self):
        passes, failures = webkit_browser_check.summarise('PASS a\nFAIL b: why\nnoise\nPASS c\n')
        self.assertEqual(len(passes), 2)
        self.assertEqual(failures, ['FAIL b: why'])

    @unittest.skipUnless(os.environ.get('OXT_WEBKIT_CHECK') == '1', 'needs X, GTK 2 and WebKitGTK (OXT_WEBKIT_CHECK=1)')
    def test_the_check_passes(self):
        proc = subprocess.run([sys.executable, os.path.join(CI, 'webkit_browser_check.py')],
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(proc.returncode, 0, proc.stdout[-3000:])


class CheckSource(unittest.TestCase):
    """What the check asks of the browser: what a script sees with CEF."""

    def test_the_check_covers_what_a_script_sees(self):
        source = read('tools', 'ci', 'webkit-browser-check.cpp')
        for what in ('htmlText: no navigation messages, as with CEF', 'htmlText: the URL is empty, as with CEF',
                     'JavaScript: a number comes back as text', 'JavaScript: a script that throws fails',
                     'handlers: its parameters arrive with their types', 'handlers: only those named are there',
                     'pages: navigateBegin, documentLoadBegin, documentLoadComplete, navigateComplete',
                     'pages: a missing page sends documentLoadFailed and navigateFailed',
                     'pages: an unknown scheme is an unhandled request, not a failure',
                     'history: can go back, not forward', 'userAgent: set and used',
                     'embed: the page is drawn in it', 'browser: releasing it ends its helper process',
                     'choice: CEF is tried first, and WebKitGTK is the browser when CEF cannot load',
                     'missing helper: there is no browser, and no crash'):
            self.assertIn('"%s"' % what, source)


class Choice(unittest.TestCase):
    """CEF stays the default wherever it loads; WebKitGTK comes after it on
    Linux; OXT_BROWSER_BACKEND names one."""

    def test_factories_on_linux(self):
        source = read('libbrowser', 'src', 'libbrowser_lnx_factories.cpp')
        cef = source.index('{ "CEF", nil, MCCefBrowserFactoryCreate }')
        webkit = source.index('{ "WebKitGTK", nil, MCWebKitGtkBrowserFactoryCreate }')
        self.assertLess(cef, webkit)
        # WebKitGTK on every architecture, CEF on x86-64 only
        self.assertNotIn('#endif', source[webkit:])

    def test_only_linux_has_it(self):
        for platform in ('win', 'osx', 'em'):
            self.assertNotIn('WebKitGtk', read('libbrowser', 'src', 'libbrowser_%s_factories.cpp' % platform))

    def test_backend_variable(self):
        source = read('libbrowser', 'src', 'libbrowser.cpp')
        body = source[source.index('bool MCBrowserFactoryGet('):]
        self.assertIn('getenv("OXT_BROWSER_BACKEND")', body)
        # matched against the factories' own names, so an unknown value
        # falls through to the default order
        self.assertIn('MCCStringEqualCaseless(t_backend, s_factory_list[i].factory_id)', body)

    def test_helper_loads_webkitgtk_at_run_time(self):
        helper = read('libbrowser', 'src', 'libbrowser_webkitprocess_lnx.cpp')
        self.assertIn('"libwebkit2gtk-4.1.so.0"', helper)
        self.assertIn('"libwebkit2gtk-4.0.so.37"', helper)
        self.assertNotRegex(helper, r'#include\s*<(gtk|webkit|glib)')
        self.assertIn('setenv("GDK_BACKEND", "x11", 1)', helper)


class Build(unittest.TestCase):
    def setUp(self):
        self.gyp = ast.literal_eval(read('libbrowser', 'libbrowser.gyp'))

    def helper_target(self):
        for condition in self.gyp['conditions']:
            for target in condition[1].get('targets', []):
                if target['target_name'] == HELPER:
                    return condition[0], target
        self.fail('no %s target' % HELPER)

    def test_helper_target(self):
        condition, target = self.helper_target()
        self.assertEqual(condition, 'OS == "linux"')
        self.assertEqual(target['type'], 'executable')
        self.assertEqual(target['libraries'], ['-ldl'])
        self.assertNotIn('dependencies', target)
        self.assertIn('dist_files', target['all_dependent_settings']['variables'])

    def test_libbrowser_depends_on_it_on_linux(self):
        lib = self.gyp['targets'][0]
        self.assertIn(['OS == "linux"', {'dependencies': [HELPER]}], lib['conditions'])
        for name in ('src/libbrowser_webkitgtk.cpp', 'src/libbrowser_json.cpp', 'src/libbrowser_webkitgtk_protocol.cpp'):
            self.assertIn(name, lib['sources'])
        linux_only = [c for c in lib['target_conditions'] if c[0] == 'toolset_os != "linux"'][0][1]['sources!']
        self.assertIn('src/libbrowser_webkitgtk.cpp', linux_only)

    def test_workflow_expects_the_helper(self):
        workflow = read('.github', 'workflows', 'build-linux.yml')
        self.assertEqual(workflow.count('lc-compile lc-run libbrowser-webkitprocess; do'), 2)


class Package(unittest.TestCase):
    def test_next_to_the_engine_and_in_every_linux_runtime(self):
        for name in ('linux-x86_64', 'linux-arm64', 'linux-x86'):
            p = package.PLATFORMS[name]
            self.assertIn((HELPER, HELPER), p.engine_support, name)
            for runtime in p.runtimes:
                self.assertIn(HELPER, runtime['files'], name)

    def test_not_elsewhere(self):
        for name, p in package.PLATFORMS.items():
            if p.family != 'linux':
                self.assertNotIn(HELPER, repr(p.engine_support) + repr(p.runtimes), name)

    def test_package_txt(self):
        text = read('Installer', 'package.txt')
        self.assertEqual(text.count('executable linux-[[TargetArchitecture]]:libbrowser-webkitprocess'), 2)


class StandaloneBuilder(unittest.TestCase):
    def test_copies_the_helper_for_the_browser_widget_on_linux(self):
        script = read('ide-support', 'revsaveasstandalone.livecodescript')
        body = script[script.index('private command revCopyCEFResources'):]
        body = body[:body.index('end revCopyCEFResources')]
        self.assertIn('if pCopyLibBrowserResources and pPlatform contains "Linux" then\n'
                      '      revCopyWebKitHelper pPlatform, pStandalonePath', body)
        helper = script[script.index('private command revCopyWebKitHelper'):]
        helper = helper[:helper.index('end revCopyWebKitHelper')]
        # A runtime without the helper builds as before
        self.assertIn('if there is not a file tHelper then\n      exit revCopyWebKitHelper', helper)


class Launcher(unittest.TestCase):
    def test_webkitgtk_keeps_the_browser_on(self):
        launcher = read('Installer', 'linux', 'oxt-beyond')
        self.assertIn('"$here/libbrowser-webkitprocess" --probe', launcher)
        body = launcher[launcher.index('if [ -z "${LIVECODE_USE_CEF+set}" ]; then'):]
        body = body[:body.index('exec "$engine"')]
        # the browser is turned off in the same two cases as before, each
        # now only when WebKitGTK cannot stand in
        self.assertEqual(len(re.findall(r'(?m)^\s+LIVECODE_USE_CEF=0$', body)), 2)
        self.assertEqual(body.count('webkit_browser'), 2)


class MediaCheck(unittest.TestCase):
    def test_browser_backend_option(self):
        source = read('tools', 'ci', 'media_check.py')
        self.assertIn("'--browser-backend', choices=('auto', 'cef', 'webkitgtk')", source)
        self.assertIn("env['OXT_BROWSER_BACKEND'] = args.browser_backend", source)
        self.assertTrue(hasattr(media_check, 'main'))

    def test_workflow_runs_both_checks(self):
        workflow = read('.github', 'workflows', 'build-linux.yml')
        step = workflow[workflow.index('- name: Browser check (WebKitGTK)'):]
        step = step[:step.index('\n      - name:', 10)]
        self.assertIn('webkit_browser_check.py --sanitize --helper "$OXT_ROOT/libbrowser-webkitprocess"', step)
        self.assertIn('--what widget --browser-backend webkitgtk', step)
        self.assertRegex(workflow, r'pkgs=\([^)]*libwebkit2gtk-4\.1-0 libx11-dev')


if __name__ == '__main__':
    unittest.main()
