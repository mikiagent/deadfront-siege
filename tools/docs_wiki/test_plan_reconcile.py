"""Plan analysis must be source-backed, read-only, and fail closed."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import plan_reconcile as plan


class ReconcileTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ('docs/current', 'docs/vision', 'docs/archive'):
            (self.root / directory).mkdir(parents=True)
        self.vision = '# Vision\n\n## Taming\nTaming requires a pen.\n'
        self.current = '# Current\n\n## Taming\nTaming currently uses a pen.\n'
        (self.root / 'docs/vision/animals.md').write_text(self.vision)
        (self.root / 'docs/current/animals.md').write_text(self.current)
        (self.root / 'docs/archive/secret.md').write_text('UNIQUE_ARCHIVE_TOKEN')
        self.citation = {'path':'docs/vision/animals.md', 'line_start':4, 'line_end':4, 'excerpt':'Taming requires a pen.'}
        self.question = {'id':'q1', 'question':'Should the pen remain required?', 'reason':'Your plan changes the approved rule.', 'sources':[self.citation]}
        self.edit = {'path':'docs/vision/animals.md', 'reason':'Owner agreed.', 'edits':[{'old_text':'Taming requires a pen.', 'new_text':'Taming uses a field kit.'}]}

    def test_questions_have_verified_citations_and_never_include_applyable_edits(self):
        def fake(prompt):
            self.assertNotIn('UNIQUE_ARCHIVE_TOKEN', prompt)
            self.assertIn('docs/current/animals.md', prompt)
            self.assertIn('docs/vision/animals.md', prompt)
            return json.dumps({'questions':[self.question], 'edits':[self.edit], 'notes':[]})
        result = plan.analyze('Taming should use a field kit.', root=self.root, runner=fake)
        self.assertEqual(result['questions'][0]['sources'], [self.citation])
        self.assertEqual(result['edits'], [])
        self.assertEqual((self.root / 'docs/vision/animals.md').read_text(), self.vision)

    def test_owner_answer_reanalysis_preserves_exact_source_and_sha(self):
        answers = [{'question_id':'q1','question':'Should the pen remain required?', 'answer':'No, use a field kit.'}]
        def fake(prompt):
            self.assertIn('No, use a field kit.', prompt)
            return json.dumps({'questions':[], 'edits':[self.edit], 'notes':[]})
        result = plan.analyze('Taming should use a field kit.', answers, root=self.root, runner=fake)
        change = result['edits'][0]
        self.assertEqual(change['base_sha256'], hashlib.sha256(self.vision.encode()).hexdigest())
        self.assertEqual(change['edits'][0]['line_start'], 4)
        self.assertEqual(change['edits'][0]['old_text'], 'Taming requires a pen.')
        self.assertEqual((self.root / 'docs/vision/animals.md').read_text(), self.vision)

    def test_unverifiable_citation_is_rejected(self):
        bad = dict(self.question, sources=[dict(self.citation, excerpt='Invented evidence')])
        with self.assertRaises(plan.PlanError):
            plan.analyze('Taming', root=self.root, runner=lambda _: json.dumps({'questions':[bad], 'edits':[], 'notes':[]}))

    def test_fabricated_or_out_of_scope_edits_are_rejected(self):
        for edit in [dict(self.edit, path='docs/current/animals.md'), dict(self.edit, edits=[{'old_text':'not in source', 'new_text':'x'}]), dict(self.edit, path='docs/archive/secret.md')]:
            with self.subTest(edit=edit), self.assertRaises(plan.PlanError):
                plan.analyze('Taming', root=self.root, runner=lambda _: json.dumps({'questions':[], 'edits':[edit], 'notes':[]}))

    def test_invalid_inputs_and_invalid_model_output_fail(self):
        for text in ('', 'x' * 100_001):
            with self.assertRaises(plan.PlanError): plan.analyze(text, root=self.root, runner=lambda _: '{}')
        with self.assertRaises(plan.PlanError): plan.analyze('Taming', [{'question':'q', 'answer':''}], root=self.root, runner=lambda _: '{}')
        with self.assertRaises(plan.PlanError): plan.analyze('Taming', root=self.root, runner=lambda _: 'not json')

    def test_readme_match_alone_does_not_claim_relevance(self):
        (self.root / 'docs/vision/README.md').write_text('# Index\n\nAquatic vessels.\n')
        with self.assertRaisesRegex(plan.PlanError, 'system name'):
            plan.analyze('Aquatic vessels', root=self.root, runner=lambda _: '{}')

    def test_structure_suggestion_requires_a_real_supplied_range(self):
        suggestion = {'path':'docs/vision/animals.md', 'line_start':4, 'line_end':4, 'reason':'Consider moving this to a taming section.'}
        value = {'questions':[], 'edits':[], 'notes':[], 'structure_suggestions':[suggestion]}
        result = plan.analyze('Taming', root=self.root, runner=lambda _: json.dumps(value))
        self.assertIn('docs/vision/animals.md:4-4', result['structure_suggestions'][0])
        suggestion['line_end'] = 999
        with self.assertRaises(plan.PlanError): plan.analyze('Taming', root=self.root, runner=lambda _: json.dumps(value))

    def test_crlf_revision_is_the_exact_source_bytes(self):
        path = self.root / 'docs/vision/animals.md'
        path.write_bytes(self.vision.replace('\n', '\r\n').encode())
        result = plan.analyze('Taming', root=self.root, runner=lambda _: json.dumps({'questions':[], 'edits':[self.edit], 'notes':[]}))
        self.assertEqual(result['edits'][0]['base_sha256'], hashlib.sha256(path.read_bytes()).hexdigest())

    def test_provider_is_isolated_and_all_permissions_denied(self):
        class Process:
            returncode = 0
            stdout = json.dumps({'type':'text','part':{'text':'{}'}}) + '\n'
            stderr = ''
        def fake_run(args, **kwargs):
            self.assertEqual(kwargs['input'], 'private plan')
            self.assertNotIn('private plan', args)
            config = json.loads(kwargs['env']['OPENCODE_CONFIG_CONTENT'])
            self.assertEqual(config['permission']['*'], 'deny')
            self.assertEqual(config['agent']['reconcile']['permission']['*'], 'deny')
            self.assertEqual(kwargs['env']['OPENCODE_DISABLE_PROJECT_CONFIG'], 'true')
            self.assertNotEqual(kwargs['env']['XDG_DATA_HOME'], str(Path.home() / '.local/share'))
            self.assertEqual(kwargs['cwd'], str(Path(kwargs['env']['XDG_DATA_HOME']).parent))
            return Process()
        with patch.object(plan.OPENCODE.__class__, 'is_file', return_value=True), patch.object(plan.subprocess, 'run', side_effect=fake_run):
            self.assertEqual(plan._run_model('private plan'), '{}')

    def test_provider_limit_is_an_explicit_failure(self):
        class Process:
            returncode = 1
            stdout = json.dumps({'type':'error','error':{'type':'provider.free-limit'}}) + '\n'
            stderr = ''
        with patch.object(plan.OPENCODE.__class__, 'is_file', return_value=True), patch.object(plan.subprocess, 'run', return_value=Process()):
            with self.assertRaisesRegex(plan.ProviderUnavailable, 'limit reached'):
                plan._run_model('private plan')

if __name__ == '__main__':
    unittest.main()
