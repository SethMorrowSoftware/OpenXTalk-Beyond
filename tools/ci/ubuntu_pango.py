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

"""Fetch Ubuntu 26.04's Pango and the libraries under it into a folder, for
a check to run an engine with them (LD_LIBRARY_PATH).

  python3 tools/ci/ubuntu_pango.py --out DIR

Issue #639: the IDE crashed on Ubuntu 26.04, in Pango 1.57, where the
Pango of the CI runners (1.52, Ubuntu 24.04) did not. The packages are
taken from snapshot.ubuntu.com at one moment, so they never change under
the check, and each is held to its SHA-256. Their libraries need glibc
2.38 or later (Ubuntu 24.04's runners have 2.39). The folder gets the
shared libraries of the packages, nothing else. Needs dpkg-deb.

Exit status 0 when every library is in the folder, 1 otherwise.
"""

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

SNAPSHOT = 'https://snapshot.ubuntu.com/ubuntu/20261125T000000Z/pool/main/'

# (path under SNAPSHOT, SHA-256): Ubuntu 26.04's ("resolute") on 2026-11-25
PACKAGES = (
    ('p/pango1.0/libpango-1.0-0_1.57.0-1_amd64.deb',
     '309f30a8ea77e0264a3c8b66811188f5b788fe87b33be3cafd97c8f221235591'),
    ('p/pango1.0/libpangoft2-1.0-0_1.57.0-1_amd64.deb',
     'c1e08ebf03feded26a42a0f07f94789e5995b402d704d2faafdc86fffda0b28b'),
    ('p/pango1.0/libpangocairo-1.0-0_1.57.0-1_amd64.deb',
     'a989e666bb0d64636a10a1253c949f92a282782d79d1725e0e1acc17282909a5'),
    ('f/fontconfig/libfontconfig1_2.17.1-3ubuntu1_amd64.deb',
     '72ba4fc43155566b46442b741a6892d5d1f1581ba58cdfd037aabf47ad9080f7'),
    ('h/harfbuzz/libharfbuzz0b_12.3.2-2_amd64.deb',
     'ec93ea39ddeb5a98179b60eab4af234b6c676f1958106645d1f4b19280d4cd09'),
    ('c/cairo/libcairo2_1.18.4-3_amd64.deb',
     '525ab7b5ad6529ea35aa09308ddd1fd2325c85ad70e7483ba66b526d8ee9f7a7'),
    ('f/freetype/libfreetype6_2.14.2+dfsg-1_amd64.deb',
     'a76ad9102039122ef72b01c9c364e7d8967331414cbe19151c01d1391ff9fe25'),
)

# The libraries the engine must find in the folder (their sonames)
SONAMES = ('libpango-1.0.so.0', 'libpangoft2-1.0.so.0', 'libpangocairo-1.0.so.0', 'libfontconfig.so.1',
           'libharfbuzz.so.0', 'libcairo.so.2', 'libfreetype.so.6')


def fetch(path, digest, work):
    url = SNAPSHOT + path
    with urllib.request.urlopen(url, timeout=120) as response:
        data = response.read()
    got = hashlib.sha256(data).hexdigest()
    if got != digest:
        raise RuntimeError('%s: SHA-256 %s, not %s' % (url, got, digest))
    deb = os.path.join(work, os.path.basename(path))
    with open(deb, 'wb') as f:
        f.write(data)
    return deb


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--out', required=True, help='the folder for the libraries')
    args = ap.parse_args(argv)

    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    work = tempfile.mkdtemp(prefix='oxt-ubuntu-pango-')
    try:
        for path, digest in PACKAGES:
            deb = fetch(path, digest, work)
            root = os.path.join(work, 'root')
            subprocess.run(['dpkg-deb', '-x', deb, root], check=True)
        libs = os.path.join(work, 'root', 'usr', 'lib', 'x86_64-linux-gnu')
        for name in sorted(os.listdir(libs)):
            if '.so' in name:
                src = os.path.join(libs, name)
                dst = os.path.join(out, name)
                if os.path.lexists(dst):
                    os.remove(dst)
                if os.path.islink(src):
                    os.symlink(os.readlink(src), dst)
                elif os.path.isfile(src):
                    shutil.copy2(src, dst)
        missing = [x for x in SONAMES if not os.path.exists(os.path.join(out, x))]
        if missing:
            raise RuntimeError('not in the packages: ' + ', '.join(missing))
    except (RuntimeError, OSError, subprocess.CalledProcessError) as e:
        print('::error title=Ubuntu 26.04 Pango::%s' % e if os.environ.get('GITHUB_ACTIONS') == 'true' else e)
        return 1
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print('Ubuntu 26.04 Pango and its libraries in %s' % out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
