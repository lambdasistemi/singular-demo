# Step 8: Alice books permanent termination

Termination spends Alice's holding and donates its protected deposit to the treasury. It creates a pending termination carrying the key's active token and approval. This is permanent, has no reclaim window and cannot be undone. A later fold burns those tokens; the key can never be registered again.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
open-datum terminate --holding "$(cat holding.ref)" --vault alice.vault > receipts/08-terminate.json
```

```bash { window=alice }
jq '{outcome, pending, treasuryDonation, submissions}' receipts/08-terminate.json
jq -er .pending receipts/08-terminate.json > ../termination.pending
```
