// Exercise the published lessons through the same run buttons and terminal as a visitor.
// Uses real release binaries, wallet prompts and unmodified chain time windows.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { chromium } = require('playwright');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'singular-demo-browser-'));
  const screenshots = path.join(__dirname, 'screenshots');
  fs.mkdirSync(screenshots, { recursive: true });
  const env = { ...process.env, HOME: home };
  let server, browser, page, transcript = '', logs = '';
  try {
    const install = spawnSync('bash', [path.join(__dirname, 'install-kit.sh')], { env, encoding: 'utf8', timeout: 180000 });
    assert.equal(install.status, 0, install.stdout + install.stderr);
    server = spawn(path.join(__dirname, '.venv/bin/python'), [path.join(__dirname, 'server.py')], { env, stdio: ['ignore', 'pipe', 'pipe'] });
    server.stdout.on('data', chunk => logs += chunk);
    server.stderr.on('data', chunk => logs += chunk);
    for (let i = 0; i < 100; i++) {
      try { if ((await fetch('http://127.0.0.1:8765/health')).ok) break; } catch {}
      await pause(100);
    }
    const { lessons } = await (await fetch('http://127.0.0.1:8765/api/lessons')).json();
    browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
    page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    let ready = false, ran = null, promptBuffer = '', prompts = 0, expectedPrompts = 0;
    page.on('websocket', ws => ws.on('framereceived', ({ payload }) => {
      const message = JSON.parse(payload.toString());
      if (message.type === 'state') ready = message.ready;
      if (message.type === 'ran') ran = message.id;
      if (message.type === 'error') errors.push(message.message);
      if (message.type === 'output') {
        transcript += message.data;
        promptBuffer += message.data;
        // Source: Singular.CLI.Passphrase at v0.12.0. Handles split PTY chunks.
        const pattern = /(?:New vault|Confirm vault|Vault) passphrase: /g;
        let match, end = 0;
        while ((match = pattern.exec(promptBuffer))) { if (expectedPrompts > 0) { prompts++; expectedPrompts--; } end = pattern.lastIndex; }
        promptBuffer = end ? promptBuffer.slice(end) : promptBuffer.slice(-100);
      }
    }));
    await page.goto('http://127.0.0.1:8765');
    await page.waitForFunction(() => document.querySelector('#connection').textContent === '● Ready');
    for (let i = 0; i < lessons.length; i++) {
      await page.locator('#lessons button').nth(i).click();
      console.log(`Lesson ${i + 1}: ${lessons[i].title}`);
      for (const block of lessons[i].blocks.filter(block => block.id !== null && block.kind === 'code')) {
        const password = block.text.includes('bob.vault') ? 'demo-bob-passphrase' : 'demo-alice-passphrase';
        prompts = 0; promptBuffer = ''; ran = null; ready = false;
        expectedPrompts = block.text.includes('--vault ') ? (block.text.includes('wallet create') ? 2 : 1) : 0;
        await page.locator(`.run-command[data-id="${block.id}"]`).click();
        const deadline = Date.now() + 360000;
        while (ran !== block.id || !ready) {
          assert(Date.now() < deadline, `Timed out at command ${block.id}: ${block.text}\n${transcript.slice(-3000)}`);
          if (prompts > 0) {
            prompts--;
            assert(await page.locator(`.run-command[data-id="${block.id}"]`).isDisabled());
            await page.locator('.xterm-helper-textarea').fill(password);
            await page.locator('.xterm-helper-textarea').press('Enter');
          }
          await pause(100);
        }
        assert(!transcript.includes('demo-alice-passphrase') && !transcript.includes('demo-bob-passphrase'), 'Passphrase echoed');
        console.log(`  command ${block.id} returned to prompt`);
      }
      if ([4, 9, 15, 18, 24].includes(i)) await page.screenshot({ path: path.join(screenshots, `demo-lesson-${i}.png`), fullPage: true });
    }
    const demo = path.join(home, 'singular-demo-run');
    const receiptPath = name => {
      const matches = ['alice', 'bob'].map(who => path.join(demo, who, 'receipts', name)).filter(file => fs.existsSync(file));
      assert(matches.length > 0, `Missing receipt ${name}`);
      return matches[0];
    };
    const read = name => JSON.parse(fs.readFileSync(receiptPath(name), 'utf8'));
    for (const name of ['01-create', '03-insert-alice', '06-update', '08-terminate', '13-fold-bob', '14c-reclaim', '15-insert-dave']) {
      assert.equal(read(name + '.json').outcome, 'success', name);
    }
    for (const name of ['04-fold-insert', '09-fold-terminate', '11d-reject', '12-insert-bob']) {
      assert.equal(read(name + '.json').outcome, 'waiting-for-signatures', name);
    }
    for (const name of ['11b-reject-too-early', '14b-reclaim-too-early']) assert.equal(read(name + '.json').outcome, 'client-refusal', name);
    for (const name of ['04-fold-insert', '09-fold-terminate', '11d-reject', '12-insert-bob']) assert(read(name + '.submitted.json').submissions.length > 0, name);
    assert.equal(read('05-inspect.json').leaf, 'active');
    assert.equal(read('10-inspect.json').leaf, 'terminal');
    assert.equal(read('16b-inspect-dave.json').leaf, 'active');
    assert(fs.readFileSync(receiptPath('02-describe.txt'), 'utf8').includes('processTime'));
    assert(read('tx-info.json').length > 0);
    assert(!/jq: error|command not found|curl: \(/.test(transcript));
    assert.deepEqual(errors, []);
    console.log('PASS: full Singular demo, real wallet prompts, signatures, submissions, time windows, receipts and extras.');
  } catch (error) {
    if (page) await page.screenshot({ path: path.join(screenshots, 'demo-failure.png'), fullPage: true }).catch(() => {});
    console.error(transcript.slice(-6000));
    throw error;
  } finally {
    if (browser) await browser.close();
    if (server) {
      server.kill('SIGTERM');
      await new Promise(resolve => server.once('exit', resolve));
    }
    fs.writeFileSync(path.join(screenshots, 'demo-terminal.txt'), transcript);
    fs.rmSync(home, { recursive: true, force: true });
    if (logs.includes('Traceback')) console.error(logs);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
