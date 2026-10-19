# Step 10: read the removed key

The key `alice` is now terminal: gone for good, it can never be used again, and nothing holds it any more.

```bash
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/10-inspect.json
jq '{state: .leaf, root}' receipts/10-inspect.json
```
