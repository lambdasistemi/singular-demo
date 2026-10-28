// Writes the two structure files Killercoda reads, the only writer of both: structure.json at the root names the course
// folder, and killercoda/structure.json lists every scenario of it, in this order.
//   node demos/structure.js ROOT
const fs = require('node:fs');
const path = require('node:path');

const root = process.argv[2];
if (!root) {
  console.error('usage: node structure.js ROOT');
  process.exit(2);
}
// Each scenario is a folder of killercoda/ that a generator writes.
const SCENARIOS = ['demo1-steps', 'demo1-script'];

const course = path.join(root, 'killercoda');
fs.mkdirSync(course, { recursive: true });
for (const s of SCENARIOS) {
  if (!fs.existsSync(path.join(course, s, 'index.json'))) {
    console.error(
      `structure.js: ${s} has not been generated (no ${path.join(course, s, 'index.json')})`,
    );
    process.exit(1);
  }
}
const write = (file, value) => fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
write(path.join(root, 'structure.json'), {
  items: [{ path: 'killercoda', title: 'Singular demos' }],
});
write(path.join(course, 'structure.json'), { items: SCENARIOS.map((s) => ({ path: s })) });
console.log(`structure files written: ${SCENARIOS.join(', ')}`);
