#!/bin/bash
set -x
export DEBIAN_FRONTEND=noninteractive
mkdir -p /root/play
cat > /root/play/install-kit.sh <<'PLAY_EOF'
#!/usr/bin/env bash
# Downloads the Ubuntu kit of a release, checks it against the release's SHA256SUMS and unpacks it.
# Every environment of the play (Killercoda, Codespaces, the tests) installs the kit with this script.
#   install-kit.sh RELEASE [DIR]
#     RELEASE   the kit's release: the Singular release and the kit's revision, for example v0.16.0-1
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
cat > /root/play/prepare.sh <<'PLAY_EOF'
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

# Registration deadlines are POSIX milliseconds. The generated chain and host
# share that clock; a four-second margin matches the packaged devnet journey.
wait_until_ms() {
  while [ "$(($(date +%s) * 1000))" -lt "$(($1 + 4000))" ]; do sleep 1; done
}

# Select the holding output from a fold transaction reported by the provider.
# This supplies a reference for a write; it is not a registry membership query.
holding_in() {
  local token=$1 transaction=$2
  curl -fsS -X POST "$(koios_url)/tx_info" -H 'content-type: application/json' \
    -d "{\"_tx_hashes\":[\"$transaction\"],\"_assets\":true}" |
    jq -er --arg p "${token%%.*}" --arg n "${token#*.}" --arg tx "$transaction" '
      [.[0].outputs[] | select(any(.asset_list[]?; .policy_id == $p and .asset_name != $n))]
      | if length == 1 then .[0] | $tx + "#" + (.tx_index | tostring) else error("expected one holding from this fold") end'
}
PLAY_EOF
cat > /root/play/stepper.sh <<'PLAY_EOF'
# shellcheck shell=bash
# Shell setup for the stepper's windows (demos/demo1/play/stepper.sh).
# The tutorial's first page sources this visibly in each window:
#   carol, alice and bob windows:  . ../stepper.sh
#   chain window:           . ./stepper.sh
# It sets what every window's shell needs: the run folder, the programs on
# PATH, the passphrase, the helpers, the window's settings file, and the
# person words.
PLAY_RUN=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PLAY_RUN
# The programs every window needs, resolved to directories when the run was
# set up (the set-up script writes path.env beside this file). Prepended so
# the tutorial's programs win and the system's remain as fallback.
# shellcheck source=/dev/null
. "$PLAY_RUN/path.env"
export PATH="$PLAY_PATH:$PATH"
# The vaults open with this throwaway passphrase; no command asks for it
# (accepted on a private chain only).
export SINGULAR_PASSPHRASE=demo
# The compiled contracts the commands need: the set-up script writes their path into path.env
# beside PLAY_PATH when they travel with the tutorial (the kit, a Homebrew install); otherwise
# the development shell (flake.nix shellHook) provides $blueprint.
# shellcheck disable=SC2154 # PLAY_BLUEPRINT is written by the set-up script in the kit, unset in the repository
export blueprint="${blueprint:-${PLAY_BLUEPRINT:-}}"
# The helpers every window has: koios_url, wait_for_slot, wallet_show.
# They read the chain's settings line through PLAY_RUN.
# shellcheck source=/dev/null
. "$PLAY_RUN/helpers.sh"
# The settings file of the window that sourced this file. The chain needs
# none: it only starts the devnet and reads its settings line.
case "${TUTORIAL_STEPPER_WINDOW:-}" in
  alice) export SINGULAR_CONFIG="$PLAY_RUN/alice/alice.json" ;;
  carol) export SINGULAR_CONFIG="$PLAY_RUN/carol/carol.json" ;;
  bob) export SINGULAR_CONFIG="$PLAY_RUN/bob/bob.json" ;;
esac
# The person words. A block that is exactly `carol`, `alice` or `bob` pins the
# settings file explicitly, so the person switches in the later steps keep
# working in every window.
if [ "${PLAY_TMUX_WINDOWS:-no}" != yes ]; then
  alice() { export SINGULAR_CONFIG="$PLAY_RUN/alice/alice.json"; }
  bob() { export SINGULAR_CONFIG="$PLAY_RUN/bob/bob.json"; }
  carol() { export SINGULAR_CONFIG="$PLAY_RUN/carol/carol.json"; }
  chain() { :; }
fi

set -o pipefail
PLAY_EOF
cat > /root/play/windows.rc <<'PLAY_EOF'
# What every window of the play starts with: the usual bash setup, the programs, the settings file of the window's
# person, the helpers, and one word for each window. prepare.sh copies this file and helpers.sh next to play.env.
[ -f ~/.bashrc ] && . ~/.bashrc
. "$(dirname "${BASH_SOURCE[0]}")/play.env"
PLAY_TMUX_WINDOWS=yes
# an environment that needs more in its windows (the Codespaces tutorial's prompt tracking) names its file here
[ -z "${PLAY_RC_HOOK:-}" ] || . "$PLAY_RC_HOOK"
export PATH="$PLAY_KIT/bin:$PATH"
export blueprint="$PLAY_KIT/share/plutus.json"
# a person's window (windows.sh names the person in PLAY_PERSON) reads that person's own settings file, in the person's folder
[ -z "${PLAY_PERSON:-}" ] || export SINGULAR_CONFIG="$PWD/$PLAY_PERSON.json"
# the vaults of the play open with this throwaway passphrase; no command asks for it (accepted on a private chain only)
export SINGULAR_PASSPHRASE=demo
# the helpers of the play: koios_url, wait_for_slot, wallet_show
. "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
# one word goes to a window
alice() { tmux select-window -t alice; }
bob() { tmux select-window -t bob; }
chain() { tmux select-window -t chain; }

carol() { tmux select-window -t carol; }
PLAY_EOF
cat > /root/play/windows.sh <<'PLAY_EOF'
#!/usr/bin/env bash
# Starts the four windows of the play in one tmux session: 0 alice, 1 bob, 2 chain, 3 carol, each with the shell setup of windows.rc
# and, for Carol, Alice and Bob, the name of the person (PLAY_PERSON), which windows.rc turns into the person's settings file.
#   windows.sh RUN_DIR
#   PLAY_TMUX   the tmux command with its options (default: tmux); an environment with its own tmux server sets it
set -euo pipefail
run=$(cd "${1:?usage: windows.sh RUN_DIR}" && pwd)
t=${PLAY_TMUX:-tmux}
shell="exec bash --rcfile $run/windows.rc -i"
$t new-session -d -s demo -n alice -c "$run/alice" "exec env PLAY_PERSON=alice bash --rcfile $run/windows.rc -i"
$t new-window -d -t demo -n bob -c "$run/bob" "exec env PLAY_PERSON=bob bash --rcfile $run/windows.rc -i"
$t new-window -d -t demo -n chain -c "$run" "$shell"
$t new-window -d -t demo -n carol -c "$run/carol" "exec env PLAY_PERSON=carol bash --rcfile $run/windows.rc -i"
# the mouse switches windows and scrolls
$t set-option -g mouse on
echo "The windows carol, alice, bob and chain are ready."
PLAY_EOF
bash /root/play/install-kit.sh v0.17.0-1 /root
# tmux holds the four windows
apt-get update -qq && apt-get install -y -qq tmux
tmux -V
bash /root/play/prepare.sh /root/singular-demo-v0.17.0-1-x86_64-linux /root/singular-demo-run
touch /tmp/finished
