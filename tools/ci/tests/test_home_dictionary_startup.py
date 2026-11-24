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

"""The IDE's start-up (ide/Toolset/home.livecodescript) goes on to its
final steps when the dictionary build of a development build throws
(HyperXTalk's fix, by Stam Kapetanakis). Before, the throw jumped past the
final steps, which install the front script and shortcuts libraries, and
the IDE came up without them.

The block is read from the source and RUN on a server engine with the
dictionary build stubbed (it throws, it returns false, it returns true)
when OXT_SERVER_ENGINE names one; the order of the start-up is checked in
the source either way.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import subprocess
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
HOME = os.path.join(REPO, 'ide', 'Toolset', 'home.livecodescript')


def startup_handler():
    with open(HOME, encoding='latin-1') as f:
        text = f.read()
    m = re.search(r'^on revInternal__openStack\b.*?^end revInternal__openStack\b', text, re.S | re.M)
    assert m, 'revInternal__openStack not found'
    return m.group(0)


def dictionary_block(handler):
    m = re.search(r'^( *)if tSuccess and not revEnvironmentIsInstalled\(\) then\n.*?^\1end if\n',
                  handler, re.S | re.M)
    assert m, 'the dictionary step not found'
    return m.group(0)


class HomeDictionaryStartupTest(unittest.TestCase):
    def test_the_build_is_inside_a_try_of_its_own(self):
        block = dictionary_block(startup_handler())
        lines = [l.strip() for l in block.splitlines()]
        code = [l for l in lines if l and not l.startswith('--')]
        start = code.index('try')
        self.assertEqual(code[start:start + 8], [
            'try',
            'revInternal__BuildDictionary',
            'put the result into tSuccess',
            'catch tDictionaryError',
            'revInternal__Log "Error", "Building Dictionary failed:" && tDictionaryError',
            'put true into tSuccess',
            'end try',
            'end if'])

    def test_the_final_steps_come_after_it(self):
        handler = startup_handler()
        block = dictionary_block(handler)
        after = handler[handler.index(block) + len(block):]
        self.assertRegex(after, r'^\s*if tSuccess then\s*\n\s*revInternal__setSplashStatus "Performing Final Steps\.\.\."\s*\n'
                                r'\s*revInternal__InitialiseFinalSteps')

    @unittest.skipUnless(os.environ.get('OXT_SERVER_ENGINE'), 'OXT_SERVER_ENGINE names a server engine')
    def test_the_block_run_on_an_engine(self):
        block = dictionary_block(startup_handler())
        script = '\n'.join([
            '<?lc',
            'global gMode, gLog',
            'function revEnvironmentIsInstalled',
            '  return false',
            'end revEnvironmentIsInstalled',
            'command revInternal__setSplashStatus pWhat',
            'end revInternal__setSplashStatus',
            'command revInternal__Log pKind, pWhat',
            '  put pKind & ":" & pWhat & "|" after gLog',
            'end revInternal__Log',
            'command revInternal__BuildDictionary',
            '  if gMode is "throw" then throw "no database library"',
            '  return gMode',
            'end revInternal__BuildDictionary',
            'function runBlock pMode',
            '  local tSuccess',
            '  put pMode into gMode',
            '  put empty into gLog',
            '  put true into tSuccess',
            block.rstrip('\n'),
            '  return tSuccess & "/" & gLog',
            'end runBlock',
            'put "throw=" & runBlock("throw") & ";" & return',
            'put "false=" & runBlock("false") & ";" & return',
            'put "true=" & runBlock("true") & ";" & return',
            '?>', ''])
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, 'block.lc')
            with open(path, 'w', newline='\n') as f:
                f.write(script)
            out = subprocess.run([os.environ['OXT_SERVER_ENGINE'], path], stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, timeout=60)
        text = out.stdout.decode('latin-1')
        # A throw is logged and the start-up goes on; a result is kept, as before
        self.assertIn('throw=true/Error:Building Dictionary failed: no database library|;', text, out.stderr)
        self.assertIn('false=false/;', text)
        self.assertIn('true=true/;', text)


if __name__ == '__main__':
    unittest.main()
