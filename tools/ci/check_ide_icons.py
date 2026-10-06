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

"""Check the IDE's icons for the dark appearance.

  python tools/ci/check_ide_icons.py [--repo DIR]

Runs tools/oxt/dark_disabled_icons.py --check: every
ide/Toolset/palettes/menubar/images/*-disabled*.png has its
*-disabled-dark*.png twin, each twin is exactly what that script makes
from the enabled icon, and the mean luminance of each twin's ink has at
least 3:1 contrast with each dark toolbar (32,32,32 on Windows, 61,61,61 on
macOS). Then tools/oxt/dark_tool_icons.py --check: every Tools palette icon
of a theme is in its dark folder, and the outline icons there (the shapes,
the arrow, the label field, the line and select tools and some tool
options) have at least 3:1 contrast with the platform's dark palette. Both
run; exit status 1 when either fails. Needs Python 3.8 or later, standard
library only.
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'oxt'))

import dark_disabled_icons  # noqa: E402  (found through the path above)
import dark_tool_icons  # noqa: E402


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(HERE, '..', '..')),
                        help='repository root (default: two levels up from this script)')
    args = parser.parse_args(argv)
    toolbar = dark_disabled_icons.main(['--check', '--repo', args.repo])
    tools = dark_tool_icons.main(['--check', '--repo', args.repo])
    return 1 if toolbar or tools else 0


if __name__ == '__main__':
    sys.exit(main())
