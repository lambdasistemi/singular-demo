# Look at the wallets

A wallet holds outputs: coins at its address, each one named by the transaction that created it and an index. The devnet's web API lists them. Run this now to see what each wallet starts with, and again whenever you like, for instance after step 16, to see what the journey cost: deposits locked in requests, fees paid, tokens received.

A small helper that asks the chain for the outputs at an address and prints the total and each output:

```bash
# wallet_show ADDRESS: list the outputs at an address (the chain's "address_utxos" answer) in a short form.
# total_ada = what the wallet holds; each line is one output: the transaction that made it, its index, its ada, and any tokens.
wallet_show() { curl -fsS -X POST "$koios_url/address_utxos" -H 'content-type: application/json' -d "{\"_addresses\":[\"$1\"]}" | jq '{outputs: length, total_ada: ([.[] | (.value|tonumber)] | add / 1000000), utxos: [.[] | {tx: .tx_hash[0:12], ix: .tx_index, ada: ((.value|tonumber)/1000000), tokens: [.asset_list[]? | .asset_name[0:8]]}]}'; }
```

Alice's wallet. At the start: six outputs of 2000 ada.

```bash
# Alice's outputs, from her public address. No passphrase is needed to look.
wallet_show "$alice_addr"
```

Bob's wallet, the same way:

```bash
# Bob's outputs.
wallet_show "$bob_addr"
```

The chain's own clock, for reference. It is what the program uses to judge windows:

```bash
# The newest block the chain has: its slot (the chain's time unit) and number.
curl -fsS "$koios_url/tip" | jq '.[0] | {abs_slot, block_no}'
```
