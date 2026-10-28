# Step 6: Alice changes the payload

The controller signs a direct update of the holding. It spends the previous holding and creates its replacement with the same protected control and deposit. No request is booked and no fold is needed.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
printf '{"answer":43}\n' > payload-new.json
open-datum update --holding "$(cat holding.ref)" --payload payload-new.json --vault alice.vault > receipts/06-update.json
```

```bash { window=alice }
jq '{outcome, holding, treasuryDonation, submissions}' receipts/06-update.json
jq -er .holding receipts/06-update.json > holding.new && mv holding.new holding.ref
```
