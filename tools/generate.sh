#!/usr/bin/env bash
# Writes everything that is generated into ROOT (default: the repository): the Killercoda scenarios of every demo and the two
# structure files that list them. The generated files are never edited by hand.
#   tools/generate.sh [ROOT]
set -euo pipefail
cd "$(dirname "$0")/.."
root=${1:-.}
node demos/demo1/killercoda.js "$root"
node demos/pay-by-name/killercoda.js "$root"
node demos/structure.js "$root"
