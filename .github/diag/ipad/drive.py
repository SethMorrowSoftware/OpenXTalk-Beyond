#!/usr/bin/env python3
"""NOT FOR MAIN. Taps the cases of page.html in Safari on an iPad simulator
and prints each page's time line.

  drive.py pick [VERSION]       (reads `simctl list devices available -j`
                                 on stdin, prints the iPad to boot: of the
                                 newest system, of the newest 18.x for
                                 "18", or of 18.5 for "18.5")
  drive.py real BASE-URL UDID SERVE-LOG
                                (a real tap: Safari opened with simctl
                                 openurl, and the mouse clicked on the
                                 Simulator's window, which is a finger on
                                 the screen. The pages' time lines are in
                                 SERVE-LOG, where serve.py writes them)
  drive.py run BASE-URL UDID    (through safaridriver, whose taps gave the
                                 page no user activation in the first run:
                                 "Cannot request fullscreen without
                                 transient activation")
"""

import json
import re
import subprocess
import sys
import time

MODES = ['plain', 'focused', 'two-taps', 'blur-before', 'blur-on-change', 'blur-then-focus-later',
         'focus-again-later', 'tap-again', 'tap-again-held', 'readonly', 'button-type', 'canvas', 'never-focused']
# The cases that take a second tap, and how long after the first
SECOND_TAP = {'two-taps': 1.5, 'tap-again': 2.2, 'tap-again-held': 2.2}


def pick(major=None):
    devices = json.load(sys.stdin)['devices']
    best = None
    for runtime, entries in devices.items():
        m = re.search(r'iOS-(\d+)-(\d+)', runtime)
        if not m:
            continue
        version = (int(m.group(1)), int(m.group(2)))
        # MAJOR, or MAJOR.MINOR for that system alone
        wanted = [int(n) for n in major.split('.')] if major else []
        if list(version[:len(wanted)]) != wanted:
            continue
        for d in entries:
            name = d.get('name', '')
            if not d.get('isAvailable') or 'iPad' not in name:
                continue
            # a plain iPad before an Air, a mini or a Pro; then the newest system
            rank = (version, 1 if re.match(r'iPad \(', name) else 0, name)
            if best is None or rank > best[0]:
                best = (rank, d['udid'], name, runtime)
    if best is None:
        sys.exit('no iPad among the available simulators%s' % (' of iOS %s' % major if major else ''))
    sys.stderr.write('picked %s, %s\n' % (best[2], best[3]))
    print(best[1])


# ---------------------------------------------------------------- real taps

def osa(script, javascript=False):
    cmd = ['osascript'] + (['-l', 'JavaScript'] if javascript else []) + ['-e', script]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=40)
    except subprocess.TimeoutExpired:
        return 1, 'osascript did not answer in 40 s'
    return r.returncode, (r.stdout + r.stderr).strip()[:300]


WINDOW = '''
tell application "System Events" to tell process "Simulator"
  set frontmost to true
  set p to position of window 1
  set s to size of window 1
  return (item 1 of p as text) & "," & (item 2 of p as text) & "," & (item 1 of s as text) & "," & (item 2 of s as text)
end tell'''

CLICK_SYSTEM_EVENTS = 'tell application "System Events" to click at {%d, %d}'

CLICK_QUARTZ = '''
ObjC.import('CoreGraphics');
var p = $.CGPointMake(%d, %d);
var down = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseDown, p, $.kCGMouseButtonLeft);
var up = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseUp, p, $.kCGMouseButtonLeft);
$.CGEventPost($.kCGHIDEventTap, down);
delay(0.08);
$.CGEventPost($.kCGHIDEventTap, up);
'''


# The same from the window server's list, which asks no permission of
# System Events: the biggest window of the Simulator on the screen
WINDOW_QUARTZ = '''
ObjC.import('CoreGraphics');
var ref = $.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements, 0);
var list = ObjC.deepUnwrap(ObjC.castRefToObject(ref));
var best = null;
list.forEach(function(w) {
  if (w.kCGWindowOwnerName != 'Simulator' || w.kCGWindowLayer != 0) return;
  var b = w.kCGWindowBounds;
  if (!best || b.Width * b.Height > best.Width * best.Height) best = b;
});
best ? [best.X, best.Y, best.Width, best.Height].map(Math.round).join(',') : 'no window';
'''


def window():
    """(left, top, width, height) of the Simulator's window, or None."""
    subprocess.run(['open', '-a', 'Simulator'], capture_output=True, timeout=60)
    for name, script, javascript in (('System Events', WINDOW, False), ('the window list', WINDOW_QUARTZ, True)):
        code, out = osa(script, javascript)
        numbers = re.findall(r'-?\d+', out) if code == 0 else []
        if len(numbers) == 4 and int(numbers[2]) > 100 and int(numbers[3]) > 100:
            print('  the Simulator\'s window by %s: %s' % (name, out), flush=True)
            return tuple(int(n) for n in numbers)
        print('  the Simulator\'s window by %s: %s (%d)' % (name, out, code), flush=True)
    return None


def click(way, point):
    if way == 'system-events':
        return osa(CLICK_SYSTEM_EVENTS % point)
    return osa(CLICK_QUARTZ % point, javascript=True)


class Served:
    """What serve.py wrote: the pages' beacons and time lines."""

    def __init__(self, path):
        self.path = path
        self.seen = 0

    def new_text(self):
        with open(self.path, encoding='utf-8', errors='replace') as f:
            text = f.read()
        fresh, self.seen = text[self.seen:], len(text)
        return fresh

    def wait_for(self, word, seconds):
        """The text written since the last look, once it holds word (or
        one of the words; or after the seconds)."""
        words = (word,) if isinstance(word, str) else word
        text = ''
        end = time.time() + seconds
        while time.time() < end:
            text += self.new_text()
            if any(w in text for w in words):
                return text, True
            time.sleep(0.3)
        return text, False


def left_words(mode, ask, tag):
    """What a page says when it has left full screen (or could not)."""
    return tuple('BEACON left full=%s mode=%s ask=%s how=%s' % (full, mode, ask, tag) for full in ('false', 'true'))


def real(base, udid, serve_log):
    served = Served(serve_log)
    box = None
    for attempt in range(20):
        box = window()
        if box:
            break
        time.sleep(3)
    if not box:
        sys.exit('the Simulator has no window to click on')
    left, top, width, height = box
    print('the Simulator\'s window: %dx%d at (%d, %d)' % (width, height, left, top), flush=True)
    # points of the window to try: the middle of the screen first
    points = [(left + width // 2, top + height // 2), (left + width // 2, top + height * 2 // 3),
              (left + width // 2, top + height // 3)]

    def open_page(mode, ask, tag):
        url = '%s/page.html?mode=%s&ask=%s&how=%s' % (base, mode, ask, tag)
        subprocess.run(['xcrun', 'simctl', 'openurl', udid, url], capture_output=True, timeout=60)
        text, loaded = served.wait_for('BEACON loaded mode=%s ask=%s how=%s' % (mode, ask, tag), 25)
        return loaded

    # which click reaches the page as a touch
    working = None
    for n, (way, point) in enumerate((w, p) for p in points for w in ('system-events', 'quartz')):
        tag = 'probe%d' % n
        if not open_page('never-focused', 'touchend', tag):
            print('  the probe page %s did not load' % tag, flush=True)
            continue
        time.sleep(1.5)
        code, out = click(way, point)
        text, touched = served.wait_for('BEACON touched', 6)
        print('  a click by %s at %s: %s%s' % (way, point, 'a touch reached the page' if touched
                                               else 'no touch reached the page',
                                               ' (osascript %d: %s)' % (code, out) if code or out else ''),
              flush=True)
        if touched:
            working = (way, point)
            probe_tag = tag
            break
    if not working:
        sys.exit('no click on the Simulator\'s window reached the page as a touch')
    way, point = working
    # the probe's page went full screen: it leaves by itself when it is done
    text, left = served.wait_for(left_words('never-focused', 'touchend', probe_tag), 22)
    print('  the probe\'s page %s' % ('left full screen' if left else 'did not say it left full screen'), flush=True)
    for line in text.splitlines():
        if line.startswith('  | ') and 'BEACON' not in line:
            print('  ' + line[4:300], flush=True)
    time.sleep(1.5)

    def case(mode, ask):
        print('\n===== %s, asked at %s, a real tap' % (mode, ask), flush=True)
        text = ''
        for tag in ('real', 'real-again'):
            if not open_page(mode, ask, tag):
                print('  FAILED: the page did not load', flush=True)
                return
            time.sleep(1.5)
            click(way, point)
            if mode in SECOND_TAP:
                time.sleep(SECOND_TAP[mode])
                click(way, point)
            text, touched = served.wait_for('BEACON touched mode=%s ask=%s how=%s' % (mode, ask, tag), 5)
            if touched:
                break
            # Another page's full screen may still be over this one: Safari
            # afresh, and the case once more
            print('  no touch reached the page (%s): Safari is ended and the case tried %s'
                  % (tag, 'again' if tag == 'real' else 'no more'), flush=True)
            subprocess.run(['xcrun', 'simctl', 'terminate', udid, 'com.apple.mobilesafari'],
                           capture_output=True, timeout=60)
            time.sleep(3)
        else:
            print('  FAILED: no touch reached the page', flush=True)
            return
        more, done = served.wait_for(left_words(mode, ask, tag), 22)
        for line in (text + more).splitlines():
            if line.startswith('  | ') and 'BEACON' not in line:
                print('  ' + line[4:300], flush=True)
        if not done:
            print('  FAILED: the page did not say it left full screen', flush=True)
        time.sleep(1.5)

    for mode in MODES:
        case(mode, 'touchend')
    for ask in ('click', 'pointerup'):
        for mode in ('plain', 'focused', 'blur-before'):
            case(mode, ask)


# -------------------------------------------------------------- safaridriver

def run(base, udid):
    from selenium import webdriver
    from selenium.webdriver.common.actions import interaction
    from selenium.webdriver.common.actions.action_builder import ActionBuilder
    from selenium.webdriver.common.actions.pointer_input import PointerInput
    from selenium.webdriver.common.by import By
    from selenium.webdriver.safari.options import Options

    opts = Options()
    opts.set_capability('platformName', 'iOS')
    opts.set_capability('safari:useSimulator', True)
    opts.set_capability('safari:deviceType', 'iPad')
    if udid:
        opts.set_capability('safari:deviceUDID', udid)
    driver = webdriver.Safari(options=opts)
    print('session: %s' % json.dumps(driver.capabilities)[:600], flush=True)

    def tap(element, how):
        if how == 'click':
            element.click()
            return
        finger = PointerInput(interaction.POINTER_TOUCH, 'finger')
        actions = ActionBuilder(driver, mouse=finger)
        actions.pointer_action.move_to(element).pointer_down().pause(0.08).pointer_up()
        actions.perform()

    try:
        for ask in ('click', 'pointerup', 'touchend'):
            for how in ('click', 'touch'):
                for mode in ('plain', 'focused', 'two-taps', 'blur-before'):
                    print('\n===== %s, asked at %s, tapped by the driver\'s %s' % (mode, ask, how), flush=True)
                    try:
                        driver.get('%s/page.html?mode=%s&ask=%s&how=driver-%s' % (base, mode, ask, how))
                        time.sleep(1.5)
                        pad = driver.find_element(By.ID, 'pad')
                        tap(pad, how)
                        if mode in SECOND_TAP:
                            time.sleep(SECOND_TAP[mode])
                            tap(pad, how)
                        end = time.time() + 8
                        while time.time() < end:
                            if driver.execute_script('return window.__done === true'):
                                break
                            time.sleep(0.3)
                        for line in driver.execute_script('return window.__log') or []:
                            print('  ' + str(line)[:300], flush=True)
                    except Exception as e:  # a case that fails says so, and the next is tried
                        print('  FAILED: %s' % str(e).splitlines()[0][:300], flush=True)
    finally:
        driver.quit()


if __name__ == '__main__':
    if len(sys.argv) >= 2 and sys.argv[1] == 'pick':
        pick(sys.argv[2] if len(sys.argv) > 2 else None)
    elif len(sys.argv) >= 5 and sys.argv[1] == 'real':
        real(sys.argv[2], sys.argv[3], sys.argv[4])
    elif len(sys.argv) >= 3 and sys.argv[1] == 'run':
        run(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else '')
    else:
        sys.exit(__doc__)
