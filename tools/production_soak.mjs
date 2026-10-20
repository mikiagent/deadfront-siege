#!/usr/bin/env node
/** Run the deployed web build through its deterministic soak route.
 * Usage: npm --prefix tools/web_soak install && node tools/production_soak.mjs [URL] [--expect-stamp=<commit>/<pack>]
 * The URL must serve a WebSoak build (tools/export_web.sh --soak): release builds carry no soak route.
 * PASS needs '[soak] PASS', no error line, no black checkpoint frame, the in-game '[soak] stamp'
 * equal to the expected stamp (flag or EXPECTED_STAMP; without one the stamp is only printed),
 * a requestAnimationFrame p95 at or under RAF_P95_MS (default 100 ms) once the route runs, and no
 * stall: no frame over RAF_MAX_MS (default 250 ms) while playing, none over RAF_LOAD_MAX_MS
 * (default 8000 ms) while an island loads (the route prints '[soak] loading <id>' before each travel).
 * Release scripts should pass the stamp they just built (EXPECTED_STAMP), or a stale cache passes.
 */
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from './web_soak/node_modules/playwright-core/index.mjs';

const flags = process.argv.slice(2);
const base = flags.find(a => !a.startsWith('--')) || process.env.DEADFRONT_URL || 'https://durango-like.vercel.app/';
const expectStamp = (flags.find(a => a.startsWith('--expect-stamp=')) || '').slice(15) || process.env.EXPECTED_STAMP || '';
// Loose on purpose: catches stalls and a stuck renderer, not a 60 fps target (headless Chrome has no GPU).
const rafBudgetMs = Number(process.env.RAF_P95_MS || 100);
const rafMaxMs = Number(process.env.RAF_MAX_MS || 250);
// shortcut: island travel still loads on the main thread, so a load freeze gets its own looser cap; tighten when W1-WEB streams islands.
const rafLoadMaxMs = Number(process.env.RAF_LOAD_MAX_MS || 8000);
const url = new URL(base);
url.searchParams.set('soak', '1');
const out = path.resolve(process.env.SOAK_ARTIFACTS || 'artifacts/web-soak');
fs.mkdirSync(out, { recursive: true });
const log = [];
const executablePath = process.env.CHROME_PATH || ['/usr/bin/google-chrome', '/usr/bin/chromium', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'].find(fs.existsSync);
const browser = await chromium.launch({ headless: true, executablePath });
const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1, isMobile: false, hasTouch: false });
// Frame deltas start at the first soak checkpoint, so page load and pack streaming do not count.
await page.addInitScript(() => {
  window.__soakRaf = { on: false, seg: 'play', deltas: [], load: [] };
  let last = 0;
  const tick = t => {
    const r = window.__soakRaf;
    if (r.on && last) (r.seg === 'load' ? r.load : r.deltas).push(t - last);
    last = t; requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
});
let failure = '';
let stamp = '';
let checkpoint = 0;
let mainReadyAt = 0;
function writeLog() { fs.writeFileSync(path.join(out, 'console.log'), log.join('\n') + '\n'); }
page.on('console', async msg => {
  const line = `[console.${msg.type()}] ${msg.text()}`;
  log.push(line);
  console.log(line);
  if (line.includes('[boot] main scene ready')) mainReadyAt ||= Date.now();
  const st = line.match(/\[soak\] stamp (\S+)/);
  if (st) {
    stamp = st[1];
    if (expectStamp && stamp !== expectStamp) failure ||= `stamp ${stamp} is not the expected ${expectStamp}`;
  }
  if (/\[soak\] loading /.test(line)) await page.evaluate(() => { window.__soakRaf.seg = 'load'; }).catch(() => {});
  if (/\[soak\] checkpoint /.test(line)) {
    checkpoint += 1;
    await page.evaluate(() => { window.__soakRaf.on = true; window.__soakRaf.seg = 'play'; }).catch(() => {});
    await inspectFrame(`checkpoint-${String(checkpoint).padStart(2, '0')}`, checkpoint === 1 || checkpoint === 2);
  }
  const click = line.match(/\[soak\] desktop_click_norm ([0-9.-]+) ([0-9.-]+)/);
  if (click) {
    const nx = Number(click[1]), ny = Number(click[2]);
    const canvas = page.locator('canvas');
    const box = await canvas.boundingBox();
    if (!box || nx < 0 || nx > 1 || ny < 0 || ny > 1) failure ||= `invalid desktop click projection: ${nx},${ny}`;
    else await page.mouse.click(box.x + nx * box.width, box.y + ny * box.height);
  }
  if (/\[soak\] FAIL|SCRIPT ERROR|Parse Error|WebGL context lost/i.test(line)) failure ||= line;
});
page.on('pageerror', err => { const line = `[pageerror] ${err.stack || err}`; log.push(line); failure ||= line; });
page.on('crash', () => { log.push('[page-crash] renderer crashed'); failure ||= 'renderer crashed'; });
async function inspectFrame(label, capture = false) {
  const stats = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas || !canvas.width || !canvas.height) return { black: true, reason: 'missing canvas' };
    const sample = document.createElement('canvas'); sample.width = 64; sample.height = 64;
    const ctx = sample.getContext('2d', { willReadFrequently: true });
    try { ctx.drawImage(canvas, 0, 0, 64, 64); } catch (e) { return { black: true, reason: String(e) }; }
    const data = ctx.getImageData(0, 0, 64, 64).data;
    let lit = 0, alpha = 0;
    for (let i = 0; i < data.length; i += 4) { if (data[i] > 8 || data[i+1] > 8 || data[i+2] > 8) lit++; if (data[i+3]) alpha++; }
    return { black: lit < 12, lit, alpha, width: canvas.width, height: canvas.height };
  });
  log.push(`[frame] ${label} ${JSON.stringify(stats)}`);
  if (capture || stats.black) await page.screenshot({ path: path.join(out, `${label}.png`) });
  if (stats.black) failure ||= `all-black frame at ${label}: ${JSON.stringify(stats)}`;
}
try {
  await page.goto(url.href, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  await page.waitForFunction(() => window.__deadfrontDiagnostics, null, { timeout: 10_000 });
  const deadline = Date.now() + 360_000;
  while (!failure && Date.now() < deadline && !log.some(line => line.includes('[soak] PASS'))) {
    await page.waitForTimeout(1000);
    // Release exports drop scripts/dev and the ?soak=1 hook (W1-WEB): say so instead of timing out.
    if (mainReadyAt && Date.now() - mainReadyAt > 60_000 && !log.some(line => line.includes('[soak] start')))
      failure = 'no [soak] start 60 s after the main scene: this build has no soak route (release exports strip it; soak a tools/export_web.sh --soak build)';
  }
  if (!failure && !log.some(line => line.includes('[soak] PASS'))) failure = 'timed out waiting for [soak] PASS';
  if (!failure && !stamp) failure = 'no [soak] stamp line: cannot tell which build was tested';
  const raf = await page.evaluate(() => {
    const d = [...window.__soakRaf.deltas].sort((a, b) => a - b);
    const l = window.__soakRaf.load;
    return { n: d.length, p50: d[Math.floor(d.length * 0.5)] || 0, p95: d[Math.floor(d.length * 0.95)] || 0, max: d[d.length - 1] || 0,
      long: d.filter(x => x > 250).length, loadN: l.length, loadMax: l.length ? Math.max(...l) : 0 };
  }).catch(() => ({ n: 0, p50: 0, p95: 0, max: 0, long: 0, loadN: 0, loadMax: 0 }));
  const perfLine = `[perf] raf_frames=${raf.n} raf_p50_ms=${raf.p50.toFixed(1)} raf_p95_ms=${raf.p95.toFixed(1)} raf_max_ms=${raf.max.toFixed(1)} frames_over_250ms=${raf.long} load_frames=${raf.loadN} load_max_ms=${raf.loadMax.toFixed(1)} budget_p95_ms=${rafBudgetMs} budget_max_ms=${rafMaxMs} budget_load_max_ms=${rafLoadMaxMs}`;
  log.push(perfLine);
  console.log(perfLine);
  if (!failure && raf.n < 30) failure = `only ${raf.n} animation frames recorded`;
  if (!failure && raf.p95 > rafBudgetMs) failure = `rAF p95 ${raf.p95.toFixed(1)} ms over the ${rafBudgetMs} ms budget`;
  if (!failure && raf.max > rafMaxMs) failure = `stall: a ${raf.max.toFixed(0)} ms frame while playing (budget ${rafMaxMs} ms, ${raf.long} frames over 250 ms)`;
  if (!failure && raf.loadMax > rafLoadMaxMs) failure = `stall: a ${raf.loadMax.toFixed(0)} ms frame while an island loaded (budget ${rafLoadMaxMs} ms)`;
  const diagnostics = await page.evaluate(() => window.__deadfrontDiagnostics?.text() || '').catch(() => '');
  fs.writeFileSync(path.join(out, 'diagnostics.log'), diagnostics);
} finally {
  writeLog();
  await browser.close();
}
if (failure) { console.error(`SOAK FAIL: ${failure}\nArtifacts: ${out}`); process.exit(1); }
console.log(`SOAK PASS (${checkpoint} checkpoints, stamp ${stamp}${expectStamp ? ' as expected' : ', not checked: pass --expect-stamp'})\nArtifacts: ${out}`);
