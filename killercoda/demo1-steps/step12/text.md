Termination spends Alice's holding and donates its protected deposit to the treasury. It creates a pending termination carrying the key's active token and approval. This is permanent, has no reclaim window and cannot be undone. A later fold burns those tokens; the key can never be registered again.

```bash
open-datum terminate --holding "$(cat holding.ref)" --vault alice.vault > receipts/08-terminate.json
```{{exec}}

```bash
jq '{outcome, pending, treasuryDonation, submissions}' receipts/08-terminate.json
```{{exec}}
