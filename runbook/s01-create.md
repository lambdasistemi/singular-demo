# Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 120 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 120 seconds; raise `process_ms` below if there is a lot to say between the two.

Which chain to talk to: the settings the devnet printed.

```bash
# Read the chain's settings from the line the devnet printed:
#   providerUrl          where the chain's web API answers
#   networkTimeDirectory the chain's clock data (when each slot happens)
koios_url=$(jq -r .providerUrl devnet.out); time_dir=$(jq -r .networkTimeDirectory devnet.out)
# From now on "${provider[@]}" stands for these three options, which every command needs:
provider=(--koios-url "$koios_url" --network-time "$time_dir" --network-magic 42)
```

The options every Alice command uses: sign from her vault, in one command.

```bash
# "${alice[@]}" stands for: sign with Alice's vault (it asks for her passphrase), then send.
alice=(--vault alice.vault)
```

Preview first. It reads the chain, writes nothing, and shows which seed Alice's address would use and what the registry would be called:

```bash
# Preview: a dry look. Nothing is signed or sent, so only her public address is needed.
#   --state-dir reg    the folder where this registry's own journal is kept (it is created)
#   --blueprint        the compiled contracts the registry is built from
open-datum create --preview --state-dir reg --blueprint "$blueprint" "${provider[@]}" --wallet-address "$alice_addr" > receipts/01a-preview.json
# seed = the coin that will be spent; stateToken = the registry's name
jq '{seed, stateToken}' receipts/01a-preview.json
```

The two windows, in milliseconds:

```bash
# process_ms: how long the registry has to process a request. retract_ms: how long after that its owner may take it back.
process_ms=120000; retract_ms=60000
```

Create: it spends the seed coin and publishes the registry. It asks for Alice's passphrase, and returns when everything has landed:

```bash
# Create the registry. --seed names the coin to spend; the windows are fixed for the registry's whole life.
open-datum create --seed "$(jq -r .seed receipts/01a-preview.json)" --process-time "$process_ms" --retract-time "$retract_ms" --state-dir reg --blueprint "$blueprint" "${provider[@]}" "${alice[@]}" > receipts/01b-create.json
jq '{outcome, stateToken}' receipts/01b-create.json
```

From now on every command names the registry by its state token:

```bash
# "${registry[@]}" stands for: this registry's journal folder, the contracts, and its name (the state token).
registry=(--state-dir reg --blueprint "$blueprint" --state-token "$(jq -r .stateToken receipts/01b-create.json)")
```
