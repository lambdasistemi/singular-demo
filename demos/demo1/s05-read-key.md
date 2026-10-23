# Step 5: read the key back

**Now Alice.**

```bash { window=alice }
alice
```

Reading is free and needs no key and no wallet: anyone can check. `inspect` asks the chain for the key's state and prints what it found. The key is now active, with its payload (`{"answer": 42}`), its controller and the deposit that stays locked with it. `root` is a fingerprint of the whole registry.

```bash { window=alice }
open-datum inspect \
  --key alice \
  > receipts/05-inspect.json
jq '{key: .keyText, state: .leaf, payload: .applicationOutput.payload, controller: .applicationOutput.controller, deposit: .applicationOutput.deposit, root}' receipts/05-inspect.json
```

**What a script can rely on.** The output read here is the key's live value: it holds the token named `alice`, which only the registry's fold mints and which is burned when the key ends. Its fixed part has not changed since the booking, because `open-datum` refuses any update that changes it. A script on the chain can read this output without spending it and trust what it finds: who controls the key and what the payload is. It has nothing to compute or prove.
