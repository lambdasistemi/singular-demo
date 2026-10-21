The reclaimed request is settled: its deposit is back with Alice. She books one more key, `dave`.

```bash
open-datum insert \
  --key dave --payload payload.json \
  --vault alice.vault \
  > receipts/15-insert-dave.json
```{{exec}}

**Read what it returned:**

```bash
jq '{outcome, reason, request, foldDeadline} | with_entries(select(.value != null))' receipts/15-insert-dave.json
```{{exec}}
