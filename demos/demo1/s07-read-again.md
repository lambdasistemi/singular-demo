# Step 7: read the key back again

The same read as step 5. The payload is now `{"answer": 43}`; the controller and the deposit are unchanged.

```bash
open-datum inspect \
  --key alice \
  > receipts/07-inspect.json
jq '{state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/07-inspect.json
```
