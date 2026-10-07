#!/usr/bin/env python3
"""Check paired resources, readable text and bright fills without changing blue."""
import json
import math
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent
MODES = ['base', 'dark']
COLORS = ['green', 'pink', 'orange', 'red']
SLOTS = ['bg', 'surface', 'ink', 'muted', 'line', 'divider', 'groupDivider', 'onAccent', 'brand', 'accent', 'tint', 'shadow']
BLUE = dict(zip(SLOTS, ['background', 'v3_surface', 'v3_text_primary', 'v3_text_secondary', 'nd_card_border', 'border', 'v3_chart_grid', 'on_accent', 'diff_content', 'diff_content', 'v3_surface_alt', 'v3_shadow']))


def resources(mode):
    result = {}
    for path in (ROOT / f'entry/src/main/resources/{mode}/element').glob('*.json'):
        for item in json.loads(path.read_text()).get('color', []):
            if item['name'] in result:
                raise AssertionError('Duplicate resource: ' + item['name'])
            result[item['name']] = item['value']
    return result


def linear_rgb(value):
    rgb = [int(value[-6:][i:i+2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]


def luminance(value):
    return sum(v * w for v, w in zip(linear_rgb(value), [.2126, .7152, .0722]))


def contrast(a, b):
    low, high = sorted([luminance(a), luminance(b)])
    return (high + .05) / (low + .05)


def oklab(value):
    r, g, b = linear_rgb(value)
    l = (.4122214708*r + .5363325363*g + .0514459929*b) ** (1/3)
    m = (.2119034982*r + .6806995451*g + .1073969566*b) ** (1/3)
    s = (.0883024619*r + .2817188376*g + .6299787005*b) ** (1/3)
    return (.2104542553*l + .793617785*m - .0040720468*s,
            1.9779984951*l - 2.428592205*m + .4505937099*s,
            .0259040371*l + .7827717662*m - .808675766*s)


class ThemeColorsTest(unittest.TestCase):
    def test_every_palette_has_matching_resources_and_compilable_references(self):
        expected = {f'theme_{color}_{slot}' for color in COLORS for slot in SLOTS}
        for mode in MODES:
            values = resources(mode)
            self.assertEqual({k for k in values if k.startswith('theme_')}, expected)
            for value in values.values():
                self.assertRegex(value, r'^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$')
        source = (ROOT / 'entry/src/main/ets/common/ThemePalettes.ets').read_text()
        references = re.findall(r"\$r\('app.color.([^']+)'\)", source)
        self.assertEqual(set(references), expected | set(BLUE.values()))
        self.assertEqual(len(references), 5 * len(SLOTS))

    def test_original_blue_anchors_are_preserved(self):
        anchors = {
            'base': {'background': '#FFF6F9FF', 'v3_surface': '#FFFFFFFF', 'v3_surface_alt': '#FFF0F4FA', 'diff_content': '#1E6FCD', 'v3_text_primary': '#FF172033', 'v3_text_secondary': '#FF5F6B7A'},
            'dark': {'background': '#1A2B3C', 'v3_surface': '#FF182231', 'v3_surface_alt': '#FF101927', 'diff_content': '#4A9CE2', 'v3_text_primary': '#FFF1F4F8', 'v3_text_secondary': '#FFA8B4C3'},
        }
        for mode, expected in anchors.items():
            values = resources(mode)
            self.assertEqual({k: values[k] for k in expected}, expected)

    def test_new_palettes_keep_readability_and_blue_layer_relationships(self):
        for mode in MODES:
            values = resources(mode)
            blue = {slot: values[key] for slot, key in BLUE.items()}
            for color in COLORS:
                palette = {slot: values[f'theme_{color}_{slot}'] for slot in SLOTS}
                with self.subTest(mode=mode, color=color):
                    for background in ['bg', 'surface', 'tint']:
                        self.assertGreaterEqual(contrast(palette['ink'], palette[background]), 7)
                        self.assertGreaterEqual(contrast(palette['muted'], palette[background]), 4.5)
                        self.assertGreaterEqual(contrast(palette['accent'], palette[background]), 4.5)
                    self.assertGreaterEqual(contrast(palette['onAccent'], palette['brand']), 4.5)
                    for slot in ['bg', 'surface', 'tint', 'ink', 'muted']:
                        self.assertLess(abs(oklab(palette[slot])[0] - oklab(blue[slot])[0]), .08)
                    for first, second in [('bg', 'surface'), ('surface', 'tint')]:
                        self.assertGreater((luminance(palette[first]) - luminance(palette[second])) * (luminance(blue[first]) - luminance(blue[second])), 0)
                    L, a, b = oklab(palette['brand'])
                    self.assertGreater(L, .70 if mode == 'base' else .75)
                    self.assertLess(L, .90)
                    self.assertGreater(math.hypot(a, b), .09)
                    self.assertLess(math.hypot(a, b), .18)
                    self.assertEqual(palette['shadow'][1:3], blue['shadow'][1:3])


if __name__ == '__main__':
    unittest.main(verbosity=2)
