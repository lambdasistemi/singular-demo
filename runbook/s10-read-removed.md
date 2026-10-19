# Step 10: read the removed key

The key is now terminal: gone for good, it can never be used again, and nothing holds it any more.

```bash
# Read "alice" once more. The state is now terminal: the key is gone for good.
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/10-inspect.json
jq '{state: .leaf, root}' receipts/10-inspect.json
```
