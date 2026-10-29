Everything the demo sent is a real transaction on the devnet, and each can be examined: what the program prepared, which transaction the fold reported, and what the chain says about it. Run these any time after step 16.

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

**What a prepared transaction is for.** A bundle is a JSON file written by a command run with `--bundle`. Its `effects` say in plain words what each transaction does, and `deadline` is the slot by which it must be sent.

```bash
jq '.transactions[] | {effects, deadline}' bundles/fold-dave.bundle
```{{exec}}

**Which transaction landed, and where.** The fold receipt names each transaction by its hash and records whether inclusion and the expected output were observed.

```bash
jq '.submissions[]? | {transaction: .identity, chainPoint, confirmations, claims}' receipts/16a-fold-dave.submitted.json
```{{exec}}

**Every transaction of the demo**, in the order of the receipts. The loop walks all receipts and prints the transactions each one landed (`tx-info.json` is the chain's answer about one of them, kept below, not a receipt, so the loop leaves it out; that also keeps this observation true when it runs again at the end of the path).

```bash
for f in receipts/*.json; do [ "$f" = receipts/tx-info.json ] && continue; jq -r --arg f "$f" '.submissions[]? | "\($f)  \(.identity)  confirmations \(.confirmations)"' "$f"; done
```{{exec}}

**What the chain says about one of them.** The devnet's web API answers the same query a public Koios does. Take the first transaction of the step 16 fold and ask the chain about it. The full answer is kept in `receipts/tx-info.json`.

```bash
tx=$(jq -r '.submissions[0].identity' receipts/16a-fold-dave.submitted.json)
curl -fsS -X POST "$(koios_url)/tx_info" -H 'content-type: application/json' -d "{\"_tx_hashes\":[\"$tx\"]}" > receipts/tx-info.json
```{{exec}}

The short form shows where the money comes from and goes to, which tokens move, and which outputs carry data:

```bash
jq '.[0] | {tx_hash, block_height, absolute_slot, inputs: [.inputs[] | {from: .payment_addr.bech32[0:16], ada: ((.value|tonumber)/1000000)}], outputs: [.outputs[] | {to: .payment_addr.bech32[0:16], ada: ((.value|tonumber)/1000000), tokens: [.asset_list[].asset_name[0:8]], has_data: (.inline_datum != null)}]}' receipts/tx-info.json
```{{exec}}

`jq . receipts/tx-info.json` prints all of it. The data on an output is shown as raw bytes; `open-datum inspect` decodes a holding's data, as in step 5. This devnet's web API does not report fees or times.
