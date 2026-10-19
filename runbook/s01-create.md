# Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. `create` picks a suitable coin of Alice's by itself and names it in the receipt. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 180 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 180 seconds; raise `process_ms` below if there is a lot to say between the two.

**Two values to keep.** The devnet printed where its web API answers (`providerUrl`) and where its clock data is (`networkTimeDirectory`). Every command below is written out in full and repeats the same groups of options, so these are the only shorthands: plain variables you can print.

- `koios_url`: where the chain's web API answers
- `time_dir`: the chain's clock data (when each slot happens)
- the last line is a check: both lines it prints must be non-empty. If one is empty, paste the block again.

```bash
koios_url=$(jq -r .providerUrl devnet.out); time_dir=$(jq -r .networkTimeDirectory devnet.out)
echo "$koios_url"; echo "$time_dir"
```

**How to read the commands from here on.** Each one has the same layout, one group per line:

- the command's own options (what to do: the key, the payload, the windows)
- the registry: `--state-dir` (its journal folder), `--blueprint` (the compiled contracts) and `--state-token` (its name)
- the chain: `--koios-url`, `--network-time` and `--network-magic 42` (this private chain's number)
- the wallet that signs: `--vault` for a wallet that signs in one command (it asks for the passphrase), or `--wallet-address` with `--bundle` for the external way

**Create.** It spends a coin of Alice's as the seed and publishes the registry, signed by her vault. It asks for her passphrase, and returns when everything has landed. There is no registry name yet, so the registry group has only the folder and the contracts.

- `process_ms`: how long the registry has to process a request, in milliseconds
- `retract_ms`: how long after that the owner may take a request back
- both windows are fixed for the registry's whole life
- `seed` in the output is the coin that was spent; `stateToken` is the registry's name

```bash
process_ms=180000; retract_ms=60000
open-datum create \
  --process-time "$process_ms" --retract-time "$retract_ms" \
  --state-dir reg --blueprint "$blueprint" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/01-create.json
```

**Read what it returned:**

```bash
jq '{outcome, reason, seed, stateToken} | with_entries(select(.value != null))' receipts/01-create.json
```

**From now on every command names the registry by its state token**, as `--state-token "$token"`. The token is the registry's name, read from the create receipt:

```bash
token=$(jq -r .stateToken receipts/01-create.json)
echo "$token"
```

Want to see the seed coin before it is spent? Add `--preview` and use `--wallet-address "$alice_addr"` instead of the vault: it reads the chain and writes nothing.
