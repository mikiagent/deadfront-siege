"""Exercise the read-only split proposal and its source protections."""
import copy
import hashlib
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from plan_refactor import apply_split, propose_refactor


class RefactorProposalTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.vision = self.root / "docs" / "vision"
        self.vision.mkdir(parents=True)
        self.path = self.vision / "example.md"
        self.source = ("# Example\n\nOwner decision.\n\n"
                       "## A first section\n\nKeep this exactly.\n\n"
                       "```md\n## not a heading\n```\n\n"
                       "### Shared heading\nSee [other](#a-second-section).\n\n"
                       "## A second section\n\nSee [local](reference.md).\n\n"
                       "### Shared heading\nLast line.\n")
        self.path.write_text(self.source)

    def test_original_is_preserved_and_index_links_are_reviewable(self):
        before = self.path.read_bytes()
        result = propose_refactor("docs/vision/example.md", root=self.root)
        self.assertEqual(result["source_revision"], hashlib.sha256(before).hexdigest())
        self.assertEqual(result["preamble"] + "".join(s["content"] for s in result["sections"]), self.source)
        self.assertEqual(result["section_count"], 2)
        self.assertEqual(result["sections"][0]["start_line"], 5)
        self.assertNotIn("not a heading](", result["index_preview"])
        self.assertIn("## [A first section](example--01-a-first-section.md#a-first-section)", result["index_preview"])
        self.assertIn("### [Shared heading](example--02-a-second-section.md#shared-heading)", result["index_preview"])
        self.assertEqual(result["sections"][1]["anchors"][1]["original"], "shared-heading-1")
        self.assertEqual(result["sections"][1]["anchors"][1]["section"], "shared-heading")
        self.assertTrue(any("#a-second-section" in w for w in result["warnings"]))
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(sorted(p.name for p in self.vision.iterdir()), ["example.md"])

    def test_existing_destination_is_flagged_without_overwrite(self):
        destination = self.vision / "example--01-a-first-section.md"
        destination.write_text("existing")
        result = propose_refactor("docs/vision/example.md", root=self.root)
        self.assertTrue(any("already exists" in w for w in result["warnings"]))
        self.assertEqual(destination.read_text(), "existing")

    def test_rejects_traversal_outside_scope_and_symlinks(self):
        outside = self.root / "private.md"
        outside.write_text(self.source)
        (self.vision / "linked.md").symlink_to(outside)
        for path in ("../private.md", "docs/vision/../../private.md", "docs/current/x.md", "docs/vision/linked.md"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                propose_refactor(path, root=self.root)

    def test_rejects_a_symlinked_vision_directory(self):
        external = self.root / 'external'
        external.mkdir()
        (external / 'example.md').write_text(self.source)
        linked_root = self.root / 'linked-root'
        (linked_root / 'docs').mkdir(parents=True)
        (linked_root / 'docs/vision').symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlinked'):
            propose_refactor('docs/vision/example.md', root=linked_root)

    def test_markup_in_heading_is_not_given_a_guessed_anchor(self):
        self.path.write_text("# Example\n## **Styled**\ntext\n## Second\ntext\n")
        with self.assertRaisesRegex(ValueError, "manual anchor review"):
            propose_refactor("docs/vision/example.md", root=self.root)

def _mid_write_failure_mock():
    """The final index replacement raises before any write happens."""
    return mock.patch("plan_refactor.os.replace", side_effect=OSError("disk had other plans"))


class RefactorApplyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.vision = self.root / "docs" / "vision"
        self.vision.mkdir(parents=True)
        self.path = self.vision / "example.md"
        self.source = ("# Example\n\nOwner decision.\n\n"
                       "## A first section\n\nKeep this exactly.\n\n"
                       "## A second section\n\nSecond body.\n")
        self.path.write_text(self.source)
        self.fresh = propose_refactor("docs/vision/example.md", root=self.root)
        self.request = {"path": "docs/vision/example.md", "proposal": self.fresh}
        self.backup = self.root / "backups"

    def test_apply_writes_sections_swaps_index_and_keeps_a_backup(self):
        result = apply_split(self.root, self.request, self.backup)
        self.assertTrue(result["ok"])
        self.assertEqual(result["sections_written"], 2)
        for section in self.fresh["sections"]:
            self.assertEqual((self.root / section["path"]).read_text(), section["content"])
        self.assertEqual(self.path.read_text(), self.fresh["index_preview"])
        self.assertEqual(result["index_sha256"], hashlib.sha256(self.path.read_bytes()).hexdigest())
        backup_path = self.root / result["backup"]
        self.assertEqual(backup_path.name, self.fresh["source_revision"] + "--split.md")
        self.assertEqual(backup_path.read_bytes(), self.source.encode("utf-8"))

    def test_restoring_the_backup_recovers_the_source_exactly(self):
        result = apply_split(self.root, self.request, self.backup)
        (self.root / result["backup"]).rename(self.path)
        self.assertEqual(self.path.read_text(), self.source)
        again = propose_refactor("docs/vision/example.md", root=self.root)
        self.assertEqual(again["source_revision"], self.fresh["source_revision"])
        self.assertEqual([s["content"] for s in again["sections"]],
                         [s["content"] for s in self.fresh["sections"]])

    def test_existing_destination_refuses_before_any_write(self):
        destination = self.vision / "example--01-a-first-section.md"
        destination.write_text("existing")
        before = sorted(p.name for p in self.vision.iterdir())
        with self.assertRaisesRegex(ValueError, "destination already exists"):
            apply_split(self.root, self.request, self.backup)
        self.assertEqual(sorted(p.name for p in self.vision.iterdir()), before)
        self.assertEqual(self.path.read_text(), self.source)
        self.assertFalse(destination.read_text() == "keep this exactly.\n")

    def test_stale_or_tampered_proposal_never_writes(self):
        before = sorted(p.name for p in self.vision.iterdir())
        stale = {"path": self.request["path"],
                 "proposal": dict(self.fresh, source_revision="0" * 64)}
        with self.assertRaisesRegex(ValueError, "Propose the split again"):
            apply_split(self.root, stale, self.backup)
        tampered = copy.deepcopy(self.request)
        tampered["proposal"]["sections"][0]["content"] += "\nDrifted."
        with self.assertRaisesRegex(ValueError, "Propose the split again"):
            apply_split(self.root, tampered, self.backup)
        indexdrift = copy.deepcopy(self.request)
        indexdrift["proposal"]["index_preview"] = "## rewritten"
        with self.assertRaisesRegex(ValueError, "Propose the split again"):
            apply_split(self.root, indexdrift, self.backup)
        self.assertEqual(sorted(p.name for p in self.vision.iterdir()), before)
        self.assertEqual(self.path.read_text(), self.source)

    def test_a_mid_write_failure_rolls_back_written_sections(self):
        with _mid_write_failure_mock():
            with self.assertRaisesRegex(ValueError, "left in place"):
                apply_split(self.root, self.request, self.backup)
        self.assertEqual(self.path.read_text(), self.source)
        leftovers = [p for p in self.vision.iterdir() if p.name != "example.md"]
        self.assertEqual(leftovers, [], "a partial split must not leave strays")

    def test_concurrent_destination_creation_is_never_overwritten(self):
        real_link = os.link
        destination = self.root / self.fresh['sections'][0]['path']
        def competing_link(source, target, **kwargs):
            destination.write_text('concurrent owner file')
            return real_link(source, target, **kwargs)
        with mock.patch('plan_refactor.os.link', side_effect=competing_link):
            with self.assertRaisesRegex(ValueError, 'left in place'):
                apply_split(self.root, self.request, self.backup)
        self.assertEqual(destination.read_text(), 'concurrent owner file')
        self.assertEqual(self.path.read_text(), self.source)

    def test_concurrent_source_change_aborts_and_preserves_modified_section(self):
        real_link = os.link
        counter = 0
        first_section = self.root / self.fresh['sections'][0]['path']
        def competing_link(source, target, **kwargs):
            nonlocal counter
            real_link(source, target, **kwargs)
            counter += 1
            if counter == 2:
                self.path.write_text('A simultaneous source edit')
                first_section.write_text('A simultaneous section edit')
        with mock.patch('plan_refactor.os.link', side_effect=competing_link):
            with self.assertRaisesRegex(ValueError, 'preserved'):
                apply_split(self.root, self.request, self.backup)
        self.assertEqual(self.path.read_text(), 'A simultaneous source edit')
        self.assertEqual(first_section.read_text(), 'A simultaneous section edit')
        self.assertFalse((self.root / self.fresh['sections'][1]['path']).exists())

    def test_symlinked_source_stays_out_of_reach(self):
        outside = self.root / "outside.md"
        outside.write_text(self.source)
        (self.vision / "linked.md").symlink_to(outside)
        with self.assertRaises(ValueError):
            apply_split(self.root, {"path": "docs/vision/linked.md", "proposal": {}}, self.backup)
        self.assertEqual(outside.read_text(), self.source)


if __name__ == "__main__":
    unittest.main()
