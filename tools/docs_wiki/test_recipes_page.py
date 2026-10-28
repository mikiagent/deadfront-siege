"""Check that the recipe reference separates gates, ability and output limits."""
import json
import tempfile
import unittest
from pathlib import Path

from gen_game_data import gen_recipes


ROOT = Path(__file__).resolve().parents[2]


class RecipePageTest(unittest.TestCase):
    def test_real_recipe_and_default_or_zero_fields(self):
        recipes = json.loads((ROOT / 'game/data/recipes.json').read_text())['recipes']
        raid = next(recipe for recipe in recipes if recipe['id'] == 'raid_maul')
        # With missing fields the game defaults to processing, minimum/ability 0,
        # and recipe max_level 60. Explicit zero values must not become 60.
        absent = {'id': 'missing_fields', 'output': {'id': 'missing_fields'}}
        zero = {'id': 'zero_fields', 'skill': 'cooking', 'min_level': 0,
                'required_ability': 0, 'max_level': 0, 'output': {'id': 'zero_fields'}}
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            data, docs, sheets = base / 'data', base / 'docs', base / 'sheets'
            for folder in (data, docs, sheets):
                folder.mkdir()
            (data / 'recipes.json').write_text(json.dumps({'recipes': [raid, absent, zero]}))
            (data / 'items.json').write_text(json.dumps({'items': []}))
            (data / 'processing.json').write_text(json.dumps({'stations': {}}))
            gen_recipes(data, docs, sheets)
            text = (docs / 'recipes.md').read_text()

        rows = {}
        for line in text.splitlines():
            cells = [cell.strip() for cell in line.strip('|').split('|')]
            if cells[0].startswith('`'):
                rows[cells[0].strip('`')] = cells
        self.assertEqual(rows['raid_maul'][3:7], ['weapon_tools', '55', '95', '60'])
        self.assertEqual(rows['missing_fields'][3:7], ['processing', '0', '0', '60'])
        self.assertEqual(rows['zero_fields'][3:7], ['cooking', '0', '0', '0'])
        self.assertIn('ability target` affects success chance rather than imposing a hard gate', text)
        self.assertNotIn('weapon_tools ≤ 60', text)


if __name__ == '__main__':
    unittest.main()
