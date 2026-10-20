/* All tutorial content is loaded from the checked-in scenario files. */
// The terminal is light by default, like the page beside it. A button in its header switches it to dark, and the choice is kept.
const terminalThemes = {
  light: {
    background: '#fbfcf8',
    foreground: '#243c32',
    cursor: '#305a35',
    cursorAccent: '#fbfcf8',
    selectionBackground: '#cfe3c4',
    black: '#243c32',
    red: '#b3261e',
    green: '#2e6b34',
    yellow: '#8a6100',
    blue: '#1f5fa8',
    magenta: '#8b3a8f',
    cyan: '#0f6e73',
    white: '#6d7a72',
    brightBlack: '#5b6e63',
    brightRed: '#d4352b',
    brightGreen: '#3f8a46',
    brightYellow: '#a87800',
    brightBlue: '#2b78cf',
    brightMagenta: '#a64ca9',
    brightCyan: '#1a8a90',
    brightWhite: '#3a4a41',
  },
  dark: {
    background: '#101b1b',
    foreground: '#e0eae3',
    cursor: '#b3e894',
    selectionBackground: '#47634e',
    green: '#a3d98c',
  },
};
const storageKey = 'tutorial-terminal-theme';
let terminalMode = 'light';
try {
  if (localStorage.getItem(storageKey) === 'dark') terminalMode = 'dark';
} catch {}
const terminal = new Terminal({
  cursorBlink: true,
  fontSize: 14,
  lineHeight: 1.3,
  fontFamily: '"DejaVu Sans Mono", "Liberation Mono", monospace',
  scrollback: 5000,
  // colours a program picks from the 256-colour range (the prompt, jq) stay readable on either background
  minimumContrastRatio: 4.5,
  theme: terminalThemes[terminalMode],
});
const fit = new FitAddon.FitAddon();
terminal.loadAddon(fit);
terminal.open(document.querySelector('#terminal'));
const themeToggle = document.querySelector('#theme-toggle');
const applyTerminalMode = () => {
  document.documentElement.dataset.terminal = terminalMode;
  terminal.options.theme = terminalThemes[terminalMode];
  themeToggle.textContent = terminalMode === 'dark' ? 'Light terminal' : 'Dark terminal';
};
themeToggle.addEventListener('click', () => {
  terminalMode = terminalMode === 'dark' ? 'light' : 'dark';
  try {
    localStorage.setItem(storageKey, terminalMode);
  } catch {}
  applyTerminalMode();
});
applyTerminalMode();
const $ = (selector) => document.querySelector(selector);
let lessons = [],
  current = 0,
  socket,
  token,
  ready = false,
  connected = false,
  exited = false;
const ran = new Set();
marked.use({
  renderer: {
    html() {
      return '';
    },
  },
});

const icons = {
  run: '<path d="m8 5 11 7-11 7Z"/>',
  again: '<path d="M3 10a9 9 0 1 1 2 8M3 4v6h6"/>',
  copy: '<rect x="8" y="8" width="12" height="13" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  previous: '<path d="m14 6-6 6 6 6"/>',
  next: '<path d="m10 6 6 6-6 6"/>',
  stop: '<rect x="6" y="6" width="12" height="12" rx="1"/>',
};
function setIcon(button, icon, label) {
  button.innerHTML = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[icon]}</svg>`;
  button.title = label;
  button.setAttribute('aria-label', label);
}
setIcon($('#previous'), 'previous', 'Previous lesson');
setIcon($('#next'), 'next', 'Next lesson');
setIcon($('#interrupt'), 'stop', 'Interrupt command (Ctrl+C)');

function notify(message) {
  $('#notice').textContent = message;
  $('#notice').hidden = !message;
}

function send(message) {
  if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
}

function updateState() {
  $('#connection').textContent = !connected
    ? 'Reconnecting…'
    : exited
      ? 'Shell exited'
      : ready
        ? '● Ready'
        : '● Running / awaiting input';
  $('#connection').className = connected && ready ? 'ready' : '';
  document.querySelectorAll('.run-command').forEach((button) => {
    button.disabled = !connected || !ready || exited;
  });
  $('#interrupt').disabled = !connected || exited;
}

function resize() {
  fit.fit();
  send({ type: 'resize', cols: terminal.cols, rows: terminal.rows });
}
new ResizeObserver(resize).observe($('#terminal'));
terminal.onData((data) => {
  if (connected && !exited) {
    if (data.includes('\r') || data.includes('\n')) {
      ready = false;
      updateState();
    }
    send({ type: 'input', data });
  }
});
$('#interrupt').onclick = () => {
  send({ type: 'input', data: '\u0003' });
  terminal.focus();
};

function showLesson(index) {
  current = index;
  localStorage.setItem('singular-lesson', String(index));
  $('#lesson-title').textContent = lessons[index].title;
  $('#step-label').textContent = 'SINGULAR / DEMO 1';
  $('#page-number').textContent = `${index + 1} / ${lessons.length}`;
  $('#previous').disabled = index === 0;
  $('#next').disabled = index === lessons.length - 1;
  $('#content').replaceChildren();
  for (const block of lessons[index].blocks) {
    if (block.kind === 'markdown') {
      const section = document.createElement('div');
      section.innerHTML = marked.parse(block.text);
      section.querySelectorAll('a').forEach((link) => {
        if (!/^https?:\/\//.test(link.getAttribute('href') || '')) link.removeAttribute('href');
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
      });
      $('#content').append(section);
    } else {
      const box = document.createElement('div');
      box.className = 'command';
      const pre = document.createElement('pre');
      const code = document.createElement('code');
      code.textContent = block.text;
      pre.append(code);
      box.append(pre);
      const actions = document.createElement('div');
      actions.className = 'command-actions';
      const copy = document.createElement('button');
      copy.className = 'copy-command';
      setIcon(copy, 'copy', 'Copy command');
      copy.onclick = async () => {
        try {
          await navigator.clipboard.writeText(block.text);
          setIcon(copy, 'check', 'Copied');
          setTimeout(() => setIcon(copy, 'copy', 'Copy command'), 1800);
        } catch {
          notify('Clipboard unavailable. Select the command to copy it.');
        }
      };
      actions.append(copy);
      if (block.id !== null) {
        const button = document.createElement('button');
        button.className = 'run-command';
        button.dataset.id = block.id;
        setIcon(
          button,
          ran.has(block.id) ? 'again' : 'run',
          ran.has(block.id) ? 'Run command again' : 'Run in terminal',
        );
        button.onclick = () => {
          ready = false;
          updateState();
          notify('');
          send({ type: 'run', id: block.id });
          terminal.focus();
        };
        actions.append(button);
      } else {
        box.classList.add('reference-command');
        box.title = 'Reference / optional command';
      }
      box.append(actions);
      $('#content').append(box);
    }
  }
  document.querySelectorAll('#lessons button').forEach((button, i) => {
    button.classList.toggle('active', i === index);
    if (i === index) button.setAttribute('aria-current', 'step');
    else button.removeAttribute('aria-current');
  });
  $('.reading').scrollTop = 0;
  updateState();
}
$('#previous').onclick = () => showLesson(Math.max(0, current - 1));
$('#next').onclick = () => showLesson(Math.min(lessons.length - 1, current + 1));

async function connect() {
  try {
    const response = await fetch('/api/lessons');
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    token = data.token;
    if (localStorage.getItem('singular-session') !== token) {
      localStorage.setItem('singular-session', token);
      localStorage.removeItem('singular-lesson');
      ran.clear();
      if (lessons.length) {
        lessons = data.lessons;
        showLesson(0);
      }
    }
    if (!lessons.length) {
      lessons = data.lessons;
      $('#lesson-count').textContent = `${lessons.length} lessons`;
      lessons.forEach((lesson, i) => {
        const button = document.createElement('button');
        const number = document.createElement('span');
        number.className = 'lesson-number';
        number.textContent = String(i + 1).padStart(2, '0');
        const title = document.createElement('span');
        title.textContent = lesson.title;
        button.append(number, title);
        button.onclick = () => showLesson(i);
        $('#lessons').append(button);
      });
      const saved = Number(localStorage.getItem('singular-lesson')) || 0;
      showLesson(Math.min(Math.max(saved, 0), lessons.length - 1));
    }
    socket = new WebSocket(
      `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws?token=${encodeURIComponent(token)}`,
    );
    socket.onopen = () => {
      terminal.reset();
      connected = true;
      notify('');
      updateState();
      resize();
    };
    socket.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.type === 'output') terminal.write(message.data);
      if (message.type === 'state') {
        ready = message.ready;
        exited = Boolean(message.exited);
        updateState();
        if (exited)
          notify('The shell has exited. Restart the tutorial server from the Codespaces terminal.');
      }
      if (message.type === 'error') notify(message.message);
      if (message.type === 'ran') {
        ran.add(message.id);
        const button = document.querySelector(`.run-command[data-id="${message.id}"]`);
        if (button) setIcon(button, 'again', 'Run command again');
      }
    };
    socket.onclose = () => {
      connected = false;
      ready = false;
      updateState();
      notify(
        'Connection lost, or this terminal is open in another tab. Retrying; the shell stays running.',
      );
      setTimeout(connect, 2000);
    };
  } catch (error) {
    notify(`Cannot load tutorial: ${error.message}. Retrying…`);
    setTimeout(connect, 3000);
  }
}
connect();
