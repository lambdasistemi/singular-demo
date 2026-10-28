#!/usr/bin/env bash
# Resolve pay-by-name entirely through its retained release, including inherited shell settings.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
runtime=$(cd "$here/../../../pay-by-name-runtime" && pwd)
export PATH="$runtime/bin:$PATH" blueprint="$runtime/share/plutus.json"
bash "$runtime/share/tutorials/pay-by-name/setup.sh"
printf 'export blueprint=%q\nexport E2E_GENESIS_DIR=%q\nexport singular_registry_datadir=%q\n' \
  "$runtime/share/plutus.json" "$runtime/share/genesis" "$runtime/share/singular-registry" >>"$PWD/stepper.sh"
