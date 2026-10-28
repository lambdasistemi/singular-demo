Alice books a different key, late, and nobody folds it. After both its processing and reclaim windows expire, anyone may clean it up. The refund goes to the registration's refund address. Cleanup is a separate command from reclaim and applies to registrations, not permanent termination.

```bash
open-datum insert --deposit 3000000 --key late --payload payload.json --vault alice.vault > receipts/11a-insert-late.json
```{{exec}}

```bash
jq -er .pending receipts/11a-insert-late.json > ../late.pending
jq -er .reclaimEnd receipts/11a-insert-late.json > ../late.expires
```{{exec}}

**Now Bob.** Go to Bob's window: click `bob`, or press `Ctrl-b 1`.

```bash
bob
```{{exec}}

```bash
wait_until_ms "$(cat ../late.expires)"
open-datum cleanup --pending "$(cat ../late.pending)" --vault bob.vault > receipts/11d-cleanup.json
```{{exec}}

```bash
jq '{outcome, pending, returned, locked, submissions}' receipts/11d-cleanup.json
```{{exec}}
