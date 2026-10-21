#!/bin/sh
# The tools of the pay-by-name scenario (sink-address, check-registry, pay, move and the rest): one file of JavaScript that
# the machine's own node runs. The kit does not bring node; Ubuntu's own package is enough (sudo apt install nodejs).
here=$(cd "$(dirname "$0")/.." && pwd)
command -v node >/dev/null 2>&1 || {
  echo "sink-tools needs node, version 18 or newer. On Ubuntu: sudo apt install nodejs" >&2
  exit 127
}
exec node "$here/share/sink-tools/sink-tools.cjs" "$@"
