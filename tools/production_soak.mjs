#!/usr/bin/env node
/** Run the deployed web build through its deterministic soak route.
 * Usage: npm --prefix tools/web_soak install && node tools/production_soak.mjs [URL]
 */
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from './web_soak/node_modules/playwright-core/index.mjs';

const base = process.argv[2] || process.env.DEADFRONT_URL || 'https://durango-like.vercel.app/';
const url = new URL(base);
url.searchParams.set('soak', '1');
const out = path.resolve(process.env.SOAK_ARTIFACTS || 'artifacts/web-soak');
fs.mkdirSync(out, { recursive: true });
const log = [];
const executablePath = process.env.CHROME_PATH || ['/usr/bin/google-chrome', '/usr/bin/chromium', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'].find(fs.existsSync);
const browser = await chromium.launch({ headless: true, executablePath });
const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1, isMobile: false, hasTouch: false });
let failure = '';
let checkpoint = 0;
function writeLog() { fs.writeFileSync(path.join(out, 'console.log'), log.join('\n') + '\n'); }
page.on('console', async msg => {
  const line = `[console.${msg.type()}] ${msg.text()}`;
  log.push(line);
  console.log(line);
  if (/\[soak\] checkpoint /.test(line)) {
    checkpoint += 1;
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
  }
  if (!failure && !log.some(line => line.includes('[soak] PASS'))) failure = 'timed out waiting for [soak] PASS';
  const diagnostics = await page.evaluate(() => window.__deadfrontDiagnostics?.text() || '').catch(() => '');
  fs.writeFileSync(path.join(out, 'diagnostics.log'), diagnostics);
} finally {
  writeLog();
  await browser.close();
}
if (failure) { console.error(`SOAK FAIL: ${failure}\nArtifacts: ${out}`); process.exit(1); }
console.log(`SOAK PASS (${checkpoint} checkpoints)\nArtifacts: ${out}`);
