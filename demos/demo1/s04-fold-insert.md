# Step 4: Bob folds Alice's booking

Bob needs the public token, the pending reference, chain data and his own wallet. He receives no file from Alice's wallet or journal. The fold creates Alice's holding with its payload and deposit.

**Now Bob.**

```bash { window=bob }
bob
```

```bash { window=bob }
open-datum fold --pending "$(cat ../alice.pending)" --vault bob.vault > receipts/04-fold-insert.json
```

```bash { window=bob }
jq '{outcome, folded, root, stateOutput, submissions}' receipts/04-fold-insert.json
```
