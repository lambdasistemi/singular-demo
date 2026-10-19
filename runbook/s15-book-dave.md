# Step 15: book the key "dave" (Alice)

The reclaimed request no longer blocks anything, so Alice books one more key, `dave`.

```bash
open-datum insert "${registry[@]}" --key dave --payload payload.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/15-insert-dave.json
jq '{outcome, request, foldDeadline}' receipts/15-insert-dave.json
```
