# Step 11: clean up an expired registration

Alice books a different key, late, and nobody folds it: no fold runs between this booking and its cleanup, so no fold finds it while it can still be folded. After both its processing and reclaim windows expire, anyone may clean it up. The refund goes to the registration's refund address. Cleanup is a separate command from reclaim and applies to registrations, not permanent termination.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
open-datum insert --deposit 3000000 --key late --payload payload.json --vault alice.vault > receipts/11a-insert-late.json
```

```bash { window=alice }
jq -er .pending receipts/11a-insert-late.json > ../late.pending
jq -er .reclaimEnd receipts/11a-insert-late.json > ../late.expires
```

**Now Bob.**

```bash { window=bob }
bob
```

```bash { window=bob }
wait_until_ms "$(cat ../late.expires)"
open-datum cleanup --pending "$(cat ../late.pending)" --vault bob.vault > receipts/11d-cleanup.json
```

```bash { window=bob }
jq '{outcome, pending, returned, locked, submissions}' receipts/11d-cleanup.json
```
