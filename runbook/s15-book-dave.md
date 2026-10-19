# Step 15: book the key "dave" (Alice)

The reclaimed request no longer blocks anything, so Alice books one more key, `dave` (her passphrase).

```bash
# Book the key "dave". The registry takes requests again because the stuck one is gone.
open-datum insert "${registry[@]}" --key dave --payload payload.json "${provider[@]}" "${alice[@]}" > receipts/15-insert-dave.json
jq '{outcome, request, foldDeadline}' receipts/15-insert-dave.json
```
