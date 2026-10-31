"""Read-only HTTP tests against temporary sheet files, never the live data."""
import hashlib
import json
import struct
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import urlopen

import docs_wiki


class SheetApiTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.old_dir = docs_wiki.SHEETS_DIR
        self.old_root = docs_wiki.ROOT
        self.old_state_path = docs_wiki.STATE_PATH
        docs_wiki.ROOT = self.root
        docs_wiki.SHEETS_DIR = self.root / "sheets"
        docs_wiki.STATE_PATH = self.root / "state.json"
        docs_wiki.SHEETS_DIR.mkdir()
        self.raw = b'\xef\xbb\xbfid,name,value\r\ntrait_1,"Name, one",12.5\r\ntrait_2,"Two\nlines",7\r\n'
        (docs_wiki.SHEETS_DIR / "traits.csv").write_bytes(self.raw)
        outside = self.root / "outside.csv"
        outside.write_text("secret\nprivate\n")
        (docs_wiki.SHEETS_DIR / "link.csv").symlink_to(outside)
        (docs_wiki.SHEETS_DIR / "not-a-sheet.txt").write_text("ignored")
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), docs_wiki.Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = "http://127.0.0.1:%d" % self.server.server_port

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        docs_wiki.SHEETS_DIR = self.old_dir
        docs_wiki.ROOT = self.old_root
        docs_wiki.STATE_PATH = self.old_state_path
        self.temp.cleanup()

    def request(self, path):
        with urlopen(self.base + path, timeout=3) as response:
            return json.load(response)

    def test_catalog_and_sheet_preserve_cells_and_revision(self):
        catalog = self.request("/api/sheets")
        self.assertEqual(catalog, {"sheets": [{"name": "traits.csv",
                                              "kind": "csv",
                                              "source_path": "game/data_sheets/traits.csv",
                                              "columns": ["id", "name", "value"],
                                              "editable_columns": ["name", "value"],
                                              "row_count": 2}]})
        sheet = self.request("/api/sheet?name=traits.csv")
        self.assertEqual(sheet["columns"], ["id", "name", "value"])
        self.assertEqual(sheet["rows"], [["trait_1", "Name, one", "12.5"],
                                         ["trait_2", "Two\nlines", "7"]])
        self.assertEqual(sheet["revision"], hashlib.sha256(self.raw).hexdigest())
        self.assertEqual((docs_wiki.SHEETS_DIR / "traits.csv").read_bytes(), self.raw)

    def test_rejects_traversal_symlinks_and_missing_files(self):
        for name, status in [("../outside.csv", 400), ("a/b.csv", 400),
                             ("link.csv", 404), ("missing.csv", 404)]:
            with self.subTest(name=name), self.assertRaises(HTTPError) as error:
                self.request("/api/sheet?name=" + quote(name, safe=""))
            self.assertEqual(error.exception.code, status)
            error.exception.close()

    def test_rejects_malformed_and_ragged_csv(self):
        for contents in ['a,b\n"unclosed', 'a,b\nonly-one\n']:
            with self.subTest(contents=contents):
                (docs_wiki.SHEETS_DIR / "bad.csv").write_text(contents)
                with self.assertRaises(HTTPError) as error:
                    self.request("/api/sheet?name=bad.csv")
                self.assertEqual(error.exception.code, 400)
                error.exception.close()

    def test_json_parameters_use_curated_paths_pointers_and_revision(self):
        data_dir = self.root / "game/data"
        (data_dir / "world").mkdir(parents=True)
        combat = b'{"a/b":{"~power":1.5},"items":[3,2.0],"enabled":true,"name":"ignored","_doc":3}'
        (data_dir / "combat_tuning.json").write_bytes(combat)
        rules = b'{"crafting":{"rare_attributes":["black_sheen","low_vibration"]},"chance":0.05,"attributes":{"a/b~c":"documented effect","light":"faster swing"}}'
        (data_dir / "world/rules.json").write_bytes(rules)
        (data_dir / "secret.json").write_text('{"number":123}')
        catalog = self.request("/api/sheets")["sheets"]
        self.assertEqual([entry["name"] for entry in catalog], [
            "traits.csv", "json:game/data/combat_tuning.json", "json:game/data/world/rules.json",
            "json:game/data/world/rules.json#traits"])
        sheet = self.request("/api/sheet?name=" + quote("json:game/data/combat_tuning.json", safe=""))
        self.assertEqual(sheet["kind"], "json")
        self.assertEqual(sheet["source_path"], "game/data/combat_tuning.json")
        self.assertEqual(sheet["columns"], ["parameter", "type", "value"])
        self.assertEqual(sheet["editable_columns"], ["value"])
        self.assertEqual(sheet["revision"], hashlib.sha256(combat).hexdigest())
        self.assertEqual(sheet["rows"], [["/a~1b/~0power", "number", "1.5"],
                                          ["/items/0", "integer", "3"],
                                          ["/items/1", "number", "2.0"]])
        rules_sheet = self.request("/api/sheet?name=" + quote("json:game/data/world/rules.json", safe=""))
        self.assertEqual(rules_sheet["rows"], [["/crafting/rare_attributes/0", "string", "black_sheen"],
                                                ["/crafting/rare_attributes/1", "string", "low_vibration"],
                                                ["/chance", "number", "0.05"]])
        traits = self.request("/api/sheet?name=" + quote("json:game/data/world/rules.json#traits", safe=""))
        self.assertEqual(traits["kind"], "trait-map")
        self.assertEqual(traits["source_path"], "game/data/world/rules.json")
        self.assertEqual(traits["revision"], hashlib.sha256(rules).hexdigest())
        self.assertEqual(traits["columns"], ["parameter", "trait name", "documented effect"])
        self.assertEqual(traits["editable_columns"], ["trait name", "documented effect"])
        self.assertEqual(traits["rows"], [["/attributes/a~1b~0c", "a/b~c", "documented effect"],
                                           ["/attributes/light", "light", "faster swing"]])
        self.assertIn("do not prove", traits["description"])
        for name in ("json:game/data/secret.json", "json:game/data/../data/combat_tuning.json"):
            with self.subTest(name=name), self.assertRaises(HTTPError) as error:
                self.request("/api/sheet?name=" + quote(name, safe=""))
            self.assertEqual(error.exception.code, 404)
            error.exception.close()
        self.assertEqual((data_dir / "combat_tuning.json").read_bytes(), combat)

    def test_image_allowlist_and_symlink_escape(self):
        image_dir = self.root / "docs/reference"
        image_dir.mkdir(parents=True)
        png = b"\x89PNG\r\n\x1a\nexample"
        (image_dir / "sample.png").write_bytes(png)
        (self.root / "outside.png").write_bytes(b"secret")
        (image_dir / "escape.png").symlink_to(self.root / "outside.png")
        (image_dir / "file.svg").write_text("<svg/>")
        with urlopen(self.base + "/api/image?path=docs%2Freference%2Fsample.png", timeout=3) as response:
            self.assertEqual(response.headers["Content-Type"], "image/png")
            self.assertEqual(response.read(), png)
        for path in ("outside.png", "docs/reference/escape.png", "docs/reference/file.svg",
                     "docs/reference/../../outside.png", "docs/reference/missing.png"):
            with self.subTest(path=path), self.assertRaises(HTTPError) as error:
                urlopen(self.base + "/api/image?path=" + quote(path, safe=""), timeout=3)
            self.assertEqual(error.exception.code, 404)
            error.exception.close()

    def test_species_tuning_excludes_animation_and_appearance_metadata(self):
        creatures = self.root / "game/data/creatures"
        creatures.mkdir(parents=True)
        (creatures / "velociraptor.json").write_text(
            '{"species":"Velociraptor","tier":25,"stats":{"hp":640},'
            '"taming":{"seconds":30},"clips":{"run":{"speed":8}},'
            '"pipeline":{"revision":3},"coloration":{"hue_deg":14},"eyes":{"glow":1}}')
        (creatures / "anim_events.json").write_text('{"duration":20}')
        catalog = self.request("/api/sheets")["sheets"]
        self.assertIn("json:game/data/creatures/velociraptor.json", [row["name"] for row in catalog])
        self.assertNotIn("json:game/data/creatures/anim_events.json", [row["name"] for row in catalog])
        sheet = self.request("/api/sheet?name=" + quote("json:game/data/creatures/velociraptor.json", safe=""))
        self.assertEqual(sheet["rows"], [["/tier", "integer", "25"], ["/stats/hp", "integer", "640"],
                                          ["/taming/seconds", "integer", "30"]])
        self.assertIn("does not prove", sheet["description"])
        with self.assertRaises(HTTPError) as error:
            self.request("/api/sheet?name=" + quote("json:game/data/creatures/anim_events.json", safe=""))
        self.assertEqual(error.exception.code, 404)
        error.exception.close()

    def test_models_api_limits_files_to_assets_and_skips_cache(self):
        assets = self.root / "game/assets"
        (assets / "creatures/raptor").mkdir(parents=True)
        (assets / "work").mkdir()
        (assets / ".godot").mkdir()
        # A complete, embedded triangle with one mesh and position accessor.
        # The model index rejects malformed files and animation-only libraries.
        positions = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
        spec = {
            "asset": {"version": "2.0"},
            "buffers": [{"byteLength": len(positions)}],
            "bufferViews": [{"buffer": 0, "byteLength": len(positions), "target": 34962}],
            "accessors": [{"bufferView": 0, "componentType": 5126, "count": 3,
                           "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 0]}],
            "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}],
            "nodes": [{"mesh": 0}], "scenes": [{"nodes": [0]}], "scene": 0,
        }
        chunk = json.dumps(spec, separators=(",", ":")).encode("utf-8")
        chunk += b" " * (-len(chunk) % 4)
        data = (struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(chunk) + 8 + len(positions))
                + struct.pack("<I4s", len(chunk), b"JSON") + chunk
                + struct.pack("<I4s", len(positions), b"BIN\0") + positions)
        (assets / "creatures/raptor/raptor.glb").write_bytes(data)
        (assets / "work/cache.glb").write_bytes(data)
        (assets / ".godot/cache.glb").write_bytes(data)
        (assets / "cache-alias.glb").symlink_to(assets / "work/cache.glb")
        (self.root / "secret.glb").write_bytes(b"secret")
        (assets / "escape.glb").symlink_to(self.root / "secret.glb")
        (assets / "not-model.txt").write_text("ignored")
        self.assertEqual(self.request("/api/models"), {"models": [
            {"path": "game/assets/creatures/raptor/raptor.glb", "name": "raptor", "group": "creatures"}]})
        path = "game/assets/creatures/raptor/raptor.glb"
        with urlopen(self.base + "/api/model?path=" + quote(path, safe=""), timeout=3) as response:
            self.assertEqual(response.headers["Content-Type"], "model/gltf-binary")
            self.assertEqual(response.read(), data)
        for path in ("game/assets/escape.glb", "game/assets/cache-alias.glb", "game/assets/work/cache.glb",
                     "game/assets/.godot/cache.glb", "game/assets/../../secret.glb",
                     "secret.glb", "game/assets/not-model.txt"):
            with self.subTest(path=path), self.assertRaises(HTTPError) as error:
                urlopen(self.base + "/api/model?path=" + quote(path, safe=""), timeout=3)
            self.assertEqual(error.exception.code, 404)
            error.exception.close()


if __name__ == "__main__":
    unittest.main()
