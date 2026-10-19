# Step 3: book the key "alice" (Alice)

Alice adds a key. She books `alice` with a first piece of data, the payload: here the number 42, written as Plutus data in JSON. The booking locks her deposit of 2 ada in a request at the registry. It does not change the registry yet: the request is pending until somebody folds it, and the receipt names the deadline for that, the fold deadline. Alice's wallet becomes the key's controller, the only one who may change it.

**The payload**: the data stored under the key, as Plutus data in JSON, constructor 0 holding the integer 42.

```bash
echo '{"constructor":0,"fields":[{"int":42}]}' > payload.json
```

**The booking.** Alice signs from her vault and the command sends it; it asks for her passphrase. The request now waits at the registry and is not part of it until it is folded.

- `request` in the output is the pending request (transaction and output number)
- `foldDeadline` is the slot by which it must be folded

```bash
open-datum insert \
  --key alice --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/03-insert-alice.json
jq '{outcome, request, foldDeadline}' receipts/03-insert-alice.json
```
