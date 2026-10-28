# Step 9: Bob folds the termination

Anyone can fold the public termination request. Bob burns its approval and active token and receives the request's value after his fee. Alice's protected deposit has already gone to the treasury.

**Now Bob.**

```bash { window=bob }
bob
```

```bash { window=bob }
open-datum fold --pending "$(cat ../termination.pending)" --vault bob.vault > receipts/09-fold-terminate.json
```

```bash { window=bob }
jq '{outcome, folded, root, stateOutput, submissions}' receipts/09-fold-terminate.json
```
