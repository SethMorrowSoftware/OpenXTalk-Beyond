"""The Stack Player's compile probe (playerCompiles, playerDropProbe) is a
stack of its own: a played stack, or one of its substacks, that happens to
be named like it is never written to or deleted (#453)."""

import os
import re
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))


def player():
    with open(os.path.join(ROOT, 'tools', 'web-player', 'stack-player.livecodescript'),
              encoding='utf-8') as f:
        return f.read()


def handler(text, kind, name):
    start = re.search(r'\n(private )?%s %s\b' % (kind, name), text)
    assert start, name
    return text[start.start():text.index('\nend %s' % name, start.start())]


class TheProbe(unittest.TestCase):
    def test_it_is_made_with_a_name_of_its_own(self):
        body = handler(player(), 'function', 'playerCompiles')
        self.assertIn('put "Player Compile Probe" && the milliseconds into tName', body)
        self.assertIn('repeat while there is a stack tName', body)
        self.assertIn('put the long id of stack tName into sProbe', body)
        self.assertIn('set the script of sProbe to pScript', body)

    def test_only_it_is_deleted(self):
        body = handler(player(), 'command', 'playerDropProbe')
        self.assertIn('if sProbe is not empty and there is a sProbe then\n         delete sProbe', body)
        self.assertIn('put empty into sProbe', body)

    def test_no_stack_is_named_by_the_fixed_name(self):
        self.assertNotIn('stack "Player Compile Probe"', player())


if __name__ == '__main__':
    unittest.main()
