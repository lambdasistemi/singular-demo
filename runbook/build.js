// Builds DEMO.md and demo.html from the step files in this folder.
// A step file is: "# title", prose, and fenced blocks. A block fenced "bash" is run by test.sh;
// "bash skip" is shown but not run (opening a shell, the kit alternative).
const fs = require('fs');
const path = require('path');

const dir = __dirname;
const files = fs.readdirSync(dir).filter((f) => /^s\d.*\.md$/.test(f)).sort();

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const inline = (s) => esc(s).replace(/`([^`]+)`/g, '<code>$1</code>');

function parse(text) {
  const lines = text.split('\n');
  const title = lines.shift().replace(/^#\s+/, '');
  const parts = [];
  let para = [];
  let code = null;
  const flush = () => { if (para.length) { parts.push({ kind: 'p', text: para.join(' ') }); para = []; } };
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

const steps = files.map((f) => ({ file: f, ...parse(fs.readFileSync(path.join(dir, f), 'utf8')) }));

// DEMO.md: GitHub shows a copy button on every code block.
let md = '# Singular Demo 1, step by step\n\n' +
  'Every grey block has a copy button on GitHub: copy it, paste it into the terminal, run the next one. ' +
  'The blocks are meant to be pasted in order into one terminal. A page with bigger buttons and a done mark per step is in `demo.html`.\n\n' +
  'Release v0.12.0. Everything runs on a private test chain.\n';
for (const s of steps) {
  md += '\n## ' + s.title + '\n';
  for (const p of s.parts) {
    if (p.kind === 'p') md += '\n' + p.text + '\n';
    // The empty last line makes GitHub's copy button end the copied text with a line return.
    else md += '\n```bash\n' + p.lines.join('\n') + '\n\n```\n';
  }
}
fs.writeFileSync(path.join(dir, '..', 'DEMO.md'), md);

// demo.html: one self-contained page with a Copy button per block.
let html = '';
steps.forEach((s, i) => {
  html += '<section class="step" id="s' + i + '">\n<h2><span class="num">' + (i + 1) + '</span>' + inline(s.title) +
    '<label class="done"><input type="checkbox" data-step="' + i + '"> done</label></h2>\n';
  for (const p of s.parts) {
    if (p.kind === 'p') html += '<p>' + inline(p.text) + '</p>\n';
    else html += '<div class="block"><button class="copy" type="button">Copy</button><pre><code>' + esc(p.lines.join('\n')) + '</code></pre></div>\n';
  }
  html += '</section>\n';
});
const nav = steps.map((s, i) => '<a href="#s' + i + '">' + esc(s.title.replace(/^Step /, '').replace(/:.*/, '').replace(/^Before you start/, 'Start').replace(/^Finish/, 'End')) + '</a>').join('');
const template = fs.readFileSync(path.join(dir, 'template.html'), 'utf8');
const page = template.replace('<!--NAV-->', nav).replace('<!--STEPS-->', html);
fs.writeFileSync(path.join(dir, '..', 'demo.html'), page);
// index.html is the same page, so the site root (GitHub Pages) opens it.
fs.writeFileSync(path.join(dir, '..', 'index.html'), page);
console.log('built DEMO.md and demo.html from ' + steps.length + ' step files');
