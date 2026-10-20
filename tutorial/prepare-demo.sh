#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
bash ./install-kit.sh
: "${TUTORIAL_TMUX_SOCKET:?Open this command in the tutorial terminal}"
: "${TUTORIAL_STATE_DIR:?Open this command in the tutorial terminal}"
tmux_cmd=(tmux -L "$TUTORIAL_TMUX_SOCKET")
if "${tmux_cmd[@]}" has-session -t demo 2>/dev/null; then
  echo 'The Alice, Bob and chain windows are already ready. Continue to the next lesson.'
  exit 0
fi
run="$HOME/singular-demo-run"
if [[ -e "$run" ]]; then
  saved=$(mktemp -d "$HOME/singular-demo-saved-$(date +%Y%m%d-%H%M%S)-XXXXXX")
  mv "$run" "$saved/run"
  printf 'Your previous demo files are saved in %s/run\n' "$saved"
fi
mkdir -p "$run"/{alice,bob}/{receipts,bundles,witnesses}
printf '{}\n' > "$run/singular.json"
cat > "$run/windows.rc" <<'RC'
source "$TUTORIAL_ROOT/tutorial/shell-rc.sh"
export PATH="$HOME/singular-demo-v0.13.0-x86_64-linux/bin:$PATH"
export blueprint="$HOME/singular-demo-v0.13.0-x86_64-linux/share/plutus.json"
export SINGULAR_CONFIG="$HOME/singular-demo-run/singular.json"
wait_for_slot() { local now; until now=$(curl -fsS "$(jq -r .providerUrl "$HOME/singular-demo-run/devnet.out")/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"; sleep 2; done; printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"; }
RC
# Each shell sources the same prompt hooks and demo settings but keeps its own variables.
"${tmux_cmd[@]}" -f /dev/null new-session -d -s demo -n alice -c "$run/alice" 'exec bash --rcfile "$HOME/singular-demo-run/windows.rc" -i'
"${tmux_cmd[@]}" new-window -d -t demo -n bob -c "$run/bob" 'exec bash --rcfile "$HOME/singular-demo-run/windows.rc" -i'
"${tmux_cmd[@]}" new-window -d -t demo -n chain -c "$run" 'exec bash --rcfile "$HOME/singular-demo-run/windows.rc" -i'
printf 'Alice, Bob and chain windows are ready. Continue to the next lesson.\n'
