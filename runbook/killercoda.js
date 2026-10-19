// Builds a Killercoda scenario (Ubuntu, no Nix) from the runbook step files.
//   node runbook/killercoda.js OUTDIR
// Every "bash" block becomes a block the learner runs with a click; "bash skip" blocks are shown only.
const fs = require('fs');
const path = require('path');

const dir = __dirname;
const out = process.argv[2];
if (!out) { console.error('usage: node killercoda.js OUTDIR'); process.exit(2); }

const KIT = 'singular-demo-v0.12.0-x86_64-linux';
const BASE = 'https://github.com/lambdasistemi/singular-demo/releases/download/v0.12.0';

const files = fs.readdirSync(dir).filter((f) => /^s\d.*\.md$/.test(f)).sort()
  .filter((f) => !/^s00a-/.test(f) && !/^s22/.test(f) && !/^s99/.test(f));

function convert(text) {
  const lines = text.split('\n');
  const title = lines.shift().replace(/^#\s+/, '');
  let body = '';
  let block = null;
  for (const line of lines) {
    const open = line.match(/^```bash(?: (skip))?$/);
    if (block === null && open) { block = { skip: !!open[1], lines: [] }; continue; }
    if (block !== null && line === '```') {
      body += '```bash\n' + block.lines.join('\n') + '\n```' + (block.skip ? '' : '{{exec}}') + '\n';
      block = null; continue;
    }
    if (block !== null) { block.lines.push(line); continue; }
    body += line + '\n';
  }
  // the page says "paste" for a terminal; here the learner clicks
  body = body.replace(/\bpasted\b/g, 'run').replace(/\bPaste\b/g, 'Run').replace(/\bpaste\b/g, 'run');
  return { title, body: body.replace(/\n{3,}/g, '\n\n').trim() + '\n' };
}

const steps = files.map((f) => ({ file: f, ...convert(fs.readFileSync(path.join(dir, f), 'utf8')) }));

fs.rmSync(out, { recursive: true, force: true });
const w = (p, s) => { fs.mkdirSync(path.dirname(path.join(out, p)), { recursive: true }); fs.writeFileSync(path.join(out, p), s); };

// the setup page starts with the kit's own environment
const setupIntro = `The kit unpacked in the background carries the programs. Put them on the \`PATH\` and name the compiled contracts the commands need as \`$blueprint\`:

\`\`\`bash
cd ~/${KIT}
export PATH="$PWD/bin:$PATH"
export blueprint="$PWD/share/plutus.json"
\`\`\`{{exec}}

`;

const idx = {
  title: 'Singular Demo 1, step by step on a private chain',
  description: 'Play Singular Demo 1 yourself on a private Cardano test chain: book keys, fold them, change and remove them, reject a stuck request and take one back. Ubuntu, nothing to install.',
  details: {
    intro: { text: 'intro/text.md', foreground: 'intro/foreground.sh', background: 'intro/background.sh' },
    steps: steps.map((s, i) => ({ title: s.title.replace(/^Before you start: two programs, one registry/, 'Two programs, one registry').replace(/^Before you start: /, 'Setup: '), text: `step${i + 1}/text.md` })),
    finish: { text: 'finish/text.md' },
  },
  backend: { imageid: 'ubuntu' },
};
w('index.json', JSON.stringify(idx, null, 2) + '\n');

steps.forEach((s, i) => {
  const lead = /^s00b/.test(s.file) ? setupIntro : '';
  w(`step${i + 1}/text.md`, lead + s.body);
});

w('intro/text.md', `Singular keeps a registry of keys on Cardano. Here you play its Demo 1 yourself on a **private test chain**: nothing touches a public network, and nothing is installed on this machine.

You will, step by step:

- create two wallets and a registry,
- book a key, fold it into the registry, read it back, change it and remove it,
- let a request go stale and reject it, and take another one back before its window closes.

Every command is shown in full with what it does. Click a command to run it, read what comes back, and go on. Two steps wait a few minutes for the chain's own clock, and the page says when.

Passphrases are typed at a prompt (they are not shown); use \`alice\` for Alice and \`bob\` for Bob.

A kit with the programs is being downloaded and checked in the background. When the terminal says \`Ready\`, start.
`);
w('intro/background.sh', `#!/bin/bash
set -x
cd /root
base=${BASE}
curl -fsSLO "$base/${KIT}.tar.gz"
curl -fsSLO "$base/SHA256SUMS"
sha256sum -c SHA256SUMS
tar xzf ${KIT}.tar.gz
touch /tmp/finished
`);
w('intro/foreground.sh', `echo "Downloading and checking the demo kit..."
while [ ! -f /tmp/finished ]; do sleep 1; done
echo "Ready."
`);
w('finish/text.md', `That was the whole of Demo 1: a key booked, folded, changed and removed; a stuck request rejected after its two windows; a request taken back inside its window. Everything ran on a private test chain.

The devnet is still running in this machine's background. Stop it:

\`\`\`bash
kill "$devnet_pid"
\`\`\`{{exec}}

Your receipts are in \`~/singular-demo-run/receipts\`, the transactions you built in \`bundles/\` and the signatures in \`witnesses/\`.
`);
console.log('scenario written to ' + out + ': ' + steps.length + ' steps');
