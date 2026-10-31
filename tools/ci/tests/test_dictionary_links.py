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

"""The Dictionary viewer's links (ide/Documentation/html_viewer/js/
dictionary_functions.js): a <placeholder> that names no entry is shown as
its text, not left as "<text>" for the browser to take as a tag and hide
(the systemAppearanceChanged entry lost "effective" and "current card",
openxtalk.org p=25668), while real HTML tags in a description stay tags and
a placeholder that resolves is still a link. The viewer's own functions are
cut out of the file and run under Node with stand-ins for jQuery and the
entry index; skipped when there is no node.

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import shutil
import subprocess
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
VIEWER = os.path.join(REPO, 'ide', 'Documentation', 'html_viewer', 'js', 'dictionary_functions.js')
FUNCTIONS = ('link_placeholder_is_html_tag', 'replace_link_placeholders_with_links', 'resolve_link_placeholder',
             'resolve_link', 'click_text_from_index')
NODE = shutil.which('node')

HARNESS = r'''
var $ = {each: function(o, f) {
  if (Array.isArray(o)) { for (var i = 0; i < o.length; i++) if (f(i, o[i]) === false) break; }
  else { for (var k in o) if (f(k, o[k]) === false) break; }
}};
function isDefined(x) { return typeof x !== 'undefined'; }
// The entries this test knows: systemAppearance (property) is index 7
function entryNameToIndex(name, type, library) {
  return (name == 'systemAppearance' && type == 'property') ? 7 : undefined;
}
%(source)s
var entry = {"display name": "systemAppearanceChanged", references: {property: ["systemAppearance"]}};
var out = {};
var cases = %(cases)s;
for (var i = 0; i < cases.length; i++) out[cases[i]] = replace_link_placeholders_with_links(cases[i], entry);
console.log(JSON.stringify(out));
'''


def cut_functions(text, names):
    """The source of the named top-level functions and the variables they
    use (html_tag_regex, link_placeholder_regex)."""
    parts = ['var link_placeholder_regex;']
    for pattern in (r'(?m)^\s*link_placeholder_regex\s*=\s*.*;$', r'(?m)^\s*var html_tag_regex\s*=\s*.*;$'):
        m = re.search(pattern, text)
        if m is None:
            raise AssertionError('no %s in the viewer' % pattern)
        parts.append(m.group(0))
    for name in names:
        m = re.search(r'(?m)^\s*function %s\s*\(' % name, text)
        if m is None:
            raise AssertionError('no function %s in the viewer' % name)
        start = m.start()
        depth, i = 0, text.index('{', m.end())
        while True:
            c = text[i]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        parts.append(text[start:i + 1])
    return '\n'.join(parts)


@unittest.skipIf(NODE is None, 'no node')
class DictionaryLinksTest(unittest.TestCase):
    def render(self, cases):
        with open(VIEWER, encoding='utf-8') as f:
            source = cut_functions(f.read(), FUNCTIONS)
        script = HARNESS % {'source': source, 'cases': json.dumps(cases)}
        out = subprocess.run([NODE, '-e', script], capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout)

    def test_unresolved_placeholder_shows_its_text(self):
        got = self.render(['the <effective> <backgroundColor> of a stack', 'the <current card> of'])
        self.assertEqual(got['the <effective> <backgroundColor> of a stack'], 'the effective backgroundColor of a stack')
        self.assertEqual(got['the <current card> of'], 'the current card of')

    def test_unresolved_label_shows_the_label(self):
        got = self.render(['the <nothing here|label> changes'])
        self.assertEqual(got['the <nothing here|label> changes'], 'the label changes')

    def test_html_tags_stay_tags(self):
        cases = ['a <b>bold</b> word', 'line<br/>break', '<code>x</code>', '<a href="x">y</a>', '<!-- note -->']
        got = self.render(cases)
        for c in cases:
            self.assertEqual(got[c], c)

    def test_resolved_placeholder_is_a_link(self):
        got = self.render(['when the <systemAppearance> changes', '<systemAppearanceChanged>'])
        self.assertIn('entryindex="7">systemAppearance</a>', got['when the <systemAppearance> changes'])
        self.assertEqual(got['<systemAppearanceChanged>'], '<span class="lcdoc_entry_name">systemAppearanceChanged</span>')


if __name__ == '__main__':
    unittest.main()
