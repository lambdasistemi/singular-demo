# Step 8: book the removal of the key (Alice)

Removing a key is also two stages. Alice books the termination of `alice`. Like an insertion, it waits as a pending request. It asks for Alice's passphrase.

In the output, `released` is the output the fold will release and `deposit` is what comes back to Alice.

```bash
open-datum terminate \
  --key alice \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/08-terminate.json
jq '{outcome, request, released, deposit, foldDeadline}' receipts/08-terminate.json
```
