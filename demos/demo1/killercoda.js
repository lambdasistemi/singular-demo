// Builds a Killercoda scenario (Ubuntu, no Nix) from the runbook step files.
//   node demos/demo1/killercoda.js ROOT   writes ROOT/killercoda/demo1-steps and ROOT/killercoda/demo1-script
// (the structure.json files that list the scenarios are written by demos/structure.js)
//
// The scenario runs in tmux with four windows: 0 `alice`, 1 `bob`, 2 `chain` and 3 `carol`.
// The private chain is a background job of its window; each person has their own directory, vault, receipts,
// journal and settings file (alice.json and bob.json: the window sets the variable SINGULAR_CONFIG to its person's
// file). Every "bash" block of the step files becomes a block the learner runs with a click, in the window of the
// person who acts. A step file says where the person changes: a paragraph "**Now Bob.**" followed by the block `bob`
// (in a single terminal that block chooses Bob's settings file; here it is the word that moves to his window). The
// page then gives the word to click (carol, alice, bob or chain); the keys Ctrl-b 0, 1, 2 and 3 are only an extra, nothing needs
// a keyboard. A block whose window is not the one the page has named stops the generator. Blocks marked
// `{ mode=show }` are shown only; `{ mode=observe }` blocks run like commands.
const fs = require('node:fs');
const path = require('node:path');

const dir = __dirname;
const root = process.argv[2];
if (!root) {
  console.error('usage: node killercoda.js ROOT');
  process.exit(2);
}
// Killercoda reads a course (a directory of scenarios) named by structure.json; everything else in the repository is ignored.
const course = path.join(root, 'killercoda');
const out = path.join(course, 'demo1-steps');

const VERSION = require('./version.js');
const RELEASE = require('./release.js');
const KIT = `singular-demo-${RELEASE}-x86_64-linux`;
const _BASE = `https://github.com/lambdasistemi/singular-demo/releases/download/${RELEASE}`;
const _RUN = '~/singular-demo-run';

// ---- reading the step files

function parse(text) {
  const lines = text.split('\n');
  const title = lines.shift().replace(/^#\s+/, '');
  const parts = []; // { text } or { code, window, mode }
  let buf = [];
  let block = null;
  const flush = () => {
    if (buf.length) {
      parts.push({ text: buf.join('\n') });
      buf = [];
    }
  };
  for (const [n, line] of lines.entries()) {
    const open = line.match(/^```bash \{([^}]*)\}$/);
    if (block === null && open) {
      flush();
      const attrs = {};
      for (const kv of open[1].trim().split(/\s+/)) {
        const [k, v] = kv.split('=');
        attrs[k] = v;
      }
      if (!attrs.window) {
        console.error(`killercoda.js:${n + 2}: fence without window=...: ${line}`);
        process.exit(1);
      }
      block = { window: attrs.window, mode: attrs.mode, status: attrs.status, lines: [] };
      continue;
    }
    if (block !== null && line === '```') {
      parts.push({
        code: block.lines.join('\n'),
        window: block.window,
        mode: block.mode,
        status: block.status,
      });
      block = null;
      continue;
    }
    if (block !== null) {
      block.lines.push(line);
      continue;
    }
    buf.push(line);
  }
  flush();
  // the page says "paste" for a terminal; here the learner clicks
  for (const p of parts)
    if (p.text)
      p.text = p.text
        .replace(/\bpasted\b/g, 'run')
        .replace(/\bPaste\b/g, 'Run')
        .replace(/\bpaste\b/g, 'run');
  return { title, parts };
}

const read = (f) =>
  parse(
    fs
      .readFileSync(path.join(dir, f), 'utf8')
      .split('@VERSION@')
      .join(VERSION)
      .split('@RELEASE@')
      .join(RELEASE),
  );
const stepFiles = fs
  .readdirSync(dir)
  .filter((f) => /^s\d.*\.md$/.test(f))
  .sort();
const pick = (re) => stepFiles.filter((f) => re.test(f));

// ---- who acts

// Each window has a word that goes to it (a function in windows.rc, so a click is enough) and a number for Ctrl-b.
// The scenario test finds the words as click-to-run blocks of one line: carol, alice, bob or chain. The chain runs as a
// background job of its window, so that window keeps its prompt and the words work there too.
const WINDOW = { alice: 0, bob: 1, chain: 2, carol: 3 };
const NAME = { alice: 'Alice', bob: 'Bob', carol: 'Carol', chain: 'Chain' };
const OWNER = { alice: "Alice's", bob: "Bob's", chain: "the chain's", carol: "Carol's" };
const goTo = (w, lead = '') =>
  `${lead}Go to ${OWNER[w]} window: click \`${w}\`, or press \`Ctrl-b ${WINDOW[w]}\`.\n\n\`\`\`bash\n${w}\n\`\`\`{{exec}}`;

// ---- who acts: the window written on each block

// ---- pages

const pages = []; // { title, md }
let current = 'alice';

// A block that is only a person's word, preceded by the paragraph "**Now Bob.**", names the person from there on.
const PEOPLE = ['alice', 'bob', 'carol', 'chain'];
function markWords(page, file) {
  page.parts.forEach((p, i) => {
    if (p.code === undefined || p.mode === 'show' || !PEOPLE.includes(p.code.trim())) return;
    if (p.window !== p.code.trim()) {
      console.error(
        `killercoda.js: ${file}: the block ${p.code.trim()} names window ${p.window}, want ${p.code.trim()}`,
      );
      process.exit(1);
    }
    const before = page.parts[i - 1];
    const caption = `**Now ${NAME[p.code.trim()]}.**`;
    if (!before || before.text === undefined || !before.text.trimEnd().endsWith(caption)) {
      console.error(
        `killercoda.js: ${file}: the block ${p.code.trim()} must come right after the paragraph ${caption}`,
      );
      process.exit(1);
    }
    before.text = before.text.trimEnd().slice(0, -caption.length);
    p.word = p.code.trim();
  });
}

function render(page, { actors }) {
  // every exec block runs in the window its fence names
  let md = '';
  for (const p of page.parts) {
    if (p.text !== undefined) {
      md += `${p.text}\n`;
      continue;
    }
    if (p.mode === 'show') {
      md += `\`\`\`bash\n${p.code}\n\`\`\`\n`;
      continue;
    }
    if (p.word) {
      // the step file names the person: the learner moves to that window, unless already there
      if (p.word !== current) md += `\n${goTo(p.word, `**Now ${NAME[p.word]}.** `)}\n\n`;
      current = p.word;
      continue;
    }
    if (!actors && p.window !== current) {
      md += `\n${goTo(p.window)}\n\n`;
      current = p.window;
    }
    if (actors && p.window !== current) {
      console.error(
        `killercoda.js: a block of ${NAME[p.window]} comes while the page has named ${NAME[current]}; put "**Now ${NAME[p.window]}.**" and the block ${p.window} above it:\n${p.code}`,
      );
      process.exit(1);
    }
    const status = p.status ? `# Expected exit status: ${p.status}\n` : '';
    md += `\`\`\`bash\n${status}${p.code}\n\`\`\`{{exec}}\n`;
  }
  return `${md.replace(/\n{3,}/g, '\n\n').trim()}\n`;
}

// -- tmux, with the commands used here (written for this scenario)
pages.push({
  title: 'tmux, in four words',
  md: `This scenario runs in **tmux**, a program that keeps several terminals in one. The setup has made four windows, each with its own shell:

- \`0\` \`alice\`: Alice's window, in her own directory with her own vault and receipts
- \`1\` \`bob\`: Bob's window, in his own directory
- \`2\` \`chain\`: the private chain
- \`3\` \`carol\`: Carol creates the registry with her own wallet

Three people, three directories: each keeps the files of what they do, exactly as three people on three machines would. A bar at the bottom of the terminal lists the windows with their numbers and marks the one you are in with a \`*\`.

Go inside:

\`\`\`bash
tmux attach -t demo
\`\`\`{{exec}}

From here on every command you click runs in the window you are in. To change window, type the window's name: \`carol\`, \`alice\`, \`bob\` or \`chain\`. Wherever the story passes from one person to the other, the page gives you the word to click.

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
  pages.push({
    title: pg.title
      .replace(/^Before you start: two programs, one registry/, 'Two programs, one registry')
      .replace(/^Before you start: two ways to sign/, 'Two ways to sign'),
    md: render(pg, { actors: false }),
  });
}

// The setup is the same source page in every tutorial face.
{
  const pg = read('s00b-wallets-and-devnet.md');
  markWords(pg, 's00b-wallets-and-devnet.md');
  pages.push({ title: pg.title, md: render(pg, { actors: false }) });
}

// -- the steps
const stepPages = [...pick(/^s(0[1-9]|1[0-7])-/), ...pick(/^s2[01]-/)];
for (const f of stepPages) {
  const pg = read(f);
  markWords(pg, f);

  pages.push({ title: pg.title, md: render(pg, { actors: !/^s20-/.test(f) }) });
}

// ---- output

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(course, { recursive: true });
const w = (p, s) => {
  fs.mkdirSync(path.dirname(path.join(out, p)), { recursive: true });
  fs.writeFileSync(path.join(out, p), s);
};

w(
  'index.json',
  `${JSON.stringify(
    {
      title: 'Singular Demo 1, step by step on a private chain',
      description:
        'Play Singular Demo 1 yourself on a private Cardano test chain, as Alice and as Bob in three actor windows: book keys, fold them, change and remove them, clean up an expired registration and take one back. Ubuntu, nothing to install.',
      details: {
        intro: {
          text: 'intro/text.md',
          foreground: 'intro/foreground.sh',
          background: 'intro/background.sh',
        },
        steps: pages.map((p, i) => ({ title: p.title, text: `step${i + 1}/text.md` })),
        finish: { text: 'finish/text.md' },
      },
      backend: { imageid: 'ubuntu-4GB' },
    },
    null,
    2,
  )}\n`,
);

for (const [i, p] of pages.entries()) w(`step${i + 1}/text.md`, p.md);

w(
  'intro/text.md',
  `Singular keeps a registry of keys on Cardano. Here you play its Demo 1 yourself on a **private test chain**: nothing touches a public network, and nothing is installed on this machine. The project is at https://github.com/lambdasistemi/singular and its documentation at https://lambdasistemi.github.io/singular/ ; its own page for this journey is https://lambdasistemi.github.io/singular/docs/demo1-devnet/

You play **Carol**, **Alice** and **Bob**, each in their own directory and tmux window, with a fourth window for the chain. You switch windows by clicking a word: \`carol\`, \`alice\`, \`bob\` or \`chain\`. You will, step by step:

- create three wallets and a registry,
- book a key, fold it into the registry (the fold finds it on the chain), change its payload and permanently terminate it, reading it back from the chain after each change,
- let a request go stale and clean it up, and take another one back before its window closes.

Every command is shown in full with what it does. Click a command to run it, read what comes back, and go on. Two steps wait a few minutes for the chain's own clock, and the page says when.

The machine lasts one hour at most and is deleted when you close this tab. The whole journey takes about 15 minutes. If the chain on the machine is ever stopped, restart the scenario: a new machine starts from the beginning.

A kit with the programs, and tmux, are being installed in the background. When the terminal says \`Ready\`, start.
`,
);

// The scripts of the play are the files in play/: the Codespaces tutorial runs the same ones. The setup of the
// machine writes them out as they are and runs them.
const PLAYFILES = [
  'install-kit.sh',
  'prepare.sh',
  'helpers.sh',
  'stepper.sh',
  'windows.rc',
  'windows.sh',
];
const embed = (files) =>
  files
    .map((f) => {
      const text = fs.readFileSync(path.join(dir, 'play', f), 'utf8');
      if (text.includes('PLAY_EOF')) {
        console.error(`killercoda.js: play/${f} contains the heredoc delimiter`);
        process.exit(1);
      }
      return `cat > /root/play/${f} <<'PLAY_EOF'\n${text.replace(/\n*$/, '\n')}PLAY_EOF\n`;
    })
    .join('');

w(
  'intro/background.sh',
  `#!/bin/bash
set -x
export DEBIAN_FRONTEND=noninteractive
mkdir -p /root/play
${embed(PLAYFILES)}bash /root/play/install-kit.sh ${RELEASE} /root
# tmux holds the four windows
apt-get update -qq && apt-get install -y -qq tmux
tmux -V
bash /root/play/prepare.sh /root/${KIT} /root/singular-demo-run
touch /tmp/finished
`,
);

w(
  'intro/foreground.sh',
  `echo "Downloading and checking the demo kit, and installing tmux..."
while [ ! -f /tmp/finished ]; do sleep 1; done
bash /root/play/windows.sh /root/singular-demo-run
echo "Ready."
`,
);

w(
  'finish/text.md',
  `That was the whole of Demo 1: a key booked, folded, changed and removed, and read back after each change; an expired registration cleaned up after its two windows; a request taken back inside its window. Everything ran on a private test chain, with Carol, Alice and Bob each in their own window.

**Stop the chain.**

${goTo('chain')}

The chain is job 1 of its window. Stop it:

\`\`\`bash
kill %1
\`\`\`{{exec}}

The window keeps its shell.

The chain's messages are in \`~/singular-demo-run/devnet.log\`. Alice's receipts are in \`~/singular-demo-run/alice/receipts\`; Bob's receipts, the transactions he built (\`bundles/\`) and his signatures (\`witnesses/\`) are in \`~/singular-demo-run/bob\`.
`,
);

console.log(`scenario written to ${out}: ${pages.length} steps`);

// ---- the second scenario: the kit's annotated script, run as it is
const script = path.join(course, 'demo1-script');
fs.rmSync(script, { recursive: true, force: true });
const ws = (p, t) => {
  fs.mkdirSync(path.dirname(path.join(script, p)), { recursive: true });
  fs.writeFileSync(path.join(script, p), t);
};
ws(
  'index.json',
  `${JSON.stringify(
    {
      title: 'Singular Demo 1 on a private devnet',
      description: `The Demo 1 script of Singular ${VERSION} on a private Cardano test chain, on Ubuntu, with nothing to install.`,
      details: {
        intro: {
          text: 'intro/text.md',
          foreground: 'intro/foreground.sh',
          background: 'intro/background.sh',
        },
        steps: [{ title: 'Run the demo', text: 'step1/text.md' }],
        finish: { text: 'finish/text.md' },
      },
      backend: { imageid: 'ubuntu-4GB' },
    },
    null,
    2,
  )}\n`,
);
ws(
  'intro/text.md',
  `This machine is a plain Ubuntu. A kit with the Singular programs, a private Cardano test chain and an annotated script of Demo 1 is being downloaded and unpacked in the background; the programs stay in their unpacked folder. Playback uses an unprivileged demo account.

When the terminal says \`Ready\`, go to the next step.
`,
);
ws(
  'intro/background.sh',
  `#!/bin/bash
set -x
mkdir -p /root/play
apt-get update -qq && apt-get install -y -qq passwd util-linux
id singular-demo >/dev/null 2>&1 || useradd --create-home --shell /bin/bash singular-demo
${embed(['install-kit.sh'])}bash /root/play/install-kit.sh ${RELEASE} /home/singular-demo
chown -R singular-demo:singular-demo /home/singular-demo/${KIT}
touch /tmp/finished
`,
);
ws(
  'intro/foreground.sh',
  `echo "Downloading and checking the demo kit..."
while [ ! -f /tmp/finished ]; do sleep 1; done
echo "Ready."
`,
);
ws(
  'step1/text.md',
  `Run the annotated script. It starts a private test chain, creates three wallets, and plays all 16 steps of Demo 1. Straight through, it takes about 5 minutes, two of them real waits on the chain (the registry's windows are set to 60 and 30 seconds here). Choose one of the two ways to run it.

**Straight through.** The script runs in the background and writes everything to a log, and the terminal follows the log. So pressing Ctrl+C, or copying text with it, only stops the following: the demo carries on.

\`\`\`bash
cd /home/singular-demo/${KIT} && (runuser -u singular-demo -- env DEMO_MODE=continuous PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 setsid nohup ./demo.sh > demo.log 2>&1 &) ; sleep 1; tail -n +1 -f demo.log
\`\`\`{{exec}}

To copy text from the terminal, select it and use Ctrl+Shift+C, or right-click.

If you stopped following, pick the log up again from the start:

\`\`\`bash
tail -n +1 -f /home/singular-demo/${KIT}/demo.log
\`\`\`{{exec}}

When the log ends with the last step, the run is over and the chain it started has been stopped.

**Pausing before each step.** The script runs in the foreground in this terminal. Before each step it says what the step does and waits for Enter. Steps 4, 13 and 16 run without a pause, because a booking must be folded before its processing deadline. Here Ctrl+C stops the run.

\`\`\`bash
cd /home/singular-demo/${KIT} && runuser -u singular-demo -- env DEMO_MODE=pause PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./demo.sh
\`\`\`{{exec}}

Run one of the two: a second run in the same folder is refused, because its wallets belong to the first chain. The script asks for no passphrase; the wallets use throwaway passphrases.
`,
);
ws(
  'finish/text.md',
  `That was all 16 steps: a key booked, folded, changed and removed, and read back after each change; an expired registration cleaned up; a request taken back. Everything ran on a private test chain.

The receipts are in \`/home/singular-demo/${KIT}/singular-demo-run\`.
`,
);
console.log(`script scenario written to ${script}`);
