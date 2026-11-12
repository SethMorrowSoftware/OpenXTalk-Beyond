#!/usr/bin/env python3
"""EXPERIMENT, not for merging. What macOS shows when the runner asks the
IDE a question by AppleScript (tools/ci/ui_tour.py, mac_ask), which
process owns that consent dialog, and what takes it off the screen.

  python3 tools/ci/zz_mac_consent_experiment.py <folder with the .app> <kill-first|allow-first> <out>
"""

import glob
import os
import plistlib
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ui_tour  # noqa: E402

WINDOWS = '''
tell application "System Events"
  set out to ""
  repeat with p in (every process)
    try
      repeat with w in (every window of p)
        set line_ to (name of p as text) & " | "
        try
          set line_ to line_ & (name of w as text)
        end try
        set line_ to line_ & " | "
        try
          set line_ to line_ & (subrole of w as text)
        end try
        set line_ to line_ & " | buttons:"
        try
          repeat with b in (every button of w)
            try
              set line_ to line_ & " [" & (name of b as text) & "]"
            end try
          end repeat
        end try
        set out to out & line_ & linefeed
      end repeat
    end try
  end repeat
  return out
end tell
'''

CLICK = '''
tell application "System Events"
  repeat with p in (every process)
    try
      repeat with w in (every window of p)
        if (exists button "Allow" of w) then
          click button "Allow" of w
          return "clicked Allow in a window of " & (name of p as text)
        end if
      end repeat
    end try
  end repeat
  return "no window with an Allow button"
end tell
'''


def say(text=''):
    print(text)
    sys.stdout.flush()


def run(cmd, timeout=60):
    started = time.time()
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        out, code = proc.stdout.decode('utf-8', 'replace').strip(), proc.returncode
    except subprocess.TimeoutExpired:
        out, code = '(no answer in %d s)' % timeout, -1
    say('$ %s\n  -> %s after %.1f s\n%s' % (' '.join(cmd)[:120].replace('\n', ' '), code, time.time() - started,
                                         '\n'.join('  ' + line for line in out.split('\n')[:60])))
    return code, out


def shot(out, name):
    path = os.path.join(out, name + '.png')
    if ui_tour.mac_screen(path):
        ui_tour.print_image('consent/' + name + '.png', path)
        say('SHOT %s' % name)


def ask(app, label):
    say('--- %s: asking the IDE' % label)
    started = time.time()
    answered = ui_tour.mac_ask(app, questions=('the version', 'the number of lines of the openStacks'), timeout=20)
    say('--- %s: answered %s after %.1f s' % (label, answered, time.time() - started))
    return answered


def dialog():
    """True when a window of UserNotificationCenter is on the screen."""
    code, out = run(['osascript', '-e', WINDOWS], timeout=90)
    return 'UserNotificationCenter' in out


def main():
    """Round 2: the runner's own mac_ask as the fix has it. First with
    mac_allow turned off, so that the question stays unanswered and
    mac_close_consent must take it away; then as it is, so that Allow is
    pressed and the answers come; then once more."""
    folder, out = sys.argv[1], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    apps = sorted(glob.glob(os.path.join(folder, '*.app')) + glob.glob(os.path.join(folder, '*', '*.app')))
    app = apps[0]
    with open(os.path.join(app, 'Contents', 'Info.plist'), 'rb') as f:
        info = plistlib.load(f)
    engine = os.path.join(app, 'Contents', 'MacOS', info['CFBundleExecutable'])
    say('engine: %s (%s)' % (engine, info.get('CFBundleIdentifier')))
    run(['sw_vers'])
    results = {}
    with open(os.path.join(out, 'engine-output.txt'), 'wb') as engine_log:
        proc = subprocess.Popen([engine], stdout=engine_log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            time.sleep(100)
            shot(out, '0-ide-started')
            results['no dialog before'] = not dialog()

            real_allow = ui_tour.mac_allow
            ui_tour.mac_allow = lambda app: False
            try:
                results['unanswered ask is False'] = ask(app, 'ask A, Allow not pressed') is False
            finally:
                ui_tour.mac_allow = real_allow
            time.sleep(3)
            shot(out, '1-after-ask-a-closed')
            results['no dialog after the close'] = not dialog()

            results['ask with Allow is True'] = ask(app, 'ask B, as the fix has it') is True
            time.sleep(3)
            shot(out, '2-after-ask-b-allowed')
            results['no dialog after Allow'] = not dialog()

            started = time.time()
            results['asked again is True'] = ask(app, 'ask C, again') is True
            results['asked again at once'] = time.time() - started < 10
        finally:
            ui_tour.stop(proc)
    time.sleep(5)
    shot(out, '9-after-the-ide-ended')
    results['no dialog at the end'] = not dialog()
    for name, good in results.items():
        say('RESULT %s: %s' % (name, 'yes' if good else 'NO'))
    return 0 if all(results.values()) else 1


if __name__ == '__main__':
    sys.exit(main())
