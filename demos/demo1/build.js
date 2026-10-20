// Builds DEMO.md and demo.html from the step files in this folder.
// A step file is: "# title", prose, and fenced blocks. A block fenced "bash" is run by test.sh;
// "bash skip" is shown but not run (opening a shell, the kit alternative).
const fs = require('fs');
const path = require('path');

const dir = __dirname;
const VERSION = require('./version.js');
const files = fs.readdirSync(dir).filter((f) => /^s\d.*\.md$/.test(f)).sort();

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const link = (t) => t.replace(/https?:\/\/[^\s<>]*[^\s<>.,;:)]/g, (u) => '<a href="' + u + '">' + u + '</a>');
const inline = (s) => esc(s).split('`').map((t, i) => i % 2 ? '<code>' + t + '</code>' : link(t).replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')).join('');

function parse(text) {
  const lines = text.split('\n');
  const title = lines.shift().replace(/^#\s+/, '');
  const parts = [];
  let para = [];
  let code = null;
  const flush = () => { if (para.length) { const isList = para.every((l) => l.startsWith('- ')); parts.push({ kind: isList ? 'ul' : 'p', text: para.join(' '), raw: para.slice(), items: isList ? para.map((l) => l.slice(2)) : [] }); para = []; } };
  for (const line of lines) {
    const open = line.match(/^```(\S*)\s*(\S*)$/);
    if (code === null && open && open[1] !== '') {
      flush();
      code = { kind: 'code', lang: open[1], mode: open[2], lines: [] };
    } else if (code !== null && line === '```') {
      parts.push(code); code = null;
    } else if (code !== null) {
      code.lines.push(line);
    } else if (line.trim() === '') {
      flush();
    } else {
      para.push(line.trim());
    }
  }
  flush();
  return { title, parts };
}

const steps = files.map((f) => ({ file: f, ...parse(fs.readFileSync(path.join(dir, f), 'utf8').split('@VERSION@').join(VERSION)) }));

// DEMO.md: GitHub shows a copy button on every code block.
let md = '# Singular Demo 1, step by step\n\n' +
  'Every block has a copy button: copy it, paste it into the terminal, run the next one. ' +
  'The blocks are meant to be pasted in order into one terminal. [A page with bigger buttons and a done mark per step](interactive.html) is the same tutorial.\n\n' +
  'Release ' + VERSION + '. Everything runs on a private test chain. The project is at ' + 'https://github.com/lambdasistemi/singular' + ' and its documentation at ' + 'https://lambdasistemi.github.io/singular/' + '.\n';
for (const s of steps) {
  md += '\n## ' + s.title + '\n';
  for (const p of s.parts) {
    if (p.kind === 'p' || p.kind === 'ul') md += '\n' + p.raw.join('\n') + '\n';
    // The empty last line makes GitHub's copy button end the copied text with a line return.
    else md += '\n```bash\n' + p.lines.join('\n') + '\n\n```\n';
  }
}
fs.writeFileSync(path.join(dir, 'DEMO.md'), md);

// demo.html: one self-contained page with a Copy button per block.
let html = '';
steps.forEach((s, i) => {
  html += '<section class="step" id="s' + i + '">\n<h2><span class="num">' + (i + 1) + '</span>' + inline(s.title) +
    '<label class="done"><input type="checkbox" data-step="' + i + '"> done</label></h2>\n';
  for (const p of s.parts) {
    if (p.kind === 'ul') html += '<ul>' + p.items.map((it) => '<li>' + inline(it) + '</li>').join('') + '</ul>\n';
    else if (p.kind === 'p') html += '<p>' + inline(p.text) + '</p>\n';
    else html += '<div class="block"><button class="copy" type="button">Copy</button><pre><code>' + esc(p.lines.join('\n')) + '</code></pre></div>\n';
  }
  html += '</section>\n';
});
const label = (t) => /^Step \d+/.test(t) ? t.match(/^Step (\d+)/)[1] : /^Extra:/.test(t) ? t.replace(/^Extra: (look at |look inside |if you open a )?(the )?/, '').slice(0, 14) : /^Before you start: open/.test(t) ? 'Shell' : /^Before you start: two programs/.test(t) ? 'Programs' : /^Before you start: two ways/.test(t) ? 'Signing' : /^Before you start/.test(t) ? 'Setup' : /^Finish/.test(t) ? 'End' : t.slice(0, 14);
const nav = steps.map((s, i) => '<a href="#s' + i + '">' + esc(label(s.title)) + '</a>').join('');
const template = fs.readFileSync(path.join(dir, 'template.html'), 'utf8');
const page = template.replace('<!--NAV-->', nav).replace('<!--STEPS-->', html);
fs.writeFileSync(path.join(dir, 'demo.html'), page);
console.log('built DEMO.md and demo.html from ' + steps.length + ' step files');
