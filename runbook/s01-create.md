# Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. A preview comes first. It reads the chain, writes nothing, and shows which seed Alice's address would use and what the registry would be called. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 120 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 120 seconds; raise `process_ms` if there is a lot to say between the two.

```bash
# Which chain to talk to: the settings the devnet printed.
koios_url=$(jq -r .providerUrl devnet.out)
time_dir=$(jq -r .networkTimeDirectory devnet.out)
provider=(--koios-url "$koios_url" --network-time "$time_dir" --network-magic 42)
# Alice signs from her vault in one command; this is the option set every Alice command uses.
alice=(--vault alice.vault --passphrase-fd 3)

# 1a. Preview: no signing, nothing written.
open-datum create --preview --state-dir reg --blueprint "$blueprint" "${provider[@]}" --wallet-address "$alice_addr" > receipts/01a-preview.json
jq '{seed, stateToken}' receipts/01a-preview.json

# 1b. Create: spends the seed coin and publishes the registry. It returns when everything has landed.
seed=$(jq -r .seed receipts/01a-preview.json)
process_ms=120000   # time the registry has to process a request
retract_ms=60000    # time after that in which the owner may take it back
open-datum create --seed "$seed" --process-time "$process_ms" --retract-time "$retract_ms" \
  --state-dir reg --blueprint "$blueprint" "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/01b-create.json
jq '{outcome, stateToken}' receipts/01b-create.json

# From now on every command names the registry by its state token.
registry=(--state-dir reg --blueprint "$blueprint" --state-token "$(jq -r .stateToken receipts/01b-create.json)")
```
