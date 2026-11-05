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
"""The Mobile Web library's phone check (tools/ci/mobile_web_check.py)
held to the pieces it works with, without a browser or an engine:

- every handler the check calls in the page is one that the check's
  stack (mobile-web-check.livecodescript) has, and one that the
  standalone's startup script (mobile-web-deploy.livecodescript) lets the
  page call
- the one attribute that lets a page keep its own layout
  (data-mobile-web-fill="no") is the one the library reads, and the
  Stack Player's page has it
- the library ships: built (extensions.gyp), laid out
  (tools/oxt/layout.py) and installed (Installer/package.txt) with the
  other script libraries
- the Phone Starter is offered: in the Stack Player's samples, with its
  picture, and in Home's gallery
- the workflow runs the check in Chromium and WebKit, and not in Firefox,
  which has no touch screen for Playwright to emulate
- the Phone Starter's tabs and Phone card agree with the check, and its
  pad takes the touch messages
- every message the library sends is listed at the top of it
- a page says so when the engine stops, and the Stack Player gives a
  stack the whole screen on a phone and nowhere else
- the check's small helpers

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import shutil
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
import mobile_web_check  # noqa: E402

LIBRARY = os.path.join(REPO, 'extensions', 'script-libraries', 'mobileweb', 'mobileweb.livecodescript')
PLAYER = os.path.join(REPO, 'tools', 'web-player')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class PageHandlers(unittest.TestCase):

    def test_every_handler_the_check_calls_is_there_and_allowed(self):
        check = read('tools', 'ci', 'mobile_web_check.py')
        stack = read('tools', 'ci', 'mobile-web-check.livecodescript')
        deploy = read('tools', 'ci', 'mobile-web-deploy.livecodescript')
        called = set(re.findall(r"findStackWithName\('MobileWebCheck'\)\.(\w+)\(", check))
        called |= set(re.findall(r"h\.(mwc\w+)\(", check))
        self.assertIn('mwcState', called)
        self.assertGreaterEqual(len(called), 4, called)
        defined = set(re.findall(r'^(?:function|command) (mwc\w+)', stack, re.M))
        allowed = set(re.findall(r'quote & "(mwc\w+)" & quote', deploy))
        for name in sorted(called):
            self.assertIn(name, defined, 'mobile-web-check.livecodescript has no %s' % name)
            self.assertIn(name, allowed, 'the startup script does not let the page call %s' % name)

    def test_the_library_is_called_by_the_name_it_has(self):
        check = read('tools', 'ci', 'mobile_web_check.py')
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        self.assertIn('script "com.livecode.library.mobileweb"', library)
        self.assertIn("findStackWithName('com.livecode.library.mobileweb')", check)
        # its one javascriptHandler, which the check calls to tell it of a
        # keyboard
        self.assertIn('mwFromBrowser', library)
        self.assertIn('lib.mwFromBrowser(', check)


class KeepItsOwnLayout(unittest.TestCase):

    def test_the_library_and_the_player_name_the_one_attribute(self):
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        self.assertIn("getAttribute('data-mobile-web-fill') === 'no'", library)
        page = read('tools', 'web-player', 'index.html')
        self.assertRegex(page, r'<body[^>]*\sdata-mobile-web-fill="no"')

    def test_mwstop_takes_the_fill_away(self):
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        stop = re.search(r'^command mwStop\n(.*?)^end mwStop', library, re.M | re.S)
        self.assertIsNotNone(stop)
        self.assertIn('unfillPage()', stop.group(1))
        self.assertIn('unfillPage: function', library)


class Ships(unittest.TestCase):

    def test_built_laid_out_and_installed(self):
        self.assertIn("'script-libraries/mobileweb/mobileweb.livecodescript',", read('extensions', 'extensions.gyp'))
        self.assertIn("'com.livecode.library.mobileweb',", read('tools', 'oxt', 'layout.py'))
        self.assertIn('packaged_extensions/com.livecode.library.mobileweb', read('Installer', 'package.txt'))

    def test_the_library_has_its_tests(self):
        # (the layout handlers' tests are in tests/responsive.livecodescript)
        tests = ''.join(read('extensions', 'script-libraries', 'mobileweb', 'tests', name)
                        for name in ('mobileweb.livecodescript', 'responsive.livecodescript'))
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        public = set(re.findall(r'^(?:command|function) (mw\w+)', library, re.M))
        self.assertIn('mwStart', public)
        for name in sorted(public):
            self.assertRegex(tests, r'\b%s\b' % name, 'the tests never call %s' % name)


class FitsAnIPhonesStack(unittest.TestCase):
    """Safari on an iPhone or an iPad gives a page's script far less stack
    than a desktop's WebKit. A Phone Starter ran out of it as it opened (a
    blank page): the library's browser script was one "put" of every line
    joined with "&", an expression as deep as the script is long. Long
    statements are kept out of what a phone runs, and the check's WebKit
    runs with an iPhone's stack."""

    LONGEST = 30

    def longest_statement(self, text):
        longest = run = 0
        for line in text.split('\n'):
            run = run + 1 if line.rstrip().endswith('\\') else 0
            longest = max(longest, run)
        return longest

    def test_no_statement_is_too_long(self):
        for path in (LIBRARY, os.path.join(PLAYER, 'phone-starter-stack.livecodescript'),
                     os.path.join(PLAYER, 'phone-starter.livecodescript'),
                     os.path.join(PLAYER, 'stack-player.livecodescript')):
            with open(path, encoding='utf-8') as f:
                text = f.read()
            self.assertLessEqual(self.longest_statement(text), self.LONGEST,
                                 '%s has a statement continued over %d lines' % (os.path.basename(path), self.LONGEST))

    def test_the_measure_sees_a_long_statement(self):
        long_put = 'put "a" & return & \\\n' * 40 + '"z" into t\n'
        self.assertEqual(self.longest_statement(long_put), 40)
        self.assertEqual(self.longest_statement('put 1 into t\nput 2 into u\n'), 0)

    def test_the_browser_script_is_put_a_line_at_a_time(self):
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        body = library[library.index('private function mwBrowserScript'):library.index('end mwBrowserScript')]
        self.assertGreater(body.count(' after tScript'), 100)

    def test_webkit_runs_with_an_iphones_stack(self):
        self.assertEqual(mobile_web_check.launch_options('chromium'), {})
        env = mobile_web_check.launch_options('webkit')['env']
        self.assertEqual(env['JSC_maxPerThreadStackUsage'], str(mobile_web_check.IPHONE_STACK))
        self.assertLessEqual(mobile_web_check.IPHONE_STACK, 512 * 1024)
        self.assertEqual(env.get('PATH'), os.environ.get('PATH'))


class FoundForStandalones(unittest.TestCase):
    """"Search for required inclusions" in the standalone builder finds
    the Mobile Web library in a stack that calls it: its manifest names
    its handlers (extension-utils), the IDE keeps them for a script
    library (revideextensionlibrary), and the builder keeps the library it
    finds (revsblibrary). web_check.py proves it in the real IDE; these
    hold the three pieces in place."""

    def test_only_the_mobile_web_manifest_names_handlers(self):
        utils = read('extensions', 'script-libraries', 'extension-utils', 'extension-utils.livecodescript')
        self.assertIn('constant kLibrariesFoundByHandlers = "com.livecode.library.mobileweb"', utils)
        self.assertRegex(utils, r'if tDataA\["name"\] is among the items of kLibrariesFoundByHandlers then\s+'
                                r'repeat for each line tHandler in __LCSDocumentedHandlers\(tDocA\)')

    def test_the_ide_keeps_a_script_librarys_handlers(self):
        ide = read('ide', 'Toolset', 'libraries', 'revideextensionlibrary.livecodescript')
        loader = ide[ide.index('private command __revIDELCSExtensionLoad'):ide.index('end __revIDELCSExtensionLoad')]
        self.assertIn('__extensionPropertySet tCacheIndex, "handlers", pAdditionalInfoA["handlers"]', loader)

    def test_the_builder_keeps_what_it_found(self):
        sb = read('ide-support', 'revsblibrary.livecodescript')
        check = sb[sb.index('private command revCheckObject'):sb.index('end revCheckObject')]
        found = check[check.index('revIDEExtensionLibraryHandlers(tLibrary)'):]
        # revSmartChecking makes the "extensions" setting from xWidgetKinds
        self.assertIn('put the keys of tExtensionIDs into tNewSettings["extensions"]', sb)
        self.assertRegex(found, r'revSBAddInclusion tLibrary, "extensions", xSettings\s+'
                                r'if tLibrary is among the items of kSBLibrariesKeptWhenFound then\s+'
                                r'put true into xWidgetKinds\[tLibrary\]\s+end if')
        # every other library found by its handlers (the JSON library, Canvas
        # and the other LCB libraries, whose manifests name them) is left out,
        # as it always was, so that old stacks' standalones keep their inclusions
        self.assertIn('constant kSBLibrariesKeptWhenFound = "com.livecode.library.mobileweb"\n', sb)
        self.assertEqual(found.count('xWidgetKinds'), 1)
        self.assertLess(sb.index('constant kSBLibrariesKeptWhenFound'), sb.index('kSBLibrariesKeptWhenFound then'))

    def test_the_web_build_reports_it(self):
        deploy = read('tools', 'ci', 'web-deploy.livecodescript')
        self.assertIn('webMobileWebFound', deploy)
        self.assertIn('"INFO mobileweb-found-" & tKind', deploy)
        self.assertIn('   mwStart', deploy)

    def test_the_web_check_judges_it(self):
        import web_check
        judge = web_check.mobile_web_found_problem
        mw = {'phone': True, 'plain': False, 'json': False}
        js = {'phone': False, 'plain': False, 'json': False}
        self.assertIsNone(judge(mw, js))
        self.assertIn('did not find', judge(dict(mw, phone=False), js))
        self.assertIn('does not call it', judge(dict(mw, plain=True), js))
        self.assertIn('does not call it', judge(dict(mw, json=True), js))
        self.assertIn('JSON library', judge(mw, dict(js, json=True)))
        self.assertIn('did not report', judge({}, js))
        self.assertIn('did not report', judge({'phone': True, 'plain': False}, js))
        self.assertIn('did not report', judge(mw, {}))
        self.assertIn('did not report', judge(mw))


# A fake page for the note code lifted out of a page's script (from
# showStopped to the WebAssembly check): the listeners it adds, and the
# elements it puts on the body. NOWASM runs it in a browser without
# WebAssembly, as an iPhone's Lockdown Mode is.
FAKE_PAGE = r"""
const listeners = {};
const window = { addEventListener: (name, fn) => { (listeners[name] = listeners[name] || []).push(fn); } };
const added = [];
const document = {
  createElement: () => ({ style: {}, setAttribute(k, v) { this[k] = v; } }),
  getElementById: (id) => added.find((e) => e.id === id) || null,
  body: { appendChild: (e) => added.push(e) },
};
const navigator = { userAgent: 'TestPhone/1.0' };
const $ = (id) => document.getElementById(id);
const RealWasm = globalThis.WebAssembly;
(function (WebAssembly, BigInt64Array) {
NOTE
})(NOWASM ? undefined : RealWasm, 'MODE' === 'oldcompile' ? undefined : globalThis.BigInt64Array);
const fire = (reason) => listeners.unhandledrejection.forEach((fn) => fn({ reason }));
if ('MODE' === 'compile' || 'MODE' === 'oldcompile') {
  fire(new RealWasm.RuntimeError('Aborted(CompileError: WebAssembly.Module doesn\'t parse at byte 9)'));
  console.log(JSON.stringify({ seen: [added.length], note: added[0] || null }));
  process.exit(0);
}
const seen = [added.length];
fire(new Error('a stack of its own'));
seen.push(added.length);
const overflow = (where) => { const e = new RangeError('Maximum call stack size exceeded.'); e.stack = where; return e; };
fire(overflow('f@https://extension.example/content.js:1:1'));
seen.push(added.length);
fire(overflow('16484@wasm-function[16484]\n864@wasm-function[864]'));
seen.push(added.length);
fire(new RealWasm.RuntimeError('unreachable'));
seen.push(added.length);
console.log(JSON.stringify({ seen, note: added[0] || null }));
"""


class SaysWhenItStops(unittest.TestCase):
    """When the engine stops in a browser (out of the stack an iPhone or
    an iPad gives a page, or WebAssembly failing) it does so in a promise
    nothing catches, and a standalone's page, and the Stack Player's, was
    left blank; a browser without WebAssembly (Lockdown Mode) left it
    loading for ever. Each now says so above everything, in the browser's
    words; a stack's own JavaScript rejecting is left as it was, and the
    'error' listener each had is kept."""

    PAGES = (('engine', 'rsrc', 'emscripten-html-template.html'), ('tools', 'web-player', 'index.html'))

    @staticmethod
    def note_code(page):
        start = page.index('function showStopped(text)')
        if 'function oxtTooOld()' in page:
            start = min(start, page.index('function oxtTooOld()'))
        check = page.index("if (typeof WebAssembly != 'object') {", start)
        end = re.compile(r'^\s*\}$', re.M).search(page, check).end()
        return page[start:end]

    def test_both_pages_note_it_and_keep_their_error_listener(self):
        for parts in self.PAGES:
            page = read(*parts)
            self.assertIn("window.addEventListener('error', function", page, parts)
            code = self.note_code(page)
            for want in ("window.addEventListener('unhandledrejection', function",
                         "reason instanceof RangeError && /wasm/.test(String(reason.stack || ''))",
                         'WebAssembly.RuntimeError', "'stopped'", "setAttribute('role', 'alert')",
                         'navigator.userAgent', 'appendChild', 'Lockdown Mode'):
                self.assertIn(want, code, (parts, want))

    def test_the_note_is_above_everything(self):
        template = self.note_code(read(*self.PAGES[0]))
        self.assertIn('position:fixed', template)
        self.assertIn('z-index:2147483647', template)
        player = read(*self.PAGES[1])
        self.assertRegex(player, r'#stopped\{position:fixed;[^}]*z-index:2147483647')

    def run_page(self, parts, nowasm, mode='normal'):
        script = FAKE_PAGE.replace('NOTE', self.note_code(read(*parts))).replace(
            'NOWASM', 'true' if nowasm else 'false').replace("'MODE'", repr(mode))
        out = subprocess.run([shutil.which('node'), '-e', script], capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, (parts, out.stderr))
        return json.loads(out.stdout)

    @unittest.skipUnless(shutil.which('node'), 'node is not installed')
    def test_only_the_engine_stopping_shows_the_note_once(self):
        for parts in self.PAGES:
            result = self.run_page(parts, False)
            self.assertEqual(result['seen'], [0, 0, 0, 1, 1], parts)
            self.assertEqual(result['note']['id'], 'stopped')
            self.assertEqual(result['note']['textContent'],
                             'The stack stopped in this browser: Maximum call stack size exceeded. (TestPhone/1.0)')

    @unittest.skipUnless(shutil.which('node'), 'node is not installed')
    def test_a_browser_too_old_for_the_engine_is_told_so(self):
        # its WebAssembly not understood (Safari before 15): the engine's
        # abort names the CompileError
        for parts in self.PAGES:
            result = self.run_page(parts, False, 'oldcompile')
            self.assertEqual(result['seen'], [1], parts)
            self.assertIn('too old', result['note']['textContent'])
            self.assertIn('Safari 15 or later', result['note']['textContent'])
            self.assertIn('CompileError', result['note']['textContent'])

    @unittest.skipUnless(shutil.which('node'), 'node is not installed')
    def test_a_newer_browser_that_cannot_read_the_engine_has_a_damaged_file(self):
        # (a server that sends a page of its own for the .wasm file, or a
        # file cut short, is not the browser's age)
        for parts in self.PAGES:
            result = self.run_page(parts, False, 'compile')
            self.assertEqual(result['seen'], [1], parts)
            self.assertNotIn('too old', result['note']['textContent'])
            self.assertIn('.wasm file is damaged', result['note']['textContent'])

    def test_its_javascript_not_understood_is_too_old_too(self):
        page = read(*self.PAGES[0])
        listener = page[page.index("window.addEventListener('error', function(e) {"):page.index('function oxtTooOld()')]
        self.assertRegex(listener, r'if \(e\.error instanceof SyntaxError && oxtTooOld\(\)\) \{\s+showStopped\(oxtTooOldText\);')
        # (only after the page's own errors are sorted from others', #341)
        self.assertLess(listener.index('oxtOwnError(e)'), listener.index('SyntaxError'))

    @unittest.skipUnless(shutil.which('node'), 'node is not installed')
    def test_a_browser_without_webassembly_is_told_at_once(self):
        for parts in self.PAGES:
            result = self.run_page(parts, True)
            self.assertEqual(result['seen'], [1, 1, 1, 1, 1], parts)
            self.assertIn('WebAssembly is turned off', result['note']['textContent'])
            self.assertTrue(result['note']['textContent'].endswith('(TestPhone/1.0)'))


class PlayerOnAPhone(unittest.TestCase):
    """On a phone the Stack Player gives a stack the whole screen: a
    stack made for phones fills it with mwStart, and any other is fitted
    to it (mwFitStack), with one button back to the library. Anywhere
    else, and in the IDE, a stack is shown in its window at its own size,
    as it always was. mobile_web_check's emulated phone saw it; these
    hold the pieces together."""

    def setUp(self):
        self.page = read('tools', 'web-player', 'index.html')
        self.player = read('tools', 'web-player', 'stack-player.livecodescript')

    def handler(self, kind, name):
        found = re.search(r'^(?:private )?%s %s\b.*?\n(.*?)^end %s$' % (kind, name, name), self.player, re.M | re.S)
        self.assertIsNotNone(found, name)
        return found.group(1)

    def test_the_page_lets_the_library_fill_only_on_a_phone(self):
        self.assertRegex(self.page, r"function isPhone\(\) \{\s+return window\.matchMedia\('\(pointer: coarse\)'\)\.matches && "
                                    r"Math\.min\(window\.innerWidth, window\.innerHeight\) <= 600;")
        self.assertIn("if (isPhone()) document.body.removeAttribute('data-mobile-web-fill');", self.page)
        self.assertIn("else document.body.setAttribute('data-mobile-web-fill', 'no');", self.page)
        # a stack that is open keeps the page as it is when a phone turns
        self.assertIn("if (document.body.classList.contains('playing')) return;", self.page)

    def test_the_page_plays_full_screen_with_a_way_home(self):
        self.assertIn("document.body.classList.toggle('phone-play', on && !document.body.hasAttribute('data-mobile-web-fill'));", self.page)
        self.assertRegex(self.page, r'<button id="phone-home"[^>]*aria-label="Back to your stacks"')
        self.assertIn("$('phone-home').addEventListener('click', function () { call('home'); });", self.page)
        self.assertIn('#phone-home{display:none}', self.page)

    def test_the_player_asks_the_page(self):
        on = self.handler('function', 'playerOnPhone')
        self.assertIn('if the platform is not "HTML5" then\n      return false', on)
        self.assertIn("document.body.hasAttribute('data-mobile-web-fill') ? 'no' : 'yes'", on)
        filled = self.handler('function', 'playerLibraryFilled')
        self.assertIn("document.getElementById('oxt-mobile-web-fill')", filled)
        self.assertIn("css.id = 'oxt-mobile-web-fill'", read(*LIBRARY[len(REPO) + 1:].split(os.sep)))

    def test_only_a_phone_changes_how_a_stack_opens(self):
        open_ = self.handler('command', 'playerOpenFile')
        self.assertIn('put playerOnPhone() and sMode is "page" into tOnPhone', open_)
        self.assertRegex(open_, r'if tOnPhone then\s+playerTakeTheScreen\s+end if\s+try')
        self.assertIn('put tOnPhone and playerLibraryFilled() into tTookTheScreen', open_)
        # off a phone, the stack's own size is put back as before
        self.assertRegex(open_, r'else if the mode of stack tName > 0 then\s+if tOnPhone then\s+'
                                r'set the resizable of stack tName to tResizable\s+end if\s+'
                                r'set the width of stack tName to item 3 of tRect - item 1 of tRect')
        self.assertIn('if tOnPhone and not tTookTheScreen and the mode of stack tName > 0 then\n      playerFitToPhone tName', open_)
        self.assertIn('mwFitStack pStack', self.handler('command', 'playerFitToPhone'))
        take = self.handler('command', 'playerTakeTheScreen')
        self.assertIn('set the resizable of me to true', take)
        self.assertIn('set the rect of me to 0, 0, tView["width"], tView["height"]', take)

    def test_home_gives_the_page_back(self):
        home = self.handler('command', 'playerGoHome')
        self.assertTrue(home.lstrip().startswith('local') and 'playerStopMobileWeb' in home.split('\n')[2])
        stop = self.handler('command', 'playerStopMobileWeb')
        self.assertRegex(stop, r'if mwIsWeb\(\) then\s+mwStop')


class PhoneStarterOffered(unittest.TestCase):

    def test_in_the_players_samples_with_its_picture(self):
        player = read('tools', 'web-player', 'build_player.py')
        self.assertIn("'files': ['Phone Starter.oxtstack'], 'image': 'Phone Starter.webp'", player)
        for name in ('Phone Starter.oxtstack', 'Phone Starter.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', name)), name)

    def test_in_homes_gallery(self):
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        self.assertRegex(learn, r'"Markdown Notes,UI Gallery,Photo Lab,Phone Starter[,"]')
        self.assertIn('case "Phone Starter"', learn)

    def test_the_check_finds_its_files(self):
        for path in (mobile_web_check.STARTER, mobile_web_check.STARTER_BUILDER, mobile_web_check.STARTER_SCRIPT,
                     mobile_web_check.LIBRARY, mobile_web_check.CHECK_STACK, mobile_web_check.DEPLOY_SCRIPT):
            self.assertTrue(os.path.isfile(path), path)


class PhoneCard(unittest.TestCase):
    """The Phone Starter's tabs and its Phone card, as the builder makes
    them, the stack's script lays them out and the check presses them"""

    def test_the_tabs_agree(self):
        want = 'constant kTabs = "%s"' % ','.join(mobile_web_check.TABS)
        self.assertIn(want, read('tools', 'web-player', 'phone-starter-stack.livecodescript'))
        self.assertIn(want, read('tools', 'web-player', 'phone-starter.livecodescript'))

    def test_the_phone_buttons_agree(self):
        builder = read('tools', 'web-player', 'phone-starter.livecodescript')
        script = read('tools', 'web-player', 'phone-starter-stack.livecodescript')
        check = read('tools', 'ci', 'mobile-web-check.livecodescript')
        build = re.search(r'^private command buildPhone\n(.*?)^end buildPhone', builder, re.M | re.S).group(1)
        built = re.findall(r'(\w+)\|[^"]+"', build)
        self.assertEqual(len(built), 6, built)
        laid = re.search(r'repeat for each item tName in "([^"]+)"', re.search(
            r'^private command psLayoutPhone pRect\n(.*?)^end psLayoutPhone', script, re.M | re.S).group(1)).group(1).split(',')
        self.assertEqual(laid, built)
        for handler in ('mwcButtons', 'mwcLabels'):
            body = re.search(r'^private function %s\n(.*?)^end %s' % (handler, handler), check, re.M | re.S).group(1)
            self.assertIn('"%s"' % ','.join(built), body)
        phone = re.search(r'^command psPhone pWhat\n(.*?)^end psPhone', script, re.M | re.S).group(1)
        for name in built:
            self.assertIn('case "%s"' % name, phone)

    def test_the_pad_takes_the_touch_messages(self):
        builder = read('tools', 'web-player', 'phone-starter.livecodescript')
        play = re.search(r'^private function playScript\n(.*?)^end playScript', builder, re.M | re.S).group(1)
        for message in ('touchStart', 'touchMove', 'touchEnd', 'touchRelease'):
            self.assertRegex(play, r'"on %s pId[^"]*" & return & "   psPlayTouch' % message)
        self.assertIn('command psPlayTouch pWhat, pId, pX, pY', read('tools', 'web-player', 'phone-starter-stack.livecodescript'))


class LibraryMessages(unittest.TestCase):

    def test_every_message_sent_is_listed_in_the_header(self):
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        header = library.split('on extensionInitialize', 1)[0]
        sent = set(re.findall(r'mwSendAt "(\w+)"', library))
        sent |= set(re.findall(r'mwSendToCard "(\w+)"', library))
        sent |= set(re.findall(r'mwSendToCardOf sSensorStack, "(\w+)"', library))
        self.assertGreaterEqual(len(sent), 16, sent)
        for message in sorted(sent):
            self.assertRegex(header, r'--\s+%s\b' % message, '%s is not in the header' % message)

    def test_only_a_no_is_a_no(self):
        # Chromium answers requestPermission with "prompt" where it asks
        # nobody: the sensor must still start
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        self.assertIn("if (r !== 'denied') then();", library)

    def test_the_browser_script_has_no_double_quote(self):
        library = read(*LIBRARY[len(REPO) + 1:].split(os.sep))
        body = re.search(r'^private function mwBrowserScript\n(.*?)^end mwBrowserScript', library, re.M | re.S).group(1)
        for line in body.split('\n')[3:]:
            if line.strip().startswith('"'):
                self.assertRegex(line.strip(), r'^"[^"]*" (& return & \\|into tScript)$', line)


class Workflow(unittest.TestCase):

    def test_chromium_and_webkit_not_firefox(self):
        web = read('.github', 'workflows', 'web.yml')
        step = re.search(r"- name: Check the Mobile Web library on phones.*?(?=\n      - name:)", web, re.S)
        self.assertIsNotNone(step)
        self.assertIn("if: matrix.browser != 'firefox'", step.group(0))
        self.assertIn('tools/ci/mobile_web_check.py', step.group(0))
        self.assertNotIn('--rebuild', step.group(0))
        self.assertEqual(sorted(mobile_web_check.DEFAULT_DEVICES), ['chromium', 'webkit'])


class Helpers(unittest.TestCase):

    def test_rect(self):
        self.assertEqual(mobile_web_check.rect('0,0,390,664'), [0, 0, 390, 664])
        self.assertEqual(mobile_web_check.rect('-4,10,20,30'), [-4, 10, 20, 30])
        self.assertIsNone(mobile_web_check.rect(''))
        self.assertIsNone(mobile_web_check.rect('a,b'))

    def test_png(self):
        import struct
        data = mobile_web_check.png(4, 3)
        self.assertTrue(data.startswith(b'\x89PNG\r\n\x1a\n'))
        self.assertEqual(struct.unpack('>II', data[16:24]), (4, 3))
        self.assertTrue(data.endswith(b'IEND\xaeB`\x82'))

    def test_buttons_and_labels(self):
        s = {'buttons': 'Camera:20,120,200,168;Share:212,120,392,168', 'labels': 'Tilt:Roll the ball;Full:Full screen'}
        self.assertEqual(mobile_web_check.buttons(s), {'Camera': '20,120,200,168', 'Share': '212,120,392,168'})
        self.assertEqual(mobile_web_check.labels(s), {'Tilt': 'Roll the ball', 'Full': 'Full screen'})
        self.assertEqual(mobile_web_check.buttons({}), {})

    def test_middle(self):
        self.assertEqual(mobile_web_check.middle('20,100,370,148'), (195, 124))
        with self.assertRaises(mobile_web_check.CheckError):
            mobile_web_check.middle('')
        with self.assertRaises(mobile_web_check.CheckError):
            mobile_web_check.middle('1,2,3')

    def test_not_from_a_tap_expected(self):
        # a browser with a whole screen: all three say "not from a tap"
        self.assertEqual(mobile_web_check.not_from_a_tap_expected(True),
                         'not from a tap,not from a tap,not from a tap')
        # none at all (an iPhone's Safari, Playwright's WebKit): the whole
        # screen says "not supported", which the library asks first
        self.assertEqual(mobile_web_check.not_from_a_tap_expected(False),
                         'not from a tap,not from a tap,not supported')
        lib = read('extensions', 'script-libraries', 'mobileweb', 'mobileweb.livecodescript')
        body = lib[lib.index('function fullScreen(on) {'):]
        self.assertLess(body.index("return 'not supported';"), body.index("return 'not from a tap';"))
        check = read('tools', 'ci', 'mobile_web_check.py')
        self.assertIn('got == not_from_a_tap_expected(whole)', check)


if __name__ == '__main__':
    unittest.main()
