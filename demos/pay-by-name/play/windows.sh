#!/usr/bin/env bash
# Starts the five windows of the play in one tmux session: 0 carol, 1 alice, 2 dave, 3 bob, 4 chain, each with the shell
# setup of windows.rc and in the folder of its person (the chain in the folder of the play).
#   windows.sh RUN_DIR
#   PLAY_TMUX   the tmux command with its options (default: tmux); an environment with its own tmux server sets it
set -euo pipefail
run=$(cd "${1:?usage: windows.sh RUN_DIR}" && pwd)
t=${PLAY_TMUX:-tmux}
shell="exec bash --rcfile $run/windows.rc -i"
$t new-session -d -s demo -n carol -c "$run/carol" "$shell"
$t new-window -d -t demo -n alice -c "$run/alice" "$shell"
$t new-window -d -t demo -n dave -c "$run/dave" "$shell"
$t new-window -d -t demo -n bob -c "$run/bob" "$shell"
$t new-window -d -t demo -n chain -c "$run" "$shell"
# the mouse switches windows and scrolls
$t set-option -g mouse on
echo "The windows carol, alice, dave, bob and chain are ready."
