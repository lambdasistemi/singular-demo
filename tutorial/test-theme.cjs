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
  const kit = path.join(home, `singular-${version.slice(1)}-x86_64-linux`);
  fs.mkdirSync(path.join(kit, 'bin'), { recursive: true });
  fs.writeFileSync(path.join(kit, 'bin/singular'), '#!/bin/sh\n', { mode: 0o755 });
  fs.writeFileSync(path.join(kit, '.verified'), 'UI-only fixture');
  const server = spawn(
    path.join(__dirname, '.venv/bin/python'),
    [path.join(__dirname, 'server.py')],
    { env: { ...process.env, HOME: home }, stdio: ['ignore', 'pipe', 'pipe'] },
  );
  let logs = '';
  server.stdout.on('data', (c) => (logs += c));
  server.stderr.on('data', (c) => (logs += c));
  let browser;
  try {
    let started = false;
    for (let i = 0; i < 100; i++) {
      try {
        if ((await fetch('http://127.0.0.1:8765/health')).ok) {
          started = true;
          break;
        }
      } catch {}
      await new Promise((r) => setTimeout(r, 100));
    }
    assert(started, `Server failed to start: ${logs}`);
    browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
    const shots = path.join(__dirname, 'screenshots');
    fs.mkdirSync(shots, { recursive: true });
    const luminance = (rgb) => {
      const [r, g, b] = rgb.match(/\d+/g).map(Number);
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };
    const seen = (page) =>
      page.evaluate(() => ({
        xterm: terminal.options.theme.background,
        pane: getComputedStyle(document.querySelector('.terminal-pane')).backgroundColor,
        label: document.querySelector('#theme-toggle').textContent,
      }));
    // light whatever the browser's own scheme is, because the page beside the terminal is light
    for (const scheme of ['light', 'dark']) {
      const context = await browser.newContext({
        viewport: { width: 1440, height: 1000 },
        colorScheme: scheme,
      });
      const page = await context.newPage();
      await page.goto('http://127.0.0.1:8765/');
      await page.waitForSelector('.xterm-screen');
      let s = await seen(page);
      assert(
        luminance(s.pane) > 128 && s.xterm === '#fbfcf8' && s.label === 'Dark terminal',
        `browser scheme ${scheme}: the terminal starts as ${JSON.stringify(s)}`,
      );
      await page.screenshot({ path: path.join(shots, `theme-light-${scheme}-browser.png`) });
      // the button switches it, the choice is kept over a reload, and the button switches it back
      await page.click('#theme-toggle');
      s = await seen(page);
      assert(
        luminance(s.pane) < 128 && s.xterm === '#101b1b' && s.label === 'Light terminal',
        `browser scheme ${scheme}: after the button ${JSON.stringify(s)}`,
      );
      await page.screenshot({ path: path.join(shots, `theme-dark-${scheme}-browser.png`) });
      await page.reload();
      await page.waitForSelector('.xterm-screen');
      s = await seen(page);
      assert(
        luminance(s.pane) < 128 && s.xterm === '#101b1b',
        `browser scheme ${scheme}: after a reload ${JSON.stringify(s)}`,
      );
      await page.click('#theme-toggle');
      s = await seen(page);
      assert(
        luminance(s.pane) > 128 && s.xterm === '#fbfcf8',
        `browser scheme ${scheme}: after the second click ${JSON.stringify(s)}`,
      );
      await context.close();
    }
    console.log(
      'Theme checks passed: the terminal is light by default whatever the scheme of the browser, the button switches it to dark and back, and the choice survives a reload.',
    );
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
