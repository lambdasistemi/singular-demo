# Step 15: book the key "dave" (Alice)

The reclaimed request is settled: its deposit is back with Alice. She books one more key, `dave` (her passphrase).

```bash
open-datum insert \
  --key dave --payload payload.json \
  --vault alice.vault \
  > receipts/15-insert-dave.json
```

**Read what it returned:**

```bash
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/15-insert-dave.json
```
