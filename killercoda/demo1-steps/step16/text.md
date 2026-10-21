The registry takes requests again. This time Bob adds a key, with his own wallet and the external flow from the start: his command names his address and a bundle file instead of a vault, and the bundle holds the booking. Build (exit status 19, nothing sent), sign, send.

**Build the bundle**, with Alice's payload file:

```bash
open-datum insert \
  --key bob --payload ../alice/payload.json \
  --wallet-address "$bob_addr" --bundle bundles/insert-bob.bundle \
  > receipts/12-insert-bob.json
jq '{outcome, reason, request: .expected.request, foldDeadline: .expected.foldDeadline} | with_entries(select(.value != null))' receipts/12-insert-bob.json
```{{exec}}

**Bob signs:**

```bash
singular wallet sign --vault bob.vault --out witnesses/insert-bob bundles/insert-bob.bundle
```{{exec}}

**Send it** and wait until it has landed:

```bash
singular submit \
  --witnesses witnesses/insert-bob --receipt receipts/12-insert-bob.submitted.json \
  bundles/insert-bob.bundle
jq '.submissions[]? | {slot: .chainPoint.slot, confirmations}' receipts/12-insert-bob.submitted.json
```{{exec}}
