# Step 3: book the key "alice" (Alice)

Alice adds a key. She books `alice` with a first piece of data, the payload: here the number 42, written as Plutus data in JSON. The booking locks her deposit of 2 ada in a request at the registry. It does not change the registry yet: the request is pending until somebody folds it, and the receipt names the deadline for that, the fold deadline. Alice's wallet becomes the key's controller, the only one who may change it.

```bash
echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json
open-datum insert "${registry[@]}" --key alice --payload payload.json "${provider[@]}" "${alice[@]}" 3< alice.passphrase > receipts/03-insert-alice.json
jq '{outcome, request, foldDeadline}' receipts/03-insert-alice.json
```
