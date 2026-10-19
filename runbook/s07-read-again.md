# Step 7: read the key back again

The same read: the payload is now 43, and the owner and the deposit are unchanged.

```bash
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/07-inspect.json
jq '{state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/07-inspect.json
```
