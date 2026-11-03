"""Windows' colour dialog (answer color, the Inspector's colour swatches):
open in its full form, with the spectrum and the red, green and blue
fields, not the short form of 48 basic colours and a row of black "Custom
colors" (TerryL, openxtalk.org p=25957: "how to choose no color", and a
dialog that looked as if it could only give a few colours). The custom
colours themselves stay as they were: they are the colorDialogColors a
script reads and sets."""

import os
import re
import unittest

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8', errors='replace') as f:
        return f.read()


def color_dialog():
    source = read('engine', 'src', 'w32ans.cpp')
    return source, source.split('bool MCA_color(', 1)[1].split('\nbool ', 1)[0].split('\nvoid ', 1)[0]


class WindowsColourDialog(unittest.TestCase):
    def test_it_opens_in_full(self):
        _source, body = color_dialog()
        flags = re.search(r'chooseclr\.Flags\s*=\s*([^;]+);', body)
        self.assertIsNotNone(flags, 'MCA_color sets no Flags')
        named = set(re.findall(r'CC_[A-Z]+', flags.group(1)))
        self.assertIn('CC_FULLOPEN', named)
        # the colour the script gives is still the one it opens on
        self.assertIn('CC_RGBINIT', named)
        self.assertIn('chooseclr.rgbResult = RGB(p_initial_color.red >> 8', body)

    def test_the_custom_colours_are_as_before(self):
        source, body = color_dialog()
        # the colorDialogColors: 16, black until a script or the dialog sets them
        self.assertIn('static COLORREF s_colordialogcolors[16];', source)
        self.assertIn('chooseclr.lpCustColors = (LPDWORD)s_colordialogcolors;', body)
        self.assertNotIn('CC_PREVENTFULLOPEN', body)


if __name__ == '__main__':
    unittest.main()
