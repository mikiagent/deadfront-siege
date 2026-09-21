/* DEADFRONT web diagnostics. Loaded before the Godot engine starts. */
(function () {
	'use strict';
	if (window.__deadfrontDiagnostics) return;
	const MAX_LINES = 200;
	const lines = [];
	let overlay;
	let body;
	function stringify(value) {
		if (value instanceof Error) return value.stack || value.message;
		if (typeof value === 'string') return value;
		try { return JSON.stringify(value); } catch (_) { return String(value); }
	}
	function ensureOverlay() {
		if (overlay || !document.body) return;
		overlay = document.createElement('section');
		overlay.id = 'deadfront-error-overlay';
		overlay.setAttribute('role', 'alert');
		overlay.style.cssText = 'display:none;position:fixed;z-index:2147483647;inset:0;background:#140b0df2;color:#ffe8e8;padding:max(16px,env(safe-area-inset-top)) 16px 16px;overflow:auto;font:13px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap';
		const heading = document.createElement('strong');
		heading.textContent = 'DEADFRONT hit an error';
		heading.style.cssText = 'display:block;font:700 18px/1.3 system-ui;margin-bottom:10px';
		body = document.createElement('div');
		const actions = document.createElement('div');
		actions.style.cssText = 'position:sticky;top:0;float:right;display:flex;gap:8px';
		const copy = document.createElement('button');
		copy.textContent = 'Copy log';
		copy.onclick = function () { navigator.clipboard && navigator.clipboard.writeText(lines.join('\n')); };
		const close = document.createElement('button');
		close.textContent = 'Hide';
		close.onclick = function () { overlay.style.display = 'none'; };
		for (const button of [copy, close]) button.style.cssText = 'min-height:44px;padding:8px 12px';
		actions.append(copy, close);
		overlay.append(actions, heading, body);
		document.body.appendChild(overlay);
	}
	function record(level, values, fatal) {
		const stamp = new Date().toISOString();
		const text = '[' + stamp + '] ' + level + ' ' + values.map(stringify).join(' ');
		lines.push(text);
		if (lines.length > MAX_LINES) lines.splice(0, lines.length - MAX_LINES);
		try { localStorage.setItem('deadfront.last-errors', lines.join('\n')); } catch (_) {}
		ensureOverlay();
		if (body) body.textContent = lines.join('\n');
		if (fatal && overlay) overlay.style.display = 'block';
	}
	for (const level of ['error', 'warn']) {
		const original = console[level].bind(console);
		console[level] = function (...args) {
			record('console.' + level, args, level === 'error');
			original(...args);
		};
	}
	window.addEventListener('error', function (event) {
		record('window.error', [event.message, event.filename + ':' + event.lineno + ':' + event.colno, event.error || ''], true);
	});
	window.addEventListener('unhandledrejection', function (event) {
		record('unhandledrejection', [event.reason], true);
	});
	document.addEventListener('webglcontextlost', function (event) {
		event.preventDefault();
		record('webglcontextlost', ['The graphics context was lost. Reload the page to recover.'], true);
	}, true);
	document.addEventListener('webglcontextrestored', function () {
		record('webglcontextrestored', ['Graphics context restored'], false);
	}, true);
	window.__deadfrontDiagnostics = {
		lines: lines,
		record: record,
		show: function () { ensureOverlay(); if (overlay) overlay.style.display = 'block'; },
		text: function () { return lines.join('\n'); }
	};
	window.addEventListener('DOMContentLoaded', ensureOverlay, { once: true });
})();
