#!/usr/bin/env python3
"""NOT FOR MAIN. Drives Safari in an iPad simulator through safaridriver:
loads each case of page.html, taps it, and prints the page's time line.

  drive.py pick                 (reads `simctl list devices available -j`
                                 on stdin, prints the iPad to boot)
  drive.py run BASE-URL UDID
"""

import json
import re
import sys
import time

MODES = ['plain', 'focused', 'two-taps', 'blur-before', 'blur-on-change', 'blur-then-focus-later',
         'focus-again-later', 'tap-again', 'tap-again-held', 'readonly', 'button-type', 'canvas', 'never-focused']


def pick():
    devices = json.load(sys.stdin)['devices']
    best = None
    for runtime, entries in devices.items():
        m = re.search(r'iOS-(\d+)-(\d+)', runtime)
        if not m:
            continue
        version = (int(m.group(1)), int(m.group(2)))
        for d in entries:
            name = d.get('name', '')
            if not d.get('isAvailable') or 'iPad' not in name:
                continue
            # a plain iPad before an Air, a mini or a Pro; then the newest system
            rank = (version, 1 if re.match(r'iPad \(', name) else 0)
            if best is None or rank > best[0]:
                best = (rank, d['udid'], name, runtime)
    if best is None:
        sys.exit('no iPad among the available simulators')
    sys.stderr.write('picked %s, %s\n' % (best[2], best[3]))
    print(best[1])


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
        for how in ('click', 'touch'):
            for mode in MODES:
                print('\n===== %s, tapped by %s' % (mode, how), flush=True)
                try:
                    driver.get('%s/page.html?mode=%s&how=%s' % (base, mode, how))
                    time.sleep(1.5)
                    pad = driver.find_element(By.ID, 'pad')
                    tap(pad, how)
                    if mode == 'two-taps':
                        time.sleep(1.5)
                        tap(pad, how)
                    if mode in ('tap-again', 'tap-again-held'):
                        # a second press while the page is full screen
                        time.sleep(2.2)
                        tap(pad, how)
                    end = time.time() + 12
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
        pick()
    elif len(sys.argv) >= 3 and sys.argv[1] == 'run':
        run(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else '')
    else:
        sys.exit(__doc__)
