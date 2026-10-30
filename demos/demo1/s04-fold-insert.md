# Step 4: Bob folds Alice's booking

Bob needs the public token, chain data and his own wallet. He does not need to know which requests are pending, and he receives no file from Alice's wallet or journal: `open-datum fold` finds the registry's pending requests on the chain and folds the ones it can. The fold creates Alice's holding with its payload and deposit. The receipt lists what was folded, what was skipped and why, and how many foldable requests were left. Here it folds Alice's registration, and it skips the application's configuration output, which holds an approval token but is not a request.

**Now Bob.**

```bash { window=bob }
bob
```

```bash { window=bob }
open-datum fold --vault bob.vault > receipts/04-fold-insert.json
```

```bash { window=bob }
jq '{outcome, folded, skipped, left, root, stateOutput}' receipts/04-fold-insert.json
```
