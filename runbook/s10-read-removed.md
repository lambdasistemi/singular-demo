# Step 10: read the removed key

The key `alice` is now terminal: gone for good, it can never be used again, and nothing holds it any more.

```bash
open-datum inspect \
  --key alice \
  --state-dir reg --blueprint "$blueprint" --state-token "$token" \
  --koios-url "$koios_url" --network-time "$time_dir" --network-magic 42 \
  > receipts/10-inspect.json
jq '{state: .leaf, root}' receipts/10-inspect.json
```
