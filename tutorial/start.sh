#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if curl -fsS http://127.0.0.1:8765/health >/dev/null 2>&1; then
  bash ./open.sh
  exit 0
fi
nohup .venv/bin/python server.py >server.log 2>&1 &
echo "$!" >server.pid
for _ in {1..60}; do
  if curl -fsS http://127.0.0.1:8765/health >/dev/null 2>&1; then
    bash ./open.sh
    exit 0
  fi
  if ! kill -0 "$(cat server.pid)" 2>/dev/null; then
    cat server.log
    exit 1
  fi
  sleep 1
done
cat server.log
echo "Tutorial startup timed out." >&2
exit 1
