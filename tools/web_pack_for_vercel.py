#!/usr/bin/env python3
"""Split Godot's index.pck into <100 MB parts so Vercel Hobby can host it.

Godot's loader expects one file named index.pck. We download the parts in the
browser, concatenate them, and preload the buffer as index.pck.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

CHUNK = 90 * 1024 * 1024  # stay under Vercel Hobby's 100 MB per-file cap

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
			const pieces = [];
			return man.parts.reduce(function (p, part) {
				return p.then(function () {
					return fetch(part).then(function (res) {
						if (!res.ok) {
							throw new Error('Failed to download ' + part + ' (' + res.status + ')');
						}
						return res.arrayBuffer();
					}).then(function (buf) {
						loaded += buf.byteLength;
						if (onProgress) {
							onProgress(loaded, man.size);
						}
						pieces.push(new Uint8Array(buf));
					});
				});
			}, Promise.resolve()).then(function () {
				const out = new Uint8Array(man.size);
				let off = 0;
				for (let i = 0; i < pieces.length; i++) {
					out.set(pieces[i], off);
					off += pieces[i].byteLength;
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
    parts: list[str] = []
    offset = 0
    idx = 0
    while offset < len(raw):
        name = f'pack.{idx:02d}.bin'
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


def patch_service_worker(out: pathlib.Path, parts: list[str]) -> None:
    sw = out / 'index.service.worker.js'
    if not sw.is_file():
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
    patch_service_worker(out, parts)
    report(out)


if __name__ == '__main__':
    main()
