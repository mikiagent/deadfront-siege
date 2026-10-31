"""The authored phase map and its protections."""
import copy
import json
import tempfile
import unittest
from pathlib import Path

import phase_map


class AuthoredMapTests(unittest.TestCase):
    ROOT = Path(__file__).resolve().parents[2]

    def test_authored_map_is_valid_and_dependency_sorted(self):
        data = phase_map.load(self.ROOT)
        phases = data["phases"]
        self.assertEqual([p["phase"] for p in phases], list(range(len(phases))))
        self.assertEqual(phases[0]["phase"], 0)
        ids = [f["id"] for p in phases for f in p["features"]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertGreaterEqual(len(ids), 40)
        # No feature depends upward past its own phase without a reason:
        # 'later' seeds may, 'done' may not depend on an unfinished thing in a past phase.
        deep = {f["id"]: (p["phase"], f["status"], f["depends"]) for p in phases for f in p["features"]}
        for fid, (num, status, deps) in deep.items():
            self.assertNotIn(fid, deps)
            if status != "done":
                continue
            for dep in deps:
                self.assertTrue(deep[dep][0] == num or deep[dep][1] == "done",
                                f"{fid} is done but depends on another phase's unfinished {dep}")

    def test_statuses_use_the_shared_vocabulary(self):
        data = phase_map.load(self.ROOT)
        for phase in data["phases"]:
            for feature in phase["features"]:
                self.assertIn(feature["status"], phase_map.STATUSES)
                self.assertTrue((self.ROOT / feature["source"]).is_file(), feature["source"])


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        (Path(self.tmp.name) / "docs" / "design").mkdir(parents=True)
        (Path(self.tmp.name) / "docs" / "design" / "x.md").write_text("# x\n")
        self.seed = {"x": {"id": "a", "title": "A", "status": "next"}}
        del self.seed

    def good(self, **overrides):
        feature = {"id": "a", "title": "Alpha", "status": "next", "depends": [],
                   "source": "docs/design/x.md"}
        feature.update(overrides)
        return {"goal": "Go", "phases": [{"phase": 0, "title": "T", "theme": "Th",
                                          "features": [feature]}]}

    def validate(self, data):
        return phase_map.validate(Path(self.tmp.name), data)

    def test_valid_map_passes(self):
        self.validate(self.good())

    def test_rejects_bad_ids_statuses_and_duplicate(self):
        with self.assertRaisesRegex(phase_map.PhaseError, "Bad feature id"):
            self.validate(self.good(id="A_1"))
        with self.assertRaisesRegex(phase_map.PhaseError, "status must be"):
            self.validate(self.good(status="tuned"))
        twin = self.good()
        twin["phases"][0]["features"].append(dict(twin["phases"][0]["features"][0]))
        with self.assertRaisesRegex(phase_map.PhaseError, "Duplicate"):
            self.validate(twin)

    def test_rejects_unknown_depend_and_cycle_and_self(self):
        with self.assertRaisesRegex(phase_map.PhaseError, "unknown ids: b"):
            self.validate(self.good(depends=["b"]))
        with self.assertRaisesRegex(phase_map.PhaseError, "depend on itself"):
            self.validate(self.good(depends=["a"]))
        data = {"goal": "g", "phases": []}
        a = {"id": "loop-a", "title": "A", "status": "later", "depends": ["loop-b"], "source": "docs/design/x.md"}
        b = {"id": "loop-b", "title": "B", "status": "later", "depends": ["loop-a"], "source": "docs/design/x.md"}
        data["phases"].append({"phase": 0, "title": "P", "theme": "", "features": [a, b]})
        with self.assertRaisesRegex(phase_map.PhaseError, "cycle"):
            self.validate(data)

    def test_rejects_missing_source_file_and_traversal(self):
        with self.assertRaisesRegex(phase_map.PhaseError, "not a file"):
            self.validate(self.good(source="docs/design/absent.md"))
        with self.assertRaisesRegex(phase_map.PhaseError, "relative"):
            self.validate(self.good(source="docs/design/../design/x.md"))

    def test_phases_must_ascending_without_repeats(self):
        data = self.good()
        data["phases"][0]["phase"] = 3
        data["phases"].append({"phase": 1, "title": "Q", "theme": "", "features": [dict(data["phases"][0]["features"][0]) if False else {"id": "b", "title": "B", "status": "later", "depends": [], "source": "docs/design/x.md"}]})
        with self.assertRaisesRegex(phase_map.PhaseError, "ascending"):
            self.validate(data)

    def test_evidence_accepts_paths_commits_and_links(self):
        self.validate(self.good(evidence=["docs/design/x.md", "commit:2a95b264",
                                          "https://github.com/o/r/pull/1"]))
        with self.assertRaisesRegex(phase_map.PhaseError, "not a file"):
            self.validate(self.good(evidence=["docs/design/absent.png"]))
        with self.assertRaisesRegex(phase_map.PhaseError, "evidence"):
            self.validate(self.good(evidence="docs/design/x.md"))
        with self.assertRaisesRegex(phase_map.PhaseError, "a evidence: .*not a file"):
            self.validate(self.good(evidence=["http://example.com/x"]))


class AuditTests(unittest.TestCase):
    def feature(self, fid, status, depends=(), **extra):
        return {"id": fid, "title": fid.title(), "status": status, "depends": list(depends),
                "source": "docs/design/x.md", **extra}

    def test_audit_sorts_next_and_flags_unevidenced_done(self):
        data = {"goal": "g", "phases": [{"phase": 0, "title": "P", "theme": "", "features": [
            self.feature("base", "done"),
            self.feature("proved", "done", evidence=["commit:abcdef1"]),
            self.feature("ready", "next", ["base"]),
            self.feature("wait", "next", ["later-one"]),
            self.feature("later-one", "later"),
        ]}]}
        report = phase_map.audit(data)
        self.assertEqual([r["id"] for r in report["done_without_evidence"]], ["base"])
        self.assertEqual([r["id"] for r in report["next_buildable"]], ["ready"])
        self.assertEqual(report["next_blocked"][0]["waiting_on"], ["later-one"])

    def test_audit_runs_on_the_authored_map(self):
        root = Path(phase_map.__file__).resolve().parents[2]
        report = phase_map.audit(phase_map.load(root))
        self.assertEqual(set(report), {"done_without_evidence", "next_blocked", "next_buildable"})



class MergeTests(unittest.TestCase):
    def setUp(self):
        self.ROOT = Path(phase_map.__file__).resolve().parents[2]
        self.data = phase_map.load(self.ROOT)

    def test_merge_overrides_without_mutating_the_authored_map(self):
        before = copy.deepcopy(self.data)
        marks = {"mounts": {"status": "later", "note": ""}}
        merged = phase_map.merge(self.data, marks)
        self.assertEqual(merged["phases"][2]["features"][2]["status"], "later")
        self.assertEqual(merged["marks"]["mounts"], {"status": "later", "note": ""})
        self.assertEqual(self.data, before)

    def test_merge_keeps_seed_note_until_a_person_writes_one(self):
        marks = {"mounts": {"status": "done", "note": "owner checked"}}
        merged = phase_map.merge(self.data, marks)
        feat = merged["phases"][2]["features"][2]
        self.assertEqual(feat["status"], "done")
        self.assertEqual(feat["note"], "owner checked")
        self.assertTrue(feat["seed_note"])
        plain = phase_map.merge(self.data, {"mounts": {"status": "done", "note": ""}})
        self.assertNotIn("seed_note", plain["phases"][2]["features"][2])

    def test_merge_tolerates_absent_or_junk_marks(self):
        for junk in (None, [], {"nope-id": {"status": "done"}}, {"mounts": "bad"}):
            merged = phase_map.merge(self.data, junk)
            kept = [f for p in merged["phases"] for f in p["features"] if f["id"] == "mounts"][0]
            self.assertEqual(kept["status"], "done")


if __name__ == "__main__":
    unittest.main()
