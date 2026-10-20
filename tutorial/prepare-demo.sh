#!/usr/bin/env bash
# Prepares the three windows of the play (alice, bob, chain) in this tutorial's own tmux server,
# with the play's shared scripts (demos/demo1/play): the same ones the Killercoda machine runs.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
play="$root/demos/demo1/play"
version=$(node -p "require('$root/demos/demo1/version.js')")
bash "$root/tutorial/install-kit.sh"
: "${TUTORIAL_TMUX_SOCKET:?Open this command in the tutorial terminal}"
: "${TUTORIAL_STATE_DIR:?Open this command in the tutorial terminal}"
export PLAY_TMUX="tmux -L $TUTORIAL_TMUX_SOCKET -f /dev/null"
# each window also gets the tutorial's prompt tracking
export PLAY_RC_HOOK="$root/tutorial/shell-rc.sh"
if $PLAY_TMUX has-session -t demo 2>/dev/null; then
  echo 'The Alice, Bob and chain windows are already ready. Continue to the next lesson.'
  exit 0
fi
run="$HOME/singular-demo-run"
if [[ -e "$run" ]]; then
  saved=$(mktemp -d "$HOME/singular-demo-saved-$(date +%Y%m%d-%H%M%S)-XXXXXX")
  mv "$run" "$saved/run"
  printf 'Your previous demo files are saved in %s/run\n' "$saved"
fi
bash "$play/prepare.sh" "$HOME/singular-demo-$version-x86_64-linux" "$run"
bash "$play/windows.sh" "$run"
printf 'Alice, Bob and chain windows are ready. Continue to the next lesson.\n'
