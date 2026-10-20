const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { chromium } = require('playwright');

(async () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'singular-browser-'));
  const version = require(path.join(__dirname, '..', 'demos/demo1/version.js'));
  const kit = path.join(home, `singular-${version.slice(1)}-x86_64-linux`);
  fs.mkdirSync(path.join(kit, 'bin'), { recursive: true });
  fs.writeFileSync(path.join(kit, 'bin/singular'), '#!/bin/sh\n', { mode: 0o755 });
  fs.writeFileSync(path.join(kit, '.verified'), 'UI-only fixture');
  const server = spawn(
    path.join(__dirname, '.venv/bin/python'),
    [path.join(__dirname, 'server.py')],
    {
      env: { ...process.env, HOME: home },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );
  let logs = '';
  server.stdout.on('data', (chunk) => (logs += chunk));
  server.stderr.on('data', (chunk) => (logs += chunk));
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
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert(started, `Server failed to start: ${logs}`);
    browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    const errors = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.goto('http://127.0.0.1:8765');
    const ready = () =>
      page.waitForFunction(() => document.querySelector('#connection').textContent === '● Ready');
    const terminalText = () =>
      page.evaluate(() =>
        Array.from({ length: terminal.buffer.active.length }, (_, i) =>
          terminal.buffer.active.getLine(i).translateToString(),
        ).join('\n'),
      );
    const outputContains = (value) =>
      page.waitForFunction(
        (value) =>
          Array.from({ length: terminal.buffer.active.length }, (_, i) =>
            terminal.buffer.active.getLine(i).translateToString(),
          )
            .join('\n')
            .includes(value),
        value,
      );
    await ready();
    assert.equal(await page.locator('#lessons button').count(), 25);
    assert.equal(await page.locator('.run-command').count(), 1);
    const run = page.getByRole('button', { name: 'Run in terminal', exact: true });
    assert.equal(await run.locator('svg').count(), 1);
    assert.equal(await run.textContent(), '');
    const preBox = await page.locator('.command pre').boundingBox();
    const controlBox = await run.boundingBox();
    assert(controlBox.x >= preBox.x + preBox.width, 'Controls must sit beside code');
    await run.click();
    await outputContains('Alice, Bob and chain windows are ready.');
    await ready();
    const type = async (command) => {
      await page.locator('.xterm-helper-textarea').fill(command);
      await page.locator('.xterm-helper-textarea').press('Enter');
    };
    await type(
      "export learner='Cardano explorer'; mkdir -p ~/tutorial-playground; cd ~/tutorial-playground",
    );
    await ready();
    await type('printf "Welcome, %s\\n" "$learner"');
    await outputContains('Welcome, Cardano explorer');
    await ready();
    await type(
      // biome-ignore lint/suspicious/noTemplateCurlyInString: a shell expansion typed into the terminal, not a template
      "read -r -s -p 'Type a throwaway word: ' practice; printf '\\nReceived %s characters.\\n' \"${#practice}\"; unset practice",
    );
    // Wait for the actual prompt, not its occurrence in the echoed read command.
    await page.waitForFunction(() =>
      Array.from({ length: terminal.buffer.active.length }, (_, i) =>
        terminal.buffer.active.getLine(i).translateToString().trim(),
      ).includes('Type a throwaway word:'),
    );
    await page.waitForFunction(() => document.querySelector('.run-command').disabled);
    await type('testing-secret');
    await outputContains('Received 14 characters');
    await ready();
    assert(!(await terminalText()).includes('testing-secret'));
    await page.locator('#next').click();
    assert.equal(await page.locator('#lesson-title').textContent(), 'tmux, in three words');
    await page.locator('#previous').click();
    await page.reload();
    await ready();
    await outputContains('Welcome, Cardano explorer');
    await page.locator('.run-command').click();
    await ready();
    fs.mkdirSync(path.join(__dirname, 'screenshots'), { recursive: true });
    await page.screenshot({
      path: path.join(__dirname, 'screenshots/desktop.png'),
      fullPage: true,
    });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForFunction(() => document.documentElement.scrollWidth <= window.innerWidth);
    await page.screenshot({ path: path.join(__dirname, 'screenshots/mobile.png'), fullPage: true });
    assert.deepEqual(errors, []);
    console.log(
      'Browser checks passed: rendering, clicks, state, hidden input, navigation, reconnect and responsive screenshots.',
    );
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
    await new Promise((resolve) => server.once('exit', resolve));
    fs.rmSync(home, { recursive: true, force: true });
    if (logs.includes('Traceback')) console.error(logs);
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
