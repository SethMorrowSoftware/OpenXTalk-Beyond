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


def main():
    folder, order, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    apps = sorted(glob.glob(os.path.join(folder, '*.app')) + glob.glob(os.path.join(folder, '*', '*.app')))
    say('apps: %s' % apps)
    app = apps[0]
    with open(os.path.join(app, 'Contents', 'Info.plist'), 'rb') as f:
        info = plistlib.load(f)
    engine = os.path.join(app, 'Contents', 'MacOS', info['CFBundleExecutable'])
    say('engine: %s (%s)' % (engine, info.get('CFBundleIdentifier')))
    run(['sw_vers'])
    run(['sh', '-c', 'ps -axo pid,ppid,comm | grep -i "hosted-compute\\|Runner\\|provision" | grep -v grep | head -12'])
    tcc = os.path.expanduser('~/Library/Application Support/com.apple.TCC/TCC.db')
    query = ("select service, client, auth_value, indirect_object_identifier from access "
             "where service in ('kTCCServiceAppleEvents', 'kTCCServiceAccessibility') order by 1, 2")
    run(['sqlite3', tcc, query])
    run(['sudo', 'sqlite3', '/Library/Application Support/com.apple.TCC/TCC.db', query])

    with open(os.path.join(out, 'engine-output.txt'), 'wb') as engine_log:
        proc = subprocess.Popen([engine], stdout=engine_log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            time.sleep(100)
            shot(out, '0-ide-started')
            run(['osascript', '-e', WINDOWS], timeout=90)

            first = ask(app, 'ask 1')
            shot(out, '1-after-ask-1')
            run(['osascript', '-e', WINDOWS], timeout=90)
            run(['sh', '-c', 'ps -axo pid,ppid,comm | grep -i "UserNotificationCenter\\|tccd\\|CoreServicesUIAgent\\|universalAccessAuthWarn" | grep -v grep'])

            steps = ('kill', 'allow') if order == 'kill-first' else ('allow', 'kill')
            for n, step in enumerate(steps):
                if step == 'kill':
                    run(['killall', 'UserNotificationCenter'])
                    time.sleep(3)
                    shot(out, '%d-after-kill' % (2 + n * 3))
                    time.sleep(15)
                    shot(out, '%d-after-kill-15-s-later' % (3 + n * 3))
                else:
                    run(['osascript', '-e', CLICK], timeout=90)
                    time.sleep(3)
                    shot(out, '%d-after-allow' % (2 + n * 3))
                again = ask(app, 'ask after %s' % step)
                shot(out, '%d-after-ask-after-%s' % (4 + n * 3, step))
                run(['osascript', '-e', WINDOWS], timeout=90)
            run(['sqlite3', tcc, query])
            say('RESULT order=%s first=%s' % (order, first))
        finally:
            ui_tour.stop(proc)
    # what a later run would find on the screen
    time.sleep(5)
    shot(out, '9-after-the-ide-ended')
    run(['osascript', '-e', WINDOWS], timeout=90)
    return 0


if __name__ == '__main__':
    sys.exit(main())
