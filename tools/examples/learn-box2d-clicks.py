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

"""Clicks every part of "Learn Box2D" with a real mouse, and checks what
each click did.

  python3 tools/examples/learn-box2d-clicks.py --install DIR
      [--stack FILE] [--shots DIR] [--log FILE]

The stack runs in the install's standalone engine
(Runtime/Linux/x86-64/Standalone), in a real window on a screen of its
own (an Xvfb server this starts), with Box2Dxt loaded from the install;
learn-box2d-clicks.livecodescript, beside this, writes what the window
shows to a file ten times a second. xdotool moves the mouse, presses its
button and the keys, as a person does, so each click goes the whole way
the engine sends a click: a script that calls a handler would skip the
field, the card and the window it passes through, and a bug there (a call
in a lesson's list that said nothing when clicked) would go unseen.

What it clicks, and what must follow:

  the front page   its banner's toy rains shapes, a click in the banner
                   keeps them, a tile goes to its lesson, the sidebar
                   goes back
  every lesson     reached by its line in the sidebar; its world runs
                   (no "Stopped", bodies drawn); each of its buttons, and
                   the world still runs after each; each Box2D call in its
                   list (scrolled to with the wheel) says what it does;
                   Pause shows Play and holds the world, Step keeps it
                   paused, Pause again runs it; Reset makes the lesson
                   again; a body that moves, dragged with the mouse,
                   follows it; Scripts opens the drawer and shuts it
  Ray Casts        a click beside a body finds it (b2OverlapCircle)
  Terrain          a click above a body blasts it (b2WorldExplode)
  Wheels           the right arrow key drives the car
  Back and Next    and the left and right arrow keys, between lessons

It writes a line for each check, PASS or FAIL, and ends with "DONE"
(exit status 0) or "FAILED <how many>" (exit status 1). With --shots, a
picture of each lesson after its clicks.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
PROBE = os.path.join(HERE, 'learn-box2d-clicks.livecodescript')
STACK = os.path.join(REPO, 'ide', 'Resources', 'Examples', 'Remastered', 'Learn Box2D.oxtstack')
# The sidebar's first line (the front page), and the room each line has
SIDEBAR_X, SIDEBAR_Y, SIDEBAR_STEP = 100, 99, 30


class Run:
    def __init__(self, args):
        self.args = args
        self.fails = 0
        self.work = tempfile.mkdtemp(prefix='learn-box2d-clicks-')
        self.state_file = os.path.join(self.work, 'state')
        self.display = ':%d' % (90 + os.getpid() % 100)
        self.env = dict(os.environ, DISPLAY=self.display, OXT_INSTALL=args.install,
                        OXT_LEARN_BOX2D=args.stack, OXT_CLICKS_STATE=self.state_file)
        self.log_file = open(args.log, 'w', encoding='utf-8') if args.log else None
        # Where the card's 0,0 is on the screen (the window is put at the
        # top left, but where its content lands is the X server's say)
        self.dx = self.dy = 0

    def calibrate(self):
        self.xdo('mousemove', 500, 300)
        st = self.wait_for(lambda s: s.get('mouse', '').count(',') == 1, 3)
        time.sleep(0.3)
        mx, my = rect(self.state()['mouse'])
        self.dx, self.dy = 500 - mx, 300 - my
        self.say('INFO the card is at %d,%d on the screen' % (self.dx, self.dy))

    def move(self, x, y):
        self.xdo('mousemove', int(x) + self.dx, int(y) + self.dy)

    # -- what the stack says

    def state(self):
        for _ in range(60):
            try:
                with open(self.state_file, encoding='utf-8', errors='replace') as f:
                    text = f.read()
                if text:
                    return dict(line.split('=', 1) for line in text.splitlines() if '=' in line)
            except FileNotFoundError:
                pass
            time.sleep(0.1)
        return {}

    def errors(self):
        try:
            with open(self.state_file + '.errors', encoding='utf-8', errors='replace') as f:
                return f.read().strip()
        except FileNotFoundError:
            return ''

    def wait_for(self, test, seconds):
        """The state once test(state) holds, or the last one after seconds"""
        end = time.time() + seconds
        st = self.state()
        while time.time() < end:
            if test(st):
                return st
            time.sleep(0.1)
            st = self.state()
        return st

    # -- the mouse and keys

    def xdo(self, *words):
        subprocess.run(['xdotool'] + [str(w) for w in words], env=self.env, check=True)

    def click(self, x, y, settle=0.5):
        self.move(x, y)
        time.sleep(0.08)
        self.xdo('click', 1)
        time.sleep(settle)
        return self.state()

    def key(self, name, hold=0.0, settle=0.4):
        if hold:
            self.xdo('keydown', name)
            time.sleep(hold)
            self.xdo('keyup', name)
        else:
            self.xdo('key', name)
        time.sleep(settle)
        return self.state()

    def drag(self, x1, y1, x2, y2, steps=12, hold=0.4):
        self.move(x1, y1)
        time.sleep(0.1)
        self.xdo('mousedown', 1)
        for i in range(1, steps + 1):
            self.move(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps)
            time.sleep(0.03)
        time.sleep(hold)
        st = self.state()
        self.xdo('mouseup', 1)
        return st

    def shot(self, name):
        if self.args.shots:
            os.makedirs(self.args.shots, exist_ok=True)
            subprocess.run(['import', '-window', 'root', '-crop', '1024x640+%d+%d' % (max(0, self.dx), max(0, self.dy)),
                            os.path.join(self.args.shots, name + '.png')], env=self.env)

    # -- reporting

    def say(self, line):
        print(line, flush=True)
        if self.log_file:
            self.log_file.write(line + '\n')

    def check(self, ok, what, detail=''):
        if ok:
            self.say('PASS %s' % what)
        else:
            self.fails += 1
            self.say('FAIL %s%s' % (what, (' (' + detail + ')') if detail else ''))
        return ok


def rect(text):
    return [int(float(v)) for v in text.split(',')]


def middle(r):
    return (r[0] + r[2]) // 2, (r[1] + r[3]) // 2


def table(text):
    """"name:l,t,r,b;..." as [(name, rect)]"""
    out = []
    for part in (text or '').split(';'):
        if ':' in part:
            name, where = part.rsplit(':', 1)
            out.append((name, rect(where)))
    return out


def stopped(st):
    said = st.get('readout', '')
    return said.startswith('Stopped') or said.startswith('Box2D is not loaded')


def go_lesson(run, index):
    """Its line in the sidebar (index 0 is the front page)"""
    return run.click(SIDEBAR_X, SIDEBAR_Y + SIDEBAR_STEP * index, 0.3)


def front(run):
    st = run.click(SIDEBAR_X, SIDEBAR_Y, 0.3)
    st = run.wait_for(lambda s: s.get('card') == 'Start' and int(s.get('toy', 0)) > 6, 4)
    run.check(st.get('card') == 'Start' and int(st.get('toy', 0)) > 6, 'Start: the banner\'s toy rains shapes',
              'card %s, %s graphics' % (st.get('card'), st.get('toy')))
    shapes = int(st.get('toy', 0))
    hero = rect(st['hero'])
    st = run.click(hero[2] - 100, hero[3] - 30, 0.8)
    run.check(st.get('card') == 'Start' and int(st.get('toy', 0)) >= shapes and not run.errors(),
              'Start: a click in the banner (a blast) keeps the toy running', run.errors())
    tiles = [r for a, r in table(st.get('actions')) if a.startswith('go ')]
    run.check(len(tiles) == 13, 'Start: 13 tiles', '%d' % len(tiles))
    if tiles:
        st = run.click(*middle(tiles[5]), settle=0.6)
        run.check(st.get('card') == 'Hinges', 'Start: the sixth tile goes to Hinges', st.get('card', ''))
    run.shot('00-Start')


def lesson(run, index, name):
    st = go_lesson(run, index)
    st = run.wait_for(lambda s: s.get('card') == name and int(s.get('bodies', 0)) > 2, 4)
    if not run.check(st.get('card') == name, '%s: the sidebar opens it' % name, st.get('card', '')):
        return
    time.sleep(1.0)
    st = run.state()
    start_bodies = int(st.get('bodies', 0))
    run.check(not stopped(st) and start_bodies > 2, '%s: the world runs' % name,
              '%s; %d graphics' % (st.get('readout'), start_bodies))
    # Each of the lesson's buttons
    for handler, r in table(st.get('buttons')):
        st = run.click(*middle(r), settle=0.7)
        if name == 'Wheels':
            # (its buttons drive for a moment, then the car rests)
            time.sleep(0.4)
            st = run.state()
        run.check(not stopped(st) and not run.errors(), '%s: button %s' % (name, handler),
                  st.get('readout', '') + ' ' + run.errors())
    # Each call in the list says what it does
    calls(run, name)
    # Pause, Step, Pause
    lab = dict(table(st.get('lab')))
    st = run.click(*middle(lab['LabPause']), settle=0.4)
    run.check(st.get('pause') == 'Play', '%s: Pause shows Play' % name, st.get('pause', ''))
    before = st.get('dynamic')
    time.sleep(0.5)
    st = run.state()
    run.check(st.get('dynamic') == before, '%s: paused, nothing moves' % name)
    st = run.click(*middle(lab['LabStep']), settle=0.4)
    run.check(st.get('pause') == 'Play', '%s: Step keeps it paused' % name, st.get('pause', ''))
    st = run.click(*middle(lab['LabPause']), settle=0.4)
    run.check(st.get('pause') == 'Pause', '%s: Pause again runs it' % name, st.get('pause', ''))
    # Reset makes the lesson again
    st = run.click(*middle(lab['LabReset']), settle=1.0)
    time.sleep(1.0)
    st = run.state()
    run.check(not stopped(st) and abs(int(st.get('bodies', 0)) - start_bodies) <= max(3, start_bodies // 4),
              '%s: Reset makes the lesson again' % name,
              '%s graphics, %d at the start' % (st.get('bodies'), start_bodies))
    # A body dragged with the mouse follows it (after Reset: the buttons
    # may have blown everything against a wall)
    time.sleep(1.0)
    drag(run, name)
    if name in ('Rays', 'Terrain'):
        empty_click(run, name)
    st = run.state()
    # Scripts opens the drawer, and shuts it
    scripts = [r for a, r in table(st.get('actions')) if a == 'scripts']
    if run.check(len(scripts) == 1, '%s: a Scripts button' % name):
        st = run.click(*middle(scripts[0]), settle=0.6)
        run.check(st.get('drawer') == 'true', '%s: Scripts opens the drawer' % name)
        if name == 'Hinges':
            run.shot('06-Hinges-scripts')
        st = run.click(*middle(scripts[0]), settle=0.6)
        run.check(st.get('drawer') == 'false', '%s: Scripts shuts it' % name)
    if name == 'Wheels':
        st = run.click(*middle(lab['LabReset']), settle=1.5)
        st = run.key('Right', hold=1.5, settle=0.1)
        speed = st.get('readout', '').split('speed', 1)[-1].split()[0] if 'speed' in st.get('readout', '') else ''
        try:
            run.check(float(speed) > 0.3, 'Wheels: the right arrow key drives the car', st.get('readout', ''))
        except ValueError:
            run.check(False, 'Wheels: the right arrow key drives the car', st.get('readout', ''))
    run.shot('%02d-%s' % (index, name))


def calls(run, name):
    st = run.state()
    names = [n for n in st.get('callnames', '').split(',') if n]
    box = rect(st['calls'])
    height = int(st.get('callsheight', 17))
    margin = int(st.get('callsmargin', 4))
    shown = (box[3] - box[1] - 2 * margin) // height
    good = 0
    for i, call in enumerate(names):
        # (the wheel scrolls the list, a few lines a turn, until the line shows)
        for _ in range(30):
            scroll = int(st.get('callsscroll', 0))
            first = scroll // height
            if first <= i < first + shown:
                break
            run.move((box[0] + box[2]) // 2, (box[1] + box[3]) // 2)
            run.xdo('click', 5 if i >= first + shown else 4)
            time.sleep(0.15)
            st = run.state()
        y = box[1] + margin + (i - int(st.get('callsscroll', 0)) / height) * height + height // 2
        st = run.click(box[0] + 30, y, 0.3)
        if st.get('calldoc', '').startswith(call):
            good += 1
        else:
            run.check(False, '%s: clicking %s explains it' % (name, call), 'it says: %s' % st.get('calldoc', ''))
    run.check(good == len(names) and good > 0, '%s: each of its %d Box2D calls, clicked, says what it does'
              % (name, len(names)), '%d of %d' % (good, len(names)))


def dynamic(run, st=None):
    """The bodies that move, well inside the court and clear of the buttons
    at its top: [(body, (x, y))]"""
    st = st or run.state()
    court = rect(st['court'])
    return [(b, tuple(p)) for b, p in table(st.get('dynamic'))
            if court[0] + 30 < p[0] < court[2] - 30 and court[1] + 70 < p[1] < court[3] - 2]


def drag(run, name):
    st = run.state()
    court = rect(st['court'])
    # The bodies no joint holds go first, then the rest newest first: a
    # body on a hinge, a slider or a motor, such as a windmill's blade or a
    # lift, may not go where it is pulled. And a press lands where the body
    # WAS when the state was read, so one still rolling (a ball rolls on a
    # flat floor for as long as nothing stops it) is pressed beside it and
    # the drag pulls nothing: a free body counts as still when it moved
    # under 3 pixels in a quarter of a second, and the test waits up to
    # four seconds for one, then tries the stillest
    free = set(n for n in st.get('free', '').split(',') if n)
    for _ in range(16):
        before = dict(dynamic(run, st))
        time.sleep(0.25)
        st = run.state()
        bodies = list(reversed(dynamic(run, st)))

        def moved(b):
            was = before.get(b[0], (-999, -999))
            return ((b[1][0] - was[0]) ** 2 + (b[1][1] - was[1]) ** 2) ** 0.5
        loose = sorted([b for b in bodies if b[0] in free], key=lambda b: (moved(b) // 3, b[1][1]))
        if not loose or moved(loose[0]) < 3:
            break
    tries = (loose + [b for b in bodies if b[0] not in free])[:6]
    if not run.check(bool(tries), '%s: a body to drag' % name, 'none in the court'):
        return
    why = []
    # (a body a joint holds, such as a lift on its motor or a flap at its
    # limit, may not go where it is pulled: one of the first few must)
    for body, (x, y) in tries:
        tx = (court[0] + court[2]) // 2 + (60 if x < (court[0] + court[2]) // 2 else -60)
        ty = court[1] + 160
        st = run.drag(x, y, tx, ty, hold=0.8)
        now = dict(table(st.get('dynamic')))
        time.sleep(0.4)
        if body not in now:
            why.append('%s is gone' % body)
            continue
        nx, ny = now[body]
        moved = ((nx - x) ** 2 + (ny - y) ** 2) ** 0.5
        near = ((nx - tx) ** 2 + (ny - ty) ** 2) ** 0.5
        if moved > 30 and near < moved:
            run.check(True, '%s: a dragged body follows the mouse' % name)
            return
        why.append('%s%s from %d,%d toward %d,%d: now %d,%d'
                   % (body, '' if body in free else ' (jointed)', x, y, tx, ty, nx, ny))
    run.check(False, '%s: a dragged body follows the mouse' % name, '; '.join(why))


def empty_click(run, name):
    """Rays and Terrain: a click on empty space, beside a body. A click ON a
    body is a drag, so the spot must be clear of every other body (and the
    bodies may still be settling): the bodies whose spot is furthest from
    the rest are tried, up to three, until one answers"""
    bodies = dynamic(run)
    if not run.check(bool(bodies), '%s: a body to click beside' % name):
        return

    def spot(x, y):
        # Rays: 35 pixels (0.7 metres) beside it, within the metre the
        # click asks about; Terrain: 45 pixels above it
        if name == 'Rays':
            return (x + 35 if x < 475 else x - 35), y
        return x, y - 45

    def clearance(item):
        b, (bx, by) = item
        sx, sy = spot(bx, by)
        return min([((ox - sx) ** 2 + (oy - sy) ** 2) ** 0.5
                    for o, (ox, oy) in bodies if o != b] or [999])

    what = {'Rays': 'Rays: a click beside a body finds it',
            'Terrain': 'Terrain: a click above a body blasts it'}[name]
    why = ''
    for body, (x, y) in sorted(bodies, key=clearance, reverse=True)[:3]:
        st = run.click(*spot(x, y), settle=0.6)
        if name == 'Rays':
            found = st.get('readout', '').split('a click found', 1)[-1].split()
            if found and found[0].isdigit() and int(found[0]) >= 1:
                run.check(not run.errors(), what, 'a script error')
                return
            why = st.get('readout', '')
        else:
            now = dict(table(st.get('dynamic')))
            if body in now and abs(now[body][1] - y) + abs(now[body][0] - x) > 4:
                run.check(not run.errors(), what, 'a script error')
                return
            why = '%s -> %s' % ((x, y), now.get(body))
        time.sleep(0.5)
        bodies = dynamic(run)
    run.check(False, what, why)


def keys(run):
    st = go_lesson(run, 2)
    st = run.wait_for(lambda s: s.get('card') == 'Bodies', 3)
    # (a click on the court's floor leaves the focus on the card)
    st = run.key('Right', settle=0.8)
    run.check(st.get('card') == 'Shapes', 'the right arrow key goes to the next lesson', st.get('card', ''))
    st = run.key('Left', settle=0.8)
    run.check(st.get('card') == 'Bodies', 'the left arrow key goes back', st.get('card', ''))
    nxt = [r for a, r in table(st.get('actions')) if a == 'next']
    back = [r for a, r in table(st.get('actions')) if a == 'back' or a == 'prev']
    if run.check(bool(nxt) and bool(back), 'Back and Next are there'):
        st = run.click(*middle(nxt[0]), settle=0.8)
        run.check(st.get('card') == 'Shapes', 'Next goes to the next lesson', st.get('card', ''))
        st = run.click(*middle(back[0]), settle=0.8)
        run.check(st.get('card') == 'Bodies', 'Back goes back', st.get('card', ''))


LESSONS = ['World', 'Bodies', 'Shapes', 'Materials', 'Forces', 'Hinges', 'Springs', 'Sliders',
           'Wheels', 'Dragging', 'Contacts', 'Rays', 'Terrain']


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--install', required=True)
    ap.add_argument('--stack', default=STACK)
    ap.add_argument('--shots')
    ap.add_argument('--log')
    ap.add_argument('--only', help='lessons to click, comma separated')
    args = ap.parse_args()
    args.install = os.path.abspath(args.install)
    args.stack = os.path.abspath(args.stack)
    engine = os.path.join(args.install, 'Runtime', 'Linux', 'x86-64', 'Standalone')
    for need, what in ((engine, 'the standalone engine'), (args.stack, 'the stack')):
        if not os.path.isfile(need):
            print('FAILED no %s at %s' % (what, need))
            return 1
    for tool in ('Xvfb', 'xdotool'):
        if not shutil.which(tool):
            print('FAILED %s is not installed' % tool)
            return 1
    run = Run(args)
    xvfb = subprocess.Popen(['Xvfb', run.display, '-screen', '0', '1280x800x24', '-nolisten', 'tcp'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    proc = None
    try:
        time.sleep(1.0)
        proc = subprocess.Popen([engine, PROBE], env=run.env, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL)
        st = run.wait_for(lambda s: s.get('card') == 'Start', 20)
        if st.get('card') != 'Start':
            print('FAILED the stack did not open: %s' % (run.errors() or st))
            return 1
        run.calibrate()
        only = set(args.only.split(',')) if args.only else None
        if not only:
            front(run)
        for index, name in enumerate(LESSONS, 1):
            if only is None or name in only:
                lesson(run, index, name)
        if not only:
            keys(run)
        errors = run.errors()
        run.check(not errors, 'no script errors', errors.replace('\n', ' | '))
    finally:
        if proc:
            proc.kill()
        xvfb.kill()
        shutil.rmtree(run.work, ignore_errors=True)
    if run.fails:
        run.say('FAILED %d' % run.fails)
        return 1
    run.say('DONE')
    return 0


if __name__ == '__main__':
    sys.exit(main())
