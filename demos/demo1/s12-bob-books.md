# Step 12: book the key "bob" (Bob signs outside the program)

The registry takes requests again. This time Bob adds a key, with his own wallet and the external flow from the start: his command names his address and a bundle file instead of a vault, and the bundle holds the booking. Build (exit status 19, nothing sent), sign, send.

**Build the bundle:**

```bash { window=bob }
open-datum insert \
  --key bob --payload payload.json \
  --wallet-address "$bob_addr" --bundle bundles/insert-bob.bundle \
  > receipts/12-insert-bob.json
jq '{outcome, reason, request: .expected.request, foldDeadline: .expected.foldDeadline} | with_entries(select(.value != null))' receipts/12-insert-bob.json
```

**Bob signs:**

```bash { window=bob }
singular wallet sign --vault bob.vault --out witnesses/insert-bob bundles/insert-bob.bundle
```

**Send it** and wait until it has landed:

```bash { window=bob }
singular submit \
  --witnesses witnesses/insert-bob --receipt receipts/12-insert-bob.submitted.json \
  bundles/insert-bob.bundle
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/12-insert-bob.submitted.json
```
