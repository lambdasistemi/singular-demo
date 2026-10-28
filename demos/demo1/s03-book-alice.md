# Step 3: Alice books her key

Alice registers the key alice with a payload and a protected deposit of 3 ada. The booking creates a pending request; it does not change the registry yet. She publishes its output reference for a folder. Fold the next page before the processing deadline.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
printf '{"answer":42}\n' > payload.json
open-datum insert --key alice --payload payload.json --deposit 3000000 --vault alice.vault > receipts/03-insert-alice.json
```

```bash { window=alice }
jq '{outcome, pending, deposit, processDeadline, reclaimEnd}' receipts/03-insert-alice.json
jq -er .pending receipts/03-insert-alice.json > ../alice.pending
```
