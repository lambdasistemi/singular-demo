# Step 14: Alice takes back an unprocessed registration

Alice books the key unfolded, and nobody folds it: no fold runs before the reclaim, so no fold finds it. Once its processing deadline passes, the refund address can sign a reclaim during its reclaim window. This request disappears without ever registering the key, and its locked value returns to Alice.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
open-datum insert --deposit 3000000 --key unfolded --payload payload.json --vault alice.vault > receipts/14a-insert-unfolded.json
```

```bash { window=alice }
wait_until_ms "$(jq -er .processDeadline receipts/14a-insert-unfolded.json)"
open-datum reclaim --pending "$(jq -er .pending receipts/14a-insert-unfolded.json)" --vault alice.vault > receipts/14c-reclaim.json
```

```bash { window=alice }
jq '{outcome, pending, returned, locked, submissions}' receipts/14c-reclaim.json
```
