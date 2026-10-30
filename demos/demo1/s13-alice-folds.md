# Step 13: Alice folds Bob's booking

Alice folds with her own wallet whatever is pending, which is Bob's registration. The fold is open to everyone and does not need Bob's key, payload file or journal, nor the reference of his booking.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
open-datum fold --vault alice.vault > receipts/13-fold-bob.json
```

```bash { window=alice }
jq '{outcome, folded, skipped, left, root}' receipts/13-fold-bob.json
```
