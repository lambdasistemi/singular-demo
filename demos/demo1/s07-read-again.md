# Step 7: read the key again

Alice reads the key again. It is still `live`, with the new payload and the same deposit, in the holding the update created. The previous holding has been spent.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
open-datum inspect --key alice --json > receipts/07-read-alice.json
jq '{answer, payload, deposit, holding: .outputRef}' receipts/07-read-alice.json
```
