#!/usr/bin/env bash
# Makes the folders of the play: one for each of Carol, Alice, Dave and Bob; the folder `publish`, where Carol's page is
# written, and the folder `messages`, where the people's messages are; the shell setup every window starts with.
#   prepare.sh KIT_DIR RUN_DIR
set -euo pipefail
kit=$(cd "${1:?usage: prepare.sh KIT_DIR RUN_DIR}" && pwd)
run=${2:?usage: prepare.sh KIT_DIR RUN_DIR}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$run"/{carol,alice,dave,bob,publish,messages}
run=$(cd "$run" && pwd)
printf 'PLAY_KIT=%q\nPLAY_RUN=%q\n' "$kit" "$run" >"$run/play.env"
cp "$here/windows.rc" "$here/helpers.sh" "$run/"
echo "The folders of the play are ready: $run"
