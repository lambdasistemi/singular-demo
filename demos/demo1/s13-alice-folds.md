# Step 13: fold Bob's key (Alice, vault in one command)

Anyone may fold, and here Alice does. The fold is a single command, because it is her vault that signs and sends it: build, sign, send and wait. It prints its receipt when it has landed. Run it before the fold deadline of step 12.

In the output, `settled` lists the requests now part of the registry and `root` is the registry's new fingerprint.

```bash
open-datum fold \
  --vault alice.vault \
  > receipts/13-fold-bob.json
```

**Read what it returned:**

```bash
jq '{outcome, reason, settled: [.settled[]? | {key, edge}], root} | with_entries(select(.value != null))' receipts/13-fold-bob.json
```

If the fold is refused because the window ended, the recovery is the one at the end of step 4 for a booking of a key (Bob takes his request back with a reclaim while the retract window is open, or any wallet rejects it after both windows), and the one at the end of step 9 when only the reject is left.
