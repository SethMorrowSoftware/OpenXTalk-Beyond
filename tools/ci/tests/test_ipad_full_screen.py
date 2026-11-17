"""The page's full screen in a browser of an iPad (engine/src/em-event.js).

Reported from an iPad with iPadOS 18.5, in Safari and in Chrome: the
Phone Starter's "Full screen" goes full screen "but in a split second it
comes back". WebKit ends a page's full screen there when a text input
takes the focus (its bug 185617, "Keyboard focus should exit fullscreen",
iOS only), and the web engine's hidden input is a text input that had the
focus from the first press on a stack. So in those browsers the input is
without the focus from the moment the page asks for full screen until
full screen ends, unless a field wants the keyboard; everywhere else it
keeps the focus as before.

Tested here: the engine's own functions under node (skipped without it)
with a page made of plain objects, in the browsers of an iPad, an iPhone
and five others; the judgement of the check that runs in Chromium
(tools/ci/web_check.py, "?tab=ipad"); and that the two are wired. WebKit's
rule itself is in no browser on Linux: it is not tested here.
"""

import json
import os
import shutil
import subprocess
import sys
import unittest

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))

import web_check  # noqa: E402

NODE = shutil.which('node')
EVENT_JS = os.path.join(REPO, 'engine', 'src', 'em-event.js')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


# The browsers: (what navigator.platform says, navigator.maxTouchPoints)
IPADS = [('MacIntel', 5), ('iPad', 5), ('iPhone', 5), ('iPod', 5)]
OTHERS = [('MacIntel', 0), ('Win32', 10), ('Win32', 0), ('Linux armv81', 5), ('Linux x86_64', 0), ('', 0)]

# The engine's event library with a page of plain objects around it: the
# element with the focus, the document's listeners, the browser's own
# request for full screen (which records what had the focus when it got
# the request), and the timers. Each story starts a new page.
HARNESS = r'''
var fs = require('fs');
var given = process.argv.slice(-2);
var source = fs.readFileSync(given[0], 'utf8');
var browsers = JSON.parse(given[1]);

function page(platform, touchPoints) {
  var told = [], listeners = {}, timers = [], asked = [];
  var active = null;
  function element(tag) {
    var e = {tagName: tag, style: {setProperty: function() {}}, setAttribute: function() {},
             addEventListener: function() {}, removeEventListener: function() {},
             appendChild: function() {}, removeChild: function() {},
             focus: function() { active = e; }, blur: function() { if (active === e) active = body; }};
    return e;
  }
  var body = element('BODY');
  active = body;
  function Element() {}
  Element.prototype.requestFullscreen = function() { asked.push(active); };
  Element.prototype.webkitRequestFullscreen = function() { asked.push(active); };
  var browsersOwn = Element.prototype.requestFullscreen;
  var root = element('HTML');
  Object.setPrototypeOf(root, Element.prototype);
  var document = {
    body: body, documentElement: root, fullscreenElement: null,
    get activeElement() { return active; },
    createElement: function(tag) { return element(tag.toUpperCase()); },
    addEventListener: function(type, f) { (listeners[type] = listeners[type] || []).push(f); }
  };
  var window = {addEventListener: function() {}, devicePixelRatio: 1,
                matchMedia: function() { return {addEventListener: function() {}}; }};
  var navigator = {platform: platform, maxTouchPoints: touchPoints};
  var Module = {ccall: function(name) { told.push(name); return 1; }};
  var LiveCodeDC = {getWindowIDForCanvas: function() { return 1; }, setActiveWindow: function() {},
                    getWindowCanvas: function() { return null; }, raiseWindow: function() {}};
  var LiveCodeAsync = {delay: function(f) { f(); }, resume: function() {}};
  var setTimeout = function(f) { timers.push(f); return timers.length; };
  var clearTimeout = function(id) { if (id) timers[id - 1] = null; };
  var library = null;
  var LibraryManager = {library: {}};
  var mergeInto = function(to, from) { library = from; };
  eval(source);
  var LiveCodeEvents = library.$LiveCodeEvents;
  eval('LiveCodeEvents = library.$LiveCodeEvents');
  LiveCodeEvents.initialize();
  var input = LiveCodeEvents._inputelement;
  var canvas = element('CANVAS');
  function name(e) { return e === input ? 'input' : e.tagName; }
  return {
    events: LiveCodeEvents, input: input, root: root, document: document,
    who: function() { return name(active); },
    asked: function() { return asked.map(name); },
    wrapped: function() { return Element.prototype.requestFullscreen !== browsersOwn; },
    press: function() { LiveCodeEvents._setInputFocus(canvas); },
    fire: function(type) { (listeners[type] || []).forEach(function(f) { f({type: type}); }); },
    goFull: function() { document.fullscreenElement = root; this.fire('fullscreenchange'); },
    leaveFull: function() { document.fullscreenElement = null; this.fire('fullscreenchange'); },
    runTimers: function() { var n = 0; timers.forEach(function(f) { if (f) { n++; f(); } }); timers = []; return n; },
    takeFocus: function(tag) { active = element(tag); },
    toldKeyFocus: function() { return told.filter(function(n) { return n == 'MCEventQueuePostKeyFocus'; }).length; }
  };
}

var answers = browsers.map(function(b) {
  var out = {};
  // a tap on a stack, a tap that asks for full screen, a tap during the
  // change, full screen, a tap in it, back, full screen again, and a
  // field that takes the focus there
  var p = page(b[0], b[1]);
  out.wrapped = p.wrapped();
  p.press(); out.pressed = p.who();
  p.root.requestFullscreen();
  p.press(); out.asking = p.who();
  p.goFull(); out.full = p.who();
  p.press(); out.pressedFull = p.who();
  p.leaveFull(); out.left = p.who();
  p.root.requestFullscreen(); p.goFull(); out.fullAgain = p.who();
  out.toldKeyFocus = p.toldKeyFocus();
  p.events.setTextInput(true); p.events._touchEnded();
  out.field = [p.who(), p.input.inputMode];
  out.asked = p.asked();

  // the prefixed request
  p = page(b[0], b[1]);
  p.press(); p.root.webkitRequestFullscreen(); out.askedPrefixed = p.asked();

  // a request that is refused, with a word and without one
  p = page(b[0], b[1]);
  p.press(); p.root.requestFullscreen(); p.fire('fullscreenerror'); out.refused = p.who();
  p = page(b[0], b[1]);
  p.press(); p.root.requestFullscreen(); out.timers = p.runTimers(); out.refusedSilently = p.who();

  // a field is being typed into when the page asks
  p = page(b[0], b[1]);
  p.press(); p.events.setTextInput(true); p.root.requestFullscreen();
  out.typing = [p.asked(), p.who()];

  // something else in the page took the focus while it was full screen
  p = page(b[0], b[1]);
  p.press(); p.root.requestFullscreen(); p.goFull(); p.takeFocus('TEXTAREA'); p.leaveFull();
  out.pagesOwn = p.who();

  // no stack has the keyboard: full screen and back give the input nothing
  p = page(b[0], b[1]);
  p.root.requestFullscreen(); p.goFull(); p.leaveFull();
  out.noStack = p.who();
  return out;
});
console.log(JSON.stringify(answers));
'''


def under_node(browsers):
    run = subprocess.run([NODE, '-e', HARNESS, EVENT_JS, json.dumps(browsers)],
                         capture_output=True, text=True, timeout=60)
    if run.returncode != 0:
        raise AssertionError('node: %s' % run.stderr.strip()[-600:])
    return json.loads(run.stdout)


@unittest.skipIf(NODE is None, 'no node')
class TheHiddenInput(unittest.TestCase):
    """The engine's functions themselves, in each browser."""

    @classmethod
    def setUpClass(cls):
        cls.ipads = dict(zip(IPADS, under_node(IPADS)))
        cls.others = dict(zip(OTHERS, under_node(OTHERS)))

    def test_a_press_gives_the_input_the_focus_everywhere(self):
        for browser, out in list(self.ipads.items()) + list(self.others.items()):
            self.assertEqual(out['pressed'], 'input', browser)

    def test_on_an_ipad_the_input_is_without_the_focus_when_the_browser_gets_the_request(self):
        # the report's case: it had the focus, and full screen ended at once
        for browser, out in self.ipads.items():
            self.assertTrue(out['wrapped'], browser)
            self.assertEqual(out['asked'], ['BODY', 'BODY'], browser)
            self.assertEqual(out['askedPrefixed'], ['BODY'], browser)

    def test_on_an_ipad_it_takes_no_focus_until_full_screen_ends(self):
        for browser, out in self.ipads.items():
            self.assertEqual((out['asking'], out['full'], out['pressedFull'], out['fullAgain']),
                             ('BODY', 'BODY', 'BODY', 'BODY'), browser)

    def test_on_an_ipad_it_has_the_focus_again_after_full_screen(self):
        for browser, out in self.ipads.items():
            self.assertEqual(out['left'], 'input', browser)

    def test_on_an_ipad_a_refused_request_gives_the_focus_back(self):
        for browser, out in self.ipads.items():
            self.assertEqual(out['refused'], 'input', browser)
            # with no answer at all, a timer ends the wait
            self.assertEqual((out['timers'], out['refusedSilently']), (1, 'input'), browser)

    def test_on_an_ipad_a_field_in_full_screen_gets_the_input_and_the_keyboard(self):
        for browser, out in self.ipads.items():
            self.assertEqual(out['field'], ['input', 'text'], browser)

    def test_on_an_ipad_a_field_being_typed_into_keeps_the_input(self):
        for browser, out in self.ipads.items():
            self.assertEqual(out['typing'], [['input'], 'input'], browser)

    def test_the_stacks_are_told_nothing(self):
        # the first press gave a stack the keyboard; full screen and back
        # tell it nothing more (no focusOut, no suspend)
        for browser, out in list(self.ipads.items()) + list(self.others.items()):
            self.assertEqual(out['toldKeyFocus'], 1, browser)

    def test_the_input_does_not_take_the_focus_from_the_page(self):
        for browser, out in list(self.ipads.items()) + list(self.others.items()):
            self.assertEqual(out['pagesOwn'], 'TEXTAREA', browser)
            self.assertEqual(out['noStack'], 'BODY', browser)

    def test_everywhere_else_nothing_changes(self):
        # a Mac, Windows with and without a touch screen, Android, Linux:
        # the request is the browser's own, no timer is set, and the input
        # keeps the focus throughout (the keys reach a stack in full screen)
        for browser, out in self.others.items():
            self.assertFalse(out['wrapped'], browser)
            self.assertEqual(out['timers'], 0, browser)
            self.assertEqual(out['asked'], ['input', 'input'], browser)
            self.assertEqual(out['askedPrefixed'], ['input'], browser)
            for moment in ('asking', 'full', 'pressedFull', 'left', 'fullAgain', 'refused', 'refusedSilently'):
                self.assertEqual(out[moment], 'input', (browser, moment))
            self.assertEqual(out['field'], ['input', 'text'], browser)
            self.assertEqual(out['typing'], [['input'], 'input'], browser)


class TheSources(unittest.TestCase):
    """What the node tests cannot see without node."""

    def setUp(self):
        self.source = read('engine', 'src', 'em-event.js')

    def member(self, name):
        text = self.source[self.source.index('\t\t%s: function(' % name):]
        return text[:text.index('\n\t\t},\n')]

    def test_an_ipad_that_says_it_is_a_mac_is_known_by_its_touch_screen(self):
        self.assertIn("(/^Mac/.test(tPlatform) && navigator.maxTouchPoints > 1)", self.source)
        self.assertIn("/^(iPhone|iPad|iPod)/.test(tPlatform) ||", self.source)

    def test_only_those_browsers_are_watched(self):
        start = self.member('initialize')
        self.assertIn('if (LiveCodeEvents._isIOS) {\n\t\t\t\tLiveCodeEvents._watchFullScreen();', start)
        self.assertEqual(self.source.count('LiveCodeEvents._watchFullScreen()'), 1)
        held = self.member('_inputHeld')
        self.assertIn('return LiveCodeEvents._isIOS && !LiveCodeEvents._textInput &&', held)

    def test_every_spelling_of_the_request_is_wrapped(self):
        watch = self.member('_watchFullScreen')
        for name in ('requestFullscreen', 'webkitRequestFullscreen', 'webkitRequestFullScreen'):
            self.assertIn("'%s'" % name, watch)
        for name in ('fullscreenchange', 'webkitfullscreenchange', 'fullscreenerror', 'webkitfullscreenerror'):
            self.assertIn("'%s'" % name, watch)

    def test_every_focus_of_the_input_asks_first(self):
        # the three places that give the input the focus: a press (and the
        # engine's own passing of the keyboard), the return from full
        # screen, and the keyboard for a field
        self.assertIn('if (LiveCodeEvents._inputelement != null && !LiveCodeEvents._inputHeld())\n'
                      '\t\t\t\tLiveCodeEvents._inputelement.focus({"preventScroll": true});',
                      self.member('_setInputFocus'))
        self.assertEqual(self.source.count('.focus({"preventScroll": true})'), 2)
        self.assertEqual(self.source.count('input.focus({preventScroll: true})'), 2)


class TheCheck(unittest.TestCase):
    """tools/ci/web_check.py's judgement of what it sees in Chromium."""

    INPUT = ['INPUT', 'none']
    BODY = ['BODY', '']

    def seen(self, like_ipad, full=None):
        full = full or (self.BODY if like_ipad else self.INPUT)
        asked = 'BODY' if like_ipad else 'INPUT'
        return {'pressed': self.INPUT + [False], 'full': full + [True], 'tapped': full + [True],
                'left': self.INPUT + [False], 'full again': full + [True],
                'field': ['INPUT', 'text', True], 'asked': [asked, asked]}

    def test_right(self):
        self.assertEqual(web_check.full_screen_focus_problems(True, self.seen(True)), [])
        self.assertEqual(web_check.full_screen_focus_problems(False, self.seen(False)), [])

    def test_what_the_engine_did_before(self):
        # the input kept the focus everywhere: right anywhere but an iPad
        before = self.seen(False)
        found = web_check.full_screen_focus_problems(True, before)
        self.assertEqual(len(found), 4, found)
        self.assertEqual(sum('WebKit ends full screen for a text input' in said for said in found), 3)
        self.assertIn('when the browser got a request for full screen (INPUT, INPUT)', found[-1])

    def test_an_engine_that_gave_the_focus_up_everywhere(self):
        found = web_check.full_screen_focus_problems(False, self.seen(True))
        self.assertEqual(len(found), 4, found)
        self.assertIn('in a browser that is not an iPad\'s', found[0])
        self.assertIn('a keyboard\'s keys reach the stack through it', found[0])

    def test_the_focus_not_given_back(self):
        seen = self.seen(True)
        seen['left'] = self.BODY + [False]
        found = web_check.full_screen_focus_problems(True, seen)
        self.assertEqual(len(found), 1, found)
        self.assertIn('back from full screen', found[0])

    def test_no_keyboard_for_a_field_in_full_screen(self):
        for field in (self.BODY + [True], ['INPUT', 'none', True]):
            seen = self.seen(True)
            seen['field'] = field
            found = web_check.full_screen_focus_problems(True, seen)
            self.assertEqual(len(found), 1, found)
            self.assertIn('a field in full screen gets the keyboard', found[0])

    def test_a_page_that_never_went_full_screen(self):
        found = web_check.full_screen_focus_problems(True, {'pressed': self.INPUT + [False], 'problem': 'no'})
        self.assertEqual(found, ['in a browser of an iPad, no'])

    def test_a_moment_not_read_or_a_request_missing(self):
        seen = self.seen(True)
        del seen['tapped']
        seen['asked'] = ['BODY']
        found = web_check.full_screen_focus_problems(True, seen)
        self.assertEqual(len(found), 2, found)
        self.assertIn('could not be read', found[0])
        self.assertIn('expected two', found[1])

    def test_the_page_is_made_to_look_like_an_ipad(self):
        # as the engine tells one (TheSources): a Mac with a touch screen
        self.assertIn("return 'MacIntel';", web_check.IPAD_HOOK)
        self.assertIn('return 5;', web_check.IPAD_HOOK)
        self.assertIn("'virtualKeyboard', {value: undefined", web_check.IPAD_HOOK)

    def test_the_check_is_wired(self):
        check = read('tools', 'ci', 'web_check.py')
        self.assertIn("'tab=ipad'", check)
        self.assertIn('for like_ipad in (True, False):', check)
        self.assertIn('pad.add_init_script(IPAD_HOOK)', check)
        self.assertIn('full_screen_focus_problems(like_ipad, full_screen_focus_seen(tab, info[\'field-rect\']))',
                      check)
        # the browser's request is recorded inside the engine's wrap
        self.assertIn('pad.add_init_script(FULL_SCREEN_ASK_HOOK)', check)
        self.assertIn('window.__oxtAskedWith.push(', web_check.FULL_SCREEN_ASK_HOOK)
        self.assertEqual([m for m, _ in web_check.FULL_SCREEN_MOMENTS],
                         ['pressed', 'full', 'tapped', 'left', 'full again', 'field'])


if __name__ == '__main__':
    unittest.main()
