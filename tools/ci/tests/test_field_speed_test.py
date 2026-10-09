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

"""tools/ci/field_speed_test.py with a made-up engine, a shell script that
writes the markers and speed.txt as field-speed-test.livecodescript does:
which profiles it takes (as if on macOS, with `sample` replaced), and how it
checks the limits.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import shutil
import stat
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import field_speed_test  # noqa: E402

# %s: the seconds the fill takes
ENGINE = '''#!/bin/sh
out="$OXT_SPEED_OUT"
: > "$out/filling"
sleep %s
printf 'RESULT\\tfill-and-prune\\t107\\t1\\t107\\n' > "$out/speed.txt"
printf 'RESULT\\ttry-digit-unlocked\\t90\\t30\\t3\\n' >> "$out/speed.txt"
: > "$out/solving"
sleep 3
printf 'INFO\\tdone\\ttrue\\n' >> "$out/speed.txt"
'''


class FieldSpeedTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_engine(self, fill_seconds, *limits):
        engine = os.path.join(self.tmp, 'engine.sh')
        with open(engine, 'w') as f:
            f.write(ENGINE % fill_seconds)
        os.chmod(engine, os.stat(engine).st_mode | stat.S_IXUSR)
        samples = []

        def sample(pid, seconds, path):
            samples.append(os.path.basename(path))
            return True
        argv = ['--engine', engine, '--out', os.path.join(self.tmp, 'out'), '--timeout', '30']
        for limit in limits:
            argv += ['--limit', limit]
        with mock.patch.object(field_speed_test.sys, 'platform', 'darwin'), \
                mock.patch.object(field_speed_test, 'defaults', return_value=(1, '')), \
                mock.patch.object(field_speed_test, 'screenshot', return_value=False), \
                mock.patch.object(field_speed_test, 'sample', side_effect=sample), \
                contextlib.redirect_stdout(io.StringIO()) as log:
            code = field_speed_test.main(argv)
        return code, samples, log.getvalue()

    def test_fast_fill_is_not_sampled(self):
        # the steps timed after it run without the profiler
        code, samples, log = self.run_engine('0.1')
        self.assertEqual(code, 0, log)
        self.assertEqual(samples, ['sample-solving.txt'])
        self.assertIn('(fill-and-prune took less than 1 s: not sampled)', log)

    def test_slow_fill_is_sampled(self):
        code, samples, log = self.run_engine('2')
        self.assertEqual(code, 0, log)
        self.assertEqual(samples, ['sample-filling.txt', 'sample-solving.txt'])

    def test_limits(self):
        code, _, log = self.run_engine('0.1', 'try-digit-unlocked=25', 'fill-and-prune=100')
        self.assertEqual(code, 1, log)
        self.assertIn('try-digit-unlocked: 3.000 ms per count (at most 25)', log)
        self.assertIn('::error::fill-and-prune took 107.000 ms per count, more than 100', log)

    def test_line_cut_short(self):
        # read while the script rewrites the file
        text = 'RESULT\tfill-and-prune\t107\t1\t107\nRESULT\twrite-unlocked\t10\t60\t'
        self.assertEqual(field_speed_test.per_count(text), {'fill-and-prune': 107.0})


if __name__ == '__main__':
    unittest.main()
