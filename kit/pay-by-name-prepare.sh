#!/usr/bin/env bash
# The carried scenario keeps its original programs and chain data.
set -euo pipefail
kit=$(cd "${1:?kit directory}" && pwd)
run=${2:?run directory}
runtime="$kit/pay-by-name-runtime"
bash "$runtime/share/pay-by-name/play/prepare.sh" "$runtime" "$run"
printf 'export E2E_GENESIS_DIR=%q\nexport singular_registry_datadir=%q\n' \
  "$runtime/share/genesis" "$runtime/share/singular-registry" >>"$run/windows.rc"
