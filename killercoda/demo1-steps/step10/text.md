The controller signs a direct update of the holding. It spends the previous holding and creates its replacement with the same protected control and deposit. No request is booked and no fold is needed.

```bash
printf '{"answer":43}\n' > payload-new.json
open-datum update --holding "$(cat holding.ref)" --payload payload-new.json --vault alice.vault > receipts/06-update.json
```{{exec}}

```bash
jq '{outcome, holding, treasuryDonation, submissions}' receipts/06-update.json
jq -er .holding receipts/06-update.json > holding.new && mv holding.new holding.ref
```{{exec}}
