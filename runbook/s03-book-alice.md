# Step 3: book the key "alice" (Alice)

Alice adds a key. She books `alice` with a first piece of data, the payload: here the number 42, written as Plutus data in JSON. The booking locks her deposit of 2 ada in a request at the registry. It does not change the registry yet: the request is pending until somebody folds it, and the receipt names the deadline for that, the fold deadline. Alice's wallet becomes the key's controller, the only one who may change it.

The payload:

```bash
# The data stored under the key, as Plutus data in JSON: constructor 0 holding the integer 42.
echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json
```

The booking. It asks for Alice's passphrase:

```bash
# Book the insertion of the key "alice" with that payload. Alice signs from her vault and the command sends it.
# The request now waits at the registry; it is not part of the registry until it is folded.
open-datum insert "${registry[@]}" --key alice --payload payload.json "${provider[@]}" "${alice[@]}" > receipts/03-insert-alice.json
# request = the pending request (transaction#output); foldDeadline = the slot by which it must be folded
jq '{outcome, request, foldDeadline}' receipts/03-insert-alice.json
```
