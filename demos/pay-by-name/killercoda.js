// Builds the Killercoda scenario of the pay-by-name story (Ubuntu, no Nix) from the step files s*.md.
//   node demos/pay-by-name/killercoda.js ROOT   writes ROOT/killercoda/pay-by-name-steps
// (the structure.json files that list the scenarios are written by demos/structure.js)
//
// The scenario runs in tmux with five windows, made by the setup: 0 `carol`, 1 `alice`, 2 `dave`, 3 `bob` and 4 `chain`
// (the private chain, a background job of its window). Each person works in a folder of their own, with their own vault and
// their own settings file. Every "bash" block of the step files carries its window as `{ window=... }`, as the
// tutorial-stepper format specifies; it becomes a block the learner runs with a click, in the window of the person
// who acts. Blocks marked `{ mode=show }` are shown only; `{ mode=observe }` blocks run like commands. The paragraph and
// the five blocks that load the stepper's shell setup (`. ../stepper.sh`, `. ./stepper.sh`) are stepper-only and are skipped here:
// Killercoda's windows already have their setup from windows.rc. Wherever the person changes, the page gives the word
// to click (carol, alice, dave, bob or chain); the keys Ctrl-b 0 to 4 are only an extra, nothing needs a keyboard.
const fs = require('node:fs');
const path = require('node:path');

const dir = __dirname;
const root = process.argv[2];
if (!root) {
  console.error('usage: node killercoda.js ROOT');
  process.exit(2);
}
const course = path.join(root, 'killercoda');
const out = path.join(course, 'pay-by-name-steps');

const VERSION = require('../demo1/version.js');
const RELEASE = require('../demo1/release.js');
const KIT = `singular-demo-${RELEASE}-x86_64-linux`;

// ---- the windows

const WINDOWS = ['carol', 'alice', 'dave', 'bob', 'chain'];
const NAME = { carol: 'Carol', alice: 'Alice', dave: 'Dave', bob: 'Bob' };
const WHOSE = {
  carol: "Carol's",
  alice: "Alice's",
  dave: "Dave's",
  bob: "Bob's",
  chain: "the chain's",
};
const goTo = (w, lead = '') =>
  `${lead}Go to ${WHOSE[w]} window: click \`${w}\`, or press \`Ctrl-b ${WINDOWS.indexOf(w)}\`.\n\n\`\`\`bash\n${w}\n\`\`\`{{exec}}`;

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
      if (!attrs.window || !WINDOWS.includes(attrs.window)) {
        console.error(
          `killercoda.js:${n + 2}: fence without window=carol|alice|dave|bob|chain: ${line}`,
        );
        process.exit(1);
      }
      if (attrs.mode !== undefined && attrs.mode !== 'show' && attrs.mode !== 'observe') {
        console.error(`killercoda.js:${n + 2}: bad mode ${attrs.mode}: ${line}`);
        process.exit(1);
      }
      block = { window: attrs.window, mode: attrs.mode, lines: [] };
      continue;
    }
    if (block === null && line.startsWith('```bash')) {
      console.error(
        `killercoda.js:${n + 2}: a block must open with \`\`\`bash { window=... }: ${line}`,
      );
      process.exit(1);
    }
    if (block !== null && line === '```') {
      parts.push({ code: block.lines.join('\n'), window: block.window, mode: block.mode });
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

// ---- pages

function render(page) {
  let md = '';
  let current = render.current;
  let chunkStart = -1; // where the text chunk just before this block starts, -1 when a block came last
  for (const p of page.parts) {
    if (p.text !== undefined) {
      // The stepper's shell-setup paragraph runs only on the stepper; Killercoda's windows already source windows.rc.
      const text = p.text
        .replace(/\*\*Load the shell setup in each window\.\*\*[^\n]*\n\n?/, '')
        .replace(/\n{3,}/g, '\n\n');
      chunkStart = md.length;
      md += `${text}\n`;
      continue;
    }
    // The stepper's shell-setup loads run only on the stepper; Killercoda's windows already source windows.rc.
    if (p.code.trim() === '. ../stepper.sh' || p.code.trim() === '. ./stepper.sh') {
      chunkStart = -1;
      continue;
    }
    if (p.mode === 'show') {
      md += `\`\`\`bash\n${p.code}\n\`\`\`\n`;
      chunkStart = -1;
      continue;
    }
    if (p.window !== current) {
      const line = `${goTo(p.window, `**Now ${NAME[p.window] ?? 'the chain'}.** `)}\n\n`;
      // the words come before the caption of the block (the last paragraph of the text above it), so the learner
      // is in the right window when reading what that person does
      if (chunkStart >= 0) {
        const cut = md.trimEnd().lastIndexOf('\n\n');
        const at = cut >= chunkStart ? cut + 2 : chunkStart;
        md = `${md.slice(0, at).replace(/\n*$/, '\n\n')}${line}${md.slice(at)}`;
      } else {
        md += `\n${line}`;
      }
      current = p.window;
    }
    chunkStart = -1;
    md += `\`\`\`bash\n${p.code}\n\`\`\`{{exec}}\n`;
  }
  render.current = current;
  return `${md.replace(/\n{3,}/g, '\n\n').trim()}\n`;
}
render.current = 'carol'; // the learner attaches to tmux in the first window

const pages = []; // { title, md }

pages.push({
  title: 'tmux, in five words',
  md: `This scenario runs in **tmux**, a program that keeps several terminals in one. The setup has made five windows, each with its own shell:

- \`0\` \`carol\`: Carol's window, in her own folder with her own vault
- \`1\` \`alice\`: Alice's window
- \`2\` \`dave\`: Dave's window
- \`3\` \`bob\`: Bob's window
- \`4\` \`chain\`: the private chain

Four people, four folders: each keeps the files of what they do, exactly as four people on four machines would. Two more folders stand for what they share: \`publish\`, the page where Carol publishes the registry, and \`messages\`, where they leave each other messages. A bar at the bottom of the terminal lists the windows with their numbers and marks the one you are in with a \`*\`.

Go inside:

\`\`\`bash
tmux attach -t demo
\`\`\`{{exec}}

From here on every command you click runs in the window you are in. To change window, type the window's name: \`carol\`, \`alice\`, \`dave\`, \`bob\` or \`chain\`. Wherever the story passes from one person to another, the page gives you the word to click.

**Try it.** Go to Bob's window; the \`*\` in the bar moves to \`bob\`:

\`\`\`bash
bob
\`\`\`{{exec}}

And back to Carol's:

\`\`\`bash
carol
\`\`\`{{exec}}

With a keyboard, \`Ctrl-b 0\` to \`Ctrl-b 4\` go to the same windows.
`,
});

for (const f of stepFiles) {
  const pg = read(f);
  pages.push({ title: pg.title, md: render(pg) });
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
      title: 'Pay by name on a private chain',
      description:
        'Bob owes money to Alice and Dave and does not know where they receive it. He pays them by name, in a registry that Carol made. Play the five of them yourself, in five tmux windows, on a private Cardano test chain. Ubuntu, nothing to install.',
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
  `Bob owes money to Alice and to Dave, and he does not know where either of them receives it. Here he pays them **by name**. The names are in a registry on Cardano that Carol made and published: anyone can put a name in it, and the person who does is the name's controller. Bob pays the name, the money waits in a script that reads the registry, and whoever moves it can only send it to the address that is registered under the name at that moment.

You play all five of them on a **private test chain**: nothing touches a public network, and nothing is installed on this machine beyond tmux. The project is at https://github.com/lambdasistemi/singular and its documentation at https://lambdasistemi.github.io/singular/ . Each person has a tmux window of their own, and you switch between them by clicking a word: \`carol\`, \`alice\`, \`dave\`, \`bob\` or \`chain\`. You will, step by step:

- make five wallets and start the chain,
- let Carol create and publish the registry, and let Alice, Bob and Dave each check it,
- let Alice and Dave put their names in it, and let Bob ask for them,
- let Bob pay both names, and let Alice and Dave move their money,
- let Alice change her address, and see a move to the old one refused.

Every command is shown in full with what it does. Click a command to run it, read what comes back, and go on.

The machine lasts one hour at most and is deleted when you close this tab. The whole journey takes about 20 minutes. If the chain on the machine is ever stopped, restart the scenario: a new machine starts from the beginning.

A kit with the programs, node included, and tmux are being installed in the background. When the terminal says \`Ready\`, start.
`,
);

// The scripts of the play are files: the scripts of Demo 1's play that do not depend on its people, and this demo's own.
// The setup of the machine writes them out as they are and runs them.
const PLAY = [
  [path.join(dir, '..', 'demo1', 'play'), ['install-kit.sh', 'helpers.sh']],
  [path.join(dir, 'play'), ['prepare.sh', 'windows.rc', 'windows.sh']],
];
const embed = () =>
  PLAY.flatMap(([from, files]) =>
    files.map((f) => {
      const text = fs.readFileSync(path.join(from, f), 'utf8');
      if (text.includes('PLAY_EOF')) {
        console.error(`killercoda.js: play/${f} contains the heredoc delimiter`);
        process.exit(1);
      }
      return `cat > /root/play/${f} <<'PLAY_EOF'\n${text.replace(/\n*$/, '\n')}PLAY_EOF\n`;
    }),
  ).join('');

w(
  'intro/background.sh',
  `#!/bin/bash
set -x
export DEBIAN_FRONTEND=noninteractive
mkdir -p /root/play
${embed()}bash /root/play/install-kit.sh ${RELEASE} /root
# tmux holds the five windows (the kit brings its own node, which runs its tools)
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
  `That was the whole story: a registry made and published, two names put in it, a payment to both names, the money moved to the addresses registered under them, and one address changed. Everything ran on a private test chain.

**Stop the chain.**

${goTo('chain')}

The chain is job 1 of its window. Stop it:

\`\`\`bash
kill %1
\`\`\`{{exec}}

The window keeps its shell.

The chain's messages are in \`~/singular-demo-run/devnet.log\`. Each person's files are in their own folder under \`~/singular-demo-run\`; Carol's page is \`publish/registry.json\` and the messages are in \`messages\`.
`,
);

console.log(`scenario written to ${out}: ${pages.length} steps`);
