# Step 7: read the key back again

The same read as step 5. The payload is now 43; the owner and the deposit are unchanged.

```bash
open-datum inspect \
  --key alice \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  > receipts/07-inspect.json
jq '{state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/07-inspect.json
```
