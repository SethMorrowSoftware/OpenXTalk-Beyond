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

"""Watch the windows that come and go on an X screen while the IDE starts,
and name every window that showed and was taken away again: the "ghost
windows" of a start (LittleNemo, openxtalk.org p=25967: "a succession of
fleeting windows" before the IDE settles).

  python3 tools/ci/startup_windows.py --display :91 --seconds 60
      --log FILE [--ready FILE]

It follows the window manager's list of the windows it manages
(_NET_CLIENT_LIST on the root window, which openbox, xfwm4 and mutter
keep), so it sees what a user sees: a window that is mapped, framed and
given a place in the taskbar, however briefly. A window that leaves the
list is a ghost, unless it is the splash, which is meant to go.

Each change is a line of the log: the time in seconds since the watch
began, "+" for a window that came or "-" for one that went, its id and
its title. Then a summary, and one "GHOST" line for each window that
went; the exit status is 1 when there was any, 0 otherwise. --ready
names a file written once the watch has begun, so the IDE starts only
after that. Needs python3-xlib.

The start check (tools/ci/linux_ide_start.sh) runs it beside the IDE.
"""

import argparse
import os
import sys
import time

# The windows that are meant to go while the IDE starts: the splash
SPLASH_TITLES = ('revSplash',)


def ghosts(events, allowed=SPLASH_TITLES):
    """The windows that came and went, from (time, sign, id, title)
    events in order, sign "+" or "-": a list of (id, title, came, went),
    one for each time a window went that is not among the allowed titles.
    A window that came back after it went is a ghost all the same."""
    found = []
    came = {}
    titles = {}
    for when, sign, wid, title in events:
        if sign == '+':
            came[wid] = when
            if title:
                titles[wid] = title
        elif sign == '-':
            title = titles.get(wid, title)
            if title in allowed:
                continue
            found.append((wid, title, came.get(wid), when))
    return found


def report(events, found):
    lines = ['%8.3f %s %#x %s' % (when, sign, wid, title or '(no title)')
             for when, sign, wid, title in events]
    if found:
        for wid, title, came, went in found:
            shown = '' if came is None else ' after %.3f s' % (went - came)
            lines.append('GHOST %#x "%s" went at %.3f s%s'
                         % (wid, title or '(no title)', went, shown))
    else:
        lines.append('No window came and went (the splash aside)')
    return lines


def watch(display_name, seconds, ready=None):
    from Xlib import X, display
    d = display.Display(display_name)
    root = d.screen().root
    root.change_attributes(event_mask=X.PropertyChangeMask)
    client_list = d.intern_atom('_NET_CLIENT_LIST')
    net_name = d.intern_atom('_NET_WM_NAME')
    utf8 = d.intern_atom('UTF8_STRING')

    def title(wid):
        try:
            w = d.create_resource_object('window', wid)
            p = w.get_full_property(net_name, utf8)
            if p is not None and p.value:
                v = p.value
                return v.decode('utf-8', 'replace') if isinstance(v, bytes) else str(v)
            n = w.get_wm_name()
            return n.decode('latin-1') if isinstance(n, bytes) else (n or '')
        except Exception:
            return ''

    def clients():
        p = root.get_full_property(client_list, X.AnyPropertyType)
        return list(p.value) if p is not None else []

    start = time.time()
    events = []
    now = clients()
    for wid in now:
        events.append((0.0, '+', wid, title(wid)))
    if ready:
        with open(ready, 'w') as f:
            f.write('ready\n')
    end = start + seconds
    while time.time() < end:
        while d.pending_events():
            e = d.next_event()
            if e.type == X.PropertyNotify and e.atom == client_list:
                after = clients()
                when = time.time() - start
                for wid in after:
                    if wid not in now:
                        events.append((when, '+', wid, title(wid)))
                for wid in now:
                    if wid not in after:
                        events.append((when, '-', wid, ''))
                now = after
        time.sleep(0.002)
    return events


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--display', default=os.environ.get('DISPLAY', ':0'))
    ap.add_argument('--seconds', type=float, default=60.0)
    ap.add_argument('--log', help='where the lines go too')
    ap.add_argument('--ready', help='a file written once the watch has begun')
    args = ap.parse_args(argv)
    events = watch(args.display, args.seconds, args.ready)
    found = ghosts(events)
    lines = report(events, found)
    text = '\n'.join(lines) + '\n'
    sys.stdout.write(text)
    if args.log:
        with open(args.log, 'w') as f:
            f.write(text)
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
