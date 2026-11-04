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

"""The web pages' oxtOwnError (tools/ci/stray_errors.py): only an error of
the page's own stops or flags anything, not a browser extension's script
or another site's (seth's web IDE, 2026-11-04: "Something went wrong" in
a normal window, opened in a private one, which leaves the extensions
out). Every page that runs the web engine carries the same function, and
asks it before it shows an error; under node (skipped without it), the
function answers for the errors browsers report; and the browser checks
that raise such errors are wired in. The browser checks settle the
pages' behaviour.

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import shutil
import subprocess
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import stray_errors  # noqa: E402

NODE = shutil.which('node')


def listeners(text):
    """The bodies of the page's window error listeners, up to the end of
    each (the first line that closes it at its own indentation)."""
    out = []
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if "window.addEventListener('error', function" in line:
            pad = line[:len(line) - len(line.lstrip())]
            body = []
            for later in lines[i + 1:]:
                if later.startswith(pad + '});'):
                    break
                body.append(later)
            out.append('\n'.join(body))
    return out


class SameRule(unittest.TestCase):
    def test_every_page_carries_the_same_function(self):
        master = stray_errors.own_error_function(stray_errors.page_text(stray_errors.PAGES[0]))
        self.assertIsNotNone(master)
        for page in stray_errors.PAGES:
            with self.subTest(page=page):
                self.assertEqual(stray_errors.own_error_function(stray_errors.page_text(page)), master)

    def test_the_rule(self):
        rule = stray_errors.own_error_function(stray_errors.page_text(stray_errors.PAGES[0]))
        # the page's site, or the engine's WebAssembly
        self.assertIn("var site = location.protocol === 'file:' ? 'file:' : location.origin + '/';", rule)
        self.assertIn("file.indexOf(site) === 0", rule)
        self.assertIn("file.indexOf('wasm:') === 0", rule)
        for kind in ('RuntimeError', 'CompileError', 'LinkError'):
            self.assertIn('e.error instanceof WebAssembly.' + kind, rule)
        # an error with no file is not the page's
        self.assertIn("return file !== '' &&", rule)

    def test_each_page_asks_before_it_shows_an_error(self):
        for page in stray_errors.PAGES:
            with self.subTest(page=page):
                bodies = listeners(stray_errors.page_text(page))
                self.assertEqual(len(bodies), 1, 'one error listener')
                body = bodies[0]
                self.assertIn('if (!oxtOwnError(e)) {', body)
                shown = [body.find(x) for x in ('fail(', "$('loading-error')", 'Module.setStatus(',
                                                'statusText.textContent') if x in body]
                self.assertTrue(shown, 'the listener shows something')
                self.assertLess(body.index('oxtOwnError(e)'), min(shown))

    def test_every_page_with_an_error_listener_is_held(self):
        # A page of the site's that runs the engine and listens for errors
        # carries the rule (a new one is added to PAGES)
        found = []
        for root in ('tools/web-ide', 'tools/web-player', 'tools/pages', 'engine/rsrc'):
            for folder, _, files in os.walk(os.path.join(REPO, root)):
                for name in files:
                    if name.endswith('.html'):
                        path = os.path.relpath(os.path.join(folder, name), REPO).replace(os.sep, '/')
                        with open(os.path.join(REPO, path), encoding='utf-8') as f:
                            if "window.addEventListener('error'" in f.read():
                                found.append(path)
        self.assertEqual(sorted(found), sorted(stray_errors.PAGES))


@unittest.skipIf(NODE is None, 'no node')
class Answers(unittest.TestCase):
    """The function itself, under node, with the errors browsers report
    (as Chromium reported them, 2026-11-04)."""

    CASES = [
        # (page, filename, a WebAssembly error, the page's own)
        ('https://x.github.io/oxt/ide/', 'https://x.github.io/oxt/ide/standalone-community-9.7.1.js', None, True),
        ('https://x.github.io/oxt/ide/', 'https://x.github.io/oxt/ide/', None, True),
        # the gallery's pages take the engine from a folder beside them
        ('https://x.github.io/oxt/games/waterwheel/', 'https://x.github.io/oxt/games/svg-lab/standalone.js', None, True),
        ('https://x.github.io/oxt/ide/?v=1#a', 'https://x.github.io/oxt/ide/index.html', None, True),
        ('https://x.github.io/oxt/ide/', 'wasm://wasm/e30a2672', None, True),
        ('https://x.github.io/oxt/ide/', '', 'RuntimeError', True),
        ('https://x.github.io/oxt/ide/', 'https://x.github.io/oxt/ide/standalone.js line 2 > WebAssembly.instantiate', None, True),
        ('file:///C:/oxt/stack/WebProbe.html', 'file:///C:/oxt/stack/standalone.js', None, True),
        # not the page's: an extension's, another site's, a script with no file, a blob
        ('https://x.github.io/oxt/ide/', '', None, False),
        ('https://x.github.io/oxt/ide/', 'chrome-extension://abc/inject.js', None, False),
        ('https://x.github.io/oxt/ide/', 'moz-extension://abc/inject.js', None, False),
        ('https://x.github.io/oxt/ide/', 'safari-web-extension://abc/inject.js', None, False),
        ('https://x.github.io/oxt/ide/', 'https://ads.example/tag.js', None, False),
        ('https://x.github.io/oxt/ide/', 'https://x.github.io.evil.example/a.js', None, False),
        ('https://x.github.io/oxt/ide/', 'blob:https://x.github.io/9bdad338', None, False),
        ('https://x.github.io/oxt/ide/', '', 'Error', False),
    ]

    def answers(self, page):
        function = stray_errors.own_error_function(stray_errors.page_text(page))
        script = '''
var cases = %s;
var WebAssembly = {RuntimeError: function() {}, CompileError: function() {}, LinkError: function() {}};
var answers = cases.map(function(c) {
  var url = new URL(c[0]);
  var location = {href: c[0], protocol: url.protocol, origin: url.protocol === 'file:' ? 'null' : url.origin};
  var error = c[2] === 'RuntimeError' ? new WebAssembly.RuntimeError() : c[2] ? new Error('x') : null;
  return (function(location) {
    %s
    return oxtOwnError({filename: c[1], error: error});
  })(location);
});
console.log(JSON.stringify(answers));
''' % (json.dumps(self.CASES), function)
        out = subprocess.run([NODE, '-e', script], capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout)

    def test_each_page_answers(self):
        for page in stray_errors.PAGES:
            with self.subTest(page=page):
                for case, answer in zip(self.CASES, self.answers(page)):
                    self.assertEqual(answer, case[3], case)


class TheChecks(unittest.TestCase):
    def read(self, *path):
        with open(os.path.join(REPO, *path), encoding='utf-8') as f:
            return f.read()

    def test_the_stray_errors(self):
        js = stray_errors.STRAY_ERRORS
        self.assertIn("var mark = '%s';" % stray_errors.STRAY_MARK, js)
        self.assertIn("throw new Error(mark + ', from a script with no file');", js)
        self.assertIn('new Blob(', js)
        self.assertIn("'chrome-extension://", js)
        self.assertIn("'moz-extension://", js)
        self.assertIn("['', 'Script error.']", js)
        # while the engine downloads and starts, and when a check asks
        self.assertIn('[300, 2500, 6000]', js)
        self.assertIn('window.oxtStrayErrors = function()', js)
        self.assertEqual(stray_errors.STRAY_NOW, 'window.oxtStrayErrors()')

    def test_the_own_error(self):
        js = stray_errors.OWN_ERROR
        self.assertIn(stray_errors.OWN_ERROR_TEXT, js)
        self.assertIn("filename: location.href.replace(/[?#].*$/, '')", stray_errors.OWN_NOW)
        self.assertIn(stray_errors.OWN_NOW, js)
        self.assertIn("document.addEventListener('DOMContentLoaded', function() {", js)

    def test_the_web_ide_check(self):
        tour = self.read('tools', 'ci', 'web_ide_tour.py')
        self.assertIn('from stray_errors import STRAY_MARK, STRAY_ERRORS, OWN_ERROR_TEXT, OWN_ERROR', tour)
        self.assertIn('page.add_init_script(STRAY_ERRORS)', tour)
        self.assertIn('page.add_init_script(OWN_ERROR)', tour)

    def test_the_stack_player_check(self):
        text = self.read('tools', 'web-player', 'build_player.py')
        self.assertIn('stray_errors.STRAY_ERRORS', text)
        self.assertIn('stray_errors.STRAY_NOW', text)
        self.assertIn("expect('stray-errors'", text)

    def test_the_web_standalone_check(self):
        text = self.read('tools', 'ci', 'web_check.py')
        self.assertIn('stray_errors.STRAY_ERRORS', text)
        self.assertIn('stray_errors.STRAY_NOW', text)
        self.assertIn('stray_errors.OWN_NOW', text)


if __name__ == '__main__':
    unittest.main()
