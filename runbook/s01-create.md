# Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 120 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 120 seconds; raise `process_ms` below if there is a lot to say between the two.

**Shorthands used from here on.** Paste this first, in the same terminal as everything else.

- `koios_url` and `time_dir`: read from the line the devnet printed. `providerUrl` is where the chain's web API answers; `networkTimeDirectory` holds the chain's clock data (when each slot happens).
- `"${provider[@]}"` stands for the three options every command needs to reach the chain.
- `"${alice[@]}"` stands for "sign with Alice's vault": the command asks for her passphrase, then sends.
- The last line is a check: both lines it prints must be non-empty. If one is empty, paste the block again.

```bash
koios_url=$(jq -r .providerUrl devnet.out); time_dir=$(jq -r .networkTimeDirectory devnet.out)
provider=(--koios-url "$koios_url" --network-time "$time_dir" --network-magic 42)
alice=(--vault alice.vault)
echo "${provider[@]}"; echo "${alice[@]}"
```

**Preview first.** A dry look: nothing is signed or sent, so only Alice's public address is needed. It shows which seed her address would use and what the registry would be called.

- `--state-dir reg`: the folder where this registry's own journal is kept (it is created)
- `--blueprint`: the compiled contracts the registry is built from
- `seed` in the output is the coin that will be spent; `stateToken` is the registry's name

```bash
open-datum create --preview --state-dir reg --blueprint "$blueprint" "${provider[@]}" --wallet-address "$alice_addr" > receipts/01a-preview.json
jq '{seed, stateToken}' receipts/01a-preview.json
```

**Create.** It spends the seed coin and publishes the registry, signed by Alice's vault. It asks for her passphrase, and returns when everything has landed.

- `process_ms`: how long the registry has to process a request, in milliseconds
- `retract_ms`: how long after that the owner may take a request back
- both windows are fixed for the registry's whole life
- `--seed` names the coin to spend; `--vault alice.vault` is Alice's wallet, the same as `"${alice[@]}"`

```bash
process_ms=120000; retract_ms=60000
open-datum create --seed "$(jq -r .seed receipts/01a-preview.json)" --process-time "$process_ms" --retract-time "$retract_ms" --state-dir reg --blueprint "$blueprint" "${provider[@]}" --vault alice.vault > receipts/01b-create.json
jq '{outcome, stateToken}' receipts/01b-create.json
```

**From now on every command names the registry by its state token.** `"${registry[@]}"` stands for the registry's journal folder, the contracts, and its name.

```bash
registry=(--state-dir reg --blueprint "$blueprint" --state-token "$(jq -r .stateToken receipts/01b-create.json)")
echo "${registry[@]}" | cut -c1-120
```
