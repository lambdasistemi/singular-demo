#!/usr/bin/env bash
# Run from the Codespaces editor terminal, outside the tutorial's own shell.
set -euo pipefail
cd "$(dirname "$0")"
expected=$(sha256sum requirements.txt package.json setup.sh | sha256sum | cut -d ' ' -f1)
if [[ ! -x .venv/bin/python || ! -f static/vendor/xterm.js || ! -f .setup-fingerprint ]] || [[ $(cat .setup-fingerprint) != "$expected" ]]; then
  bash ./setup.sh
fi
bash ./install-kit.sh
# Prepare everything before interrupting an existing session.
.venv/bin/python stop.py
bash ./start.sh
bash ./open.sh --show
printf '\nUpdated. Refresh the tutorial tab to begin a fresh session.\n'
