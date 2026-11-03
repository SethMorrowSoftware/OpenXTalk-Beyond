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

"""Clicks every part of the "Learn" stacks of the xTalk Suite's extensions
with a real mouse, and checks what each click did.

  python3 tools/examples/learn-clicks.py --install DIR
      [--stack FILE ...] [--shots DIR] [--log FILE]

Each stack runs in the install's standalone engine
(Runtime/Linux/x86-64/Standalone), in a real window on a screen of its
own (an Xvfb server this starts), with its extensions loaded from the
install as its cLoad says; learn-clicks.livecodescript, beside this,
writes what the window shows to a file ten times a second. xdotool moves
the mouse, presses its button and the keys, as a person does, so each
click goes the whole way the engine sends a click (the field, the group
"Learn", the card, the window), which a script calling a handler skips.
tools/examples/test-learn-stacks.livecodescript checks the same stacks'
behaviour in depth; this checks that a person's clicks reach it.

What it clicks, and what must follow:

  the front page   it says the extension is loaded; a tile goes to its
                   lesson
  every lesson     reached by its line in the sidebar; Run gives the
                   lesson's result; each call in its list opens the
                   call's page over the script, and Back to the script
                   shuts it; on the first lesson, Copy puts the script on
                   the clipboard, a word typed into the script makes it
                   the reader's own, and Reset puts the lesson's back
  the Reference    a line of the list shows its page; the wheel scrolls
                   the list; a name typed in the search box keeps the
                   names that match, and the box emptied lists them all
  Back and Next    between lessons

With no --stack, it clicks every ide/Resources/Examples/Remastered/Learn
*.oxtstack but Learn Box2D (which has learn-box2d-clicks.py). It writes a
line for each check, PASS or FAIL, and ends with "DONE" (exit status 0)
or "FAILED <how many>" (exit status 1). With --shots, a picture of each
card after its clicks.
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
PROBE = os.path.join(HERE, 'learn-clicks.livecodescript')
REMASTERED = os.path.join(REPO, 'ide', 'Resources', 'Examples', 'Remastered')
# The sidebar's first line (the front page), and the room each line has
SIDEBAR_X, SIDEBAR_Y, SIDEBAR_STEP = 100, 99, 30


class Run:
    def __init__(self, args, stack):
        self.args = args
        self.stack = stack
        self.name = os.path.splitext(os.path.basename(stack))[0]
        self.fails = 0
        self.work = tempfile.mkdtemp(prefix='learn-clicks-')
        self.state_file = os.path.join(self.work, 'state')
        self.display = ':%d' % (90 + os.getpid() % 100)
        self.env = dict(os.environ, DISPLAY=self.display, OXT_INSTALL=args.install,
                        OXT_LEARN_STACK=stack, OXT_CLICKS_STATE=self.state_file)
        self.dx = self.dy = 0

    def calibrate(self):
        """Where the card's 0,0 is on the screen (the window is put at the
        top left, but where its content lands is the X server's say)"""
        self.xdo('mousemove', 500, 300)
        self.wait_for(lambda s: s.get('mouse', '').count(',') == 1, 3)
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

    def click(self, x, y, settle=0.5, button=1):
        self.move(x, y)
        time.sleep(0.08)
        self.xdo('click', button)
        time.sleep(settle)
        return self.state()

    def type(self, text, settle=0.5):
        self.xdo('type', '--delay', 40, text)
        time.sleep(settle)
        return self.state()

    def key(self, name, settle=0.3):
        self.xdo('key', name)
        time.sleep(settle)
        return self.state()

    def shot(self, name):
        if self.args.shots:
            folder = os.path.join(self.args.shots, self.name)
            os.makedirs(folder, exist_ok=True)
            subprocess.run(['import', '-window', 'root', '-crop',
                            '1024x640+%d+%d' % (max(0, self.dx), max(0, self.dy)),
                            os.path.join(folder, name + '.png')], env=self.env)

    # -- reporting

    def say(self, line):
        print(line, flush=True)
        if self.args.log_file:
            self.args.log_file.write(line + '\n')

    def check(self, ok, what, detail=''):
        if ok:
            self.say('PASS %s: %s' % (self.name, what))
        else:
            self.fails += 1
            self.say('FAIL %s: %s%s' % (self.name, what, (' (' + detail + ')') if detail else ''))
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


def lines(text):
    """A field's text, as the state file joins its lines"""
    return (text or '').split(' | ') if text else []


def matches(st):
    """Does the result match the lesson's cExpect (a PCRE, as matchText
    takes it; these use only what Python's re reads the same way)"""
    expect = st.get('expect', '').replace(' | ', '\n')
    result = st.get('result', '').replace(' | ', '\n')
    try:
        return bool(expect) and re.search(expect, result) is not None
    except re.error:
        return False


def go_card(run, index):
    """Its line in the sidebar (index 0 is the front page)"""
    return run.click(SIDEBAR_X, SIDEBAR_Y + SIDEBAR_STEP * index, 0.4)


def front(run, cards):
    st = go_card(run, 0)
    st = run.wait_for(lambda s: s.get('card') == cards[0], 3)
    run.check(st.get('learn') == 'front', 'the sidebar\'s first line is the front page', st.get('card', ''))
    run.check('is loaded' in st.get('status', ''), 'the front page says the extension is loaded',
              st.get('status', ''))
    tiles = [(a, r) for a, r in table(st.get('actions')) if a.startswith('go ')]
    run.check(len(tiles) >= len(cards) - 2, 'a tile for every lesson', '%d tiles' % len(tiles))
    run.shot('00-front')
    if len(tiles) > 1:
        action, where = tiles[1]
        st = run.click(*middle(where), settle=0.6)
        run.check(st.get('card') != cards[0] and st.get('learn') == 'lesson',
                  'the second tile (%s) goes to a lesson' % action, st.get('card', ''))


def lesson(run, index, name, first):
    st = go_card(run, index)
    st = run.wait_for(lambda s: s.get('card') == name, 3)
    if not run.check(st.get('card') == name and st.get('learn') == 'lesson',
                     '%s: the sidebar opens it' % name, st.get('card', '')):
        return
    run.check(st.get('own') == 'true' and st.get('sheet') == 'false',
              '%s: the lesson\'s own script shows' % name)
    buttons = dict(table(st.get('buttons')))
    if not run.check('lessonRun' in buttons, '%s: Run is there' % name, st.get('buttons', '')):
        return
    st = run.click(*middle(buttons['lessonRun']), settle=0.5)
    st = run.wait_for(matches, 12)
    run.check(matches(st), '%s: Run gives the lesson\'s result' % name,
              'got "%s" for /%s/' % (st.get('result'), st.get('expect')))
    run.shot('%02d-%s' % (index, name))
    # each call opens its page, and Back to the script shuts it
    calls = table(st.get('calls'))
    run.check(len(calls) > 0, '%s: its list of calls has links' % name)
    for call, where in calls:
        st = run.click(*middle(where), settle=0.3)
        st = run.wait_for(lambda s: s.get('sheet') == 'true', 2)
        run.check(st.get('sheet') == 'true' and st.get('sheettext', '').startswith(call),
                  '%s: a click on %s opens its page' % (name, call), st.get('sheettext', ''))
        back = dict(table(st.get('buttons'))).get('lessonBack')
        if back:
            st = run.click(*middle(back), settle=0.3)
        st = run.wait_for(lambda s: s.get('sheet') == 'false', 2)
        run.check(st.get('sheet') == 'false', '%s: Back to the script shuts the page of %s' % (name, call))
    if first:
        copy(run, name, buttons)


def copy(run, name, buttons):
    st = run.state()
    script = st.get('script', '')
    st = run.click(*middle(buttons['lessonCopy']), settle=0.4)
    st = run.wait_for(lambda s: s.get('clipboard') == script, 2)
    run.check(st.get('clipboard') == script, '%s: Copy puts the script on the clipboard' % name,
              st.get('clipboard', '')[:60])
    # a word typed at the end of the script, then Reset
    where = rect(st['scriptrect'])
    st = run.click(where[0] + 40, where[1] + 30, settle=0.3)
    run.check(st.get('focus') == 'lessonScript', '%s: a click in the script opens it for typing' % name,
              'the focus is in %s' % st.get('focus'))
    run.key('ctrl+End')
    st = run.type(' -- mine')
    st = run.wait_for(lambda s: s.get('own') == 'false', 2)
    run.check(st.get('own') == 'false' and st.get('script', '').endswith('-- mine'),
              '%s: a word typed into the script goes into it' % name, st.get('script', '')[-40:])
    st = run.click(*middle(buttons['lessonReset']), settle=0.4)
    st = run.wait_for(lambda s: s.get('own') == 'true', 2)
    run.check(st.get('own') == 'true', '%s: Reset puts the lesson\'s script back' % name)


def reference(run, index, name):
    st = go_card(run, index)
    st = run.wait_for(lambda s: s.get('card') == name, 3)
    if not run.check(st.get('learn') == 'reference', 'the last line of the sidebar is the Reference',
                     st.get('card', '')):
        return
    names = lines(st.get('reflist'))
    run.check(len(names) > 3 and st.get('reftext', '').startswith(names[0]),
              'the Reference lists the handlers and shows the first', st.get('reftext', ''))
    # a click on the third line shows its page
    st = run.click(*middle(rect(st['refline3'])), settle=0.4)
    st = run.wait_for(lambda s: s.get('reftext', '').startswith(names[2]), 2)
    run.check(st.get('reftext', '').startswith(names[2]) and st.get('refhilite') == '3',
              'a click on the third line shows the page of %s' % names[2], st.get('reftext', ''))
    # the wheel scrolls the list
    where = rect(st['refrect'])
    for _ in range(3):
        run.click(where[0] + 60, where[1] + 120, settle=0.15, button=5)
    st = run.wait_for(lambda s: int(s.get('refscroll', 0)) > 0, 2)
    run.check(int(st.get('refscroll', 0)) > 0, 'the wheel scrolls the list', st.get('refscroll', ''))
    run.shot('%02d-%s' % (index, name))
    # a search keeps the names that match, and an empty box lists them all
    target = names[len(names) // 2]
    st = run.click(*middle(rect(st['refsearchrect'])), settle=0.3)
    st = run.type(target, settle=0.6)
    st = run.wait_for(lambda s: s.get('refsearch') == target, 3)
    found = lines(st.get('reflist'))
    run.check(target in found and len(found) < len(names),
              'a search for %s keeps the names that match' % target, ', '.join(found[:4]))
    run.check(any(st.get('reftext', '').startswith(f) for f in found),
              'the page shown is one the search found', st.get('reftext', ''))
    run.shot('%02d-%s-search' % (index, name))
    for _ in target:
        run.xdo('key', 'BackSpace')
    st = run.wait_for(lambda s: s.get('refsearch') == '', 3)
    run.check(lines(st.get('reflist')) == names, 'an empty search box lists every handler again',
              '%d lines' % len(lines(st.get('reflist'))))


def next_back(run, cards):
    go_card(run, 1)
    st = run.wait_for(lambda s: s.get('card') == cards[1], 3)
    actions = dict(table(st.get('actions')))
    if not run.check('next' in actions and 'back' in actions, 'Back and Next are there',
                     st.get('actions', '')):
        return
    st = run.click(*middle(actions['next']), settle=0.4)
    st = run.wait_for(lambda s: s.get('card') == cards[2], 2)
    run.check(st.get('card') == cards[2], 'Next goes to the next lesson', st.get('card', ''))
    actions = dict(table(st.get('actions')))
    st = run.click(*middle(actions['back']), settle=0.4)
    st = run.wait_for(lambda s: s.get('card') == cards[1], 2)
    run.check(st.get('card') == cards[1], 'Back goes to the lesson before', st.get('card', ''))


def click_stack(args, stack, engine):
    run = Run(args, stack)
    xvfb = subprocess.Popen(['Xvfb', run.display, '-screen', '0', '1280x800x24', '-nolisten', 'tcp'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    proc = None
    try:
        time.sleep(1.0)
        proc = subprocess.Popen([engine, PROBE], env=run.env, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL)
        st = run.wait_for(lambda s: s.get('learn') == 'front', 45)
        if st.get('learn') != 'front':
            run.check(False, 'the stack opens', run.errors() or str(st)[:200])
            return run.fails
        run.calibrate()
        cards = st['cards'].split(',')
        front(run, cards)
        for index, name in enumerate(cards[1:-1], 1):
            lesson(run, index, name, index == 1)
        reference(run, len(cards) - 1, cards[-1])
        next_back(run, cards)
        errors = run.errors()
        run.check(not errors, 'no script errors', errors.replace('\n', ' | '))
    finally:
        if proc:
            proc.kill()
        xvfb.kill()
        shutil.rmtree(run.work, ignore_errors=True)
    return run.fails


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--install', required=True)
    ap.add_argument('--stack', action='append')
    ap.add_argument('--shots')
    ap.add_argument('--log')
    args = ap.parse_args()
    args.install = os.path.abspath(args.install)
    args.log_file = open(args.log, 'w', encoding='utf-8') if args.log else None
    stacks = [os.path.abspath(s) for s in (args.stack or [])]
    if not stacks:
        stacks = sorted(s for s in glob.glob(os.path.join(REMASTERED, 'Learn *.oxtstack'))
                        if os.path.basename(s) != 'Learn Box2D.oxtstack')
    engine = os.path.join(args.install, 'Runtime', 'Linux', 'x86-64', 'Standalone')
    if not os.path.isfile(engine):
        print('FAILED no standalone engine at %s' % engine)
        return 1
    if not stacks:
        print('FAILED no Learn stacks to click')
        return 1
    for tool in ('Xvfb', 'xdotool'):
        if not shutil.which(tool):
            print('FAILED %s is not installed' % tool)
            return 1
    fails = 0
    for stack in stacks:
        if not os.path.isfile(stack):
            print('FAIL no stack at %s' % stack)
            fails += 1
            continue
        fails += click_stack(args, stack, engine)
    if fails:
        print('FAILED %d' % fails)
        return 1
    print('DONE')
    return 0


if __name__ == '__main__':
    sys.exit(main())
