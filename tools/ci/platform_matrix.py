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

"""The platform matrix (tools/ci/platform-matrix.json): the oldest system
each part of a package must run on, read by the package checks so that
they and README.md say the same thing.

  load(path=None)              the matrix as a dict
  elf_limits(matrix, platform) ({name: version}, [(pattern, {name: version}, reason)])
                               the --max limits of a Linux package and the
                               files allowed a higher floor
  macos_limits(matrix, platform, part=None)
                               {arch: version} for a Mac package or a part
                               of it ('extensions')
  readme_phrases(matrix)       [(where, phrase)] every phrase README.md must
                               contain (tools/ci/tests/test_platform_matrix.py)

Only the Python 3 standard library is used.
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(HERE, 'platform-matrix.json')


class MatrixError(Exception):
    pass


def load(path=None):
    with open(path or DEFAULT, encoding='utf-8') as f:
        return json.load(f)


def _platform(matrix, platform):
    try:
        return matrix['platforms'][platform]
    except KeyError:
        raise MatrixError('the platform matrix has no platform %r (it has %s)'
                          % (platform, ', '.join(sorted(matrix.get('platforms', {})))))


def elf_limits(matrix, platform):
    p = _platform(matrix, platform)
    if 'elf' not in p:
        raise MatrixError('platform %r has no ELF limits' % platform)
    exceptions = []
    if platform.startswith('linux-'):
        for e in matrix.get('linux_exceptions', {}).get('exceptions', []):
            exceptions.append((e['files'], dict(e['elf']), e['reason']))
    return dict(p['elf']), exceptions


def macos_limits(matrix, platform, part=None):
    p = _platform(matrix, platform)
    if part:
        try:
            p = p['parts'][part]
        except KeyError:
            raise MatrixError('platform %r has no part %r' % (platform, part))
    if 'macos' not in p:
        raise MatrixError('%s has no macOS limits' % (platform + ('/' + part if part else '')))
    return dict(p['macos'])


def readme_phrases(matrix):
    found = []
    for name, p in sorted(matrix.get('platforms', {}).items()):
        for phrase in p.get('readme', []):
            found.append((name, phrase))
        for part, q in sorted(p.get('parts', {}).items()):
            for phrase in q.get('readme', []):
                found.append(('%s/%s' % (name, part), phrase))
    for e in matrix.get('linux_exceptions', {}).get('exceptions', []):
        if e.get('readme'):
            found.append((e['files'], e['readme']))
    return found
