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

"""Writes the images a test printed into its log back to PNG files.

  python3 tools/ci/print_images.py <log> <folder>

tools/ci/mac_appearance_test.py prints images as lines
"IMAGE <run>/<file> <part>/<parts> <base64>" (a log line of the Actions
runner may have a time stamp before it). Each complete image is written to
<folder>/<run>-<file>, and its name printed.
"""

import base64
import os
import re
import sys

LINE = re.compile(r'IMAGE (\S+) (\d+)/(\d+) (\S*)\s*$')


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 2:
        print(__doc__.strip())
        return 2
    log, folder = argv
    parts = {}
    with open(log, 'r', errors='replace') as f:
        for line in f:
            m = LINE.search(line)
            if m:
                name, i, n, data = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
                parts.setdefault(name, [None] * n)[i - 1] = data
    if not os.path.isdir(folder):
        os.makedirs(folder)
    for name, pieces in sorted(parts.items()):
        if any(p is None for p in pieces):
            print('incomplete: %s' % name)
            continue
        path = os.path.join(folder, name.replace('/', '-'))
        with open(path, 'wb') as out:
            out.write(base64.b64decode(''.join(pieces)))
        print(path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
