#!/usr/bin/env bash
# Makes the folders of the play: one directory for Alice and one for Bob, each with the folders for
# their receipts, bundles and witnesses, the settings file they share, and the shell setup every window starts with.
#   prepare.sh KIT_DIR RUN_DIR
set -euo pipefail
kit=$(cd "${1:?usage: prepare.sh KIT_DIR RUN_DIR}" && pwd)
run=${2:?usage: prepare.sh KIT_DIR RUN_DIR}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$run"/{alice,bob}/{receipts,bundles,witnesses}
run=$(cd "$run" && pwd)
# the settings file Alice's and Bob's windows share; step 1 fills it
[ -f "$run/singular.json" ] || echo '{}' >"$run/singular.json"
printf 'PLAY_KIT=%q\nPLAY_RUN=%q\n' "$kit" "$run" >"$run/play.env"
cp "$here/windows.rc" "$run/windows.rc"
echo "The folders of the play are ready: $run"
