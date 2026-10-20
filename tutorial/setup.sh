#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v tmux >/dev/null 2>&1; then
  if [[ $(id -u) == 0 ]]; then
    apt-get update -qq && apt-get install -y -qq tmux
  else
    sudo apt-get update -qq && sudo apt-get install -y -qq tmux
  fi
fi
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
npm install --ignore-scripts --no-audit --no-fund
mkdir -p static/vendor
cp node_modules/@xterm/xterm/lib/xterm.js static/vendor/
cp node_modules/@xterm/xterm/css/xterm.css static/vendor/
cp node_modules/@xterm/addon-fit/lib/addon-fit.js static/vendor/
cp node_modules/marked/lib/marked.umd.js static/vendor/
printf '\nTutorial dependencies installed.\n'
sha256sum requirements.txt package.json setup.sh | sha256sum | cut -d ' ' -f1 > .setup-fingerprint
