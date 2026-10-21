#!/bin/bash
set -x
export DEBIAN_FRONTEND=noninteractive
mkdir -p /root/play
cat > /root/play/install-kit.sh <<'PLAY_EOF'
#!/usr/bin/env bash
# Downloads the Ubuntu kit of a release, checks it against the release's SHA256SUMS and unpacks it.
# Every environment of the play (Killercoda, Codespaces, the tests) installs the kit with this script.
#   install-kit.sh RELEASE [DIR]
#     RELEASE   the kit's release: the Singular release and the kit's revision, for example v0.14.0-1
#     DIR       where the kit folder goes (default: $HOME)
#   PLAY_KIT_BASE   takes the files from this address instead of the release page; file:///dir tests a kit that is not released yet
set -euo pipefail
release=${1:?usage: install-kit.sh RELEASE [DIR]}
dir=${2:-$HOME}
base=${PLAY_KIT_BASE:-https://github.com/lambdasistemi/singular-demo/releases/download/$release}
name=singular-demo-$release-x86_64-linux
mkdir -p "$dir"
if [ -x "$dir/$name/bin/singular" ] && [ -f "$dir/$name/.verified" ]; then
  echo "The kit is already installed: $dir/$name"
  exit 0
fi
if [ -e "$dir/$name" ]; then
  echo "A kit that was not verified is in $dir/$name. Move it aside and try again." >&2
  exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 -o "$tmp/$name.tar.gz" "$base/$name.tar.gz"
curl -fsSL --retry 3 -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"
(cd "$tmp" && sha256sum -c SHA256SUMS)
tar xzf "$tmp/$name.tar.gz" -C "$dir"
touch "$dir/$name/.verified"
echo "The kit is installed: $dir/$name"
PLAY_EOF
cat > /root/play/helpers.sh <<'PLAY_EOF'
# shellcheck shell=bash
# The helpers every window of the play has, and the runbook test too. They need PLAY_RUN (the demo folder), jq and curl.

# koios_url: where the chain's web API answers, read from the devnet's settings line
koios_url() { jq -r .providerUrl "$PLAY_RUN/devnet.out"; }

# wait_for_slot N: ask the chain for its latest slot every 2 seconds until it is past N (the chain's own clock).
wait_for_slot() {
  local now
  until now=$(curl -fsS "$(koios_url)/tip" | jq -r '.[0].abs_slot') && [ "$now" -gt "$1" ]; do
    printf '\r  chain slot %s, waiting for slot %s ' "$now" "$1"
    sleep 2
  done
  printf '\n  done: chain slot %s is past slot %s\n' "$now" "$1"
}

# wallet_show ADDRESS: the outputs at an address, in a short form
wallet_show() {
  curl -fsS -X POST "$(koios_url)/address_utxos" -H 'content-type: application/json' -d "{\"_addresses\":[\"$1\"]}" |
    jq '{outputs: length, total_ada: ([.[] | (.value|tonumber)] | add / 1000000), utxos: [.[] | {tx: .tx_hash[0:12], ix: .tx_index, ada: ((.value|tonumber)/1000000), tokens: [.asset_list[]? | .asset_name[0:8]]}]}'
}
PLAY_EOF
cat > /root/play/prepare.sh <<'PLAY_EOF'
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
PLAY_EOF
cat > /root/play/windows.rc <<'PLAY_EOF'
# What every window of the play starts with: the usual bash setup, the programs, the helpers, and one word for each window.
# prepare.sh copies this file and helpers.sh next to play.env.
[ -f ~/.bashrc ] && . ~/.bashrc
. "$(dirname "${BASH_SOURCE[0]}")/play.env"
# an environment that needs more in its windows names its file here
[ -z "${PLAY_RC_HOOK:-}" ] || . "$PLAY_RC_HOOK"
export PATH="$PLAY_KIT/bin:$PATH"
export blueprint="$PLAY_KIT/share/plutus.json"
# the vaults of the play open with this throwaway passphrase; no command asks for it (accepted on a private chain only)
export SINGULAR_PASSPHRASE=demo
# the helpers of the play: koios_url, wait_for_slot, wallet_show
. "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# settings [STATE_TOKEN]: writes singular.json in this folder. The programs read it to find the chain, the network, the
# compiled contracts and the folder where this person keeps the journal of their writes, and, when a registry is named, its state token.
settings() {
  jq -n --slurpfile chain "$PLAY_RUN/devnet.out" --arg blueprint "$blueprint" --arg dir "$PWD/state" --arg token "${1:-}" \
    '$chain[0] | {"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": $dir} + (if $token == "" then {} else {"state-token": $token} end)' >singular.json
}

# outputs_at ADDRESS [TRANSACTION]: the outputs at an address, one line each; only those of the transaction when it is given
outputs_at() {
  curl -fsS -X POST "$(koios_url)/address_utxos" -H 'content-type: application/json' -d "{\"_addresses\":[\"$1\"]}" |
    jq -c --arg tx "${2:-}" '.[] | select($tx == "" or .tx_hash == $tx) | {tx: .tx_hash[0:12], ix: .tx_index, ada: ((.value|tonumber)/1000000)}'
}

# one word goes to a window
carol() { tmux select-window -t carol; }
alice() { tmux select-window -t alice; }
dave() { tmux select-window -t dave; }
bob() { tmux select-window -t bob; }
chain() { tmux select-window -t chain; }
PLAY_EOF
cat > /root/play/windows.sh <<'PLAY_EOF'
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
PLAY_EOF
bash /root/play/install-kit.sh v0.14.0-1 /root
# tmux holds the five windows (the kit brings its own node, which runs its tools)
apt-get update -qq && apt-get install -y -qq tmux
tmux -V
bash /root/play/prepare.sh /root/singular-demo-v0.14.0-1-x86_64-linux /root/singular-demo-run
touch /tmp/finished
