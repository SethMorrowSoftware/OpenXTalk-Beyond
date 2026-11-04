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
"""The Responsive Starter's check (tools/ci/responsive_web_check.py) held
to the pieces it works with, without a browser or an engine:

- every handler the check calls in the page is one that the check's
  stack (responsive-web-check.livecodescript) has, and one the check
  asks the standalone's startup script to let the page call; that script
  (mobile-web-deploy.livecodescript) still lets the Phone Starter's check
  call its own when it is not asked
- the Responsive Starter is offered: in the Stack Player's samples, with
  its picture, and in Home's gallery, with an icon Home can draw
- the workflow runs the check in Chromium and WebKit, and not in Firefox
- the starter's tabs agree in its builder and its script, the bars'
  sizes the check expects are the builder's rules, and every rule the
  builder writes uses only words the library knows
- no statement is too long for an iPhone's Safari
- the guide is in the Dictionary's deployment guides, beside Stacks for
  Phones, and names what it teaches
- the check's small helpers

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
sys.path.insert(0, HERE)
import responsive_web_check as rwc  # noqa: E402
import test_mobile_web_check  # noqa: E402

PLAYER = os.path.join(REPO, 'tools', 'web-player')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class PageHandlers(unittest.TestCase):

    def test_every_handler_the_check_calls_is_there_and_asked_for(self):
        check = read('tools', 'ci', 'responsive_web_check.py')
        stack = read('tools', 'ci', 'responsive-web-check.livecodescript')
        called = set(re.findall(r"call\([\w.]+, '(rc\w+)'", check))
        called |= set(re.findall(r"h\.(rc\w+)\(", check))
        self.assertIn('rcState', called)
        self.assertIn('rcInsets', called)
        defined = set(re.findall(r'^(?:function|command) (rc\w+)', stack, re.M))
        for name in sorted(called):
            self.assertIn(name, defined, 'responsive-web-check.livecodescript has no %s' % name)
            self.assertIn(name, rwc.HANDLERS, 'the check does not ask for %s to be callable' % name)
        self.assertIn('script "%s"' % rwc.CHECK_NAME, stack)

    def test_the_deploy_script_takes_the_handlers_and_keeps_its_own(self):
        deploy = read('tools', 'ci', 'mobile-web-deploy.livecodescript')
        self.assertIn('repeat for each item tHandler in $OXT_MW_HANDLERS', deploy)
        self.assertIn('$OXT_MW_CHECK_NAME', deploy)
        # without them, the Phone Starter's check's handlers, as before
        self.assertIn('if $OXT_MW_HANDLERS is not empty then', deploy)
        for name in ('mwcState', 'mwcStarterScript', 'mwcNotFromATap'):
            self.assertIn('quote & "%s" & quote' % name, deploy)

    def test_the_check_finds_its_files(self):
        for path in (rwc.STARTER, rwc.STARTER_BUILDER, rwc.STARTER_SCRIPT, rwc.CHECK_STACK):
            self.assertTrue(os.path.isfile(path), path)


class Offered(unittest.TestCase):

    def test_in_the_stack_players_samples(self):
        sys.path.insert(0, PLAYER)
        import build_player
        sample = [s for s in build_player.SAMPLES if s['title'] == 'Responsive Starter']
        self.assertEqual(len(sample), 1)
        self.assertEqual(sample[0]['files'], ['Responsive Starter.oxtstack'])
        for name in ('Responsive Starter.oxtstack', 'Responsive Starter.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', name)), name)

    def test_in_homes_gallery_with_an_icon(self):
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        kit = read('ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
        self.assertRegex(learn, r'Phone Starter,Responsive Starter"')
        case = re.search(r'case "Responsive Starter"\n(.*?)\n      case|case "Responsive Starter"\n(.*?)end switch',
                         learn, re.S)
        self.assertIsNotNone(case)
        icon = re.search(r'\|([a-z0-9-]+)\|[a-z]+\|[^|"]+"', case.group(0)).group(1)
        self.assertIn('case "%s"' % icon, kit)


class Workflow(unittest.TestCase):

    def test_chromium_and_webkit(self):
        web = read('.github', 'workflows', 'web.yml')
        step = web[web.index('- name: Check the Responsive Starter'):]
        step = step[:step.index('\n      - name:', 10)]
        self.assertIn("if: matrix.browser != 'firefox'", step)
        self.assertIn('tools/ci/responsive_web_check.py', step)
        self.assertIn('--browser "$BROWSER"', step)
        self.assertIn('--engine-cache', step)
        self.assertNotIn('--rebuild', step)


class Starter(unittest.TestCase):

    def test_the_tabs_agree(self):
        builder = read('tools', 'web-player', 'responsive-starter.livecodescript')
        script = read('tools', 'web-player', 'responsive-starter-stack.livecodescript')
        tabs = re.search(r'^constant kTabs = "([^"]+)"', builder, re.M).group(1)
        self.assertIn('constant kTabs = "%s"' % tabs, script)
        self.assertEqual(tabs.split(','), ['Explore', 'Saved', 'Guide'])

    def test_the_bars_the_check_expects_are_the_rules(self):
        builder = read('tools', 'web-player', 'responsive-starter.livecodescript')
        nav = builder[builder.index('private command buildNav'):builder.index('end buildNav')]
        self.assertIn('height %d, bleed' % rwc.TAB_BAR, nav)
        self.assertIn('width %d, bleed' % rwc.RAIL, nav)
        self.assertIn('width %d, bleed' % rwc.SIDEBAR, nav)
        detail = builder[builder.index('private command buildDetail'):builder.index('end buildDetail')]
        self.assertIn('width %d' % rwc.PANE, detail)

    def rules(self, text):
        """Every string in the builder that reads as a layout rule"""
        first = r'(?:within|hidden|shown|bleed|left|top|right|bottom|width|height|flow|gap)\b'
        return [r for r in re.findall(r'"([^"]*)"', text) if re.match(first, r)]

    def test_every_rule_uses_the_librarys_words(self):
        library = read('extensions', 'script-libraries', 'mobileweb', 'mobileweb.livecodescript')
        words = re.search(r'^constant kRuleWords = "([^"]+)"', library, re.M).group(1).split(',')
        builder = read('tools', 'web-player', 'responsive-starter.livecodescript')
        found = self.rules(builder)
        self.assertGreater(len(found), 40)
        for rule in found:
            parts = rule.split(',')
            for at, part in enumerate(parts):
                self.assertIn(part.split()[0], words, rule)
                if part.split()[0] in ('within', 'hidden', 'shown', 'bleed'):
                    continue
                if at == len(parts) - 1 and part.strip() in words:
                    continue  # its number follows in the script ("top" && 72 + i * 64)
                self.assertRegex(part.strip(), r'^\w+ -?\d+%?$', rule)

    def test_the_measure_sees_a_bad_word(self):
        self.assertEqual(self.rules('x "left 0, rigth 4" y "Kyoto"'), ['left 0, rigth 4'])

    def test_fields_on_every_card_share_their_text(self):
        builder = read('tools', 'web-player', 'responsive-starter.livecodescript')
        for group in ('Nav', 'Top Bar', 'Detail'):
            self.assertIn('shareText the long id of group "%s"' % group, builder)
        self.assertIn('set the sharedText of field i of pGroup to true', builder)

    def test_no_field_takes_the_keys_until_it_is_wanted(self):
        builder = read('tools', 'web-player', 'responsive-starter.livecodescript')
        script = read('tools', 'web-player', 'responsive-starter-stack.livecodescript')
        self.assertIn('set the traversalOn of field "Search" of tBox to false', builder)
        self.assertIn('command rsSearchFocus', script)
        self.assertNotIn('focus on field "Search"\n', script)

    def test_no_statement_is_too_long_for_an_iphone(self):
        measure = test_mobile_web_check.FitsAnIPhonesStack('test_no_statement_is_too_long')
        for name in ('responsive-starter.livecodescript', 'responsive-starter-stack.livecodescript'):
            self.assertLessEqual(measure.longest_statement(read('tools', 'web-player', name)),
                                 test_mobile_web_check.FitsAnIPhonesStack.LONGEST, name)


class Guide(unittest.TestCase):

    def test_the_guide_is_in_its_group_and_links_its_neighbour(self):
        guide = read('ide', 'Documentation', 'guides', 'Stacks for Every Screen.md')
        self.assertTrue(guide.startswith('---\ngroup: deployment\n---\n# Stacks for Every Screen\n'))
        for name in ('mwResponsive', 'mwApplyLayout', 'mwLayoutClass', 'mwSetBreakpoints', 'mwFlow',
                     'mwPointer', 'mwAppearance', 'layoutChanged', 'Responsive Starter', 'Stacks for Phones'):
            self.assertIn(name, guide)
        self.assertIn('Stacks for Every Screen', read('ide', 'Documentation', 'guides', 'Stacks for Phones.md'))


class Helpers(unittest.TestCase):

    def test_tiles_and_columns(self):
        text = '1:248,84,463,240;2:479,84,693,240;3:709,84,924,240;4:248,256,463,412'
        self.assertEqual(sorted(rwc.tiles(text)), [1, 2, 3, 4])
        self.assertEqual(rwc.tiles(text)[2], [479, 84, 693, 240])
        self.assertEqual(rwc.columns(text), 3)
        self.assertEqual(rwc.tiles(''), {})
        self.assertEqual(rwc.columns(''), 0)

    def test_centre(self):
        self.assertEqual(rwc.centre([0, 0, 10, 20]), (5, 10))


if __name__ == '__main__':
    unittest.main()
