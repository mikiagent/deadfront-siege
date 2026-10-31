"""Check the biome-spawn page follows CreatureDef.eligible and the spawn-level rule."""
import tempfile
import unittest
from pathlib import Path

from gen_game_data import eligible, gen_spawns, spawn_rows


ROOT = Path(__file__).resolve().parents[2]


class BiomeSpawnsTest(unittest.TestCase):
    def test_eligible_matches_noboxes_rule(self):
        with tempfile.TemporaryDirectory() as tmp:
            assets = Path(tmp)
            for sp in ("b", "z"):
                (assets / "creatures" / sp).mkdir(parents=True)
                (assets / "creatures" / sp / ("%s.glb" % sp)).write_bytes(b"")
            self.assertEqual(eligible(assets, "b", ["a", "b"]), "b")
            self.assertEqual(eligible(assets, "a", ["a", "b", "c"]), "b")  # next in table
            self.assertEqual(eligible(assets, "c", ["a", "b", "c"]), "b")  # wraps
            self.assertEqual(eligible(assets, "a", ["a", "c"], ["c", "z"]), "z")  # island pool
            self.assertEqual(eligible(assets, "a", ["a"]), "")

    def test_real_data_rows_and_page(self):
        data = ROOT / "game/data"
        defs, rows = spawn_rows(data, ROOT / "game/assets")
        islands = {r["island"] for r in rows}
        self.assertIn("tutorial_isle", islands)
        self.assertIn("volcanic_60", islands)
        for r in rows:
            if r["got"]:
                self.assertTrue((ROOT / "game/assets/creatures" / r["got"] / ("%s.glb" % r["got"])).exists(), r)
            if r["island"] in ("tutorial_isle", "home_grassland"):
                self.assertEqual(r["levels"], (1, 1), r)  # level_override 1
            self.assertTrue(1 <= r["levels"][0] <= r["levels"][1] <= 60, r)
        self.assertFalse(any(r["alpha"] for r in rows if r["island"] == "tutorial_isle"))
        with tempfile.TemporaryDirectory() as tmp:
            gen_spawns(data, Path(tmp))
            page = (Path(tmp) / "biome-spawns.md").read_text()
        self.assertIn("## Tundra", page)
        self.assertIn("### `tutorial_isle`", page)


if __name__ == "__main__":
    unittest.main()
