# Step 12: book the key "bob" (Bob signs outside the program)

The registry takes requests again. This time Bob adds a key, with his own wallet and the external flow from the start: his command names his address and a bundle file, and the bundle holds the booking. Build (exit status 19), sign, send.

```bash
open-datum insert "${registry[@]}" --key bob --payload payload.json "${provider[@]}" --wallet-address "$bob_addr" --bundle bundles/insert-bob.bundle > receipts/12-insert-bob.json
jq '{outcome, request: .expected.request, foldDeadline: .expected.foldDeadline}' receipts/12-insert-bob.json
singular wallet sign --vault bob.vault --passphrase-fd 3 --out witnesses/insert-bob bundles/insert-bob.bundle 3< bob.passphrase
singular submit --witnesses witnesses/insert-bob "${provider[@]}" --receipt receipts/12-insert-bob.submitted.json bundles/insert-bob.bundle
jq '.submissions[] | {slot: .chainPoint.slot, confirmations}' receipts/12-insert-bob.submitted.json
```
