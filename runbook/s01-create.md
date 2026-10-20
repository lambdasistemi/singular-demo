# Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. `create` picks a suitable coin of Alice's by itself and names it in the receipt. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 180 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 180 seconds; raise `process_ms` below if there is a lot to say between the two.

**The settings, written once.** Every command needs the same few things: where the chain answers, the compiled contracts and a folder for the registry's journal. They go in a file named `singular.json`, which the commands read by themselves, so no command below repeats them. The devnet's settings line has two of the values; `jq` builds the file from it.

- `koios-url`: where the chain's web API answers (`providerUrl` in the devnet's line)
- `network-time`: the chain's clock data, when each slot happens (`networkTimeDirectory`)
- `network-magic`: the number of this private chain, 42
- `blueprint`: the compiled contracts
- `state-dir`: the folder for the registry's journal

```bash
jq --arg blueprint "$blueprint" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "reg"}' devnet.out > singular.json
jq . singular.json
```

A few commands below ask the chain's web API directly (its clock, the extras). They use the variable `koios_url`:

```bash
koios_url=$(jq -r .providerUrl devnet.out)
```

**How to read the commands from here on.** The chain, the contracts and the journal folder come from `singular.json`, so each command shows only what it does:

- its own options: the key, the payload, the windows
- the wallet that signs: `--vault` for a wallet that signs in one command (it asks for the passphrase), or `--wallet-address` with `--bundle` for the external way

An option typed on a command still wins over the file.

**Create.** It spends a coin of Alice's as the seed and publishes the registry, signed by her vault. It asks for her passphrase, and returns when everything has landed.

- `process_ms`: how long the registry has to process a request, in milliseconds
- `retract_ms`: how long after that the owner may take a request back
- both windows are fixed for the registry's whole life
- `seed` in the output is the coin that was spent; `stateToken` is the registry's name

```bash
process_ms=180000; retract_ms=60000
open-datum create \
  --process-time "$process_ms" --retract-time "$retract_ms" \
  --vault alice.vault \
  > receipts/01-create.json
```

**Read what it returned:**

```bash
jq '{outcome, reason, seed, stateToken} | with_entries(select(.value != null))' receipts/01-create.json
```

**From now on every command names the registry by its state token.** The token is the registry's name, read from the create receipt. It goes into the same file as `state-token`, and every command below finds it there:

```bash
jq --arg token "$(jq -r .stateToken receipts/01-create.json)" '."state-token" = $token' singular.json > singular.new && mv singular.new singular.json
jq . singular.json
```

Want to see the seed coin before it is spent? Add `--preview` and use `--wallet-address "$alice_addr"` instead of the vault: it reads the chain and writes nothing.
