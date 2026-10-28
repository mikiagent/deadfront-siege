"""Exercise the sheet overwrite guard against the real data in temporary outputs."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


class GenerationTest(unittest.TestCase):
    def test_sheet_conflict_is_preflighted_and_force_is_explicit(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            docs, sheets = base / "docs", base / "sheets"
            command = [sys.executable, str(HERE / "gen_game_data.py"),
                       "--data", str(ROOT / "game/data"), "--docs", str(docs),
                       "--sheets", str(sheets)]

            def run(*args):
                return subprocess.run(command + list(args), capture_output=True, text=True)

            first = run()
            self.assertEqual(first.returncode, 0, first.stderr)
            unchanged = run()
            self.assertEqual(unchanged.returncode, 0, unchanged.stderr)

            sheet = sheets / "items.csv"
            original = sheet.read_bytes()
            sheet.write_bytes(original + b"owner edit\n")
            before = {p: p.read_bytes() for folder in (docs, sheets) for p in folder.iterdir()}

            refused = run()
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("items.csv", refused.stderr)
            self.assertIn("No outputs were written", refused.stderr)
            self.assertEqual(before, {p: p.read_bytes() for folder in (docs, sheets)
                                      for p in folder.iterdir()})

            forced = run("--force-sheets")
            self.assertEqual(forced.returncode, 0, forced.stderr)
            self.assertEqual(sheet.read_bytes(), original)

            notes = sheets / "NOTES.md"
            notes.write_text(notes.read_text() + "\nOwner notes\n")
            refused_notes = run()
            self.assertNotEqual(refused_notes.returncode, 0)
            self.assertIn("NOTES.md", refused_notes.stderr)
            self.assertIn("Owner notes", notes.read_text())


if __name__ == "__main__":
    unittest.main()
