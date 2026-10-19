# Step 5: read the key back

Reading is free and needs no key and no wallet. `inspect` asks the chain for the key's state and prints what it found: the key is now active, with its payload, its owner and the deposit that stays locked with it.

```bash
open-datum inspect "${registry[@]}" --key alice "${provider[@]}" > receipts/05-inspect.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/05-inspect.json
```
