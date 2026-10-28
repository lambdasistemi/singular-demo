# Step 15: book one more key

The reclaimed request was never folded. Alice now books a fresh key, dave, so Bob can demonstrate an externally signed fold.

**Now Alice.**

```bash { window=alice }
alice
```

```bash { window=alice }
open-datum insert --deposit 3000000 --key dave --payload payload.json --vault alice.vault > receipts/15-insert-dave.json
```

```bash { window=alice }
jq -er .pending receipts/15-insert-dave.json > ../dave.pending
```
