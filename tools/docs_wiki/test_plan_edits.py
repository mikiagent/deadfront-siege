import hashlib
import tempfile
import unittest
from pathlib import Path
from plan_edits import EditError, StaleEdit, apply_vision_edits

class PlanEditTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / 'docs/vision').mkdir(parents=True)
        self.doc = self.root / 'docs/vision/spec.md'
        self.doc.write_text('# Vision\nAlpha decision\nBeta decision\n')
        self.backup = self.root / 'backups'
        self.sha = hashlib.sha256(self.doc.read_bytes()).hexdigest()
        self.proposal = {'path':'docs/vision/spec.md','base_sha256':self.sha,
                         'edits':[{'old_text':'Alpha decision','new_text':'Revised decision'}]}
    def tearDown(self):
        self.tmp.cleanup()
    def run_edit(self, proposal=None):
        return apply_vision_edits(self.root, proposal or self.proposal, self.backup)
    def test_applies_only_reviewed_passage_and_keeps_original_backup(self):
        result = self.run_edit()
        self.assertEqual(self.doc.read_text(), '# Vision\nRevised decision\nBeta decision\n')
        self.assertEqual((self.backup / (self.sha + '.md')).read_text(), '# Vision\nAlpha decision\nBeta decision\n')
        self.assertEqual(result['sha256'], hashlib.sha256(self.doc.read_bytes()).hexdigest())
        with self.assertRaises(StaleEdit): self.run_edit()
    def test_rejects_stale_and_ambiguous_without_writing(self):
        self.doc.write_text('Alpha decision\nAlpha decision\n')
        self.proposal['base_sha256'] = hashlib.sha256(self.doc.read_bytes()).hexdigest()
        with self.assertRaises(StaleEdit): self.run_edit()
        self.assertFalse(self.backup.exists())
        self.assertEqual(self.doc.read_text(), 'Alpha decision\nAlpha decision\n')
    def test_rejects_overlap_traversal_and_symlink(self):
        self.proposal['edits'] = [{'old_text':'Alpha decision','new_text':'x'},{'old_text':'decision\nBeta','new_text':'y'}]
        with self.assertRaises(EditError): self.run_edit()
        self.proposal['path'] = 'docs/vision/../../outside.md'
        with self.assertRaises(EditError): self.run_edit()
        link = self.root / 'docs/vision/link.md'; link.symlink_to(self.doc)
        self.proposal['path'] = 'docs/vision/link.md'
        with self.assertRaises(EditError): self.run_edit()
        self.assertEqual(self.doc.read_text(), '# Vision\nAlpha decision\nBeta decision\n')

if __name__ == '__main__': unittest.main()
