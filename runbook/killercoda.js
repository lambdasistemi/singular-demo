// Builds a Killercoda scenario (Ubuntu, no Nix) from the runbook step files.
//   node runbook/killercoda.js OUTDIR
//
// The scenario runs in tmux with three windows: `devnet` (the private chain, with a shell), `alice` and `bob`, each
// person in a directory of their own with their own vault, receipts and journal. Every "bash" block of the step
// files becomes a block the learner runs with a click, in the window of the person who acts. Wherever the person
// changes, the page gets a switcher block first. "bash skip" blocks are shown only.
const fs = require('fs');
const path = require('path');

const dir = __dirname;
const out = process.argv[2];
if (!out) { console.error('usage: node killercoda.js OUTDIR'); process.exit(2); }

const KIT = 'singular-demo-v0.12.0-x86_64-linux';
const BASE = 'https://github.com/lambdasistemi/singular-demo/releases/download/v0.12.0';
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

const read = (f) => parse(fs.readFileSync(path.join(dir, f), 'utf8'));
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

const SWITCH = (w) => `tmux select-window -t ${w} \\; send-keys -t ${w} '. ../env.sh' Enter`;
const NAME = { alice: 'Alice', bob: 'Bob' };

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
  for (const p of page.parts) {
    if (p.text !== undefined) { md += p.text + '\n'; continue; }
    if (p.skip) { md += '```bash\n' + p.code + '\n```\n'; continue; }
    if (actors && p.actor && p.actor !== current) {
      md += `\n**Now ${NAME[p.actor]}.** Switch to ${NAME[p.actor]}'s window; the same line loads the shared settings there:\n\n\`\`\`bash\n${SWITCH(p.actor)}\n\`\`\`{{exec}}\n\n`;
      current = p.actor;
    }
    md += '```bash\n' + p.code + '\n```{{exec}}\n';
  }
  return md.replace(/\n{3,}/g, '\n\n').trim() + '\n';
}

// -- tmux, in three commands (written for this scenario)
pages.push({
  title: 'tmux, in three commands',
  md: `This scenario runs in **tmux**, a program that keeps several terminals in one: three windows, each with its own shell.

- \`alice\`: Alice's window, in her own directory with her own vault and receipts
- \`bob\`: Bob's window, in his own directory
- \`devnet\`: the private chain (it appears when the chain starts)

Two people, two directories: each keeps the files of what they do, exactly as two people on two machines would. A bar at the bottom of the terminal lists the windows and marks the one you are in with a \`*\`.

You need three commands, and nothing else:

- **Switch window**: \`tmux select-window -t NAME\`. It is the *switcher*. Wherever the story passes from one person to the other, the page gives you the switcher to click. It also loads the shared settings in the window you go to.
- **Leave**: \`tmux detach\`. Nothing stops; the windows and the chain keep running.
- **Come back**: \`tmux attach -t demo\`.

Let us start. The programs are already unpacked by the setup, which also wrote \`${RUN}/env.sh\`, the file that holds the settings Alice and Bob share. First create the session with the two windows:

\`\`\`bash
tmux new-session -d -s demo -n alice -c ${RUN}/alice && tmux new-window -d -t demo -n bob -c ${RUN}/bob && tmux send-keys -t demo:alice '. ../env.sh' Enter && tmux send-keys -t demo:bob '. ../env.sh' Enter
\`\`\`{{exec}}

Now go inside it. From here on, every command you click runs in the window you are in; the bar at the bottom shows \`alice\`:

\`\`\`bash
tmux attach -t demo
\`\`\`{{exec}}

Try the switcher: go to Bob's window, then back to Alice's. The bar at the bottom moves the \`*\`.

\`\`\`bash
tmux select-window -t bob
\`\`\`{{exec}}

\`\`\`bash
tmux select-window -t alice
\`\`\`{{exec}}
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

**Alice's vault.** You are in her window, in her directory. \`singular wallet create\` makes the vault file and prints her address. It asks for a new passphrase twice. The \`$(...)\` keeps the printed address in \`alice_addr\`.

- \`--vault alice.vault\`: the file to create
- \`--network-magic 42\`: the number of this private test chain (preprod is 1, mainnet 764824073)

\`\`\`bash
alice_addr=$(singular wallet create --vault alice.vault --network-magic 42)
\`\`\`{{exec}}

The address is public: it is all the chain will ever be told about her. Save it in the shared settings, where Bob's window can read it too:

\`\`\`bash
echo "alice_addr=$alice_addr" >> ../env.sh; echo "Alice: $alice_addr"
\`\`\`{{exec}}

**Now Bob.** Switch to his window; the same line loads the shared settings there:

\`\`\`bash
${SWITCH('bob')}
\`\`\`{{exec}}

**Bob's vault**, the same way, with his own passphrase:

\`\`\`bash
bob_addr=$(singular wallet create --vault bob.vault --network-magic 42)
\`\`\`{{exec}}

\`\`\`bash
echo "bob_addr=$bob_addr" >> ../env.sh; echo "Bob:   $bob_addr"
\`\`\`{{exec}}

**The private chain.** \`devnet\` runs a real Cardano node with a Koios-style web API in front of it. It only ever sees the two addresses, never the keys. It gets a window of its own, \`devnet\`, which keeps a shell so you can leave it again with a click.

- \`--fund-address ADDRESS:6:2000000000\`: gives the address 6 coins of 2000 ada each (2000000000 lovelace)
- \`> devnet.out\`: its one line of settings goes to this file; its messages stay in the window
- \`& exec bash\`: the chain runs in the background of that window, which keeps a shell

\`\`\`bash
. ../env.sh && tmux new-window -d -n devnet -c ${RUN} "export PATH=$PATH; devnet --fund-address $alice_addr:6:2000000000 --fund-address $bob_addr:6:2000000000 > devnet.out & exec bash"
\`\`\`{{exec}}

**Wait until the settings line has appeared**, then show it. \`providerUrl\` is where the chain's web API answers.

\`\`\`bash
until jq -e .providerUrl ../devnet.out >/dev/null 2>&1; do sleep 1; done; jq . ../devnet.out
\`\`\`{{exec}}

**Two values to keep** in the shared settings: where the chain answers, and where its clock data is (when each slot happens).

\`\`\`bash
printf 'koios_url=%s\\ntime_dir=%s\\n' "$(jq -r .providerUrl ../devnet.out)" "$(jq -r .networkTimeDirectory ../devnet.out)" >> ../env.sh && . ../env.sh && echo "$koios_url"
\`\`\`{{exec}}

Want to see the chain? Switch to its window and look at its messages, then come back to Alice's window with her switcher:

\`\`\`bash
tmux select-window -t devnet
\`\`\`{{exec}}

\`\`\`bash
${SWITCH('alice')}
\`\`\`{{exec}}
`,
});

// -- the steps
const stepPages = [...pick(/^s(0[1-9]|1[0-6])-/), ...pick(/^s2[01]-/)];
for (const f of stepPages) {
  const pg = read(f);

  if (/^s01-/.test(f)) {
    // the chain's two values are already in the shared settings; the registry's name goes there too
    const i = pg.parts.findIndex((p) => p.text !== undefined && p.text.includes('**Two values to keep.**'));
    if (i < 0) { console.error('killercoda.js: s01 "Two values to keep" not found'); process.exit(1); }
    // drop that paragraph and its first block
    const j = pg.parts.findIndex((p, k) => k > i && p.code !== undefined);
    pg.parts.splice(i, j - i + 1);
    const tok = pg.parts.findIndex((p) => p.code !== undefined && p.code.startsWith('token='));
    if (tok < 0) { console.error('killercoda.js: s01 token block not found'); process.exit(1); }
    pg.parts[tok].code = 'echo "token=$(jq -r .stateToken receipts/01-create.json)" >> ../env.sh && . ../env.sh && echo "$token"';
    const k = pg.parts.findIndex((p, n) => n < tok && p.text !== undefined && p.text.includes('From now on every command names the registry'));
    if (k >= 0) pg.parts[k].text = pg.parts[k].text.replace(/The token is the registry's name, read from the create receipt:?/, "The token is the registry's name, read from the create receipt. It goes into the shared settings, so Bob's window knows it too:");
  }
  if (/^s03-/.test(f)) {
    swapCode(pg, `echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json`, `echo '{"constructor":0,"fields":[{"int":42}]}' | tee payload.json ../bob/payload.json`);
    const t = pg.parts.findIndex((p) => p.text !== undefined && p.text.includes('**The payload**'));
    pg.parts[t].text = swap(pg.parts[t].text, '**The payload**: the data stored under the key, as Plutus data in JSON, constructor 0 holding the integer 42.', "**The payload**: the data stored under the key, as Plutus data in JSON, constructor 0 holding the integer 42. It is also written into Bob's directory, because he books a key later.");
  }
  if (/^s11-/.test(f)) {
    // the waiting helper lives in the shared settings: drop its definition from the page
    const d = pg.parts.findIndex((p) => p.code !== undefined && p.code.startsWith('wait_for_slot()'));
    if (d < 0) { console.error('killercoda.js: wait_for_slot definition not found'); process.exit(1); }
    const lead = d - 1;
    if (pg.parts[lead].text === undefined || !pg.parts[lead].text.includes('wait_for_slot')) { console.error('killercoda.js: lead of the helper not found'); process.exit(1); }
    pg.parts.splice(lead, 2, { text: '\n**The waiting helper.** `wait_for_slot N` asks the chain for its latest slot every 2 seconds until it is past `N`. It uses the chain\'s clock, like the program does. It is part of the shared settings, so both windows have it.\n' });
  }
  pages.push({ title: pg.title, md: render(pg, { actors: !/^s20-/.test(f) }) });
}

// ---- output

fs.rmSync(out, { recursive: true, force: true });
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

w('intro/text.md', `Singular keeps a registry of keys on Cardano. Here you play its Demo 1 yourself on a **private test chain**: nothing touches a public network, and nothing is installed on this machine.

You play two people, **Alice** and **Bob**, each in a tmux window of their own, and a third window holds the chain. You will, step by step:

- create two wallets and a registry,
- book a key, fold it into the registry, read it back, change it and remove it,
- let a request go stale and reject it, and take another one back before its window closes.

Every command is shown in full with what it does. Click a command to run it, read what comes back, and go on. Two steps wait a few minutes for the chain's own clock, and the page says when.

Passphrases are typed at a prompt (they are not shown); use \`alice\` for Alice and \`bob\` for Bob.

The machine lasts one hour at most and is deleted when you close this tab. The whole journey takes about 15 minutes. If the chain on the machine is ever stopped, restart the scenario: a new machine starts from the beginning.

A kit with the programs, and tmux, are being installed in the background. When the terminal says \`Ready\`, start.
`);

w('intro/background.sh', `#!/bin/bash
set -x
cd /root
base=${BASE}
curl -fsSLO "$base/${KIT}.tar.gz"
curl -fsSLO "$base/SHA256SUMS"
sha256sum -c SHA256SUMS
tar xzf ${KIT}.tar.gz
# tmux holds the three windows
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq tmux
tmux -V
# one directory for each person (with the folders for their receipts, bundles and witnesses), and the settings they share
mkdir -p /root/singular-demo-run/alice/receipts /root/singular-demo-run/alice/bundles /root/singular-demo-run/alice/witnesses \
  /root/singular-demo-run/bob/receipts /root/singular-demo-run/bob/bundles /root/singular-demo-run/bob/witnesses
cat > /root/singular-demo-run/env.sh <<'ENVEOF'
# Settings shared by Alice's and Bob's windows; every window loads this file (". ../env.sh").
export PATH="/root/${KIT}/bin:$PATH"
export blueprint="/root/${KIT}/share/plutus.json"
# wait_for_slot N: ask the chain for its latest slot every 2 seconds until it is past N (the chain's own clock).
wait_for_slot() { local now; until now=$(curl -fsS "$koios_url/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do printf '\\r  chain slot %s, waiting for slot %s ' "$now" "$1"; sleep 2; done; printf '\\n  done: chain slot %s is past slot %s\\n' "$now" "$1"; }
ENVEOF
touch /tmp/finished
`);

w('intro/foreground.sh', `echo "Downloading and checking the demo kit, and installing tmux..."
while [ ! -f /tmp/finished ]; do sleep 1; done
echo "Ready."
`);

w('finish/text.md', `That was the whole of Demo 1: a key booked, folded, changed and removed; a stuck request rejected after its two windows; a request taken back inside its window. Everything ran on a private test chain, with Alice and Bob each in a window of their own.

Stop the chain, which still runs in its window:

\`\`\`bash
tmux kill-window -t devnet
\`\`\`{{exec}}

Alice's receipts are in \`~/singular-demo-run/alice/receipts\`; Bob's receipts, the transactions he built (\`bundles/\`) and his signatures (\`witnesses/\`) are in \`~/singular-demo-run/bob\`.
`);

console.log('scenario written to ' + out + ': ' + pages.length + ' steps');
