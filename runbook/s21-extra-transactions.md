# Extra: look inside the transactions

Everything the demo sent is a real transaction on the devnet, and each can be examined: what the program prepared, which transaction landed and where, and what the chain says about it. Run these any time after step 4.

**What a prepared transaction is for.** A bundle is a JSON file written by a command run with `--bundle`. Its `effects` say in plain words what each transaction does, and `deadline` is the slot by which it must be sent.

```bash
jq '.transactions[] | {effects, deadline}' bundles/fold-insert.bundle
```

**Which transaction landed, and where.** The landing receipt names each transaction by its `identity` (its hash, the name to look it up by), the slot and block it is in, and how many blocks have been built on top since.

```bash
jq '.submissions[] | {transaction: .identity, slot: .chainPoint.slot, block: .chainPoint.blockHash[0:12], confirmations}' receipts/04-fold-insert.submitted.json
```

**Every transaction of the demo**, in the order of the receipts. The loop walks all receipts and prints the transactions each one landed.

```bash
for f in receipts/*.json; do jq -r --arg f "$f" '.submissions[]? | "\($f)  \(.identity)  slot \(.chainPoint.slot)"' "$f"; done
```

**What the chain says about one of them.** The devnet's web API answers the same query a public Koios does. Take the first transaction of the step 4 fold and ask the chain about it. The full answer is kept in `receipts/tx-info.json`.

```bash
tx=$(jq -r '.submissions[0].identity' receipts/04-fold-insert.submitted.json)
curl -fsS -X POST "$koios_url/tx_info" -H 'content-type: application/json' -d "{\"_tx_hashes\":[\"$tx\"]}" > receipts/tx-info.json
```

The short form shows where the money comes from and goes to, which tokens move, and which outputs carry data:

```bash
jq '.[0] | {tx_hash, block_height, absolute_slot, inputs: [.inputs[] | {from: .payment_addr.bech32[0:16], ada: ((.value|tonumber)/1000000)}], outputs: [.outputs[] | {to: .payment_addr.bech32[0:16], ada: ((.value|tonumber)/1000000), tokens: [.asset_list[].asset_name[0:8]], has_data: (.inline_datum != null)}]}' receipts/tx-info.json
```

`jq . receipts/tx-info.json` prints all of it. The data on an output is shown as raw bytes; `open-datum inspect` (step 5) prints the same data decoded. This devnet's web API does not report fees or times.
