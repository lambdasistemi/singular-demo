Removing a key is also two stages. Alice books the termination of `alice`. Like an insertion, it waits as a pending request.

In the output, `released` is the output the fold will release and `deposit` is what comes back to Alice.

```bash
open-datum terminate \
  --key alice \
  --vault alice.vault \
  > receipts/08-terminate.json
```{{exec}}

**Read what it returned:**

```bash
jq '{outcome, reason, request, released, deposit, foldDeadline} | with_entries(select(.value != null))' receipts/08-terminate.json
```{{exec}}
