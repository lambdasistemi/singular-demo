# Step 15: book the key "dave" (Alice)

The reclaimed request no longer blocks anything, so the registry takes requests again. Alice books one more key, `dave` (her passphrase).

```bash
open-datum insert \
  --key dave --payload payload.json \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  --vault alice.vault \
  > receipts/15-insert-dave.json
```

**Read what it returned:**

```bash
jq '{outcome, request, foldDeadline}' receipts/15-insert-dave.json
```
