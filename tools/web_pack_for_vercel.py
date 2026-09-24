#!/usr/bin/env python3
"""Split Godot's index.pck into <100 MB parts so Vercel Hobby can host it.

Godot's loader expects one file named index.pck. We download the parts in the
browser, concatenate them, and preload the buffer as index.pck.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys

CHUNK = 16 * 1024 * 1024  # keep fallback buffers small on memory-constrained mobile browsers

LOADER = r'''
(function (engine) {
	if (engine.__durangoPckLoader) {
		return;
	}
	engine.__durangoPckLoader = true;
	engine.startGame = function (override) {
		this.config.update(override);
		const exe = this.config.executable;
		const pack = this.config.mainPack || (exe + '.pck');
		this.config.args = ['--main-pack', pack].concat(this.config.args);
		const me = this;
		const onProgress = this.config.onProgress;
		const loadParts = fetch('pack.manifest.json', { cache: 'no-store' }).then(function (r) {
			if (!r.ok) {
				throw new Error('Missing pack.manifest.json');
			}
			return r.json();
		}).then(function (man) {
			let loaded = 0;
			const out = new Uint8Array(man.size);
			function reportProgress() {
				if (onProgress) {
					onProgress(loaded, man.size);
				}
			}
			// One dropped fetch used to kill the whole multi-part load. Retry each part up to
			// three times, rewinding to the part's start offset so partial bytes are overwritten.
			function fetchPart(part, attempt) {
				const start = loaded;
				return downloadPart(part).catch(function (err) {
					if (attempt >= 3) {
						throw err;
					}
					loaded = start;
					reportProgress();
					console.warn('Retrying ' + part + ' (attempt ' + (attempt + 1) + ' of 3): ' + err);
					return new Promise(function (resolve) {
						setTimeout(resolve, 1000 * attempt);
					}).then(function () {
						return fetchPart(part, attempt + 1);
					});
				});
			}
			function downloadPart(part) {
					return fetch(part).then(function (res) {
						if (!res.ok) {
							throw new Error('Failed to download ' + part + ' (' + res.status + ')');
						}
						if (!res.body || !res.body.getReader) {
							return res.arrayBuffer().then(function (buf) {
								const bytes = new Uint8Array(buf);
								out.set(bytes, loaded);
								loaded += bytes.byteLength;
								reportProgress();
							});
						}
						const reader = res.body.getReader();
						function pump() {
							return reader.read().then(function (result) {
								if (result.done) {
									return;
								}
								if (loaded + result.value.byteLength > out.byteLength) {
									throw new Error('Downloaded pack is larger than its manifest');
								}
								out.set(result.value, loaded);
								loaded += result.value.byteLength;
								reportProgress();
								return pump();
							});
						}
						return pump();
					});
			}
			return man.parts.reduce(function (p, part) {
				return p.then(function () {
					return fetchPart(part, 1);
				});
			}, Promise.resolve()).then(function () {
				if (loaded !== man.size) {
					throw new Error('Downloaded pack size mismatch (' + loaded + ' of ' + man.size + ' bytes)');
				}
				return me.preloadFile(out.buffer, pack);
			});
		});
		return Promise.all([me.init(exe), loadParts]).then(function () {
			return me.start();
		});
	};
})(engine);
'''


def split_pck(out: pathlib.Path) -> list[str]:
    pck = out / 'index.pck'
    if not pck.is_file():
        manifest = out / 'pack.manifest.json'
        if manifest.is_file():
            data = json.loads(manifest.read_text())
            return list(data['parts'])
        raise SystemExit(f'missing {pck}')
    raw = pck.read_bytes()
    # Content-hashed part names: the parts can be cached forever, and a new build never
    # collides with what a browser (or Vercel's edge) still holds from the previous one.
    digest = hashlib.sha1(raw).hexdigest()[:10]
    for old in out.glob('pack.*.bin'):
        old.unlink()
    parts: list[str] = []
    offset = 0
    idx = 0
    while offset < len(raw):
        name = f'pack.{digest}.{idx:02d}.bin'
        (out / name).write_bytes(raw[offset:offset + CHUNK])
        parts.append(name)
        idx += 1
        offset += CHUNK
    (out / 'pack.manifest.json').write_text(json.dumps({
        'parts': parts,
        'size': len(raw),
        'virtual': 'index.pck',
    }, indent=2) + '\n')
    pck.unlink()
    print(f'split index.pck ({len(raw) / (1024*1024):.1f} MB) into {len(parts)} parts')
    return parts


def patch_html(out: pathlib.Path) -> None:
    html_path = out / 'index.html'
    html = html_path.read_text()
    if 'pack.manifest.json' in html:
        return
    needle = 'const engine = new Engine(GODOT_CONFIG);'
    if needle not in html:
        raise SystemExit('index.html has no Engine(GODOT_CONFIG) hook')
    html = html.replace(needle, needle + '\n' + LOADER, 1)
    html_path.write_text(html)
    print('patched index.html pck loader')


STUB_SW = """// Stub: the PWA service worker is disabled; this one evicts the old cached app from
// browsers that still run the previous worker, then unregisters itself.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
	event.waitUntil(caches.keys().then(function (keys) {
		return Promise.all(keys.map(function (k) { return caches.delete(k); }));
	}).then(function () { return self.registration.unregister(); }).then(function () {
		return self.clients.matchAll({ type: 'window' });
	}).then(function (clients) { clients.forEach(function (c) { c.navigate(c.url); }); }));
});
"""



def install_diagnostics(out: pathlib.Path) -> None:
    """Install diagnostics before Engine construction and expose the opt-in soak arg."""
    source = pathlib.Path(__file__).with_name('web_diagnostics.js')
    if not source.is_file():
        raise SystemExit(f'missing {source}')
    (out / 'web_diagnostics.js').write_text(source.read_text())
    html_path = out / 'index.html'
    html = html_path.read_text()
    marker = '<script src="web_diagnostics.js"></script>'
    if marker not in html:
        needle = '<script src="index.js"></script>'
        if needle not in html:
            raise SystemExit('index.html has no index.js script hook')
        html = html.replace(needle, marker + '\n' + needle, 1)
    config_needle = 'const engine = new Engine(GODOT_CONFIG);'
    soak_hook = "if (new URLSearchParams(location.search).get('soak') === '1' && !GODOT_CONFIG.args.includes('--web-soak')) GODOT_CONFIG.args.push('--', '--web-soak');"
    if soak_hook not in html:
        if config_needle not in html:
            raise SystemExit('index.html has no Engine(GODOT_CONFIG) hook')
        html = html.replace(config_needle, soak_hook + '\n' + config_needle, 1)
    html_path.write_text(html)
    print('installed web crash diagnostics and soak hook')


def patch_service_worker(out: pathlib.Path, parts: list[str]) -> None:
    sw = out / 'index.service.worker.js'
    if not sw.is_file():
        sw.write_text(STUB_SW)
        print('wrote stub service worker (unregisters the old PWA cache)')
        return
    text = sw.read_text()
    quoted = ','.join(json.dumps(p) for p in (['index.wasm'] + parts))
    text2, n = re.subn(
        r'const CACHEABLE_FILES = \[[^\]]*\];',
        f'const CACHEABLE_FILES = [{quoted}];',
        text,
        count=1,
    )
    if n != 1:
        print('WARN could not patch service worker CACHEABLE_FILES')
        return
    sw.write_text(text2)
    print('patched service worker cache list')


def report(out: pathlib.Path) -> None:
    files = sorted(p for p in out.iterdir() if p.is_file())
    total = sum(p.stat().st_size for p in files)
    limit = 100 * 1024 * 1024
    print(f'total {total / (1024*1024):.1f} MB')
    over = [p for p in files if p.stat().st_size > limit]
    if over:
        print('ERROR files still over Vercel Hobby 100 MB limit:')
        for p in over:
            print(f'  {p.name} {p.stat().st_size / (1024*1024):.1f} MB')
        raise SystemExit(2)
    print('all files under Vercel Hobby 100 MB per-file limit')
    for p in files:
        if p.suffix in {'.bin', '.wasm', '.json'} or p.name.startswith('pack.'):
            print(f'  {p.name:24s} {p.stat().st_size / (1024*1024):6.1f} MB')


def main() -> None:
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    parts = split_pck(out)
    patch_html(out)
    install_diagnostics(out)
    patch_service_worker(out, parts)
    report(out)


if __name__ == '__main__':
    main()
