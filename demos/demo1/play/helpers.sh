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
