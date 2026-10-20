# Step 5: read the key back

Reading is free and needs no key and no wallet: anyone can check. `inspect` asks the chain for the key's state and prints what it found. The key is now active, with its payload (42), its owner and the deposit that stays locked with it. `root` is a fingerprint of the whole registry.

```bash
open-datum inspect \
  --key alice \
  > receipts/05-inspect.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, deposit: .applicationOutput.deposit, root}' receipts/05-inspect.json
```
