// Builds a Killercoda scenario (Ubuntu, no Nix) from the runbook step files.
//   node demos/demo1/killercoda.js ROOT   writes ROOT/killercoda/demo1-steps and ROOT/killercoda/demo1-script, and the two structure.json files
//
// The scenario runs in tmux with three windows, made by the setup: 0 `alice`, 1 `bob` and 2 `chain` (the private
// chain, a background job of its window), each person in a directory of their own with their own vault, receipts and
// journal. The two people share one settings file, singular.json, which the Singular commands read by themselves
// (the variable SINGULAR_CONFIG names it). Every "bash" block of the step files
// becomes a block the learner runs with a click, in the window of the person who acts. Wherever the person changes,
// the page gives the word to click (alice, bob or chain); the keys Ctrl-b 0, 1 and 2 are only an extra, nothing needs a
// keyboard. "bash skip" blocks are shown only.
const fs = require('fs');
const path = require('path');

const dir = __dirname;
const root = process.argv[2];
if (!root) { console.error('usage: node killercoda.js ROOT'); process.exit(2); }
// Killercoda reads a course (a directory of scenarios) named by structure.json; everything else in the repository is ignored.
const course = path.join(root, 'killercoda');
const out = path.join(course, 'demo1-steps');

const VERSION = require('./version.js');
const KIT = `singular-demo-${VERSION}-x86_64-linux`;
const BASE = `https://github.com/lambdasistemi/singular-demo/releases/download/${VERSION}`;
const RUN = '~/singular-demo-run';

// ---- reading the step files

function parse(text) {
  const lines = text.split('\n');
  const title = lines.shift().replace(/^#\s+/, '');
  const parts = []; // { text } or { code, skip }
  let buf = [];
  let block = null;
  const flush = () => { if (buf.length) { parts.push({ text: buf.join('\n') }); buf = []; } };
  for (const line of lines) {
    const open = line.match(/^```bash(?: (skip))?$/);
    if (block === null && open) { flush(); block = { skip: !!open[1], lines: [] }; continue; }
    if (block !== null && line === '```') { parts.push({ code: block.lines.join('\n'), skip: block.skip }); block = null; continue; }
    if (block !== null) { block.lines.push(line); continue; }
    buf.push(line);
  }
  flush();
  // the page says "paste" for a terminal; here the learner clicks
  for (const p of parts) if (p.text) p.text = p.text.replace(/\bpasted\b/g, 'run').replace(/\bPaste\b/g, 'Run').replace(/\bpaste\b/g, 'run');
  return { title, parts };
}

const read = (f) => parse(fs.readFileSync(path.join(dir, f), 'utf8').split('@VERSION@').join(VERSION));
const stepFiles = fs.readdirSync(dir).filter((f) => /^s\d.*\.md$/.test(f)).sort();
const pick = (re) => stepFiles.filter((f) => re.test(f));

// A replacement must find its text, so a change in a step file cannot slip past this generator unnoticed.
function swap(str, from, to) {
  const next = str.replace(from, to);
  if (next === str) { console.error('killercoda.js: text to replace not found: ' + String(from).slice(0, 80)); process.exit(1); }
  return next;
}
function swapCode(page, from, to) {
  let hit = false;
  for (const p of page.parts) {
    if (p.code !== undefined && p.code.includes(from)) { p.code = p.code.replace(from, to); hit = true; }
  }
  if (!hit) { console.error('killercoda.js: code to replace not found: ' + from.slice(0, 80)); process.exit(1); }
}

// ---- who acts

// Each window has a word that goes to it (a function in windows.rc, so a click is enough) and a number for Ctrl-b.
// The scenario test finds the words as click-to-run blocks of one line: alice, bob or chain. The chain runs as a
// background job of its window, so that window keeps its prompt and the words work there too.
const WINDOW = { alice: 0, bob: 1, chain: 2 };
const NAME = { alice: 'Alice', bob: 'Bob' };
const OWNER = { alice: "Alice's", bob: "Bob's", chain: "the chain's" };
const goTo = (w, lead = '') => `${lead}Go to ${OWNER[w]} window: click \`${w}\`, or press \`Ctrl-b ${WINDOW[w]}\`.\n\n\`\`\`bash\n${w}\n\`\`\`{{exec}}`;

function actorOf(code) {
  if (/open-datum inspect/.test(code)) return 'alice'; // reads are Alice's: she owns the receipts the next steps compare
  if (/bob\.vault|\$bob_addr|bundles\//.test(code)) return 'bob';
  if (/alice\.vault|\$alice_addr/.test(code)) return 'alice';
  if (/^echo '\{"constructor"/.test(code)) return 'next'; // payload files belong to whoever uses them next
  return null; // neutral: runs where the learner already is (read-backs of the last receipt, waits)
}

// ---- pages

const pages = []; // { title, md }
let current = 'alice';

function render(page, { actors }) {
  // decide the window of every exec block, with a look ahead for the blocks that belong to the next one
  const codes = page.parts.filter((p) => p.code !== undefined && !p.skip);
  codes.forEach((p, i) => { p.actor = actorOf(p.code); });
  codes.forEach((p, i) => {
    if (p.actor === 'next') {
      const nxt = codes.slice(i + 1).find((q) => q.actor && q.actor !== 'next');
      p.actor = nxt ? nxt.actor : null;
    }
  });
  let md = '';
  let chunkStart = -1; // where the text chunk just before this block starts, -1 when a block came last
  for (const p of page.parts) {
    if (p.text !== undefined) { chunkStart = md.length; md += p.text + '\n'; continue; }
    if (p.skip) { md += '```bash\n' + p.code + '\n```\n'; chunkStart = -1; continue; }
    if (actors && p.actor && p.actor !== current) {
      const line = goTo(p.actor, `**Now ${NAME[p.actor]}.** `) + '\n\n';
      // the keys come before the caption of the block (the last paragraph of the text above it), so the learner
      // is in the right window when reading what that person does
      if (chunkStart >= 0) {
        const cut = md.trimEnd().lastIndexOf('\n\n');
        const at = cut >= chunkStart ? cut + 2 : chunkStart;
        md = md.slice(0, at) + line + md.slice(at);
      } else {
        md += '\n' + line;
      }
      current = p.actor;
    }
    chunkStart = -1;
    md += '```bash\n' + p.code + '\n```{{exec}}\n';
  }
  return md.replace(/\n{3,}/g, '\n\n').trim() + '\n';
}

// -- tmux, with the commands used here (written for this scenario)
pages.push({
  title: 'tmux, in three words',
  md: `This scenario runs in **tmux**, a program that keeps several terminals in one. The setup has made three windows, each with its own shell:

- \`0\` \`alice\`: Alice's window, in her own directory with her own vault and receipts
- \`1\` \`bob\`: Bob's window, in his own directory
- \`2\` \`chain\`: the private chain

Two people, two directories: each keeps the files of what they do, exactly as two people on two machines would. A bar at the bottom of the terminal lists the windows with their numbers and marks the one you are in with a \`*\`.

Go inside:

\`\`\`bash
tmux attach -t demo
\`\`\`{{exec}}

From here on every command you click runs in the window you are in. To change window, type the window's name: \`alice\`, \`bob\` or \`chain\`. Wherever the story passes from one person to the other, the page gives you the word to click.

**Try it.** Go to Bob's window; the \`*\` in the bar moves to \`bob\`:

\`\`\`bash
bob
\`\`\`{{exec}}

And back to Alice's:

\`\`\`bash
alice
\`\`\`{{exec}}

With a keyboard, \`Ctrl-b 0\`, \`Ctrl-b 1\` and \`Ctrl-b 2\` go to the same windows.
`,
});

// -- the two text pages
for (const f of pick(/^s00a[12]-/)) {
  const pg = read(f);
  pages.push({ title: pg.title.replace(/^Before you start: two programs, one registry/, 'Two programs, one registry').replace(/^Before you start: two ways to sign/, 'Two ways to sign'), md: render(pg, { actors: false }) });
}

// -- setup: the two wallets and the chain, one window each
pages.push({
  title: 'Setup: two wallets and a private chain',
  md: `A wallet here is a vault: an encrypted key file, opened by a passphrase that is typed when a command asks for it. The key never leaves the vault. Nothing here touches a public network.

Passphrases are not shown while typed. Use \`alice\` for Alice and \`bob\` for Bob, or anything else; the same one is asked again at every command that signs with that vault.

**Alice's vault.** You are in her window, in her directory. \`singular wallet create\` makes the vault file and prints her address. It asks for a new passphrase twice. The \`$(...)\` keeps the printed address in \`alice_addr\`, and \`tee\` also keeps it in the file \`alice.address\`.

- \`--vault alice.vault\`: the file to create
- \`--network-magic 42\`: the number of this private test chain (preprod is 1, mainnet 764824073)

\`\`\`bash
alice_addr=$(singular wallet create --vault alice.vault --network-magic 42 | tee alice.address)
\`\`\`{{exec}}

The address is public: it is all the chain will ever be told about her.

${goTo('bob', '**Now Bob.** ')}

**Bob's vault**, the same way, with his own passphrase:

\`\`\`bash
bob_addr=$(singular wallet create --vault bob.vault --network-magic 42 | tee bob.address)
\`\`\`{{exec}}

**The private chain.** \`devnet\` runs a real Cardano node with a Koios-style web API in front of it. It only ever sees the two addresses, never the keys. It runs in its own window, as a background job: the window keeps its prompt.

${goTo('chain')}

Then run it:

- \`--fund-address ADDRESS:6:2000000000\`: gives the address 6 coins of 2000 ada each (2000000000 lovelace)
- \`$(cat alice/alice.address)\`: the address, read from the file Alice's window wrote (Bob's the same way)
- \`> devnet.out\`: its one line of settings goes to this file
- \`2> devnet.log\`: its messages go to this file
- \`&\`: runs it in the background, so that the window gets its prompt back and the chain keeps running

\`\`\`bash
devnet --fund-address "$(cat alice/alice.address):6:2000000000" --fund-address "$(cat bob/bob.address):6:2000000000" > devnet.out 2> devnet.log &
\`\`\`{{exec}}

The chain keeps running: leave it.

${goTo('alice')}

**Wait until the settings line has appeared**, then show it. \`providerUrl\` is where the chain's web API answers.

\`\`\`bash
until jq -e .providerUrl ../devnet.out >/dev/null 2>&1; do sleep 1; done; jq . ../devnet.out
\`\`\`{{exec}}

**The chain's log.** The chain's messages went to \`devnet.log\`. Show the last lines:

\`\`\`bash
tail -n 20 ../devnet.log
\`\`\`{{exec}}
`,
});

// -- the steps
const stepPages = [...pick(/^s(0[1-9]|1[0-7])-/), ...pick(/^s2[01]-/)];
for (const f of stepPages) {
  const pg = read(f);

  if (/^s01-/.test(f)) {
    // one settings file for both windows, named by SINGULAR_CONFIG; the devnet's line is in the folder above
    for (const p of pg.parts) if (p.code !== undefined) p.code = p.code.replace(/\bdevnet\.out/g, '../devnet.out').replace(/\bsingular\.json/g, '"$SINGULAR_CONFIG"');
    const w = pg.parts.findIndex((p) => p.text !== undefined && p.text.includes('**For this tutorial, the JSON file**'));
    if (w < 0) { console.error('killercoda.js: s01 settings paragraph not found'); process.exit(1); }
    pg.parts[w].text = swap(pg.parts[w].text, 'The devnet\'s settings line has two of the values; `jq` builds the file from it.', 'The devnet\'s settings line has two of the values; `jq` builds the file from it. Here the file\'s name is in the variable `SINGULAR_CONFIG`.');
  }
  if (/^s04-/.test(f)) {
    swapCode(pg, 'jq -r .providerUrl devnet.out', 'jq -r .providerUrl ../devnet.out');
  }
  if (/^s14-/.test(f)) {
    // the waiting helper is in every window: the page's note about defining it again does not apply
    const n = pg.parts.findIndex((p) => p.text !== undefined && p.text.includes('was defined in step 11'));
    if (n < 0) { console.error('killercoda.js: s14 helper note not found'); process.exit(1); }
    pg.parts[n].text = pg.parts[n].text.replace(/`wait_for_slot` was defined in step 11\. In a new terminal, define it again from there\.\n*/, '');
  }
  if (/^s12-/.test(f)) {
    // Bob's directory has no payload file: his booking uses the one Alice wrote
    swapCode(pg, '--key bob --payload payload.json', '--key bob --payload ../alice/payload.json');
    const c = pg.parts.findIndex((p) => p.text !== undefined && p.text.includes('**Build the bundle:**'));
    if (c < 0) { console.error('killercoda.js: s12 caption not found'); process.exit(1); }
    pg.parts[c].text = pg.parts[c].text.replace('**Build the bundle:**', "**Build the bundle**, with Alice's payload file:");
  }
  if (/^s11-/.test(f)) {
    // the waiting helper is defined by the setup in both windows: drop its definition from the page
    const d = pg.parts.findIndex((p) => p.code !== undefined && p.code.includes('wait_for_slot()'));
    if (d < 0) { console.error('killercoda.js: wait_for_slot definition not found'); process.exit(1); }
    const lead = d - 1;
    if (pg.parts[lead].text === undefined || !pg.parts[lead].text.includes('wait_for_slot')) { console.error('killercoda.js: lead of the helper not found'); process.exit(1); }
    pg.parts.splice(lead, 2, { text: '\n**The waiting helper.** `wait_for_slot N` is ready to use: it asks the chain for its latest slot every 2 seconds until it is past `N`, by the chain\'s clock, like the program does.\n' });
  }
  if (/^s21-/.test(f)) {
    // this page moves between the windows, and only Alice's keeps the variable: read the chain's address where it is used
    swapCode(pg, '"$koios_url/tx_info"', '"$(jq -r .providerUrl ../devnet.out)/tx_info"');
  }
  if (/^s20-/.test(f)) {
    // the addresses are in files and the chain's address in the devnet's line: this window reads them into variables
    const h = pg.parts.findIndex((p) => p.text !== undefined && p.text.includes('**A small helper**'));
    if (h < 0) { console.error('killercoda.js: s20 helper paragraph not found'); process.exit(1); }
    pg.parts.splice(h, 0,
      { text: "**Read the addresses and the chain's address.** The addresses were written to files when the wallets were made, and the chain's address is in the devnet's settings line. Read them into variables, in this window:\n" },
      { code: 'alice_addr=$(cat ../alice/alice.address); bob_addr=$(cat ../bob/bob.address); koios_url=$(jq -r .providerUrl ../devnet.out)', skip: false });
  }
  pages.push({ title: pg.title, md: render(pg, { actors: !/^s20-/.test(f) }) });
}

// ---- output

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(course, { recursive: true });
fs.writeFileSync(path.join(root, 'structure.json'), JSON.stringify({ items: [{ path: 'killercoda', title: 'Singular demos' }] }, null, 2) + '\n');
fs.writeFileSync(path.join(course, 'structure.json'), JSON.stringify({ items: [{ path: 'demo1-steps' }, { path: 'demo1-script' }] }, null, 2) + '\n');
const w = (p, s) => { fs.mkdirSync(path.dirname(path.join(out, p)), { recursive: true }); fs.writeFileSync(path.join(out, p), s); };

w('index.json', JSON.stringify({
  title: 'Singular Demo 1, step by step on a private chain',
  description: 'Play Singular Demo 1 yourself on a private Cardano test chain, as Alice and as Bob in two tmux windows: book keys, fold them, change and remove them, reject a stuck request and take one back. Ubuntu, nothing to install.',
  details: {
    intro: { text: 'intro/text.md', foreground: 'intro/foreground.sh', background: 'intro/background.sh' },
    steps: pages.map((p, i) => ({ title: p.title, text: `step${i + 1}/text.md` })),
    finish: { text: 'finish/text.md' },
  },
  backend: { imageid: 'ubuntu-4GB' },
}, null, 2) + '\n');

pages.forEach((p, i) => w(`step${i + 1}/text.md`, p.md));

w('intro/text.md', `Singular keeps a registry of keys on Cardano. Here you play its Demo 1 yourself on a **private test chain**: nothing touches a public network, and nothing is installed on this machine. The project is at https://github.com/lambdasistemi/singular and its documentation at https://lambdasistemi.github.io/singular/ ; its own page for this journey is https://lambdasistemi.github.io/singular/docs/demo1-devnet/

You play two people, **Alice** and **Bob**, each in a tmux window of their own, and a third window holds the chain. You switch windows by clicking a word: \`alice\`, \`bob\` or \`chain\`. You will, step by step:

- create two wallets and a registry,
- book a key, fold it into the registry, read it back, change it and remove it,
- let a request go stale and reject it, and take another one back before its window closes.

Every command is shown in full with what it does. Click a command to run it, read what comes back, and go on. Two steps wait a few minutes for the chain's own clock, and the page says when.

The machine lasts one hour at most and is deleted when you close this tab. The whole journey takes about 15 minutes. If the chain on the machine is ever stopped, restart the scenario: a new machine starts from the beginning.

A kit with the programs, and tmux, are being installed in the background. When the terminal says \`Ready\`, start.
`);

// The scripts of the play are the files in play/: the Codespaces tutorial runs the same ones. The setup of the
// machine writes them out as they are and runs them.
const PLAYFILES = ['install-kit.sh', 'prepare.sh', 'windows.rc', 'windows.sh'];
const embed = (files) => files.map((f) => {
  const text = fs.readFileSync(path.join(dir, 'play', f), 'utf8');
  if (text.includes('PLAY_EOF')) { console.error('killercoda.js: play/' + f + ' contains the heredoc delimiter'); process.exit(1); }
  return "cat > /root/play/" + f + " <<'PLAY_EOF'\n" + text.replace(/\n*$/, '\n') + "PLAY_EOF\n";
}).join('');

w('intro/background.sh', `#!/bin/bash
set -x
export DEBIAN_FRONTEND=noninteractive
mkdir -p /root/play
${embed(PLAYFILES)}bash /root/play/install-kit.sh ${VERSION} /root
# tmux holds the three windows
apt-get update -qq && apt-get install -y -qq tmux
tmux -V
bash /root/play/prepare.sh /root/${KIT} /root/singular-demo-run
touch /tmp/finished
`);

w('intro/foreground.sh', `echo "Downloading and checking the demo kit, and installing tmux..."
while [ ! -f /tmp/finished ]; do sleep 1; done
bash /root/play/windows.sh /root/singular-demo-run
echo "Ready."
`);

w('finish/text.md', `That was the whole of Demo 1: a key booked, folded, changed and removed; a stuck request rejected after its two windows; a request taken back inside its window. Everything ran on a private test chain, with Alice and Bob each in a window of their own.

**Stop the chain.**

${goTo('chain')}

The chain is job 1 of its window. Stop it:

\`\`\`bash
kill %1
\`\`\`{{exec}}

The window keeps its shell.

The chain's messages are in \`~/singular-demo-run/devnet.log\`. Alice's receipts are in \`~/singular-demo-run/alice/receipts\`; Bob's receipts, the transactions he built (\`bundles/\`) and his signatures (\`witnesses/\`) are in \`~/singular-demo-run/bob\`.
`);

console.log('scenario written to ' + out + ': ' + pages.length + ' steps');

// ---- the second scenario: the kit's annotated script, run as it is
const script = path.join(course, 'demo1-script');
fs.rmSync(script, { recursive: true, force: true });
const ws = (p, t) => { fs.mkdirSync(path.dirname(path.join(script, p)), { recursive: true }); fs.writeFileSync(path.join(script, p), t); };
ws('index.json', JSON.stringify({
  title: 'Singular Demo 1 on a private devnet',
  description: `The Demo 1 script of Singular ${VERSION} on a private Cardano test chain, on Ubuntu, with nothing to install.`,
  details: {
    intro: { text: 'intro/text.md', foreground: 'intro/foreground.sh', background: 'intro/background.sh' },
    steps: [{ title: 'Run the demo', text: 'step1/text.md' }],
    finish: { text: 'finish/text.md' },
  },
  backend: { imageid: 'ubuntu-4GB' },
}, null, 2) + '\n');
ws('intro/text.md', `This machine is a plain Ubuntu. A kit with the Singular programs, a private Cardano test chain and an annotated script of Demo 1 is being downloaded and unpacked in the background; nothing is installed on the system.

When the terminal says \`Ready\`, go to the next step.
`);
ws('intro/background.sh', `#!/bin/bash
set -x
mkdir -p /root/play
${embed(['install-kit.sh'])}bash /root/play/install-kit.sh ${VERSION} /root
touch /tmp/finished
`);
ws('intro/foreground.sh', `echo "Downloading and checking the demo kit..."
while [ ! -f /tmp/finished ]; do sleep 1; done
echo "Ready."
`);
ws('step1/text.md', `Run the annotated script. It starts a private test chain, creates two wallets, and plays all 16 steps of Demo 1, explaining each one as it goes. It takes about 5 minutes, two of them real waits on the chain (the registry's windows are set to 60 and 30 seconds here).

The script runs in the background and writes everything to a log, and the terminal follows the log. So pressing Ctrl+C, or copying text with it, only stops the following: the demo carries on.

\`\`\`bash
cd ~/${KIT} && (PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 setsid nohup ./demo.sh > demo.log 2>&1 &) ; sleep 1; tail -n +1 -f demo.log
\`\`\`{{exec}}

To copy text from the terminal, select it and use Ctrl+Shift+C, or right-click.

If you stopped following, pick the log up again from the start:

\`\`\`bash
tail -n +1 -f ~/${KIT}/demo.log
\`\`\`{{exec}}

The script asks nothing; the wallets use throwaway passphrases. When the log ends with the last step, the run is over and the chain it started has been stopped.
`);
ws('finish/text.md', `That was all 16 steps: a key booked, folded, changed and removed; a stuck request rejected; a request taken back. Everything ran on a private test chain.

The receipts are in \`~/${KIT}/singular-demo-run/receipts\`.
`);
console.log('script scenario written to ' + script);
