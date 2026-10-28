# Step 13: Alice folds Bob's booking

Alice folds Bob's named registration with her own wallet. The fold is open to everyone and does not need Bob's key, payload file or journal.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
open-datum fold --pending "$(cat ../bob.pending)" --vault alice.vault > receipts/13-fold-bob.json
```

```bash { window=alice }
jq '{outcome, folded, root, submissions}' receipts/13-fold-bob.json
```
