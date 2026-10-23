# shellcheck shell=bash
# Shell setup for the stepper's windows (demos/pay-by-name/play/stepper.sh).
# The tutorial's first page sources this visibly in each window:
#   carol, alice, dave and bob windows:  . ../stepper.sh
#   chain window:                       . ./stepper.sh
# It sets what every window's shell needs: the run folder, the programs on
# PATH, the passphrase, the helpers, and the pay-by-name commands.
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
# The compiled contracts the commands need: in the kit the tutorial directory sits at
# <kit>/share/tutorials/<name>, so the set-up script writes their path into path.env
# beside PLAY_PATH; otherwise the development shell (flake.nix shellHook) provides $blueprint.
# shellcheck disable=SC2154 # PLAY_BLUEPRINT is written by the set-up script in the kit, unset in the repository
export blueprint="${blueprint:-${PLAY_BLUEPRINT:-}}"
# The helpers every window has: koios_url, wait_for_slot, wallet_show.
# They read the chain's settings line through PLAY_RUN.
# shellcheck source=/dev/null
. "$PLAY_RUN/helpers.sh"
# settings [ADDRESS]: writes singular.json in this folder. The programs read
# it to find the chain, the network, the compiled contracts and the folder
# where this person keeps the journal of their writes, and, when a registry
# is named, its address.
# shellcheck disable=SC2154 # blueprint comes from the development shell (flake.nix shellHook), as in windows.rc
settings() {
  jq -n --slurpfile chain "$PLAY_RUN/devnet.out" --arg blueprint "$blueprint" --arg dir "$PWD/state" --arg address "${1:-}" \
    '$chain[0] | {"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": $dir} + (if $address == "" then {} else {"registry": $address} end)' >singular.json
}
# outputs_at ADDRESS [TRANSACTION]: the outputs at an address, one line each; only those of the transaction when it is given
outputs_at() {
  curl -fsS -X POST "$(koios_url)/address_utxos" -H 'content-type: application/json' -d "{\"_addresses\":[\"$1\"]}" |
    jq -c --arg tx "${2:-}" '.[] | select($tx == "" or .tx_hash == $tx) | {tx: .tx_hash[0:12], ix: .tx_index, ada: ((.value|tonumber)/1000000)}'
}
# The window words. The stepper already switches windows, so these are
# no-ops that keep the words working in every window (as Demo 1's stepper
# keeps alice()/bob() working for its person switches).
carol() { :; }
alice() { :; }
dave() { :; }
bob() { :; }
chain() { :; }
