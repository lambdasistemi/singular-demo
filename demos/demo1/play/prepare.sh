#!/usr/bin/env bash
# Makes the folders of the play: one directory for Alice and one for Bob, each with the folders for
# their receipts, bundles and witnesses and an empty settings file of their own (alice.json, bob.json), and the shell setup
# every window starts with.
#   prepare.sh KIT_DIR RUN_DIR
set -euo pipefail
kit=$(cd "${1:?usage: prepare.sh KIT_DIR RUN_DIR}" && pwd)
run=${2:?usage: prepare.sh KIT_DIR RUN_DIR}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$run"/{alice,bob,carol}/{receipts,bundles,witnesses}
run=$(cd "$run" && pwd)
# the settings files of Carol, Alice and Bob, each in the person's folder; the steps fill them
for who in alice bob carol; do [ -f "$run/$who/$who.json" ] || echo '{}' >"$run/$who/$who.json"; done
printf 'PLAY_KIT=%q\nPLAY_RUN=%q\n' "$kit" "$run" >"$run/play.env"
cp "$here/windows.rc" "$here/helpers.sh" "$here/stepper.sh" "$run/"
chmod u+w "$run/windows.rc" "$run/helpers.sh" "$run/stepper.sh"
printf 'PLAY_PATH=%q\nPLAY_BLUEPRINT=%q\n' "$kit/bin" "$kit/share/plutus.json" >"$run/path.env"
echo "The folders of the play are ready: $run"
