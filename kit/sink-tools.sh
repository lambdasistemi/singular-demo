#!/bin/sh
# The tools of the pay-by-name scenario (sink-address, check-registry, pay, move and the rest): one file of JavaScript,
# run by the kit's own Node.js, bin/node, like every other program of the kit.
here=$(cd "$(dirname "$0")/.." && pwd)
exec "$here/bin/node" "$here/share/sink-tools/sink-tools.cjs" "$@"
