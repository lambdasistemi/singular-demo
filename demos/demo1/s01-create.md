# Step 1: create the registry

A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. `create` picks a suitable coin of Alice's by itself and names it in the receipt. The registry's name is its address.

The windows are short on purpose, so the waits later last minutes: 180 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 180 seconds; raise `process_ms` below if there is a lot to say between the two. The [documentation on choosing the windows](https://lambdasistemi.github.io/singular/docs/singular-node/#choosing-a-registrys-windows).

**The settings.** The commands need the same settings again and again: where the chain answers, the chain's clock data and number, the compiled contracts, a folder for the registry's journal and, once it exists, the registry. Each can be given as an option on the command (`--koios-url URL`), as an environment variable (`SINGULAR_KOIOS_URL=URL`) or as a key in a JSON file (`"koios-url": "URL"`); for the registry they are `--registry ADDRESS`, `SINGULAR_REGISTRY=ADDRESS` and `"registry": "ADDRESS"`. The first one present wins: option, then variable, then file. The [full description](https://lambdasistemi.github.io/singular/docs/singular-node/#giving-the-chain-the-contracts-and-the-registry-once) is in the documentation.

**For this tutorial, a JSON file for each person**, so that no command below repeats them. You could override a value with a variable or an option, or skip the file and give every setting that way. Alice's file is `alice.json`. The devnet's settings line has two of the values; `jq` builds the file from it.

- `koios-url`: where the chain's web API answers (`providerUrl` in the devnet's line)
- `network-time`: the chain's clock data, when each slot happens (`networkTimeDirectory`)
- `network-magic`: the number of this private chain, 42
- `blueprint`: the compiled contracts
- `state-dir`: the folder for her journal

**Now Alice.**

```bash
alice
```

```bash
jq --arg blueprint "$blueprint" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "alice-journal"}' devnet.out > alice.json
jq . alice.json
```

**How to read the commands from here on.** The chain, the contracts, the registry and the journal folder come from the settings file of the person who acts, so each command shows only what it does:

- its own options: the key, the payload, the windows
- the wallet that signs: `--vault` for a wallet that signs in one command, or `--wallet-address` with `--bundle` for the external way

**Create.** It spends a coin of Alice's as the seed and publishes the registry, signed by her vault. It returns when everything has landed.

- `process_ms`: how long the registry has to process a request, in milliseconds
- `retract_ms`: how long after that the owner may take a request back
- both windows are fixed for the registry's whole life
- `seed` in the output is the coin that was spent; `registry` is the registry's address, its name; `fingerprint` is a short name for the same registry, the one wallets and explorers show

```bash
process_ms=180000; retract_ms=60000
open-datum create \
  --process-time "$process_ms" --retract-time "$retract_ms" \
  --vault alice.vault \
  > receipts/01-create.json
```

**Read what it returned:**

```bash
jq '{outcome, reason, seed, registry, fingerprint} | with_entries(select(.value != null))' receipts/01-create.json
```

**From now on every command names the registry by its address.** The address is read from the create receipt and goes into Alice's file as `registry`, and every command below finds it there:

```bash
jq --arg address "$(jq -r .registry receipts/01-create.json)" '.registry = $address' alice.json > alice.new && mv alice.new alice.json
jq . alice.json
```
