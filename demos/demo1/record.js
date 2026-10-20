// Writes "a run": the steps of the tutorial with, under each command, what it printed in a real run.
//   node demos/demo1/record.js LOG OUT.md
// LOG is the log of test.sh, which has a marker line "@@ BLOCK file n" before each block. The commands are the
// blocks of the step files; the results are the lines up to the next marker. Blocks shown but not run ("bash skip")
// have no result.
const fs = require('node:fs');
const path = require('node:path');
const VERSION = require('./version.js');

const [logFile, outFile] = process.argv.slice(2);
if (!logFile || !outFile) {
  console.error('usage: node record.js LOG OUT.md');
  process.exit(2);
}
const dir = __dirname;

// the log, cut at the markers
const results = new Map();
let key = null;
for (const raw of fs.readFileSync(logFile, 'utf8').split('\n')) {
  const m = raw.match(/^@@ BLOCK (\S+) (\d+)$/);
  if (m) {
    key = `${m[1]} ${m[2]}`;
    results.set(key, []);
    continue;
  }
  if (key !== null) results.get(key).push(raw);
}
// a progress line that rewrites itself with \r shows only its last state
const clean = (lines) =>
  lines
    .map(
      (l) =>
        l
          .split('\r')
          .filter((x) => x !== '')
          .pop() ?? '',
    )
    .join('\n')
    .replace(/^\n+|\n+$/g, '');

const files = fs
  .readdirSync(dir)
  .filter((f) => /^s\d.*\.md$/.test(f))
  .sort();
let md =
  "# Demo 1, a run\n\nThe tutorial's steps as they ran, with the result under each command. A real run of the release " +
  VERSION +
  ' on a private chain, made by the continuous-integration workflow of this repository: every command is the one in the tutorial, and every result is what it printed.\n';
let blocks = 0,
  withResult = 0;
for (const f of files) {
  const lines = fs
    .readFileSync(path.join(dir, f), 'utf8')
    .split('@VERSION@')
    .join(VERSION)
    .split('\n');
  const title = lines.shift().replace(/^#\s+/, '');
  md += `\n## ${title}\n`;
  let n = 0,
    inBlock = null,
    _buf = [];
  for (const line of lines) {
    const open = line.match(/^```bash(?: (skip))?$/);
    if (inBlock === null && open) {
      inBlock = { skip: !!open[1], code: [] };
      if (!open[1]) n++;
      continue;
    }
    if (inBlock !== null && line === '```') {
      md += `\n\`\`\`bash\n${inBlock.code.join('\n')}\n\`\`\`\n`;
      if (!inBlock.skip) {
        blocks++;
        const r = results.get(`${f} ${n}`);
        if (r === undefined) {
          console.error(`record.js: no result in the log for ${f} block ${n}`);
          process.exit(1);
        }
        const out = clean(r);
        if (out) {
          withResult++;
          md += `\nResult:\n\n\`\`\`text\n${out}\n\`\`\`\n`;
        }
      }
      inBlock = null;
      continue;
    }
    if (inBlock !== null) {
      inBlock.code.push(line);
      continue;
    }
    md += `${line}\n`;
  }
}
fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, md);
console.log(`record.js: ${blocks} blocks, ${withResult} with a result, written to ${outFile}`);
