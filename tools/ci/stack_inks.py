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

"""The words of the IDE's own windows can be read in the light and the dark
appearance: no button or field of a binary IDE stack is drawn in a text
colour that a stack file keeps, over a background that is the theme's.

A control with no colours of its own is drawn in the theme's: dark words on
a light window, light words on a dark one. One that was given a text colour
when the IDE had only a light look (black, a dark grey) and no background
keeps that colour on the dark window. Standalone Settings' "UAC Execution
Level" menu and the Object Library's library menu were black on Windows'
dark window, where nothing of their words was seen, and the "Required",
"Used" and "n/a" headers of the Android card a dark grey (the IDE
screenshots of 0.2.7, found in the review for 0.2.8-dp.1). A stack, card or
group that keeps a text colour gives it to every control under it that has
none of its own: Replicate (Edit > Replicate...) kept black on its stack,
so all of the dialog's words were black on the dark window (a picture of it
in the dark, 12 November 2026). The screenshots show only the cards the
tour opens, on the three platforms; this reads every card of every stack.

Under ide/Toolset and ide/Plugins,

  - a button or field fails when it has a text colour (foreColor) of its
    own, and
  - a stack, substack, card or group fails when it has one and a button or
    field under it takes it (it has none of its own, and this is the
    nearest owner with one; a substack's controls take the main stack's),

where neither the control nor an owner of it (group, card, stack) has a
backColor or a backPattern, so what is behind the words is the theme's, and
the colour does not stand out from the dark window or from the light one
(WCAG contrast below 2.5 to 1: a mid grey passes on both, black and white
on one only). An owner is reported once, with how many controls take its
colour.

EXCEPTIONS lists the controls and owners that are left as they are, each
with why. An entry that no longer matches a failing one is an error too, so
the list cannot outlive what it excuses.

What this does not read: a background that is set but not painted (on a
control or group that is not opaque), which it takes for a background; and
the other way round, a background of its own with the theme's text colour
(a white box whose words are white on a dark window, as the print dialog's
"Pages" field was). Colours a script sets as a window opens are not in the
stack file, and are the tour's to look at.

  python3 tools/ci/stack_inks.py --dumps DUMPDIR

DUMPDIR holds the dumps that tools/codebase-map/make_dumps.sh writes with
tools/oxt/ide-stack-dump.livecodescript (one per stack, named after the
stack's path); tools/oxt/stack-scripts.sh runs this with them, and the Linux
build runs that with the engine it built. Exit status 1 when a control or
an owner fails or an exception is stale, 2 when there is no dump to read.
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, os.pardir, os.pardir))

# The IDE's own windows; the examples, lessons and documentation stacks
# under ide/ have looks of their own
SCOPE = ('ide/Toolset/', 'ide/Plugins/')

# The window behind a control with no background of its own: Windows' dark
# window (32,32,32; the Mac's and GTK's dark windows are a little lighter)
# and the light one (240,240,240)
DARK_WINDOW = (32, 32, 32)
LIGHT_WINDOW = (240, 240, 240)
MIN_CONTRAST = 2.5

# How EXCEPTIONS and the report name a main stack whose own text colour its
# controls take (its other objects are named by their path below it)
THE_STACK = 'the stack itself'

_TIP = ('white on the notice\'s own graphic behind it, which this check does not see (a notice of '
        'LiveCode\'s commercial editions, in a group that is saved hidden)')
_TEMPLATE = ('the note on a data grid\'s row template card, read only by someone who edits that template; '
             'the Data Grid library\'s is copied into the user\'s stack with every new data grid, so its '
             'colour is part of what users\' stacks hold')
_MARKS = 'no script opens this substack (a chooser of menu marks that the Menu Builder does not use)'
_STANDALONE = 'ide/Toolset/palettes/standalone settings/revstandalonesettings.8.rev'
_MENUS = 'ide/Toolset/palettes/revmenumanager.rev'

# (stack file, object as the dump names it, without the main stack, or
# THE_STACK for the main stack itself): why
EXCEPTIONS = {
    ('ide/Toolset/palettes/revpagesetup.rev', THE_STACK):
        'a MetaCard 2.4 stack file, which the patch tool does not save (the engine would write it in another '
        'format), so it keeps its black; no script of the engine or the IDE opens it (Standalone Settings can '
        'copy it into a Linux standalone, its "UNIX,pageSetup" setting)',
    ('ide/Toolset/palettes/revrulersh.rev', THE_STACK):
        'the ruler\'s one button shows a picture and no words; the stack\'s black is what the ruler\'s marks '
        'are drawn in, on its own white strip',
    ('ide/Toolset/palettes/splash/revSplash.livecode', 'card "Main" (id 1008)'):
        'the splash\'s script sets the card\'s colour as it opens (white in the dark appearance, black in the '
        'light one) and each shown field\'s own, over the splash picture (revsplashstackbehavior.livecodescript)',
    (_STANDALONE, 'card "General" (id 1002) > group "generalCommercialTip" (id 3125) > field "tip_close" (id 3127)'): _TIP,
    (_STANDALONE, 'card "General" (id 1002) > group "generalCommercialTip" (id 3125) > field "tip_message" (id 3128)'): _TIP,
    (_STANDALONE, 'card "iOS" (id 1641) > group "iOSCommercialTip" (id 3135) > field "tip_close" (id 3137)'): _TIP,
    (_STANDALONE, 'card "iOS" (id 1641) > group "iOSCommercialTip" (id 3135) > field "tip_message" (id 3138)'): _TIP,
    (_STANDALONE, 'card "Emscripten" (id 3757) > group "emscriptenLicenseTip" (id 3821) > '
                  'field "emscriptenNoLicenseLabel" (id 3819)'): _TIP,
    (_STANDALONE, 'substack "Data Grid Templates 1496227828115" > card (id 1002) > '
                  'group "_DataGridTemplateInstructions_" (id 1003) > '
                  'field "_DataGridTemplateInstructions_" (id 1004)'): _TEMPLATE,
    ('ide/Plugins/Quick Dictionary.livecode',
     'substack "Data Grid Templates 1713287896563" > card (id 1002) > '
     'group "_DataGridTemplateInstructions_" (id 1003) > field "_DataGridTemplateInstructions_" (id 1004)'): _TEMPLATE,
    ('ide/Toolset/palettes/revdatagridlibrary.rev',
     'card (id 1002) > group "Templates" (id 1061) > group "_DataGridTemplateInstructions_" (id 1143) > '
     'field "_DataGridTemplateInstructions_" (id 1144)'): _TEMPLATE,
    (_MENUS, 'substack "revMenuItemStylePopup" > card (id 1002) > button "Checked" (id 1050)'): _MARKS,
    (_MENUS, 'substack "revMenuItemStylePopup" > card (id 1002) > button "Diamond" (id 1011)'): _MARKS,
    (_MENUS, 'substack "revMenuItemStylePopup" > card (id 1002) > button "None" (id 1054)'): _MARKS,
    ('ide/Toolset/palettes/message box/revmessagebox.8.rev',
     'card "Stacks in Use" (id 9525) > group "objectList" (id 10669) > group "dvListMask" (id 10673) > '
     'group "dvList" (id 10674) > group "stacksRow" (id 221617) > field "stack name" (id 221620)'):
        'its row\'s script sets the colour each time it fills the row (revIDEColor text_1 or text_3)',
}

OBJ_RE = re.compile(r'^== (.*)$')
GREY_RE = re.compile(r'^gr[ae]y(\d{1,3})$')
# The colour names the stacks use (the engine knows the X11 names; one not
# here is reported, to be added)
NAMES = {
    'black': (0, 0, 0), 'white': (255, 255, 255), 'red': (255, 0, 0),
    'green': (0, 255, 0), 'blue': (0, 0, 255), 'yellow': (255, 255, 0),
    'gray': (190, 190, 190), 'grey': (190, 190, 190),
    'darkgray': (169, 169, 169), 'darkgrey': (169, 169, 169),
    'lightgray': (211, 211, 211), 'lightgrey': (211, 211, 211),
    'dimgray': (105, 105, 105), 'dimgrey': (105, 105, 105),
}


def dump_name(rel):
    """As tools/oxt/stack_scripts.py names a stack's dump."""
    return rel.replace('/', '_').replace(' ', '_') + '.txt'


def colour(value):
    """(r, g, b) of a colour property's value, or None for one not known."""
    value = value.strip()
    low = value.lower().replace(' ', '')
    if low in NAMES:
        return NAMES[low]
    m = GREY_RE.match(low)
    if m and int(m.group(1)) <= 100:
        v = int(int(m.group(1)) * 255 / 100.0 + 0.5)
        return (v, v, v)
    if re.match(r'^#[0-9a-f]{6}$', low):
        return tuple(int(low[i:i + 2], 16) for i in (1, 3, 5))
    parts = value.split(',')
    if len(parts) in (3, 4) and all(p.strip().isdigit() for p in parts[:3]):
        rgb = tuple(int(p) for p in parts[:3])
        if max(rgb) <= 255:
            return rgb
    return None


def luminance(rgb):
    total = 0.0
    for v, w in zip(rgb, (0.2126, 0.7152, 0.0722)):
        v = v / 255.0
        v = v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
        total += v * w
    return total


def contrast(one, two):
    """The WCAG contrast ratio of two colours."""
    a, b = luminance(one), luminance(two)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def objects(dump_path):
    """The objects of a stack dump, in its order: (label, {property: value}).
    The label is the object's path, as the dump writes it."""
    out, props = [], None
    with open(dump_path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            m = OBJ_RE.match(line)
            if m:
                props = {}
                out.append((m.group(1), props))
            elif props is not None and line.startswith('prop '):
                key, sep, value = line[5:].partition(':')
                if sep:
                    props[key] = value[1:] if value.startswith(' ') else value
    return out


def _windows(rgb):
    """The windows a colour does not stand out from: (ratio, name) each."""
    return [(contrast(rgb, window), name)
            for window, name in ((DARK_WINDOW, 'dark'), (LIGHT_WINDOW, 'light'))
            if contrast(rgb, window) < MIN_CONTRAST]


def findings(rel, dump_path):
    """What fails in one stack: (object, colour, what). A button or field
    with a text colour of its own, or an owner (group, card, stack) whose
    text colour buttons and fields under it take, where nothing from the
    control up has a background and the colour does not stand out from the
    dark or the light window. An owner is named once, with how many
    controls take its colour; the main stack is THE_STACK."""
    objs = objects(dump_path)
    by_label = dict(objs)
    out = []
    taken = {}
    order = []
    for label, props in objs:
        segments = label.split(' > ')
        if segments[-1].split(' ', 1)[0] not in ('button', 'field'):
            continue
        if any(by_label.get(' > '.join(segments[:depth]), {}).get(key)
               for depth in range(1, len(segments) + 1) for key in ('backColor', 'backPattern')):
            continue
        short = ' > '.join(segments[1:])
        ink = props.get('foreColor')
        if not ink:
            # the nearest owner with a text colour gives this control its words' colour
            for depth in range(len(segments) - 1, 0, -1):
                owner = ' > '.join(segments[:depth])
                if by_label.get(owner, {}).get('foreColor'):
                    if owner not in taken:
                        taken[owner] = []
                        order.append(owner)
                    taken[owner].append(segments[-1])
                    break
            continue
        rgb = colour(ink)
        if rgb is None:
            out.append((short, ink, 'is a colour this check does not know (add it to NAMES)'))
            continue
        for ratio, name in _windows(rgb):
            out.append((short, ink, 'is %.1f to 1 on the %s window' % (ratio, name)))
    for owner in order:
        ink = by_label[owner]['foreColor']
        short = ' > '.join(owner.split(' > ')[1:]) or THE_STACK
        who = '(taken by %d button(s) and field(s) under it, the first %s)' % (len(taken[owner]), taken[owner][0])
        rgb = colour(ink)
        if rgb is None:
            out.append((short, ink, who + ' is a colour this check does not know (add it to NAMES)'))
            continue
        for ratio, name in _windows(rgb):
            out.append((short, ink, '%s is %.1f to 1 on the %s window' % (who, ratio, name)))
    return out


def stacks(dumps):
    """The stacks in SCOPE that have a dump (a stack the engine does not load
    has none), as paths from the repository's root."""
    found = []
    for scope in SCOPE:
        for root, dirs, names in os.walk(os.path.join(REPO, scope)):
            dirs.sort()
            for n in sorted(names):
                if n.endswith(('.livecode', '.rev', '.oxtstack')):
                    rel = os.path.relpath(os.path.join(root, n), REPO).replace(os.sep, '/')
                    if os.path.exists(os.path.join(dumps, dump_name(rel))):
                        found.append(rel)
    return found


def check(dumps, rels, exceptions):
    """(failures, stale, excused): the lines to report for controls that
    fail and for exceptions that match no failing control, and the number of
    findings the exceptions excused."""
    failures, used = [], set()
    excused = 0
    for rel in rels:
        for obj, ink, what in findings(rel, os.path.join(dumps, dump_name(rel))):
            if (rel, obj) in exceptions:
                used.add((rel, obj))
                excused += 1
                continue
            failures.append('%s: %s: its text colour %s %s, over a background that is the theme\'s'
                            % (rel, obj, ink, what))
    stale = ['%s: %s: listed in EXCEPTIONS, but it passes or is gone' % key
             for key in sorted(exceptions) if key not in used]
    return failures, stale, excused


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--dumps', required=True, help='the folder of stack dumps')
    args = parser.parse_args()
    rels = stacks(args.dumps)
    if not rels:
        print('no dump of a stack under %s in %s' % (' or '.join(SCOPE), args.dumps), file=sys.stderr)
        return 2
    failures, stale, excused = check(args.dumps, rels, EXCEPTIONS)
    for line in failures + stale:
        print('FAIL ' + line)
    if failures or stale:
        print('%d control(s) or owner(s) with words that cannot be read in one appearance, %d stale exception(s). '
              'Clear the text colour with a patch in tools/oxt/ide-stack-patches (so the theme\'s is used), '
              'or give the control a background of its own.' % (len(failures), len(stale)))
        return 1
    print('The buttons and fields of %d IDE stacks have no text colour, of their own or from an owner, '
          'over the theme\'s background that the dark or the light window hides (%d excused in EXCEPTIONS).'
          % (len(rels), excused))
    return 0


if __name__ == '__main__':
    sys.exit(main())
