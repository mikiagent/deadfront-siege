"""Archive exclusion and explicit-search tests against temporary checkouts."""
import json
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import urlopen

import docs_wiki


class ArchivePolicyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.canon, self.archive = root / 'canon', root / 'archive'
        (self.canon / 'docs').mkdir(parents=True)
        (self.archive / 'docs').mkdir(parents=True)
        (self.canon / 'docs/current.md').write_text('# Current\nLive rule')
        (self.archive / 'docs/secret-history.md').write_text('# Old history\nForgotten creature example')
        (root / 'outside.md').write_text('# Outside\nprivate')
        (self.archive / 'docs/escape.md').symlink_to(root / 'outside.md')
        self.state_path = root / 'state.json'
        self.state = {'docs': {'main:docs/secret-history.md': {'notes': 'preserve'}}, 'tasks': [], 'dismissed': [], 'models': {}}
        self.state_path.write_text(json.dumps(self.state))
        self.patches = [patch.object(docs_wiki, 'ROOT', self.canon),
                        patch.object(docs_wiki, 'STATE_PATH', self.state_path),
                        patch.object(docs_wiki, 'main_root', return_value=self.archive),
                        patch.object(docs_wiki, 'seed_model_marks')]
        for p in self.patches:
            p.start()
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), docs_wiki.Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = 'http://127.0.0.1:%d' % self.server.server_port

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        for p in reversed(self.patches):
            p.stop()
        self.temp.cleanup()

    def get(self, path):
        with urlopen(self.base + path, timeout=5) as response:
            return response.read()

    def status(self, path, code):
        with self.assertRaises(HTTPError) as error:
            self.get(path)
        self.assertEqual(error.exception.code, code)
        error.exception.close()

    def test_index_and_state_do_not_enumerate_or_erase_history(self):
        before = self.state_path.read_bytes()
        with patch.object(docs_wiki, 'scan_line', wraps=docs_wiki.scan_line) as scan:
            index = json.loads(self.get('/api/index'))
            self.assertEqual(scan.call_count, 1)
            self.assertEqual(scan.call_args.args, (self.canon, 'canon'))
        self.assertEqual(set(index['docs']), {'canon:docs/current.md'})
        self.assertEqual(index['cross_line_diffs'], [])
        self.assertEqual(json.loads(self.get('/api/state')), self.state)
        self.assertEqual(self.state_path.read_bytes(), before)
        self.assertNotIn('secret-history', json.dumps(index))

    def test_explicit_archive_search_is_bounded_and_requires_query(self):
        result = json.loads(self.get('/api/archive/search?q=forgotten'))['results']
        self.assertEqual([r['key'] for r in result], ['main:docs/secret-history.md'])
        self.assertIn('Forgotten creature', result[0]['excerpt'])
        self.assertLessEqual(len(result[0]['excerpt']), 240)
        self.status('/api/archive/search', 400)
        self.status('/api/archive/search?q=' + 'x' * 201, 400)
        for i in range(55):
            (self.archive / 'docs' / ('match%02d.md' % i)).write_text('# Match\nneedle')
        matches = json.loads(self.get('/api/archive/search?q=needle'))['results']
        self.assertEqual(len(matches), 50)

    def test_explicit_read_rejects_traversal_and_symlink_escapes(self):
        url = '/api/doc?key=' + quote('main:docs/secret-history.md', safe='')
        self.assertIn('Forgotten creature', self.get(url).decode())
        for key in ('main:../outside.md', 'main:docs/escape.md', 'main:docs/missing.md',
                    'main:/etc/passwd', 'main:.git/config'):
            with self.subTest(key=key):
                self.status('/api/doc?key=' + quote(key, safe=''), 404)
        self.assertEqual(json.loads(self.get('/api/archive/search?q=private'))['results'], [])

    def test_brand_does_not_misclassify_vision_systems(self):
        self.assertEqual(docs_wiki.system_of('docs/vision/WildLandsMMO_Combat_Math.md', ''), 'Creatures, AI & combat')
        self.assertEqual(docs_wiki.system_of('docs/vision/WildLandsMMO_Crafting_Building_Math.md', ''), 'Crafting & cooking')
        self.assertEqual(docs_wiki.system_of('docs/vision/WildLandsMMO_Game_Vision.md', ''), 'Vision & PRDs')
        self.assertEqual(docs_wiki.system_of('docs/current/multiplayer-server.md', ''), 'Multiplayer & server')


if __name__ == '__main__':
    unittest.main()
