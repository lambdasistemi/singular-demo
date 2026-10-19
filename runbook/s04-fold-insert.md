# Step 4: fold it (Bob signs outside the program)

A fold moves pending requests into the registry for good. Anyone may do it, and here Bob does, the external way: his command only names his address and a bundle file. It builds the transactions, writes them into that file, signs nothing and sends nothing, and exits with status 19, which means waiting for signatures. It is not an error.

Then Bob signs the bundle with his vault, and the signed bundle is sent; the send waits until the transactions have landed. Run all three before the fold deadline of step 3.

```bash
# 4a. Build the fold into a bundle file (exit status 19).
open-datum fold "${registry[@]}" "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/fold-insert.bundle > receipts/04-fold-insert.json
jq '{outcome, settling: [.expected.settled[] | {key, edge}], msLeft: .expected.remainingMs}' receipts/04-fold-insert.json

# 4b. Bob signs the bundle with his vault (witnesses = signatures).
singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/fold-insert bundles/fold-insert.bundle 3< bob.passphrase

# 4c. Send the signed bundle and wait until it has landed.
singular submit --witnesses witnesses/fold-insert "${provider[@]}" --receipt receipts/04-fold-insert.submitted.json bundles/fold-insert.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/04-fold-insert.submitted.json
```
