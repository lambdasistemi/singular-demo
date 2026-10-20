// The terminal follows the browser's theme: a light terminal for a light theme, a dark one for a dark theme.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { chromium } = require('playwright');

(async () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'singular-theme-'));
  const version = require(path.join(__dirname, '..', 'demos/demo1/version.js'));
  const kit = path.join(home, `singular-demo-${version}-x86_64-linux`);
  fs.mkdirSync(path.join(kit, 'bin'), { recursive: true });
  fs.writeFileSync(path.join(kit, 'bin/singular'), '#!/bin/sh\n', { mode: 0o755 });
  fs.writeFileSync(path.join(kit, '.verified'), 'UI-only fixture');
  const server = spawn(path.join(__dirname, '.venv/bin/python'), [path.join(__dirname, 'server.py')], { env: { ...process.env, HOME: home }, stdio: ['ignore', 'pipe', 'pipe'] });
  let logs = '';
  server.stdout.on('data', (c) => logs += c);
  server.stderr.on('data', (c) => logs += c);
  let browser;
  try {
    let started = false;
    for (let i = 0; i < 100; i++) {
      try { if ((await fetch('http://127.0.0.1:8765/health')).ok) { started = true; break; } } catch {}
      await new Promise((r) => setTimeout(r, 100));
    }
    assert(started, `Server failed to start: ${logs}`);
    browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
    const shots = path.join(__dirname, 'screenshots');
    fs.mkdirSync(shots, { recursive: true });
    const luminance = (rgb) => { const [r, g, b] = rgb.match(/\d+/g).map(Number); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
    for (const scheme of ['light', 'dark']) {
      const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, colorScheme: scheme });
      await page.goto('http://127.0.0.1:8765/');
      await page.waitForSelector('.xterm-screen');
      await page.waitForFunction(() => document.querySelector('#connection')?.textContent !== 'Connecting…', null, { timeout: 15000 }).catch(() => {});
      const seen = await page.evaluate(() => ({
        xterm: terminal.options.theme.background,
        pane: getComputedStyle(document.querySelector('.terminal-pane')).backgroundColor,
        screen: getComputedStyle(document.querySelector('.xterm-screen')).backgroundColor,
      }));
      const wantLight = scheme === 'light';
      assert.equal(luminance(seen.pane) > 128, wantLight, `${scheme}: the terminal pane is ${seen.pane}`);
      assert.equal(seen.xterm === '#fbfcf8', wantLight, `${scheme}: the xterm palette background is ${seen.xterm}`);
      // a change of the browser's theme while the page is open is followed too
      const other = wantLight ? 'dark' : 'light';
      await page.emulateMedia({ colorScheme: other });
      const after = await page.evaluate(() => terminal.options.theme.background);
      assert.equal(after === '#fbfcf8', !wantLight, `${scheme} -> ${other}: the xterm palette background is ${after}`);
      await page.emulateMedia({ colorScheme: scheme });
      await page.screenshot({ path: path.join(shots, `theme-${scheme}.png`) });
      await page.close();
    }
    console.log('Theme checks passed: a light terminal for a light theme, a dark one for a dark theme, and a live change is followed.');
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
  }
})().catch((error) => { console.error(error); process.exit(1); });
