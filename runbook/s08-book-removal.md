# Step 8: book the removal of the key (Alice)

Removing a key is also two stages. Alice books the termination of `alice`. The receipt names the pending request, the live output the fold will release, and the deposit that will come back to her.

```bash
open-datum terminate "${registry[@]}" --key alice "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/08-terminate.json
jq '{outcome, request, released, deposit, foldDeadline}' receipts/08-terminate.json
```
