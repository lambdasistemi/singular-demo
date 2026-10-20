A registry is created from one unspent coin, the seed: whoever holds that coin can create exactly one registry from it, which is what makes its identity unique. `create` picks a suitable coin of Alice's by itself and names it in the receipt. The registry's name is its state token.

The windows are short on purpose, so the waits later last minutes: 180 seconds for the registry to process a request, then 60 more for its owner to take it back. A booking must be folded within its 180 seconds; raise `process_ms` below if there is a lot to say between the two. The [documentation on choosing the windows](https://lambdasistemi.github.io/singular/docs/singular-node/#choosing-a-registrys-windows).

**The settings.** The commands need the same settings again and again: where the chain answers, the chain's clock data and number, the compiled contracts, a folder for the registry's journal and, once it exists, the registry's name. Each can be given as an option on the command (`--koios-url URL`), as an environment variable (`SINGULAR_KOIOS_URL=URL`) or as a key in a JSON file (`"koios-url": "URL"`). The first one present wins: option, then variable, then file. The [full description](https://lambdasistemi.github.io/singular/docs/singular-node/#giving-the-chain-the-contracts-and-the-registry-once) is in the documentation.

**For this tutorial, the JSON file**, `singular.json`, so that no command below repeats them. You could override a value with a variable or an option, or skip the file and give every setting that way. The devnet's settings line has two of the values; `jq` builds the file from it. Here the file's name is in the variable `SINGULAR_CONFIG`.

- `koios-url`: where the chain's web API answers (`providerUrl` in the devnet's line)
- `network-time`: the chain's clock data, when each slot happens (`networkTimeDirectory`)
- `network-magic`: the number of this private chain, 42
- `blueprint`: the compiled contracts
- `state-dir`: the folder for the registry's journal

```bash
jq --arg blueprint "$blueprint" '{"koios-url": .providerUrl, "network-time": .networkTimeDirectory, "network-magic": 42, "blueprint": $blueprint, "state-dir": "reg"}' ../devnet.out > "$SINGULAR_CONFIG"
jq . "$SINGULAR_CONFIG"
```{{exec}}

**How to read the commands from here on.** The chain, the contracts and the journal folder come from `singular.json`, so each command shows only what it does:

- its own options: the key, the payload, the windows
- the wallet that signs: `--vault` for a wallet that signs in one command (it asks for the passphrase), or `--wallet-address` with `--bundle` for the external way

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
```{{exec}}

**Read what it returned:**

```bash
jq '{outcome, reason, seed, stateToken} | with_entries(select(.value != null))' receipts/01-create.json
```{{exec}}

**From now on every command names the registry by its state token.** The token is the registry's name, read from the create receipt. It goes into the same file as `state-token`, and every command below finds it there:

```bash
jq --arg token "$(jq -r .stateToken receipts/01-create.json)" '."state-token" = $token' "$SINGULAR_CONFIG" > singular.new && mv singular.new "$SINGULAR_CONFIG"
jq . "$SINGULAR_CONFIG"
```{{exec}}
