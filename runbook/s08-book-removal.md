# Step 8: book the removal of the key (Alice)

Removing a key is also two stages. Alice books the termination of `alice`. The receipt names the pending request, the live output the fold will release, and the deposit that will come back to her. It asks for Alice's passphrase.

```bash
# Book the removal ("terminate") of the key "alice". Like an insertion, it waits as a pending request.
open-datum terminate "${registry[@]}" --key alice "${provider[@]}" "${alice[@]}" > receipts/08-terminate.json
# released = the output the fold will release; deposit = what comes back to Alice
jq '{outcome, request, released, deposit, foldDeadline}' receipts/08-terminate.json
```
